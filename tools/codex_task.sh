#!/usr/bin/env bash
# Run one delegated Codex worker task non-interactively in this workspace.
# See docs/CODEX_ORCHESTRATION.md. Usage:
#   tools/codex_task.sh <task-name> <brief-file> [extra codex exec args...]
# Environment overrides: CODEX_MODEL, CODEX_EFFORT, CODEX_NETWORK (1/0),
# CODEX_RUN_DIR.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ $# -lt 2 ]]; then
  printf 'Usage: %s <task-name> <brief-file> [extra codex exec args...]\n' "$0" >&2
  exit 2
fi
name="$1"; brief="$2"; shift 2
if [[ ! "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
  printf 'Task name may only contain letters, digits, ., _ and -\n' >&2; exit 2
fi
if [[ ! -s "$brief" ]]; then printf 'Brief not found or empty: %s\n' "$brief" >&2; exit 2; fi

model="${CODEX_MODEL:-gpt-6.1-sol}"
effort="${CODEX_EFFORT:-medium}"
network="${CODEX_NETWORK:-1}"
run_dir="${CODEX_RUN_DIR:-/tmp/codex-runs}/$name"

mkdir -p "$run_dir"
cp "$brief" "$run_dir/brief.md"
# Only the workspace and /tmp are writable; workers run Flutter/Dart through
# tools/sdk_direct.sh. flutter test needs loopback sockets, which the sandbox
# only allows with network access enabled.
net_args=()
[[ "$network" == 1 ]] && net_args=(-c sandbox_workspace_write.network_access=true)

printf 'Codex task %s: model=%s effort=%s network=%s\nOutput: %s\n' \
  "$name" "$model" "$effort" "$network" "$run_dir" >&2
status=0
codex exec -m "$model" -c "model_reasoning_effort=\"$effort\"" \
  -s workspace-write --skip-git-repo-check -C "$PWD" \
  "${net_args[@]}" \
  -o "$run_dir/final.md" "$@" - < "$run_dir/brief.md" > "$run_dir/log.txt" 2>&1 || status=$?
printf '%s\n' "$status" > "$run_dir/exit_code"
printf 'Codex task %s finished with exit %s\n' "$name" "$status" >&2
exit "$status"
