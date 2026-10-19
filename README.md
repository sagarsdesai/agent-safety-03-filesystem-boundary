# Workshop 03 — Filesystem boundary

## Aim
Demonstrate a permitted read, permitted temporary write, and a denied
write to a directory that ordinary Linux permissions allow.

## Concepts
The image supplies software. Linux permissions govern ordinary access.
OpenShell adds process restrictions enforced by Landlock in the host kernel.
Direct Docker execution is an administrative control path; it does not
demonstrate access available to the sandboxed agent.

## Prerequisites
A Linux Docker-backed OpenShell sandbox using the Task 02 tool image.
Task 02 tested source: d8e5e86 in
https://github.com/sagarsdesai/agent-safety-02-tool-image

Use its pinned build recipe. Record the actual image ID used here.
This workshop does not build an image or create a sandbox.

The current experiment expects:
- sandbox execution as UID/GID 1000;
- /etc readable, /tmp writable, /var/log read-only under OpenShell;
- administrative Docker access from the host;
- sh, mktemp, chmod, cat, rm and rmdir in the image.

Review the effective policy and confirm that the supplied container is
the workload belonging to the supplied sandbox before running.

## Run
From the repository root:
    bash scripts/validate.sh WORKLOAD_CONTAINER SANDBOX_NAME

Use host Docker administration only for fixture setup, the control,
inspection and cleanup. The tested workload actions use OpenShell.

The script prints the identity and OS information, verifies a temporary
write, creates a disposable writable directory under /var/log, verifies
a Docker control write, and attempts a corresponding OpenShell write.
It also collects relevant workload Landlock diagnostics.

## Expected observations
The control write succeeds; the OpenShell write fails with Permission denied.
Landlock application/build diagnostics support enforcement attribution.
A transport or command-execution failure is not a valid denied-write result.

## Evidence
Record a transcript, current tool versions, the effective policy,
image ID and filtered workload Landlock diagnostics.
Review all files before committing. Do not commit raw sandbox metadata,
credentials, private endpoints or the confidential presentation.

## Troubleshooting
If fixture creation, chmod or the control fails, stop: no valid comparison
exists. Changing ownership is unnecessary and may be prohibited.
An empty fixture path must never be used.
If diagnostics are absent, attribution needs further investigation.
Do not broaden policy or install packages to force a passing result.

## Cleanup and recovery
The script removes its known probe files and uniquely named fixture.
It leaves the sandbox and policy intact.
If interrupted before cleanup, use the printed fixture path to remove
only control.txt and sandbox.txt, then use rmdir on that directory.
Never recursively delete /var/log or prune unrelated Docker resources.

## Limits
A successful comparison establishes the tested operation and path.
It is not an escape-resistance audit, network-policy test or DPU test.
No macOS runtime validation is claimed.
Fresh-clone verification must be recorded separately.
