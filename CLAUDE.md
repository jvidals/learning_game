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
- Snapshot first (the workspace isn't a Git repository). Give parallel workers
  disjoint files, and keep planning, final review and validation, APK
  build/install, devices, gcloud/audio generation and the handoff notes with the
  lead session.
- Review every worker's actual diff and rerun the checks yourself before
  reporting. When reporting, say which tasks Codex did.
- Claude sub-agents must not start Codex workers unless their brief says so.
