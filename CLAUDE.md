@AGENTS.md

# Claude-only instructions

Codex reads `AGENTS.md` but not this file, so Claude-specific workflow lives here.

## Codex workers

Use the `cli-workers` skill (backend: codex only) to hand bounded
implementation tasks to Codex GPT-6.1-Sol workers when the user asks for
Codex/GPT workers or cost savings, or confirms it for a larger task. Its scripts
are in
`.claude/skills/cli-workers/scripts/`. Project specifics, with the reasons
behind them, are in [the Codex orchestration notes](docs/CODEX_ORCHESTRATION.md).

- Checks: workers run Flutter/Dart only through `tools/sdk_direct.sh`:
  `tools/sdk_direct.sh flutter --no-version-check test <files> --no-pub`,
  `tools/sdk_direct.sh dart format <files>`,
  `tools/sdk_direct.sh dart analyze <files>`. You rerun the full suite and
  analysis with the runbook commands in `docs/testing.md`.
- Keep with lead: version and checksum updates, `tools/build_apk.sh`, physical
  devices, starting/stopping emulators, audio generation, gcloud, and the
  handoff and validation notes.
- Network: on. Launch with `WORKER_NETWORK=1`, because `flutter test` and the
  adb client need loopback sockets. The user approved this.
- Web search: off. MCP: off, so workers don't get this project's MCP servers
  (`.codex/config.toml`) or ChatGPT apps.
- Exceptions: a worker may drive the lead-booted `LearningCornerTest` emulator
  (`emulator-5570`) with the adb client, under the rules in the orchestration
  notes. Workers never run `pub get`/`pub add` or add dependencies unless
  planned, and never edit ignored paths (`artifacts/`, `docs/screenshots/`).
