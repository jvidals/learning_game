# Testing Learning Corner

## 0.21.1 — native emulator validation and feedback fix (2026-10-17)

Native testing of 0.21.0 on the disposable **LearningCornerTest / emulator-5570** (Codex worker driving adb; [results](../artifacts/new-games-0210/native/results.json)) passed all 14 checks: 0.20.2 → 0.21.0 `install -r` preserved XP; each new game's round awarded exactly 50 XP; Word Sprint (best, undo, hint pause, early stop, untimed, timer persistence, background → explicit Resume) and Cursive play awarded none; Number hunt showed a look-alike in all five questions; no Flutter/FATAL/AndroidRuntime errors (only the known platform `ashmem` deprecation line). It found that on a 411×914 dp phone 'Try again' and Next sat below the fold for Make-believe words and Same number. **0.21.1** moves feedback and manual Next into the fixed bottom bar for all four visual games (other games unchanged); new layout tests cover it.

**937 Flutter tests passed**; full analysis 0 errors/warnings (62 infos); format clean. APK **0.21.1+46**, **670,896,188 bytes**, SHA-256 `045198a5436dd22922ac71280f32c275f0aa1aaeb9850d202d5c93c67914aabd`; same certificate and offline permissions; all 1,992 bundled files byte-identical to 0.21.0 ([audit](../artifacts/new-games-0210/apk-verification-0211.json)). Native retest of 0.21.1 ([results](../artifacts/new-games-0210/native-0211/results.json)): upgrade preserved the fixture; feedback/Next fully visible without scrolling in all four visual games; Number hunt/uppercase regressions passed; XP 300 → 550; no app errors. Opening the gift sheet clears transient 'Try again' text as in every game (existing interruption behavior, not a regression). Final emulator fixture: Player 1, 550 XP / level 6, five gifts, Word Sprint best 4, timer on, sound on; emulator stopped with data preserved.

## 0.21.0 — reading, number-sense and cursive games (2026-10-17)

**920 Flutter tests passed** (760 at 0.20.2), including foundation seams, builders over hundreds of seeds, widget flows, cancellation, persistence/migration, 360×640 at 200% text and both palettes. Full `flutter analyze` completed without the file-watcher fallback: **0 errors/warnings, the same 62 informational notices**. `dart format` reports no changes for lib/test. **All Python tool tests passed**, including new generator and APK-verifier cases; `generate_audio.py --verify` confirms **325** recordings. **336 rendered review scenarios / 336 PNGs** (320×640, 393×852, 740×360, 800×1100; Light/Dark; 100%/200% text, reduced motion at 200%) passed with no exceptions or overflows; the lead inspected representative captures, and review-driven fixes (Word Sprint mode picker, landscape grid, centered words; cursive pad above the fold and open bowls; compact Same number row, reading-order hints, dice patterns, simplified Make 10, larger shapes/ten-frame dots) were re-captured and re-inspected. Some dark 200% captures intermittently omit static paint in the harness; layout assertions pass.

APK **0.21.0+45**, **670,896,188 bytes**, SHA-256 `0d7e5f445800e7c7ae97c9684669f34fdfd20ab3c5c8dff42fd95e4651d1f65c`. The audit verified the original signing certificate, package/label/entrypoint, API 24–36, not debuggable, and no INTERNET/network/RECORD_AUDIO/VIBRATE permission. All **1,852** previous content/shader files are byte-identical; the two audio manifests were updated and exactly **140** files were added (104 `cvc_*`/`nonsense_*` recordings, 34 word pictures plus manifest and license). [APK](../artifacts/learning-corner.apk) · [Evidence](../artifacts/new-games-0210/README.md) · [Gallery](screenshots/0210/README.md).

Not performed: device/emulator install, physical touch, listening review of new recordings, TalkBack exploration.

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


## 0.20.2 — compact uniform Numbers cards (2026-09-19)

APK **0.20.2+44**, **662,129,648 bytes**, SHA-256 `711018b573aa33507cfb37034c3216eaffd05744504b8e4790b0da969d2812f3`. The approved build and release audit verified the original signing certificate, application identity/label, normal release entrypoint, API 24–36 and offline permissions. All **1,852 bundled content/shader files** match 0.20.1 byte-for-byte, including 221 recordings. No save format, native API, dependency or asset changes.

**760 full Flutter tests passed**, plus **61 focused checks** and **16 rendered scenarios / 240 PNGs**. Extended checks assert equal heights across all five cards, original normal-text phone height with real fonts, independent actions, centered range controls at least 48×48 dp, and fitting 0–100 / 98–100 labels. Representative phone/tablet views at normal/200% text were inspected. Final formatting passed for all **3 changed Dart files**. The full suite emitted 12 nonfatal tap hit-test warnings; all tests passed.

Full Flutter analysis hit the known host file-watcher limit (`errno 24`, too many open files). The documented watcher-free fallback checked **96 Dart files with zero diagnostics**; full Flutter linting remains unverified for this release. No host limits or unrelated processes were changed.

The first long-range review exposed cramped titles at large text. The final layout constrains the range action width and stacks artwork above the title in narrow large-text cards; all scenarios passed afterward. The 102 dp assertion uses actual capture fonts, since Flutter's Ahem test font has different metrics. Uniformity, touch targets and no-overflow checks also pass with the default test font.

No device or emulator was started or installed during this release; earlier native upgrade results remain historical. Physical touch and full TalkBack exploration remain manual. Confirmed-idle project Gradle daemon 562177 was stopped after checking its last build directory. Scoped escalation was required for the existing bwrap failure; no host, SDK, cloud or source-skill settings changed. [Evidence](../artifacts/compact-cards-0202/README.md) · [Gallery](screenshots/0202/README.md).

## 0.20.1 — range shortcuts inside cards (2026-09-19)

APK **0.20.1+43**, **662,096,880 bytes**, SHA-256 `dfaa231e622140ef2df9c4ffd9a846d3d9b23e35f3db87bd7f68a84b10a6ca58`. The approved build and audit verified the original signing certificate, package/label, API 24–36, normal release entrypoint and offline permissions. All **1,852 bundled content/shader files** match 0.20.0 byte-for-byte. No persistence, native API, dependency or asset changes.

**61 focused Flutter tests passed** (range widgets, interface refresh and learning expansion), plus **16 rendered layout scenarios / 224 PNGs**. All four shortcuts remain within their card surfaces with touch targets at least 48 dp; existing tests cover separate semantics, normal game entry, parent-gated editing and saved range updates. Representative phone/tablet renders at normal/200% text in both themes were inspected. Both changed Dart files passed final formatting.

Full `flutter analyze` hit the known host file-watcher limit (`errno 24`, too many open files). The documented watcher-free fallback checked **96 Dart files with zero diagnostics**; it does not replace full Flutter linting. No system limits or unrelated processes were changed.

No device or emulator was started or installed during this layout-only release. Earlier native upgrade results remain historical; physical touch and full TalkBack review were not performed. The full 760-test result below belongs to 0.20.0; this layout-only change ran the focused checks above. [Logs and baseline](../artifacts/card-range-0201/README.md) · [Gallery](screenshots/0201/README.md).

## 0.20.0 — independent game ranges and automatic settings (2026-09-19)

APK **0.20.0+42**, **662,096,880 bytes**, SHA-256 `67367fcac685e7b1578eb39140248ed3eb1bf9dd7edc3ace9bd084c21dd07e7b`. [APK audit](../artifacts/number-settings-0200/apk-verification.json) · [Release evidence](../artifacts/number-settings-0200/README.md) · [Gallery](screenshots/0200/README.md).

- **760 full Flutter tests passed** on the final source. New coverage includes strict legacy migration, malformed neighboring profiles, independent ranges/caps, nonzero counting minima, balanced answer slots, default/reset preservation, immediate appearance and settings, required pack/sound selections, exact failed-write retry, rapid coalescing, edits during manual retry, player ownership and blocked reward/reset/profile operations. Existing Writing, 2048, Tap Challenge, rewards and identification coverage ran again. The suite emitted 13 nonfatal tap hit-test warnings; all assertions passed. [Full log](../artifacts/number-settings-0200/flutter-tests.log).
- **137 focused checks passed** after final layout changes: continuous rounds, voice controls and range widgets. Canceled/unchanged editing preserves work, changed ranges restart once, closing before slow/failed saves pauses play, and retry resumes correctly. Tests exercise 1–15 grouping capacity, zero, full counting rewards and replay. [Focused log](../artifacts/number-settings-0200/tests-final-layout.log).
- **16 production-art review scenarios passed / 224 PNG captures**: 320×640, 393×852, 740×360 and 800×1100; Light/Dark; normal/200% text with reduced motion at 200%. Each covers category shortcuts, four editors and exact controls, resulting games and main Settings. Representative captures were inspected. Review exposed and fixed narrow title wrapping, accessible header sizing and constrained completed-ordering footer overflow. [Capture log](../artifacts/number-settings-0200/captures.log).
- Full Flutter analysis completed with **zero errors/warnings and 61 informational notices**, exit 1. These include existing and touched-file style notices; this is not a clean lint exit. No watcher fallback. **27 changed Dart files** passed final formatting with zero changes. Python generator tests were not rerun for this Dart-only feature; normal build verifiers checked all bundled assets.
- Approved normal build and release audit passed: original signing certificate, non-debuggable release, API 24–36 and no INTERNET/ACCESS_NETWORK_STATE/VIBRATE permissions. All **1,852 bundled content/shader files** match 0.19.2 exactly, including 221 audio clips and 1,601 companion assets. Profile envelope remains version 1; valid legacy settings migrate to named per-game fields without replacing malformed saves. No native API, dependency or bundled-content changes.

- Offline `install -r` on verified **LearningGardenWriting / emulator-5560** passed independent ranges (hunt 2–10, order 1–20, counting 0–5, grouping 1–15), changed-range restart, immediate appearance and Tap Next saves across process restarts. The final Writing P/p state, exact 2048 board, **560 XP / level 6** and **three gifts** match the baseline; muted sound is retained. Original System appearance and Tap Next on were restored. Installed version/checksum match the distributable. The emulator was stopped with data preserved; no phone or user AVD was touched. [Native evidence](../artifacts/number-settings-0200/native/results.json). The initial automation missed Number hunt because the category retained its scroll position; reopening the category fixed the harness and the full rerun passed. No production change was needed. Final app-process error log contains only Android's ashmem deprecation message, with no Flutter exception. Confirmed-idle project Gradle daemon 438071 was stopped.

Physical touch, listening/haptics and full TalkBack exploration remain manual. Older results below are historical unless explicitly repeated above.

## 0.19.2 — personalized Home greeting (2026-09-19)

APK **0.19.2+41**, **662,080,376 bytes**, SHA-256 `8e9d2942b0e173d7c47b44e334d2b4ff698cf320d9d366226094610199bd5a39`. [APK audit](../artifacts/home-greeting-0192/apk-verification.json) · [Release evidence](../artifacts/home-greeting-0192/README.md) · [Gallery](screenshots/0192/README.md).

- **726 full Flutter tests passed**. Existing Home/navigation assertions now expect the active-player greeting. Profile checks cover switching, canceled/successful rename, pending/failed rename retaining the saved name, successful retry, restart, silence and unavailable-profile recovery. The run emitted 12 nonfatal tap hit-test warnings in existing flows; all tests passed. [Full log](../artifacts/home-greeting-0192/flutter-tests.log).
- **16 rendered review scenarios passed**, producing **48 PNG captures** with real companion art and installed Roboto/Material fonts. Each reviews Sam, the 24-character Alexandra Rainbow Flower and 24 unbroken W characters at 320×640, 393×852, 740×360 and 800×1100; Light/Dark, normal/200% text, reduced motion at 200%. Checks confirm the complete greeting in semantics, no truncation/overflow, retained Learning Corner application title, silent Home/category return and reachable activities. Representative screenshots were visually inspected. Exceptionally long names wrap within words on narrow screens while preserving text scale. [Review log](../artifacts/home-greeting-0192/review.log).
- Full Flutter analysis completed with **zero errors/warnings and 48 existing informational notices**, exit 1; no watcher fallback. **10 touched Dart files** passed final formatting with zero changes. Python tests were not rerun for this Dart-only heading change; approved build verifiers checked bundled content.
- Approved normal build, SHA-256 check and release audit passed. Original signing key/application ID, Learning Corner Android label, API 24–36, release entrypoint and absence of INTERNET/ACCESS_NETWORK_STATE/VIBRATE permissions verified. All **1,852 bundled content/shader files** match 0.19.1 exactly. Save formats, native implementation, assets and dependency lockfile are unchanged.
- No device installation, emulator startup, phone interaction or native upgrade test occurred. Screen-reader semantics were checked in widgets, not physical TalkBack. Earlier device/audio results remain historical. Confirmed-idle project Gradle daemon 409472 was stopped; existing sandbox failure used scoped escalation without host/SDK/cloud/source-skill changes.

All older results below are historical unless repeated above.

## 0.19.1 — Learning Corner identity (2026-09-19)

APK **0.19.1+40**, **662,080,376 bytes**, SHA-256 `cec00b4b7c7dba53e1614d10ca4b576247caf45bf58779f550e46ea6764099a4`. [Release evidence](../artifacts/learning-corner-0191/README.md) · [APK audit](../artifacts/learning-corner-0191/apk-verification.json) · [Rendered gallery](screenshots/0191/README.md).

- **725 full Flutter tests passed**. Existing title/return expectations were updated; navigation, continuous rounds, save/retry, settings and profile coverage remain. The run emitted 12 nonfatal tap hit-test warnings in existing test flows; no test failed. [Full log](../artifacts/learning-corner-0191/flutter-test.log).
- **16 focused review scenarios passed**, producing **128 production-art PNG captures**: 320×640, 393×852, 740×360 and 800×1100 at normal/200% text in Light/Dark (reduced motion at 200%). Covers Home name/semantics, help, appearance/counting/progress settings, category tooltip, reward-sheet root return and Tap Challenge results. Representative images were inspected; labels fit or wrap with scrolling retained. The review did not change saved player data. [Harness](../artifacts/learning-corner-0191/review.dart), [log](../artifacts/learning-corner-0191/review.log).
- Full **flutter analyze** completed with **zero errors/warnings and 48 existing informational notices**, exit 1; no watcher fallback or host-limit changes. **20 touched Dart files** passed formatting with no changes. Both shell scripts passed `bash -n`; **5 existing APK-verifier Python tests** passed.
- Approved normal build and default-path APK verification passed. The new filename is **artifacts/learning-corner.apk**, with its checked SHA-256 file. Android application label is Learning Corner; application ID and original signing certificate match 0.19.0. Non-debuggable normal entrypoint, API 24–36 and absence of INTERNET/ACCESS_NETWORK_STATE/VIBRATE permissions verified.
- All **1,852 content/shader files** are byte-identical to the preserved 0.19.0 APK, including all 221 recordings, 1,601 companion assets, phonics pictures and shaders. Launcher art, native storage/audio implementation, save formats and dependencies are unchanged. No generation or migration.
- No device installation, emulator startup or phone interaction was performed. APK metadata and widget tests establish naming/navigation and update compatibility; this session does not claim an installed upgrade or physical TalkBack/listening review. Confirmed-idle project Gradle daemon 394813 was stopped. The sandbox/image-reader bwrap startup issue required scoped escalation; no approval was rejected.

All older validation below is historical unless explicitly repeated above.

## 0.19.0 — continuous rounds (2026-09-19)

Final APK **0.19.0+39**, **662,080,376 bytes**, SHA-256 `945a59d8dbcceb97e63000f7e8c362d32c2cbae9d85ead91fa7b359fe94d30a9`. [APK audit](../artifacts/continuous-rounds-0190/apk-verification.json), [full Flutter log](../artifacts/continuous-rounds-0190/flutter-tests.log), [gallery](screenshots/0190/README.md), [native results](../artifacts/continuous-rounds-0190/native/results.json).

- **725 full Flutter tests passed**, including 98 new checks. Consecutive manual/automatic rounds cover all eight five-question activities and both ordering boards. Existing 2/2/1 balance, settings, sound, hints, profiles, rewards, Writing, 2048 and Tap Challenge regressions ran again.
- Focused coverage includes the exact two-second save-gated delay, accessibility override, slow/failed saves, retry after navigation, timer/tap races, background/coverage/rebuild behavior, unanswered voiced return, retained counting/order work, gift saves after sheet dismissal, blocked profile changes, banking/restart and empty gift state. Header semantics explicitly name Rewards at 0/1/25 gifts.
- **64 separate layout/capture scenarios passed**, producing **128 images**, with real bundled art. They cover Letter friends, Sight Words, Make a group and Number Order at 320×640, 393×852, 740×360 and 800×1100, Light/Dark, 100%/200% text; 200% also uses reduced motion. Every scenario checks reachable completion/sheet actions and saves a gift selection. Representative renders were inspected. Constrained completion/status content scrolls. The final accessibility-label fix changes semantics only; the reviewed pixels are unchanged.
- Full Flutter analysis: **zero errors/warnings, 48 informational notices**, exit 1. This includes pre-existing style notices and touched-file style notices; it is not a clean lint exit. No watcher fallback or host-limit changes. Formatting checked 49 Dart files, zero changes. Python generator tests were not rerun for this Dart-only feature; normal build verifiers checked all bundled content.
- Approved build script, original certificate, release/normal entrypoint, API 24–36, no network/VIBRATE permissions and exact asset inventory passed. All **1,852 content/shader files** match 0.18.3, including 221 audio clips and 1,601 companion files. No cloud generation, package changes or persistence migration. Existing counting-icon work is preserved.
- The final native APK passed two consecutive Letter friends rounds, Next round, in-progress reward review preserving the exact target, banked rewards and Back to garden. With parent-gated Tap Next off, Number hunt advanced questions and started a fresh round automatically; rewards remained accessible afterward. Tap Next was restored on, and saved sound stayed off.
- Offline install-r and restart preserved the original player, Writing P/p, and the exact saved 2048 board. Four rounds across validation (including one before the final semantics fix) earned exactly 200 XP: **360 → 560 / level 6**, **10/150 toward level 7**, three unclaimed gifts. No gifts were redeemed natively; redemption is covered by widget/capture tests. Final installed bytes match the published checksum. The verified isolated emulator and confirmed-idle project Gradle daemon were stopped with saves intact. No phone or user AVD was used.
- Initial regression work found/fixed lazy animation-controller disposal and ordering final-feedback cancellation during footer reflow. Native inspection found/fixed a gift button exposing only the badge number. Old mandatory-reward expectations were updated. Capture readiness was corrected to accept decoded static posters, and a test-only semantics-handle teardown was corrected. Final checks above passed after the relevant fixes.

