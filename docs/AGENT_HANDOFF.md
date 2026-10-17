# Learning Corner: current handoff

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


Snapshot updated **2026-10-17**, after 0.22.2 (branch `feature/new-learning-games-0.21.0`, not merged).
Read [AGENTS.md](../AGENTS.md), [README](../README.md), [design](design.md),
[testing](testing.md) and the [development runbook](DEVELOPMENT_ENVIRONMENT.md).
This handoff is context, not authorization for another feature.


## Current release: 0.22.2+49 — Word Sprint: Activity 2 words, 50-word runs (2026-10-17)

From the second school sheet: 22 new pretend words join Word Sprint's make-believe/Mix pool and runs drop from 60 to 50 words; pretend-word hints play letter sounds only ([design](design.md#word-sprint-activity-2-words-50-word-runs-0222)). A Codex worker made the change; the lead reviewed the diff and ran all checks. **1,028 Flutter tests passed**; full analysis 0 errors/warnings (62 infos); format clean. APK **0.22.2+49**, **670,879,932 bytes**, SHA-256 `3ce792dd741bf719575c2b4de049301df96e3c930a4862f17e3e3d0e1201577d`; same certificate, offline permissions, all 1,992 bundled files byte-identical, no added assets ([audit](../artifacts/new-games-0210/apk-verification-0222.json)). Native check on LearningCornerTest (Codex worker, [report](../artifacts/icons-0220/native-0222/report.txt)): upgrade preserved the fixture; Make-believe run had exactly 50 tiles including all 22 new words with no adjacent repeats; Mix mixed real and pretend words; a new-word hint opened without errors and the timer resumed; best 4 → 6, a lower run kept 6; no XP change; no app errors. Final fixture: Player 1, 1000 XP / level 8, seven gifts, Word Sprint best 6, timer on; emulator stopped with data preserved.

## Previous release: 0.22.1+48 — consistency pass: retry layout, uniform cards, styling (2026-10-17)

