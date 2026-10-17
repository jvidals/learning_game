# Learning Corner

Workspace cleanup (2026-10-03) removed obsolete artwork, old APKs and generated
caches. The current game artwork, editable model and installable APK are unchanged.
[Retained artwork studies](art/foal/archive/README.md) ·
[Cleanup record](artifacts/workspace-cleanup-20261003/README.md).

An Android game for little learners, centered on learning activities and companions. Unicorns and rainbows are the current companion theme; future themes will broaden the choices. Built with Flutter; everything needed to play is inside the APK, including all spoken prompts. No internet permission, online accounts, ads, hosting, or runtime downloads.

For a new agent conversation, start with [AGENTS.md](AGENTS.md), then the [current project handoff](docs/AGENT_HANDOFF.md) and [local development runbook](docs/DEVELOPMENT_ENVIRONMENT.md). These preserve accepted preferences, implementation details, validation limits, and the personal gcloud setup.

The main screen is **Home**, greeting the active player with **Hi, [profile name]!**, with **Back to home** return actions. The greeting follows saved profile switches and name changes; it stays silent. The [design guidelines](docs/design.md#learning-corner-identity-0191) record the neutral app identity and future companion direction. Existing artwork and progress remain unchanged by the rename.

## Play

The game includes five categories. **Letters** opens Uppercase letters, Lowercase letters, Letter friends, Alphabet Order, and Letter Sounds. **Numbers** opens Number hunt, Number Order, 2048, How many?, Make a group, Same number and Number parts. **Words** opens Sight Words, Read and find, Make-believe words and Word Sprint. **Writing** opens Handwriting and Cursive play. **Reflex** opens Tap Challenge. Game Back returns to its category; **Back to home** in the reward sheet returns directly home.

- **Uppercase letters:** hear a letter and find its uppercase form.
- **Lowercase letters:** hear a letter and find its lowercase form.
- **Letter friends:** match uppercase and lowercase in both directions. The upper-right speaker toggles voice for this visit, including Next round. It starts from the Home’s sound setting each time you open the game. Muting stops speech; turning it on is silent. Silent play still asks you to find the match; **Show a hint** reveals the answer.
- **Number hunt:** recognize shuffled numbers, starting at **0–10**. A grown-up can choose any inclusive range within **0–100**. One wrong choice is a look-alike when the range allows (12/21, 6/9, 13/30).
- **Letter Sounds:** hear only a sound and select its lowercase letter. Parents choose among 24 basic letter spellings; short vowels and common consonants are included. c and k share /k/ and cannot compete as answers. Show a hint reveals a letter, reference picture and word. q, x and multi-letter spellings are deferred.
- **How many?:** count still objects and select their numeral. Tap objects to mark/unmark them while counting. There is no running total or narration; Show a hint numbers the objects and reveals the answer.
- **Make a group:** match the displayed numeral/object picture by adding objects to an open tray, tap placed objects to remove them, then Check. Zero accepts an empty tray. Hints show an example without filling the tray. Each counting game has an independent parent-selected range within 0–20 (default 0–10); both have five questions, saved 50 XP rewards and fixed Next/Check controls.
- **Sight Words:** hear “Find the word” followed by a word and choose it from three cards. Pack 1 starts enabled; parents can independently enable three bundled packs totaling 43 words. Both targets and distractors come from enabled packs.
- **Read and find:** read a printed word (no voice) and tap its picture. **Show a hint** opens **Sound it out**: each letter lights up with its sound, then the whole word plays; tap a letter to hear just that sound.
- **Make-believe words:** read a pretend word, tap the three sound cards to hear options, select one and Check. The hint plays only the separate sounds.
- **Word Sprint:** read each word aloud and tap it (tap again to undo); hold a word to sound it out. Real, Make-believe or Mix words; the saved 1-minute timer can be switched off. Completed timed runs keep a personal best; there is no XP.
- **Same number:** complete a Numeral | Ten frame | Picture row by choosing the missing one. Silent.
- **Number parts:** find the missing part of a whole, ending with Make 10 on a ten frame. Silent.
- **Cursive play:** optional practice-only lowercase cursive: pick a family and letter, Watch the dot, Trace, then Write. No XP; nothing saved.
- **Alphabet Order:** arrange all 26 letters across rows, then down. The live **A/a** button changes every letter without changing the puzzle and remembers its case across replay, visits and restarts.
- **Number Order:** arrange every value in the saved inclusive range, smallest first. Both ordering games use floating square cards: hold and drag or tap two cards to swap. Correct cards sparkle, turn green with a check, and lock. A full board earns **50 XP**. Boards fit the screen when possible; large ranges and constrained accessible layouts scroll, including near-edge scrolling during drags. Leaving an unfinished board starts fresh next time.

- **Handwriting:** practise both uppercase and lowercase for each shuffled letter. Trace the numbered, arrow-guided example, then write freehand on the blank handwriting lines and tap **Check**. Tap either case at the top to switch; each retains its drawing during the visit. Complete both in either order to earn **10 XP**. Check and Continue stay visible at the bottom. **Clear** allows more practice without duplicate XP; **Skip letter** moves on without XP. The alphabet and completed forms resume across visits. **Choose a letter** opens practice-only Aa–Zz selection and **Shuffled alphabet** resumes the saved sequence without affecting XP. Writing always waits for Next and stays silent.

- **2048:** swipe the 4×4 board or use an attached keyboard’s arrow/WASD keys to merge matching tiles. There are no on-screen directional buttons. Reaching 2048 earns **500 XP once per game**, with an in-game celebration by your customized unicorn. **Keep playing** continues for a higher score. The board, score, high score and win state save automatically; reopening resumes your game. **Start over** asks first and preserves high score and earned XP. The parent’s number range does not apply.

**Voice policy:** Letter Sounds plays only isolated target sounds. Counting is silent, with picture/numeral instructions; existing screen-reader semantics remain available. Uppercase letters, Lowercase letters, Number hunt and Sight Words use spoken targets and Listen again when the shared sound setting is on. Home and identification speaker buttons remember the last choice across app restarts. Muted identification gently pulses its speaker; reduced motion uses a steady highlight. Answers appear only after **Show a hint**, including when audio fails. Turning voice on during an unanswered identification plays its current target. Letter friends offers optional instructions using its local toggle, which is hidden while the silent reward sheet is open and retained across Next round. All rewards and retry feedback are silent, as are ordering games, Tap Challenge and My unicorn. Visual instructions, haptics and screen-reader announcements remain available.

Each recognition round has five targets (unique when the range contains at least five numbers) and three answer choices per question. Correct-answer positions are balanced in shuffled order: each position is correct once or twice per round. Replay a prompt, reveal a hint, or take as long as needed. Wrong answers show a small coral × for 600 ms (a brief hold, then fade), show “Try again” and give an optional retry haptic. Answers stay available; a correct tap clears the marker immediately. Correct answers stop speech, sparkle, pop the newly earned progress star and give the equipped pet a short happy response. Reduced motion uses a static happy expression and filled star. Tap Next is on by default; switching it off advances questions 1–4 after 800 ms. Accessible navigation always uses Next. After the fifth answer saves, **50 XP earned!** appears on the finished game. **Next round** continues the same activity directly; with Tap Next off it starts automatically after two seconds. A small gift button is always available, and **Rewards** at completion opens the optional reward sheet. The sheet shows current level/XP and lets you collect gifts without losing the current question or board. Closing returns to that same work and restarts any applicable delay. Saved level-ups celebrate once inline. Failed saves block continuation and remain retryable after navigation. Ordering boards use this same completion flow. Five finds earn **50 learning XP**, saved immediately after the fifth correct answer. Each level earns one unicorn reward choice while more catalog choices can be earned. Unclaimed gifts can select new items; adding rewards does not create gifts for past levels. Unfinished rounds earn no XP.

**My unicorn** uses five picture tabs for mane colors, headwear, wings, nail polish and celebrations. A large preview stays visible while choosing shaded portraits and matching pictures of owned items. Head choices use a close-up portrait. Tap the gift button to collect an earned surprise; the same picture cards appear in the optional in-game reward sheet. One tap saves and wears a choice; a checkmark identifies the saved selection. Celebrations have a short demonstration and a replay button.

**Tap Challenge** is freely replayable under Reflex. Each round lasts 30 active seconds: tap stars for **+1**, rainbows for **+3**, and avoid cartoon bombs (**−2**, with a zero score minimum). Up to three stationary targets appear in a nine-position arena. Misses are okay. The timer and targets pause when the app is interrupted; tap Resume to continue. Leaving an unfinished round earns nothing.

Each player has a saved personal best. A completed final score above that best earns **50 XP**, including the first positive score. Ties and lower scores earn none. The high score and XP save together; failures can be retried without duplicate rewards. There is no untimed mode. Target roles and scoring are independent of artwork, allowing a future companion to provide its own icon set.

Current distributable: **Learning Corner 0.21.0+45**, **671 MB**. Adds Read and find, Make-believe words, Word Sprint, Same number, Number parts and Cursive play. [Gallery](docs/screenshots/0210/README.md) · [Validation](docs/testing.md) · [APK audit](artifacts/new-games-0210/apk-verification.json).

The previous **0.17.0+34** release: Adventure, board moves, saved-play restrictions and its exclusive assets have been removed. Existing XP, unicorn rewards, profiles/settings, Writing and 2048 carry forward; retired destination scores do not transfer to Tap Challenge. [Screenshots](docs/screenshots/0170/README.md) · [Validation](docs/testing.md).

Home retains the full-width player/sound/Settings header and tablet Writing reach improvements. The earlier audio-startup mitigation and offline recordings are unchanged; physical phone listening is still needed to confirm clipping relief.

## Players

Tap the round unicorn portrait at the upper-left of Home to choose a player.
Each player keeps their own progress, unicorn, saved 2048 game, scores and all
settings. The app remembers the last player. Existing progress becomes **Player 1**
on upgrade; new players begin at level 1 with the app defaults.

**Add player** and the pencil beside the current player use the same grown-up gate
as Settings. Names can have 1–24 visible characters. The editor also offers
**Delete player**, with confirmation; at least one player must remain.
**Reset progress** affects only the current player and preserves their settings
and name. Portraits automatically show saved mane colors and headwear.

## Settings

Settings belong to the current player. Open the Home cog and answer the grown-up gate. Every valid change applies immediately and saves automatically; Back keeps changes. **Appearance** offers System (default), Light and AMOLED Midnight Rainbow Dark. **Tap Next** and **Haptics** default on; haptics also respect Android settings.

Each number game has its own range button in the upper-right. The compact settings icon and range on the right of its Numbers activity card open that game and its parent-gated editor. Number hunt and Number Order allow **0–100**; How many? and Make a group allow **0–20**. Set inclusive start/end values using the slider or exact +/− controls, with 0–5/0–10/0–20 presets. Each range contains at least three numbers and defaults to **0–10**. For example, Number Order can use **1–20** while Make a group uses **1–15**. 2048 remains independent.

The game pauses during range editing. Edits save automatically; closing starts one fresh round when the final range differs. An unchanged range preserves current work. Unfinished work earns no XP. The game waits for pending saves before resuming; a failed save offers retry even after leaving the editor. Existing saved numeral/counting settings migrate into the corresponding independent ranges.

**Letter Sounds** expands to individual letter choices. At least three distinct sounds must remain; c/k share one sound. **Sight Word packs** expands to checkboxes, word lists and a selection summary. Removing the last pack or too many sounds is prevented with an accessible explanation. Every accepted selection saves immediately.

Background saves are serialized. Later settings edits remain responsive and merge into the latest queued settings; failures retain the exact document for retry. Progress changes and player switching wait until saving finishes. There is no storage-write timeout.

**Reset progress** asks for confirmation, then clears the active player's XP, companion rewards, Tap Challenge/2048 scores, saved 2048 game and Writing progress. It preserves all settings. The multiplication gate is a simple child deterrent, not account security; settings require unlocking each time.

## Install the test APK

The ready-to-install file is **`artifacts/learning-corner.apk`**. Copy it to your Android phone and open it, allowing installation from that file manager if Android asks. No server is needed. Android 7.0 / API 24 or newer is required.

Alternatively, enable USB debugging, connect the phone, and run:

```bash
./tools/install_apk.sh
# When several devices are connected, specify the phone's adb serial:
./tools/install_apk.sh DEVICE_SERIAL
```

Installation uses `adb install -r` to preserve saved settings and player progress (the 0.4.0 upgrade intentionally removes old flowers). Uninstalling or clearing app data removes it. Test builds use this computer's Android debug signing key, including the release-mode APK. Keep using that key for updates to these installs; use a private release keystore before public distribution.

## Build and verify

Development baseline: Flutter **3.38.7**, Dart **3.10.7**, Java **17**, Android SDK **36**. Build dependencies may need downloading on the development computer; the installed game does not.

```bash
flutter pub get
flutter analyze
flutter test
python3 -m unittest discover -s tools -p 'test_*.py'
./tools/build_apk.sh
```

The build script creates a universal APK and SHA-256 checksum in `artifacts/`. Increase `version` in `pubspec.yaml` for the next named build. Keep `pubspec.lock` in version control for repeatable dependency resolution.

This workspace's snap launcher failed inside the execution environment. These overrides use the installed tools directly:

```bash
export FLUTTER_BIN="$HOME/snap/flutter/common/flutter/bin/flutter"
export ADB_BIN="$HOME/Android/Sdk/platform-tools/adb"
./tools/build_apk.sh
./tools/install_apk.sh DEVICE_SERIAL
```

`tools/codex_task.sh` runs a sandboxed Codex worker (GPT-6.1-Sol) on a task brief. Workers run Flutter/Dart through `tools/sdk_direct.sh`, which writes nothing outside the workspace and `/tmp`. Claude uses these to delegate implementation; see [Codex orchestration](docs/CODEX_ORCHESTRATION.md).

The 0.15.3 icon update passed **509 Flutter tests**, plus **16 capture scenarios with 64 images**. Formatting passed. Full analysis completed with no errors/warnings and 45 pre-existing informational style notices. See the [new icon gallery](docs/screenshots/0153/README.md) and [current validation](docs/testing.md) for APK evidence and limits.

Current 2048 captures: [phone/landscape/tablet and installed-release gallery](docs/screenshots/070/README.md).

Earlier ordering captures: [phone/landscape/tablet gallery](docs/screenshots/060/README.md), including installed-release dragging, correct placements and solved-board screenshots.

[Saved identification sound captures and pulse recording](docs/screenshots/081/README.md).

Earlier Letter friends captures: [voice on](docs/screenshots/052/emulator-voice-on.png), [voice off](docs/screenshots/052/emulator-voice-off.png), and [phone/landscape/tablet layout gallery](docs/screenshots/052/README.md) at normal and 200% text. The [0.5.1 gallery](docs/screenshots/051/README.md) retains home button and retry-animation evidence.

Historical screenshots: [home](docs/screenshots/home.png), [letter activity](docs/screenshots/letters.png), [reward](docs/screenshots/reward.png), [settings](docs/screenshots/settings.png), [Letters category](docs/screenshots/letters-category.png), [Numbers category](docs/screenshots/numbers-category.png), [success animation](docs/screenshots/success.mp4). See [current validation](docs/testing.md) for companion-adventure checks and their limits.

## Maintain and extend

| File | Responsibility |
| --- | --- |
| `lib/app_theme.dart` | Shared light/AMOLED palettes, Material themes and system bars |
| `lib/progress.dart` | XP curve, rewards, personal best and versioned save migration/validation |
| `lib/app_settings.dart` | Independent game ranges, activity caps and immutable player settings |
| `lib/widgets/number_range_editor.dart` | Gated autosaving range editor and game header control |
| `lib/progress_controller.dart` | Shared profile/gameplay persistence guard, durable publication and retry |
| `lib/profiles.dart` | Player identity, names, settings/progress envelopes and collection validation |
| `lib/screens/profiles_sheet.dart` | Minimal player picker and gated name/delete editor |
| `lib/widgets/profile_portrait.dart` | Cached static unicorn head portraits |
| `lib/widgets/parent_gate.dart` | Shared grown-up gate for Settings and player management |
| `lib/game_2048.dart` | Plain Dart 2048 rules and saved board validation |
| `lib/screens/game_2048_page.dart` | Swipe/keyboard play, saved victory, restart and responsive layout |
| `lib/widgets/board_2048.dart` | Pastel tiles, slide/pop animation and board semantics |
| `lib/tap_challenge.dart` | Plain Dart timed targets and scoring |
| `lib/widgets/tap_challenge_art.dart` | Companion-specific target skins, shared legend/art and neutral tapping icon |
| `lib/screens/companion_page.dart` | Picture tabs, focused previews, gifts and owned customization |
| `lib/widgets/companion_choices.dart` | Shared shaded portraits, item pictures, cards and category tabs |
| `lib/screens/tap_challenge_page.dart` | Timed play, record rewards and lifecycle handling |
| `lib/handwriting.dart` | Authored vector alphabet and offline geometric handwriting matching |
| `lib/word_bank.dart` | Curated CVC real/make-believe words, pictures and phoneme clip mapping |
| `lib/decoding.dart`, `lib/widgets/decoding_visuals.dart` | Read and find / Make-believe builders and visuals |
| `lib/widgets/sound_it_out.dart` | Shared explicit blending hint |
| `lib/word_sprint.dart`, `lib/screens/word_sprint_page.dart` | Word Sprint session, timer, hint sheet and personal best |
| `lib/number_sense.dart`, `lib/widgets/number_visuals.dart` | Same number / Number parts builders, ten frames and dot patterns |
| `lib/widgets/visual_question.dart` | `QuestionVisual` context and dispatcher used by GamePage |
| `lib/cursive.dart`, `lib/screens/cursive_page.dart`, `lib/widgets/cursive_pad.dart` | Original cursive stroke paths, families, pad and practice page |
| `tools/render_word_pictures.py` | Authoring-only renderer for `assets/words/` |
| `lib/writing.dart` | Saved shuffled alphabet and paired-form completion rules |
| `lib/screens/writing_page.dart` | Handwriting, letter picker, saved rewards and lifecycle |
| `lib/widgets/writing_pad.dart` | Bounded finger/stylus ink, practice rules and direction guides |
| `lib/letter_sounds.dart` | Basic sound spellings, reference pictures and parent selection validation |
| `lib/counting.dart` | Stable collection scenes and temporary marking/building state |
| `lib/widgets/counting_board.dart` | Silent tappable objects and counting frames |
| `assets/phonics/` | 24 bundled Noto hint pictures, provenance and checksums |
| `lib/game.dart` | Activity definitions, randomized questions, round progress |
| `lib/sight_words.dart` | Immutable word catalog and validated pack selection |
| `lib/ordering_game.dart` | Plain Dart ordering permutations, swaps, locked positions and completion |
| `lib/screens/ordering_page.dart` | Ordering activity, live saved case, lifecycle and completion |
| `lib/widgets/ordering_board.dart` | Responsive card grid, dragging, snapping, tap swaps and scrolling |
| `lib/widgets/learning_reward.dart` | Shared learning reward presentation |
| `lib/screens/home_page.dart` | Home, categories and root navigation |
| `lib/screens/category_page.dart` | Games grouped under Letters, Numbers, Words, Writing and Reflex |
| `lib/widgets/selection_card.dart` | Shared selection cards and responsive grid |
| `lib/screens/game_page.dart` | Questions, feedback, rewards |
| `lib/widgets/success_celebration.dart` | Short decorative sparkle animation |
| `lib/companion.dart` | Shared companion widget, bounded reactions and lifecycle |
| `lib/companion/` | Rigged foal clip timing, bounded streaming playback, posters and recoloring |
| `art/foal/` | Editable Blender source, skeleton/actions and authoring instructions |
| `assets/companion/foal_3d/` | Fitted WebP clips, independent material masks, posters, item atlas and checksums |
| `shaders/companion_hair.frag` | Shaded hair recoloring |
| `lib/device_services.dart` | Testable interface to Android audio and storage |
| `android/app/src/main/kotlin/com/rainbowgarden/rainbow_garden/MainActivity.kt` | Plays bundled WAVs; atomically migrates and stores the player collection |
| `android/app/src/main/kotlin/com/rainbowgarden/rainbow_garden/PromptAudio.kt` | Adds playback-only silence while preserving original speech samples |
| `assets/audio/` | 221 learning recordings, including 23 sound-only phoneme clips |
| `assets/audio_phrases.json` | Audio filenames and corresponding phrases |
| `assets/audio_manifest.json` | Voice configuration and request/audio checksums |
| `lib/number_range.dart` | Inclusive range validation and storage defaults |
| `lib/screens/settings_page.dart` | Parent gate, range controls, progress reset |
| `test/` | Randomization, scoring, navigation, error recovery, layout tests |

There are no third-party runtime packages beyond Flutter. Keep new game rules in the plain Dart model and platform calls behind `DeviceServices`. The game uses the Android [MediaPlayer API](https://developer.android.com/media/platform/mediaplayer/basics) through a [Flutter platform channel](https://docs.flutter.dev/platform-integration/platform-channels).

The bundled voice is **Google Chirp 3 HD Puck**, a male US English voice at 0.9× speaking rate. The current source and APK contain 221 WAVs: 196 identification targets, two matching instructions and 23 sound-only phoneme clips. Since 0.18.1, phonemes use Gemini 2.5 Flash/Pro TTS with Puck and explicit phonics instructions, tracked as phonics-directed-v2 (held L has a 700 ms cap/fade, phonics-directed-l-v3); the previous single-letter SSML requests produced letter names. Existing prompts remain Chirp 3 HD. c/k share /k/. All 43 Sight Words clips and 155 other active recordings remain byte-identical. The seven retired narration clips were removed in 0.17.0. The phone never contacts Google, and neither cloud credentials nor the generator ships with the app. Letter prompts use explicit SSML character pronunciation; numbers use cardinal pronunciation. Every original identification target prompt requests a 400 ms pause immediately before the letter, number or word. Words retain natural word pronunciation, including uppercase I, without character-spelling markup. The generator normalizes the longest interior quiet interval to 400 ms because the voice service can vary the requested duration, using 10 ms RMS windows and joining noise interruptions up to 30 ms, while retaining 50 ms at each quiet edge to protect speech onsets. Generated speech is not a human recording; check pronunciation and pacing on the phone before sharing.

The 24 reference pictures are rendered from the installed Noto Color Emoji font and bundled with provenance/checksums. `tools/render_phonics_pictures.py` reproduces them; no device font or runtime download is needed. [Listening review](artifacts/learning-0181/phoneme-review.html) provides all new sound clips for human pronunciation checks.

Normal builds verify and reuse the existing recordings, with no cloud access. To change prompts, edit `assets/audio_phrases.json`; letter pronunciation markup is maintained in `tools/generate_audio.py`. Generate only when needed:

```bash
# No network/authentication: inspect missing or changed prompts and estimated cost.
python3 tools/generate_audio.py --dry-run

# Refresh personal credentials without changing the active work account.
source ~/.config/learning-corner/personal-gcloud.env
gcloud auth login "$LC_GCLOUD_ACCOUNT" --no-activate

# Select account/project for this command only; default configuration stays active.
source ~/.config/learning-corner/personal-gcloud.env
python3 tools/generate_audio.py \
  --configuration "$LC_GCLOUD_CONFIGURATION" \
  --account "$LC_GCLOUD_ACCOUNT" \
  --project "$LC_GCLOUD_PROJECT"

# Offline bundle integrity check (also runs before every scripted APK build).
python3 tools/generate_audio.py --verify
```

Requires Python 3, authenticated gcloud and the local identity file described in [the runbook](docs/DEVELOPMENT_ENVIRONMENT.md#personal-google-cloud-account) on the development computer, with Text-to-Speech enabled and billing on the explicitly selected project. Phoneme authoring also requires aiplatform.googleapis.com for Gemini TTS; normal builds do not use either service. No Python packages are required. Target gaps are normalized locally with the Python standard library; if a clear interior pause is missing, generation stops for review. The processing version is recorded in the manifest. Successful clips are saved individually; rerunning skips matching request/audio hashes. Use `--clips welcome upper_a number_100` to regenerate a subset. Generation failures stop with an error and never fall back to the old robotic voice. Do not run multiple generators against the same asset folder simultaneously.

The original 159-clip batch used at most 6,623 input characters including SSML: roughly **$0.20** at $30/million, before free allowance or retries. The 0.3.0 cadence update regenerates 153 prompts with 14,864 input characters, approximately $0.45 before free allowance or retries; five other clips are reused. Future pricing and actual billed characters can differ. See [Chirp 3 HD documentation](https://docs.cloud.google.com/text-to-speech/docs/chirp3-hd) and [Google TTS pricing](https://cloud.google.com/text-to-speech/pricing).

## Workspace skills

`.agent-skills` lists the skills linked from `~/agent_toolkit/skills/` into `.agents/skills/` and `.claude/skills/`:

- `mobile-design`
- `flutter-development`
- `testing`

Claude Code and Codex are the supported agents. Both get the same MCP servers from `.mcp.json` and `.codex/config.toml`; see [the runbook](docs/DEVELOPMENT_ENVIRONMENT.md#project-mcp-servers-claude-code-and-codex).

The source repo is unchanged. On another development computer, clone agent_toolkit and run `~/agent_toolkit/bin/link_skills.py sync .` to recreate the links. After cloning this repository, also enable the secret-scanning hook with `git config core.hooksPath tools/git-hooks` and install gitleaks ([runbook](docs/DEVELOPMENT_ENVIRONMENT.md#secret-scanning-gitleaks-pre-commit-hook)). See `docs/design.md` for decisions and `docs/testing.md` for validation and the phone checklist.