Physical-device touch comfort, actual automatic pacing preference, listening/haptic feel and a complete TalkBack play-through remain manual. Native label checks and widget semantics do not substitute for that exploration. All older validation below is historical unless explicitly repeated above.


## 0.18.3 — generic counting activity icons (2026-09-19)

- **9 existing category/navigation tests passed**. No game rules, settings, saves, audio or assets changed.
- **8 visual-review scenarios passed**, producing **32 captures** at 320×640, 393×852, 740×360 and 800×1100, with 100%/200% text and live Light-to-Dark switching. Activity labels, whole-card taps and foreground/outline contrast ≥4.5:1 passed. Phone captures in both themes, small-phone large text and tablet large text were visually inspected. [Gallery](screenshots/0183/README.md).
- Full Flutter analysis completed: **zero errors/warnings, 42 existing informational notices** (exit 1). Touched Dart formatting passed with zero further changes. The capture harness initially left a SemanticsHandle active at teardown; explicit disposal fixed the harness, with no production change. No new permanent tests were added for this visual-only edit; the reproducible review harness is under release evidence.
- Approved build produced **0.18.3+38**, **662,080,452 bytes**, SHA-256 `309710a52fade1579e47f685fa2a4b931784f4bae1c136b527a188a1b495046b`. Same certificate, normal entrypoint, API 24–36, no network/VIBRATE permissions and exact asset inventory verified. All **1,852 content/shader files** match 0.18.2 byte-for-byte, including all 221 audio clips and the compressed companion library. [APK evidence](../artifacts/counting-icons-0183/apk-verification.json).

No emulator/phone installation, cloud synthesis, asset regeneration or host/toolchain changes occurred in this session. Prior full-suite, codec and device results below are historical; current work ran the checks listed above. Logs, prior APK and source baseline are in `artifacts/counting-icons-0183`.


## 0.18.2 — companion compression (2026-09-18)

APK **0.18.2+37**, **661,998,532 bytes**, SHA-256 `ea2109f167813da45dfea0c9597fd51ccde7b1bba698250f42709da8f7c55da4`. Down from 1,105,916,340 bytes: **443,917,808 bytes / 40.14% saved**. [Compression report](../artifacts/companion-compression/README.md) · [APK audit](../artifacts/companion-compression/apk-verification.json) · [Android comparison](../artifacts/companion-compression/native/comparison.json).

- All **1,575 segments / 23,025 authored frames** were checked against original PNG renders. Transparency and all four material masks are exact. Quality remains 90, resolution 1024 pixels, sampling 60 Hz; decoded frame counts are unchanged. Animated WebPs are 43.29% smaller. Aggregate source-relative RGB error improved from 1.8323 to 1.7986; RGB is still lossy, not lossless.
- Final real-Flutter codec/shader checks passed for **29 all-outfit/action pilot segments** and **15 full-run worst-case samples**, including held and partial segments. Frame counts, dimensions and durations matched. Median segment p95 decode times were 22.34 → 8.86 ms and 25.01 → 13.38 ms respectively. These host timings are separate from Android/physical-device performance.
- Paired production-shader sheets were inspected for the largest color-error increase, tinted mane/hooves and a turning pose, on light/dark backgrounds. No visible degradation was observed in those samples. Every authored frame was numerically audited; not every frame was visually inspected. Native reduced-motion rendering was also inspected.
- **627 full Flutter tests passed** with the compressed production assets. **30 Python tests passed**, including timing, held-frame behavior, mask corruption, checkpoint invalidation and atomic-output failure cases. Full analysis completed with **zero errors/warnings and 42 existing informational notices** (exit 1); no watcher fallback. The three changed/new diagnostic Dart files passed formatting.
- Identical release-mode Android scenarios on verified **LearningGardenWriting / emulator-5560** exercised idle, every celebration type, all 25 outfits and reduced motion. Stage median engine fps was 59.03/58.22/58.38 before and 58.70/58.18/58.38 after; interval p95 was 16.667 ms in all three phases. Raster p95 changed by at most about 2.2%. Managed decoded-image peaks were identical at **61,669,376 bytes**, below the 64 MiB limit. Process-memory snapshots showed no increase in sampled peak RSS (213,836 → 197,104 KiB), but they are not continuous peak measurements. No material playback regression was observed on this software-rendered emulator; physical-device performance remains unmeasured.
- Approved normal build, existing certificate, API 24–36, offline permissions and marker-free normal entrypoint passed. Exactly **1,575 animated files plus their manifest** changed; **276 other content/shader files** are byte-identical, including all 221 recordings, phonics pictures, static companion art and shaders. No new runtime dependencies or network permission.
- Final offline **install-r** preserved the exact visible player/settings, Writing and 2048 state. Player 1 remains 360 XP/level 4, muted, at Writing P/p with the same board. Normal Home/My unicorn rendering, empty app error log and installed checksum passed. [Final native evidence](../artifacts/companion-compression/native/final-results.json). No uninstall, reset, fixture injection or phone/tablet install.
- The disposable emulator's original power setting was restored and it was stopped with data retained. Only confirmed-idle project build daemons were stopped. No user AVD, unrelated applications, host limits, SDK settings, cloud configuration or source skills changed. Original APK/assets and the exact encoding tools are preserved under `artifacts/companion-compression/`.

Normal builds reuse these bundled files. The new compression runner uses original PNGs, bounded workers, an 8 GiB available-memory reserve and verified checkpoints. The old render stamps were not rewritten: historical source reconstruction proved that only removed walk/travel definitions separated the raw cache from the current retained library. See the report for commands and detailed logs. All older validation below is historical unless repeated above.

## 0.18.1 — counting boxes and letter-name audio fixes (2026-09-18)

APK **0.18.1+36**, **1,105,916,340 bytes**, SHA-256 `f318f85495713350879c8f1bea444295ca12f9a6df07c14703ae7dc43780e721`. [APK evidence](../artifacts/learning-0181/apk-verification.json) · [Native results](../artifacts/learning-0181/native/results.json) · [Captures](screenshots/0181/README.md).

- 627 full Flutter tests passed on the final Dart source. 35 focused expansion checks passed and produced 48 captures; both phone palettes were visually inspected. A redundant Container was subsequently removed without changing layout; the full suite passed after that cleanup.
- 25 Python tests passed on the final generator/assets, including a signal-level regression that rejects the old voiced “ess” recording, duration rejection, and preserved onset/faded tail for the held L edit. All 198 pre-phonics prompts remain byte-identical.
- All 221 clips passed offline request/hash/PCM checks and native 300 ms lead-in preservation; nine malformed formats rejected. Final analysis completed with zero errors/warnings and 42 info notices (exit 1). Formatting: 92 files, zero changes.
- Same-key normal APK build, API/permissions, exact asset inventory, 23 changed clips and 1,829 unchanged content/shader files verified. No new runtime dependencies or network permissions.
- Offline install-r and restart on verified LearningGardenWriting / emulator-5560 preserved the 360 XP/level 4 player, muted setting, Writing and exact 2048 board. All three activities opened, the Letter Sounds target played without audio error, explicit hint worked, and counting exposed no voice controls. Installed checksum matched; emulator stopped with data preserved. No phone/user AVD, reset or fixture injection.

Audio quality evidence: the original s has a pronounced voiced vowel and was blindly transcribed /ɛs/; new s is unvoiced frication, and the regression rejects the old pattern. Independent Gemini audio review recognized new sustained sounds and short vowels. It caught a repeated h and overlong L; those were replaced. Several L candidates were rejected; the final capped Flash L was transcribed as an isolated lateral. Some short consonants were transcribed with release schwa vowels; automated transcription of isolated consonants is imperfect and does not establish pure-sound teaching quality. Human audition and physical-speaker onset remain open, using the [listening page](../artifacts/learning-0181/phoneme-review.html). Audit JSON files record intermediate and final stages; `audio-final-manifest.json` pins shipped bytes. No claim of human listening.

Generation encountered transient SERVICE_DISABLED responses immediately after enabling the personal project's Gemini dependency; resumed generation reused completed clips. Nothing changed in the active work gcloud configuration/account/project or ADC. All authoring requests used explicit personal flags. Logs and original APK/clips are preserved under `artifacts/learning-0181`.


## 0.18.0 — Letter Sounds and Counting Garden (2026-09-18)

Current APK: **0.18.0+35**, **1,105,774,948 bytes**, SHA-256 `40178507bec4a2791fcc34dffdacaee2ff458fbdf195c8742ffd547227025b93`.
[APK evidence](../artifacts/learning-0180/apk-verification.json) · [gallery](screenshots/0180/README.md).

### Checks run in this session

- **627 full Flutter tests passed on the final source**, up from 577 at 0.17.0. Coverage adds supported/enabled-only phonics, three distinct sound choices (including c/k), parent validation, additive settings round-trip/malformed data, profile isolation, retained failed writes, reset preservation, all counting limits including zero, reversible marks/add/remove, both pacing modes, silent replay, hints, once-only XP and failed fifth-answer retry.
- **23 focused widget tests passed with captures** after the final Light-mode outline refinement. The 16 layout scenarios produced **48 captures** for three activities across 320×640, 393×852, 740×360 and 800×1100 windows, normal/200% text, both palettes and reduced motion in the 200% cases. Representative captures and all 24 hint pictures were visually inspected. Counting controls remain fixed/reachable; twenty-object frames retain large targets.
- **22 Python tests passed**. All **221 WAVs** passed request/processing/hash integrity verification; all 198 prior clips remain byte-identical. Native JVM validation preserved every original PCM sample in all 221 recordings, added exactly 300 ms native lead-in and rejected nine malformed formats. Its stale historical 205-clip assertion was updated; this is test-only.
- Full Flutter analysis completed with **zero errors/warnings and 42 informational style notices** (exit 1), with no watcher fallback. Final formatting passed for **92 Dart files**, zero changes. No host limits or unrelated processes were changed.
- Approved normal build, original signing certificate, API 24–36 and offline permissions verified. All **1,803 prior content/shader files** are byte-identical. Added exactly 23 phoneme clips, 24 hint PNGs and two picture provenance/manifest files. Companion inventory remains 1,601 assets. No new runtime dependencies.

### Native validation

Only verified **LearningGardenWriting / emulator-5560** was used, with airplane mode already on. The install-r upgrade from 0.17.0 preserved Player 1, 210 XP, muted sound, the saved Writing P/p position and the exact visible 2048 board/high score. Three real new-activity rounds saved exactly 50 XP each: final **360 XP / level 4**, 110/150 toward level 5, one unclaimed gift. These gameplay checks used the first 0.18.0 candidate; final differences are distinct distractor sounds, scroll-to-top on counting Next and Light-mode outlines, covered by final automated tests and the final APK smoke check.

Make a group retained the answered question through background/resume. An automation assertion initially looked for off-screen success text; inspecting the visible Next button proved the answer remained, and the remaining four questions completed normally. No production change was needed for that assertion. Parent UI validation saved m/s/t and counting maximum 20, verified both after restart, then restored all 24 letters, maximum 10 and muted sound. No fixture injection, uninstall, reset, phone or user AVD was used. [Native evidence](../artifacts/learning-0180/native/).

The final APK passed all three activity smoke checks and an explicit picture hint. Its installed SHA-256 matches the distributable. The final restart retained 360 XP, muted sound, the exact Writing state and 2048 board. The verified isolated emulator was stopped with data preserved. [Final native results](../artifacts/learning-0180/native/results.json).

### Remaining human checks

The 23 new phonemes use explicit IPA synthesis, not a human recording. Automated waveform, file and decoder checks do **not** establish pronunciation, absence of an unwanted vowel, or audible onset on a physical speaker. Audition every sound using the [local listening page](../artifacts/learning-0180/phoneme-review.html) and the actual phone/tablet. Physical touch comfort and TalkBack gameplay also remain manual. Screenshots and headless emulator playback are not substitutes for those checks.


## 0.17.0 Tap Challenge — September 18, 2026

- **577 full Flutter tests passed**. New deterministic coverage exercises spawn balance, deadlines/expiry, once-only taps, score floor, new-record XP, zero/tied/lower scores, exact failed/lost-acknowledgement retries, profile isolation, reset, v1/v2 migration, malformed payload preservation, paused active time, navigation, coverage/resize/background interruptions, alternate skins, screen-reader activation and silent/Haptics-off behavior. Existing Writing, 2048, audio, learning, customization and layout regressions pass with renamed shared progress types.
- **19 Python tests passed**. Offline asset verification passed for **198 recordings** and **1,601 companion assets**. No synthesis or retained artwork regeneration occurred.
- **24 final capture scenarios passed**, producing **96 images** across six sizes, two text scales and both themes. Actual companion assets loaded; representative screens were reviewed. [Gallery](screenshots/0170/README.md).
- Full analysis completed with **zero errors/warnings, 41 informational notices**, exit 1. No file-watcher fallback was needed. Formatting check reported zero changed files. Two initially unused test imports were removed before final analysis; the first full test run's two failures were obsolete expected audio/category counts and were corrected before all 577 passed.
- Approved build script produced **0.17.0+34**, **1,103,648,170 bytes**, SHA-256 `ea17f90814385a9a0cd412d828072636a85a2bcd6bf4e7d5905987436cfb7336`. Same signing key, API 24–36, non-debuggable release and no network/VIBRATE permissions verified. Exactly **261 old assets** are absent; **1,802 retained content/shader files** match the 0.16.0 APK byte-for-byte. The updated foal manifest records only the six active clip types and the pruned authoring source hash. [APK evidence](../artifacts/tap-challenge-0170/apk-verification.json).
- Offline **install-r upgrade on LearningGardenWriting / emulator-5560 passed**. It preserved Player 1, initial 160 XP, muted sound, Writing P/p (letter 2, one completed pair), and the exact saved 2048 board/high score. A visibly played Tap Challenge round saved best **58** and exactly **50 XP** (final **210 XP / level 3**, 60/100 toward level 4). Background/explicit Resume, free zero-score replay without XP, root navigation, restart persistence and installed-APK checksum all passed. Native automation was adjusted for UIAutomator's inability to idle during target changes and Home's preserved scroll position; neither required a production change. [Native results](../artifacts/tap-challenge-0170/native/results.json). The emulator and confirmed-idle task Gradle daemon were stopped with emulator data preserved. No phone/user AVD was touched. Physical haptic feel, timer comfort and TalkBack usability are not established by emulator/widget checks. Earlier physical audio-onset listening remains outstanding.

All logs/baselines are under [release evidence](../artifacts/tap-challenge-0170/). Results below are historical.


## 0.16.0 tablet layout — September 18, 2026

Home's profile/sound/Settings controls now live in a fixed full-width safe-area
header. Writing windows with shortest side ≥600 logical pixels place spare
vertical space above the pads and Skip in the information header. Pad sizes,
Clear, grading, XP, profiles, themes and all other activity layouts are preserved.
Constrained/large-text lessons scroll while Check/Continue stay fixed.

- **543 full Flutter tests passed**, including **34 new tablet regressions**.
  The initial existing Home/Writing check passed all **26 tests**. New coverage
  asserts edge placement and minimum targets, fixed controls through scrolling,
  cutout/navigation insets, reachable profile/Settings gates, bottom tablet pads,
  phone/split-screen behavior, normal pad sizes at large text, preserved ink and
  active-stroke cancellation through 600×960 → 960×600 → 540×900 → 800×1100,
  no ink from blank margins, touch/stylus writing and Clear preserving paired XP.
  The existing suite also covers extra contacts, pad bounds, backgrounding,
  case switching, save retries and all prior gameplay regressions.
- **50 separate capture/check scenarios passed**, producing **432 images**:
  64 focused Home/Writing captures across eight sizes and 368 existing full-app
  flow captures across four tablet orientations. Both themes, normal/200% text
  and reduced motion were exercised. Representative Home/Writing, phone,
  small-tablet, Settings, words, 2048, customization, ordering and Sparkle Pop
  images were inspected; no further screen changes were required.
  [Main gallery](screenshots/0160/README.md) ·
  [Other tablet screens](screenshots/0160-review/README.md).
- Formatting passed for the three changed/new production/test Dart files.
  **Full Flutter analysis completed with zero errors/warnings and the same 45
  pre-existing informational notices** as 0.15.3 (exit 1). No watcher failure or
  fallback this session. Early new-test runs exposed a missing test import and
  an invalid equal-label-height assertion; these were corrected before the
  successful final suite/captures. No production input change was needed.