Parent feedback on 0.22.0: Number parts' 'Try again' popped over the answers; card heights differed; the Same number icon's 3 looked hand-drawn; new games should match old styling. Codex workers fixed the cards/icon (uniform `SelectionGrid` heights on every category page, typed 3) and the retry/styling pass (constant-height visual-game bottom bar with a reserved feedback line, standard RetryMarker/timing/haptics, answered-content reveal, typography/surfaces aligned with the closest original game — see [design](design.md#consistency-pass-0221)). The Codex emulator test then found Make-believe's third sound card under the bar on entry; the lead generalized the entry reveal to all four visual games and added entry-visibility tests at 411×914, 411×860 and 393×852 (6 failed without the fix, all pass with it). Preferences are recorded in AGENTS.md ("UI consistency for new work").

**1,025 Flutter tests passed**; full analysis 0 errors/warnings (62 infos); format clean. APK **0.22.1+48**, **670,798,012 bytes**, SHA-256 `41590d71487bedd2b4aabdab598d028eff5b3c736183519ce1f0a391dd98795b`; same certificate, offline permissions; all 1,992 bundled files byte-identical, no added assets ([audit](../artifacts/new-games-0210/apk-verification-0221.json)). Native tests on LearningCornerTest (Codex worker): [first pass](../artifacts/icons-0220/native-0221/report.md) — uniform card/icon bounds on all five category pages, typed 3, retry leaves every choice card's bounds unchanged in all four games, Number hunt regression, Word Sprint (no XP), Cursive, persistence, no app errors; [retest of the rebuilt APK](../artifacts/icons-0220/native-0221b/report.md) — all three Make-believe cards and the printed word visible on all five entries, retry bounds stable in all four games, XP 800 → 1000. The entry reveal can scroll the progress stars just above the top (they remain reachable by scrolling). Final fixture: Player 1, 1000 XP / level 8, seven gifts, Word Sprint best 4; emulator stopped with data preserved.

## Previous release: 0.22.0+47 — simpler Cursive play and new activity icons (2026-10-17)

Parent phone feedback on 0.21.1: recordings sound good; Same number pictures are big enough (what to do was not immediately clear — revisit later); Cursive play felt complicated. Decisions are in [design](design.md#simpler-cursive-play-and-new-activity-icons-0220). Sound it out and Word Sprint are not yet phone-tested.

Codex GPT-6.1-Sol workers drew the six icons and rebuilt Cursive play (Handwriting-style two pads, Watch button, upper-right faint-letter toggle and letter/group picker, precision guard on Check); the lead enlarged the Same number icon shapes, reviewed diffs and captures, and ran all final checks. **955 Flutter tests passed**; full `flutter analyze` 0 errors/warnings (62 infos); `dart format` no changes. Captures ([gallery](screenshots/0220/)): 14 icon/category scenarios (`artifacts/icons-0220/icons_review.dart`) and 80 cursive scenarios (`artifacts/new-games-0210/review.dart --name cursive-`) passed with no exceptions/overflows; the lead inspected the icon grids (62×54 and 48 px, Light/Dark), category pages and cursive start/sheet/passed/faint-off captures.

APK **0.22.0+47**, **670,716,116 bytes**, SHA-256 `08159147193725217e1909e7297f148ea03dce441228e2a09271470161ab324b`; same certificate, offline permissions, API 24–36, not debuggable; all 1,992 bundled files byte-identical to 0.21.1, no added assets ([audit](../artifacts/new-games-0210/apk-verification-0220.json)). Native test on **LearningCornerTest / emulator-5570** (Codex worker, [results](../artifacts/icons-0220/native/results.json)): 0.21.1 → 0.22.0 `install -r` preserved the fixture; icons visible and clear; cursive defaults to a / a–z, Watch auto-plays, replays and stops on tracing; both pads, Watch, Skip and Clear/Check fit a 1080×2400 screen without scrolling; scribble rejected, model stroke passed, Next → b; faint toggle keeps ink; Loops walk/wrap and z → a verified; HOME during Watch recovered; XP unchanged by cursive; no Flutter/FATAL/AndroidRuntime errors. (A brief expectation that Handwriting shows a message on empty Check was wrong: Check is disabled until there is ink, as before.) A broad stroke starting at the screen edge can trigger Android's back gesture, as with any edge-to-edge pad. Child freehand tolerance remains a manual check. Final fixture unchanged: Player 1, 550 XP / level 6, five gifts, Word Sprint best 4; emulator stopped with data preserved.

## Previous release: 0.21.1+46 — visual-game feedback in the fixed bar (2026-10-17)

Native testing of 0.21.0 on the disposable **LearningCornerTest / emulator-5570** (Codex worker driving adb; [results](../artifacts/new-games-0210/native/results.json)) passed all 14 checks: 0.20.2 → 0.21.0 `install -r` preserved XP; each new game's round awarded exactly 50 XP; Word Sprint (best, undo, hint pause, early stop, untimed, timer persistence, background → explicit Resume) and Cursive play awarded none; Number hunt showed a look-alike in all five questions; no Flutter/FATAL/AndroidRuntime errors (only the known platform `ashmem` deprecation line). It found that on a 411×914 dp phone 'Try again' and Next sat below the fold for Make-believe words and Same number. **0.21.1** moves feedback and manual Next into the fixed bottom bar for all four visual games (other games unchanged); new layout tests cover it.

**937 Flutter tests passed**; full analysis 0 errors/warnings (62 infos); format clean. APK **0.21.1+46**, **670,896,188 bytes**, SHA-256 `045198a5436dd22922ac71280f32c275f0aa1aaeb9850d202d5c93c67914aabd`; same certificate and offline permissions; all 1,992 bundled files byte-identical to 0.21.0 ([audit](../artifacts/new-games-0210/apk-verification-0211.json)). Native retest of 0.21.1 ([results](../artifacts/new-games-0210/native-0211/results.json)): upgrade preserved the fixture; feedback/Next fully visible without scrolling in all four visual games; Number hunt/uppercase regressions passed; XP 300 → 550; no app errors. Opening the gift sheet clears transient 'Try again' text as in every game (existing interruption behavior, not a regression). Final emulator fixture: Player 1, 550 XP / level 6, five gifts, Word Sprint best 4, timer on, sound on; emulator stopped with data preserved.

## Previous release: 0.21.0+45 — reading, number-sense and cursive games (2026-10-17)

Built from the daughter's kindergarten materials (AVID WICOR number-representation posters, a one-minute nonsense-CVC reading sheet, the teacher's out-of-order number check) and a cursive request. Research (Codex, live web search) is preserved locally in `artifacts/new-games-0210/research/`; decisions are in [design](design.md#reading-number-sense-and-cursive-games-0210).

New: **Read and find**, **Make-believe words** and **Word Sprint** (Words); **Same number** and **Number parts** (Numbers); **Cursive play** (Writing, practice-only, no XP); a shared **Sound it out** hint; and **Number hunt** look-alike distractors. No speech recognition: decoding is verified by taps; Word Sprint keeps only a per-player personal best (no XP) with a saved 1-minute timer toggle (default on). New optional save fields `wordSprintBest` (progress v3) and `wordSprintTimer` (settings) default safely when absent. A `QuestionVisual` payload on `Question`, rendered by `lib/widgets/visual_question.dart`, lets custom tap-choice games reuse the shared round/XP/gift/save flow.

Audio: 34 `cvc_*` Chirp words and 70 `nonsense_*` Gemini phonics-directed IPA prompts were generated with the explicit personal gcloud configuration/account/project (`isolated-word-v1`); the work configuration and ADC were untouched. **Make-believe pronunciations have not been listened to by a person yet**; duration outliers worth a listen: nonsense_koz, nonsense_duv, nonsense_wob, cvc_mad, cvc_net, cvc_pen.

**920 Flutter tests passed** (760 at 0.20.2), including foundation seams, builders over hundreds of seeds, widget flows, cancellation, persistence/migration, 360×640 at 200% text and both palettes. Full `flutter analyze` completed without the file-watcher fallback: **0 errors/warnings, the same 62 informational notices**. `dart format` reports no changes for lib/test. **All Python tool tests passed**, including new generator and APK-verifier cases; `generate_audio.py --verify` confirms **325** recordings. **336 rendered review scenarios / 336 PNGs** (320×640, 393×852, 740×360, 800×1100; Light/Dark; 100%/200% text, reduced motion at 200%) passed with no exceptions or overflows; the lead inspected representative captures, and review-driven fixes (Word Sprint mode picker, landscape grid, centered words; cursive pad above the fold and open bowls; compact Same number row, reading-order hints, dice patterns, simplified Make 10, larger shapes/ten-frame dots) were re-captured and re-inspected. Some dark 200% captures intermittently omit static paint in the harness; layout assertions pass.

APK **0.21.0+45**, **670,896,188 bytes**, SHA-256 `0d7e5f445800e7c7ae97c9684669f34fdfd20ab3c5c8dff42fd95e4651d1f65c`. The audit verified the original signing certificate, package/label/entrypoint, API 24–36, not debuggable, and no INTERNET/network/RECORD_AUDIO/VIBRATE permission. All **1,852** previous content/shader files are byte-identical; the two audio manifests were updated and exactly **140** files were added (104 `cvc_*`/`nonsense_*` recordings, 34 word pictures plus manifest and license). [APK](../artifacts/learning-corner.apk) · [Evidence](../artifacts/new-games-0210/README.md) · [Gallery](screenshots/0210/README.md).

Work was done on branch `feature/new-learning-games-0.21.0`. Codex GPT-6.1-Sol workers did the research (5 reports), foundation seams, all six game implementations, Number hunt distractors, the capture harness and the review fixes; the lead session planned, curated the word bank/pictures, generated audio, fixed integration issues (2048 description regression, foundation/phrase-count tests, number shape sizing), ran all final checks, built and audited the APK. No device or emulator was used; physical touch, listening and TalkBack review remain manual. Follow-ups: stretched continuous-blend recordings, joined cursive, parent stage settings for word sets (activity icons were added in 0.22.0).

## Previous release: 0.20.2+44 — compact uniform Numbers cards

All five Numbers cards now share one compact height, restoring **102 logical pixels at normal phone text**. The settings icon sits above the saved range on the right, replacing each applicable game's play arrow. The footer is removed; 2048 retains its description with neither arrow nor settings. Launching and range editing remain separate accessible actions. At large text on narrow cards, artwork stacks above the title and ranges may wrap; all five cards expand together without reducing text scale. Home and other category layouts are retained.

**760 full Flutter tests passed**, plus **61 focused checks** and **16 rendered scenarios / 240 PNGs**. Extended checks assert equal heights across all five cards, original normal-text phone height with real fonts, independent actions, centered range controls at least 48×48 dp, and fitting 0–100 / 98–100 labels. Representative phone/tablet views at normal/200% text were inspected. Final formatting passed for all **3 changed Dart files**. The full suite emitted 12 nonfatal tap hit-test warnings; all tests passed. Full Flutter analysis hit the known host file-watcher limit (`errno 24`, too many open files). The documented watcher-free fallback checked **96 Dart files with zero diagnostics**; full Flutter linting remains unverified for this release. No host limits or unrelated processes were changed.

APK **0.20.2+44**, **662,129,648 bytes**, SHA-256 `711018b573aa33507cfb37034c3216eaffd05744504b8e4790b0da969d2812f3`. The approved build and release audit verified the original signing certificate, application identity/label, normal release entrypoint, API 24–36 and offline permissions. All **1,852 bundled content/shader files** match 0.20.1 byte-for-byte, including 221 recordings. No save format, native API, dependency or asset changes. [APK](../artifacts/learning-corner.apk) · [Evidence](../artifacts/compact-cards-0202/README.md) · [Gallery](screenshots/0202/README.md).

No device or emulator was started or installed during this release; earlier native upgrade results remain historical. Physical touch and full TalkBack exploration remain manual. Confirmed-idle project Gradle daemon 562177 was stopped after checking its last build directory. Scoped escalation was required for the existing bwrap failure; no host, SDK, cloud or source-skill settings changed.

## Previous release: 0.20.1+43 — range shortcuts inside cards

The settings icon and current range now sit in the **bottom-right corner inside each applicable Numbers card**, sharing its background and rounded border. The main illustration/title/play area starts the game; the footer remains a separate accessible shortcut to its parent-gated range editor. The footer has 12 dp horizontal and 8 dp bottom padding, no divider, and a minimum 48 dp touch target. Cards without a shortcut retain their prior layout.

**61 focused Flutter tests passed** (range widgets, interface refresh and learning expansion), plus **16 rendered layout scenarios / 224 PNGs**. All four shortcuts remain within their card surfaces with touch targets at least 48 dp; existing tests cover separate semantics, normal game entry, parent-gated editing and saved range updates. Representative phone/tablet renders at normal/200% text in both themes were inspected. Both changed Dart files passed final formatting. Full `flutter analyze` hit the known host file-watcher limit (`errno 24`, too many open files). The documented watcher-free fallback checked **96 Dart files with zero diagnostics**; it does not replace full Flutter linting. No system limits or unrelated processes were changed.

APK **0.20.1+43**, **662,096,880 bytes**, SHA-256 `dfaa231e622140ef2df9c4ffd9a846d3d9b23e35f3db87bd7f68a84b10a6ca58`. The approved build and audit verified the original signing certificate, package/label, API 24–36, normal release entrypoint and offline permissions. All **1,852 bundled content/shader files** match 0.20.0 byte-for-byte. No persistence, native API, dependency or asset changes. [APK](../artifacts/learning-corner.apk) · [Evidence](../artifacts/card-range-0201/README.md) · [Gallery](screenshots/0201/README.md).

No device or emulator was started or installed during this layout-only release. Earlier native upgrade results remain historical; physical touch and full TalkBack review were not performed.

## Previous release: 0.20.0+42 — independent game ranges and automatic settings

Each player now has separate inclusive ranges for **Number hunt**, **Number Order**, **How many?** and **Make a group**. Identification/ordering are capped at 100; counting/grouping at 20. Defaults remain 0–10 with at least three values. Existing shared ranges migrate to hunt/order, and the old counting maximum seeds both counting games; malformed data stays recoverable. Open the parent-gated editor from a Numbers activity's range shortcut or the game's upper-right range control. Exact Start/End buttons, slider and presets save immediately. Closing a changed editor restarts the round once, after saving; unchanged/canceled editing preserves work. Unfinished work earns no XP.

All main Settings also apply and save immediately, including appearance, Tap Next, Haptics, Sight Words and phonics selections; Back keeps edits. There is no Save button. The final required word pack or third distinct phonics sound cannot be removed. Immutable pending writes retain exact retry snapshots, coalesce newer edits, stay attached to the originating player and block progress/profile operations until saved. Native storage API and profile envelope version remain unchanged. The 0.19.2 Home greeting is preserved. [Design](design.md), [gallery](screenshots/0200/README.md).

**760 full Flutter tests passed**, plus **137 final focused regression checks** and **16 rendered scenarios / 224 PNG captures**. Full analysis completed with **zero errors/warnings and 61 informational notices** (exit 1); no watcher fallback. Formatting checked **27 Dart files**, zero changes. The full suite emitted 13 nonfatal tap hit-test warnings; all assertions passed. Layout fixes preserve 56 dp header actions and scrollable completion controls at 320 px/200% text. [Validation](testing.md).

APK: [artifacts/learning-corner.apk](../artifacts/learning-corner.apk), **662,096,880 bytes**, SHA-256 `67367fcac685e7b1578eb39140248ed3eb1bf9dd7edc3ace9bd084c21dd07e7b`. Same signing certificate, API 24–36, offline permissions and all **1,852 unchanged content/shader files**, including 221 recordings, verified against preserved 0.19.2. No dependencies, assets, cloud generation or native API changes. [Release evidence](../artifacts/number-settings-0200/README.md).

Offline `install -r` on verified **LearningGardenWriting / emulator-5560** passed independent ranges (hunt 2–10, order 1–20, counting 0–5, grouping 1–15), changed-range restart, immediate appearance and Tap Next saves across process restarts. The final Writing P/p state, exact 2048 board, **560 XP / level 6** and **three gifts** match the baseline; muted sound is retained. Original System appearance and Tap Next on were restored. Installed version/checksum match the distributable. The emulator was stopped with data preserved; no phone or user AVD was touched. [Native evidence](../artifacts/number-settings-0200/native/results.json).

Confirmed-idle project Gradle daemon 438071 was stopped. The existing bwrap failure required scoped escalation; no host, SDK, cloud or source-skill settings changed. Native logs contained only an Android ashmem deprecation entry, with no Flutter exception. Physical touch, listening/haptics and full TalkBack review remain manual. No usable Git repository exists.

## Previous release: 0.19.2+41 — personalized Home greeting

Home displays **Hi, [saved active profile name]!**, or **Hi!** when no profile is available during loading/recovery. The greeting follows successful profile switches and renames, retains the previous saved name through pending/failed writes, and stays silent. The full name wraps at large text; normal screen-reader semantics expose it. Android label and Flutter application title remain **Learning Corner**. [Design](design.md#personalized-home-greeting-0192), [gallery](screenshots/0192/README.md).

**726 Flutter tests passed**, including greeting assertions for profile switching, canceled/successful renames, pending/failed rename and retry, restart, and load-failure recovery. **16 rendered review scenarios passed / 48 PNG captures**, covering short and 24-character spaced/unbroken names at four sizes, both palettes and normal/200% text. Representative renders were inspected; activities remain reachable by scrolling. Full analysis completed with zero errors/warnings and **48 existing informational notices** (exit 1); no watcher fallback. Ten touched Dart files passed final formatting. The full suite emitted 12 nonfatal tap hit-test warnings with all tests passing. [Validation](testing.md).

APK: [artifacts/learning-corner.apk](../artifacts/learning-corner.apk), **662,080,376 bytes**, SHA-256 `8e9d2942b0e173d7c47b44e334d2b4ff698cf320d9d366226094610199bd5a39`. Same certificate, application ID/label, API 24–36, offline permissions and normal entrypoint verified; all **1,852 content/shader files** match 0.19.1 byte-for-byte. No save, API, dependency, artwork or navigation changes. The previous APK/source are preserved under [release evidence](../artifacts/home-greeting-0192/README.md).

No device/emulator was started, installed or modified. Earlier native tests remain historical; physical TalkBack and device review were not performed. Confirmed-idle project Gradle daemon 409472 was stopped. Existing bwrap sandbox failure required scoped escalation; no host, SDK, cloud or source-skill settings changed.

## Previous release: 0.19.1+40 — Learning Corner

The Android app label, Flutter title and Home heading are **Learning Corner**. All visible garden wording is neutral: **Back to home**, **Counting**, **Player progress**, **Count the objects**, and **Use light appearance.** Help refers to Home's sound controls. Return destinations and the 0.19.0 continuous-round/reward-sheet flow are unchanged. [Design](design.md#learning-corner-identity-0191), [gallery](screenshots/0191/README.md).

The design guidelines and AGENTS.md now center the product on games and companions. Unicorns/rainbows are the current companion theme; a future second theme should broaden appeal, including for boys, with choices open to any player. Specific companion design/selection is future work. My unicorn, launcher icon, artwork, Light/Midnight Rainbow palettes, Android/Dart identities, signing key, storage keys and save formats remain unchanged. Build/install scripts and the default APK verifier now use **artifacts/learning-corner.apk**.

**725 Flutter tests passed**, plus **16 rendered review scenarios / 128 captures** and **5 APK-verifier Python tests**. Full analysis completed with zero errors/warnings and the same **48 informational notices** (exit 1); no watcher fallback. Formatting checked 20 touched Dart files without changes; shell syntax checks passed. Representative renders were inspected, including 200% text. The full suite emitted nonfatal hit-test warnings; all assertions passed. [Actual validation](testing.md).

Historical APK: preserved 0.19.1 (historical file removed during cleanup), **662,080,376 bytes**, SHA-256 `cec00b4b7c7dba53e1614d10ca4b576247caf45bf58779f550e46ea6764099a4`. Original signing certificate, Android label, application ID, API 24–36, offline permissions, normal entrypoint and all **1,852 byte-identical content/shader files** verified against 0.19.0. Existing 0.18.3/0.19.0 work was preserved, so this build is 0.19.1+40 rather than the earlier proposed 0.18.3. [Evidence](../artifacts/learning-corner-0191/README.md).

No device/emulator was started, installed or modified. The previous 0.19.0 native state/results remain historical; no new installed-upgrade or physical-device claim. Source baseline and prior APK are preserved under the evidence directory, and the old `artifacts/learning-garden.apk` remains the historical 0.19.0 file. Confirmed-idle project Gradle daemon 394813 was stopped. No cloud, SDK, host-limit or source-skill changes. No usable Git repository exists.

## Previous release: 0.19.0+39 — continuous learning rounds

Standard five-question games and ordering boards keep the solved game visible with **50 XP earned!**, a primary **Next round** action and optional **Rewards**. Tap Next off starts another round after two visible seconds of saved completion; accessible navigation always waits for a tap. The header gift button opens a sheet at any time, with live level/XP and the existing reward choices. Opening pauses input/timers/speech; closing restores the same work and the applicable full delay. Gifts bank across rounds, and the shared save/retry/profile guard is preserved. Writing, 2048 and Tap Challenge retain their own flow. [Design](design.md#continuous-rounds-0190), [gallery](screenshots/0190/README.md).

**725 Flutter tests passed**, including 98 continuous-flow/semantics/layout checks. The **64 layout scenarios** separately passed with **128 production-art captures** and saved gift selection at phone/landscape/tablet sizes, both themes and normal/200% text (reduced motion at 200%). Full Flutter analysis completed with zero errors/warnings and **48 informational style notices**; no watcher fallback. Formatting checked 49 Dart files without changes. [Current validation](testing.md).

APK: artifacts/learning-garden.apk (historical file removed during cleanup), **662,080,376 bytes**, SHA-256 `945a59d8dbcceb97e63000f7e8c362d32c2cbae9d85ead91fa7b359fe94d30a9`. Same signing key, normal entrypoint, API 24–36 and offline permissions verified. All **1,852 bundled content/shader files** are byte-identical to 0.18.3, including the compressed companion library and all 221 recordings. The 0.18.3 geometric counting icons are preserved; build code 39 follows that intervening release. No new package, saved schema or native API. [Release evidence](../artifacts/continuous-rounds-0190/apk-verification.json).

Offline install-r on verified **LearningGardenWriting / emulator-5560** passed direct consecutive replay, optional review preserving an unanswered target, automatic Number hunt continuation, root navigation and restart. Native validation caught a badge-only accessible label; the final APK explicitly announces Rewards and its count, verified on Android and at counts 0/1/25 in widget tests. Four completed rounds across validation (three on the final APK) raised the disposable player's XP from 360 to **560 / level 6**, with **three banked gifts**. Saved Writing P/p and the exact 2048 board are unchanged; sound remains off and Tap Next is restored on. Installed checksum matched. The emulator was stopped with data preserved and the confirmed-idle project Gradle daemon stopped. No phone/tablet or user AVD was touched. Physical touch timing, listening, haptics and full TalkBack exploration remain manual. [Native evidence](../artifacts/continuous-rounds-0190/native/results.json).

## Previous release: 0.18.3+38 — generic counting icons

Numbers now shows a rounded question mark with three geometric shapes for **How many?**, and five staggered shapes for **Make a group**. Circles, triangles and squares use theme blue/gold/mint with contrasting outlines. Both static 62 × 54 illustrations are companion-independent, have no individual boxes and retain the existing card semantics. No gameplay, audio, settings or save changes. [Gallery](screenshots/0183/README.md).

**9 existing category tests and 8 visual review scenarios passed**, producing 32 captures across four sizes, normal/200% text and both themes. The scenarios cover live theme repaint, accessible labels, card taps and foreground/outline contrast. Representative phone/tablet renders were inspected. Full Flutter analysis: zero errors/warnings, 42 existing informational notices. Touched Dart formatting passed. A review-harness semantics-handle teardown issue was corrected; no production change was needed. [Current validation](testing.md).

APK: artifacts/learning-garden.apk (historical file removed during cleanup), **662,080,452 bytes**, SHA-256 `309710a52fade1579e47f685fa2a4b931784f4bae1c136b527a188a1b495046b`. Approved normal build, same signing key, API 24–36 and offline permissions verified. All **1,852 bundled content/shader files** are byte-identical to 0.18.2, preserving compressed companion assets and all 221 recordings. [Release evidence](../artifacts/counting-icons-0183/apk-verification.json). No cloud generation or device/emulator installation was performed in this icon-only session; earlier device results below are historical.

## Previous release: 0.18.2+37 — companion compression

The existing 1,575 animated companion segments were re-encoded from original renders at WebP quality 90, method 6, minimize-size/mixed on. Resolution remains 1024 pixels, authored animation remains 60 Hz, and all 23,025 frames preserve exact transparency and material masks. Animated files are 43.29% smaller; static portraits/posters, the item atlas, all 221 recordings, hint pictures and shaders are unchanged. No game behavior, settings, save-format or runtime-dependency changes.

APK: artifacts/learning-garden.apk (historical file removed during cleanup), **661,998,532 bytes**, **40.14% smaller** than 0.18.1 (443,917,808 bytes saved). SHA-256 `ea2109f167813da45dfea0c9597fd51ccde7b1bba698250f42709da8f7c55da4`. Same signing key, API 24–36, offline permissions, normal entrypoint and exact inventory verified. Original APK/assets and detailed evidence are preserved in [the compression report](../artifacts/companion-compression/README.md).

**627 Flutter tests and 30 Python tests passed.** Two final real-Flutter codec/shader runs covered 29 pilot and 15 worst-case segments; frame counts/durations matched and host decoding improved. Reviewed frames showed no visible degradation. Full analysis completed with zero errors/warnings and 42 existing informational notices; touched Dart formatting passed. Android comparisons on verified LearningGardenWriting / emulator-5560 stayed near 58–59 fps with identical 61,669,376-byte managed image peaks, within the 64 MiB budget. These are emulator/host measurements, not physical-device benchmarks.

The final offline install-r upgrade retained Player 1, 360 XP/level 4, muted sound, Writing P/p and the exact 2048 board. Normal Home/My unicorn rendering, empty app error log and installed checksum passed. The emulator was stopped with data preserved and the confirmed-idle project Gradle daemon was stopped. No phone/tablet or user AVD was installed or modified.

New authoring tools support staged benchmarking, source/tool/codec fingerprints, verified segment checkpoints, exact-mask audits and an enforced available-memory reserve. Future exports use `--webp-method 6 --minimize-size --allow-mixed`; normal APK builds only verify bundled assets. Preserve the raw cache's historical stamps; see [authoring instructions](../art/foal/README.md#compression-experiments-and-production-recipe).

## Previous release: 0.18.1+36 — unboxed counting and phonics audio

Per the user's feedback, counting objects and empty slots have no individual boxes, including marked objects and hint examples. Group spacing, the outer collection surface, check badges, large touch targets and all game rules remain. No settings/save migration.

Replaced all 23 Letter Sounds clips: single-letter SSML had produced alphabet names (the old s was /ɛs/). Authoring now uses explicit phonics instructions with Gemini 2.5 Flash/Pro TTS and Puck. c/k share /k/; short vowels/hard g remain. All 198 older learning recordings and all pictures/companion assets are unchanged. Normal builds/runtime remain offline. Sustained L uses an explicit 700 ms authoring cap plus a 20 ms fade; other sounds exceeding three seconds are rejected. Processing is phonics-directed-v2, except phonics-directed-l-v3 for L.

627 full Flutter tests, 35 focused expansion checks with 48 captures, 25 Python tests and native PCM validation for all 221 clips passed. Full analysis: zero errors/warnings and 42 informational notices; 92 files formatted without changes. Blind automated phonetic review recognized the new /s/, /m/, short vowels and final sustained L, and correctly identified the old /ɛs/ as a letter name. These checks are not a human audition: the reviewer flagged brief release vowels on some consonants, and physical-speaker/teaching-quality review remains necessary. [Listening page](../artifacts/learning-0181/phoneme-review.html) · [Validation](testing.md).

APK: artifacts/learning-garden.apk (historical file removed during cleanup), **1,105,916,340 bytes**, SHA-256 `f318f85495713350879c8f1bea444295ca12f9a6df07c14703ae7dc43780e721`. Same signing key, API 24–36 and offline permissions verified. Exactly 23 clips changed; 1,829 other content/shader files are byte-identical. Offline install-r on verified LearningGardenWriting / emulator-5560 retained Player 1, 360 XP, level 4, muted sound, Writing P/p and the saved 2048 board. All three activity smoke checks, phoneme playback without audio error, explicit picture hint and installed checksum passed. Emulator stopped with data preserved. No phone or user AVD was used.

## Previous release: 0.18.0+35 — Letter Sounds and Counting Garden

Letters adds **Letter Sounds**: isolated sounds with three lowercase choices, parent-selected basic letters and explicit picture hints. 24 spellings share 23 sounds; c/k cannot compete as answers. Short vowels/common consonants only; q/x and multi-letter spellings are deferred. Numbers adds silent **How many?** (mark/count objects and choose a numeral) and **Make a group** (add/remove objects in an open tray, then Check). Both include zero, their own 0–5/0–10/0–20 setting (default 10), fixed counting action controls and the existing durable five-question/50 XP rewards. No animal-specific instructions or new narration. [Design](design.md#letter-sounds-and-counting-garden-0180).

Additive per-player `enabledLetterSounds` and `countingMax` settings use the current `ProgressController`; Save/Back/reset/profile and failed-write behavior is preserved. GameRound/GamePage share lifecycle/reward logic; counting scene/manipulative rules are in `lib/counting.dart`, the board in `lib/widgets/counting_board.dart`, and phonics catalog/validation in `lib/letter_sounds.dart`. No new platform API, save-envelope version or runtime package.

**627 full Flutter tests**, **22 Python tests**, **23 focused widget/capture checks** and native PCM preservation for **221 recordings** passed. The 16 capture configurations produced 48 images. Full analysis: zero errors/warnings, 42 informational style notices; formatting passed, no watcher fallback. All 1,803 previous content/shader files are unchanged. Added 23 IPA-generated phoneme WAVs and 24 licensed, bundled Noto hint pictures with metadata. [Validation](testing.md), [gallery](screenshots/0180/README.md).

APK: artifacts/learning-garden.apk (historical file removed during cleanup), **1,105,774,948 bytes**, SHA-256 `40178507bec4a2791fcc34dffdacaee2ff458fbdf195c8742ffd547227025b93`. Approved scripts, existing signing key, normal entrypoint, API/offline permissions and exact inventory verified. [APK evidence](../artifacts/learning-0180/apk-verification.json).

The offline isolated emulator upgrade preserved Player 1, Writing P/p and 2048. Three played rounds raised XP from 210 to **360 / level 4**, with one unclaimed gift. Settings m/s/t and max 20 survived restart; final settings are all 24 letters, max 10 and original sound off. A background/resume check passed; an off-screen automation assertion was corrected without production changes. The final installed checksum and all three activity smoke checks passed. The verified isolated emulator was stopped with data preserved. No phone or user AVD was used. [Native evidence](../artifacts/learning-0180/native/).

**Pronunciation is not yet human-auditioned.** File, waveform and headless decoder checks cannot verify pure consonants or physical speaker onset. Use the [listening review](../artifacts/learning-0180/phoneme-review.html) and a physical device before treating audio quality as accepted. Touch comfort and TalkBack remain manual.

## Previous release: 0.17.0+34 — Reflex / Tap Challenge

Adventure is removed completely. Home adds Reflex → Tap Challenge using normal category cards. Free 30-active-second rounds use star +1, rainbow +3 and cartoon bomb −2 (zero floor), with up to three stationary targets in nine slots. Target roles are separate from the swappable companion skin; future companion selection is separate work. The first positive completed score and every later strictly higher final score earn **50 XP**, saved atomically with the per-player high score and normal level gifts. Ties/lower scores earn none. Pause/background/coverage/resize require explicit Resume; abandoned rounds earn nothing. No untimed mode remains.

Shared classes are now `PlayerProgress` / `ProgressController`. Version-3 migration retires board moves, visits, destination scores and relaxed settings, preserving XP, gifts, equipment, profiles/settings, Writing and 2048. Malformed documents remain recoverable. Legacy readers are intentional upgrade code; all runtime Adventure routes, entitlements, movement hooks and old tapping code are gone.

Removed **261 bundled assets**: four scenery images, seven unused narration clips, and 250 walking/travel clip segments. The retained **198 learning recordings**, **1,601 companion assets**, and shaders are unchanged (**1,802 byte-identical content/shader files**). Active export/spec/verification tools match the pruned library; retained art was not rerendered. Baseline source/APK and retired assets are preserved outside production under `artifacts/tap-challenge-0170/baseline/`.

**577 full Flutter tests passed**, plus **19 Python tests** and **24 final capture scenarios / 96 images**. Formatting passed. Full Flutter analysis completed with **zero errors/warnings and 41 informational style notices**; no watcher fallback. Initial full-run failures were two obsolete audio-count/category expectations, corrected before the final pass. [Screenshots](screenshots/0170/README.md), [validation](testing.md), [APK evidence](../artifacts/tap-challenge-0170/apk-verification.json).

APK: artifacts/learning-garden.apk (historical file removed during cleanup), **1,103,648,170 bytes**, SHA-256 `ea17f90814385a9a0cd412d828072636a85a2bcd6bf4e7d5905987436cfb7336`. Approved script, original signing certificate, version/API/offline permissions and exact retained/removed asset inventory verified. This is **117,960,436 bytes smaller** than 0.16.0.

Offline **install-r upgrade on LearningGardenWriting / emulator-5560 passed**. It preserved Player 1, initial 160 XP, muted sound, Writing P/p (letter 2, one completed pair), and the exact saved 2048 board/high score. A visibly played Tap Challenge round saved best **58** and exactly **50 XP** (final **210 XP / level 3**, 60/100 toward level 4). Background/explicit Resume, free zero-score replay without XP, root navigation, restart persistence and installed-APK checksum all passed. Native automation was adjusted for UIAutomator's inability to idle during target changes and Home's preserved scroll position; neither required a production change. [Native results](../artifacts/tap-challenge-0170/native/results.json). The emulator and confirmed-idle task Gradle daemon were stopped with emulator data preserved. No phone/user AVD was touched. Physical timing comfort, haptic feel and TalkBack gameplay remain manual. No phone or user AVD is involved. No usable Git repository exists.

## Previous release: 0.16.0+33 — tablet reach and Home header

Home's profile portrait stays at the safe left edge; sound and Settings stay at
the right, outside the centered/scrolled activities. The fixed header preserves
20 dp margins, existing 56 dp targets and all gate/save guards.

Writing windows with shortest side ≥600 logical pixels put spare vertical space
above both pads, with Skip in the information header and a 16 dp gap before the
fixed action area. Text/footer measurements govern available space; constrained
layouts scroll. Pad sizes, phone/narrow-window flow, Clear, saved completion,
paired XP and pointer input remain unchanged. The 0.15.3 activity icons are
preserved. [Design](design.md#tablet-layout-0160),
[gallery](screenshots/0160/README.md), [validation](testing.md).

**543 full Flutter tests passed**, including 34 new layout/reflow checks;
**50 separate capture/check scenarios passed**, producing 432 images including
other tablet screens. Representative captures were reviewed. Formatting passed.
Full Flutter analysis completed with no errors/warnings and the same 45 existing
informational notices as 0.15.3 (exit 1); no watcher fallback was needed.

APK: artifacts/learning-garden.apk (historical file removed during cleanup),
**1,221,608,606 bytes**, SHA-256
`2fce978abbab5fefc65d950247899c74c4691910a314f72e807250fd88e81ce7`. Approved build script, existing signing certificate, normal entrypoint,
version/API/offline permissions and all **2,064 unchanged content/shader files**
verified against 0.15.3. [APK evidence](../artifacts/tablet-0160/apk-verification.json).

No device was installed or interacted with. This improves reach for a basic
capacitive pen; it does not add hardware palm rejection. Comfort with the actual
Lenovo tablet/pen, TalkBack and the earlier physical audio-onset check remain
manual. No Undo, new settings or save migration. No usable Git repository exists.

## Previous release: 0.15.3+32 — clearer activity icons

Alphabet Order shows C A / D B in four rounded tiles; Number Order shows
3 1 / 4 2. The user confirmed **2×2**, rather than a sixteen-tile board.
Writing and Handwriting share Aa on solid top/baseline and dotted middle rules,
using the taught letter paths and single-storey a. Illustrations are static,
theme-aware Flutter widgets in the existing icon space. Uppercase, lowercase,
Letter friends, 2048 and the other examples retain their approved appearance.
No gameplay, saves, audio or bundled artwork changed.

**509 existing Flutter tests passed**. A separate **16-scenario capture run**
produced **64 images**, covering four sizes, normal/200% text, both themes and
reduced motion. Representative images were reviewed; text and graphic palette
contrast passed. Formatting passed. **Full Flutter analysis completed** with no
errors/warnings and 45 pre-existing informational style notices (exit 1).
The host watcher failure did not recur; no fallback was needed.
[Gallery](screenshots/0153/README.md), [validation](testing.md).

APK: artifacts/learning-garden.apk (historical file removed during cleanup),
**1,221,592,222 bytes**, SHA-256
`242fb9a4498b0d0b11fc3d03de0401548bfa213b7fe323fd2f33101c7c2ec541`.
Approved build script, original signing certificate, version/API/offline
permissions and all **2,064 unchanged content/shader files** verified against
0.15.2. [APK evidence](../artifacts/icons-0153/apk-verification.json).
No device installation or native checks were requested/performed; the affected
phone still needs the earlier audio-startup listening check. Existing emulator
and phone state was not touched. No usable Git repository exists here.

## Previous release: 0.15.2+31 — first-prompt audio startup

The user confirmed that the **beginning is missing through the phone speaker**,
while Listen again works. The first automatic prompt now waits for the game route
entrance to complete and its visible frame to paint. Pending entry speech cancels
on mute, answer, explicit replay, coverage, Back, backgrounding and disposal.
Android feeds **300 ms of silence through the same MediaPlayer stream before each
recording**, including later prompts/replays that may follow idle time. This is a
bounded speaker-warmup mitigation, not continuous silent playback. Android
preparation is still asynchronous; playback errors remain explicit-hint only.

All original recordings and their 400 ms target pauses are byte-identical.
`PromptAudio.kt` validates the bundled PCM format and constructs a playback-only
buffer; the existing native stop/release boundary remains. No save, permission,
cloud synthesis or runtime dependency changes. Actual relief of phone clipping
still needs listening on the affected phone; emulator playback cannot prove it.

**509 full Flutter tests passed**, including 14 new entry/cancellation cases;
**74 focused tests passed**. The native JVM check preserved every original PCM
sample in **205 recordings**, verified exact silence/headers and rejected nine
malformed formats. Full analysis hit host watcher errno 24; fallback checked
**85 Dart files with zero diagnostics**, not a full lint pass. Formatting passed.

Historical APK: preserved 0.15.2 (historical file removed during cleanup),
**1,221,592,222 bytes**, SHA-256
`87b54b213ed3d32fb150523b8a14ac4f41f4634c425941d31562fd1c6366d384`.
Approved build script, original signing certificate, version/API/offline permission
checks and all **2,064 unchanged asset/shader files** verified.
[Investigation](audio_startup_investigation.md), [validation](testing.md),
[APK evidence](../artifacts/audio-startup-0152/apk-verification.json).

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

## Initial audio startup investigation — September 18, 2026

[Investigation and evidence](audio_startup_investigation.md): all five voiced
activities request their first prompt during the entrance transition (about
500 ms before completion in the widget trace). No later navigation stop was
observed; Android waits for MediaPlayer preparation. All 205 recordings verified,
and 65 focused/diagnostic tests passed. Physical clipping remains unconfirmed;
route completion gating is a candidate experiment, not an implemented fix.
That initial investigation left production unchanged; the follow-up patch is
recorded above.

## Previous release: 0.15.1+30

Fixes clipped lowercase letters in the Writing alphabet picker (notably Mm/Ww).
The grid measures pairs with current font scaling and includes all padding/gaps;
labels stay on one line without shrinking. Handwriting matching/feedback, XP,
progress, existing artwork and AMOLED themes remain unchanged.

**495 full Flutter tests passed**, plus 20 separate picker capture scenarios with
40 images across five sizes, normal/200% text and light/dark. Formatting passed.
Full analysis hit host watcher errno 24; the fallback checked 87 Dart files with
zero diagnostics, not a full lint pass. [Validation](testing.md),
[picker gallery](screenshots/0151/README.md).

Main APK: artifacts/learning-garden.apk (historical file removed during cleanup),
**1,221,592,218 bytes**, SHA-256
`c3400f0130df5b2a26b983a14a68e2dbb2b075a1b6caae8fc173edcce114323c`.
Approved build/install scripts, original signing key, API/offline permissions and
all 2,064 unchanged bundled content/shader files verified. Offline emulator
upgrade preserved Player 1, 160 XP, two moves, muted sound and Writing P (letter
2, one completed pair). M/W selection, shuffle resume, both themes and restart
passed. Display overrides and Android night mode restored; isolated emulator and
confirmed-idle task Gradle daemon stopped with data preserved. No phone/user AVD
used. [Native evidence](../artifacts/picker-0151/native/results.json).

## Previous release: 0.15.0+29

**AMOLED Midnight Rainbow** uses true-black page backgrounds, dark surfaces and
vivid rainbow accents. Parent Settings offers **System / Light / Dark**, saved
per player with System default for new/legacy saves. Save commits, Back discards,
reset and sound/case changes preserve appearance. The existing controller still
owns durable writes and failed retries; the app root now owns that controller.

Read [the dark-mode design reference](dark_mode.md) before extending colors.
It records palette values, the AMOLED rationale, semantic roles, contrast rules,
Android startup/system following, and future-agent implementation guidance.
[The light/dark gallery](screenshots/0150/README.md) contains **368 captures**.
Writing pads, 14-color 2048, selection/answer cards, portraits, customization,
rewards, sheets, gates, errors and system bars all adapt. Adventure/Sparkle Pop
retain their scenery under 70% black; unicorn/equipment colors remain unchanged.
Appearance changes preserve navigation, ink, gameplay and automatic deadlines.

**475 Flutter tests passed**, plus the separate **16-scenario capture run** and
15 focused appearance regressions. Formatting passed; full Flutter analysis hit
host watcher errno 24. The watcher-free fallback checked **86 Dart files with
zero diagnostics**, not a full lint pass. [Actual validation](testing.md).

Historical 0.15.0 APK: artifacts/learning-garden.apk (historical file removed during cleanup),
**1,221,592,218 bytes**, SHA-256
`13217fb3f2458825779aa3e855771fdea271fdb6c9258dc49c25cd883df370a1`.
The approved script, normal entrypoint, existing certificate, package/API 24–36
and offline permissions verified. All **2,064 existing bundled content/shader
files** match 0.14.0. No asset regeneration or new packages.

Offline in-place upgrade on verified **LearningGardenWriting / emulator-5560**
preserved Player 1, **160 XP / level 3**, two moves, muted sound and Writing P
(letter 2, one completed pair). Native Save/draft/System switching, Light/Dark
overrides and restart passed, including live switching within Writing. Final
appearance is System; Android night mode is restored to no. No XP was earned,
progress reset, phone or user AVD used. [Native evidence](../artifacts/dark-mode-0150/native/).
Physical OLED feel, TalkBack and battery savings remain unmeasured/manual.

## Previous release: 0.14.0+28

The catalog now has **28 rewards**, adding lavender/coral/teal manes, seven
independent nail-polish colors, heart tiara, lavender flower crown, coral bow,
fairy wings, mint feather wings and lavender butterfly wings. My unicorn has
five picture tabs; polish colors all four hooves, and No polish restores the
original lavender hooves. The purple preview and accessible targets remain.

Adventure JSON version 2 persists `earnedRewardChoices`. Legacy saves receive
min(level − 1, 12), retaining unclaimed gifts while excluding excess past levels.
Existing gifts can select new items. Future level crossings earn more choices,
capped by the current catalog; adding rewards itself grants no retroactive gifts.
All three XP sources use the same accounting. Failed writes, reset and profile
isolation preserve the existing controller boundaries.

The finished **Writing refresh** is included: fixed Check/Continue controls,
switchable cases with independent ink, either-case-first completion, shuffle
resume in the picker and more forgiving shape matching. Its separate Writing
version-2 subdocument continues to read valid v1. The six finished Writing
source/test files were preserved byte-for-byte during integration.

The full art library contains **25 geometry outfits, 1,851 verified assets**,
and five packed planes (color/hair/hooves/headwear/wings). The shared palette
supports recolors without new geometry exports. Managed decoded images stay
within 64 MiB using actual 20 MiB frame reservations, small posters, four optional
detailed posters and shared playback lookahead control. This is not an overall
process-RAM cap. [Authoring guide](../art/foal/README.md).
[Reward and animation gallery](screenshots/0140/README.md).

**444 full Flutter tests passed**, plus **19 Python tests**, 16 final normal/
reduced-motion gallery tests and the explicit renderer review. Formatting passed
for 83 Dart files. Full Flutter analysis still fails at the host watcher limit
(errno 24), including the final retry after tools stopped; the watcher-free
fallback checked **83 files with zero diagnostics**, not a full lint pass.
A 1,200-pose audit preserved all packed alpha/mask planes exactly. All 16 original
outfit posters retain identical alpha/bounds, with maximum opaque RGB RMS
difference 0.115/255.

Current APK: artifacts/learning-garden.apk (historical file removed during cleanup),
**1,221,378,890 bytes**, SHA-256
`99850fa03d7d540c64cc467683dfd319a5011f72a6fd577e70061fc745be0574`.
The approved build script, exact asset inventory, unchanged 205 recordings/four
scenery files, normal entrypoint, existing debug certificate, package/API 24–36
and offline permissions were verified.

Offline native `install -r` upgraded verified **LearningGardenWriting /
emulator-5560** from 0.13.0+26. It preserved Player 1, 60 XP, one move/gift, muted
sound and Writing P (letter 2, one completed pair). The legacy gift unlocked pink
polish; polish and removal both survived restart. Two real five-question rounds
raised XP to 160, earned exactly one future gift, then saved blue mane independently
of pink polish. Final save: **160 XP, two moves, blue mane, pink polish, no unclaimed
choices, Writing P unchanged**. Installed APK checksum matches the artifact.
No fixture injection, uninstall, phone or user-AVD interaction. Physical-device
appearance, finger/stylus comfort and TalkBack remain manual checks.

Blender is finished. Peak RSS was **5.97 GiB** (export group 6.17 GiB), with one
Blender throughout. The 8 GiB headroom guard safely stopped one run during
concurrent work; saved renders resumed after RAM recovered. After the user
authorized available overnight resources, eight CPU threads/four pack workers
were used; normal tool defaults remain two threads/one pack worker. Direct
/usr/bin/blender works with the installed 580.178.04 driver. The confirmed-idle
task Gradle daemon and disposable emulator were stopped, preserving emulator data.
Logs, baseline backups and native evidence are in
[artifacts/rewards-0140](../artifacts/rewards-0140/WORK_IN_PROGRESS.md).

## Writing preview promotion (0.13.2+27, historical)

Before the combined art was ready, the user requested promotion of the tested
Writing preview to the main APK. That byte-identical promotion is recorded in
[main-promotion.json](../artifacts/writing-refresh/main-promotion.json).
It was subsequently superseded by 0.14.0 above. The separate preview remains
available; its 429-test/native results describe that earlier artifact only.
[Writing evidence](../artifacts/writing-refresh/PREVIEW.md).

## Distinct 2048 tile colors (0.13.1+27, historical)

All 14 values from 2 through 16384 now have unique backgrounds. 2–64 retain
their original pastels; larger values use the approved coral, amber, lime,
turquoise, gold, periwinkle, orchid and rose palette. Numbers stay dark purple;
2048 retains its gold border. Stationary, sliding and merging tiles share the
palette; values above 16384 reuse rose and remain playable. Changes are local
to Board2048. Gameplay, XP, profiles, handwriting, saves and assets are unchanged.

**424 Flutter tests passed**, including two new rendered-palette/animation
regressions. All **32 2048 widget tests passed with captures**, producing 30
phone/landscape/tablet images at normal/200% text. Fourteen colors are distinct,
small tiles unchanged, text contrast at least 4.5:1, five-digit tiles readable,
and higher-value fallback tested. [Palette gallery](screenshots/0131/README.md).
Formatting passed. Full Flutter analysis hit the known watcher limit (errno 24);
the fallback checked **77 Dart files with zero diagnostics**, not a full lint pass.

Historical 0.13.1 APK: **613,160,403 bytes**, SHA-256
`86b259c53181f2874c6ce4ff2c89104a2a48b45f6a6fc96fd9a3e5d137279cd0`. Approved build script verified 205 recordings,
1,185 foal assets and exact packaged companion inventory. Same signing key,
package/API bounds, offline permissions and checksum verified; all **1,398**
bundled content/shader files match 0.13.0 byte-for-byte. No device installation
or native checks for this visual patch. Isolated emulators retain their previous
saved state. The build daemon was confirmed idle and stopped after packaging.

## Writing / paired handwriting (0.13.0+26, historical)

Home now offers **Writing → Handwriting**. A saved, shuffled 26-letter alphabet
presents uppercase then lowercase. Matching both freehand forms earns **10 XP**
once per pair in that cycle; tracing earns none. Large tracing examples have
numbered starts and direction arrows; the separate blank pad has solid top and
baseline, a dashed middle line and descender space. Single-storey a/g use upright
print. Shape, size and line alignment are graded offline; stroke order/direction
are taught but not graded. Each next step is manual and silent.

The upper-right picker offers all Aa–Zz pairs for **practice only / no XP**, with
a return to the saved shuffle. Skip advances a whole pair without XP. Clear
allows another attempt without revoking saved completion or awarding twice.
The cycle summary reports actual pairs/XP (no bonus); a fresh shuffle avoids
repeating the previous final letter first. Per-player progress saves uppercase
immediately and lowercase plus XP atomically. Existing saves without Writing
remain valid; malformed Writing data is not silently discarded. Reset clears
Writing with the active player's adventure, retaining settings/name.

New core files: `lib/writing.dart` (deck/save rules), `lib/handwriting.dart`
(52 authored guides and bounded geometric matcher), `lib/widgets/writing_pad.dart`
(pointer input/painter), and `lib/screens/writing_page.dart` (paired flow).
Adventure/controller and category routing integrate the existing persistence,
retry, rewards and profile boundaries. No new packages, assets, permissions,
audio or network dependencies.

**422 full Flutter tests passed**, including **80 new Writing tests**. Coverage
includes 52 independent imperfect samples, all 1,300 same-case wrong-letter
comparisons, line/size errors, scribbles, dots/bars/tails, stale/failed writes,
profile isolation, 260 XP for 26 pairs, touch/stylus, lifecycle/resize and eight
screen/text configurations. The samples are synthetic, not recorded child
handwriting. The [gallery](screenshots/0130/README.md) has 46 widget captures
including all 52 direction guides. The final singular-count copy correction
was followed by all 18 Writing widget tests passing and a fresh APK build.
Full Flutter analysis hit host watcher errno 24; the watcher-free fallback
checked **77 Dart files with zero diagnostics**, not a full Flutter lint pass.
Formatting passed.

Offline native tests on a new isolated **LearningGardenWriting / emulator-5560**
verified a 0.12.2 in-place upgrade preserving Player 1, 50 XP, one move, one reward
choice and muted sound. Native pointer input completed C/c; a restart after C
resumed c; the pair earned exactly 10 XP. Clear/recheck and selected L/l practice
earned no extra XP. Returning to the shuffle retained the C pair; Next selected
P, and restart retained the resulting 60 XP. No debug fixture injection or phone
interaction was used. Physical finger/stylus comfort, child tolerance and TalkBack
still need device review. Native evidence is in `artifacts/writing-0130/native/`.

Historical 0.13.0 APK: `artifacts/learning-garden.apk`, **613,160,407 bytes**, SHA-256
`d06718c8b4b06f32d57b0964053bd148b4a43af08d0a45a08382c13de84e7511`. Approved build script, same debug certificate, package/API 24–36,
checksum and offline permissions verified. All **1,398 existing bundled content/
shader files match 0.12.2 byte-for-byte**. Logs and baseline APK are retained in
`artifacts/writing-0130/`. See the runbook for the temporary isolated AVD; the
user's existing AVD was untouched. No Git repository is initialized here.

The final installed APK hash matches the distributable. Trace-only native input
left Check disabled. The disposable emulator was stopped after verification,
preserving its data; the confirmed-idle build daemon was also stopped (none
remain running). The user's AVD and unrelated processes were untouched.

## Full-panel customization preview (0.12.2+25, historical)

The My unicorn preview now occupies its entire purple panel, with clipping at
the rounded outer edge. Internal padding is removed. The existing head/body/full
framing still determines zoom and centering, but no longer cuts off artwork
inside this panel. `CompanionView` and `CompanionPainter` have an optional
`clipToFraming` flag defaulting to true; only the customization stage passes false.
Portraits, thumbnails and other screens retain their prior framing/clipping.
The Wings tab now shows the existing feather-wing artwork. New-player equipment,
ownership, saved choices, unlocks, gestures and animation timing are unchanged.

**342 full Flutter tests passed**, including the new pixel-level clipping
regression and expanded small-phone gallery coverage. **13 focused tests** and
**16 additional normal/reduced-motion gallery tests** passed. The 168 new captures
include all four categories and petting, with the user's flower-crown/feather-wing
appearance. [Before/after gallery](screenshots/0122/README.md).
Formatting passed for five Dart files. Full Flutter analysis hit the documented
host watcher limit (errno 24); the recreated `/tmp/rainbow-analyzer` fallback
checked **70 Dart files with zero diagnostics**, not a full lint pass.

Historical 0.12.2 APK: **612,865,395 bytes**, SHA-256
`617763c81d46e1d228ef3b14c4e0c8db3fb95c76c5f1547019cb4b37d9a46b9f`.
Approved build script, same debug certificate, version/package/API/checksum and
offline permissions verified. All **1,398 bundled content/shader files match
0.12.1 byte-for-byte**. No device installation or native check was performed.
Logs are in `artifacts/companion-0122/`; physical Pixel/TalkBack/frame pacing
remain unverified for this patch. No host limits or unrelated processes changed.
The build's confirmed-idle Gradle daemon was stopped; final status reports none
running. Gallery checks resolved all 11 links and verified 170 PNGs, including
byte-identical copies of both supplied screenshots.

## Grounded companion and larger Home preview (0.12.1+24, historical)

Home explicitly uses a **240 dp** companion, up from 180 dp; other screens retain
their sizes. The shared Flutter shadow now follows the projected ground plane:
a soft 400×100 oval centered at (502, 872), rotated −14.5° in the 1000-unit canvas.
Read-only inspection of the saved Blender scene found all four idle hoof soles
at ground height (within 4e-9 model units). Perspective raised the rear pair above
the old thin screen-space oval; the model and all bundled animations are unchanged.
Petting, mirroring, head portraits, scrolling, reduced motion and save APIs remain.

**339 Flutter tests passed**, plus all **21 profile/interface capture tests**,
**six default-appearance gallery tests**, and the explicit real-codec review.
The latter now includes idle, happy, hop, bow and turn sheets with mirrored poses,
all 64 looks, and two decoded idle loops. Formatting passed for the four touched
Dart files; full analysis reports zero errors/warnings and the same 27 existing
informational notices (exit 1). See [before/after and review captures](screenshots/0121/README.md).

Historical 0.12.1 APK: **612,865,395 bytes**, SHA-256
`037874f37b74c782873aa56e4190a5cb85aa5826fa7a0fc45c84dedd41b576ef`.
The approved build script verified all 205 recordings and 1,185 foal assets.
All **1,398 bundled content/shader files match 0.12.0 byte-for-byte**. Version,
checksum, existing debug certificate, API 24–36 and offline permissions verified.
No device was started or installed for this patch; physical-device appearance,
TalkBack and frame pacing remain manual checks. The emulator remains on 0.12.0
with the fixture recorded below. No Git repository is initialized here.
Validation logs are in `artifacts/companion-0121/`. The confirmed-idle Gradle
daemon from this build was stopped; the final status shows none running.

## Approved revision-five unicorn integration (0.12.0+23, historical)

The approved horse-reference revision 5 is now the production model: fuller
rounded muzzle, hinged animated jaw/tongue, six eyelashes, lateral eyes, accepted
longer body and straighter hind legs. The eight-second planted idle, all eight
actions and their durations, 64 looks, item IDs/unlocks, four mane colors and
pink default remain. App behavior, audio, public APIs and save schemas are unchanged.
Learning-question artwork, the 2048 win panel and item/player portraits remain
static; existing animated companions use the replacement library.

Historical 0.12.0 APK: **612,865,395 bytes** (about 613 MB),
**138,110,380 bytes smaller** than 0.11.1. SHA-256:
`3c7174d626fd07f1afca724e5fec6f9ed8e6c11df9da05021be64d04695fdf66`. Built with `tools/build_apk.sh`, normal entrypoint,
existing signing key, API 24–36 and no network permission. Exact APK inventory
contains only the current 1,185 foal images/segments plus their manifest; all 205
recordings and four scenery files match the previous APK byte-for-byte.
Resolution, 60 Hz timing, quality-90 color encoding and lossless masks are unchanged.

**339 Flutter tests and 17 Python tests passed.** All 15 profile capture tests and
the separate real-codec review passed. Formatting passed for 72 Dart files;
full analysis has zero errors/warnings and 27 existing informational notices
(exit 1). All 16,848 raw frames passed alpha/framing/mask checks. Rig validation
covers 480 idle samples plus endpoint, zero idle hoof drift and velocity seam,
173 attachments, jaw/lashes, bow anatomy and all-action framing.
[Gallery](screenshots/0120/README.md): all 64 looks, 16 bow/turn pose sheets,
36 companion layouts, 25 profile captures and two consecutive decoded idle loops.

Verified offline in-place upgrade on **RainbowGarden / emulator-5554** preserved
Player 1, 2850 XP, seven moves, 0–20, sound off, Pack 1, all three settings toggles,
blue/bow/butterfly/hop and all 16 saved 2048 cells/high score 132. The installed
normal APK checksum matches the artifact. Release-candidate checks passed 12
outfit changes with restoration, background/foreground idle recovery and identical
reduced-motion stills. A 120-second release-mode emulator sample recorded median
60 fps engine cadence and a 27 MiB managed image peak against the 64 MiB limit.
Engine cadence is not unique decoded-frame throughput; emulator timing and
memory are not physical-device measurements. See [testing](testing.md) for limits.

All **1,388** prior review/source/gallery files remain byte-identical. Frozen
models are in `art/foal/review/`; previous production inputs, bundled library and
0.11.1 APK are in `artifacts/playful-spark/release-0120/baseline/`, outside the APK.
Current raw export cache is `artifacts/playful-spark/release-0120/frames`.
`tools/export_foal_library.py` stages disjoint outfits, checks source stamps and
publishes no partial manifest. The exporter/build audit reject stale or extra
assets and authoring files. The task-local GPU wrapper used extracted matching
Ubuntu libraries without changing installed drivers or host settings.
The separate performance candidate is `artifacts/companion-profile.apk`; it is
not the distributable. Full evidence and reproduction notes are in the release
artifact folder. Physical Pixel/TalkBack/listening checks remain manual.

The disposable emulator and confirmed idle build daemon were stopped after validation.

## 2048 Game over popup (0.11.1, historical)

**0.11.1+22** replaces the top No moves left label with a themed **Game over** dialog. It appears after a final move saves and finishes animating, or on reentry to a finished board. **Start over** is the reset confirmation and creates a fresh saved board while keeping that player's high score and XP. **View board** or Back dismisses without changing progress; the popup stays dismissed for that visit. It waits while backgrounded/covered and gives the winning panel priority if the last move also makes 2048. Failed final moves and resets retain the existing exact retry flow. Gameplay, profiles, settings, save formats and assets are unchanged.

**339 Flutter tests passed**, including five added 2048 tests and expanded terminal-board/layout coverage. All **30 2048 widget tests passed with captures** across five sizes and normal/200% text. Full analysis completed with zero errors/warnings and 27 existing informational style notices (exit 1); formatting passed. The approved build script verified all 205 recordings and 1,185 foal assets. All 1,398 bundled content/shader files match 0.11.0 byte-for-byte.

Historical APK (now preserved under `artifacts/playful-spark/release-0120/baseline/artifacts/learning-garden.apk`): **750,975,775 bytes**, SHA-256 `0bc6af1e39644e0a677c16d838a4ad6a96b9efa6dc16cb56962b341762008b24`. Same signing certificate, package/API bounds and offline permissions. See [validation](testing.md) and [popup gallery](screenshots/0111/README.md). No device installation or native checks were run for this UI patch; the disposable emulator remains stopped on 0.11.0 with Player 1's prior fixture. The build daemon was confirmed idle and stopped after packaging.

## Local player profiles (0.11.0)

**0.11.0+21** adds a minimal upper-left unicorn portrait on Home and a player picker.
Each player has a name, independent progress, all settings, and their own unicorn.
The app remembers the last player. Existing saves migrate once to **Player 1**;
new players start with the app defaults and empty progress. Switching is free.
Add and the current-player pencil reuse the Settings multiplication gate; deletion
also confirms by name and cannot remove the last player. Reset affects only the
active player and preserves readable settings and their name.

`profiles` is the new version-1 native preference document. It contains ordered
player records (stable ID, name, settings and encoded adventure) and the active ID.
The existing AdventureController owns every write and publishes only after the
atomic native commit succeeds. Pending writes retain the complete intended
collection and originating player ID, blocking switches until retry succeeds.
Migration copies existing adventure text and settings and removes legacy keys in
one commit. Malformed per-player payloads stay intact for scoped, parent-gated
recovery; an unreadable collection is never silently recreated.

Portraits reuse cached, static production head artwork with saved mane/headwear.
All 1,398 existing bundled audio/art/shader files are unchanged. The separate
Blender review candidate was unapproved and not integrated in 0.11.0; it is now integrated as described above.

**334 Flutter tests and 10 Python tooling tests passed.** All **15 profile widget
tests also passed with captures**, producing 25 layouts/portrait images. Full
Flutter analysis completed with **zero errors/warnings and 27 informational style
notices** (exit 1); no watcher fallback was needed. Formatting passed for 70 Dart
files. The normal build script verified 205 recordings and 1,185 foal assets.

The same-key APK is **750,893,855 bytes**, SHA-256
`fb4edbdb1d328217a00f2fe03b1d2ae376d3402f7848517a876a7136c2750858`.
Package/API bounds and offline permissions are unchanged; WAVs remain uncompressed.
See [testing notes](testing.md) for native upgrade outcomes and remaining manual
checks, and [the profile gallery](screenshots/0110/README.md) for layouts.

Offline in-place upgrade on verified **RainbowGarden / emulator-5554** preserved
Player 1’s 2850 XP, seven moves, 0–20, sound off, blue/bow/butterfly/hop and exact
2048 board/high score 132. A temporary player independently saved 0–11, earned
50 XP and a Flower crown, renamed across restart, and was deleted through the
gate. Only Player 1 remains. After a later emulator graphics crash, a software-
rendered cold restart reconfirmed Player 1, progress/settings (including Pack 1)
and the exact 2048 board. The disposable emulator was then stopped cleanly;
confirmed idle build daemons were stopped. Physical phone checks remain manual.
Concurrent Blender review notes below are preserved.

## Blender model review revision 5 (2026-09-15, historical authoring record)

The user supplied front and three-quarter horse photographs and requested a
fuller nose/mouth, restored eyelashes and an animated mouth. This supersedes the
previous closed-mouth-only review direction. The separate candidate is
`art/foal/review/playful_spark_v05.blend`. It deepens the rounded muzzle, splits
an actual lower lip/jaw with a rear hinge, adds a coordinated tongue and restores
three eyelashes per eye. The existing happy control opens the mouth and adjusts
lids/ears; blink controls remain. There are no separate eyebrows. Accepted body
length, neck, side-set eyes and straighter hind-leg joints are preserved.
Both supplied photographs are saved under `art/foal/review/v05/references/` and
packed into the model with persistent image users. No outside mesh was imported.

[Authoring notes](../art/foal/review/v05/README.md) and the
[comparison gallery](../artifacts/playful-spark/model-review/v05/index.html)
contain the independent source and matching relaxed/happy/closed-eye/profile
views, crown, phone-sized previews and an expression clip. Saved-scene validation
passes eight sampled actions and 173 bone attachments, zero idle hoof movement,
IK, bow anatomy, camera bounds, seven partial blink amounts, jaw/tongue controls
and packed-reference persistence. Front muzzle height measures 0.46725 versus
0.33707 units in v04; body span and hind-joint coordinates match exactly.
The final gallery passes ten paired views, video playback and 320–1440 px browser
widths without broken images or horizontal overflow. Media checks pass twelve
stills, both 256 px phone previews and the three-second/36-frame expression clip.
These are desktop checks, not physical-device measurements. The preservation
report confirms 1,299 unchanged files; its current-APK entry is explicitly
reported as the separate documented 0.11.1 release update. Model SHA-256:
`0999137d26c35b7ed4ac1cebf86442ceb625dde14671ffe36b62f771175e3ef2`.
This is a Blender review only: no game integration, library regeneration, runtime
API/save change or APK build. Earlier candidates remain preserved.

## Historical: Blender model review revision 4 (2026-09-15)

The user's selected direction is a **cartoon foal**, with happiness through eyes
and ears and a subtle closed mouth. The latest separate candidate is
`art/foal/review/playful_spark_v04.blend`. It extends the muzzle and nasal bridge,
tucks the jaw beneath the muzzle, makes eyes 10% smaller and farther around the
sides, removes separate eyebrows and the open grin, and adds recessed side
nostrils. The existing happy control drives eyelids and a small forward ear perk.
Body length, neck and straighter hind-leg rest joints are preserved from v03.

[Authoring notes](../art/foal/review/v04/README.md) cover the independent source,
controls and headless rendering commands. The
[review gallery](../artifacts/playful-spark/model-review/v04/index.html) compares
v03/v04 with matched cameras and includes neutral clay anatomy, headwear,
phone-size previews, turntable, expressions and all eight sampled actions.
Saved-scene checks pass 164 bone attachments, planted idle hooves, bow anatomy,
IK, camera framing, closed-mouth surface contact, ear morphs and partial blinks.
No game integration, public API/save-schema change or APK build is included.
All 1,048 protected files are unchanged and all 1,185 production companion
assets still verify. The gallery passed fifteen paired views, both videos and
browser widths from 320 to 1440 px. Review clips are six/four seconds at 12 fps;
only review video sampling changed, not the saved game actions. These browser
checks are not physical-device performance measurements. Visual approval is
still required before promoting this model.

The host's desktop graphics context failed with an NVIDIA driver/library
mismatch during this review. Headless EEVEE rendering works with the documented
fallback; no host settings or drivers were changed.

## Historical: Blender model review revision 3 (2026-09-15)

The latest review candidate is `art/foal/review/playful_spark_v03.blend`.
The user accepted revision two's body length but requested less cheek puffiness,
a smoother cheek/chin transition and straighter hind legs. Revision three
replaces the separate cheek/chin lobes with one tapered jaw (about 14% narrower
at the cheek cross-section). Hind knees and hocks move toward a straighter
stance while keeping their bend directions, hip positions and grounded hooves.
The accepted torso length is unchanged. Revisions one and two are preserved.

[Authoring notes](../art/foal/review/v03/README.md) and the
[matching-view gallery](../artifacts/playful-spark/model-review/v03/index.html)
contain reproduction commands, face/body comparisons, fitted headwear, phone-size
previews, a turntable, expression clip and action sheet. Saved-scene checks pass
for all eight sampled actions, 175 attachments, planted idle hooves, bow anatomy,
IK, camera bounds and intermediate blinks. All 681 protected files still match.
The gallery passes all 15 paired views, both videos and four browser widths
from 320 to 1440 px; these are desktop-browser checks. No game assets or APK were generated
from this candidate. Collect visual feedback before integrating the model.

## Historical: Blender model review revision 2 (2026-09-15)

The user's requested slimmer neck/cheeks/chin, deeper eye sockets, higher
closed-eyeline arch, raised playful smile corners and longer torso are in
`art/foal/review/playful_spark_v02.blend`. This is **a review candidate awaiting
visual feedback**, not an approved production replacement. Revision one's
model, authoring sources and gallery are preserved.

[Revision-two authoring notes](../art/foal/review/v02/README.md) include the
independent source and commands. The [comparison gallery](../artifacts/playful-spark/model-review/v02/index.html)
lets the user switch revisions with matching cameras and lighting. It includes
face/body comparisons, profile and partial-blink views, fitted headwear,
phone-size previews, a turntable and expression video. The user's three Meshy
examples are visual references only; no model was imported. Their preview
images and original C are packed into the Blender scene.

Saved-scene checks passed for eight sampled actions, 175 bone attachments,
planted idle hooves, bow anatomy, IK alignment and camera bounds. The corrected
happy/blink combination retains eye clearance at seven intermediate blink
positions. The gallery's measurement report records the slimmer cross-sections,
0.04-unit eye recession, 35% greater closed arch, 0.045-unit happy-corner lift
and 10% longer shoulder-to-hip span. All 1,185 production companion assets
still verify. All 32 gallery view/revision combinations and both revisions’
videos passed desktop-browser checks, with no overflow at 1920/1280/390/320 px.
These are browser checks, not physical-device or in-game performance tests.
Final verification found 296 protected files byte-identical. The shared APK
was independently replaced during gallery checks; the observed hash is recorded
in `concurrent-workspace-changes.json` and was left untouched. Actual
reports and limitations are in the review directory.

This Blender review changed no bundled assets, Flutter code, save schema,
app version or APK. Concurrent workspace work advanced `pubspec.yaml` to
0.11.0+21 and replaced the shared APK; this review does not validate that release. Collect visual feedback on revision 2;
obtain approval before promoting a model or regenerating the full game library.

## Historical: Blender model review revision 1 (2026-09-15)

The user rejected the released face as creepy and requested a Blender model
review against the original C mockup before any game integration. A separate
candidate is saved at `art/foal/review/playful_spark_v01.blend`, with editable
source and reproduction instructions in [the review README](../art/foal/review/README.md).
The [offline gallery](../artifacts/playful-spark/model-review/v01/index.html)
contains actual Blender renders, expression close-ups, four angles, fitted
headwear, phone-size pink/blue previews, a turntable and an expression video.

This is **a first review candidate, not an approved redesign**. It rebuilds
the eyes/eyelids, fitted brows and open smile, and refines the sculpture and
connected crown geometry. The original concept is packed into the `.blend`.
The production model, generator, action spec, bundled assets and **0.10.1+20
APK remain unchanged**. Existing game validation above/below is historical;
this pass runs saved-scene Blender checks and production asset verification.
See the review's validation JSON and authoring README for actual results.

The next step is the user's visual feedback. Continue iterating on this
separate model; obtain visual approval before promoting it or re-exporting
the full game library. Do not treat the model-review request as approval to
build or install another APK.

## Always-vertical word choices (0.10.1)

**0.10.1+20** makes word identification choices a single vertical column for every pack selection, including Pack 1 alone, landscape and tablets. Cards fill the existing content width, keeping 40-point text with accessibility scaling, a 100 dp minimum height and 12 dp gaps. The user approved this as the default for word games; it is recorded in `AGENTS.md` and `docs/design.md`, superseding the earlier adaptive word-length layout. Letter/number layouts, pack saving, gameplay, audio, rewards and the Playful Spark companion are preserved.

**305 Flutter tests passed.** The expanded word suite also passed all **20 tests with captures enabled**, producing 16 phone/landscape/tablet layouts for Pack 1 and all packs at normal/200% text, including replay and geometry checks. Full Flutter analysis completed with **zero errors/warnings and 27 informational style notices** (exit 1); no watcher fallback was needed. Formatting passed. The approved build script verified all 205 recordings and 1,185 foal assets. All **1,398 bundled content/shader files are byte-identical to 0.10.0**.

The same-key APK is **750,762,499 bytes** (about 751 MB), SHA-256 `6b6e00b666992c1bd283bac4343bd1a34ae71cc9dad174ae15e95f7e36891ff5`. Checksum, version/package/API levels and absence of network permissions verified; WAVs remain uncompressed. No device installation was performed for this layout-only patch. The stopped disposable emulator remains on 0.10.0 with its previously documented progress; physical phone review remains for the user. The build daemon was confirmed idle and stopped. See [testing notes](testing.md) and the [layout gallery](screenshots/0101/README.md).

## Historical: Playful Spark release (0.10.0)

The requested C redesign and gentle grounded idle are complete in **0.10.0+19**.
The [approved concept](../art/foal/references/approved-c-playful-spark.png) is now
preserved alongside the editable model. The prior model/source/APK remain in
`artifacts/playful-spark/baseline/`. The new sculpture has compact proportions,
a rounder face, shorter muzzle, larger eyes, outward ears, a curled tail and
no top-of-head mane. Fitted headwear, shoulder wings and all equipment IDs,
unlocks and four mane palettes remain intact; pink is still the default.

Idle stays **eight seconds / 480 samples**, with staggered weight shifts,
head tilt, separate ear flicks, tail swish and irregular blinks. All four
hooves stay fixed; there is no breathing, torso scaling, bouncing, stepping
or idle wing flapping. Quiet endpoint rests match pose and velocity. A simple
happy smile uses the existing expression control. Action durations and the
rendered asset architecture remain unchanged. Learning questions, the 2048
panel and item portraits retain their static boundaries; lifecycle, retry,
reaction priority and the shared 64 MiB managed-image budget are preserved.

**297 Flutter tests and ten Python tests passed.** All 1,185 assets and all
16,848 frame margins verify; rig checks cover weights, attachments, planted
idle, bounds, seamless motion and bow anatomy. All 64 looks were reviewed; 36 layout captures were produced with
representative phone/landscape/tablet review. Full analysis still hits the host watcher limit after
cleanup; the watcher-free fallback checked 64 files with zero diagnostics,
**not a full lint pass**. See [testing](testing.md) and the [gallery](screenshots/0100/README.md).

The final normal same-key APK is **750,762,503 bytes** (about 751 MB), SHA-256
`58f2414c135c64ed3c86e70ba2f8860695253e712c4bae5bdbc798f84a1e334f`. All 205 recordings and the previous 209
audio/scenery files are unchanged; profiling code and network permissions
are absent. Offline in-place upgrade on verified **RainbowGarden /
emulator-5554** preserved 2850 XP / level 17, seven moves, 0–20, sound off,
Pack 1, blue/bow/butterfly/hop and the saved 2048 board (two 2 tiles, score 0,
high 132). The installed hash matches. No XP, moves or plays were consumed.

A two-minute same-content release candidate measured 57–60 fps engine cadence
(median 60), 35 MiB peak managed decoded images and roughly 78–90 thousand KiB
process PSS. Occasional 133 ms frame intervals occurred. These are emulator
results, not physical Pixel performance. The emulator is stopped on the final
normal APK and idle build daemons were stopped. Physical listening, haptics,
TalkBack and Pixel frame pacing remain manual checks. No further feature work
is pending; no public API, save-schema or runtime dependency change was made.

## Historical: rigged unicorn and combined release (0.9.0)

The requested animation overhaul and the other session's Sight Words feature are complete in the final **0.9.0+18** APK. The editable [Blender source](../art/foal/README.md) replaces the approximate painted turnaround with a weighted model and eight actions. Wings attach near the shoulders and sweep toward the rump; the bow folds the lifted foreleg backward while three support hooves remain grounded. Crowns/headwear follow the head, and all accessories rotate with the rig through a full twirl. Bow and twirl last two seconds; simple/hop remain 1.4 seconds. Saved equipment IDs, unlocks and game rules are unchanged.

Flutter plays complete, occlusion-correct outfit frames from bounded WebP segments, with a visible-hair mask for four shaded mane colors. There are 16 headwear/wing combinations and 64 looks. Static reward/item portraits include distinct celebration poses. Generation cancellation, retry, lifecycle/reduced-motion behavior and a shared 64 MiB managed decoded-image cap are tested. This cap excludes engine-internal codec/GPU allocations. The APK is substantially larger (about **869 MB**) because all animations are bundled offline; the editable model and raw frames are not shipped. Normal builds verify existing assets, never run Blender.

**295 Flutter tests and 10 Python tests passed.** Final full Flutter analysis completed after ordinary emulator/idle-daemon cleanup with **zero errors/warnings and 27 informational style notices** (exit 1). A preceding attempt hit the known watcher limit; its fallback checked 64 files with zero diagnostics, and is not itself a lint pass. Read-only Blender validation passed all eight actions, weighted vertices, attachment invariance, bow support/direction and turn endpoints. Review includes all 64 looks and bow/twirl sheets for every outfit; see the [gallery](screenshots/090/README.md).

The approved scripts built and installed the normal, same-key APK on verified disposable **RainbowGarden / emulator-5554**, offline. Installed hash matches the artifact, every asset verifies, all 166 previous audio/scenery files remain byte-identical, and profiling code is absent. Existing **2850 XP / level 17, seven moves, range 0–20, sound off, Pack 1, all twelve rewards, blue/bow/butterfly/hop**, and the 2048 board (two 2 tiles, score 0/high 132) survived. Bow/twirl previews were exercised and the original outfit restored without earning XP or consuming moves/plays. The disposable emulator and confirmed idle Gradle/Kotlin build daemons were stopped afterward. No phone or user AVD was changed.

An optional same-content timing candidate measured approximately 60 fps engine cadence in quiet emulator windows, 27 MiB managed decoded images (observed peak 35 MiB) and about 98 MiB home PSS. Raster p95 was about 17–18 ms; host-load spikes occurred in other windows. These are not physical Pixel performance, listening, haptic or TalkBack results. Exact evidence and limitations are in [testing](testing.md). No further feature implementation is pending for this release.

## Sight Words implementation checkpoint (historical, earlier 2026-09-15)

The following records the other session's intermediate results. Its companion-related blockers and temporary APK state were resolved by the combined release above.

The requested Words → Sight Words feature is implemented, with Pack 1 enabled by default and three independent packs containing exactly the user's 43 words. The expandable parent-settings section shows counts and full word lists; an empty draft immediately displays a red, announced error and cannot save. Save applies selections; Back discards drafts. Both targets and distractors use only enabled packs. Whole-word cards adapt between three columns and a vertical stack, preserving case (including I), five-question 2/2/1 answer balance, shared sound, explicit hints, existing pacing and once-only saved 50 XP.

`lib/sight_words.dart` owns immutable catalog/selection types. `AppSettings.enabledSightWordPacks` serializes stable pack IDs through the existing guarded Android settings commit; defaults apply to absent older preferences. Sound/case changes and reset preserve selection. No adventure schema migration, runtime dependency or app network permission was added. Forty-three new Puck recordings use natural word pronunciation and the existing 400 ms `target-pause-v2` processing. The source bundle now contains **205 WAVs**; all **162 previous recordings are unchanged**.

**122 focused Flutter regressions passed**, covering game rules, all seven pack combinations, answer-slot balance, feedback, range/settings, navigation, voice, lifecycle/pacing and word layouts. **Seven generator tests passed**; all 205 WAVs verify and all 43 new target gaps retain normalized 400 ms pauses. Fourteen touched Dart files pass formatting. Twelve word widget tests also passed with 24 layout captures at four sizes and normal/200% text; see [gallery](screenshots/090/README.md).

The user confirmed a **separate session is changing the companion renderer** and instructed this session to leave it alone. Full-workspace validation encountered those in-progress changes: one run had 261 passes and seven failures (companion asset/interface failures plus a compiler cascade); final full analysis reported three errors in `test/gentle_foal_export_test.dart`, no warnings and 43 informational notices. The companion's new asset manifest was not complete. Do not treat these as a validated release or overwrite that session's work.

Source version is **0.9.0+18**, but **the distributable APK remains 0.8.2+17** with its existing checksum. An isolated native validation snapshot was built through the approved script under `/tmp/learning-090-native-build`, using version **0.9.0+17** only so the existing APK can be restored with `install -r`. This candidate is not for distribution: it includes the concurrent incomplete companion state. APK hash: `1a163234470911ef0a3a5317e9c3d72704ef561b8c3034a8957a45b54c10f6a4`; 88,052,297 bytes. Its signing certificate matches the existing debug key, no network permission was added, and all 205 WAVs match manifests and are uncompressed. See current [testing notes](testing.md) for native outcomes and the final emulator state.

Native offline Sight Words checks passed on verified RainbowGarden / emulator-5554: Pack 1 default, muted/hint behavior, prompt/replay, immediate red empty-pack error and invalid Save, Pack 3 persistence/filtering, and Back discard. No round completed and no XP was earned. Default Pack 1 and saved sound-off were restored; the existing 0.8.2 APK was then reinstalled with `install -r`. The installed APK hash matches the unchanged distributable; the original unicorn and 2048 (two 2 tiles, score 0/high 132) were verified. The disposable emulator is stopped on 0.8.2+17 with 2850 XP, seven moves, range 0–20 and sound off preserved. The build daemon was confirmed idle and stopped.

That checkpoint's next step was combined validation and release; this is now complete as recorded above. Physical listening and TalkBack remain manual checks.

## Idle development-tool cleanup (2026-09-15)

At the user's request, stopped the idle Gradle 8.14 daemon with `android/gradlew --stop`; its Kotlin compiler child also exited. These used Android Studio's bundled Java and together held about 3.0 GiB RSS. Measured system available memory increased from 20.04 to 22.72 GiB during cleanup. No Android Studio IDE or emulator process remained running. Editors, active language servers, unrelated applications, SDKs, caches, signing key and saved AVD data were preserved; app/APK unchanged.

Future builds automatically restart the required daemons. Keep development tools off when not needed; after build work, check for active jobs before stopping idle build daemons. See the [memory cleanup instructions](DEVELOPMENT_ENVIRONMENT.md#idle-build-tool-memory).

## Development tooling update (2026-09-14)

Google Design and Developer Knowledge MCP servers are configured only in this
project's `.codex/config.toml`. Both passed live initialization/tool calls and
Codex configuration loading. Developer Knowledge uses the existing personal
gcloud identity through `tools/google_knowledge_headers.py`; its API was enabled
in the personal project. No credentials are stored here, and active work gcloud
configuration/ADC were preserved. Restart Codex to load the tools. See the
[runbook](DEVELOPMENT_ENVIRONMENT.md#project-only-google-mcp-servers) for details.
That tooling setup did not change the app/APK. The 0.7.0 checks below were run afterward for the 2048 implementation.

## Current release

| Item | Current state |
| --- | --- |
| App version | **0.12.2+25** |
| APK | `artifacts/learning-garden.apk`, 612,865,395 bytes (about 613 MB) |
| SHA-256 | `617763c81d46e1d228ef3b14c4e0c8db3fb95c76c5f1547019cb4b37d9a46b9f` |
| Checksum | `artifacts/learning-garden.apk.sha256` |
| Package / activity | `com.rainbowgarden.rainbow_garden` / `.MainActivity` |
| Android | Minimum API 24, target/compile API 36 |
| Signing | Same local Android debug certificate as 0.3.0, including release-mode test APK |
| Runtime dependencies | Flutter only; native MediaPlayer and SharedPreferences |
| Assets | 205 WAVs, four scenery PNGs, 1,185 foal image/clip assets, export metadata and a compiled hair-color shader |

The game remains completely offline, Android first, for a kindergarten child who likes unicorns and rainbows. No network permissions, accounts, ads, analytics or backend were introduced. Public distribution and release signing remain outside the current scope.

## 2048 placement and silent saves (0.8.2)

Portrait scores remain at the top, with the board immediately below. Instructions and Start over now sit beneath the board, anchored at the bottom during normal-text play. Large text and victory layouts remain scrollable; landscape keeps the side information panel. Start over retains its text and outline colors during guarded saves and tile motion. Routine saves no longer display a status message. Failures still expose retry; restart confirmation, saved-before-publication rules, XP, haptics and persistence are unchanged.

**248 Flutter tests passed**, including a new delayed-save regression for stable rendered button colors and board/control bounds, silent saving and restart guarding. All 25 2048 widget tests also passed with captures at five sizes and normal/200% text. Full Flutter analysis completed with **zero errors/warnings and 36 informational style notices** (exit 1); no fallback needed. Formatting and 162 bundled recording checks passed. The approved build script produced the same-key APK; all 177 bundled content/shader files match 0.8.1. See [testing](testing.md) and the [layout gallery](screenshots/082/README.md).

No device installation or native checks were run for this layout patch. The stopped disposable emulator remains on 0.8.1 with the fixture described below. Physical one-handed feel remains for user review.

## Saved identification voice (0.8.1)

Home, Uppercase letters, Lowercase letters and Number hunt now share saved `soundOn`. Absent preferences default on; existing range, relaxed mode, Tap Next, Haptics, ordering case and adventure/2048 data are preserved. The identification voice buttons are back. Unmuting an unanswered question immediately plays its target; mute stops current/preparing audio. Home enabling remains silent. Letter friends keeps an optional visit-local override initialized from saved sound; enabling it is silent and does not change shared sound.

Mute and audio failure never reveal an answer automatically. Show a hint is explicit in all recognition games. A muted unanswered identification gently pulses the speaker until voice or a hint is enabled. The 56 dp touch target stays fixed; reduced motion shows a static highlight. Pulse stops for correct answers, rewards, backgrounding, coverage and pending writes. Its accessible label explains how to hear the letter/number. Rewards, retries and other activities remain silent.

Sound uses the existing guarded native settings commit. Requested mute is immediate; failed saves remain retryable after leaving. Pending writes pause answers and automatic advancement, and disabled unanswered choices all stay neutral so they cannot disclose the answer. Fifth-answer XP keeps its once-only guarded save. Parent Save, reset and ordering changes preserve sound.

Historical 0.8.1 automated validation: **247 Flutter tests passed**, six generator tests passed, all 162 recordings verified. An initial full Flutter analysis completed with zero errors/warnings and 37 informational style notices. After the final home stop-error guard, a rerun hit the known host watcher limit; the fallback checked **57 Dart files with zero diagnostics**, not a full lint pass. The approved build/install scripts produced the same-key 0.8.1 APK; all 177 bundled content/shader files match 0.8.0 byte-for-byte. See [testing](testing.md) for native checks and limitations.

Offline upgrade, shared toggle persistence across restart, explicit hints, native prompt completion and local Letter friends behavior passed on verified RainbowGarden / emulator-5554. It is stopped with 2850 XP, seven moves, 0–20, original equipment and 2048 (two 2 tiles, score 0/high 132) preserved. **Saved Home/identification sound is off** after these checks. See the [0.8.1 captures](screenshots/081/README.md); physical listening and TalkBack remain unverified.

## Gentle foal (0.8.0)

The user selected **B — Gentle foal** from the shaded-cartoon candidates. The shared companion now uses its transparent painted master across Home, learning feedback/rewards, Adventure, customization, mini-games and 2048. All existing color/headwear/wing rewards are restyled without changing IDs, unlock order or persistence. The dinosaur remains a future separate companion.

`lib/companion.dart` retains the public widget/painter interfaces and handles bounded reactions/lifecycle. `lib/companion/foal_assets.dart` owns a shared retryable cache; `foal_motion.dart` evaluates poses; `foal_renderer.dart` applies joint skinning and equipment attachments. `shaders/companion_hair.frag` preserves shading when recoloring hair. The master is skinned continuously because separated cutout outlines exposed neck/knee seams; the separated atlas remains in the production pack for editing. Idle is 8 s, walk 800 ms, happy 550 ms, and all celebrations 1.4 s. Walking waits for the saved board move and follows travel progress/facing. Repaint isolation prevents live motion from redrawing static reward cards. Reduced motion is static; hidden/backgrounded reactions cancel without replay.

The sixteen-view twirl includes front/rear drawings and camera-specific accessory artwork. **Generated angular spacing and proportions remain approximate**, documented in the asset pack; do not describe it as an exact 3D turnaround. The neutral foal and main joint animations retain the selected master. Assets/prompts/limitations: [production notes](../output/imagegen/gentle-foal-production/README.md). Review: animation demo (historical file removed during cleanup), [gallery](screenshots/080/README.md).

Historical 0.8.0 validation: **231 Flutter tests passed**, six generator tests passed, 162 recordings verified, all 166 packaged audio/scenery files unchanged from 0.7.0. Real alpha/atlas bounds, all 64 outfits and all 16 turn views per outfit were rendered; 36 layout captures cover phone/landscape/tablet at normal/200% text. Full Flutter analysis again hit host errno 24; the watcher-free fallback checked **55 Dart files with zero diagnostics**. Targeted Dart MCP analysis reported no errors. Same-key normal release built and installed with the approved scripts; installed APK hash matches the artifact, all companion asset bytes match, timing instrumentation is absent and no network permission was added.

A temporary same-key release entrypoint (`tools/profile_companion.dart`) measured Flutter timings on the disposable emulator. Repaint isolation reduced representative steady customization raster p95 from about 12 ms to about 2 ms; samples, including interaction/host-load spikes, are in `artifacts/gentle-foal/timing-samples.json`. This is not physical Pixel validation. The image cache stays at **35,370,960 decoded bytes**; two repeated color cycles yielded PSS 92,615 then 90,000 KiB.

The final normal APK is restored and the disposable **RainbowGarden / emulator-5554 is stopped**. Its existing **2850 XP / level 17**, seven moves, range 0–20, twelve owned rewards, original **blue/bow/butterfly/hop** outfit and 2048 board (two 2 tiles, score 0, high score 132) remain intact. No native move/play/learning reward was consumed or earned. No phone, user AVD, cloud configuration, system limit or source skill repository was changed. See testing notes for exact limitations.

## 2048 (0.7.0)

Numbers adds free 2048 play with a 4×4 board, two starting tiles, standard once-per-move merges and 90% 2 / 10% 4 spawns. Controls are **swipes or attached-keyboard arrows/WASD only; no on-screen arrows**. Parent number ranges do not apply. Cards reuse the app’s pastel colors, dark numerals, white edges and raised shadows, with 180 ms slides/120 ms pops. Score digits fit a single line at large text sizes. Swipes, keyboard repeats, motion, haptics and lifecycle cancellation have dedicated tests.

Making the first 2048 tile saves **500 XP once per session** in the same commit as the board and scores. Multiple level gains grant the existing moves/reward choices. The compact in-game win panel uses the currently equipped unicorn and its celebration; Keep playing retains the board. An unacknowledged win reopens statically, without duplicate XP or feedback. Higher tiles keep scoring without further XP. Start over confirms before creating a new session and preserves high score/XP. No-moves-left boards are retained. Back returns to Numbers; reentry and app relaunch resume automatically.

The version-1 adventure JSON now has optional `game2048` data: highScore and nullable session (id, 16 row-major board cells, score, moves, won, winAcknowledged). Missing data defaults only for older saves; malformed present data fails recovery rather than resetting. All mutations go through AdventureController, save before publication and retain the exact failed snapshot/random spawn for retry after navigation. Winning commits use a namespaced session ID in existing reward bookkeeping. Parent reset clears 2048 data with other progress, keeping all settings. No native method, package, permission or asset changes.

Code: `lib/game_2048.dart` owns immutable rules/save validation; `lib/screens/game_2048_page.dart` owns interaction/lifecycle and the win panel; `lib/widgets/board_2048.dart` paints tiles and bounded transitions. Activity recognition is now explicit, so 2048 cannot enter the five-question engine. The shared controller owns starting, moving and acknowledging wins.

Historical 0.7.0 verification: **217 Flutter tests passed**, including 48 new 2048 rule/controller/widget/layout tests; all 24 new widget tests also passed with captures enabled. Six generator tests and all 162 recording checks passed. Formatting passed. Full Flutter analysis hit the known host watcher limit; the documented fallback checked **49 Dart files with zero diagnostics**, not a full lint pass. The approved script built 0.7.0+14 with the same signing certificate; checksum/package/API/permissions verified, all 166 packaged audio/scenery assets byte-identical to 0.6.2 and WAVs uncompressed. See the current testing section and [2048 gallery](screenshots/070/README.md) for installed-release checks and remaining physical-device limits.

## Learning-only voice (0.6.2)

Identification games (Uppercase letters, Lowercase letters, Number hunt) retain current-question prompts and Listen again, controlled by home sound. Letter friends retains optional instructions and its visit-local voice setting initialized from home sound. Its toggle is hidden on rewards and restored for Play again with the same setting. This was session-local in 0.6.2; 0.8.1 now persists shared Home/identification sound, as described above.

All XP/reward narration, spoken retry encouragement and non-learning spoken help are removed. Ordering games, Sparkle Pop, Adventure and My unicorn are silent with visual guidance preserved. The unused `SpokenHelp` widget and silent-page sound arguments are gone. Reward entry stops any active/preparing prompt and invalidates late errors; only question recordings can be requested. Visual retry feedback, haptic cooldowns, success reactions, screen-reader semantics, pacing and XP persistence are preserved, including the 0.6.1 ordering haptic. All 162 WAVs and manifests remain unchanged; seven retired narration recordings stay bundled but unused. No native, settings or save migration changes.

## Correct placement haptic (0.6.1)

Correct ordering swaps use dedicated `DeviceFeedback.placement`: confirmation followed by a gentle tick 80 ms later. Ordinary swaps and other confirmations are unchanged. One request covers a swap solving two cards. Both pulses use native system-controlled touch feedback without VIBRATE permission; Haptics off suppresses the request. New feedback, shared stop, backgrounding, window-focus loss and destruction cancel the pending tail. Exact physical feel remains device-dependent and unverified on a phone. No visuals, game rules, persistence or assets changed.

## Ordering games (0.6.0)

Letters now includes Alphabet Order; Numbers includes Number Order. Each board contains the full alphabet or every integer in the saved inclusive number range. Cards start shuffled with none correct. Hold 300 ms and drag, or tap two cards to swap. Correct positions turn green, show a check, lock and sparkle; a swap can correctly place both cards. Ordinary swaps use light feedback; correct swaps use one success cue, extended in 0.6.1 above. All feedback honors Haptics and reduced motion.

Boards fit normal phone/landscape/tablet screens, preferring 3–4 columns but adding columns when needed. Large ranges and constrained large-text layouts scroll; dragging near an edge scrolls automatically. Source slots stay visible and active drag recognizers stay alive off screen. Background, coverage, resize and disposal cancel transient gestures, including their separate overlay.

A/a changes display without changing arrangement or correctness. The new settings field `orderingLowercase` defaults false and persists through the existing controller/native boundary; parent settings saves and resets preserve it. It previews immediately while guarded persistence blocks further moves/toggles. Failed case saves remain retryable after leaving.

One solved board immediately saves 50 XP with the existing stable round ID, then enables See my reward. Reward presentation is shared with recognition games. Replay and re-entry start a new shuffle; case is remembered. Unfinished arrangements are not persisted. Existing recognition pacing, balanced 2/2/1 slots and speech are unchanged. No packages, audio, permissions or adventure-document migration were added.

New files: `lib/ordering_game.dart`, `lib/screens/ordering_page.dart`, `lib/widgets/ordering_board.dart`, and shared `lib/widgets/learning_reward.dart`. See design/testing notes for geometry, animation and validation details.

## Letter friends voice toggle (0.5.2)

Letter friends originally alone had an upper-right speaker button; identification also has one since 0.8.1, during questions; since 0.6.2 its reward view is silent and has no voice button. It starts from the garden sound setting, retains local changes through questions, background/coverage and Play again, and resets from the garden setting when reopened. It never persists or changes other destinations’ sound. The accessible 56 dp control reports “Turn voice off/on” and its on/off state. Enabling voice is silent; muting stops current/preparing audio and suppresses matching instructions. Listen again is hidden while muted.

The matching answer is now revealed only through Show a hint, including when the garden starts muted or audio fails. The starting letter, instruction and choices provide the silent exercise. Other activities retain their sound/hint behavior. Local request IDs suppress stale playback failures after mute, replacement or interruption; safe stop calls preserve navigation even on audio failure. Haptics, visuals, pacing, XP, assets and persistence remain unchanged. All implementation is within the existing Flutter game page; no Android boundary changes.

## Retry and home refinement (0.5.1)

Home My unicorn now shows a 40 dp present and separately laid-out count only when rewards are positive, with 12 dp clearance before its label. Zero rewards produce centered text only and the accessible name “My unicorn.” Home actions keep 16 dp spacing and wrap. Successful redemption updates the button through the existing shared controller. The reward-screen button remains text-only.

Wrong answers show a coral × in a 24 dp circular overlay: hold 150 ms, fade 450 ms; reduced motion uses a static 600 ms marker. Answers stay enabled. Duplicate taps on the currently marked wrong option are ignored; another wrong option restarts its visual duration. Retry haptics use a separate 600 ms cooldown; since 0.6.2 retries request no audio. Correct taps clear the marker immediately and start existing success feedback. `GamePage` owns cancellable transient state; `lib/widgets/retry_marker.dart` paints it separately from success feedback. Background, covered routes, Next, replay and disposal cancel it. The live-region “Try again” and all learning rules remain.

`DeviceFeedback.retry` maps to Android REJECT (API 30+) or VIRTUAL_KEY (API 24–29), honoring Haptics/system settings/focus and catching optional platform failures. No packages, permissions, recordings or persistence fields changed. Parent help explains the feedback. Original screenshot attachments were unavailable; implementation follows the supplied plan’s explicit scenarios.

## Interface refresh (0.5.0)

The launcher, app and home title are **Learning Garden**. Build/install scripts now use `learning-garden.apk`. Package, signing certificate, storage identifiers and progress format are unchanged. Home slogans and repeated category descriptions are removed; numbers retain their range and matching keeps a short instruction. Rewards say “50 XP earned!”, “Level up!” and “Choose a reward.” Numeric XP, level/move information and save errors remain. The original home badge was refined in 0.5.1 as described above. Home actions use 16 dp spacing; reward actions use 24 dp before My unicorn and 12 dp before Adventure.

New settings **Tap Next** and **Haptics** default on for both new and existing installations. They use the parent-gated Save/Back draft flow; reset preserves every setting. Tap Next off advances questions 1–4 after 800 ms. Accessible navigation always uses manual Next. Question 5 immediately starts the existing save and always waits; See my reward is disabled until success. Back, replay, disposal, coverage and backgrounding cancel stale transitions. Visibility restoration restarts the delay without replaying feedback.

The equipped pet now appears inside the puzzle rainbow. Each correct answer triggers a 550 ms happy reaction, the existing sparkle and a pop on only the newly filled star. Home and My unicorn have tappable pets with bounded happy feedback and duplicate-tap guards. A saved level-up celebrates once on reward entry for 1.4 seconds; the default has a visible bounce. `CompanionReaction` and `reactionTrigger` keep intent separate from painting. Reduced motion uses a static happy face/filled star; hidden/backgrounded reactions stop. Haptics use typed `DeviceFeedback`, safe optional calls and Android `performHapticFeedback` with a window-focus guard. Successful retained customization retries emit one cue; failures add none; wrong-answer retry cues were added in 0.5.1. No vibration permission is introduced.

Home and Letter friends sound-on are silent; since 0.8.1 identification unmute plays an unanswered target. All 162 bundled WAVs and all four scenery PNGs are unchanged from 0.4.2. The reward screen and Play again scroll to the top.

## Implemented behavior

Flower rewards were replaced with learning XP, twelve collectible companion options, an eight-stop animated adventure board and earned Sparkle Pop plays. **The 0.4.0 upgrade intentionally clears legacy flower counts while preserving the saved number range.** It never reinitializes an existing adventure document.

A completed five-question round immediately saves **50 XP at the fifth correct answer**. Hints and retries do not reduce it; unfinished rounds earn nothing. Level 2 needs one round, levels 3–4 two rounds each, levels 5–7 three, and later levels four. Each level earns one move and one reward choice while unowned items remain. All activities and Play again retain balanced correct-answer slots (2, 2, 1), silent correct-answer sparkles and existing target cadence.

The fixed mixed catalog offers up to three unowned items: blue/flower crown/feather/hop, mint/bow/butterfly/bow, gold/star crown/rainbow/twirl. Selecting an item saves ownership and equips it; skipped items remain available later. My unicorn allows free switching among owned items, including default pink/no headwear/no wings/simple behavior. My unicorn now has four picture tabs with owned-only choices and a persistent focused preview. Colors are mane swatches; headwear/wings show their actual shapes; celebrations have illustrated poses and bounded replay. The gift button opens a scrollable picture picker, and learning rewards use those same cards. A selection is checked and worn only after saving succeeds. Dismissed sheets retain pending saves through the shared controller. Owned/equipped items render through the same layered companion on home, reward, board, customization and mini-game screens. Rewards and movement may be postponed independently.

Move spends one earned move and atomically saves the next destination plus one visit-based play. The board starts at Trailhead and visits Meadow Gate, Flower Hill, Bubble Brook, Rainbow Bridge, Firefly Grove, Moonlit Clearing, Cloud Harbor and Star Castle. The next move after Star Castle starts journey two at Meadow Gate. XP, ownership, scores and unused plays remain. Destination buttons show saved plays; the header offers the oldest play.

Sparkle Pop has one large target in a 3×3 arena. Standard mode lasts 30 active seconds, targets expire at 1.5 seconds, taps score one and misses have no penalty. Relaxed mode uses twenty non-expiring targets with no deadline, selected by the parent setting or accessible navigation when starting. Standard bests are stored per destination and never affect learning XP. Backgrounding pauses with explicit Resume. Leaving/restarting abandons unfinished scores and preserves their plays. A completed play is consumed only after its result saves successfully.

Letter activities are now titled Uppercase letters and Lowercase letters. Home/category descriptions and all letter-case speech use uppercase/lowercase terminology; Letter friends remains the matching activity. Unrelated uses of big/little in garden copy retain their ordinary meaning. Navigation remains Home → category → learning round. Game Back returns to category; reward Back to garden returns to root. Adventure from reward removes category/game routes before opening the board above home. Mini-game Back returns to the board. Play again preserves activity and range.

Settings remain parent-gated. Number range, relaxed mode, Tap Next and haptics are drafts until Save; Back discards them. Confirmed reset removes XP, rewards, board position, plays and scores, preserving all settings. Load errors, including malformed adventure data, expose retry and parent-gated reset rather than silently resetting.

## Code and persistence

| File | Responsibility |
| --- | --- |
| `lib/adventure.dart` | XP curve, typed progress/configuration/destinations/entitlements/reward result, strict JSON decoding |
| `lib/adventure_controller.dart` | Shared listenable progress, all mutations, single write guard, retained failed operation and retry |
| `lib/app_settings.dart` | Number range, relaxed mode, Tap Next and haptics |
| `lib/device_services.dart` | Android progress/settings/audio boundary; no flower API |
| `lib/screens/home_page.dart` | Controller ownership and root navigation |
| `lib/screens/game_page.dart` | Existing learning interaction, stable round IDs, saved XP reward screen |
| `lib/screens/adventure_page.dart` | Board paths/markers, scroll positioning, committed-before-animation moves, saved plays |
| `lib/screens/companion_page.dart` | Picture tabs, focused preview, owned equipment, gift sheet and celebration replay |
| `lib/widgets/companion_choices.dart` | Shared static thumbnails, swatches, picture cards and category tabs |
| `lib/sparkle_game.dart` | Plain Dart rules with a controllable active clock |
| `lib/screens/sparkle_page.dart` | Monotonic clock, pause/resume, responsive arena, saved result |
| `lib/companion.dart` | Body, mane/tail, wings, expression, accessories and lifecycle-aware motion |
| `lib/widgets/scenery.dart` | Bundled paintings and restrained glints |
| `lib/widgets/progress_widgets.dart` | Level progress, reward choices and persistent save retry |
| `lib/garden_art.dart` | Familiar static learning rainbow, reusing companion body layers |
| `android/app/src/main/kotlin/com/rainbowgarden/rainbow_garden/MainActivity.kt` | Serialized native persistence, atomic migration and bundled audio |

SharedPreferences `garden` stores `adventure` as a version-1 JSON string, plus `numberMin`, `numberMax`, `relaxed`, `tapNext`, `haptics` and `orderingLowercase`. The adventure document contains XP, total moves taken, owned/equipped IDs, pending visit numbers, destination bests and the last rewarded round ID, plus optional 2048 progress described above. Level, move availability, journey and choices derive from authoritative values. Initial migration saves the empty document and removes `flowers` in one native commit.

Every mutation uses the controller. It publishes state only after persistence succeeds. Writes have **no artificial timeout**. A failed operation retains its exact intended document/settings and blocks conflicting writes until retry, even after the originating screen closes. Stable round IDs prevent a repeated award; completed visit IDs cannot be consumed again. Do not bypass this guard when adding features.

In 0.4.2, all 52 alphabet targets and both matching recordings were regenerated with uppercase/lowercase wording. The other 108 recordings remain byte-identical to 0.4.1. All 52 regenerated letter targets measure a 400 ms interior pause and retain `target-pause-v2` processing; all 101 number recordings are unchanged. Voice is still Google Chirp 3 HD Puck at 0.9×. Normal builds only verify/reuse assets. Intentional generation uses the explicit personal configuration/account/project flags in [the runbook](DEVELOPMENT_ENVIRONMENT.md); never change active work gcloud configuration or ADC. [ARTWORK.md](ARTWORK.md) records exact built-in image-generation prompts and final file paths.

## Verification and remaining manual checks

Current-session checks for 0.7.0 are summarized in the 2048 section above and [testing notes](testing.md). All **217 Flutter tests**, including 48 new 2048 tests, passed. Offline upgrade, native input, exact saved-board resume and confirmed/canceled restart were exercised on the disposable emulator. Physical haptic feel, attached keyboard hardware, TalkBack play and frame pacing remain unverified; the native 500 XP victory path is covered by rule/controller/widget tests rather than a full played-to-2048 emulator run.

Historical checks for 0.6.2:

- **169 Flutter tests passed**, including prompt-only speech, silent reward/retry/destination coverage, preparing-audio cancellation, retained matching voice, unchanged XP/pacing/haptics, and normal/200% layouts.
- **Six generator tests passed**; all 162 recordings verify. All 166 packaged audio/scenery assets remain byte-identical to 0.6.1 and WAVs are uncompressed.
- Dart formatting passed. Full Flutter analysis hit the documented inotify watcher limit; the fallback checked **44 Dart files with zero diagnostics**, not a full lint pass.
- Approved build script produced **0.6.2+13**. Checksum, package/version/API levels, same signing certificate and absence of network/VIBRATE permissions verified.

- Verified offline upgrade on disposable **emulator-5554 / RainbowGarden** retained level progress, seven moves and range 0–20. One Letter friends round saved exactly 50 XP; reward/replay/voice controls, number prompt replay and persistence after restart passed. Fixture is now **2850 XP / level 17**, 150/200 to level 18. No plays were consumed. See [0.6.2 captures](screenshots/062/README.md) and [testing notes](testing.md).
- The disposable emulator was stopped after testing. The connected Pixel 9 Pro was not interacted with. Physical listening, TalkBack, haptic feel and frame pacing remain unverified.

Historical checks for 0.6.1 (previous implementation session):

- **164 Flutter tests passed**, including updated dedicated-placement and platform-channel regression assertions. Dart formatting passed.
- Full Flutter analysis hit the known inotify watcher limit (errno 24). The documented watcher-free fallback checked **45 Dart files with zero diagnostics**, not a full lint pass. No host settings or unrelated processes changed.
- Approved build script produced 0.6.1+12; checksum, same debug certificate against 0.6.0, package/version/API levels and absence of network/VIBRATE permissions verified. All 162 recordings verify, and all 166 packaged audio/scenery assets remain byte-identical to 0.6.0 with uncompressed WAVs.
- Native timing/cancellation code was reviewed and compiled. No device installation or new captures this session; physical haptic feel/system suppression remain unverified. Generator tests were not rerun for this haptic-only patch.

Historical checks for 0.6.0 (previous implementation session):

- **164 Flutter tests passed**: all 141 existing regressions plus 23 ordering tests, including permutations, locks, direct/tap swaps, long drags beyond the original row, interruptions, saved case, delayed/failed persistence, reward/replay/navigation and responsive layout. The 23 ordering tests also passed with captures enabled.
- **Six generator tests passed**; all 162 recordings verify. Packaged audio and all four scenery images are byte-identical to 0.5.2; WAVs remain uncompressed.
- **Full Flutter analysis completed**: no errors or warnings, 31 pre-existing informational style notices, exit 1. The watcher limit did not recur; no fallback or host changes were needed.
- Approved scripts built and installed 0.6.0+11. Checksum, same signing certificate, package/version/API levels and absence of network/VIBRATE permissions verified.
- Offline upgrade on verified disposable **emulator-5554 / RainbowGarden** retained visible 2750 XP / level 17, seven moves and range 0–20. Native hold/drag/drop, green lock, all-26 alphabet completion, exactly 50 XP, reward Home, case/reward persistence after restart, fresh re-entry and all 21 number-range values passed. One completed board intentionally leaves the disposable fixture at **2800 XP**; unfinished Number Order earned nothing.
- [0.6.0 gallery](screenshots/060/README.md): 32 rendered phone/landscape/tablet images at normal/200% text plus seven installed-release captures. Representative rendered and native images were reviewed. Physical haptic feel, system haptic suppression, TalkBack, listening and frame pacing remain manual. The connected Pixel 7 was not installed to or interacted with.

The previous 0.4.0–0.4.2 manual migration/recovery/adventure checks in testing.md are historical; their automated regressions ran again, but not every manual flow was repeated.

The disposable AVD at `/tmp/rainbow-avd/RainbowGarden.avd` was stopped after 0.7.0 verification. Its 2048 game is a fresh saved two-tile board at score 0, high score **132**, not yet won. Native swipe/key events, whole-board visibility, restart confirmation and exact resume passed; the installed APK hash matches the final artifact. Learning progress remains the earlier synthetic fixture: **2850 XP / level 17**, nine spent moves (journey 2, Meadow Gate), pending visits `[1, 7, 8, 9]`, all twelve owned items, blue/bow/butterfly/hop equipped, range 0–20, relaxed mode, Tap Next and Haptics on, ordering lowercase preference true. Level XP, range and available moves were checked in 0.7.0; destination, exact visit IDs, ownership and settings not explicitly checked are inherited from prior verification. Verify serial/state before reuse. The user's `Medium_Phone_API_36.1` was left untouched. Temporary `/tmp/learning-*` scripts/logs are evidence and may assume fixtures; do not run them blindly.

No usable Git repository was found in this workspace; no commit or clean Git state is claimed. Source skills and host settings remain unchanged.
