# Codex orchestration: Learning Corner specifics

The general workflow (snapshots, briefs, launching, review), the wrapper and
its settings, and the generic brief template come from the toolkit's
`cli-workers` skill, linked at `.claude/skills/cli-workers/`. This file
records only what differs for Learning Corner, and why. It's for the lead
Claude session. Codex workers get their instructions from `AGENTS.md` and their
brief, not from here. The short version of these rules is in `CLAUDE.md`.

## Verified setup (2026-10-17, moved to the skill 2026-10-18)

| Item | Value |
| --- | --- |
| CLI | `/usr/local/bin/codex`, signed in with ChatGPT (usage counts against the user's ChatGPT plan) |
| Wrapper | `.claude/skills/cli-workers/scripts/run_worker.sh codex`, which pins `gpt-6.1-sol`, `workspace-write` and this repo. **The user's global config is `danger-full-access` with `gpt-6-astra`; never rely on it** |
| Network | Launch with `WORKER_NETWORK=1`. The skill defaults to off, but `flutter test` and the adb client need loopback sockets. The user approved network use |
| Flutter/Dart | Workers run them only through `tools/sdk_direct.sh flutter|dart ...`, which writes nothing outside the workspace and `/tmp` (see below) |

Smoke tests on 2026-10-17 passed: a read-only question (about 7 s, 5k tokens),
two parallel workers whose writes to `$HOME` failed with `Read-only file
system`, a focused `flutter test` (10 passed), `dart analyze` and
`dart format --set-exit-if-changed`. Simple tasks used 5–20k tokens; expect far
more for real implementation.

Launch example:

```bash
WORKER_NETWORK=1 .claude/skills/cli-workers/scripts/run_worker.sh codex <task> /tmp/worker-briefs/<task>.md
```

Snapshots are stored under `refs/snapshots/` and cover `assets/` and `art/`.
They don't cover the ignored `artifacts/` and `docs/screenshots/`, so workers
must not edit those.

## Emulator exception (approved 2026-10-17)

Workers never build or install APKs on physical devices, and never start or
stop emulators. The exception: the lead boots and verifies the disposable
`LearningCornerTest` AVD as `emulator-5570` (see the runbook's "Disposable test
emulator" section), and then a worker may drive it with the adb client, always
with `-s emulator-5570`: `install -r` of the project APK, `shell input`,
`screencap`, `uiautomator dump`, `am`, `dumpsys`, `logcat` and `pull`.

Workers must re-check that `adb -s emulator-5570 emu avd name` prints
`LearningCornerTest` before acting. They must never touch another serial or the
user's `Medium_Phone_API_36.1`, and never run `emu kill`, uninstall, `pm clear`,
wipe data or re-enable network. The tablet AVD (`emulator-5572`) is lead-only.
Network access must be on so the sandboxed client can reach the lead's adb
server.

## Why `tools/sdk_direct.sh`

With home read-only, the normal launchers fail in three places, and the helper
avoids each one:

- **`flutter`/`dart` launcher scripts** rewrite `bin/cache/engine.stamp` on
  every run. The helper calls the cached Dart VM and the `flutter_tools`
  snapshot directly.
- **The Flutter tool** opens `bin/cache/lockfile`. The helper sets
  `FLUTTER_ALREADY_LOCKED=true`, Flutter's own switch for nested calls. The SDK
  cache must already be populated, so the lead session handles SDK upgrades
  and precache.
- **Analytics** write under `~/.dart-tool`. The helper passes
  `--suppress-analytics`.

Since the 2026-10-18 batch, `tools/sdk_direct.sh flutter test ...` fails before running tests because the version check writes to the read-only SDK; brief workers to run `tools/sdk_direct.sh flutter --no-version-check test ... --no-pub`.

`flutter test` reads packages from `~/.pub-cache` through
`.dart_tool/package_config.json`. Reading is allowed, so use `--no-pub`.
The lead session doesn't need the helper and keeps using the runbook commands.

## Brief additions

Fill the skill's brief template with these:

- **Opening:** "You are a Codex worker on Learning Corner." Keep the template's
  line that the brief overrides `AGENTS.md` instructions to read the handoff or
  update notes.
- **Checks:** the three `tools/sdk_direct.sh` commands from `CLAUDE.md`, never
  the `flutter`/`dart` launchers.
- **Forbidden, in addition to the template:** APK builds, physical devices,
  starting/stopping emulators, any adb use beyond the emulator exception,
  gcloud, audio generation, `pub get`/`pub add`, version bumps, and
  handoff/testing-note edits.

## Troubleshooting (Flutter-specific)

See the skill's troubleshooting reference for general sandbox problems.

| Symptom | Cause and fix |
| --- | --- |
| `engine.stamp` or `bin/cache/lockfile: Read-only file system` | A worker used the `flutter`/`dart` launcher. Use `tools/sdk_direct.sh` |
| `Failed to create server socket (OS Error: Operation not permitted, errno = 1)` | Loopback is blocked. Launch with `WORKER_NETWORK=1` |
| `"libimobiledevice"/"libusbmuxd" was downloaded, but Flutter failed to update its stamp file` | Expected with the read-only SDK cache. It appears even with networking off, so nothing is downloaded. Harmless |
| adb `cannot connect to daemon` | Network is off, so the client tried to start its own server. Launch with `WORKER_NETWORK=1` after the lead has booted the emulator |