- Approved build script produced **0.16.0+33**, **1,221,608,606 bytes**, SHA-256
  `2fce978abbab5fefc65d950247899c74c4691910a314f72e807250fd88e81ce7`. Same signing certificate, package, API 24–36, non-debuggable release,
  offline permission constraints and all **2,064 byte-identical content/shader
  files** verified against preserved 0.15.3. Build verification passed for all
  205 recordings, 1,851 foal assets and the normal production entrypoint.
  [APK evidence](../artifacts/tablet-0160/apk-verification.json).
- No device installation/native interaction or physical TalkBack/performance
  checks were performed. The daughter's Lenovo tablet and basic touch stylus
  still need a comfort trial. This layout reduces reach; it does **not** claim
  palm rejection or distinguish a passive pen from a finger. No Undo, new input
  mode, save fields, dependencies, permissions or asset generation were added.
  The earlier physical audio-startup listening check remains outstanding.

Logs, baseline and verification helpers are in
[artifacts/tablet-0160](../artifacts/tablet-0160/). Results below are historical.

## 0.15.3 activity icons — September 18, 2026

Four menu illustrations changed: Alphabet Order (C A / D B), Number Order
(3 1 / 4 2), Writing and Handwriting (shared Aa on practice rules). Existing
labels, icon bounds, semantics and gameplay remain intact.

- **509 existing Flutter tests passed** in the complete suite. No new gameplay
  regression tests were needed for the decorative update.
- **16 separate capture scenarios passed, with 64 images**: 320×640, 393×852,
  740×360 and 800×1100, normal/200% text, Light/Dark. The 200% cases also enable
  reduced motion. Representative phone, small/200%, landscape/200% and tablet
  images were inspected; all scenarios reported no render exceptions.
  [Gallery and reproduction command](screenshots/0153/README.md).
- Foreground/palette calculations passed: ordering text ≥10.83:1, tile borders
  ≥5.14:1, Writing letter strokes ≥13.33:1 and rules ≥4.36:1.
  [Contrast values](../artifacts/icons-0153/contrast.json).
- Formatting passed for all four changed/new production Dart files.
  **Full Flutter analysis completed** with zero errors/warnings and 45 existing
  informational notices, all in untouched files (exit 1). No watcher error or
  fallback this session. No host limits or unrelated processes changed.
- Approved build script produced **0.15.3+32**, **1,221,592,222 bytes**,
  SHA-256 `242fb9a4498b0d0b11fc3d03de0401548bfa213b7fe323fd2f33101c7c2ec541`.
  Existing signing certificate, package, API 24–36, non-debuggable release and
  absence of INTERNET/ACCESS_NETWORK_STATE/VIBRATE permissions verified.
  All **2,064 bundled content/shader files** match preserved 0.15.2 byte-for-byte;
  the build also verified 205 recordings, 1,851 foal assets and the normal
  production entrypoint. [APK checks](../artifacts/icons-0153/apk-verification.json).
- No device installation, native interaction or physical TalkBack check in this
  visual-only session. Previous audio-startup listening limitations still apply.

Logs and the reusable session capture/verification helpers are in
[artifacts/icons-0153](../artifacts/icons-0153/). Results below are historical.

## 0.15.2 audio startup — September 18, 2026

The first prompt waits for the route entrance and painted frame. Native playback
prepends 300 ms of silence to warm the output stream without editing recordings.
The user reports a missing beginning on the phone speaker; this patch addresses
startup timing but still requires a phone listening check.

- **509 full Flutter tests passed**, including 14 new regressions: all five voiced
  activity entries, immediate explicit replay, zero/long transitions with reduced
  motion, and cancellation on mute, correct answer, replay, background, coverage,
  Back and disposal. **74 focused tests passed** before the full suite.
- **205 native WAV checks passed**, proving exact original PCM and header-format
  preservation, exactly 300 ms of zero samples before each recording, and rejection
  of nine invalid/truncated/unsupported input cases. Run with
  `JAVA_HOME=/usr/local/android-studio/jbr tools/test_prompt_audio.sh`.
  This uses existing Gradle/Kotlin tooling with no new test or runtime dependencies.
- Both changed Dart files passed formatting; shell syntax passed. Full Flutter
  analysis hit the known watcher exhaustion (**errno 24**). The watcher-free
  fallback checked **85 Dart files with zero diagnostics**; it is not full linting.
- Approved build script produced **0.15.2+31**, **1,221,592,222 bytes**,
  SHA-256 `87b54b213ed3d32fb150523b8a14ac4f41f4634c425941d31562fd1c6366d384`.
  Original signing certificate, package/version/API levels, no network permission,
  and all **2,064 byte-identical bundled content/shader files** verified. Existing
  audio verification passed for 205 recordings, with no synthesis.

Offline native upgrade on verified **LearningGardenWriting / emulator-5560**
passed all five voiced activity entries and replays. Dumpsys evidence shows all
**10 initial/replay requests decoded PCM successfully**; all five Back checks
released the app's native player. No audio error UI or fatal/audio-failure log
entries were observed. The installed APK checksum matches the distributable.
Player 1's visible level 3 progress (10/100 toward level 4, total 160 XP) and two
moves stayed unchanged; the original muted sound choice was restored and survived
restart. No answers were submitted. The emulator and confirmed-idle task Gradle
daemon were stopped with data preserved. No phone or user AVD was used.
[Native evidence](../artifacts/audio-startup-0152/native/results.json).
The headless emulator does not validate audible onset on the phone.

[Logs and native checks](../artifacts/audio-startup-0152/),
[APK verification](../artifacts/audio-startup-0152/apk-verification.json),
[investigation and phone-listening limitation](audio_startup_investigation.md).

## Audio startup investigation — September 18, 2026 (no release)

**65 focused/diagnostic tests passed** across voice toggles, identification,
Sight Words and five real-navigation entry/replay traces. **205 recordings verified
offline**. First playback is requested before the entrance transition finishes;
no subsequent normal-entry stop was observed. The diagnostic does not reproduce
or measure audible phone clipping. Production code/APK unchanged; no full suite,
full analysis, build or device installation in this investigation.
[Findings, limitations and reproducible evidence](audio_startup_investigation.md).

## 0.15.1 alphabet picker — September 18, 2026

Only the Writing picker layout changed. Columns now include measured letter-pair
width, current text scaling, button padding and grid gaps. Aa–Zz stays on one
line at the existing font size, including Mm and Ww. Matching, feedback, XP,
saved progress, artwork and themes are unchanged.

- **495 full Flutter tests passed**. The new 20-scenario regression also passed
  separately with Roboto and **40 captures**: five screen sizes, normal/200% text,
  both themes. It checks actual rendered glyph bounds/single-line fit, minimum
  touch size, manual selection and shuffle resume without saved changes. Before
  the fix, it reproduced Mm wrapping at Pixel width.
- Formatting passed for both changed Dart files. Full Flutter analysis failed
  at the known host watcher limit (**errno 24**); the watcher-free fallback checked
  **87 Dart files with zero diagnostics**, not a full Flutter lint pass.
- Approved build script produced **0.15.1+30**, **1,221,592,218 bytes**,
  with the existing signing key, normal entrypoint, API 24–36 and no network
  permission. All **2,064 bundled content/shader files** match 0.15.0 byte-for-byte.
  Main APK and checksum updated; installed emulator checksum matches.
- Offline native **install -r** on verified **LearningGardenWriting / emulator-5560**
  preserved Player 1, **160 XP / level 3**, two moves, muted sound and Writing
  **P, letter 2, one completed pair**. All 26 pairs were present; light/dark
  captures visibly show Mm/Ww. Manual M/W selection, shuffle resume and process
  restart passed without earning XP or advancing saved progress. Original display
  size/density and Android light mode were restored. No phone or user AVD used.

APK SHA-256: `c3400f0130df5b2a26b983a14a68e2dbb2b075a1b6caae8fc173edcce114323c`.
[APK report](../artifacts/picker-0151/apk-verification.json),
[native results](../artifacts/picker-0151/native/results.json),
[gallery](screenshots/0151/README.md). Physical-device/TalkBack checks were not run.

## 0.15.0 AMOLED Midnight Rainbow — September 18, 2026

Current-session validation for the new per-player System/Light/Dark setting and
complete dark UI. [Design reference](dark_mode.md),
[368-image light/dark gallery](screenshots/0150/README.md), and
[validation artifacts](../artifacts/dark-mode-0150/).

- **475 full Flutter tests passed**, including 15 new theme regressions and 16
  whole-app gallery scenarios. A subsequent 15-test focused check passed after
  reviewing enabled Writing action contrast. Captures and the contrast assertion
  wait for the enabled-state text animation to finish; no production change was
  needed for that timing issue. The final gallery run covers both
  palettes at 320×640, 393×852, 740×360 and 800×1100, normal/200% text; 200% uses
  reduced motion. It captures 23 screen/state families per configuration.
- Appearance tests cover all six preference/system combinations, absent versus
  malformed settings, profile separation, restart, reset, sound/case retention,
  Save versus Back, delayed/failed writes and exact retry after route exit.
  Live changes preserve the question and 800 ms automatic deadline, completed
  handwriting and an active stroke. Actual pixels verify #000000 page backgrounds.
  Palette tests cover reading contrast, 14 distinct 2048 colors, higher-value
  fallback, stationary/sliding tiles, and Writing guide/ink/direction contrast.
- Formatting passed. Full `flutter analyze` failed at the known host file-watcher
  limit (errno 24); the watcher-free fallback checked **86 Dart files with zero
  diagnostics**. This is **not a full Flutter lint pass**. No host limits or
  unrelated processes were changed. No Python production/tooling code changed;
  the historical Python suite results are not represented as new checks.
- The approved build script produced **0.15.0+29**, **1,221,592,218 bytes**, using
  the existing debug signing key and normal entrypoint. Package/API 24–36 and
  offline permissions verified. **2,064 bundled asset/shader files are byte-for-byte
  identical to 0.14.0**, including all audio and unicorn/scenery assets. There were
  no synthesis, rendering, dependency or permission additions.
- Native `install -r` upgraded verified **LearningGardenWriting / emulator-5560**
  from 0.14.0 while offline. It retained Player 1, **160 XP / level 3**, two moves,
  muted sound and Writing **P, letter 2, one completed pair**. Missing appearance
  initially followed Android. System changes immediately switched the Home and
  Writing backgrounds; the current Writing target/position remained identical.
- Native checks verified unsaved Dark still follows saved System, persisted Dark
  overrides a light OS, persisted Light overrides a dark OS, both overrides
  survive process restart, and switching back to System restores live following.
  Captured background pixels are exactly #000000 or #FFFBF5 as appropriate.
  Final preference is **System**, with Android night mode restored to its original
  **no** setting. No learning work was completed or progress reset.

APK SHA-256: `13217fb3f2458825779aa3e855771fdea271fdb6c9258dc49c25cd883df370a1`.
[Artifact/signature/asset report](../artifacts/dark-mode-0150/apk-verification.json)
and [native appearance results](../artifacts/dark-mode-0150/native/appearance-results.json).

Physical Pixel/OLED appearance, TalkBack and power consumption remain manual
checks; emulator screenshots do not measure battery savings. Native startup
resources follow Android until the saved player's appearance loads. No phone or
user AVD was used. The disposable emulator retains its test data.


## 0.14.0 rewards and Writing integration — 2026-09-17

- **444 full Flutter tests passed** against the completed new library and finished
  Writing changes. Reward tests cover catalog/migration, no retroactive excess-level
  gifts, flexible old gifts, future XP from rounds/Writing/2048, exhaustion,
  failed-write retry, polish equip/removal/reset and player defaults/isolation.
  Real-poster/shader tests keep mane, hooves, headwear and wing colors independent.
  Codec/playback tests cover actual five-plane frame size, bounded concurrent
  playback, rewind, lookahead release and coalesced detailed-poster loading.
- **19 Python tests passed** for export/provenance/memory and existing tooling.
  Saved Blender rig validation passed attachment, grounding, loop, expression
  and framing checks. The complete library verified **1,851 assets**. A separate
  **1,200-pose audit** compared all packed/source alpha planes byte-for-byte and
  checked image bounds. Raw AOV antialiasing can exceed color alpha by up to 16;
  the shader normalizes/clamps coverage. All 16 original outfit posters retained
  identical alpha/bounds; maximum opaque RGB RMS difference was **0.115/255**.
- **128 UI captures** cover four sizes, normal/200% text and reduced motion.
  After fixing capture timing to let tab borders settle, all eight normal and
  eight reduced-motion gallery tests passed. The explicit renderer review passed
  with 175 base looks, all cosmetic rewards/mixed looks, 25 eight-action pose
  sheets, and 240 bow/twirl plus 960 idle frames. New geometry, recolors, polish,
  mixed materials, action attachments and constrained layouts were visually
  inspected. [Gallery and 60 fps videos](screenshots/0140/README.md).
- Formatting passed: **83 files, zero changes**. Full Flutter analysis still
  crashed at host watcher **errno 24 / Too many open files**, including a final
  retry after build/emulator shutdown. Watcher-free analysis checked **83
  lib/test/tools Dart files, zero diagnostics**; this does not replace Flutter
  linting. Host limits and unrelated processes were not changed.
- Approved scripts built **0.14.0+28**, **1,221,378,890 bytes**, SHA-256
  `99850fa03d7d540c64cc467683dfd319a5011f72a6fd577e70061fc745be0574`.
  Same debug certificate, package/API 24–36, checksum, offline permissions,
  exact companion/content inventory and normal entrypoint verified. All **209
  audio/scenery files** match the preserved 0.13.1 APK; all 205 WAVs remain
  uncompressed. No authoring/review files or profiling entrypoint are bundled.
- Offline native upgrade on verified **LearningGardenWriting / emulator-5560**
  used `install -r` from **0.13.0+26**, preserving Player 1, 60 XP, one move/gift,
  muted sound and Writing P (letter 2, one completed pair). The old gift selected
  new pink polish; restart retained it. No polish restored original hooves and
  also survived restart. Two actual five-question rounds added 100 XP: the first
  granted no extra gift at level 2, the second crossed level 3 and offered one.
  Choosing blue mane retained pink polish independently across restart. Writing
  remained on P with Check visible. Final save: **160 XP, two moves, blue mane,
  pink polish, zero unclaimed choices**. Installed APK hash matches the artifact;
  airplane mode was on and Wi-Fi/data off. No fixture injection or phone use.
  The former high-level exhausted-catalog AVD was absent; that migration case
  is covered by automated tests, not claimed as a native check.
- Peak Blender RSS **5.97 GiB**, peak export group **6.17 GiB**, maximum one Blender.
  The 8 GiB available-memory guard paused once at 7.93 GiB during concurrent
  work. Completed renders were retained. After headroom recovered and the user
  authorized available resources, the remaining run used eight CPU threads and
  four pack workers; minimum available RAM then was 12.18 GiB. The emulator and
  confirmed-idle task Gradle daemon were stopped, with emulator data preserved.
  Logs/reports/native captures are under `artifacts/rewards-0140/`.
- Physical phone appearance, child finger/stylus tolerance and TalkBack remain
  manual checks. Writing preview evidence below is historical; its finished
  source is included in this combined release.

## Writing APK promoted to main — 2026-09-17

At the user's request, the verified Writing preview **0.13.2+27** was copied
byte-for-byte to `artifacts/learning-garden.apk`. SHA-256
`b4257fc47d05a72a92b138cb6d7a8bbf76226843cf15bc675f81fff108323549`, **613,242,431 bytes**. Promotion checks verified the preview
hash, preserved 0.13.1 backup, final main hash and checksum file. The 429 tests
and native checks below are prior validation of these exact bytes; no rebuild,
new tests or device installation was performed for this artifact promotion.
The 0.14.0+28 source and in-progress artwork export remain unchanged.


## Writing refresh alongside reward work — 2026-09-17

**85 focused Writing tests** passed in the shared source, including four
screenshot-derived examples, 52 letters with width/slant variation, 1,300
wrong-letter comparisons, either-case-first saves and independent ink.
**20 final widget tests** passed, with explicit assertions that primary actions
remain visible at normal/200% text and both pads fit typical phone/tablet screens.
The [gallery](screenshots/writing-refresh/README.md) contains **62 captures**.

A separate complete-art preview passed **429 full Flutter tests** and native
offline upgrade/restart checks on verified WritingRefresh / emulator-5562.
Saved uppercase S resumed lowercase; lowercase-first d resumed uppercase D;
both pairs awarded exactly 10 XP. Native replay accepted Q/j/h/u screenshot
approximations; picker practice and repeats left the saved total at **20 XP**.
Both pads and Continue were visible without scrolling at 426.7×952 dp. The
installed APK checksum matches the preview artifact. The user's phone and AVD,
existing Writing emulator, and the other agent's export were untouched.

Preview **0.13.2+27**, **613,242,431 bytes**, SHA-256
`b4257fc47d05a72a92b138cb6d7a8bbf76226843cf15bc675f81fff108323549`. Same debug certificate/API/offline permissions; all **1,398 existing
content/shader files** match 0.13.1. The initial preview run did not replace the main APK; it was subsequently
promoted as recorded above. The combined
reward/artwork release still needs its own final full-suite/build validation.
Full analysis hit watcher errno 24; fallback checked **80 Dart files, zero
diagnostics**, not a full lint pass. Six changed Dart files passed formatting.
The isolated emulator and confirmed-idle preview daemon were stopped. Physical
finger/stylus calibration and TalkBack remain manual. [Full evidence and
integration boundary](../artifacts/writing-refresh/PREVIEW.md).


## 0.13.1 2048 tile colors — historical, 2026-09-17

- **424 Flutter tests passed.** Two new widget tests verify fourteen distinct
  rendered backgrounds, preserved 2–64 colors, text contrast of at least 4.5:1,
  unchanged borders, matching colors while sliding/merging and reuse of rose
  above 16384. Existing save, XP, profile, Writing and 2048 regressions passed.
