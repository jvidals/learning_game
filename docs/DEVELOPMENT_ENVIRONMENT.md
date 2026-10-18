# Local development runbook

## Workspace cleanup — 2026-10-03

Removed obsolete artwork/models/APKs, all raw animation caches and generated
project build output. Current **0.20.2+44**, bundled art/audio, editable production
source, required references and saved-data behavior are unchanged. The selected
[concept sheets and revision-five previews](../art/foal/archive/README.md) remain.
Historical source, reports and documentation screenshot galleries remain;
older claims below that binary baselines/raw caches are “preserved” describe their
original release sessions and no longer describe current disk contents.

Current cleanup checks: **30 Python tests passed with no skips**, **1,601 companion
assets** and **221 recordings** verified, exact APK inventory and checksum passed.
Retained files were fingerprinted before deletion and checked afterward. No new
Flutter build, analysis, device installation or UI validation was performed.
[Cleanup inventory, measurements and logs](../artifacts/workspace-cleanup-20261003/README.md).

Fresh art exports must render again before packing or rebuilding the item atlas;
normal builds continue to reuse bundled artwork. Only project-local caches were
cleared; host tooling, signing keys, devices, emulators and source skills were
untouched.


Recorded 2026-09-14 for `/home/jvidals/Documents/ScriptWork/learning_game`. Paths and temporary resources describe this computer; verify availability in a new session. Product behavior and current validation are in [the handoff](AGENT_HANDOFF.md).

## 0.20.2 compact uniform cards — 2026-09-19

**760 full Flutter tests passed**, plus **61 focused checks** and **16 rendered scenarios / 240 PNGs**. Extended checks assert equal heights across all five cards, original normal-text phone height with real fonts, independent actions, centered range controls at least 48×48 dp, and fitting 0–100 / 98–100 labels. Representative phone/tablet views at normal/200% text were inspected. Final formatting passed for all **3 changed Dart files**. The full suite emitted 12 nonfatal tap hit-test warnings; all tests passed. Full Flutter analysis hit the known host file-watcher limit (`errno 24`, too many open files). The documented watcher-free fallback checked **96 Dart files with zero diagnostics**; full Flutter linting remains unverified for this release. No host limits or unrelated processes were changed. Existing capture fonts under `/tmp/continuous-rounds-fonts` were reused with `SCREENSHOT_ROOT=docs/screenshots/0202`. The direct Flutter SDK, original JBR and approved build script produced the release. No device or emulator was started or installed during this release; earlier native upgrade results remain historical. Physical touch and full TalkBack exploration remain manual. Confirmed-idle project Gradle daemon 562177 was stopped after checking its last build directory. Scoped escalation was required for the existing bwrap failure; no host, SDK, cloud or source-skill settings changed. [Evidence and commands](../artifacts/compact-cards-0202/README.md).

## 0.20.1 card range placement — 2026-09-19

**61 focused Flutter tests passed** (range widgets, interface refresh and learning expansion), plus **16 rendered layout scenarios / 224 PNGs**. All four shortcuts remain within their card surfaces with touch targets at least 48 dp; existing tests cover separate semantics, normal game entry, parent-gated editing and saved range updates. Representative phone/tablet renders at normal/200% text in both themes were inspected. Both changed Dart files passed final formatting. Full `flutter analyze` hit the known host file-watcher limit (`errno 24`, too many open files). The documented watcher-free fallback checked **96 Dart files with zero diagnostics**; it does not replace full Flutter linting. No system limits or unrelated processes were changed. Captures reuse `/tmp/continuous-rounds-fonts`, with `SCREENSHOT_ROOT=docs/screenshots/0201`. Scoped escalation was needed for the existing bwrap loopback failure. The approved build reused the original JBR/signing key and bundled assets; no host, SDK, cloud or source-skill settings changed. No device was used. [Evidence and commands](../artifacts/card-range-0201/README.md).

## 0.20.0 game ranges and automatic settings — 2026-09-19

The installed Flutter/Dart SDK and approved build script with `JAVA_HOME=/usr/local/android-studio/jbr` produced 0.20.0+42, preserving the intervening 0.19.2 Home greeting. Final full tests (760), focused regressions (137), capture scenarios (16 / 224 PNGs), full analysis (0 errors/warnings, 61 informational notices) and 27-file formatting completed. Captures reuse `/tmp/continuous-rounds-fonts`; run with `--dart-define=CAPTURE_REFRESH=true --dart-define=REFRESH_FONT_DIR=/tmp/continuous-rounds-fonts` and the `range controls fit` selector. In-memory JPEG previews allowed visual inspection despite the image-viewer's bwrap failure.

Scoped escalation remains necessary for the host's bwrap loopback setup failure. No host-limit, SDK, source-skill or cloud settings changed. Confirmed-idle Gradle 8.14 daemon 438071 had this project's Android directory as its last build and was the only running matching daemon; the project wrapper stopped it. Source/APK baseline, scripts and actual logs are in [release evidence](../artifacts/number-settings-0200/README.md). No usable Git repository exists.

The existing disposable `LearningGardenWriting` AVD under `/tmp/learning-garden-writing-avd` ran headless on emulator-5560 in airplane mode. Its installed 0.19.0 upgraded directly to 0.20.0 with `tools/install_apk.sh`, preserving progress. Native checks confirmed all four independent ranges, immediate appearance/Tap Next persistence and identical Writing/2048 state; installed bytes match the release. Original System appearance, Tap Next on and sound off remain. The emulator was stopped with saves intact. Only the test range values changed (2–10 / 1–20 / 0–5 / 1–15); XP remains 560 with three gifts. No phone or user AVD was used.

## 0.19.2 Home greeting — 2026-09-19

The same direct Flutter/Dart SDK and approved build script with `JAVA_HOME=/usr/local/android-studio/jbr` produced 0.19.2+41. Full tests (726), rendered review (16 scenarios / 48 PNGs), analysis (0 errors/warnings, 48 existing informational notices) and final formatting (10 files) completed. Existing fonts under `/tmp/continuous-rounds-fonts` were reused. No tooling changes were needed; bwrap still required scoped escalation. Representative PNGs were read through an in-memory JPEG contact sheet without modifying captures. No device/cloud/SDK/source-skill changes. Gradle daemon 409472 was the only running 8.14 daemon, IDLE, with this project's Android directory as its last build; the wrapper stopped it. [Validation](testing.md), [evidence](../artifacts/home-greeting-0192/README.md).

## 0.19.1 Learning Corner rename — 2026-09-19

The approved build script now writes `artifacts/learning-corner.apk` and its SHA-256 file. The install script and `tools/verify_apk_assets.py` default to that filename; `APK_PATH` still supports an explicit alternate install file. Android application ID/activity, Dart package, signing key and storage identifiers retain their original names. The old `artifacts/learning-garden.apk` is preserved as historical 0.19.0 evidence.

Direct installed Flutter/Dart tools and `JAVA_HOME=/usr/local/android-studio/jbr` produced 0.19.1+40. Full tests (725), focused review (16 scenarios / 128 captures), full analysis (0 errors/warnings, 48 informational notices), touched formatting, five APK-verifier tests and shell syntax checks passed as recorded in [testing](testing.md). The earlier planned 0.18.3 version was advanced because 0.18.3 and 0.19.0 had already shipped in this workspace.

The same bwrap loopback startup failure required scoped escalation for reads/edits/checks/build. The normal image viewer also failed; representative PNGs were reviewed via an in-memory JPEG contact sheet without altering the source captures. Existing fonts under `/tmp/continuous-rounds-fonts` were reused. No device, cloud, SDK, system-limit or source-skill changes. Gradle showed only project daemon 394813 active, IDLE, with this project's Android directory as its last build; `android/gradlew --stop` stopped it. Evidence and reproducible review/audit scripts are in `artifacts/learning-corner-0191`.

## 0.18.3 counting icon update — 2026-09-19

The existing scoped shell escalation remains necessary because bwrap loopback setup fails. Direct Flutter/Dart tools and the approved build script worked. Nine category tests and eight visual-review scenarios passed (32 captures); full analysis completed with zero errors/warnings and 42 existing infos. Only the two production Dart files were formatted. Review PNGs use the existing font/capture helpers; the review harness is in `artifacts/counting-icons-0183/capture.dart`.

No synthesis, asset regeneration, dependency update, emulator/phone interaction or host configuration change was needed. The normal signed APK contains byte-identical bundled assets relative to 0.18.2. Baseline APK/source, validation logs and exact release verification are under `artifacts/counting-icons-0183`; see the current handoff/testing notes for checksum and counts.

## 0.19.0 continuous rounds — 2026-09-19

The existing bwrap loopback failure still prevents sandbox shell/image operations. Scoped escalation ran the authorized reads, edits, SDK checks/build and isolated-emulator work; no host limits or cloud/SDK/source-skill settings changed. The normal image viewer also failed, so rendered PNGs were inspected through in-memory JPEG contact sheets without changing the source captures.

