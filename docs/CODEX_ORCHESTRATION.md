# Codex orchestration (Claude plans, Codex implements)

To save cost, the lead Claude session can plan and review work, then hand
bounded implementation tasks to OpenAI Codex workers running **GPT-6.1-Sol**
through `tools/codex_task.sh`. The lead session owns planning, review,
final validation and reporting. Codex workers only implement what their brief
asks. This file is for the lead Claude session. Codex workers get their
instructions from `AGENTS.md` and their brief, not from here.

Use it when the user asks for Codex/GPT workers or cost savings, or confirms
it for a larger task. Claude sub-agents must not start Codex workers unless
their own brief says to.

## Verified setup (2026-10-17)

| Item | Value |
| --- | --- |
| CLI | `/usr/local/bin/codex`, codex-cli 0.160.1, signed in with ChatGPT (usage counts against the user's ChatGPT plan) |
| Worker model | `gpt-6.1-sol` (efforts: low, medium, high, xhigh, max, ultra). The global default `gpt-6-astra` is not used here |
| Sandbox | `workspace-write`, set explicitly. **The user's global config is `danger-full-access`; never rely on it** |
| Flutter/Dart | Workers run them only through `tools/sdk_direct.sh flutter|dart ...`, which writes nothing outside the workspace and `/tmp` (see below) |

Smoke tests run on 2026-10-17, all passing with the current wrapper settings:

- Read-only question: about 7 s and 5k tokens.
- Two parallel workers wrote and tested code in scratch directories. Their attempts to write to `$HOME` failed with `Read-only file system`.
- `tools/sdk_direct.sh flutter test test/answer_positions_test.dart --no-pub`: 10 passed. `tools/sdk_direct.sh dart analyze lib/main.dart`: no issues. About 8k tokens together.
- `dart format --set-exit-if-changed`: unchanged.
- The worker's sandbox was `[workdir, /tmp, $TMPDIR]`, with nothing under `~/` writable.
- No project source files were modified.

Simple tasks used 5–20k tokens. Expect far more for real implementation.

## What to delegate

Good fits are well-specified, file-bounded work:

- implementing a planned change in named files
- writing or extending tests
- mechanical refactors and renames
- focused bug fixes with a known cause

Keep these with the lead Claude session:

- planning and design decisions
- anything that needs the user's confirmation
- final review and the final full test and analysis run
- version and checksum updates
- `tools/build_apk.sh`, physical devices, and starting/stopping emulators
- audio generation and anything touching gcloud
- the handoff and validation notes

Workers must never run these. **Exception — emulator UI testing (approved
2026-10-17):** the lead boots and verifies the disposable `LearningCornerTest`
AVD as `emulator-5570` (see the runbook's "Disposable test emulator" section),
then a worker may drive it with the adb client, always with `-s emulator-5570`:
`install -r` of the project APK, `shell input`, `screencap`, `uiautomator dump`,
`am`, `dumpsys`, `logcat` and `pull`. Workers must re-check
`adb -s emulator-5570 emu avd name` prints `LearningCornerTest` before acting,
and must never touch another serial or the user's `Medium_Phone_API_36.1`,
`emu kill`, uninstall, `pm clear`, wipe data, or re-enable network. Keep
`CODEX_NETWORK=1` so the sandboxed client can reach the lead's adb server.

## Workflow

1. **Plan.** Read the relevant code. Split the work into tasks with
   **disjoint file sets**. Two parallel workers must never edit the same file.
   Shared files (`pubspec.yaml`, `lib/main.dart`, docs) go to one worker, or the
   lead edits them afterwards. Run 2–4 workers at a time.
2. **Snapshot.** Record the starting point without committing:

   ```bash
   tools/git_snapshot.sh <batch>-before
   ```

   This stores the whole working tree (tracked and untracked files, minus
   `.gitignore`) as a commit under `refs/snapshots/<batch>-before`. HEAD, `main`,
   the index and files are untouched, so the lead's uncommitted work and the
   user's staging are safe, and plain `git push` doesn't send snapshot refs.
   `assets/` and `art/` are covered automatically; ignored paths
   (`artifacts/`, `docs/screenshots/`) are not, and workers must not edit them.
   Workers can't write to `.git` (Codex keeps it read-only in
   `workspace-write`, verified 2026-10-17), so they can't commit or move refs.
3. **Brief.** Write one brief per task to `/tmp/codex-briefs/<task>.md`
   using the template below.
4. **Launch.** Start each worker with Bash `run_in_background: true`, one
   call per task, all in one message:

   ```bash
   tools/codex_task.sh <task-name> /tmp/codex-briefs/<task-name>.md
   ```

   Output goes to `/tmp/codex-runs/<task-name>/`: `brief.md`, `final.md` (the
   worker's report), `log.txt` (full transcript with session id) and
   `exit_code`. Wait for completion notifications. Don't poll.
5. **Review.** Read each `final.md`, then check the actual diff. Take a second
   snapshot and compare, which includes new and deleted files:

   ```bash
   tools/git_snapshot.sh <batch>-after
   git diff --stat refs/snapshots/<batch>-before refs/snapshots/<batch>-after
   git diff refs/snapshots/<batch>-before refs/snapshots/<batch>-after -- <path>
   ```

   Restore a file with `git restore --source=refs/snapshots/<batch>-before -- <path>`.
   Labels can't be reused; after review, list snapshots with
   `git for-each-ref refs/snapshots` and delete finished ones with
   `git update-ref -d refs/snapshots/<label>`. Don't trust the report alone. Check scope, the preserved behavior
   listed in `AGENTS.md`, and test quality. Then run the focused tests and the
   full suite and analysis yourself, as in `docs/testing.md`.
6. **Follow up.** For fixes, write a new brief that includes the review
   findings and run it through the wrapper again under a new task name such as
   `<task>-fix1`. **Do not use `codex exec resume`**: it has no `--sandbox`
   flag, so it would fall back to the global `danger-full-access`. Fix small
   issues directly instead of sending another round.
7. **Report.** Record actual outcomes the usual way. Name which tasks Codex
   did and which checks the lead session ran.

## Wrapper settings

`tools/codex_task.sh <task-name> <brief-file> [extra codex exec args]`. Override
with environment variables:

| Variable | Default | Notes |
| --- | --- | --- |
| `CODEX_MODEL` | `gpt-6.1-sol` | |
| `CODEX_EFFORT` | `medium` | `low` for mechanical edits, `high` for tricky game/state logic. Avoid `ultra` (cost) |
| `CODEX_NETWORK` | `1` | `flutter test` needs loopback sockets, which the sandbox allows only with network access on. The user approved network use. `0` is available for tasks that run no Flutter tests |
| `CODEX_RUN_DIR` | `/tmp/codex-runs` | |

Workers can write only to the workspace and `/tmp`. All of `$HOME` stays
read-only, including the Flutter SDK, the pub cache, and gcloud and adb
configuration. Codex itself still keeps its session logs in `~/.codex`; that is
the Codex CLI, outside the sandbox. Briefs must still forbid `pub get`/`pub add`
and new dependencies unless planned.

### Why `tools/sdk_direct.sh`

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

`flutter test` reads packages from `~/.pub-cache` through
`.dart_tool/package_config.json`. Reading is allowed, so use `--no-pub`.
The lead session doesn't need the helper and keeps using the runbook commands.

## Brief template

```markdown
You are a Codex worker on Learning Corner, delegated by a lead agent that
will review your diff. Follow AGENTS.md (already loaded). Your brief overrides
any instruction there to read the handoff or update notes.

## Goal
<one or two sentences: the outcome>

## Files you may edit
- <exact paths; create only the listed new files>
Do not edit any other file. If the task cannot be done within these files, stop
and explain why in your report instead of widening scope.

## Context
<relevant design decisions, the existing functions/classes to use, the
behavior to preserve from AGENTS.md, and the snippets you already read>

## Requirements
- <specific, checkable requirements>
- Write or update tests first in <test file>; match existing test style.

## Checks to run (only through tools/sdk_direct.sh; never the flutter/dart launchers)
- tools/sdk_direct.sh flutter test <focused test files> --no-pub
- tools/sdk_direct.sh dart format <changed dart files>
- tools/sdk_direct.sh dart analyze <changed dart files>

## Forbidden
No APK builds/installs, adb, emulators, gcloud, audio generation, pub get/add,
new dependencies, version bumps, handoff/testing-note edits, Git commands that
write (commit, stash, checkout, restore, reset), or edits outside the listed
files. Read-only `git diff`/`git status` are fine. Do not start other Codex or
agent sessions.

## Report (final message)
Files changed, a short summary per file, each check command with its exit
status and summary line, and any open questions or deviations.
```

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `engine.stamp` or `bin/cache/lockfile: Read-only file system` | A worker used the `flutter`/`dart` launcher. Use `tools/sdk_direct.sh` |
| `Failed to create server socket (OS Error: Operation not permitted, errno = 1)` | Loopback is blocked. Run with `CODEX_NETWORK=1` |
| `"libimobiledevice"/"libusbmuxd" was downloaded, but Flutter failed to update its stamp file` | Expected with the read-only SDK cache. It appears even with networking off, so nothing is downloaded. Harmless |
| `bwrap: Can't mkdir parents ... Not a directory` | A custom `writable_roots` entry is a file (for example `~/.flutter`). Don't add writable roots |
| Running `codex sandbox -c 'sandbox_mode="workspace-write"' -- <cmd>` from the workspace | Tests a command under the same sandbox without a model or tokens |
| A worker reports `.git` permission errors | Expected: `.git` is read-only for workers. Briefs must not ask workers to run Git write commands |
| Warnings about ignored `projects.*` config settings | Unrelated entries in the user's `~/.codex/config.toml`. Harmless. Don't edit that file |