- All **32 2048 widget tests passed with captures**. The normal board fixture now
  contains every value through 16384, with a legitimately won/acknowledged save.
  Thirty board/victory/game-over images cover five screen sizes at normal/200%
  text. Phone, small-phone/200% and landscape/200% images were visually reviewed;
  all fourteen colors and five-digit tile values are visible. [Gallery](screenshots/0131/README.md).
- Formatting passed. Full Flutter analysis failed at the documented host watcher
  limit, **errno 24 / Too many open files**. The watcher-free fallback checked
  **77 Dart files with zero diagnostics**; this is not a full Flutter lint pass.
  No host settings or unrelated processes changed.
- Approved `tools/build_apk.sh` produced **0.13.1+27**, **613,160,403 bytes**, SHA-256
  `86b259c53181f2874c6ce4ff2c89104a2a48b45f6a6fc96fd9a3e5d137279cd0`. Same debug certificate, package/API 24–36,
  checksum and absence of Internet/VIBRATE permissions verified. All **1,398**
  bundled content/shader files match 0.13.0 byte-for-byte; WAVs uncompressed.
  The build verified **205 recordings, 1,185 foal assets** and exact APK asset
  inventory with no profiling entrypoint. Python tests were not rerun for this
  Flutter color-only patch.
- No device installation/native checks. Previous emulator results below are
  historical. Physical phone color appearance and TalkBack remain manual checks.
  Confirmed-idle Gradle was stopped after building.

## 0.13.0 Writing / paired handwriting — 2026-09-17

- **422 full Flutter tests passed**, including **80 new Writing tests** (62 rule/
  matcher/controller and 18 widget tests). The final singular-count copy fix
  was followed by all **18 Writing widget tests passing** and rebuilding.
  Formatting passed. Full Flutter analysis hit the documented host watcher
  limit, errno 24; fallback analysis checked **77 Dart files, zero diagnostics**.
  This is not a full Flutter lint pass; no host limits were changed.
- Independent synthetic polylines cover all 52 forms with imprecision, reversed
  strokes and horizontal shifts. All **1,300 wrong same-case template pairs**
  are rejected. Tests cover incorrect size/line placement, missing dots/bars/
  tails, mirrored asymmetric letters, blank/trace-only input and scribbles.
  These are not real child recordings, so child acceptance tolerance remains
  a physical-device check.
- Persistence tests cover 300 seeded shuffles, strict malformed-save rejection,
  old saves, saved uppercase, once-only atomic pair XP, retry after failed/lost
  acknowledgements, player isolation, skip/resume and a full 26-pair **260 XP**
  cycle. Widget tests cover touch/stylus, extra-pointer/ink bounds, delayed saves
  with no timeout, retry after navigation, background/resize cancellation,
  preserved finished ink, manual Next, reduced motion/haptics, practice picker,
  replay and reward navigation.
- **46 widget captures** cover 320×640, 393×852, 740×360 and 800×1100 at normal/
  200% text, plus all 52 numbered/arrow guides. Representative phone, landscape,
  picker, lowercase and guide sheets were visually inspected. These are desktop
  renders using installed Roboto/Material fonts. See the [gallery](screenshots/0130/README.md).
- The approved script built **0.13.0+26**, **613,160,407 bytes**, SHA-256
  `d06718c8b4b06f32d57b0964053bd148b4a43af08d0a45a08382c13de84e7511`. It verified all 205 recordings, 1,185 foal assets and exact APK
  inventory. All **1,398 existing content/shader files** match 0.12.2 byte-for-byte.
  Package/API 24–36, checksum and offline permissions verified. Debug signing
  certificate remains `0c9ff0af99704ea0b4d113a8043444fa636181b61481a7256e08a8e9c8f38cd4`.
- **Native offline emulator checks passed** on verified `emulator-5560`, new
  isolated AVD `LearningGardenWriting` (API 36.1, 1080×1920, density 420).
  Airplane mode was enabled and Wi-Fi/data disabled before first installation.
  Baseline 0.12.2 earned 50 XP through normal UI and muted sound. Approved
  `install -r` upgrade preserved Player 1, XP, one move/reward and sound choice.
  Android pointer events drew independent C/c samples on the blank pad; C saved
  before an app force-stop and resumed at c; c awarded exactly 10 XP. Clear and
  rechecking c awarded no more; picker-selected L/l completed with no XP. Return
  to shuffle retained C completion, Next showed P, and restart retained **60 XP**.
  Native screenshots and accessibility XML are in `artifacts/writing-0130/native/`.
- Physical Pixel drawing feel, actual stylus/palm rejection, child acceptance,
  TalkBack and device performance remain manual checks. Native input used
  synthetic polylines, not physical touch hardware. No phone, user's AVD, host
  limits or unrelated processes were modified. Python tooling and Blender tests
  were not rerun because their source/assets are unchanged. Logs are under
  `artifacts/writing-0130/`; the prior APK is preserved there as `baseline-0122.apk`.

The final installed APK hash matches the distributable. Trace-only native input
left Check disabled. The disposable emulator was stopped after verification,
preserving its data; the confirmed-idle build daemon was also stopped (none
remain running). The user's AVD and unrelated processes were untouched.

## 0.12.2 full-panel customization preview — 2026-09-17

- **342 full Flutter tests passed**. The added rendering regression checks
  landscape and portrait viewports for both head/body framing: art appears
  beyond the former focus crop but never leaks outside the viewport. Default
  clipped rendering remains covered. **13 focused rendering/customization
  tests passed**, including saving/retry, gift access, lifecycle cancellation,
  selected semantics and reachable choices at small/landscape/tablet 200% text.
- **16 additional gallery tests passed** for flower-crown/feather-wing outfits
  under normal and reduced motion. Together with the suite's gallery, these
  produced **168 captures** across 320×640, 393×852, 740×360 and 800×1100 at
  normal/200% text: Home, Colors, petting, Headwear, Wings, Celebrations and turn
  preview. Representative normal, small, landscape and reduced-motion tablet
  captures were visually inspected. Supplied screenshots are preserved in the
  [before/after gallery](screenshots/0122/README.md).
- Formatting passed for all five touched Dart files. **Full Flutter analysis
  failed at the host file-watcher limit**, errno 24 / Too many open files.
  The documented `/tmp/rainbow-analyzer` helper was recreated with cached
  analyzer 8.4.1; it checked **70 Dart files with zero diagnostics**. This is
  not a full Flutter lint pass. No host limits or unrelated processes changed.
- Approved script built **0.12.2+25**, **612,865,395 bytes**, SHA-256
  `617763c81d46e1d228ef3b14c4e0c8db3fb95c76c5f1547019cb4b37d9a46b9f`.
  It verified 205 recordings, 1,185 foal assets and the exact APK inventory;
  WAVs remain uncompressed and no profiling/authoring files ship. All **1,398
  content/shader files** match the pre-build 0.12.1 APK digest snapshot.
  Version/package/API 24–36, checksum and offline permissions verified. The
  debug signing certificate SHA-256 remains
  `0c9ff0af99704ea0b4d113a8043444fa636181b61481a7256e08a8e9c8f38cd4`.
- No phone/emulator installation or native check was performed. Pixel visual
  review, TalkBack and frame pacing remain manual. Python tooling, Blender rig
  validation and the separate full animation review were not rerun for this
  layout patch. Logs are retained in `artifacts/companion-0122/`.
- Gallery checks resolved all 11 local links and verified all 170 PNGs,
  including byte-identical copies of the two supplied screenshots. The build's
  Gradle daemon was confirmed idle and stopped; none remain running.

## 0.12.1 companion grounding and Home size — 2026-09-16

- **339 full Flutter tests passed**. **21 profile/interface tests passed with
  captures**, including 320×640, 393×852, landscape and tablet at normal/200%
  text, reduced-motion Home and scrollable controls. **Six additional gallery
  tests passed** with the default pink appearance. The normal gallery fixture
  retains its equipped unicorn; the optional `FOAL_REVIEW_DEFAULT` capture flag
  changes appearance only and retains the fixture's twirl preview behavior.
- The **explicit real-codec review passed**, producing 64 looks, 16 expanded
  action sheets (idle/happy/hop/bow/turn and mirrored midpoints), 240 bow/turn
  video frames and 960 frames for two full idle loops. The managed-image limit
  and release-after-disposal assertions passed. Representative default/equipped
  action sheets and phone, small-phone, landscape and tablet captures were
  visually inspected. These are desktop Flutter checks, not device profiling.
- Formatting passed for all four touched Dart files. Full Flutter analysis
  completed with **zero errors/warnings and 27 existing informational notices**
  (exit 1); no watcher fallback or system-limit change was needed.
- Read-only Blender inspection during planning measured all four idle hoof
  soles at z=0 within 4e-9 units. Their projected centers are approximately
  (447,903), (368,890), (637,854), (558,841) in the painter's 1000-unit canvas.
  The correction changes the Flutter ground shadow, not the model or its rig.
- Approved script built **0.12.1+24**, **612,865,395 bytes**, SHA-256
  `037874f37b74c782873aa56e4190a5cb85aa5826fa7a0fc45c84dedd41b576ef`.
  All 205 audio recordings and 1,185 foal images/segments verified; the APK
  inventory is exact and excludes profiling/authoring files. All **1,398
  content/shader files** match a pre-build 0.12.0 APK digest snapshot. WAVs
  remain uncompressed. Version/package, checksum, API 24–36 and no network or
  VIBRATE permission verified. Signing certificate SHA-256 remains
  `0c9ff0af99704ea0b4d113a8043444fa636181b61481a7256e08a8e9c8f38cd4`.
- No phone/emulator installation or native check was performed. Physical Pixel
  appearance, TalkBack and frame pacing remain unverified for this patch.
  Python tooling and Blender rig validation were not rerun; their earlier
  results below are historical. [Captures and reproduction](screenshots/0121/README.md).
- Gallery validation resolved all 13 local links and verified all 1,350 PNGs.
  Encoded videos contain 960 frames/16 seconds and 240 frames/four seconds.
  Logs are retained in `artifacts/companion-0121/`. The build's daemon was
  confirmed idle and stopped; final Gradle status reports none running.

## 0.12.0 approved unicorn integration — historical, 2026-09-15

- **339 full Flutter tests passed** against the replacement library. Existing
  static-screen boundaries, reduced motion, interruption/cancellation, reaction
  priority, retry, outfit switching and 64 MiB managed-image tests all passed.
  **17 Python tooling tests passed**, including stale source-cache rejection,
  exact APK inventory, extra old-art rejection and profiling-entrypoint checks.
- **72 Dart files formatted, zero changes** on the final format check. Full
  Flutter analysis completed with **zero errors/warnings and 27 existing
  informational notices**, exit 1. No watcher fallback was needed.
- Saved Blender scene validation passed: 44,806 weighted vertices, 173 bone
  attachments, 480 idle samples plus endpoint, zero hoof displacement and idle
  velocity seam, body shift 0.018 model units (below 1% standing height),
  head tilt below three degrees, no breathing/scaling/wing flaps. Bow anatomy,
  headwear clearance, animated jaw/tongue/lashes and camera bounds passed.
- All **128 clips / 16,848 raw frames** passed transparency, 1024-pixel image/mask
  and framing checks; minimum transparent margin was 82 pixels. Preflight
  headwear stills, full turn and two idle loops were reviewed before full export.
  The separate Flutter real-codec review passed and produced all 64 looks,
  16 bow/turn sheets, a bow/turn video and 960 decoded frames for two idle loops.
  All 36 phone/landscape/tablet companion layouts were visually reviewed at
  normal/200% text. All 15 profile capture tests passed, producing 25 images
  including 16 static portraits. [Gallery](screenshots/0120/README.md).
- **0.12.0+23 APK: 612,865,395 bytes**, SHA-256
  `3c7174d626fd07f1afca724e5fec6f9ed8e6c11df9da05021be64d04695fdf66`. It is **138,110,380 bytes smaller**
  than 0.11.1. The rendered library shrank from 666,765,748 to 528,655,321 bytes.
  Quality/resolution/frame timing were preserved. Approved build script, normal
  entrypoint, same signing certificate, API 24–36, no network/VIBRATE permission.
  Exact inventory verified all 1,185 foal assets plus manifest, rejected authoring/
  prior-model files, and confirmed all 205 WAVs (uncompressed) and four scenery
  files byte-identical to the old APK. Profiling marker absent in all app ABIs.
- **1,388 prior review/source/gallery files** verified unchanged. Previous model,
  source, library and APK preserved outside bundled assets. Current raw cache,
  audit reports, logs and native screenshots are in
  `artifacts/playful-spark/release-0120/`. The isolated GPU runtime changed no
  installed packages/drivers or host settings; see the development runbook.

### Native upgrade and playback

Verified **RainbowGarden / emulator-5554** (the disposable AVD, not the user's
Medium_Phone AVD); airplane mode remained enabled with Wi-Fi/data disabled.
The preserved 0.11.1 baseline updated in place through the measurement candidate
and final normal 0.12.0 APK using the approved install script and `install -r`.
The installed final APK SHA-256 matches the distributable.

- Final UI-semantic comparison matched Home, settings, all customization tabs,
  player picker, Numbers and all 16 saved 2048 cells. Player 1 retained **2850 XP,
  seven moves, range 0–20, sound off, Pack 1, Relaxed Sparkle Pop/Tap Next/Haptics
  on, blue/bow/butterfly/hop, score 0 and high score 132**. Private preference bytes
  are inaccessible on this production AVD; this was a UI comparison. Initial
  capture comparison exposed an extra Reset button because of scroll coasting;
  only that non-state label was normalized, preserving every setting assertion.
- Release measurement candidate: **12 outfit changes** saved/selected correctly;
  original choices were restored. Idle resumed after background/foreground.
  Temporarily disabling Android animations produced identical pet crops two
  seconds apart. All original animation settings were restored. The final normal APK was also captured across a pet response: its jaw opens
  and returns to the relaxed mouth. Automated Flutter tests cover reaction priority.
- **120-second sustained idle measurement**, after startup warmup, on the
  software-rendered emulator: 41 timing batches / 7,585 engine frames, median
  **60.0 fps**, batch range **59.02–60.00**, largest interval **66.666 ms**;
  median batch raster p95 **17.719 ms**. Managed decoded images peaked at
  **28,311,552 bytes (27 MiB)** against the shared **64 MiB** limit. Process PSS
  changed from **102,231 to 97,792 KiB** and RSS from **189,080 to 186,088 KiB**.
  Timing batches include startup around the steady sample. Engine cadence does
  not prove unique animation-frame throughput; managed accounting excludes
  internal codec/GPU caches and total process memory. The final normal APK was
  built and installed afterward, with instrumentation explicitly rejected.

No physical-phone performance, listening, haptics or TalkBack pass was run.
Emulator and widget results do not substitute for those checks. App production
Dart logic, game/audio content, public APIs, saves and dependencies are unchanged.

The disposable emulator and confirmed idle build daemon were stopped after validation.

## 0.11.1 2048 Game over — historical session, 2026-09-15

- **339 Flutter tests passed.** Five added tests cover delayed final save/animation, failed final move and failed popup restart with retry, background/covered completion and terminal-win priority. The existing finished-board test now covers dismissal, no duplicate popup after resume, reentry, direct reset and retained XP/high score. Existing profiles, persistence, learning, voice, companion and 2048 regressions passed.
- All **30 2048 widget tests passed with captures**: board, victory and Game over at 320×640, 393×852, 411×731, 740×360 and 800×1100, normal/200% text. Checks include visible reset buttons of at least 56 dp, functioning restart and no layout exceptions. Representative phone, small-phone/200% and landscape/200% popup images were visually reviewed. Capture boundary includes the dialog overlay and hides the test debug banner. [30-image gallery](screenshots/0111/README.md).
- Formatting passed. Full Flutter analysis completed with **zero errors/warnings and 27 informational style notices**, exit 1; no watcher fallback needed. The approved build script verified **205 recordings and 1,185 foal assets**. Python tooling tests were not rerun for this Dart UI-only change.
- **0.11.1+22** APK: **750,975,775 bytes**, SHA-256 `0bc6af1e39644e0a677c16d838a4ad6a96b9efa6dc16cb56962b341762008b24`. Built with `tools/build_apk.sh`, normal entrypoint. Checksum, same debug certificate, package/API 24–36 and absence of Internet/VIBRATE permissions verified. All **1,398 bundled content/shader files** match 0.11.0 byte-for-byte; WAVs remain uncompressed.
- No device installation/native checks for this popup patch. The disposable emulator remains stopped on 0.11.0; native profile/persistence checks below are historical. Physical TalkBack and phone interaction remain manual. No native, save-format, asset or dependency changes. Gradle was confirmed IDLE and stopped after building, in keeping with the user's memory-cleanup preference.

## 0.11.0 local profiles — historical session, 2026-09-15

- **334 Flutter tests passed**, including 29 new profile model/widget tests. Coverage
  includes independent progress and every setting, default players, stable names/IDs,
  remembered selection, profile-scoped reset/delete, malformed payload recovery,
  delayed/failed writes, exact retries and lost acknowledgements. Existing learning,
  audio/pacing, Adventure, customization and 2048 regressions passed.
- All **15 profile widget tests passed with captures enabled**: 25 Home/picker/editor
  and portrait captures across 320×640, 393×852, 740×360 and 800×1100, normal/200% text,
  plus all 16 mane/headwear portraits. Keyboard inset, reduced motion, accessible
  labels/selection, portrait taps and short-screen retry access are covered.
  [Gallery](screenshots/0110/README.md).