The installed Flutter/Dart tools passed 725 tests, 64 capture scenarios, full analysis (0 errors/warnings, 48 informational notices; no watcher fallback), and 49-file formatting. Capture fonts under /tmp/continuous-rounds-fonts use the installed layoutlib Roboto font and Flutter MaterialIcons; no extra font-processing dependency was installed. Static production posters are valid screenshot content even without an animation frame. Commands and evidence are in artifacts/continuous-rounds-0190.

Approved build/install scripts produced 0.19.0+39 with the original signing key, all 1,852 content/shader files unchanged and no new dependencies. Build code 39 preserves the intervening 0.18.3+38 counting-icon release. Verified LearningGardenWriting / emulator-5560 was the only device used. Final state is Player 1, 560 XP/level 6, three gifts, muted, Tap Next on, with Writing P/p and 2048 unchanged. The emulator was stopped preserving data; Gradle daemon 337716 was confirmed IDLE with this project's Android directory before stopping it. No phone/user AVD was touched.

## 0.18.2 companion compression — 2026-09-18

`tools/compress_foal.py` benchmarks and repacks original renders into staging; it never publishes production assets. The selected recipe is WebP quality 90 / method 6 / minimize-size / mixed encoding. Pass `--webp-method 6 --minimize-size --allow-mixed` to the normal export tools for future artwork. Existing CLI defaults retain method 1 for baseline reproduction. Normal builds do not recompress.

This host used Pillow 10.2.0, libwebp 1.3.2 and NumPy 2.2.6 (authoring only). The full pass used 24 workers after a verified 21-worker checkpoint/resume, with an enforced 8 GiB available-memory reserve and roughly 577 MiB measured maximum worker RSS. Choose future worker counts from current memory and a pilot; do not assume the same free resources. Preserved historical source/manifest evidence validates the 0.14.0 raw cache after 0.17.0 action pruning without altering source stamps. Original assets, checksums, source snapshots, commands and results are in [the compression report](../artifacts/companion-compression/README.md).

All 627 Flutter and 30 Python tests passed. Full analysis completed with zero errors/warnings and 42 existing informational notices; touched Dart formatting passed. Sandbox/view-image bwrap loopback failure still required scoped command escalation; image inspection used in-memory JPEG previews of saved PNG comparisons. No host/SDK/source-skill/cloud settings changed.

`tools/profile_companion.dart` supports opt-in `FOAL_COMPRESSION_SCENARIO=true` for an isolated, save-free comparison sequence. A local Flutter wrapper passed that define through the approved `--profile-companion` build path. Baseline/candidate diagnostic APKs are clearly separated under the report's `native/` directory; the duplicate root profiling APK was removed. The final normal build rejects timing markers and uses the original signing key. It is 0.18.2+37, 661,998,532 bytes, with offline content preserved.

Verified LearningGardenWriting / emulator-5560 completed both playback runs and final normal install-r validation with saved player, Writing and 2048 state unchanged. Its original power setting was restored; it was stopped without clearing data. The final build daemon was confirmed IDLE with this project's Android directory as its last build before `./gradlew --stop`. No phone/tablet or user AVD was touched. Native timing is emulator evidence, not a physical-device benchmark.

## 0.18.1 phonics correction — 2026-09-18

Single-letter IPA SSML yielded spoken alphabet names in Chirp and Neural2. Phonics-only requests now use Gemini 2.5 Flash/Pro TTS with Puck and explicit articulation instructions; all other requests/hashes remain unchanged. `aiplatform.googleapis.com` was enabled only in the already-authorized personal project using explicit configuration/account/project flags, because Gemini TTS requires it. No active work configuration/account/project or ADC was changed. Temporary enablement-propagation 403s were resumed safely. Cloud audio review also used the explicit personal identity, on game clips only; no saves or user data were uploaded.

Held L generation sometimes ran many seconds or produced an opening vowel. The final Flash request uses a 700 ms onset-preserving duration cap and 20 ms fade (`phonics-directed-l-v3`); other clips use `phonics-directed-v2` and a three-second rejection guard. Request/model/processing and content hashes are recorded; native playback preserves the final bundled PCM. Audits/candidate scripts are authoring-only under `artifacts/learning-0181` and are excluded from the APK. Normal builds remain entirely offline.

627 Flutter / 25 Python tests, 35 focused checks with 48 captures, full analysis (0 errors/warnings; 42 infos), 92-file formatting and 221 native PCM checks passed. Same-key offline upgrade and exact installed checksum passed on LearningGardenWriting / emulator-5560; player remained 360 XP/level 4 with Writing and 2048 unchanged. Original muted setting restored, emulator stopped with data retained. Final tests/build/install logs and remaining human audio checks are in current testing notes.

## 0.18.0 Letter Sounds / Counting Garden — 2026-09-18

The normal sandbox/image viewer still failed bwrap loopback setup; scoped escalation was used. Direct Flutter/Dart and approved build/install scripts worked. 627 Flutter tests, 22 Python tests, 23 focused capture checks, and native PCM checks passed. Full analysis completed with zero errors/warnings and 42 infos; no watcher workaround. No SDK/host/source-skill settings were changed.

23 new phoneme clips were intentionally synthesized using the existing explicit personal configuration/account/project flags. No active gcloud configuration, account/project or ADC was changed. The new generator branch uses SSML IPA and `phoneme-only-v1` processing rather than the interior-gap normalizer. All 198 existing prompts remain unchanged. Human pronunciation checks remain pending; the local release listening page exposes all new clips.

Hint pictures are reproducible using `python3 tools/render_phonics_pictures.py`, Pillow and the installed Noto Color Emoji font. Normal builds need none of those authoring steps and verify bundled pictures and audio. The original font provenance/license accompanies the PNGs.

Isolated LearningGardenWriting / emulator-5560 retained its saved state during install-r validation. Three real rounds produced final 360 XP / level 4, with Writing P/p and 2048 unchanged. Parent sound selection/counting range persisted; defaults and muted sound were restored. Final installed checksum/smoke checks passed; the verified isolated emulator was stopped with its data preserved. Native automation scripts/results and source/APK baseline are under `artifacts/learning-0180`. See current testing/handoff notes for limitations.

## 0.17.0 Tap Challenge — 2026-09-18

Sandbox commands still fail bwrap loopback setup; scoped command escalation was used. The installed Flutter SDK completed full analysis (zero errors/warnings, 41 infos), all 577 tests, 24 final capture scenarios and normal APK packaging. Python checks passed. No host limits, cloud configuration, dependencies or source skills changed.

Adventure-only assets were pruned without rerendering retained clips; active spec/rig/export contracts and the manifest source hash were updated. Exact byte comparison proves 1,802 retained content/shader files unchanged. Baseline/retired assets and source archive are under `artifacts/tap-challenge-0170/baseline/`. Native validation uses only verified LearningGardenWriting / emulator-5560 under the existing `/tmp/learning-garden-writing-avd`, upgraded with the approved install-r script. The emulator and confirmed-idle Gradle daemon 3619915 were stopped with data preserved. Final fixture: Player 1, 210 XP, Tap Challenge best 58, muted sound, Writing P/p and unchanged 2048 board. See current handoff/testing for results and remaining physical checks.

## 0.15.3 activity icons — 2026-09-18

Direct installed Flutter/Dart tools and `tools/build_apk.sh` produced the
same-key 0.15.3+32 APK. 509 existing tests and 16 visual capture scenarios passed;
64 screenshots are in the [icon gallery](screenshots/0153/README.md).
Full `flutter analyze` completed this session with zero errors/warnings and
45 pre-existing informational style notices (exit 1). The watcher limitation
below did not recur, and no fallback or host adjustment was needed.

The bwrap loopback startup error still affects normal shell, patch and image
viewer tools. Scoped escalated commands performed the authorized file edits,
checks/build and screenshot reads. No source skills, cloud settings, SDK,
phones or emulator state changed. No native installation was performed.
[Actual validation](testing.md), [release evidence](../artifacts/icons-0153/).

## 0.16.0 tablet layout — 2026-09-18

Built with `FLUTTER_BIN=/home/jvidals/snap/flutter/common/flutter/bin/flutter`
and `JAVA_HOME=/usr/local/android-studio/jbr` through `tools/build_apk.sh`.
543 full Flutter tests and 50 separate capture/check scenarios passed. Full
analysis completed with no errors/warnings and the same 45 existing style infos
as 0.15.3 (exit 1); no watcher fallback. Formatting passed. Approved packaging
and `artifacts/tablet-0160/verify_release.py` verified same-key 0.16.0+33,
API/offline permissions and all 2,064 unchanged content/shader files.

The normal sandbox/image reader still fails its bwrap loopback setup; scoped
command escalation was used without changing host settings. Existing screenshots
were read through base64, with in-memory JPEG previews only when original image
output exceeded tool limits; saved PNG evidence is unchanged. No cloud calls,
asset generation, SDK/skill edits or device/AVD interaction occurred. Baseline
APK is a hard link preserved safely before the build script's atomic replacement.
[Validation](testing.md), [gallery/reproduction](screenshots/0160/README.md).

