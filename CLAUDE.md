@AGENTS.md

# Claude-only instructions

Codex reads `AGENTS.md` but not this file, so Claude-specific workflow lives here.

## Delegating to Codex workers

The lead Claude session may plan and review work, then hand bounded
implementation tasks to Codex **GPT-6.1-Sol** workers to save cost. Follow
[the Codex orchestration guide](docs/CODEX_ORCHESTRATION.md). Key rules:

- Launch workers only through `tools/codex_task.sh`. It pins the model and the
  `workspace-write` sandbox, because the user's global Codex config is
  `danger-full-access`. Never use `codex exec resume`: it can't pin the sandbox.
- Workers can write only to the workspace and `/tmp`. Their briefs must run
  Flutter/Dart only through `tools/sdk_direct.sh`.
- Snapshot first with `tools/git_snapshot.sh <task>-before` (a ref under
  `refs/snapshots/`, no commit on `main`), then review with a matching
  `-after` snapshot and `git diff`. Codex keeps `.git` read-only, so Git stays
  with the lead session. Give parallel workers disjoint files, and keep
  planning, final review and validation, APK build/install, devices,
  gcloud/audio generation and the handoff notes with the lead session. A worker may drive
  the lead-booted `LearningCornerTest` emulator (`emulator-5570`) with the adb client; see
  the orchestration guide's emulator exception.
- Review every worker's actual diff and rerun the checks yourself before
  reporting. When reporting, say which tasks Codex did.
- Claude sub-agents must not start Codex workers unless their brief says so.