- **Full Flutter analysis completed** with zero errors/warnings and 27 informational
  style notices (exit 1). No watcher fallback was needed. Formatting passed for
  70 Dart files. **10 Python tooling tests passed**. The build script verified
  all 205 recordings and 1,185 foal assets.
- Final **0.11.0+21** APK: **750,893,855 bytes**, SHA-256
  `fb4edbdb1d328217a00f2fe03b1d2ae376d3402f7848517a876a7136c2750858`.
  Built with `tools/build_apk.sh`, normal entrypoint and existing debug signing key.
  Checksum, version/package/API 24–36, same certificate and absence of network
  permissions verified. All **1,398** existing bundled audio/art/shader files are
  byte-identical to 0.10.1; all 205 WAVs remain uncompressed.

Initial regression runs exposed a 2048 object-identity regression in the new save
publication path; preserving the exact committed in-memory state restored its
animations, input guard and once-only feedback. Visual review caught a cached-art
placeholder flash and cramped large-text names. A targeted failure-state test also
caught a short-screen overflow; save status now scrolls inside the picker. These
were fixed before the passing final suites/build. Initial fixture/compiler errors
were corrected; they are not release validation results.

### Offline native upgrade and isolation

Verified **RainbowGarden / emulator-5554** before interaction. The installed
0.10.0+19 upgraded offline through `tools/install_apk.sh` with `install -r`.
The installed SHA-256 matches the final 0.11.0 artifact. Airplane mode remained on.

- Migration retained **Player 1: 2850 XP / level 17, 150/200 toward level 18,
  seven moves, range 0–20, sound off**. The exact 2048 board survived: two 2 tiles
  at row 1/column 1 and row 3/column 1, score 0/high score 132.
- The shared gate added temporary **TestSam** at level 1, 0–10 and sound on.
  Selection survived force-stop/relaunch. Saving its range as 0–11 and switching
  back/forth verified independent settings and unchanged Player 1 progress.
- One five-question Uppercase round earned **exactly 50 XP only for TestSam**.
  Its Flower crown reward appeared in its pink-maned portrait beside Player 1’s
  blue/bow portrait. Rename to **TestRobin** retained progress/settings and
  survived another process restart.
- Canceling deletion retained the test player. Confirmed deletion removed only
  that player and selected Player 1. Deletion of the last player was disabled.
  Final native checks confirmed Player 1’s **blue mane, Pretty bow, Butterfly
  wings and Happy hop**, original XP/moves/range/sound and exact 2048 board.
  No original-player XP was earned and no original moves/plays were consumed.

Native screenshots are in the [gallery](screenshots/0110/README.md). Serial-checked
helpers, XML captures and logs are `/tmp/learning_profiles_native.py` and
`/tmp/learning-profiles-*`; these are session evidence, not general phone scripts.
The host-rendered emulator later logged OpenGL synchronization errors, a QEMU
main-loop hang and exit 139 after the completed checks. This was an emulator
process crash, not a reported app exception. Restarted the same AVD using
`-gpu swiftshader_indirect` (no data wipe or persistent GPU setting change).
The cold restart verified Player 1 alone, 2850 XP, seven moves, sound off, 0–20,
Pack 1 and the exact 2048 board/high score 132. Then `adb emu kill` shut it down
cleanly. The confirmed idle Gradle daemon and its Kotlin compiler were stopped;
no emulator/build daemon remains. The APK checksum still matches.

Physical Pixel listening, haptics, TalkBack interaction and frame timing remain
manual; automated semantics and emulator UI inspection are not a physical
TalkBack pass. No phone or user-owned AVD was changed.


## 0.10.1 always-vertical word choices — 2026-09-15

- **305 full Flutter tests passed** (`/tmp/learning-0101-tests.log`). Existing word-layout checks now cover Pack 1 alone and all packs across 320×640, 393×852, 740×360 and 800×1100 at normal/200% text. They assert full content width, shared left alignment, 12 dp vertical gaps, readable text, saved selection and two completed rounds. Recognition position/feedback, letters/numbers, voice, settings, reward and companion regressions passed.
- **20 Sight Words widget tests passed with captures enabled**, producing 16 current game screenshots (`/tmp/learning-0101-gallery.log`). Representative phone Pack 1, small phone at 200% text and tablet combined-pack layouts were visually reviewed. [Gallery](screenshots/0101/README.md).
- Full `flutter analyze` completed with **zero errors, zero warnings and 27 informational style notices**, exit 1 (`/tmp/learning-0101-analyze-final.log`). No watcher fallback was needed. The one added multiline test-style notice was corrected before this final analysis; capture tests then passed. Formatting passed for both changed Dart files.
- `tools/build_apk.sh` produced the normal **0.10.1+20** APK, **750,762,499 bytes**, SHA-256 `6b6e00b666992c1bd283bac4343bd1a34ae71cc9dad174ae15e95f7e36891ff5`. Existing debug signing certificate retained; package/API 24–36 preserved, no Internet/VIBRATE permission. All 205 WAVs remain uncompressed and all **1,398 packaged content/shader files match 0.10.0 byte for byte**. The script verified 205 recordings and 1,185 foal assets; no regeneration occurred. Python generator/export unit tests were not rerun for this UI-only change.
- No phone/emulator installation or native interaction this session. The disposable emulator remains stopped on 0.10.0 with the previous fixture. The build daemon was confirmed idle and stopped. No source skills, companion assets, cloud configuration or host limits were changed. The workspace still has no initialized Git repository.

## Historical: 0.10.0 Playful Spark — 2026-09-15

### Release and assets

- **0.10.0+19**, `artifacts/learning-garden.apk`: **750,762,503 bytes** (about 751 MB), SHA-256 `58f2414c135c64ed3c86e70ba2f8860695253e712c4bae5bdbc798f84a1e334f`. Built and installed through the approved scripts with the normal entrypoint and the same debug signing certificate as 0.9.0. API 24–36 and package ID are unchanged; no Internet/VIBRATE permission.
- All **1,185 foal assets, 205 uncompressed WAVs and four scenery PNGs** match their manifests. All **209 previous audio/scenery files** are byte-identical to 0.9.0. Profiling code, Blender/Python authoring files and obsolete companion atlases are absent from the final APK. Evidence: `artifacts/playful-spark/apk-assets-verification.json`, `final-badging.txt`, `final-permissions.txt`, `final-certificate.txt`, `final-build.log` and `final-install.log`.
- The selected [C concept](../art/foal/references/approved-c-playful-spark.png) was recovered from the earlier session's generated-image folder and preserved with provenance. The previous model, generator, validator, manifest, render logs and 0.9.0 APK are under `artifacts/playful-spark/baseline/`, with recorded hashes. The editable source filename stays `art/foal/gentle_foal.blend`.

### Automated and visual checks

- **297 full Flutter tests passed** against the completed final library (`full-tests.log`). New coverage checks idle resumption after feedback, paused/hidden/reduced/static behavior and 64 repeated outfit/reaction replacements without retaining old frames. Existing question-round and 2048 tests now explicitly assert static idle artwork. Existing reaction priority/duration, retries, lifecycle, shared memory budget, real WebP codecs, shader, static portraits, game/audio/navigation/settings and persistence regressions passed.
- **Ten Python tests passed** (`python-tests.log`); all 205 recordings verified without synthesis. **66 Dart files pass formatting**. Full `flutter analyze` was attempted before and after cleanup; both hit the known host watcher limit (errno 24 / analysis server exit 255). The final watcher-free fallback checked **64 Dart files with zero diagnostics**. This is **not a complete Flutter lint pass**. No system limits or unrelated processes were changed. Logs: `analyze.log`, `analyze-after-cleanup.log`, `analyze-fallback-final.log`, `format-final.log`.
- Read-only saved-model validation passed all eight actions, **13,426 weighted vertices** and **136 invariant accessory attachments**. Idle hoof transforms are fixed; the largest leg-end error is below 0.000001 model units. Body shift peaks at **0.018 units**, below 1% of standing height; the head tilt is bounded by 2.5°. Idle has no body/root scale change or wing flap, keeps the relaxed expression, and has **zero endpoint velocity discontinuity**. Bow anatomy/support and rest-joint regression checks pass (`model-validation-final.log`).
- The proportion sculpt initially exposed a connected-bone editing error: Blender updates child joints while editing their parent. Snapshotting all rest endpoints before transforming them fixed the shortened chain and reversed bow bend. A rest-knee regression protects the correction. Camera framing was widened before export. Final raster checks cover **all 16,848 source frames / 128 clips**, with **at least 60 pixels of transparent margin** (`frame-bounds-final.json`).
- Before full export, inspected neutral/happy expressions, all headwear, full turn and two consecutive idle loops at 256-pixel phone display size. Final Flutter review passed all **64 looks**, bow/turn sheets for every outfit and **960 decoded idle samples** within the managed budget. The full suite produced **36 phone/landscape/tablet companion captures at normal/200% text**; representative layouts were inspected. [Gallery](screenshots/0100/README.md), decoded idle loops (historical file removed during cleanup), bow and turn (historical file removed during cleanup).

### Offline native upgrade and performance

Verified **RainbowGarden / emulator-5554** before interaction. The initial installed 0.9.0 checksum matched the preserved baseline. Airplane mode was enabled with Wi-Fi/data off. The same-key release timing candidate upgraded in place; the final normal APK then replaced it with `install -r`. Its installed SHA-256 exactly matches the final artifact.

Native checks preserve **2850 XP / level 17, 150/200 toward level 18, seven moves, 0–20 range, sound off, Pack 1 and blue/bow/butterfly/hop**. Three outfit/reaction cycles and full bow/turn/replay checks passed, restoring the original outfit. Sight Words, explicit hints and the saved 2048 board were checked: two 2 tiles at row 1/column 1 and row 3/column 1, score 0/high 132. No XP, moves or plays were earned/consumed. Logs: `native-baseline.log`, `native-profile-check.log`, `native-animation-check.log`, `final-native-check.log`. Native animation recording (historical file removed during cleanup) is from the timing candidate; `final-*.png` captures show the normal installed APK.

The temporary same-content **release-mode candidate** measured **120 seconds** of home idle after stopping the confirmed idle build daemon. Across **37 timing windows**, engine cadence ranged **57.05–60.00 fps**, median **60.00 fps**; raster p95 ranged **1.413–18.445 ms**. Occasional frame intervals reached **133.344 ms**, with raster maxima **142.246 ms**: do not describe playback as uniformly smooth. Managed decoded images ranged **19–35 MiB**, with **35 MiB peak**, below the shared **64 MiB** cap. That cap excludes codec/GPU internals. Five process samples ranged **78,413–90,453 KiB PSS**; after repeated outfits, PSS was **91,478 KiB**. Evidence: `idle-measurement.json`, `idle-timing-summary.json`, `timing-idle.log`, `memory-idle-*.txt` and `memory-after-outfits.txt`.

These are **emulator observations**, not physical Pixel frame pacing, listening, haptics or TalkBack results. No phone was connected or installed to. The disposable emulator is stopped on the final normal 0.10.0+19 APK; idle Gradle/Kotlin processes were stopped. The user's AVD, source skills, work cloud configuration and ADC were untouched. No usable Git repository exists; no commit or clean-tree claim.

## Historical: 0.9.0 rigged unicorn + Sight Words — final combined release, 2026-09-15

- **0.9.0+18**: `artifacts/learning-garden.apk`, **868,660,843 bytes**, SHA-256 `5443a8f7a482c72f42987ab927d401471b7d80e70848c006a8905a9c70807a12`. Approved build/install scripts used with the normal entrypoint. Package/API 24–36 and existing debug certificate preserved; no Internet/VIBRATE permission. All **205 uncompressed WAVs, 1,185 foal image/clip assets and four scenery PNGs** match their source manifests. All 166 prior audio/scenery files match 0.8.2. Compiled hair shader is present; old companion atlases, Blender/Python source and `FOAL_TIMING` are absent. Evidence: `artifacts/foal-3d/apk-assets-verification.json`, `final-certificate.txt`, `final-badging.txt`, `final-build.log` and `final-install.log`.
- **295 full Flutter tests passed** after the final static-celebration-card correction (`full-tests.log`). Coverage includes actual animated WebP decoding, merged/held frames, lossless visible-hair mask alpha, premultiplied-edge recoloring, outfit cancellation/replacement, retry latching, mid-clip failure/disposal cleanup, shared decoded-image budget, distinct static thumbnails, reaction durations, reduced motion and layout/lifecycle regressions, alongside Sight Words and all existing games/settings/persistence.
- **10 Python tests passed**: seven audio-generator and three foal-export tests (`python-tests.log`). Foal tests cover complete metadata, static held segments, exact mask alpha and index-only recovery without rewriting clip bytes. All 205 recordings and the complete export pass offline verification. This session did not regenerate audio; the earlier Sight Words session generated the 43 additions.
- Final full `flutter analyze` **completed with zero errors/warnings and 27 informational style notices**, exit 1 (`analyze-after-cleanup.log`). An earlier final-source attempt hit the known host watcher limit (`analyze-final.log`); the watcher-free fallback checked 64 Dart files with zero diagnostics (`analyze-fallback.log`), not a full lint pass. Ordinary cleanup of this task's disposable emulator and confirmed idle build daemon allowed the full retry to complete. No system limits or unrelated processes were changed. Touched Dart formatting passed.
- Read-only Blender validation passed all eight actions, **13,134 weighted vertices**, **136 accessory attachments** invariant across every animation frame, backward foreleg fold, three grounded support hooves during bow, full-turn endpoints and representative camera bounds (`model-validation.log`). EEVEE source/export is reproducible from `art/foal`; normal builds only verify. A late exporter index error for fully held WebP frames was corrected and recovered from complete renders/packed clips using `--index-only`; no incomplete manifest remains.
- Explicit final art review passed: all **64 looks**, 16 outfit bow/twirl sheets and a four-second 60 fps renderer video (`review.log`). Twelve Sight Words widget tests passed again with the finished model and 24 refreshed captures (`words-gallery.log`). Companion captures include phone/landscape/tablet at normal/200% text. [Gallery](screenshots/090/README.md), renderer animation (historical file removed during cleanup).

### Native upgrade and performance

The verified disposable **RainbowGarden / emulator-5554** ran offline (airplane mode, Wi-Fi/data off). The final normal APK was installed in place and its installed SHA-256 matched the artifact. Root home, equipped preview, Sight Words with saved Pack 1, explicit hint and 2048 were checked. Existing **2850 XP / level 17, 150/200 toward level 18, seven moves, range 0–20, saved sound off, all twelve rewards and blue/bow/butterfly/hop** remain. 2048 retains its two 2 tiles at row 1/column 1 and row 3/column 1, score 0/high 132. No XP, moves or saved plays were consumed/earned. Evidence: `final-native-check.log` and `final-*.png` in the gallery.

A temporary release timing entrypoint with the **same final runtime and assets** exercised bow/twirl/replay, outfit changes and memory. Crowns and shoulder wings stayed attached throughout the turn; the lifted foreleg folded backward. The original outfit was restored afterward (`native-animation-check.log`). Native recording (historical file removed during cleanup) and `profile-foal-*.png` are from this instrumented candidate, not the shipped normal executable.

Quiet 180-frame windows after warmup measured approximately **60.0 fps engine cadence**, with p50/p95/max vsync intervals about **16.667 ms** (`timing-cadence.log`). Build p95 was 0.39–0.53 ms; raster p95 17.1–17.7 ms and total p95 18.8–19.0 ms. Raster duration is not a direct FPS calculation; this emulator can overlap pipeline stages. Other host-loaded windows had spikes (`timing-home.log`, `timing-customization.log`); do not claim universally jank-free playback. Managed decoded images were **27 MiB**, observed peak **35 MiB**, under the shared 64 MiB cap. This excludes codec/GPU internals. Home process PSS was **99,867 KiB**, RSS **180,756 KiB** (`memory-home.txt`). These are emulator observations, not physical Pixel performance.

The final normal APK replaced the timing build and was verified marker-free. The disposable emulator and confirmed idle Gradle/Kotlin processes were stopped. No physical phone, user-owned AVD, source skill repository, work cloud configuration or ADC was changed. Physical listening/pronunciation, TalkBack, haptic feel and sustained Pixel frame pacing remain manual checks. No usable Git repository exists; no commit or clean-tree claim.

## Sight Words implementation — historical parallel-session checkpoint, 2026-09-15

The intermediate companion-related failures and temporary APK state below are retained as history. The final combined results above supersede those release blockers. The widget gallery has since been recaptured with the completed companion.

### Automated validation

- **122 focused Flutter tests passed** across `sight_words_test`, `sight_words_widgets_test`, `game_test`, `answer_positions_test`, `success_feedback_test`, `retry_feedback_test`, `number_range_test`, `settings_test`, `category_test`, `identification_voice_test` and `voice_toggle_test`. Log: `/tmp/learning-090-feature-tests-final.log`.
- Coverage includes all seven nonempty pack combinations over 1,000 seeds each, exact 43-word content/case/audio IDs, five distinct targets and three enabled-pool choices, 2/2/1 slots, settings defaults/serialization/immutability, immediate red empty-pack validation and collapsed-section recovery, Back discard, retry after navigation, saved pack preservation, shared voice/hints, audio failure, interrupted 800 ms pacing, once-only fifth-answer XP, reward navigation and replay.
- **12 Sight Words widget tests passed with captures enabled**: 24 home/settings/game captures across 320×640, 393×852, 740×360 and 800×1100 at normal/200% text. Real local Roboto and Material icons are loaded for captures. See the [gallery](screenshots/090/README.md). The companion is incomplete in the parallel session and absent/retry-only in these captures.
- **Seven Python generator tests passed**. All **205 bundled recordings** verified; all **43 new word recordings** have `target-pause-v2` and are byte-identical after reapplying 400 ms pause normalization. All 162 prior manifest entries and recordings are preserved. Only 43 word clips were synthesized using the explicit personal configuration/account/project from the runbook.
- Formatting passed for all 14 touched Dart files. An initial new lifecycle test incorrectly awaited a void callback; that test-only error was corrected before the final passing runs. Initial native helpers assumed visible home controls and an unmerged expansion label; their selectors were corrected without app changes.