## 0.15.2 audio startup — 2026-09-18

Approved build script produced 0.15.2+31 with the existing signing key and unchanged
bundled assets. 509 Flutter tests passed; full analysis hit watcher errno 24 and
the fallback checked 85 Dart files with zero diagnostics (not full linting).
The new dependency-free native check runs with
`JAVA_HOME=/usr/local/android-studio/jbr tools/test_prompt_audio.sh`: Gradle compiles
the Kotlin test entry point offline, then Java executes it with the existing
Kotlin standard library. It verified all 205 recordings and nine rejected formats.
No new dependencies, synthesis or host setting changes. Logs are in
`artifacts/audio-startup-0152/`; [validation and limitations](testing.md).

Native tests used only the existing LearningGardenWriting AVD on verified
emulator-5560, with airplane mode enabled. Approved install-r upgrade retained
visible Player 1/160 XP/two moves; sound was turned on for playback checks and
restored off before restart. All five games decoded initial/replay audio and
released their player on Back. Installed checksum matched. Emulator stopped with
data preserved; daemon 3343636 was confirmed IDLE with this project's android
build directory before the wrapper stopped it. No phone/user AVD was touched.

## 0.15.1 alphabet picker — 2026-09-18

Approved scripts built 0.15.1+30 and upgraded the isolated LearningGardenWriting
AVD on emulator-5560 with install -r. Its existing 160 XP/two moves/Writing P state
survived selection/shuffle/restart checks. Temporary 1280×2856 / 480 dpi overrides
and Android dark mode were restored to 1080×1920 / 420 dpi / night no afterward.
The emulator was stopped preserving data. Build daemon 3214030 was verified IDLE
and its build directory matched this project before the wrapper stopped it.
495 Flutter tests and 20 separate capture cases passed. Host watcher errno 24
still blocks full analysis; fallback checked 87 files with zero diagnostics.
No host limits, unrelated processes, cloud settings, dependencies or assets changed.
[Current verification](testing.md), [native evidence](../artifacts/picker-0151/native/).

## 0.15.0 AMOLED appearance — 2026-09-18

The approved build/install scripts produced 0.15.0+29 with the existing debug
certificate, normal entrypoint and bundled assets. All 475 Flutter tests passed;
16 capture scenarios produced 368 screenshots, and the final focused 15-test
appearance run passed. The Writing button contrast check waits for the first
rebuild and then the enabled-state text animation before sampling final colors.
No production fix was needed for that capture-timing issue.

Full Flutter analysis hit the existing watcher limit (errno 24). The final
watcher-free fallback checked 86 Dart files with zero diagnostics, which is not
a full Flutter lint pass. Formatting passed. The broken bwrap loopback setup
required scoped command escalation; no host limits or unrelated processes changed.
No asset generation, network permission, dependency or cloud configuration changes.

Verified **LearningGardenWriting / emulator-5560** upgraded offline with install -r.
System/Light/Dark saves, live Android changes and override persistence across
restart passed. Original Player 1, 160 XP, two moves, muted sound and Writing P
(letter 2, one completed pair) were preserved. Final appearance is System and
Android night mode is restored to its original no setting. The installed checksum
matches the distributable. No phone or user AVD was used. The task emulator was
stopped with its data preserved. Gradle daemon 3129308 was confirmed IDLE and its
build directory matched this project before the existing wrapper stopped it.
[Current validation and checksum](testing.md), [design reference](dark_mode.md).

## 0.14.0 reward export and combined release — 2026-09-17

The approved build/install scripts produced 0.14.0+28 with the existing signing
key. All 444 combined Flutter tests, 19 Python tests, 16 final UI gallery tests
and the explicit renderer review passed. Complete art/provenance, 1,200 sampled
poses, exact APK inventory and unchanged audio/scenery passed. Current artifact,
checksum and limitations are in [testing](testing.md).

Direct **/usr/bin/blender 4.0.2** works with the current NVIDIA **580.178.04**
driver. The older process-local wrapper pinned to 580.173.02 failed EGL; no
driver/system setting was changed. Software fallback was also checked.
The exporter defaults to one Blender, two CPU threads, one packing worker and
an 8 GiB available-RAM stop threshold. Always stage outside assets and publish
only a fully verified library. [Authoring commands](../art/foal/README.md).

The full export retained one Blender throughout (peak RSS 5.97 GiB; group
6.17 GiB). Concurrent Writing build/emulator work lowered available RAM below
8 GiB, so only the export group stopped. Completed frames were reused after
at least 18 GiB became available. Later the user explicitly authorized available
overnight resources; the remaining export used eight CPU threads/four pack
workers, retaining the same stop guard. GPU headroom favored one Blender.
Task-private continuation scripts/logs in artifacts/rewards-0140 are historical
and have finished; do not launch them again against the published library.

Verified **LearningGardenWriting / emulator-5560**, under
/tmp/learning-garden-writing-avd, upgraded offline from 0.13.0+26 using install -r.
Saved fixture now has Player 1, **160 XP, two moves, blue mane and pink polish,
zero unclaimed choices, muted sound, Writing P at letter 2 with one completed
pair**. No polish/removal and independent mane/polish survived restart; the
installed APK checksum matches the distributable. The newer WritingRefresh
AVD on port 5562, the user's AVD and phones were not used by this release.
The task emulator was stopped with data preserved. Gradle PID 2770684 reported
IDLE, its build directory matched this project, and the existing wrapper with
JAVA_HOME=/usr/local/android-studio/jbr stopped it.

Full Flutter analysis still hit watcher errno 24 on the final retry after tools
stopped. /tmp/rainbow-analyzer checked 83 Dart files with zero diagnostics; it is
not a complete Flutter lint pass. Formatting passed for 83 files. The broken
bwrap helper required scoped command escalation; no host limits, cloud config,
credentials, source skills or unrelated processes were changed.

## 0.13.1 2048 palette — 2026-09-17

The approved script built 0.13.1+27 using the existing signing key. All 424 Flutter
tests and all 32 2048 capture tests passed. Full analysis hit the host watcher
limit; `/tmp/rainbow-analyzer` checked 77 Dart files with zero diagnostics,
not a complete lint pass. Formatting, 205 recording and 1,185 companion asset
checks passed. All 1,398 packaged content/shader files match 0.13.0. No device
was started or installed. The build's Gradle daemon reported IDLE and was stopped
with the existing wrapper/JAVA_HOME command. Logs are `/tmp/learning-0131-*`.

## Writing refresh preview — 2026-09-17

Concurrent reward art export was left alone. Native validation used a separate
snapshot `/tmp/learning-writing-refresh-preview`, based on the preserved complete
0.13.1 source/art plus the three Writing source changes. Approved build/install
scripts produced `artifacts/learning-garden-writing-preview.apk` (0.13.2+27).
The main APK and main pubspec were unchanged. Build code 27 is deliberately
retained for the preview, leaving the planned 0.14.0+28 upgrade available.

A fresh isolated **WritingRefresh** AVD under `/tmp/learning-writing-refresh-avd`
used port 5562 / verified `emulator-5562`, 2 cores, 2048 MB and software graphics.
Native tests set `wm size 1280x2856` and `wm density 480`, with airplane mode on
and Wi-Fi/data off before installing 0.13.1, then updating to the preview using
`install -r`. Saved test state is Player 1, 20 XP, sound off, completed S/s and
D/d at Writing index 1. It was stopped with data preserved; existing Writing
AVD, user's AVD and phones were untouched. The exclusively snapshot-owned idle
Gradle daemon was also stopped. Export and watchdog processes were not touched.

Full Flutter analysis hit errno 24; fallback analyzed 80 Dart files without
diagnostics. No host limits, cloud settings, unrelated processes or source
skills changed. Native helper in `artifacts/writing-refresh/native/` is a
session-specific diagnostic, not a reusable test fixture. Verify AVD identity
and state before reuse. [Evidence](../artifacts/writing-refresh/PREVIEW.md).

## 0.13.0 isolated Writing emulator — 2026-09-17

The prior `/tmp/rainbow-avd` was absent. A new **LearningGardenWriting** AVD was
created under `/tmp/learning-garden-writing-avd/` using the installed API 36.1
Google Play x86_64 system image. The user's `Medium_Phone_API_36.1` is untouched.
This AVD uses 2 cores, 2048 MB RAM, software graphics, 1080×1920 at density 420.
The session verified `emulator-5560` / `LearningGardenWriting` before interaction.
Restart if this temporary directory still exists:

```bash
ANDROID_AVD_HOME=/tmp/learning-garden-writing-avd   "$HOME/Android/Sdk/emulator/emulator" -avd LearningGardenWriting   -port 5560 -no-window -no-audio -no-snapshot -gpu swiftshader_indirect
```

Native checks used airplane mode with Wi-Fi/data disabled and normal release
APKs only. The preserved 0.12.2 baseline is
`artifacts/writing-0130/baseline-0122.apk`; approved `install -r` upgraded to
0.13.0. No fixture injection/uninstall or phone interaction. Final saved fixture
is Player 1, 60 XP, one move/reward choice, sound off and shuffled Writing index 1
(P, following credited C/c). Screenshots/XML and native helper are in
`artifacts/writing-0130/native/`. The helper is a session-specific diagnostic;
verify the AVD/state before reuse. `/tmp` is not durable storage.

