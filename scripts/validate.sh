#!/usr/bin/env bash
set -euo pipefail

container=${1:?Supply the workload container}
sandbox=${2:?Supply the sandbox name}
openshell=${OPENSHELL_BIN:-/usr/bin/openshell}
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$root/evidence"

fixture=
cleanup() {
  local result=$?
  trap - EXIT
  if [[ -n "$fixture" ]]; then
    if ! docker exec --user 0 "$container" sh -c '
      set -eu
      rm -f "$1/control.txt" "$1/sandbox.txt"
      rmdir "$1"
    ' sh "$fixture"; then
      printf 'Cleanup failed; inspect fixture: %s\n' "$fixture" >&2
      exit 1
    fi
    printf '%s\n' 'Disposable fixture removed'
  fi
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

"$openshell" --version
docker version --format \
  'Docker client: {{.Client.Version}}; server: {{.Server.Version}}'
docker inspect --format '{{.Image}}' "$container" \
  > "$root/evidence/image-id.txt"
"$openshell" sandbox get "$sandbox" --policy-only \
  > "$root/evidence/effective-policy.yaml"

printf '%s\n' 'Checking restricted execution identity'
uid=$("$openshell" sandbox exec -n "$sandbox" -- id -u)
gid=$("$openshell" sandbox exec -n "$sandbox" -- id -g)
if [[ "$uid" != 1000 || "$gid" != 1000 ]]; then
  printf '%s\n' 'Unexpected identity; review before adapting the control' >&2
  exit 1
fi

printf '%s\n' 'Permitted read and temporary write'
"$openshell" sandbox exec -n "$sandbox" -- sh -c '
set -eu
id
cat /etc/os-release
d=$(mktemp -d /tmp/task03-fs.XXXXXX)
trap '\''rm -f "$d/probe.txt"; rmdir "$d"'\'' EXIT
printf "%s\n" "permitted write succeeded" > "$d/probe.txt"
cat "$d/probe.txt"
'

fixture=$(docker exec --user 0 "$container" \
  mktemp -d /var/log/task03-fs.XXXXXX)
if [[ ! "$fixture" =~ ^/var/log/task03-fs\.[A-Za-z0-9]+$ ]]; then
  printf '%s\n' 'Unexpected fixture path; manual inspection required' >&2
  fixture=
  exit 1
fi
printf 'Disposable fixture: %s\n' "$fixture"
docker exec --user 0 "$container" chmod 1777 "$fixture"

printf '%s\n' 'Direct Docker control'
docker exec --user 1000:1000 "$container" sh -c '
set -eu
id
ls -ld "$1"
printf "%s\n" "control write succeeded" > "$1/control.txt"
cat "$1/control.txt"
' sh "$fixture"

printf '%s\n' 'Corresponding restricted write'
set +e
"$openshell" sandbox exec -n "$sandbox" -- sh -c '
set -eu
test -n "$1"
id
printf "%s\n" "restricted probe started"
printf "%s\n" "sandbox write probe" > "$1/sandbox.txt"
' sh "$fixture" > "$root/evidence/denied-write.txt" 2>&1
denied_status=$?
set -e
cat "$root/evidence/denied-write.txt"
printf 'Restricted command exit status: %s\n' "$denied_status"

if [[ "$denied_status" == 0 ]] ||
   ! grep -Fq 'restricted probe started' "$root/evidence/denied-write.txt" ||
   ! grep -Fq "$fixture/sandbox.txt" "$root/evidence/denied-write.txt" ||
   ! grep -Fiq 'Permission denied' "$root/evidence/denied-write.txt"; then
  printf '%s\n' 'Expected filesystem denial was not established' >&2
  exit 1
fi

docker logs --tail 500 "$container" \
  > "$root/evidence/workload-log.private.local" 2>&1
if ! grep -Ei 'landlock.*(applying|built)|applying.*landlock|landlock.*ruleset' \
  "$root/evidence/workload-log.private.local" \
  > "$root/evidence/landlock.txt"; then
  printf '%s\n' 'No matching diagnostics; enforcement attribution needs review' >&2
  exit 1
fi
rm "$root/evidence/workload-log.private.local"
cat "$root/evidence/landlock.txt"
printf '%s\n' 'Comparison passed; review policy and diagnostics for attribution'