### Full-workspace limits

The user confirmed another session is changing the companion renderer and asked this session to leave those edits alone. The full Flutter suite run returned **261 passes and seven failures** while those files were changing: obsolete companion export/test interfaces, incomplete companion assets, companion-dependent widget expectations and a compiler cascade. The final full `flutter analyze` returned **three errors** in the old companion export test, **zero warnings and 43 informational notices**; the watcher limit did not occur. These results are not a successful full regression/lint pass. Logs: `/tmp/learning-090-full-tests.log`, `/tmp/learning-090-final-analyze.log`.

### Isolated Android validation candidate

Source version is **0.9.0+18**. To compile and check Sight Words without replacing the current distributable, the authorized script built an isolated snapshot under `/tmp/learning-090-native-build`. Its validation-only version is **0.9.0+17**, allowing restoration of the existing 0.8.2+17 APK with `install -r`. It is **not a release artifact**, because its snapshot includes unfinished companion assets.

Candidate: 88,052,297 bytes, SHA-256 `1a163234470911ef0a3a5317e9c3d72704ef561b8c3034a8957a45b54c10f6a4`. Native Kotlin compilation passed. Same signing certificate as the distributable (`0c9ff0af99704ea0b4d113a8043444fa636181b61481a7256e08a8e9c8f38cd4`), API 24–36, no Internet/VIBRATE permission. All 205 packaged WAVs match manifest hashes and are stored uncompressed.

Native checks on verified **RainbowGarden / emulator-5554**, with airplane mode on and Wi-Fi/data off, passed: absent-pack default to Pack 1, word-only choices, muted speaker/hint behavior, native prompt playback and Listen again, immediate empty-pack error, invalid Save reopening the collapsed section, Pack 3 save/force-stop/relaunch and game-pool filtering, and Back discarding an unsaved Pack 2 selection. The pack check scrolled to include the offscreen third checkbox. Pack 1 and saved sound-off were restored afterward; no learning round was completed and no progress reset was performed. Initial UI labels and final labels retained level 17, 150/200 XP to level 18, seven moves and range 0–20. Native evidence: `/tmp/learning-090-native-voice.log`, `/tmp/learning-090-native-packs.log`, `/tmp/learning-090-native-finish.log`; [native captures](screenshots/090/README.md) are from the isolated candidate, with the incomplete companion placeholder.

Restoration completed: `tools/install_apk.sh` reinstalled **0.8.2+17** with `install -r`, and a pull of the installed APK matched the existing artifact SHA-256 exactly. The original unicorn rendered normally. Level 17 / 150 of 200 XP, seven moves, range 0–20 and sound-off remained; 2048 still has two 2 tiles (row 1/column 1 and row 3/column 1), score 0 and high score 132. No move was made. The verified disposable emulator was stopped. The build's Gradle daemon was confirmed idle and stopped, including its Kotlin compiler child. The physical phone and user's AVD were untouched; no source skills, system limits, work cloud configuration or ADC were changed.

The existing `artifacts/learning-garden.apk` remains **0.8.2+17**, SHA-256 `2fe4775151fe41e27c26b0ccc131892a3e6a43102ed831491d0c2b930dcd9e9e`. A complete new distributable and full validation must follow completion of the other session's companion work. Physical listening, TalkBack and physical haptic feel were not verified in this session.


## 0.8.2 2048 placement — historical session, 2026-09-15

- Release **0.8.2+17**: `artifacts/learning-garden.apk`, **88,298,902 bytes**, SHA-256 `2fe4775151fe41e27c26b0ccc131892a3e6a43102ed831491d0c2b930dcd9e9e`. Built using `tools/build_apk.sh`; checksum, same debug certificate, package and API 24–36 bounds verified. No Internet/VIBRATE permission. All **177 bundled content/shader files** match 0.8.1 byte-for-byte and WAVs remain uncompressed.
- **248 Flutter tests passed**. The new delayed-save test checks the rendered Start over text/border colors and board/button positions before, during and after save and tile animation, absence of Saving text, guarded restart and committed score. Existing failed-save retry, wins, XP, continuation, gestures, keyboard and lifecycle tests pass. Layout cases now assert portrait score/board/instruction/button order and full normal-text visibility.
- All **25 2048 widget tests passed with captures enabled**: five sizes at normal/200% text, board and victory. Representative phone, small-phone, large-text, landscape and victory images reviewed in the [20-image gallery](screenshots/082/README.md). The capture setup now preloads Gentle foal art outside fake widget time; this corrected missing unicorn artwork in initial test captures.
- Dart formatting passed. Full `flutter analyze` completed with **zero errors/warnings and 36 informational style notices**, exit 1; no watcher fallback needed. All **162 recordings verified** by the build script. Generator unit tests were not rerun for this UI-only patch.
- **No device installation or native checks this session.** The disposable RainbowGarden emulator remains stopped on 0.8.1; prior native persistence results below are historical. Physical one-handed reach, haptic feel and TalkBack were not tested. No gameplay, save format, audio, native code or runtime dependency changes.

## 0.8.1 saved identification voice — historical session, 2026-09-15

- Release **0.8.1+16**: `artifacts/learning-garden.apk`, **88,298,898 bytes**, SHA-256 `389ecb7cb5746aafd5885895f784a57dc2353197fc9639ea5e0a856fee620883`. Built with `tools/build_apk.sh` and installed with `tools/install_apk.sh emulator-5554`. Same Android debug certificate, package and API 24–36 bounds. No Internet/VIBRATE permission; installed APK hash matches the artifact.
- **247 Flutter tests passed** on the final source. Six generator tests and all **162 recording checks** passed; no synthesis. All **177 bundled content/shader files** match 0.8.0 byte-for-byte, with every WAV uncompressed. Formatting passed.
- Sixteen new tests cover shared sound across navigation/restart, default/serialized preferences, pending/failed/retried writes, settings preservation, immediate once-only unmute playback, late audio failures, explicit hints, muted replay, silent rewards, fifth-answer XP conflicts, automatic pacing, lifecycle/route cancellation, static reduced motion and accessible labels. All three identification games fit phone 320×640, landscape 740×360 and tablet 800×1100 at normal/200% text with fixed 56 dp controls. Parent Save/Back/reset regression now asserts sound preservation; prior Letter friends, narration, XP, ordering, 2048 and foal regressions pass.
- Initial full `flutter analyze` completed with **zero errors/warnings and 37 informational style notices**. After a final home mute stop-error guard and brace cleanup, full analysis hit the known inotify **errno 24 / Too many open files** limitation. The documented fallback checked **57 Dart files with zero diagnostics**; this is not a full lint pass for the final source. No system limits or unrelated processes were changed. Initial test fixture errors (missing helper import and Tooltip-versus-IconButton finder) were fixed before the passing final suite.

- Offline in-place upgrade from **0.8.0+15** passed on verified disposable **emulator-5554 / RainbowGarden**, with airplane mode on and Wi-Fi/mobile data off. Home mute survived force-stop/relaunch. Uppercase unmute updated Home and survived restart; lowercase mute shared back to Home. All three muted identification games kept the target hidden with Show a hint available. Explicit lowercase hint revealed the target. Native identification prompts and Number hunt Listen again completed without an audio-error message. Letter friends enabling stayed local; reentry initialized from saved mute. Helper lookups were corrected for range/descriptive accessible activity labels before continuing checks; no app defect was involved.
- Existing **2850 XP / level 17, 150/200 toward level 18**, seven moves, range 0–20 and equipped blue/bow/butterfly/hop remained. No learning round or Adventure play was completed. 2048 retained two 2 tiles at score 0/high score 132. Final Home sound is **off**, intentionally persisted by this check. The disposable emulator was stopped after validation. [Release captures and pulse recording](screenshots/081/README.md) document the UI. Native output was headless with host audio off: physical listening/pronunciation, haptic feel and TalkBack remain unverified on a phone.

## 0.8.0 Gentle foal — historical session, 2026-09-14

- Release **0.8.0+15**: `artifacts/learning-garden.apk`, **88,282,518 bytes**, SHA-256 `9f191074a00bebc793575076ce9be6d780cd956943ccb547a30bca9995a36c37`. Built through `tools/build_apk.sh` with the normal entrypoint after profiling. Same Android debug certificate as 0.7.0, package/API bounds unchanged, no Internet/VIBRATE permission. Installed APK hash equals the artifact. All bundled companion files match workspace bytes; `FOAL_TIMING` is absent from the delivered app library.
- **231 Flutter tests passed** after the final rendering optimization; 14 new tests cover one-shot durations, duplicate taps, hidden/background cancellation, reduced motion, save-before-walk, retry/coalesced asset loads, pose endpoints, turn-frame ordering, actual RGBA transparency/bounds, cache budget, outfit rendering and six size/text configurations. The art setup preloads outside fake widget time; an initial new test run was stopped after a fixture/save-document error and fake-time image-loading stall, both corrected before the final passing run.
- **Six generator tests passed**, all **162 recordings verified**, and all **166 packaged audio/scenery files match 0.7.0 byte for byte**. No audio generation or cloud changes. Dart formatting passed. Full Flutter analysis again crashed at the known host watcher limit (`Too many open files`, errno 24); fallback checked **55 Dart files with zero diagnostics**. Targeted Dart MCP analysis reported no errors. This does not establish a successful full Flutter lint pass.
- Rendered the neutral/colored/expressive foal, **64 outfits**, all **1,024 outfit/turn combinations**, and **36 screenshots** at 393×852, 740×360 and 800×1100, normal/200% text. Reviewed representative portraits, full-body poses, equipment, turns and native screens. The eight-second animation demo (historical file removed during cleanup) uses the real renderer. [Gallery and reproduction instructions](screenshots/080/README.md).

### Installed release and performance

Verified disposable **emulator-5554 / RainbowGarden**, enabled airplane mode and disabled Wi-Fi/data. The approved install script upgraded 0.7.0 in place. Final normal release retains **2850 XP / level 17**, 150/200 XP to level 18, **seven moves**, range **0–20**, all twelve rewards, and original **blue/bow/butterfly/hop** equipment after exercising color/headwear/wing choices. Existing 2048 remains two 2 tiles (row 1/column 1 and row 3/column 1), score 0 and high score **132**; no game move or reset was performed. Native garden and happy response render with correct transparency and shading. A short native twirl recording was captured using the temporary timing build; its artwork is the same as the final build.

The native timing experiment used a temporary **release-mode** entrypoint, the existing key and the approved build/install scripts via a temporary Flutter executable wrapper. It was replaced by the final normal build and verified absent. After 120 warmup frames, 180-frame windows showed customization repainting surrounding cards. Adding a repaint boundary and a static-portrait fast path reduced representative steady raster p95 from **11.7–12.2 ms** to **1.9–2.2 ms**; representative optimized total-span p95 was **9.5–12.0 ms**. Interaction, screen recording and concurrent host work produced higher windows; all captured windows are retained in [timing samples](../artifacts/gentle-foal/timing-samples.json), not averaged into a misleading FPS claim. Android gfxinfo and SurfaceFlinger latency output were insufficient to isolate Flutter animation, so they were not used for this conclusion.

Shared decoded image memory is **35,370,960 bytes (33.7 MiB)**, independent of outfit/route count. Optimized process PSS after warmup was **81,229 KiB**, then **92,615 KiB** and **90,000 KiB** after repeated complete color cycles; no monotonic growth in that short check. These are emulator samples, not a long-duration leak proof. The final normal APK was restored; the disposable emulator was stopped. No physical phone or user AVD was touched.

Limitations: generated turn angles/proportions vary between frames; the sixteen drawings are not geometrically exact 22.5° views. The neutral skin and main joint animations preserve the selected master. Physical Pixel frame pacing, TalkBack and haptic/audio experience remain manual checks. No new runtime dependencies, permissions, native storage methods or save migrations were added.


## 0.7.0 2048 — historical session, 2026-09-14

- Release **0.7.0+14**: `artifacts/learning-garden.apk`, **78,858,092 bytes**, SHA-256 `3d6d0bde77e7cc8b4b885f4737a14111dca3a4307c4f27d58b76e30b10ccd43b`. The approved build script succeeded. Checksum, package/version, API 24–36, same signing certificate against 0.6.2, and absence of Internet/VIBRATE permissions verified. No native interface or runtime dependencies changed.
- **217 Flutter tests passed**, including **48 new 2048 tests** (24 rule/controller tests and 24 widget/layout tests). Coverage includes all merge directions, non-chaining merges, exact spawn probabilities, invalid/no-op moves, seeded games and save round-trips, first-win 500 XP, multiple level gains, continuation, high scores, initialization/restart/acknowledgement failures, delayed and lost-acknowledgement writes, atomic rewards, retry after navigation, parent reset and old/malformed save documents.
- Interaction tests cover all swipe directions and keyboard equivalents, ignored repeats/rapid input, no directional buttons, dialog focus, configured unicorn appearance, once-only win effects, reduced motion, Haptics off, interruption/route coverage, retry, Back/reentry, tile semantics and normal/200% text. Five screen sizes include the shorter 411×731 emulator-like portrait. Normal-text portrait boards fit completely; larger text and victory content can scroll. All **24 widget tests also passed with captures enabled**, producing twenty rendered screenshots.
- Dart formatting passed. Full Flutter analysis failed at the documented host inotify watcher limit (`Too many open files`, errno 24). The documented watcher-free fallback checked **49 Dart files with zero diagnostics**; this is not a full Flutter lint pass. SDK/cache/telemetry access used normal tool escalation. No system limits or unrelated processes changed.
- **Six generator tests passed**, all **162 recordings verified**, and all **166 packaged audio/scenery files are byte-identical to 0.6.2**, with WAVs uncompressed. No synthesis, new artwork or cloud configuration changes.

### Installed release checks

Verified disposable **emulator-5554 / RainbowGarden** before interaction. The approved install script performed an offline in-place upgrade from 0.6.2, retaining **2850 XP / level 17**, 150/200 XP to level 18, seven moves and range 0–20. Numbers offers 2048 independently of that range. Native arrow-key events and swipes play the board. Exact tile values and scores survive Back/reentry and force-stop/relaunch. Canceling Start over retains the board; confirming it creates two new tiles at score zero and preserves the high score and learning XP. Restarted state and high score survive relaunch.

The installed final APK’s SHA-256 matched the artifact. A final native swipe visibly changed the board, all sixteen tile bounds confirmed full portrait visibility, and the final played-board screenshot (score 72, high score 132) matches the restored screenshot. Confirmed restart left a two-tile game at score 0/high score **132**, preserved after another force-stop/relaunch. Learning XP remains **2850**. Twenty rendered and six installed-release captures were produced; representative phone, short-phone, landscape/200% and customized victory images plus native board/restart captures were visually reviewed. The disposable emulator was stopped after verification.

The connected **Pixel 7 (28191FDH2006C5)** was listed but not installed to or interacted with. The user's Medium_Phone_API_36.1 was left untouched. Physical haptic feel/system suppression, an actual attached keyboard, TalkBack play and frame pacing remain manual. The 500 XP victory/continued-play/retry cases were tested through Dart and Flutter widgets; no complete played-to-2048 native session or device save-failure injection was performed.

See the [0.7.0 gallery](screenshots/070/README.md). Temporary evidence: `/tmp/learning-2048-*.log`, `/tmp/learning-2048-apk.json`, `/tmp/learning-2048-native-result.json`, and the `/tmp/learning_2048_*` helpers. These assume the verified disposable fixture and are not general-purpose automation. No usable Git repository was found; no commit or clean Git state is claimed.

## 0.6.2 learning-only voice — historical session, 2026-09-14

- Release **0.6.2+13**: `artifacts/learning-garden.apk`, **78,727,020 bytes**, SHA-256 `ec72ea81addb6957b6b9b93ee36347b687b26d4d2824fdc332280e98501a382f`. Approved build script succeeded. Checksum, package/version, API 24–36, identical signing certificate against 0.6.1, and absence of network/VIBRATE permissions verified.
- **169 Flutter tests passed**. New/updated coverage verifies only question recordings across all four recognition activities and Play again, silent retries and rewards with sound on, preserved haptics, home mute and local matching defaults, hidden reward voice controls, preserved replay choices, and cancellation of preparing audio/late failures on reward entry. Silent destinations retain visual instructions; standard/relaxed mini-game completion and failed saves stay silent. Both ordering rewards are covered with home sound on. Existing save/retry, 2/2/1 positions, navigation, pacing, 0.6.1 placement haptics and normal/200% phone/landscape/tablet layout regressions passed.
- **Six Python generator tests passed** and all **162 recordings verified**. All 166 packaged audio/scenery assets are byte-identical to 0.6.1; WAVs remain uncompressed. No synthesis or native/persistence changes.
- Dart formatting passed. Full Flutter analysis failed at the documented host inotify limit (`Too many open files`, errno 24; analysis server exit 255, Flutter exit 1). The documented watcher-free fallback checked **44 Dart files with zero diagnostics**; this does not establish a full Flutter lint pass. No host limits or unrelated processes changed.