Full Flutter analysis again hit errno 24; `/tmp/rainbow-analyzer` checked 77 Dart
files with zero diagnostics. This is not a full Flutter lint pass. The sandbox
helper failed with `bwrap: loopback: Failed RTM_NEWADDR`; scoped shell/SDK/ADB
commands used normal escalation. No system limits, unrelated processes, cloud
configuration or source skills changed. See [current validation](testing.md).

The final installed APK hash matches the distributable. Trace-only native input
left Check disabled. The disposable emulator was stopped after verification,
preserving its data; the confirmed-idle build daemon was also stopped (none
remain running). The user's AVD and unrelated processes were untouched.

## Codex workers (2026-10-17)

The toolkit's `cli-workers` skill (linked at `.claude/skills/cli-workers/`
since 2026-10-18) runs `codex exec` (`gpt-6.1-sol`) through its
`scripts/run_worker.sh codex` with an explicit `workspace-write` sandbox. The user's global
`~/.codex/config.toml` sets `danger-full-access`, so every run must override it.
Do not edit that file. Workers can write only to the workspace and `/tmp`;
nothing under `~/` is writable. They run Flutter and Dart through
`tools/sdk_direct.sh`, which bypasses the launcher scripts' SDK-cache writes,
the cache lockfile and analytics. `flutter test` needs network access enabled
because it uses loopback sockets, and the skill defaults to off, so launch with
`WORKER_NETWORK=1`. Smoke tests passed: a focused `flutter test`,
`dart analyze`/`format`, parallel runs, and denial of writes outside the
workspace. Workflow, brief template and
troubleshooting: [Codex orchestration](CODEX_ORCHESTRATION.md).

## Secret scanning (gitleaks pre-commit hook)

Added 2026-10-17. `tools/git-hooks/pre-commit` runs
`gitleaks git --pre-commit --staged --redact` and blocks the commit on a finding
or when gitleaks is missing (fail closed). Output is redacted, so secrets don't
reach terminals or agent transcripts. Codex workers never commit (`.git` is
read-only for them), so the hook covers the user's and the lead session's commits.

Enable once per clone (stored in `.git/config`, not committed):

```bash
git config core.hooksPath tools/git-hooks
```

gitleaks **8.30.1** is installed at `~/.local/bin/gitleaks` from the official
release, SHA-256 verified against the release checksums. Ubuntu's apt package
(8.16.0) is too old. To install or upgrade, set `v` to the wanted release:

```bash
v=8.30.1; d=$(mktemp -d); cd "$d"
curl -fsSLO "https://github.com/gitleaks/gitleaks/releases/download/v$v/gitleaks_${v}_linux_x64.tar.gz"
curl -fsSLO "https://github.com/gitleaks/gitleaks/releases/download/v$v/gitleaks_${v}_checksums.txt"
grep " gitleaks_${v}_linux_x64.tar.gz$" "gitleaks_${v}_checksums.txt" | sha256sum -c -
tar -xzf "gitleaks_${v}_linux_x64.tar.gz" gitleaks && install -m 0755 gitleaks ~/.local/bin/gitleaks
cd - && rm -rf "$d"
```

Full checks: `gitleaks git --redact .` scans every ref (including
`refs/snapshots/*`); `gitleaks dir --redact .` also reads ignored paths. On
2026-10-17 history was clean. The directory scan's only matches were signing
certificate fingerprints in ignored `artifacts/*/logs/*certificate.log`, which
are public digests, not secrets. Hook tests: `tools/test_git_hooks.py`.

Don't bypass with `git commit --no-verify` or add a `.gitleaksignore`/allowlist
without the user's explicit approval.

## Project MCP servers (Claude Code and Codex)

Only Claude Code and Codex are used in this workspace. Since 2026-10-17 both share
one server set, declared twice because the formats differ: `.mcp.json` (Claude)
and `.codex/config.toml` (Codex). Edit both together.

| Server | Purpose | Claude | Codex |
| --- | --- | --- | --- |
| `google-design` | Material color/design tooling | `.mcp.json` | project config |
| `google-developer-knowledge` | Official Google/Flutter docs search | `.mcp.json` (`headersHelper`) | project config (`http_headers_helper`) |
| `dart` | Dart/Flutter analysis, tests, pub.dev | `.mcp.json` | project config |
| `playwright` | Browser automation | `.mcp.json` | project config |
| `context7` | Library docs | user config (holds API key) | user config; forwards `CONTEXT7_API_KEY` if exported |

Claude asks for approval of new `.mcp.json` servers on first launch (`/mcp`).
context7 is the only global server in either tool; work-only servers such as
ZohoMCP are scoped to their own project, so nothing else should appear here.
Verified 2026-10-17: `codex mcp list` (codex-cli 0.160.1) and `claude mcp list`
(2.1.302) both showed exactly these five; all five Claude servers connected.
Skills are shared the same way: `.agent-skills` drives both `.agents/skills/`
(Codex) and `.claude/skills/` (Claude).

The Google servers were added 2026-09-14 in `.codex/config.toml`, verified with
Codex CLI **0.154.0**. These are development tools; the game and APK remain
offline and unchanged.

- `google-design`: `https://design.googleapis.com/mcp`, no credentials. A live
  `generate_color_scheme` call succeeded without authentication.
- `google-developer-knowledge`: `https://developerknowledge.googleapis.com/mcp`.
  The Developer Knowledge API was enabled in the personal project for this
  setup. `tools/google_knowledge_headers.py` supplies a short-lived OAuth token
  from the existing personal gcloud sign-in and the explicit personal quota
  project, both read from the local identity file below. Every gcloud invocation pins configuration, account and project.
  The active work configuration and ADC were not changed; no API key was created.