- Offline in-place upgrade from **0.6.0+11** to **0.6.2+13** passed on verified disposable **emulator-5554 / RainbowGarden** using the approved install script. Home retained level 17, 100/200 level XP, seven available moves and range 0–20. My unicorn, Adventure and relaxed Sparkle Pop retained their visual guidance and had no narration controls. No saved play was consumed.
- A five-question Letter friends round with voice on saved exactly **50 XP**, showed a reward with no voice controls, and restored the voice toggle on Play again. Muting hid Listen again without exposing the answer; re-entering the game inherited home sound again. Number hunt Listen again completed offline without an audio-error message. Force-stop/relaunch retained level 17, **150/200 level XP**, seven moves and range 0–20 (fixture now **2850 XP**). No data clearing or debug fixture injection was used.
- [Installed release captures](screenshots/062/README.md) document the changed controls; Sparkle Pop and reward were visually reviewed. The disposable AVD was stopped after checks. The connected Pixel 9 Pro and the user's `Medium_Phone_API_36.1` were not interacted with. Physical listening, haptic feel, TalkBack and device frame pacing remain unverified; the headless emulator has no audio output.

## 0.6.1 placement haptic — historical session, 2026-09-14

- Release **0.6.1+12**: `artifacts/learning-garden.apk`, **78,743,484 bytes**, SHA-256 `e30daed64c59ec1822d7a3a5a178bcae9536f33c216a504ccde106fc12da428e`. Approved build script succeeded. Checksum, API 24–36, package/version, identical debug signing certificate against 0.6.0 and absence of network/VIBRATE permissions verified.
- **164 Flutter tests passed**. Updated regression assertions cover the dedicated placement cue, one request for a swap solving two cards, unchanged light swaps, disabled Haptics and platform-channel serialization/failure handling. Native 80 ms tail scheduling and interruption cancellation were reviewed and compiled, not instrumented on a device.
- Dart formatting passed. Full Flutter analysis crashed at the known inotify watcher limit (`Too many open files`, errno 24). The documented watcher-free fallback checked **45 Dart files with zero diagnostics**; this is not a complete Flutter lint pass. No system limits or unrelated processes changed.
- Build verification passed for all 162 recordings. All 166 packaged audio/scenery assets are byte-identical to 0.6.0, with WAVs uncompressed. Generator tests were not rerun for this haptic-only patch.
- No installation or fresh screenshot capture this session; the prior 0.6.0 gallery and native checks below are historical. No phone/emulator data changed. Physical pulse feel/duration, system suppression and API 24–29 behavior remain manual checks. Temporary evidence: `/tmp/learning-061-*`.

## Historical: 0.6.0 ordering games — 2026-09-14

- Release **0.6.0+11**: `artifacts/learning-garden.apk`, **78,743,488 bytes**, SHA-256 `61b0e530502d34cfaa1c9a3a54d52e2d05c900ad935d922b535a29153abf4514`. Approved build script succeeded; checksum, Android package/version/API 24–36 and identical debug signing certificate verified against 0.5.2. No network or VIBRATE permissions.
- **164 Flutter tests passed**: 141 existing regressions plus 23 ordering tests. New coverage includes full inclusive ranges through 100, 800 seeded board permutations solved without breaking locked positions, valid/invalid swaps, numeric sorting, case-independent identity, fit/target geometry, tap selection, direct dragging, pointer cancellation, background cancellation, cross-screen auto-scrolling with the source row off screen, once-only haptics and final two-card sparkles, reduced motion, live case persistence, delayed/failed saves after disposal, reward navigation and replay. Existing recognition, companion, adventure, settings and speech checks remain passing.
- The **23 ordering tests passed again with captures enabled**, producing [32 layout captures](screenshots/060/README.md): 320×640 and 393×852 portrait, 740×360 landscape, 800×1100 tablet, each at normal/200% text. Each layout covers uppercase/lowercase, 0–10 and 0–100. Tests assert no alphabet/default-range scrolling at normal text, minimum 48 dp cards and reachable final cards when scrolling. Representative captures were visually reviewed; review replaced unsupported arrow glyphs with an A/a label and retained a outlined source slot during dragging.
- **Full Flutter analysis completed** with **zero errors/warnings and 31 pre-existing informational style notices**, exit 1. The host watcher limit did not recur, so no fallback was necessary. Dart formatting completed successfully after allowing the SDK's normal cache access. No host limits or unrelated processes changed.
- **Six generator tests passed** and all **162 recordings verified** offline. All packaged recordings and four scenery PNGs match 0.5.2 byte-for-byte; WAVs remain uncompressed. No cloud synthesis or new assets.

### Installed-release checks

The existing disposable `RainbowGarden` AVD was started from `/tmp/rainbow-avd`; serial **emulator-5554**, AVD name and boot state were verified before interaction. Airplane mode was enabled and Wi-Fi/mobile data disabled before installing through the approved script with `install -r`.

- Before/after upgrade retained **2750 XP / level 17**, seven moves, saved range 0–20 and the existing equipped companion.
- All 26 letters fit the display. A/a changed case in place. Native DOWN/hold/MOVE/UP moved lowercase a into the first slot; it turned green, displayed a check and locked. Completing the board through accessible two-tap swaps locked all 26 and saved exactly **50 XP**.
- See my reward showed the shared reward screen; Back to garden returned to the root home. Force-stop/relaunch retained **2800 XP**, seven moves and range 0–20. Alphabet re-entry retained lowercase but started a fresh unlocked puzzle.
- Number Order displayed all **21 distinct values from 0 through 20**. Leaving unfinished preserved 2800 XP. The native helper initially used “Numbers” instead of the home button's “Numbers. 0–20” accessible label; the remaining range check passed with the corrected label.
- [Native upper](screenshots/060/emulator-alphabet-upper.png), [lower](screenshots/060/emulator-alphabet-lower.png), [drag](screenshots/060/emulator-drag.png), [correct](screenshots/060/emulator-correct.png), [solved](screenshots/060/emulator-solved.png), [reward](screenshots/060/emulator-reward.png), and [numbers](screenshots/060/emulator-numbers.png) captures are from the installed release. Drag/correct frames were visually reviewed.
- The disposable emulator was stopped afterward. No physical phone or user-owned AVD was modified. The connected Pixel 7 was listed but untouched.

Physical haptic feel/distinction, system touch-feedback suppression, TalkBack traversal, audible speech and frame pacing remain **not run**. Emulator gestures, screenshots and semantic assertions do not establish those physical results. No artificial storage timeout or adventure document migration was added. Older migration/recovery manual checks below are historical; their automated regressions ran again.

Evidence: `/tmp/learning-060-*.log`, `/tmp/learning_060_native.py` and `/tmp/learning_060_finish.py` are temporary session-specific diagnostics. No usable Git repository exists here; no commit or clean-tree claim.

## Historical: 0.5.2 Letter friends voice toggle — 2026-09-14

- Release **0.5.2+10**: `artifacts/learning-garden.apk`, **78,153,432 bytes**, SHA-256 `f30052f03423bdb8a70037d3284fe3a59a81c75df769c840842a6f4918f3d8c2`. Approved build script succeeded; checksum, package/version/API levels and unchanged debug signing certificate verified against 0.5.1. No network or VIBRATE permission.
- **141 Flutter tests passed** in the full suite, including 17 new tests. The new tests also passed with captures enabled; after adding explicit on/off semantics and scrolled hint/answer interaction assertions, all 17 passed again. Coverage includes initial voice on/off, both matching directions and pacing modes, silent retries/haptics, fifth-answer save/reward, voiced reward cancellation, Play again, optional hints on mute/audio failure, visit scope, unaffected other activities and customization sound, stale failures after mute/background/coverage/disposal, and failing audio stop calls.
- [12 rendered captures](screenshots/052/README.md) show voice on/off on 320×640 phone, 740×360 landscape and 800×1100 tablet at normal/200% text. Tests check 56 dp button bounds, labels, on/off semantics and reachable hints/answers. Representative captures across all three device shapes were visually reviewed. Large-text and landscape content scrolls; the toolbar stays available.
- Six Python generator tests passed; offline verification passed for all **162 recordings**. Packaged WAVs and all four scenery PNGs match 0.5.1 byte-for-byte; WAVs remain uncompressed. No synthesis, new recordings, dependencies or persistence fields.
- Full Flutter analysis failed with the existing host watcher limit: errno 24, analysis server exit 255, Flutter exit 1. The final watcher-free fallback checked **40 Dart files, zero diagnostics**. It does not replace full Flutter linting. No host limits or unrelated processes were changed.
- Verified **emulator-5554 / RainbowGarden** accepted the 0.5.1 → 0.5.2 offline upgrade using the approved install script (`adb install -r`). Before/after UI retained **2750 XP / level 17, seven moves, range 0–20 and zero gifts**. No debug fixture injection or data clearing was needed.

- Installed-release checks passed for both voice states, muted retries/correction, Next in both matching directions, explicit hints, and restoring the garden state on re-entry. Enabling voice locally while the garden was muted left Uppercase letters muted with its existing hint behavior. Native Listen again returned without an audio error. After restart, 2750 XP, seven moves, range 0–20 and zero gifts remained. No learning round was completed or saved setting changed. [Voice on](screenshots/052/emulator-voice-on.png) and [voice off](screenshots/052/emulator-voice-off.png) captures were reviewed. The disposable emulator was stopped after verification.

Physical audio quality and TalkBack remain **not run**. The headless emulator is muted. A Pixel 7 (`28191FDH2006C5`) was listed by ADB but was not installed to or interacted with; no physical Pixel 9 Pro verification occurred. Widget semantics and playback completion do not establish physical listening or TalkBack behavior.

Evidence: `/tmp/learning-052-*` logs and `/tmp/learning_052_native.py` are temporary, session-specific diagnostics. No usable Git repository was found. Results below are historical unless explicitly repeated above.


## Historical: 0.5.1 retry and home refinement — 2026-09-14

- Release **0.5.1+9**: `artifacts/learning-garden.apk`, **78,137,048 bytes**, SHA-256 `21d4191306a0c59bb6d30d5326ffb24dda6daf4031683930025cdd4c4fcd689a`. Built through `tools/build_apk.sh`; checksum, package/version/API levels, launcher label, and unchanged debug signing certificate verified against 0.5.0. No network or VIBRATE permissions.
- **124 Flutter tests passed** in the full suite. Retry coverage spans all four activities and both pacing modes: 150/450 ms hold/fade, replacement and same-option suppression, independent 600 ms cue cooldown, immediate correction, stationary cards, no partial-round XP, reduced motion, live-region semantics, ignored marker pointers, disabled haptics, platform/audio failures, background, route coverage and disposal. Existing navigation, replay, automatic pacing, persistence and saved rewards remain covered. Final added action-spacing assertions passed in the six layout cases.
- **Six Python generator tests passed**; offline verification passed for all **162 recordings**. Packaged WAVs and four scenery images match 0.5.0 byte-for-byte; WAVs remain uncompressed. No synthesis, new assets, dependencies, permissions or persistence changes.
- Full `flutter analyze` failed with the documented host watcher exhaustion: errno 24, analysis server exit 255, Flutter exit 1. No system limits or unrelated processes changed. The watcher-free fallback checked **39 Dart files, zero diagnostics**. This is not a successful full Flutter lint pass.
- [36 rendered layout captures](screenshots/051/README.md): home at counts 0/1/2/12 and both reward scenarios, at 393×852 phone, 740×360 landscape and 800×1100 tablet, normal/200% text. Bounds checks establish a 40 dp gift, separate badge space, 12 dp label clearance, centered zero-state text, and 16 dp home action spacing with wrapping. Redemption from one reward to zero verifies the saved controller update and accessible label. Representative captures across each device shape and both home states were visually reviewed. These implement the plan’s screenshot scenarios; original screenshot attachments were not available in this context.
- The verified disposable **emulator-5554 / RainbowGarden** upgraded from release 0.5.0 using `tools/install_apk.sh` / `adb install -r`, offline. Before/after home UI retained **2750 XP / level 17, seven available moves, range 0–20**, and zero remaining gifts. No debug fixture injection, data clearing or physical-phone interaction was needed.

- Native release checks opened zero-state customization, replayed bundled letter speech offline without an error, then exercised wrong taps, a different wrong option and immediate correction. [Retry screenshot](screenshots/051/emulator-retry.png) and [MP4](screenshots/051/retry.mp4) show the unobstructed answer, fading marker, replacement and success. Tap Next and Haptics remained on through the upgrade. Restart retained 2750 XP, seven moves, range 0–20 and zero gifts; the unfinished round earned no XP. The equipped blue/bow/butterfly companion remains visible. No settings or adventure writes were made by these native checks. The disposable emulator was stopped after verification.

Physical Pixel checks remain **not run**: retry haptic feel, system touch-feedback suppression, animation smoothness, TalkBack and audible speech quality. The headless emulator is muted. API 24–29 fallback was reviewed in code and compiled, not executed on an older device. Automated semantics, timing and successful playback calls do not establish those physical results.

Current evidence logs: `/tmp/learning-051-*` (temporary). No usable Git repository was found; no commit or clean-tree claim. All results below are historical unless explicitly repeated above.


## Historical: 0.5.0 interface refresh — 2026-09-14

- Final release: **Learning Garden 0.5.0+8**, `artifacts/learning-garden.apk`, **78,137,048 bytes**. SHA-256: `a0646f389d4b44a1c8ba93c3ff8f0ecad4d06edbc93909bb39d6e68e089e592a`. The checksum file verifies. Same Android package and debug signing certificate as 0.4.2; launcher label is Learning Garden. No network or VIBRATE permissions.
- **112 Flutter tests passed** in the complete suite, with capture enabled for layout tests. New refresh tests cover both pacing modes and Play again across all four activities, balanced slots, duplicate answers, 800 ms timing, mandatory fifth pause, failed save/retry, once-only level-up feedback, background/covered-route cancellation, reduced motion, accessible navigation, settings defaults/channel serialization/Save/Back/reset, pet taps, equipped puzzle art, disabled feedback and gift badges at 0/1/2/12. Existing adventure, navigation, persistence, audio interruption and mini-game regressions passed.
- Six layout cases cover 393×852 portrait, 740×360 landscape and 800×1100 tablet at 100% and 200% text. Each exercises Home and rewards with gifts and with the collection complete. The [18-image gallery](screenshots/050/README.md) was rendered and reviewed; large text remains scrollable. Review found a badge/text overlap, fixed with text-scaled reserved space and a separation assertion. Reward Adventure spacing is asserted at 12 dp with and without gifts. The test runner's Ahem fallback is replaced with the installed Roboto font for captures, including custom button styles; no new app font assets were added.
- **Six generator tests passed** and **162 audio files verified** offline. Final packaged WAVs and four scenery PNGs match the prior 0.4.2 APK byte-for-byte; WAVs are stored uncompressed. Existing `target-pause-v2` audio and 400 ms target pauses were preserved, without regeneration.
- Full `flutter analyze` was attempted and failed at the host's exhausted file-watcher limit (`Too many open files`, errno 24; analysis server exit 255, Flutter exit 1). Final watcher-free diagnostic fallback: **37 Dart files, zero diagnostics**. This is not a successful full Flutter lint pass. No system limits were changed and no unrelated processes were stopped.
- The approved build/install scripts produced and installed the release in place on the verified disposable **RainbowGarden / emulator-5554** while airplane mode was enabled and Wi-Fi/mobile data disabled. The installed 0.4.2 release upgraded without clearing data: level 17, seven moves, number range 0–20 and equipped blue/bow/butterfly/hop persisted.
- Native UI checks confirmed Tap Next/Haptics default on for the old save, both off values persisted across restart, and Back discarded drafts. With Tap Next off, a five-answer number round advanced the first four, saved 50 XP at the fifth and waited for See my reward. Both switches were saved back on and verified after a final APK restart. Bundled letter replay returned without an audio error; the verified disposable AVD was stopped after final captures. Final test progress is **2750 XP**, with the same level/moves/range/equipment. Updated emulator captures: [home](screenshots/home-050.png), [puzzle](screenshots/puzzle-050.png), [reward](screenshots/reward-050.png), [settings](screenshots/settings-050.png).

Physical Pixel validation remains **not run**: haptic feel and system touch-feedback suppression, animation smoothness, TalkBack interaction and listening quality. The headless/muted emulator and widget semantics cannot establish these. Native API fallback behavior on API 24–29 was reviewed in code, not executed on an older device. No physical phone or user's regular AVD was modified.

Evidence logs are under `/tmp/learning-*`; they are temporary. No Git repository was present. Results below are historical unless explicitly repeated above.


## Historical release: 0.4.2+7 (2026-09-14)

Letter-case labels and speech now say uppercase/lowercase. Stable activity IDs and audio filenames preserve navigation and save compatibility. The APK is `artifacts/rainbow-garden.apk` (78,120,664 bytes), SHA-256 `b727a713af2701edcfcc56091542e3cbaf9d916aa0305a99c5047202b2b416e1`.

### Checks run in the 0.4.2 session

- **86 Flutter tests passed**. The three added layout tests open all letter activities at 200% text on 320×640, 640×320 and 800×1100 displays. Existing activity selection, matching, answer balance, audio routing, progress, navigation and customization regressions passed with the updated labels.
- **Six Python generator tests passed**, including a new check of all 52 letter phrases and both matching directions. Existing explicit letter pronunciation, immediate 400 ms target pause, normalization, malformed-audio and bundle reuse checks passed.
- **Full `flutter analyze` completed** this session: zero errors/warnings, **22 existing informational style notices** (21 missing-brace notices and one null-aware collection-element suggestion), exit code 1. The host watcher limit did not recur; no host limits or unrelated processes were changed. The watcher-free fallback independently checked 35 Dart files with zero diagnostics. Full linting is not clean because of the informational notices.
- Regenerated exactly **54 WAVs**: `upper_a`–`upper_z`, `lower_a`–`lower_z`, `match_lower`, and `match_upper`. The generator used explicit personal configuration/account/project flags, Puck at 0.9×, and retained `target-pause-v2` processing. The 108 other recordings, including all 101 number prompts, are byte-identical to 0.4.1.
- All **52 regenerated target gaps measured 400 ms** using 10 ms RMS windows at the existing quiet threshold. Complete offline integrity verification passed for 162 clips. These checks verify files and pacing, not perceived pronunciation.
- The universal release APK built through `tools/build_apk.sh`. All 162 packaged WAVs match their manifest hashes and remain uncompressed; exactly 54 differ from 0.4.1. All four paintings are unchanged. Checksum and debug-signing continuity passed; package version is 0.4.2 / code 7, API 24–36, with no network permissions.

### Isolated emulator checks (0.4.2)

Verified `emulator-5554` as the existing `RainbowGarden` AVD before interaction. Installed the final release in place over 0.4.1 with airplane mode enabled and Wi-Fi/mobile data disabled. No phone or user-owned AVD was used.

- The upgrade retained level 17, seven available moves, number range 0–20 and all four selected companion options (blue mane, pretty bow, butterfly wings and happy hop).
- Updated home/category labels and both activity titles rendered correctly. Uppercase and lowercase prompt replay ran offline without exposing an audio error. Matching exercised lowercase → uppercase and uppercase → lowercase targets; the scrollable Next button remained reachable.
- Captured and inspected the category at 200% text in landscape. Temporary display settings were restored. Force-stop/relaunch retained level, moves and range; unfinished matching questions did not award XP.
- Confirmed the installed package was release version 0.4.2 / code 7 and stopped the isolated emulator. No progress fixtures or resets were used in this session.

Screenshots: [home](screenshots/home-042.png), [Letters category](screenshots/letters-category-042.png), [uppercase](screenshots/uppercase-042.png), [lowercase](screenshots/lowercase-042.png), [matching](screenshots/matching-042.png), [landscape at 200% text](screenshots/letters-landscape-042.png).

Physical Pixel listening remains pending for the regenerated letter and matching prompts. Emulator playback and waveform checks do not establish pronunciation quality or listening comfort.

## Historical release: 0.4.1+6 (2026-09-14)

Picture-led customization adds four category tabs, persistent close-up previews, owned-item picture choices and shared earned-reward cards. The APK remains `artifacts/rainbow-garden.apk`; its exact SHA-256 is in `artifacts/rainbow-garden.apk.sha256` and the current handoff.

### Checks run in the 0.4.1 implementation session

- **83 Flutter tests passed**: the original 72 plus eleven focused customization tests. These cover owned-only choices/default removal, tab framing, selected semantics, accessible tap targets, delayed writes and rapid taps, failed writes across navigation, gift collection/retry, closing a sheet during an unfinished save, bounded celebration playback/backgrounding and all owned choices at 200% text on 320×640, 640×320 and 800×1100 layouts. Existing reduced-motion and learning regressions also passed.
- Full `flutter analyze` was attempted and failed again at the host file-watcher limit (`Too many open files`, errno 24). The watcher-free fallback checked **35 Dart files with zero diagnostics**. This is not a successful full Flutter lint pass; no system limits or unrelated processes were changed.
- **Five Python generator tests passed**. Offline audio integrity verification passed for 162 WAVs. All 166 bundled audio/scenery assets are byte-identical to the 0.4.0 APK; all WAVs remain uncompressed. No synthesis or new artwork was needed.
- The universal release APK was built with `tools/build_apk.sh`, version 0.4.1 / code 6. Its checksum and existing debug certificate were verified. Android API levels remain 24–36 and no network permission was introduced.

### Isolated emulator checks

The only connected device was verified as `emulator-5554`, AVD `RainbowGarden` under `/tmp/rainbow-avd`. It ran in airplane mode with Wi-Fi/mobile data disabled. The user's existing AVD and physical phone were not used.

- Installed in place over 0.4.0. Existing level 17, seven available moves, range 0–20, all twelve owned items and gold/star/rainbow/twirl equipment remained available.
- Selected blue mane, pretty bow, butterfly wings and happy hop using pictures. Force-stop/relaunch retained every selection, level, moves and range. Native inspection subsequently confirmed XP 2700, nine spent moves, pending visits `[1, 7, 8, 9]`, best score and all twelve owned items.
- A temporary same-key debug build allowed backup and fixture testing only on this disposable emulator. A level-2 fixture verified gift pictures, single-tap collection, sheet closure and committed flower-crown ownership/equipment. A zero-XP fixture completed five uppercase questions and selected feather wings from the new learning reward cards; native storage confirmed 50 XP and the reward, and the updated companion returned into view.
- The backed-up level-17 document and settings were restored byte-for-byte after fixture testing. The final release APK was then restored and its retained progress and screens checked, including landscape at 200% text. Temporary emulator display settings were restored and the isolated AVD stopped. These fixture rewards were not added to the retained test progress.
- Visual review refined the head crop, reduced card height to fit four choices on the portrait display, separated celebration arrows from selection checkmarks, and corrected the gift button's accessible name. Screenshots of the gift sheet and learning reward cards were captured with the temporary debug fixture; final customization screenshots use the release build.

Screenshots: [colors](screenshots/companion-colors-041.png), [headwear](screenshots/companion-headwear-041.png), [wings](screenshots/companion-wings-041.png), [celebrations](screenshots/companion-celebrations-041.png), [gifts](screenshots/companion-gifts-041.png), [learning rewards](screenshots/learning-rewards-041.png), [home](screenshots/companion-home-041.png), [landscape at 200% text](screenshots/companion-landscape-041.png).

Physical Pixel touch feel, TalkBack traversal, listening and animation performance remain manual checks. Emulator screenshots, semantic tests and successful playback do not establish those results.

## Historical release: 0.4.0+5 (2026-09-14)

The companion adventure replaces flower rewards. The final APK is `artifacts/rainbow-garden.apk`; checksum is in `artifacts/rainbow-garden.apk.sha256`. Its SHA-256 is `f31a33d2a252dec840e0825b3c991107b01e70b89136641a4e53302167ecc00f`.

### Checks run in this implementation session

- **72 Flutter tests passed**. Existing rules, all activities, answer balance, Play again, audio feedback, category navigation and settings coverage remain. New domain/controller tests cover XP boundaries and the four-round cap, deferred/exhausted rewards, valid equipment, move banking, repeated journeys, exactly-once plays, delayed/failed writes, lost acknowledgements, reset coordination, restart and invalid documents.
- New widget tests cover learning → reward choice → root-based Adventure navigation, immediately updated companion equipment, retry after leaving a failed learning save, standard pause/resume, failed play completion after leaving, abandoned relaxed plays, twenty-target consumption, accessible-navigation mode selection, malformed-save parent recovery, all companion layers and phone/tablet/landscape layouts at 200% text. A Star Castle regression verifies the final saved-play button remains reachable at large text sizes.
- Mini-game rules use a controllable active clock for expiry, deadline and duplicate-tap coverage. Widget tests inject a clock where time-sensitive. Animation tests pump bounded durations; they do not wait for decorative loops to settle.
- **Full `flutter analyze` was attempted and failed at the host watcher limit** (`Too many open files`, errno 24). The documented watcher-free fallback reported **33 Dart files, zero diagnostics**. This does not replace complete Flutter linting. No system limits or unrelated processes were changed.
- All **five Python generator tests passed**, and offline integrity verification passed for **162 WAVs**. All **153 target WAVs are byte-for-byte identical to the 0.3.0 APK** and retain `target-pause-v2`; the earlier measured 400 ms cadence is therefore preserved. Six adventure clips were generated/refreshed, including the final fifty-learning-points reward wording.
- The final universal release-mode APK built through `tools/build_apk.sh`. Signature continuity with 0.3.0 passed using the existing Android debug certificate. All 162 packaged WAV hashes match the manifest and remain uncompressed; all four scenery PNGs match the workspace assets. Package version is 0.4.0 / code 5, min API 24, target API 36. No Internet or network-state permission is present.

### Isolated emulator verification

The verified device was `emulator-5554`, AVD `RainbowGarden` under `/tmp/rainbow-avd`, API 36.1. Airplane mode was enabled and Wi-Fi/mobile data disabled. The user's `Medium_Phone_API_36.1` and physical phone were not used.

- The 0.3.0 UI baseline showed **six flowers and range 0–20**. An in-place release APK upgrade started at level 1, zero XP, preserving 0–20. A full number round earned 50 XP/level 2; choosing blue mane, moving to Meadow Gate, standard play completion, background/Resume and force-stop/relaunch succeeded.
- A temporary debug build with the same signing key allowed inspection of persisted preferences. The old flower key was absent, the adventure document contained XP 50, one spent move, blue ownership/equipment, no pending plays after completion, and the destination's standard best. Number range remained 0–20.
- Later-level fixtures were seeded **only in the disposable debug app**, then UI Move actions exercised visits 3–9, all environments and the loop to journey 2. Every move persisted exactly one entitlement; XP, twelve owned items and bests stayed unchanged. The oldest saved play was associated with its original destination.
- An unfinished relaxed play survived force-stop/relaunch. Completing twenty targets consumed only that entitlement, preserved the others, and changed neither XP nor standard bests. Restarted JSON matched the completed state.
- The final release APK was restored after debug testing and rechecked with a gold mane, star crown and rainbow wings. Travel, the corrected reachable Star Castle play, looping to journey two and restart retention passed. A short [travel recording](screenshots/adventure-travel.mp4) is included.
- Native reset and malformed-document recovery were also exercised with the multiplication gate and confirmation dialog. The invalid document remained untouched until explicit reset; range 0–20 and relaxed mode survived reset.
- Screenshots were inspected for home, reward, customization, all four board environments and mini-game entry/play/result. Review found and fixed insufficient bottom space at Star Castle. Flat companion layers remain separate from backgrounds, labels have solid readable surfaces and target controls are large. This was functional/visual emulator validation, not a physical-device performance benchmark.

Current screenshots: [home](screenshots/adventure-home.png), [reward](screenshots/adventure-reward.png), [customization](screenshots/companion-customized.png), [meadow](screenshots/adventure-meadow.png), [stream](screenshots/adventure-stream.png), [woodland](screenshots/adventure-woodland.png), [cloud castle](screenshots/adventure-castle.png), [standard play](screenshots/sparkle-standard.png), [relaxed result](screenshots/sparkle-relaxed-result.png). Artwork prompts are in [ARTWORK.md](ARTWORK.md).

The following release sections are historical; their old APK hashes, flower counts and audio counts do not describe 0.4.0.

## Historical 0.3.0 automated checks

`flutter test` covers 49 tests: five unique round targets, three distinct choices, complete alphabet/number coverage over seeded rounds, varied answer positions, both matching directions, retries, double taps, exact round completion, bundled WAV presence, home/game/Back navigation, hints, reward saving, replay, storage/audio failure recovery, and phone/tablet/landscape layouts at 200% text. Tests also cover range validation, full 0–100 coverage, small three/four-number pools, the parent gate, slider/stepper bounds, save/discard/reload, reset confirmation and retry, and blocking settings until a pending reward commits. Answer-slot tests exercise 1,000 seeded rounds per activity/range, requiring counts 2, 2, 1 with varied sequences. Widget tests inspect actual button coordinates through Next, retries, and Play again in every activity. They verify silent success, a single 550 ms effect, stable card centers and layout widths during the pop, reduced motion, early Next, Back, backgrounding, and active animations at 200% text.

A watcher-free analyzer found zero static diagnostics across the Dart files. Standard Flutter linting remains unverified because its analysis server hit this machine's inotify limit. The version 0.3.0+4 universal APK and its bundled audio built successfully. The five Python generator tests also pass (`python3 -m unittest discover -s tools -p 'test_*.py'`), covering explicit character pronunciation, malformed audio rejection, offline reuse, corruption detection, explicit target pauses, and normalization of quiet gaps with brief noise interruptions.

Release artifact: `artifacts/rainbow-garden.apk`, approximately 65.3 MB, version **0.3.0+4**. SHA-256: `71acabc20384680d4195f1a9bfef7f4357f139658d56ff8cd05903bcb3304775`.

## Version 0.3.0 offline emulator verification

Installed over 0.2.1 in the separate Android API 36.1 emulator with airplane mode enabled and Wi-Fi/mobile data disabled. The upgrade retained five flowers and range 0–20. Both category screens rendered correctly; all three letter games opened and returned to Letters. A number round earned a sixth flower, the reward button returned directly to the home garden, and force-stop/relaunch retained six flowers and the range. The new home and category screenshots are in `docs/screenshots/`.

## Version 0.3.0 automated verification

- Home contains only Letters and Numbers; both open category pages. Tests check grouping, game Back, reward Home, Play again, rapid taps, and shared pending-save blocking.
- All 153 target requests contain a 400 ms break before explicit character/cardinal pronunciation. Five non-target recordings are reused.
- All 158 APK recordings match the manifest hashes and remain uncompressed. Every target clip contains a 380–420 ms interior quiet run when measured using 10 ms RMS windows at approximately −40 dBFS; this verifies the generated files, not just request markup.
- Representative A, Z, 100, and clips with noisy gaps were additionally inspected with waveform silence detection. Final perceived pronunciation and cadence should still be checked on the Pixel.
- The APK signature and checksum passed; no internet permission is present.

## Version 0.2.1 emulator verification

An Android API 36.1 emulator ran in airplane mode with Wi-Fi and mobile data disabled. Installing over 0.2.0 preserved one earned flower and a saved 0–20 range. Completing all four activities saved four more flowers; force-stop/relaunch retained five flowers and the range. Observed correct-answer positions (0 = left, 1 = middle, 2 = right):

| Activity | Positions across five questions |
| --- | --- |
| Uppercase | 1, 0, 2, 2, 1 |
| Lowercase | 0, 2, 2, 0, 1 |
| Matching | 0, 2, 0, 2, 1 |
| Numbers | 0, 2, 1, 1, 0 |

Visual review caught an initial card-width change during the animation; the final layout preserves its constraints and has a regression test for stable center and width. See [celebration recording](screenshots/success.mp4) and [animation frame](screenshots/success.png).

The final APK contains 158 verified, uncompressed WAV recordings and no `correct.wav`. Signature and checksum checks passed; the manifest has no internet permission. No voice regeneration or cloud access was needed for this update.

Release: `artifacts/rainbow-garden.apk`, 62.0 MB, **0.2.1+3**. SHA-256: `03991f71c340e40c72d0b3f9c05c68db08ee7fd3b74c5880d6ab38b4d3b229e9`.

## Earlier Android emulator verification (0.2.0)

Verified the final release-mode APK on a fresh Android API 36.1 emulator with airplane mode enabled and Wi-Fi/mobile data disabled before installation and first launch:

- The documented installation script installed and launched the APK.
- Home and letter-question screens rendered correctly; screenshots are in `docs/screenshots/`.
- A wrong answer allowed retry, a hint revealed the target, and five correct answers earned one flower.
- The reward remained after force-stop and relaunch while still offline.
- The APK signature and SHA-256 checksum verified. All 159 WAVs are present and stored uncompressed for native playback.
- The packaged manifest has no internet or network-state permission.
- Clearing only the disposable emulator's test app data confirmed a fresh 0.2.0 launch, default 0–10, empty garden, and prompt playback with airplane mode still enabled.
- Version 0.2.0+2 installed over 0.1.0+1 with `install -r` and preserved the existing flower; the missing number-range preference defaulted to 0–10.
- A custom 20–30 range saved through exact controls and persisted after force-stop. Five prompts in that range played without reporting audio errors; answers earned a second flower, which persisted.
- Canceling reset preserved both flowers. Confirming reset removed flowers, retained 20–30, and survived force-stop/relaunch.
- All 159 Puck recordings match the generation manifest hashes, decode as 24 kHz mono PCM, and contain non-silent audio. The generator reuses them without authentication or network calls.

The emulator ran without host audio output, so audible voice quality is not verified. The pre-existing emulator had rendering/locked-profile problems; the successful test used a separate disposable emulator in `/tmp` and did not erase the existing emulator.

## Physical Pixel acceptance still pending

No physical phone was connected during the 0.4.0 session. The headless emulator is muted; successful playback, asset hashes and waveform preservation do not establish perceived audio quality or real-device frame pacing.

1. Install the APK with `install -r`, keeping the existing debug key. Confirm the intentional flower reset and preserved number range when upgrading from 0.3.0.
2. Play the identification games in airplane mode. Check pronunciation and the 400 ms target pause, shared Home/identification mute after restart, immediate identification playback on unmute, the gentle muted pulse/static reduced-motion highlight, explicit hints and optional local Letter friends instructions. Verify that rewards, retries, ordering games, Adventure, My unicorn and both Sparkle Pop modes have no app narration.
3. Verify silent correct-answer sparkles, hints, retries, and balanced answer positions. Complete five finds and confirm 50 XP. Play again must keep activity and range.
4. Choose and postpone unicorn rewards, try all accessory/wing combinations and preview celebrations. Check alignment and perceived motion quality on the Pixel.
5. Spend a move; check travel responsiveness, arrival feedback, automatic positioning and journey completion. Leave saved plays for later, including across a restart.
6. Play standard and relaxed Sparkle Pop. Try rapid taps, expiration, background/Resume, Back and force-stop. A completed play requires another entitlement to play again. Scores never add XP.
7. Turn on TalkBack before starting a play: relaxed mode should be selected automatically. Verify target announcements, focus order, free customization, board labels and all controls. Test 200% text, landscape and Android Remove animations.
8. Edit both settings; Back discards drafts and Save applies them. Confirmed reset clears adventure progress while retaining range and mini-game mode.