The helper uses only Python's standard library and `/usr/bin/gcloud`. Its stdout
contains an Authorization header: do not run it directly in logged terminals or
redirect its output into the repository. Codex consumes it via
`http_headers_helper` and Claude via `headersHelper`; credentials stay in the existing external gcloud store.
Codex refreshes helper headers after an authentication failure. If personal login
expires, use the refresh command in [Personal Google Cloud account](#personal-google-cloud-account).

Restart/reload Codex in this trusted workspace to load the servers. Use `/mcp`
to check connection status or `codex mcp get google-design` and
`codex mcp get google-developer-knowledge` to inspect configuration. The helper
path is absolute for this computer; update it if moving the project. Project
configuration is TOML, following the [Codex MCP documentation](https://learn.chatgpt.com/docs/extend/mcp?surface=cli),
even though Google's Developer Knowledge guide currently shows a JSON example.

Validation in this setup session: both project entries loaded through
`codex mcp get --json`; both endpoints completed MCP initialization; Design
generated a palette and Developer Knowledge returned official Flutter search
results using the configured helper. Both entries were absent when queried from
`/tmp`, confirming workspace scope. This checks live endpoints and config
loading; the current chat's tool list is not hot-reloaded. No Flutter tests,
build, installation or device interaction was needed for this tooling change.

## Tools and routine commands

| Tool | Installed baseline / path |
| --- | --- |
| Flutter | 3.38.7; `/home/jvidals/snap/flutter/common/flutter/bin/flutter` |
| Dart | 3.10.7; adjacent `bin/dart` |
| Direct Dart VM | `/home/jvidals/snap/flutter/common/flutter/bin/cache/dart-sdk/bin/dart` |
| Java | 17 |
| Android SDK | `/home/jvidals/Android/Sdk` |
| adb | `platform-tools/adb` under the SDK; 1.0.41, platform-tools 36.0.2-14143358 |
| Installed build-tools | 36.1.0 and 35.0.0; do not assume a `36.0.0` directory exists |

Run from the project root:

```bash
export FLUTTER_BIN="$HOME/snap/flutter/common/flutter/bin/flutter"
export ADB_BIN="$HOME/Android/Sdk/platform-tools/adb"

"$FLUTTER_BIN" pub get
"$HOME/snap/flutter/common/flutter/bin/dart" format lib test
"$FLUTTER_BIN" analyze
"$FLUTTER_BIN" test --reporter expanded
python3 -m unittest discover -s tools -p 'test_*.py'
python3 tools/generate_audio.py --verify

./tools/build_apk.sh
sha256sum -c artifacts/learning-corner.apk.sha256
"$ADB_BIN" devices -l
./tools/install_apk.sh PHONE_SERIAL
```

Replace `PHONE_SERIAL` with the chosen device's actual serial. The install script uses `install -r` and starts the activity. With exactly one connected device, the serial argument can be omitted. See [ADB_INFO.md](../ADB_INFO.md) for USB debugging, authorization, troubleshooting, and manual commands.

The build script verifies bundled audio, runs pub get, builds a universal release-mode APK, copies it into `artifacts/`, and writes its SHA-256 file. It does not generate speech or contact Google TTS. Development dependency resolution may need network access; the installed app does not.

The `/snap/bin/flutter` launcher failed in the prior agent environment; the explicit SDK path worked. SDK/cache writes and local adb/emulator access may need the execution environment's permission escalation. Use the applicable tool approval mechanism for necessary authorized commands; do not silently alter host configuration. `flutter doctor` reported missing Android command-line tools and unknown license status, but APK builds succeeded.

## 0.11.1 2048 popup verification

The approved build script produced 0.11.1+22 with the existing signing key. All 339 Flutter tests passed, as did all 30 2048 widget tests with captures. Full analysis completed with zero errors/warnings and 27 informational style notices (exit 1); no fallback needed. Formatting, 205 recordings and 1,185 foal asset checks passed. All 1,398 bundled content/shader files match 0.11.0. No device was started or installed for this UI patch. Gradle reported IDLE after the build and was stopped with the existing `JAVA_HOME=/usr/local/android-studio/jbr` wrapper command, preserving the user's memory-cleanup preference.

## 0.11.0 profile verification

The approved scripts built 0.11.0+21 and installed it with `install -r` on verified
**emulator-5554 / RainbowGarden**, upgraded from 0.10.0 while offline. The same
signing certificate, package/API bounds and all 1,398 bundled content files were
verified against the preserved 0.10.1 APK at `/tmp/learning-profiles-baseline.apk`.
334 Flutter tests, 15 profile widget tests with captures, and 10 Python tooling
tests passed. Full analysis completed with zero errors/warnings and 27 style
notices; no watcher workaround or system change was needed.

The sandbox helper still fails with `bwrap: loopback: Failed RTM_NEWADDR`.
Scoped shell commands used normal escalation; source skills and host limits were
unchanged. `/tmp/learning-profiles-*.log` and the serial-checked
`/tmp/learning_profiles_native.py` record this session; the helper assumes the
disposable emulator and must not be used against a phone. See [testing](testing.md)
for the exact native checks and final saved state.

After native checks, host-GPU emulation logged OpenGL synchronization errors and a
QEMU main-loop hang, then exited 139. Reopening the same disposable AVD with
`-gpu swiftshader_indirect` verified the durable final Player 1 save, settings and
2048 board; it was then stopped cleanly with `adb emu kill`. No data wipe, user-AVD
change or persistent GPU configuration edit was used. Gradle was confirmed idle
and stopped with `JAVA_HOME=/usr/local/android-studio/jbr android/gradlew --stop`.

## 0.10.1 word-layout verification

The approved build script produced 0.10.1+20 with the normal entrypoint and existing signing key. All 305 Flutter tests passed; 20 Sight Words widget tests also passed with 16 captures at four sizes and normal/200% text. Full Flutter analysis completed this session with no errors/warnings and 27 informational style notices; no watcher fallback was needed. All 1,398 packaged content/shader files match 0.10.0 byte for byte. The build verified 205 recordings and 1,185 foal assets without regeneration. No device was started or installed to for this layout-only change; the disposable emulator remains on 0.10.0. Gradle was confirmed idle and stopped after the APK checks. See the [current testing notes](testing.md) and [gallery](screenshots/0101/README.md).

## Idle build-tool memory

The user requested idle development tools be stopped to free RAM (2026-09-15). The Gradle 8.14 daemon and its Kotlin compiler used Android Studio's bundled Java, holding approximately 2.35 GiB and 0.69 GiB RSS respectively. Gradle reported IDLE and its last build belonged to this project. Running the following stopped both processes cleanly:

```bash
cd /home/jvidals/Documents/ScriptWork/learning_game/android
./gradlew --status
./gradlew --stop
```

System available memory increased from 20.04 to 22.72 GiB during cleanup (other applications can affect this measurement). No Gradle/Kotlin daemon, Android Studio IDE or emulator process remained. Editors, active language servers and unrelated applications were left running. No SDKs, caches, signing keys, AVD data or configuration were removed or disabled.

Future builds start the required daemons automatically; no re-enabling step is needed. After development work, verify jobs are idle before stopping daemons. `--stop` affects daemons of this Gradle version, so check for other active builds first. Start emulators only for necessary device checks and stop project-owned disposable emulators afterward, preserving their saved data.

## Playful Spark authoring and validation (0.10.0)

The same installed Blender/Flutter/Android tools built the updated model and
same-key 0.10.0+19 APK. The original C concept was recovered from the earlier
session's generated-image folder and copied into `art/foal/references/`.
Previous model/source/APK backups are under `artifacts/playful-spark/baseline/`.
The source's compact rest sculpt must snapshot all connected bone endpoints
before editing: Blender otherwise moves child joints before they are mapped.
The saved-model validator now checks this along with grounded idle, movement
bounds and loop velocity. See [authoring notes](../art/foal/README.md).

The explicit session export runner used four disjoint outfit workers and one
final `--index-only` publication. All 16,848 rendered frames retain at least
60 pixels of transparent camera margin. Final APK: 750,762,503 bytes, 1,185
foal assets and 205 recordings. No runtime/render format changes or new
dependencies were needed. Normal builds still verify rather than regenerate.

Both full analyzer attempts hit the existing watcher limit, including after
stopping the disposable emulator and confirmed idle build daemons. The final
watcher-free fallback checked 64 files with zero diagnostics; it is not full
Flutter linting. The tool sandbox launcher also failed with `bwrap: loopback:
Failed RTM_NEWADDR: Operation not permitted`; approved execution outside that
launcher was used. No host limits, source skills or unrelated processes changed.

Two minutes of release-mode emulator idle measured 57–60 fps engine cadence
(median 60), 35 MiB peak managed images and occasional 133 ms frame intervals.
These are not physical Pixel results. The final normal APK replaced the
profiling candidate, passed offline in-place upgrade checks and is marker-free.
The disposable emulator is stopped on 0.10.0+19 with its previous progress,
settings, equipment and 2048 board retained. Idle Gradle/Kotlin daemons are off.
Actual logs and limits: [testing notes](testing.md).

## Rigged companion authoring (0.9.0)

The user installed Blender through apt: `/usr/bin/blender`, version 4.0.2
(`4.0.2+dfsg-1ubuntu8`). Background EEVEE rendering works with the host graphics
context. This package lacks OpenImageDenoiser support; do not enable Cycles
denoising without checking the installed build. No Blender download or host
configuration change is required. Python/Pillow/libwebp are development-only.

The [editable source instructions](../art/foal/README.md) cover rebuilding the
scene, read-only rig validation, explicit full exports, and visual review.
`tools/build_apk.sh` verifies both audio and the existing foal export before
building; it never renders or synthesizes content. Full exports are substantial
jobs. Preserve raw frame caches when resuming, and never run two renders against
the same outfit/clip directory. Partial outfit exports do not publish the final
manifest. Tests require a complete export, but do not regenerate it.

`tools/verify_apk_assets.py APK --baseline PREVIOUS_APK` checks all current
recording/foal hashes, uncompressed WAVs, unchanged prior audio/scenery, absence
of old companion atlases and source files, and absence of the profiling marker.
Use Android build-tools separately for version, permissions and certificate
verification. The optional timing entrypoint now also reports managed decoded
image bytes; its numbers do not include Flutter's internal codec/GPU caches.
Never distribute the timing build. A final normal scripted build must follow it.

The completed 0.9.0+18 normal APK is 868,660,843 bytes, with 1,185 companion
image/clip assets and 205 recordings. Final APK verification, in-place emulator
upgrade, 295 Flutter tests, ten Python tests and full analysis (zero
errors/warnings, 27 style infos) completed. The full analyzer initially hit the
known watcher limit, then succeeded after stopping this task's disposable AVD
and confirmed idle Gradle daemon. Do not change host limits as a workaround.

Timing now reports vsync intervals/engine cadence separately from raster and
total latency. Quiet emulator windows were approximately 60 fps with 27 MiB
managed decoded images (observed peak 35 MiB, cap 64 MiB); host-loaded windows
had spikes. Do not infer device FPS from raster duration or claim physical
Pixel validation. The normal deliverable is marker-free. Evidence is under
`artifacts/foal-3d`; the roughly 26 GB raw frame cache is resumable authoring
output, not an APK input. Preserve it unless cleanup is explicitly requested.

## Sight Words isolated validation (historical checkpoint, 2026-09-15)

The following was the other session's interim state. The combined release
above resolves these asset/test blockers and replaces the distributable.

Sight Words source is 0.9.0+18. The user confirmed a separate companion-renderer session and requested leaving it untouched. Its incomplete assets/old export tests prevent a validated combined release. The distributable artifact remains 0.8.2+17 with its existing checksum.

A source snapshot under `/tmp/learning-090-native-build` was built using its copy of `tools/build_apk.sh` with the explicit local Flutter path. The native-only candidate used version 0.9.0+17 so 0.8.2+17 could be restored using `install -r`, avoiding uninstall or a version downgrade. Its SHA-256 is `1a163234470911ef0a3a5317e9c3d72704ef561b8c3034a8957a45b54c10f6a4`; it is not for distribution. Candidate snapshot/hash metadata stays under `/tmp`, and the original project artifact was preserved.

On verified RainbowGarden / emulator-5554 with airplane mode on and Wi-Fi/data off, word prompts, explicit hints, pack validation and save/reload/Back discard passed. The existing 0.8.2 APK was restored with the approved install script, its installed hash verified, original unicorn rendered, and previous XP/range/moves/2048 retained. Pack 1 and sound-off were restored before cleanup. The disposable emulator and confirmed-idle build daemon were stopped. The personal gcloud flags from this runbook generated only the 43 word recordings; all 162 prior recordings remained unchanged. No work configuration/account/project or ADC was changed.

122 feature/recognition/settings Flutter tests, seven generator tests, all 205 recording checks and formatting of 14 touched Dart files passed. Full workspace checks remain limited by the separate companion work, as detailed in [testing notes](testing.md). Sandbox shell/image reads again needed normal escalation after the host's bwrap loopback error; no host settings or unrelated processes were altered.

## 0.8.2 2048 layout verification

The approved build script produced 0.8.2+17 with the existing signing key. All 248 Flutter tests passed; the 25 2048 widget tests also passed with captures enabled. Full analysis completed with zero errors/warnings and 36 informational style notices (exit 1), so no fallback was needed. Formatting and 162 recording checks passed. All 177 bundled content/shader files match 0.8.1. No device installation or native checks were run; the disposable emulator remains stopped on 0.8.1. This session's shell/file-image sandbox helper failed with `bwrap: loopback: Failed RTM_NEWADDR`; approved shell escalation was used without changing host settings.

## 0.8.1 sound verification

The approved scripts built and installed 0.8.1+16 with the existing signing key. All 247 Flutter tests and six generator tests passed; 162 recordings verified. All 177 bundled content/shader files match 0.8.0, and the installed APK hash matches the artifact. Initial full analysis completed with no errors/warnings and 37 style notices; a rerun after the final home audio guard hit the host watcher limit. The fallback checked 57 Dart files with zero diagnostics, not a full final lint pass.

The execution sandbox failed even read-only shell calls with `bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted`; scoped SDK, filesystem, build and emulator commands used normal tool escalation. No host settings or source skill repositories changed. Only the existing disposable `/tmp/rainbow-avd/RainbowGarden` emulator was used, after serial/name verification. Native helper and logs are `/tmp/learning_081_native*.py` and `/tmp/learning-081-*`; these are session evidence, not scripts to run against an arbitrary device. The emulator is stopped with 2850 XP, seven moves, range 0–20, original equipment and the 2048 board preserved; shared sound is now saved off. See [testing](testing.md) for release checks.

## 0.8.0 Gentle foal verification

The approved scripts built and installed 0.8.0+15 with the existing signing key. All 231 Flutter tests and six generator tests passed; 162 recordings verified. Full analysis again hit the host watcher limit, while the documented fallback checked 55 Dart files with zero diagnostics. Targeted Dart MCP analysis also reported no errors. The final APK matches installed bytes and retains all 166 audio/scenery files. The verified disposable RainbowGarden emulator is stopped with the previous XP, moves, equipment, settings and 2048 board preserved. See [testing](testing.md) and the [gallery](screenshots/080/README.md).

`tools/profile_companion.dart` is an optional local alternate entrypoint using Flutter frame-timing callbacks, with 120 warmup frames and 180-frame sample windows. It is not used by normal builds. This session passed a temporary `FLUTTER_BIN` wrapper to `tools/build_apk.sh`; the wrapper forwarded normal commands and added `--target=tools/profile_companion.dart` only to `build apk`. Profiling used the same release mode and signing key on the disposable emulator. A final normal `tools/build_apk.sh`/`tools/install_apk.sh` restored the deliverable; verification confirmed `FOAL_TIMING` absent from the shipped app library. Do not ship the timing build or leave it in artifacts. Raw windows are preserved in `artifacts/gentle-foal/timing-samples.json`.

The generated image cache is bounded at 35,370,960 decoded bytes. A measured repaint issue in customization was fixed by isolating the live companion and drawing static portraits without skinning. Short repeated-outfit memory samples stabilized; physical Pixel performance remains unverified. Native helper/logs at `/tmp/learning_foal_native.py` and `/tmp/learning-foal-*` are session evidence, not blind reusable device scripts.

## 0.7.0 2048 verification

The approved scripts built and installed 0.7.0+14 on verified disposable emulator-5554 / RainbowGarden. All 217 Flutter tests and six generator tests passed; 162 recordings verified. The complete new widget suite also generated the 0.7.0 gallery at five screen sizes and normal/200% text. Full analysis again hit the host watcher limit; the documented fallback checked 49 Dart files with zero diagnostics. Direct Dart formatting initially needed telemetry write access; successful final checks used normal tool escalation, without changing SDK/host settings. The final APK retains the signing key, offline permissions and all 166 audio/scenery asset bytes.

Native checks used the existing disposable AVD with airplane mode on and Wi-Fi/data off. The connected Pixel 7 and the user's Medium_Phone_API_36.1 were untouched. No debug APK, fixture injection or whole-progress reset was needed. The stopped emulator retains 2850 XP and a fresh 2048 board at score 0/high score 132. See testing.md for exact saved-game/score results and remaining physical-device checks. Session-specific helpers/logs under /tmp/learning_2048_* and /tmp/learning-2048-* assume that emulator and should not be run blindly.

## File-watcher limitation and analysis fallback

**0.6.2 update:** all 169 Flutter tests and six generator tests passed; 162 recordings verified and all packaged audio/scenery bytes match 0.6.1. Full analysis again failed at the host watcher limit; the fallback checked 44 Dart files with zero diagnostics. Formatting, build/checksum, same signing key and offline in-place emulator upgrade passed. The verified disposable RainbowGarden AVD now has 2850 XP after one completed matching round and was stopped. Native validation evidence is in `/tmp/learning-062-*`; screenshots and actual outcomes are in [testing notes](testing.md). SDK/cache/telemetry and ADB access used normal tool escalation. No physical phone, host limits, unrelated processes, cloud configuration or source skills were changed.

**0.6.1 update:** full Flutter analysis again crashed with inotify errno 24 / “Too many open files.” The existing watcher-free fallback checked 45 Dart files with zero diagnostics; full linting was not completed. All 164 Flutter tests passed and the approved script built the same-key APK. No device installation, system limit changes or unrelated process changes were made.

**0.6.0 update:** full Flutter analysis completed with zero errors/warnings and 31 pre-existing informational style notices (exit 1). No watcher failure or fallback occurred in this session. SDK cache/telemetry writes required normal tool escalation; no host limits or unrelated processes were changed. All 164 tests passed. The disposable RainbowGarden AVD was upgraded offline through the approved scripts and stopped after native ordering checks; its fixture now has 2800 XP and ordering lowercase enabled. The [0.6.0 gallery](screenshots/060/README.md) includes the reproducible capture command.

**0.4.2 update:** full `flutter analyze` completed with zero errors/warnings and 22 existing informational style notices (exit code 1). The watcher limit did not recur in that session. The fallback still checked 35 Dart files with zero diagnostics; preserve the earlier workaround if the host issue returns.

`flutter analyze` previously crashed its analysis server with errno 24 / “Too many open files” while adding an inotify watcher. This was a host resource limitation. Do not label the standard lint pass successful or modify system limits/stop unrelated work merely to clear it.

A temporary package at `/tmp/rainbow-analyzer` checked source diagnostics without starting a watcher. If it still exists:

```bash
"$HOME/snap/flutter/common/flutter/bin/cache/dart-sdk/bin/dart" \
  run /tmp/rainbow-analyzer/analyze.dart "$PWD"
```

This fallback checks diagnostics, **not the complete Flutter lint pass**. If the temporary directory is gone and the fallback is needed, recreate its following two files, then run the direct Dart executable with `pub get --offline` from that directory. Analyzer 8.4.1 was already cached on this computer; if it is no longer available, report that rather than assuming offline resolution works.

`/tmp/rainbow-analyzer/pubspec.yaml`:

```yaml
name: local_analysis
publish_to: none
environment:
  sdk: ^3.10.0
dependencies:
  analyzer: 8.4.1
```

`/tmp/rainbow-analyzer/analyze.dart`:

```dart
import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';

Future<void> main(List<String> args) async {
  final root = args.single;
  final collection = AnalysisContextCollection(
    includedPaths: ['$root/lib', '$root/test'],
  );
  var count = 0;
  var issues = 0;
  for (final dir in ['lib', 'test']) {
    for (final file in Directory('$root/$dir')
        .listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final result = await collection.contextFor(file.path)
          .currentSession.getErrors(file.path);
      if (result is ErrorsResult) {
        for (final error in result.errors) {
          stdout.writeln('${file.path}:'
              '${result.lineInfo.getLocation(error.offset)}: ${error.message}');
          issues++;
        }
      }
      count++;
    }
  }
  stdout.writeln('Analyzed $count Dart files without watchers: '
      '$issues diagnostics.');
  await collection.dispose();
  exitCode = issues == 0 ? 0 : 1;
}
```

For success-animation layout tests, viewport clamping can move a card's screen coordinates when status text changes height. Existing tests compare content coordinates (global center plus scroll offset) with a small floating-point tolerance. Preserve the actual width/centering check; `StackFit.passthrough` fixed a real shrinking/sideways-shift bug.

## Personal Google Cloud account

The user works concurrently with their work gcloud configuration. Personal access was explicitly approved and sign-in completed. Use these values **per command**:

The identity is kept out of the repository in
`~/.config/learning-corner/personal-gcloud.env` (mode 600, shell-sourceable):

```bash
LC_GCLOUD_CONFIGURATION=personal
LC_GCLOUD_ACCOUNT=<personal Google account>
LC_GCLOUD_PROJECT=<personal project ID>
```

`tools/google_knowledge_headers.py` reads that file; matching environment
variables override it and `LC_GCLOUD_SETTINGS` points to another file. On a new
computer, recreate the file; nothing in the project needs editing. It holds no
credential: tokens stay in gcloud's own store.

Do not use `gcloud config set`, activate the personal configuration globally, change the default account/project, or update Application Default Credentials. Do not print access tokens or store authentication files in this project.

For an intentional prompt change:

```bash
# Local inspection only; no cloud call or authentication needed.
python3 tools/generate_audio.py --dry-run

# Uses only the explicitly selected personal identity/project.
source ~/.config/learning-corner/personal-gcloud.env
python3 tools/generate_audio.py \
  --configuration "$LC_GCLOUD_CONFIGURATION" \
  --account "$LC_GCLOUD_ACCOUNT" \
  --project "$LC_GCLOUD_PROJECT"

# Subsets are supported by adding, for example:
# --clips welcome upper_a number_100

python3 tools/generate_audio.py --verify
```

The generator skips matching files. There is no `--force` option. It captures a gcloud access token internally, uses the TTS API, and writes each successful clip plus manifest entry before continuing. Run one generator at a time. Changes to generation/normalization require the generator tests and integrity check, followed by listening checks for affected prompts.

If authentication expires, the user can refresh it in their own terminal without changing the active account:

```bash
source ~/.config/learning-corner/personal-gcloud.env
gcloud auth login "$LC_GCLOUD_ACCOUNT" --no-activate
```

Continue independent app work while authentication is unresolved. TTS was enabled in the personal project and billing was available during prior generation; do not infer that credentials will remain valid indefinitely. Existing bundled recordings are sufficient for normal development and builds.

## Disposable test emulator: LearningCornerTest (current, 2026-10-17)

Use this AVD for all emulator testing. **Never use, wipe or modify the user's own `Medium_Phone_API_36.1`** (in `~/.android/avd/`). Earlier disposable AVDs under `/tmp` (`RainbowGarden`, `LearningGardenWriting`) no longer exist; their results are historical.

| Item | Value |
| --- | --- |
| AVD | `LearningCornerTest`, in `ANDROID_AVD_HOME=$HOME/Android/avd-learning-corner` (kept out of the default AVD list, so Android Studio and `emulator -list-avds` without that variable show only the user's AVD) |
| Image | `system-images/android-36.1/google_apis_playstore/x86_64/` (Android 16, the only installed image) |
| Hardware | 4 cores, 4096 MB, 1080×2400 at 420 dpi, 6 GiB data, no camera/mic/SD card, cold boot |
| Port / serial | `-port 5570` → **`emulator-5570`** (the user's emulator defaults to 5554) |
| Tools | `~/Android/Sdk/emulator/emulator`, `~/Android/Sdk/platform-tools/adb` (not on PATH). `avdmanager`/cmdline-tools are **not installed**; the AVD was written by hand (below) |
| KVM | `/dev/kvm` grants the user via ACL; boot completes in about 20 s |

Boot headless (lead session only; run in the background):

```bash
ANDROID_AVD_HOME=$HOME/Android/avd-learning-corner \
  ~/Android/Sdk/emulator/emulator -avd LearningCornerTest -port 5570 \
  -no-window -no-audio -no-snapshot -no-boot-anim -gpu swiftshader_indirect \
  > /tmp/learning-corner-emulator.log 2>&1
```

Verify identity and boot, then make it offline (the app must work without network):

```bash
adb=~/Android/Sdk/platform-tools/adb; s=emulator-5570
$adb -s $s wait-for-device
until [ "$($adb -s $s shell getprop sys.boot_completed | tr -d '\r')" = 1 ]; do sleep 5; done
$adb -s $s emu avd name            # must print LearningCornerTest
$adb -s $s shell cmd connectivity airplane-mode enable
$adb -s $s shell svc wifi disable; $adb -s $s shell svc data disable
$adb -s $s shell settings put system screen_off_timeout 2147483647
ADB_BIN=$adb tools/install_apk.sh $s   # install -r preserves app data
```

**Renderer (2026-10-18):** if the emulator exits 139 with `glWaitSync ... error 0x501` in the log (seen three times with `swiftshader_indirect` when Sketch pad popovers animated during `uiautomator dump` or a closing tap), boot with `-gpu swangle_indirect` instead; it ran all 0.25.0 checks without a crash. Pause about 2 s after a tap before dumping.

Stop it only with `$adb -s emulator-5570 emu kill` after re-checking `emu avd name`. Its app data persists between boots (cold boot, no snapshot), so it doubles as an upgrade fixture; record the fixture state you leave behind in the handoff.

**Codex workers and the emulator.** Codex's `workspace-write` sandbox cannot write `$HOME`, so a worker cannot start the emulator or an adb server. The lead boots and verifies the emulator (which also starts the adb server on `tcp:5037`); the worker then runs the adb *client* against `-s emulator-5570`. This requires sandbox network access (launch with `WORKER_NETWORK=1`; the wrapper defaults to off): without it the client tries to start its own daemon and fails with `cannot connect to daemon`. Verified 2026-10-17 inside the sandbox: `shell getprop`, `exec-out screencap -p > /tmp/x.png`, `uiautomator dump` + `pull`. Quick check without spending tokens:

```bash
codex sandbox -c 'sandbox_mode="workspace-write"' -c sandbox_workspace_write.network_access=true \
  -- ~/Android/Sdk/platform-tools/adb -s emulator-5570 shell getprop ro.build.version.release
```

To recreate the AVD (if the folder is lost), write `$HOME/Android/avd-learning-corner/LearningCornerTest.ini` (`avd.ini.encoding=UTF-8`, `path=$HOME/Android/avd-learning-corner/LearningCornerTest.avd`, `path.rel=LearningCornerTest.avd`, `target=android-36.1`) and `LearningCornerTest.avd/config.ini` with: `AvdId=LearningCornerTest`, `abi.type=x86_64`, `hw.cpu.arch=x86_64`, `hw.cpu.ncore=4`, `hw.ramSize=4096`, `disk.dataPartition.size=6G`, `hw.lcd.width=1080`, `hw.lcd.height=2400`, `hw.lcd.density=420`, `hw.keyboard=yes`, `hw.gpu.enabled=yes`, `hw.audioInput=no`, `hw.camera.back=none`, `hw.camera.front=none`, `hw.sdCard=no`, `fastboot.forceColdBoot=yes`, `PlayStore.enabled=true`, `tag.id=google_apis_playstore`, `target=android-36.1`, `image.sysdir.1=system-images/android-36.1/google_apis_playstore/x86_64/`.

### Disposable tablet emulator: LearningCornerTablet (2026-10-17)

A second disposable AVD for tablet and rotation checks, in the same `ANDROID_AVD_HOME=$HOME/Android/avd-learning-corner`. It was written by hand by copying `LearningCornerTest.avd/config.ini` with `AvdId=LearningCornerTablet`, `avd.ini.displayname=Learning Corner Tablet (disposable)`, `hw.lcd.width=2560`, `hw.lcd.height=1600`, `hw.lcd.density=320`, `hw.initialOrientation=landscape` (1280×800 dp, **natural orientation landscape**, like most tablets), plus a matching `LearningCornerTablet.ini`. Boot it the same way with `-avd LearningCornerTablet -port 5572` (serial **`emulator-5572`**, log `/tmp/learning-corner-tablet.log`), verify `emu avd name` prints `LearningCornerTablet`, then apply the same offline commands. Codex workers may not drive it (the orchestration guide's emulator exception names only `emulator-5570`); the lead does tablet checks. Rotation checks (lead only): `settings put system accelerometer_rotation 0` and `settings put system user_rotation 0..3`; restore `accelerometer_rotation 1` / `user_rotation 0` afterward. `cmd uimode night yes|no` and `settings put system font_scale 2.0|1.0` toggle dark mode and large text.

The headless emulator is muted: playback completion and the absence of the app's "Sound could not play" message are the only audio evidence; listening still needs the phone.

### Backup and launcher-shortcut checks (0.24.0, lead only, disposable emulators)

Backup rules can be exercised offline with Android's local transport. First note the starting state (`bmgr enabled`, `bmgr list transports`; the Google Play images start disabled on the GMS transport), then:

```bash
a="$HOME/Android/Sdk/platform-tools/adb -s emulator-5572"; P=com.rainbowgarden.rainbow_garden
$a shell bmgr enable true
$a shell bmgr transport com.android.localtransport/.LocalTransport
$a shell settings put secure backup_local_transport_parameters 'is_encrypted=true'   # cloud with encryption
$a shell bmgr backupnow $P            # logcat FullBackup_native "measured" lists the included files
# change something (e.g. a 2048 move), then:
$a shell bmgr restore 1 $P            # token from `bmgr list sets`; the change reverts
$a shell settings put secure backup_local_transport_parameters 'is_encrypted=false'  # expect: nothing backed up
$a shell settings put secure backup_local_transport_parameters 'is_device_transfer=true'
$a shell bmgr backupnow $P
# restore the starting state:
$a shell settings delete secure backup_local_transport_parameters
$a shell bmgr transport com.google.android.gms/.backup.BackupTransportService
$a shell bmgr enable false
```

The local transport overwrites its single backup set, and restoring replaces the app's data with it, so use this only on disposable emulators, never a physical device. A launcher shortcut can be simulated without the launcher: `am start -a android.intent.action.VIEW -n $P/.MainActivity --es learning_corner.shortcut sketchPad -f 0x34000000` (NEW_TASK | CLEAR_TOP | SINGLE_TOP, as the launcher sends it). A warm launch prints "intent has been delivered to currently running top-most instance". `dumpsys shortcut` lists the published shortcuts.

## Companion adventure validation (0.4.0)

The release was built with the same SDK and scripts. The file-watcher failure remains reproducible; the watcher-free fallback checked 33 Dart files with zero diagnostics. Run widget tests using bounded pumps because companions and scenery have continuous decorative tickers. Mini-game timing tests inject an active clock.

The API 36.1 Google Play emulator does not support `adb root`, and release APKs do not permit `run-as`. To inspect migration and seed **only disposable emulator test data**, a same-key debug build was temporarily installed with `install -r`, then the release APK was restored using `tools/install_apk.sh`. The debug fixture checks are distinct from the initial release-mode upgrade and final release smoke test. Never seed or clear a physical phone or the user's existing AVD.

Audio generation refreshed six adventure clips with the existing explicit personal identity; no cloud configuration or ADC was changed. The final bundle has 162 WAVs. All 153 target recordings stayed byte-identical to 0.3.0. Four built-in image-generation outputs were copied into `assets/scenery/`; exact prompts are in `ARTWORK.md`.

## Picture customization validation (0.4.1)

The same direct SDK paths and build/install scripts worked for 0.4.1+6. Full Flutter analysis again hit the watcher limit; the fallback checked 35 Dart files with zero diagnostics, and all 83 Flutter tests passed. No new audio generation or image generation was needed.

The isolated RainbowGarden AVD was reused after verifying its serial/name. Release updates used `install -r` and retained the 0.4.0 adventure document. A temporary same-key debug APK permitted native inspection and earned-reward fixtures. Its original `garden.xml` was backed up to `/tmp/rainbow-041-preserved-garden.xml` and restored byte-for-byte after testing; the final release was then restored. This is disposable emulator data, never phone data. Final saved equipment is blue/bow/butterfly/hop, with the previous level 17, plays and settings retained.

Use explicit `Semantics` around a gift button with a numeric Badge: relying on the icon button tooltip alone let the badge count obscure its accessible name in the Android hierarchy. The regression checks the complete gift label. When testing modal save completion, guard the route's `isCurrent` before popping: the sheet can still be mounted during dismissal.

Current screenshots and distinctions between release checks and debug fixtures are in [testing.md](testing.md). Temporary `/tmp/rainbow_041_*.py` scripts are session-specific diagnostic helpers, not a general test harness.

## Letter terminology and speech update (0.4.2)

The generator regenerated 54 changed letter/matching clips using the explicit `--configuration personal` with explicit personal `--account`/`--project` flags. No global gcloud configuration, account/project selection or ADC was changed. The remaining 108 clips were reused. The Puck voice, 0.9× speed and `target-pause-v2` processing remain unchanged. All 52 regenerated letter target gaps measured 400 ms; complete manifest verification passed. No generator implementation changes were needed.

Full Flutter tests: 86 passed. Python generator tests: six passed. The final release uses version 0.4.2+7 with the same debug signing key. Physical Pixel listening remains a manual check; see [testing.md](testing.md) for current results and limits.


## 0.5.0 tooling and validation

The same direct Flutter/Dart/ADB paths and debug signing certificate were used. Build/install scripts now deliver `artifacts/learning-garden.apk`. No synthesis or asset generation was needed. SDK/cache writes needed sandbox escalation; no SDK, host watcher limit, active gcloud configuration or source skill files were changed.

Full analysis again hit the documented inotify/file-watcher limit. The watcher-free fallback checked 37 Dart files with zero diagnostics; full Flutter linting remains unverified in this session. All 112 tests and six generator tests passed. The optional screenshot command and installed-font path are in the [layout gallery](screenshots/050/README.md).

The verified disposable AVD upgraded from release 0.4.2 to 0.5.0 with `install -r` while offline. Native UI checks toggled and restored Tap Next/Haptics, tested Save/Back/restart, and earned one synthetic 50 XP round. No debug APK or fixture injection was needed this session. The final fixture is 2750 XP with the previous nine spent moves, pending plays and equipment preserved; both new switches are on. The disposable AVD was stopped after final checks. See the handoff and testing notes for final release details and physical-device limitations.

## 0.5.1 tooling and validation

The approved build/install scripts and existing signing key produced 0.5.1+9. All 124 Flutter tests and six generator tests passed. Full analysis again hit host watcher exhaustion; the existing fallback checked 39 files with zero diagnostics. No host limits, source skills, cloud configuration or credentials changed. The gallery test now writes optional captures to `docs/screenshots/051`; its installed-font command is in that gallery’s README. The 0.5.0 images remain historical.

The verified disposable RainbowGarden emulator accepted `install -r` from 0.5.0 while offline. Current native captures and the retry screen recording are in the 0.5.1 gallery. No debug APK or fixture injection was needed. Temporary `/tmp/learning_051_native.py` and `/tmp/learning-051-*` logs are session-specific evidence, not a reusable fixture harness. Physical Pixel checks remain separate.

## 0.5.2 tooling and validation

The existing tool paths and approved build/install scripts produced 0.5.2+10 with the same signing key. Full analysis hit the known watcher limit; the final watcher-free fallback checked 40 files with zero diagnostics. The full Flutter suite passed 141 tests, with six Python generator tests and all offline recordings verified. No source skills, SDK settings, system limits or cloud configuration changed.

`test/voice_toggle_test.dart` uses shared optional font/capture helpers to write `docs/screenshots/052/` when CAPTURE_REFRESH is enabled; older layout captures keep their own directory. See that gallery’s README for the command. A Pixel 7 was listed by ADB but left untouched; installation and native UI checks explicitly used verified emulator-5554 / RainbowGarden. Temporary `/tmp/learning-052-*` evidence and `/tmp/learning_052_native.py` describe this session only.


### Blender review headless fallback (2026-09-15)

During isolated model review v04, desktop EEVEE rendering aborted with
`Couldn't find current GLX or EGL context`; `nvidia-smi` reported a
`Driver/library version mismatch` (NVML 580.178). The read-only rig checks and
model build still worked. Rendering succeeded with
`env -u DISPLAY EGL_PLATFORM=surfaceless LP_NUM_THREADS=4 /usr/bin/blender --background ...`
(with Blender `--threads 4` for review jobs).
This fallback is slower. No driver, host setting or running desktop was changed.
Use the regular graphics context when available; the failure is host-specific.


### Revision-five production render runtime (0.12.0)

The running NVIDIA kernel module was 580.173.02 while installed user libraries
were 580.178.04. For this export only, `apt-get download` fetched the matching
Ubuntu `libnvidia-gl-580=580.173.02-0ubuntu0.24.04.1` package, and `dpkg-deb -x`
extracted it under `artifacts/playful-spark/release-0120/render-runtime/`.
The local `blender.sh` scopes the library path and EGL vendor JSON to Blender;
EGL confirmed the RTX 4060 and OpenGL 4.6. No package was installed and no system
driver, kernel module, desktop setting or unrelated process was changed.

`tools/export_foal_library.py` supports four disjoint outfit workers and stages a
complete, source-stamped library before publication. The current raw cache is
`artifacts/playful-spark/release-0120/frames`; explicitly pass `--frames-root`
when repacking it. Old default caches intentionally fail source checks.

Use `tools/build_apk.sh --profile-companion` only for release-mode measurements.
It writes `artifacts/companion-profile.apk`; `APK_PATH` selects it for the normal
install script. Follow it with a normal build and in-place install. Packaging
requires the profiling marker in the candidate and rejects it in the normal APK.
No profiling entrypoint is shipped to the user.
