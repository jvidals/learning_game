# Learning Corner design decisions

## Compact uniform Numbers cards (0.20.2)

All five Numbers cards share a single height measured from their content at the actual card width and text scale, with a 102 dp minimum. Normal phone text restores the original height. Four applicable cards have a compact settings icon above their saved range on the right, replacing the play arrow; 2048 has neither arrow nor settings. There is no extra footer. The main card area launches the game and the range button remains independently accessible and parent-gated, with at least a 48×48 dp touch target.

At large text on narrow cards, illustrations stack above the title within the left area, while ranges remain on the right and may wrap without reducing text scale. All cards expand to the tallest required content, including 2048. The illustration's numeric example stays on one line. Home and other category cards retain their prior layout. Settings, caps, autosave, save format and navigation behavior are unchanged. This supersedes the footer layout in 0.20.1.

## Range shortcuts inside cards (0.20.1)

The settings icon and current range now sit in the **bottom-right corner inside each applicable Numbers card**, sharing its background and rounded border. The main illustration/title/play area starts the game; the footer remains a separate accessible shortcut to its parent-gated range editor. The footer has 12 dp horizontal and 8 dp bottom padding, no divider, and a minimum 48 dp touch target. Cards without a shortcut retain their prior layout. Existing range editing, autosave, caps and game restart behavior are unchanged.

## Independent number ranges and autosave (0.20.0)

Each player owns four inclusive ranges, default 0–10 and at least three values. Number hunt and Number Order allow 0–100; How many? and Make a group allow 0–20, including arbitrary bounds such as 1–15. 2048 remains independent. Legacy numeral settings seed both numeral games; legacy countingMax seeds both counting games. Existing malformed fields remain recoverable, without clamping or replacement.

Each applicable game has a 56 dp upper-right range button. The Numbers activity's separate accessible range shortcut enters that game and immediately opens its parent gate/editor, without playing a target first. The sheet has exact Start/End controls, a slider and 0–5/0–10/0–20 presets. It pauses input, ordering gestures, speech and automatic progression. Every accepted edit applies and autosaves; closing starts one fresh round only when the final range differs from the entry range, after saving succeeds. Canceling the gate or restoring the original range preserves work. Existing earned XP remains; unfinished work earns none. Small windows at 200% text place number-game titles below the action row so controls and the full title remain available.

Counting pools use both endpoints. Make a group always starts empty, including nonzero-minimum ranges, and its tray/addition capacity is its own maximum. It still requires Check, including zero. Objects and hints remain unboxed and silent; five correct questions still award durable 50 XP with balanced answer slots.

Main Settings no longer owns numeric ranges or a Save button. Valid changes apply immediately and save automatically; Back retains them. Appearance updates the existing route immediately. Prevent empty Sight Word selection or fewer than three distinct Letter Sounds, keeping the last required selection and showing accessible explanatory feedback. Clear letters is removed. Reset retains its confirmation and preserves settings after pending saves complete.

AppSettings now stores numberGameRanges with numberHunt, numberOrder, howMany and makeGroup min/max pairs. Profile schema version 1 and the native storage API remain unchanged. Strict legacy readers remain; migration updates valid profiles together without rewriting damaged neighbors. The controller exposes committed settings and effectiveSettings for immediate presentation. updateSettings derives edits from the latest effective state. One writer retains its immutable in-flight/failed document while coalescing later edits into one complete next snapshot, pinned to the original player. Retry completes the exact failed write before draining newer edits. Editing/Back stay available for pending settings; gameplay mutations, reset and profile switches remain guarded throughout. No write timeout or new service/package is introduced.

This supersedes historical Save/Back drafts and shared number/counting settings described in earlier release sections below.

## Personalized Home greeting (0.19.2)

Home greets the active player with **Hi, [profile name]!**, using the complete saved name with its existing spelling and punctuation. It replaces the visible app-name heading. When no profile is available during loading or recovery, show **Hi!**; do not invent a player name. The Android app label and Flutter application title remain Learning Corner.

Use the shared controller's committed active profile. Successful switches and renames update the greeting; pending or failed writes retain the previous saved name until retry succeeds. Reopening uses the saved active profile. The greeting is silent, with normal screen-reader text semantics. Keep the centered 36 dp heading, existing palette and natural multiline wrapping; do not truncate names or shrink away the user's text-size choice. Preserve the fixed profile/sound/Settings header and scrollable content below it.

No saved field, migration, public API, new narration or navigation change is needed. Validate default/short/24-character names, switches, rename cancellation/failure/retry/restart, unavailable profiles, both palettes and normal/200% text on phone/landscape/tablet. This supersedes only the Home-heading part of the identity decision below.

## Learning Corner identity (0.19.1)

Accepted September 19, 2026. **Learning Corner** is an offline learning game centered on activities and companions. This supersedes the earlier app-wide garden identity and the Learning Garden name. The main destination is **Home**; every action returning there and its accessible label says **Back to home**. Counting settings use **Counting**, the progress section uses **Player progress**, and instructions refer to objects rather than garden objects.

Unicorns and rainbows are the current companion theme. A future second companion/theme should broaden appeal, including for boys, with choices open to any player. Its specific design and selection flow are separate future work. App-wide names, navigation and learning instructions should work across companions; cosmetic themes must remain independent of game rules, reward accounting and player progress ownership.

This first step preserves My unicorn, the launcher icon, existing artwork, original equipment colors, and the approved Light/Midnight Rainbow appearance. It adds no theme selector or rendering architecture. The main Home layout, large accessible controls, continuous rounds and optional reward sheets remain. Game Back returns to its category; Back to home from rewards, Writing completion and Tap Challenge results returns to root Home. Settings Back discards drafts.

Android label and Flutter application title are Learning Corner. Home uses the personalized greeting described above. The APK and checksum use `artifacts/learning-corner.apk`. Android package `com.rainbowgarden.rainbow_garden`, Dart package/API names, `rainbow_garden/device`, SharedPreferences `garden`, save formats, player/equipment IDs and signing key remain stable. No migration or new runtime dependency is required. Historical release records and artifact names retain their original names.

Mobile checkpoint: Android/Flutter on existing phone/tablet layouts. Apply consistent visible/accessible naming, readable scaled text and unchanged navigation/save guards. Preserve current artwork and touch targets; avoid rebuilding the app identity through a storage or package migration. Feasibility 7 (platform 5 + accessibility readiness 5 − interaction 1 − performance 1 − offline dependence 1).

## Continuous rounds (0.19.0)

This supersedes earlier mandatory See my reward / Play again steps and the fifth-answer pause described below. All five-question learning activities and both ordering games stay on the solved game after completion. Existing 50 XP writes still start immediately; only committed completion shows “50 XP earned!” and “Level up!”. The primary action is Next round, with a secondary Rewards action. Tap Next on waits for a tap; off starts the next round after two visible seconds of saved completion. Accessible navigation always requires the button. Questions 1–4 keep the existing 800 ms automatic delay. Writing, 2048 and Tap Challenge retain their own flow.

A 56 dp gift button stays in the game header and announces the pending gift count. It opens a safe-area, scrollable sheet with live saved level/XP, the equipped companion, existing reward cards, a fixed Back to game action and Back to home. Claims use the shared controller, stay in the sheet and show updated equipment/choices only after saving. No gifts shows “No gifts to choose right now.” Gifts never expire and remain available in My unicorn. No extra setting, package, native API, saved field or asset generation.

Opening rewards synchronously pauses input, timers and speech; closing preserves the exact question, hints, counting work, ordering board and scroll state. An unanswered voiced target replays after dismissal; completed questions and counting/ordering remain silent. Pending gift writes continue after dismissal, block conflicting play/profile changes, and expose retry on the game. Backgrounding/coverage cancels delays; visible, unblocked restoration starts the full applicable delay. Normal rebuilds preserve elapsed delay. Round IDs guard stale timer callbacks and each replay creates a fresh ID. Save callbacks are accepted only for their originating round.

Completion controls sit below scrollable game content and scroll themselves only in constrained windows. Both themes, reduced motion and large text apply. Saved level-ups use a bounded inline rainbow burst and optional confirmation haptic once; opening rewards never replays that cue. Existing per-answer companion/star feedback remains. Ordering completion can reflow its solved board; the final placement snaps into the new cells and retains its single sparkle, while window/text changes still cancel movement and feedback.


## Generic counting activity icons (0.18.3)

Numbers uses companion-independent geometric illustrations for its two counting activities. How many? shows a large rounded question mark surrounded by one circle, triangle and square. Make a group shows five separated shapes (two circles, two triangles, one square) in a compact staggered cluster. Blue, gold and mint come from the current theme palette; foreground-colored outlines retain contrast. No individual boxes or animation.

Both illustrations fit 62 × 54 logical pixels inside the existing card icon area. They are decorative; card title/range semantics, tap targets and text scaling remain intact. Only the activity-list icons change; counting-game objects and behavior remain as approved. [Review gallery](screenshots/0183/README.md).


## Letter Sounds and Counting Garden (0.18.0)

Letters adds Letter Sounds; Numbers adds How many? and Make a group. The new activities use only essential target audio: isolated phonemes for Letter Sounds, no app narration for counting, instructions, hints, retries or rewards. Pictures, numerals and brief text carry instructions. Themes and wording are independent of the current companion; no second companion is implemented.

Letter Sounds practices 24 lowercase spellings (a–z excluding q/x), with short vowels, hard c/g and common consonants. c/k share one sound; each three-card question has three distinct phonemes and exactly one correct answer. Targets and distractors use the parent's enabled letters. At least three distinct sounds are required. Explicit hints reveal a reference letter, caption and bundled picture; mute/audio failure never reveal them automatically. The existing remembered sound toggle, explicit replay, route-entry delay, interruption cancellation and muted speaker cue apply. There are 23 phoneme clips: one /k/ clip serves c/k. Since 0.18.1 they use Gemini 2.5 Flash/Pro TTS with Puck, explicit phonics instructions and `phonics-directed-v2` processing with a 400 ms lead-in (held L uses `phonics-directed-l-v3`, a 700 ms cap and 20 ms fade). The previous single-letter SSML requests produced letter names; existing target-pause-v2 prompts are unchanged. Human listening remains necessary for pronunciation acceptance.

How many? shows a stable collection of apples, flowers or gems, with three numeral choices. Tap an object to mark/unmark it; check badges indicate marks without displaying a running total. An explicit hint numbers the objects and reveals the total. Rows, groups of five and bounded scattered arrangements vary quantities through ten; larger collections use two groups of ten. Per the 0.18.1 preference, objects and empty slots have no individual outlines or filled boxes, including hint examples. Group spacing and the outer counting area remain. Shapes stay still while counting, and only objects inside the counting area contribute.

Make a group shows a target numeral/object picture and a five-, ten- or twenty-space open tray. A large Add object tile appends one object; tapping a placed object removes it. Check evaluates the current quantity and preserves wrong attempts for correction. Zero can be checked with an empty tray. There is no running total or automatic acceptance. A hint shows a numbered example without filling the child's tray. Controls are taps; Check/Next stay fixed below the scrolling content. Next scrolls new visual prompts back into view. Resize/theme/background changes retain the current collection; leaving restarts an unfinished round.

Both counting activities use `countingMax` 5/10/20 (default 10), independently of the older 0–100 number range. `enabledLetterSounds` defaults to all supported letters. Both additive fields belong to AppSettings and use the current shared ProgressController/profile persistence. Missing fields use defaults; invalid present values remain recoverable. Save/Back, sound/case updates, reset and profile switches preserve the choices. No save-envelope migration or new platform API is needed.

All three activities reuse GameRound/GamePage lifecycle, durable completion and existing reward presentation. Choice games retain shuffled answer positions 2,2,1; Make a group has its own checked quantity input. Five correct questions award 50 XP once, saved before reward access. Tap Next, reduced motion, haptics and screen-reader behavior follow existing settings. Objects have 56 dp targets; exceptionally narrow windows scroll collections rather than shrinking hit areas. Large-text layouts scroll.

The counting approach is informed by [CKMath Numbers 1–10](https://www.coreknowledge.org/free-resource/ckmath-unit-2-numbers-1-10/) and [Numbers 0–20](https://www.coreknowledge.org/free-resource/ckmath-unit-6-numbers-0-20/). It is practice, not a claimed reproduction of a classroom sequence. School CKLA use was not assumed. Later beginning-sound activities should use pictures rather than narrated word names.

Mobile checkpoint: Android/Flutter, existing navigation and fully offline content. Apply visible tap controls, stable counting scenes and durable shared saves; avoid gesture-only interactions and automatic answer revelation. Feasibility 6 (platform 5 + accessibility readiness 5 − interaction 2 − performance 1 − offline dependence 1). Flutter, mobile and testing references applied. [Gallery](screenshots/0180/README.md).

## Reflex / Tap Challenge (0.17.0)

Reflex is a fifth standard Home category, opening an activity list with Tap Challenge. The category/activity illustration is a neutral tapping hand. Adventure and all reward-screen Adventure shortcuts are removed; My unicorn, learning rewards and the full-width Home header remain.

Tap Challenge is freely replayable for 30 active seconds. A 3×3 arena holds up to three stationary targets. Spawn every 600 ms; each target expires after 1.8 s. Every shuffled ten-target bag has six regular (+1), two bonus (+3), and two hazard (−2) roles. Score floors at zero; missed targets and empty taps have no penalty. Target IDs reject repeated/expired taps. The monotonic active clock ends input at exactly 30 seconds.

`TapChallengeSkin` maps the three roles to drawings and accessible labels; the same definition builds the legend and targets. The initial unicorn set is star/rainbow/cartoon bomb. Artwork never controls timing, score or hit areas. Select one skin at entry; future companion selection is not implemented here. All cosmetic sets share the player's Tap Challenge best.

Start requires an explicit tap after illustrated instructions. Pause, backgrounding, route coverage and layout-size changes freeze targets/time until Resume. Leaving abandons unfinished play with no XP. Results compare the final score, not its peak, to the saved best. The first positive score and every strictly better completed score earn 50 XP with the normal future-level gift accounting. Ties/lower scores earn none. High score, XP and reward identity commit atomically before the record reward appears. Save failures persist on the shared controller after navigation; replay stays disabled until saved. Results offer Play again, Back to Reflex and Back to home.

The game stays silent, honors saved Haptics, uses large stationary buttons and static point feedback, and retains screen-reader activation/labels. Accessible navigation does not silently remove the requested timer. Entry/results scroll at large text; landscape has a side status panel. Both palettes use existing semantic surfaces, with contrasting target outlines. No scenery, generated artwork, packages or network permissions are added.

Mobile checkpoint: Android / Flutter; mobile, Flutter and testing references read. Apply large stationary targets, interruption-safe active time and atomic offline saves; avoid color-only meaning and duplicate tap awards. Feasibility 4 (platform 5 + accessibility readiness 3 − interaction 2 − performance 1 − offline dependence 1); responsive/semantic and lifecycle validation is required.


## Activity illustrations (0.15.3)

Alphabet Order shows four rounded tiles in a fixed 2×2 arrangement: C A / D B.
Number Order uses the same illustration with 3 1 / 4 2. These are stable visual
examples; saved alphabet case and number range do not alter the icons.
Writing on Home and Handwriting in its activity list share an Aa practice-paper
illustration, with solid top/baseline rules and a dotted middle guide. The shapes
reuse the taught alphabet, including single-storey a.

The Flutter illustrations fit the existing 70×66 card icon area and use shared
Light/Midnight Rainbow colors. Cards retain their accessible labels, touch areas,
text scaling and navigation; decorative artwork adds no speech or controls.
Uppercase letters, Lowercase letters, Letter friends, 2048 and all other examples
remain unchanged. No gameplay, persistence or asset changes.
[Rendered gallery](screenshots/0153/README.md).

## Appearance: AMOLED Midnight Rainbow (0.15.0)

System, Light and Dark are saved per player in parent Settings. System is the
new-player and legacy-save default. Save applies drafts after persistence;
Back discards them. Reset, sound and alphabet-case changes preserve appearance.
System changes update active routes without resetting gameplay or temporary ink.

The dark theme uses #000000 backgrounds, dark surfaces and vivid rainbow
accents. Tap Challenge uses dark surfaces and vivid outlined targets; unicorn
and equipment colors stay recognizable. Writing uses dark pads with distinct
guides, arrows and mint ink. 2048 retains 14 distinct colors in both themes.
See [the design reference](dark_mode.md) for palette roles, contrast requirements,
Android startup behavior and instructions for future agents, and
[the comparison gallery](screenshots/0150/README.md) for rendered examples.


## Reward expansion (0.14.0)

The catalog contains 28 unlockable rewards. New additions are lavender, coral
and teal manes; seven nail-polish colors; heart tiara, lavender flower crown
and coral bow; fairy wings, mint feather wings and lavender butterfly wings.
Existing IDs and ownership remain stable. New entries interleave with the
original order, cycling polish, mane, headwear and wings. Each earned gift
still offers the next three unowned choices.

My unicorn has five picture tabs: Colors, Headwear, Wings, Nail polish and
Celebrations. Picture targets remain at least 64 dp in supported layouts;
narrow layouts wrap the tabs. The purple preview stays visible and fills its
panel. Nail polish uses the full-body view. All four hooves match; No polish
restores the source lavender hooves. Mane and polish unlock and save independently.

Adventure document version 2 persists `earnedRewardChoices`. Migrating
version 1 initializes it to min(level − 1, 12), preserving existing unclaimed
gifts without crediting levels earned after the old catalog was exhausted.
Unclaimed gifts can choose new items. Only future level crossings earn more
gifts, through learning rounds, Writing or 2048. The counter stops at the
current catalog size; later catalog expansion alone grants no extra gifts.
Reset clears the counter with active-player progress. Invalid counters or
ownership still cause the existing recoverable load error.

The shared palette in `art/foal/reward_palette.json` supplies all seven mane
and polish colors and the four equipment recolors. Export metadata carries
the palette into the offline app. One heart and one fairy geometry extend
the library to 25 outfits. Five full-resolution planes per frame carry color
and independent hair/hoof/headwear/wing masks. A 64 MiB shared decoded-image
budget accounts for 20 MiB animation frames, small posters and a bounded
detail cache. See [authoring instructions](../art/foal/README.md).

## Tablet layout (0.16.0)

Home uses a fixed, full-width safe-area header: profile at the left, sound then
Settings at the right, with 20 dp side margins and the existing 56 dp targets.
Only the activity content uses the centered 680 dp limit and scrolls. Header
controls retain the existing parent gates and pending-save guards.

Writing treats windows with a shortest side of at least 600 logical pixels as
tablets. During a lesson, the content column has at least the available viewport
height (less its padding), with spare space between the information header and
both drawing pads. Skip sits in that header; the pads end 16 dp above the fixed
action area. Measured text/footer heights determine the remaining space. Content
that does not fit scrolls without shrinking the pads or hiding Check/Continue.
Phone and narrow split-screen layouts retain their original arrangement; summary
and loading screens retain their normal flow. Pad dimensions and the 640 dp
content-width threshold for side-by-side pads remain unchanged.

This is a reach/placement improvement, not hardware palm rejection. A basic
capacitive stylus behaves like touch, so disabling touch would also disable that
pen. Keep the existing per-pad single-pointer ownership, out-of-bounds handling
and cancellation; blank margins do not create ink. Clear remains the sole erasing
control and does not revoke completion. No Undo, new settings or save migration.
Physical comfort with the daughter's Lenovo tablet/pen still requires her trial.

## Paired handwriting (Writing refresh)

Home → Writing → Handwriting uses one saved shuffled 26-letter alphabet per
player. Both forms together earn 10 XP once per pair/cycle. Either case may be
completed first. The tappable case badges always allow switching, retain green
completion checks, and keep independent temporary trace/freehand drawings.
Clear resets only the displayed case's ink and feedback, preserving completion.
Reopening selects the unfinished case, or uppercase if neither/both are done.

The compact header shows progress, case buttons and the XP/practice label.
Portrait keeps stacked 200 dp pads on screens at least 800 dp tall, 180 dp on
shorter screens; widths at least 640 dp retain side-by-side 240 dp pads.
Directions and solid top/baseline, dashed middle line and descender space remain.
The bottom action area stays outside the content scroll: Check changes to
Next: lowercase/uppercase or Next letter after a saved success. Returning to a
completed case exposes Continue immediately; redrawing exposes an additional
Check without hiding Continue. Large text on narrow screens stacks controls.
Typical portrait phones fit both pads and primary controls; small/large-text
layouts may scroll the pads. Skip remains a quiet secondary content action,
above the pads on tablets and below them on phones (see the tablet layout above).

The picker retains Aa–Zz and includes Shuffled alphabet above the practice grid.
Grid columns account for the widest rendered pair, current text scaling, button
padding and grid spacing. Pairs stay on one line at 26 sp; narrower or larger-text
layouts use fewer columns instead of clipping lowercase letters (0.15.1).
That option resumes the saved position, not a new shuffle. Entering manual
practice retains the paused shuffled pair's ink and selected case for this visit.
Choosing another manual letter starts fresh practice; the picker and practice
never award XP or advance the saved shuffle. New visits resume shuffled mode.
Skip advances the entire pair without XP, including partial pairs. Completing a
cycle reports actual matched pairs/XP, with no bonus; New shuffled alphabet
avoids repeating the previous last letter first. Next is always manual. Writing
is silent, haptics follow settings, and reduced motion uses static feedback.

The checker is bounded pure Dart geometry, not OCR. It first checks raw size
(70–130% of the example's height) and line placement (within .18 cap-height
units at top/bottom), then independently fits width and height for shape matching.
Ordinary widths from 50–185% of the guide are allowed; vertical-line letters
avoid magnifying pen wobble. It does not rotate or reflect the drawing. Modest
slant, uneven curves and small gaps can pass; stroke order/direction are not
graded. Direction arrows still teach the authored upright print, single-storey a/g.

After fitting, uppercase/lowercase distance tolerances are .14/.105 cap-height
units: at least 82% of ink must be near the guide and 80% of each guide stroke
must be covered. Mean bidirectional distance must be at most .085/.065. Closer
same-case alternatives that fit the original writing lines, reflected shapes,
and distinguishing stem/opening checks reject confusable letters. Length/input
limits reject excess marks. WritingEvaluation includes a structured rejection
reason; reliable size/line/missing-part failures give actionable guidance, with
generic retry for uncertain shape mismatches. Tests include all 52 independent
samples, their width/slant variations, wrong-letter comparisons and manually
reconstructed Q/j/h/u screenshot examples. These are not original touch traces
or a replacement for child usability testing.

The optional Writing subdocument is version 2: unchanged cycle ID, permutation,
index and completion bit masks, now allowing 2 (lowercase only), as well as 0/1/3.
Valid version-1 data loads without losing progress; malformed legacy data remains
an error. Completion plus any XP is committed atomically through the shared
profile controller; only the transition to both forms awards XP. Stale callbacks,
failed-write retry, profile isolation and reset retain existing safeguards.
This is separate from the Adventure document's reward-accounting schema version.

Ink stays in memory only. It survives case switching, ordinary backgrounding and
resizing; interruptions cancel only active strokes. Advancing the shuffle, changing
a manual letter or leaving the page clears the affected drafts. Drawing owns its
pointer; page scrolling remains outside the pads. Case buttons expose selected,
completed and enabled semantics plus a tap action. All drawing buffers and
animation controllers are disposed with the route.

Mobile checkpoint: Android / Flutter, existing mobile/Flutter/testing skills.
Priorities: recognizable writing, stable reachable actions, large drawing pads
and durable per-form progress. Avoid shrinking text for accessibility, hiding
Continue below the fold, and awarding before a successful save. MFRI remains 3.

## Local player profiles (0.11.0)

Profiles support multiple people sharing the same offline installation. Home keeps
its existing Home layout and adds a 56 dp circular portrait at upper-left. Tapping opens
a compact modal sheet with named portrait rows, a current-player checkmark, a pencil
for that player and Add player. At large text sizes, names use their own line.
Save status scrolls inside the list, including on short landscape screens.
There is no profile dashboard or startup selection step; the last player resumes.

Switching is unrestricted. Add/edit reuse `openParentGate`, extracted unchanged
from Settings apart from an action-specific explanation. The name editor trims
names, accepts 1–24 grapheme clusters, and offers Save/Cancel. Stable opaque IDs
own data, so renaming or duplicate names cannot move or overwrite progress.
Deletion confirms the player name, removes that player's data, and selects the
earliest remaining player. The final player cannot be deleted. New players are
selected after saving and start with empty adventure/2048 progress, pink mane,
0–10, Pack 1, sound/Tap Next/Haptics on, lowercase ordering off.
All settings are per player. Reset is scoped to the active player and preserves
name/settings; unreadable settings require explicit confirmed recovery to defaults.

The static portrait uses the production renderer's angled head/neck framing,
mane recoloring and fitted headwear, excluding wings. It shares cached posters and
the existing 64 MiB managed image budget and starts no animation player. Changes
appear after customization is saved. Profile screens are silent, preserve normal
Back behavior, and support TalkBack names, selected state and 200% text.

A version-1 `profiles` envelope stores active ID plus ordered player records with
ID, name, settings and encoded player progress. The nested document is version 3
as of 0.17.0; existing reward rules remain. Android copies legacy settings and the
exact legacy progress text into Player 1 and removes old keys in one commit. Existing
profile documents are always authoritative. A failed migration retains its exact
intended document for retry, including activity recreation in the same process.
Malformed player payloads remain encoded until explicitly recovered; a healthy
player can still be selected. Only an unreadable collection exposes the separately
worded parent-gated, confirmed reset-all recovery.

ProgressController remains the single writer for all operations, including
selection and management. Writes have no timeout; the full intended collection and
originating player ID survive failure/navigation. Switching stays blocked until
pending writes finish. Saved-before-publication behavior, immediate requested mute,
and exact in-memory 2048 move identity are retained. Switching clears transient
move/companion state and exposes the selected player's settings immediately.

Mobile checkpoint: Android / Flutter; existing rainbow theme, offline storage and
parent gate. Use large visible tap targets, cached static art and per-player durable
saves. Avoid extra management screens and per-portrait animation/decoding.
Feasibility: platform 5 + accessibility 4 − interaction 2 − performance 1 − offline
risk 1 = 5. Validation emphasizes migration, save failures and large-text recovery.

## Sight Words (0.9.0 source implementation)

Home → Words → Sight Words uses the existing five-question identification engine. The exact 43-word catalog is in `lib/sight_words.dart`: Pack 1 has eight words, Pack 2 thirteen, Pack 3 twenty-two. Display case is preserved, including I. Packs are independent, with Pack 1 enabled by default. Every target and distractor comes from the combined enabled pool, equally weighted by word. Each round has five distinct targets, three distinct choices per question, and shuffled 2/2/1 correct slots. Replay retains the selection. The fifth correct answer earns the existing once-only saved 50 XP.

Parent settings adds a collapsed Sight Word packs expansion below number controls, with a count summary and full-word-list checkbox rows. Unchecking the last pack immediately displays a red, announced “Choose at least one pack.” error. Save rejects an empty selection, expands the section and scrolls to it. Selecting a pack clears the error. Save applies all drafts; Back discards them. Expansion respects reduced motion. Saved `enabledSightWordPacks` uses stable pack IDs through the existing guarded controller/native atomic settings commit. Absent older preferences default to Pack 1. Present invalid values are rejected. Sound/case changes and progress reset preserve the selection; adventure storage does not change.

Word cards share 40-point, text-scaled lettering and the existing pastel feedback. Since 0.10.1, word identification games always use three full-width cards stacked vertically with 12 dp gaps and a 100 dp minimum card height. This user-approved default applies to Pack 1 alone, every pack combination, landscape and tablets, superseding the earlier word-length-based adaptive layout. The arrangement stays stable through the round and Play again. Words remain on one line, with scrolling at constrained sizes. Semantics say “Word …” and the speaker says “Turn voice on to hear the word.” Shared sound, explicit hints even on mute/failure, lifecycle cancellation, haptics, pacing and silent rewards remain unchanged.

Forty-three new `word_` WAVs say “Find the word,” then pause 400 ms immediately before the target. Puck at 0.9×, natural word pronunciation and `target-pause-v2` are used. All 162 earlier recordings are preserved, for 205 total. Generation used the runbook's explicit personal configuration/account/project, without changing work configuration or ADC. Normal builds remain offline with respect to narration.

Mobile checkpoint: Android / Flutter; existing rainbow theme and parent gate. Apply readable whole words, stationary large touch targets and interruption-safe reuse of identification behavior. No new runtime dependency or network permission. Validation includes all seven pack combinations and four screen sizes at normal/200% text. See current testing notes for validation outcomes.

## 2048 (0.7.0)

Numbers adds a freely playable 2048 activity, independent of the parent’s number range. The 4×4 rules follow the supplied Python example: two starting tiles, equal-value merges once per tile per move, score equal to merged values, and one new tile after a changed move (90% 2, 10% 4). No-op moves do not spawn, save or give haptics. Higher tiles continue beyond 2048. No moves left retains the finished board until Start over. As of 0.11.1, the saved final move finishes animating before a themed Game over dialog offers View board and Start over. The dialog explains that high score and earned XP stay; choosing Start over is the reset confirmation, so there is no second prompt. View board or Back dismisses without changing the save, and the dialog stays dismissed for that visit. Reopening a finished game shows it again. Covered/backgrounded pages wait until visible; an unacknowledged winning terminal move shows its win panel first. The old top-of-screen No moves left label is removed. Failed move/reset writes keep the existing retry path.

Controls are board swipes and attached-keyboard arrows/WASD only, as explicitly requested; no directional buttons are shown. Each gesture or key press produces at most one move; repeated key events, conflicting saves and active tile motion suppress extra input. Board swipes consume their gesture while the surrounding information can scroll. The board uses a dedicated 14-color palette through 16384, cream background, purple numerals, white edges, raised shadows and a gold 2048 border. As of 0.13.1, 2–64 retain the six original pastel backgrounds; larger values use coral 128 (#F29A87), amber 256 (#E8AD62), lime 512 (#B5CE72), turquoise 1024 (#67C7BE), gold 2048 (#F0CF58), periwinkle 4096 (#8FA7DE), orchid 8192 (#BD96DA) and rose 16384 (#DB8AB6). Values above 16384 reuse rose and remain playable. Stationary, sliding and merging faces share this palette, without changing the shared rainbow used elsewhere. All tile text retains at least 4.5:1 contrast with its background. Score and High score keep their digits on one line, fitting within their cards at large text sizes. As of 0.8.2, portrait play puts Score and High score above the board, and instructions plus Start over below it. Normal-text play anchors those controls at the bottom and fits all four board rows into the remaining space. Routine commits have no saving message; Start over retains its text and outline colors while its action is guarded during saves and tile motion. Save failures still expose retry. Large-text and victory layouts scroll; landscape uses a side information panel. Buttons remain at least 56 dp. Board semantics name all 16 positions and their values; move results have a concise live region. The screen is silent.

Committed moves slide over 180 ms and pop over 120 ms. A slide requests light feedback; a merge requests the existing placement cue; a first win replaces it with confirmation. All obey Haptics. Reduced motion displays committed tiles directly and a static winning companion. Coverage, backgrounding, resize and disposal cancel gestures and transient effects; a save finishing while hidden does not replay its effects on return.

The first 2048 tile saves **500 XP**, board, score, high score and win flag atomically. Each session earns it once; subsequent 2048/higher tiles only increase score. All levels crossed grant normal moves and available unicorn choices. The compact victory panel appears only after saving, using the currently equipped mane, headwear, wings and celebration through CompanionView. Keep playing saves acknowledgement and retains the board. Unacknowledged wins reopen with a static panel; XP/haptics/animation do not repeat. The celebration ends after its equipped duration (1.4 seconds for simple/hop; 2 seconds for bow/twirl), without idle animation.

One session and one all-time high score live in the optional `game2048` section of the per-player adventure JSON. Missing sections default to no session/high score zero; present malformed sections cause the existing recoverable load error, with no silent reset. Session fields are id, 16 row-major board values (0 means empty), score, moves, won and winAcknowledged. Validation checks integer powers of two, score bounds/multiples, high score, minimum tile merge scores and consistent win flags. Every other adventure mutation preserves this section.

ProgressController owns initialization, each changed move, restart and acknowledgement through the existing native atomic commit. The exact failed document—including the random spawn—is retained for retry after navigation. Writes have no timeout, and committed state is published only on success. A namespaced session ID occupies existing reward bookkeeping on the winning commit; the saved session win flag prevents re-awarding after learning rounds or reloads. Start over confirms before replacing the board, retaining high score and XP. The parent-gated whole-progress reset clears the session and high score while preserving settings. No new package, platform method, permission, recording or artwork asset is needed.

Mobile checkpoint (including 0.8.2 layout): Android / Flutter, existing offline architecture; universal and Android mobile references plus Flutter/testing skills applied. For the layout update, prioritize thumb reach, stationary controls and large-text scrolling; avoid transient save labels and disabled-color flashing. Priorities: deterministic rules, atomic saved outcomes, cancellable gestures and readable large text. The user explicitly chose swipe/keyboard controls over the skill’s suggested visible directional fallback. Feasibility: platform clarity 5 + accessibility readiness 4 − interaction complexity 2 − performance risk 2 − offline dependence 1 = 4. Physical TalkBack play, keyboard and haptic feel remain separate device checks.

## Voice only for learning prompts (0.6.2, 2026-09-14)

Voice supports the learning task. Rewards, retry encouragement and general app guidance are silent. This decision supersedes earlier narration behavior.

| Activity or screen | Voice policy |
| --- | --- |
| Uppercase letters, Lowercase letters, Number hunt | Current question prompts and Listen again; Home and game toggles share saved sound |
| Letter friends | Optional question instructions; local voice setting starts from home sound |
| Alphabet Order, Number Order, Tap Challenge | Silent, retaining visual instructions |
| Home, categories, My unicorn, all rewards | Silent |

Since **0.8.1**, Home and the three identification games share `soundOn`, saved through the existing controller and native settings commit. Missing preferences default on; parent Save, ordering case changes and progress reset preserve it. Muting stops active/preparing audio immediately. Unmuting an unanswered identification plays the current target once; unmuting on Home or after a correct answer stays silent. Pending sound writes immediately preview the choice, block conflicting writes/answers/advancement and retain retry after navigation. Disabled unanswered choices all use the same neutral color.

Identification has a 56 dp speaker button during questions, hidden on rewards. While muted, unanswered and without an explicit hint, its icon gently scales 1.0–1.12 with a circular highlight over a 1.8-second cycle. The hit target does not move. Hint, correct answer, background, route coverage, pending save and disposal stop the pulse. Reduced motion uses a static highlight. The stable accessible label explains “Turn voice on to hear the letter/number”; there are no repeated announcements.

All recognition answers appear only after **Show a hint**, including mute and audio failure. Listen again is hidden while muted. Letter friends retains its optional local choice through backgrounding, coverage and Play again, initializes from saved sound when reopened, and never changes shared sound. Enabling it stays silent and it never pulses.

`GamePage` requests only the current question's recording. Reward entry stops active/preparing speech and invalidates pending audio errors; stale replay callbacks cannot speak over rewards. Wrong answers request no audio and retain their visual marker, live-region text and separately throttled retry haptic. Correct-answer and level-up visuals/haptics, balanced rounds, pacing and saved XP behavior are preserved. System screen-reader announcements remain available.

Tap Challenge has illustrated instructions. My unicorn loses its speaker button. The unused spoken-help widget and sound arguments on silent destinations are removed. The 0.6.2 narration removal needed no save migration; 0.8.1 adds the optional `soundOn` native preference without changing player data. At that historical release, 162 WAVs remained bundled. Current 0.17.0 packaging retains 198 learning recordings and removes the seven retired narration clips. Target pauses remain 400 ms.

Mobile checkpoint: Android / Flutter with the existing offline boundary; mobile thinking, touch, performance, backend, testing, debugging and Android references reviewed with Flutter/testing skills. Priorities: preserve accessible controls and visual help, cancel preparing speech, retain immediate visual/haptic feedback. Avoid redundant controls on silent screens and new state-management layers. Feasibility: platform clarity 5 + accessibility readiness 4 − interaction complexity 1 − performance risk 1 − offline dependence 0 = 7.

## Correct placement haptic refinement (0.6.1)

Correct ordering swaps now request dedicated `DeviceFeedback.placement` once, even when both cards become correct. Android plays the existing confirmation followed by a light finishing tick 80 ms later. This extends the cue without changing ordinary swaps or other games' confirmations. The 80 ms is the pulse spacing, not a guaranteed vibration duration; physical feel depends on the device.

Both pulses use system-controlled `View.performHapticFeedback`; the tail is scheduled only when the first request succeeds. App Haptics off suppresses the request. New feedback, the shared stop call, backgrounding, loss of window focus and activity destruction cancel any pending tail. Older Android versions retain compatible touch-feedback fallbacks. No VIBRATE permission is added. See [Android haptic guidance](https://developer.android.com/develop/ui/views/haptics/haptic-feedback).

## Ordering games (0.6.0)

Alphabet Order is the fourth Letters activity; Number Order is the second Numbers activity. Each starts with a full shuffled permutation with no correct positions: 26 alphabet indices or every integer in the saved inclusive range. Order goes left to right, then top to bottom. Dropping on an unlocked slot swaps exactly two cards. Correct cards become pale green with dark green checks and lock; both exchanged cards can become correct at once. No penalties, timer, next-question pacing, or partial XP applies.

Cards have pastel surfaces, white edges and raised shadows. Press feedback scales to .97; a 300 ms hold begins dragging, with a 150 ms lift to 1.06. The source slot remains outlined. The card center selects the nearest existing slot with half-gutter tolerance. Locked targets, trailing empty cells, same-slot and out-of-board releases do not change the arrangement. Both exchanged cards settle over 200 ms, followed by the existing 550 ms sparkle/pop on newly correct cards. Ordinary swaps request one light haptic; a swap placing one or two correct cards requests one success cue instead (extended in 0.6.1 above). All haptics follow the shared optional boundary and settings.

An alternate two-tap interaction selects then swaps; tapping the selected card cancels. Semantics identify symbol/case, row-major position, selection and correct/locked state. A live region announces swaps and completed count. The A/a control has an accessible toggle action. Reduced motion retains direct finger tracking and static correctness/selection, without decorative motion.

The layout uses available width and height, normally 3–4 columns, 8 dp gutters and 64–112 dp squares. It can use more columns to fit a full board; the minimum is 48 dp, increasing with text scaling. Normal alphabet and default-range boards fit tested phone/landscape/tablet screens. Large ranges and constrained large-text windows scroll. A single board ticker scrolls within 48 dp of the top/bottom at up to 360 dp/second during a drag. The source recognizer stays alive when its row scrolls away. Resizing, route coverage, backgrounding and disposal invalidate the drag generation, hide its overlay and stop transient motion. Committed swaps survive backgrounding while the page remains open.

The live A/a toggle changes display only. SharedPreferences settings add `orderingLowercase`, default false, through AppSettings and the existing shared controller/native write guard. The board previews the case immediately, blocks more moves/toggles until persistence succeeds, and exposes retained retry on failure. Parent settings saves and progress resets preserve this preference. Play again and re-entry remember case; unfinished puzzles are not persisted.

Completion immediately requests the existing stable-ID 50 XP save. The solved board waits for successful persistence before offering See my reward. A retained failed completion can be retried after navigation. Both learning screens use shared silent reward presentation while retaining their own save and replay lifecycle. Existing recognition rounds remain balanced 2/2/1 and retain pacing, hints and retry behavior. No new audio, runtime packages, permissions or adventure document migration is needed.

Mobile checkpoint: Android / Flutter, existing offline architecture; universal/Android mobile references plus Flutter/testing skills applied. Priorities are usable touch targets, cancelable gestures and persistent-before-reward writes. Avoid gesture-only interaction and continuously animated off-screen cards. Feasibility: platform clarity 5 + accessibility readiness 5 − interaction complexity 3 − performance risk 2 − offline dependence 1 = 4; validate scrolling, interruption, large text and physical feel.

## Letter friends voice toggle (0.5.2)

Letter friends shows a speaker in the upper-right AppBar during questions; identification also has one since 0.8.1; since 0.6.2 it is hidden on the silent reward view. The 56 dp button exposes “Turn voice off” / “Turn voice on” and an accessible on/off state. The title can ellipsize at constrained widths while retaining its full accessible text.

The choice belongs to the current `GamePage` visit. It initializes from Home’s sound setting, survives questions, rewards, route coverage, backgrounding and Play again, and resets to the Home setting when the game is opened again. It is not saved and does not alter Home, customization or other activities. Identification games use the shared saved sound value since 0.8.1; other destinations are silent.

Voice off immediately stops current/preparing audio and suppresses matching instructions. Listen again is hidden while muted. Enabling voice makes no sound itself; later prompts and Listen again work normally. A request counter invalidates stale playback failures after muting, newer playback, stopping or leaving. Audio stop failures are harmless.

Matching always keeps its starting letter, instruction and choices visible. Voice off and audio failure do not reveal the answer; Show a hint explicitly reveals it for the current question. Existing hint behavior for other activities is unchanged. Haptics, visual retry/success, question balance, automatic/manual pacing and XP are independent of the toggle. No settings, persistence, platform API, assets or dependency changes.

Mobile checkpoint: Android / Flutter using the existing navigation and offline speech boundary. Apply accessible 56 dp targets, visit-local state and immediate audio cancellation; avoid automatic answer disclosure and global sound changes from this game. Feasibility: platform clarity 5 + accessibility readiness 4 − interaction complexity 1 − performance risk 1 − offline dependence 1 = 6. Relevant Flutter, mobile and testing skill guidance applies. Validate normal/200% text, both matching directions and both pacing modes.

## Interface refresh (0.5.0)

At 0.5.0 the app was named **Learning Garden**, superseded by Learning Corner in 0.19.1. Android package `com.rainbowgarden.rainbow_garden`, the `rainbow_garden/device` channel, `garden` preferences, equipment IDs and the version-1 adventure document remain unchanged. The test file for that historical release was `artifacts/learning-garden.apk`.

Home has no slogans or repeated XP explanation. Category cards keep examples, the numeric range and matching instructions. Puzzle retry reads “Try again”; idle encouragement is removed and static success remains. Rewards use “50 XP earned!”, “Level up!” and “Choose a reward.” Numeric XP, levels, progress bars, essential instructions and save errors remain. Rewards have 24 dp before My unicorn, even with no remaining gifts. The home My unicorn button shows a 40 dp present only with positive rewards. Its badge occupies its own space beside the present’s upper-right edge, separated from the label by 12 dp. At zero, only centered text remains, with no icon spacing. The accessible label includes the count only when positive. The shared controller updates it after a successful redemption. The reward-screen My unicorn button remains text-only.

`AppSettings.tapNext` and `haptics` default true for absent keys and new installations. Parent-gated switches are drafts until Save; Back discards them. Reset preserves range, Tap Next, haptics and other current settings. Native settings writes commit together through the shared controller.

Tap Next on keeps manual pacing. When off, correct answers 1–4 start an 800 ms timer; Next is hidden. Accessible navigation always keeps manual Next. Question 5 immediately starts the existing XP save and always pauses; See my reward stays disabled until success. Route coverage/backgrounding cancels automatic advance; returning starts a fresh 800 ms without replaying feedback. Back, replay and disposal cancel stale transitions. The reward view and replay start at the top of the scroll view.

The puzzle rainbow contains the equipped companion. Correct answers trigger a 550 ms happy pet response, the existing sparkle and a pop on only the newly filled star. Home and My unicorn pets have accessible tap actions and suppress duplicate taps during their response. A saved level-up celebrates once on entering rewards for the equipped duration: 1.4 seconds for simple/hop or 2 seconds for bow/twirl. The default celebration has a visible bounce; equipped celebrations use existing behavior IDs. Typed `CompanionReaction` plus an explicit `reactionTrigger` separates event handling in the companion widget from drawing. A future species can replace the painter without changing callers or save IDs.

Reduced motion keeps the timing and uses a static happy face/filled star. Covered routes and backgrounding stop reactions. Haptics are optional typed `DeviceFeedback` requests: light for correct answers, pet taps, explicit previews and committed customization/reward choices; confirmation for saved level-ups when entering rewards. Retried writes emit a cue only after success. Failed saves and duplicate taps have no added cue. Wrong answers use the retry cue described below. Android uses `View.performHapticFeedback`, system touch settings and a window-focus guard; CONFIRM is used on API 30+ with a compatible fallback. No VIBRATE permission is added. [Android haptic guidance](https://developer.android.com/develop/ui/views/haptics/haptic-feedback).

Sound-on no longer plays welcome. All bundled recordings and scenery are byte-identical to 0.4.2, including the 400 ms target pauses.

Mobile checkpoint: Android / Flutter, existing navigation and offline boundary. Read the mobile universal/Android references and Flutter/testing skills. Apply generous controls, explicit success/save states and lifecycle cancellation; avoid layout movement and background animation. Feasibility: 5 + 4 − 2 − 2 − 1 = 4; validate large text, interruption and on-device feel.

## Mobile checkpoint

Android first, primarily Pixel 9 Pro, with phone, landscape and tablet layouts. Flutter only at runtime, Material controls, offline from first launch. No accounts, analytics, network permissions or runtime downloads. The rainbow palette belongs to the current companion theme; the current appearance contract includes Light and Midnight Rainbow.

Mobile feasibility for this extension: platform clarity 5 + accessibility readiness 4 − interaction complexity 2 − performance risk 2 − offline dependence 1 = 4. The board adds motion, but explicit taps, bundled art, plain Dart rules and a small storage boundary keep complexity bounded. Validate large text, interruption and performance. Universal mobile references and the Android platform reference were read during implementation.

## Retry refinement (0.5.1)

A wrong option shows a coral-red × in a 24 dp pale circular marker at its upper trailing corner. The marker overlays the answer card without changing layout, hit handling or semantics. It holds for 150 ms, fades linearly for 450 ms, then disappears. Reduced motion shows a static marker for 600 ms. The “Try again” live region and bundled retry recording remain; no penalties or learning progress changes apply.

Repeated taps on the currently marked wrong option are ignored. A different wrong option replaces the marker and restarts its 600 ms visual duration. A separate 600 ms cooldown throttles retry haptics; since 0.6.2 retries request no audio. Correct answers immediately clear the marker, stop speech and start normal success feedback. Next, replay, covered routes, backgrounding and disposal cancel transient feedback; it never returns on resume.

`RetryMarker` is separate from `SuccessCelebration`; `GamePage` owns the transient option, animation and cancellable timers. `DeviceFeedback.retry` uses Android [REJECT on API 30+](https://developer.android.com/reference/android/view/HapticFeedbackConstants#REJECT) and VIRTUAL_KEY on older supported devices. Sensation is device-defined. The existing Haptics switch, system settings, focus guard and failure-safe optional boundary apply. No new permissions, packages, recordings or persistence fields.

Mobile checkpoint: Android / Flutter; universal and Android mobile references plus Flutter/testing skills read. Apply stationary large touch targets, text-scaled layout and interruption-safe local state. Avoid blocking answer input and continuous retry animation. Feasibility: platform clarity 5 + accessibility readiness 4 − interaction complexity 1 − performance risk 1 − offline dependence 1 = 6. Original screenshot attachments were unavailable in the implementation context; layout verification follows the supplied plan’s explicit gift/count and zero-state specifications.

## Learning and XP

Home → Letters/Numbers → activity → learning round remains intact. Letter activities use **Uppercase letters** and **Lowercase letters**; descriptions and all letter-case speech use uppercase/lowercase terminology. Letter friends matches the two cases in both directions. Game Back returns to its category. Reward Back to home returns to the root home route. Play again keeps the activity and saved number range.

Each recognition activity has five questions with three answer choices. Answer slots remain balanced 2, 2, 1 with a random singleton slot and shuffled order, including Play again. Targets exhaust their pool before repeating and avoid adjacent repeats for small number ranges. Letter friends matches in both directions. Unlimited hints and retries do not reduce rewards.

The fifth correct answer immediately starts a **50 XP** save. Unfinished rounds earn nothing. XP begins at zero and level 1. XP is authoritative; level and within-level progress are derived:

| Level reached | Additional rounds | Additional XP |
| --- | --- | --- |
| 2 | 1 | 50 |
| 3–4 | 2 each | 100 each |
| 5–7 | 3 each | 150 each |
| 8 onward | 4 each | 200 each |

Each level grants one companion reward choice while unowned rewards remain. Available choices = saved earnedRewardChoices − number owned. The counter credits future level crossings up to the catalog size; version-1 migration uses min(level − 1, 12). Nothing expires; there are no daily limits.

Correct answers stop speech and retain the 550 ms rainbow sparkle/pop effect with silent static success text. Reduced motion removes the effect. No repetitive correct-answer recording is present.

## Companion rewards

The initial unicorn has a pink mane, no headwear or wings, original lavender hooves (No polish), and a simple celebration. The 28-item mixed catalog preserves the original twelve IDs and their relative order while interleaving the new polish, mane, headwear and wing rewards. Up to three unowned items are offered at a time. Choosing an item saves ownership and equips it atomically. Skipped choices remain unowned and available later. Owned choices can be freely equipped or removed; one option per category is active. After all 28 unlocks, levels continue and customization remains available.

### Picture-led customization (0.4.1)

My unicorn is designed for a child who cannot read. Five large picture tabs show a mane, an example crown, feathered wings, a hoof and a hopping unicorn. They select Colors, Headwear, Wings, Nail polish and Celebrations. Each tab shows only owned items plus its default; colors apply to the mane and tail, and accessories retain their existing designs. Short supporting labels and explicit TalkBack names remain available, but reading is not needed to choose an item.

The main preview stays above the controls on portrait phones and beside them at widths of at least 600 dp. Mane/headwear show a clean head portrait, wings focus on the body, and nail polish/celebrations show the whole companion. Choices scroll independently. Tabs are at least 64 dp on the supported small-phone layouts; choice cards exceed 88 dp, separated by 12 dp. The saved choice has a strong border and checkmark. All five defaults remain available even before the first reward.

Since 0.12.2 the companion fills the preview panel's entire viewport without
inner padding. Focus rectangles set category zoom and centering, while artwork
can extend beyond them to the panel's rounded outer edge. Panel dimensions,
12 dp outer margin, 28 dp corner radius and gift-button placement remain.
Only this stage disables `clipToFraming`; other companions, profile portraits
and item thumbnails retain the default focus crop. The feathered Wings tab
icon is illustrative and does not grant or equip wings automatically.

A gift button with a pending-count badge opens a scrollable reward sheet. A single tap collects and equips the selected reward through the existing controller. Only successful persistence closes the sheet and selects the matching customization tab. Dismissal never cancels a pending save or discards its retry. Learning rewards use the same picture cards and bring the updated companion back into view after collecting. The mixed catalog offers the next three unowned rewards; legacy unclaimed gifts can choose new additions.

The renderer shares production artwork between static thumbnails and the companion. Mane choices use shaded portraits, accessories and wings use isolated renders of their actual geometry, and celebration cards pair static poses with movement arrows. Selecting a celebration or pressing its play button runs a complete demonstration: 1.4 seconds for simple/hop or 2 seconds for bow/twirl. Category changes, backgrounding, covered routes and disposal stop demonstrations; reduced motion uses static feedback. Since 0.6.2 customization is silent and has no speaker button. The 0.9.0 companion update uses an editable Blender rig and bundled 60 Hz rendered clips, without a live 3D runtime, new runtime dependencies or companion save-schema changes.

Wings attach near the shoulders and sweep rearwards. Headwear inherits the head transform and is rendered with correct near/far occlusion during turns. The bow folds one foreleg backward beneath the chest while the other extends; supporting hooves stay grounded. Bow/twirl use two-second clips rather than accelerated 1.4-second motion. Idle remains eight seconds and happy feedback 550 ms. CompanionView owns one-shot completion. Adventure-only walk/travel clips were removed in 0.17.0. Twenty-five fitted headwear/wing outfits share seven mane colors, seven independent polish colors and four equipment recolors. Playback streams quarter-second segments with lookahead only for a single visible player and a shared 64 MiB managed-image limit; static choice thumbnails do not decode animation clips. See [editable source and export contract](../art/foal/README.md).

Mobile checkpoint for this update: Android / Flutter, established fixed palette and offline storage. Apply picture recognition, generous tap targets and a persistent preview; avoid text-only choices and continuously animated thumbnails. Feasibility: platform clarity 5 + accessibility readiness 4 − interaction complexity 1 − performance risk 2 − offline dependence 1 = 5. Read the mobile universal/Android references and Flutter/testing skills; validate layout and lifecycle behavior.

## Persistence, migration and settings

`ProgressController` owns every profile/progress/settings mutation, publishes only durable state, retains exact failed writes without a timeout, and blocks conflicting operations/player switches until retry. The native boundary remains the version-1 profiles envelope under SharedPreferences `garden` / `profiles`.

Each profile now stores version-3 `PlayerProgress`: XP, earned reward choices, owned/equipped rewards, last rewarded round ID, Tap Challenge high score, 2048 and optional Writing. Valid version-1/2 saves migrate through the shared guard across all valid profiles; malformed documents/settings remain unchanged for parent-gated recovery. The legacy native `adventure` key remains solely for upgrades from pre-profile installs. Retired moves, visits, destination bests and relaxed mode are removed; Tap Challenge best starts at zero. Existing XP, gifts, equipment, Writing, 2048, settings, names and stable IDs remain.

Settings retain their parent gate and Save/Back draft behavior. Reset confirms clearing the active player's progress, including Tap Challenge best, while preserving name and remaining settings. The untimed-mode switch has been removed.

## Offline audio and validation

Since **0.15.2**, the first automatic learning prompt waits for the route entrance
transition and its painted frame. Leaving, muting, answering, explicit replay,
coverage or backgrounding cancels it. Existing manual replay, Next and sound
semantics remain. Android adds 300 ms of playback-only leading silence through
the same MediaPlayer stream to protect speech onset when the speaker pipeline
starts cold. All original speech samples and 400 ms interior target pauses remain
unchanged; the silent lead-in also applies to later/replayed prompts after idle.
This is bounded per-prompt silence, with normal stop/release and no keep-alive audio.
Phone listening is required to verify the reported clipping is resolved.


In 0.4.2 the 52 alphabet target recordings and two matching instructions were regenerated with uppercase/lowercase wording; the other 108 recordings stayed byte-identical. Stable clip IDs preserve routing. The current APK ships 198 learning WAVs: 196 identification targets and two matching instructions. Seven unused narration clips were removed in 0.17.0. All target recordings retain `target-pause-v2` processing and the 400 ms pause immediately before the spoken target. The voice remains Google Chirp 3 HD Puck, US English, 0.9×. Generation uses explicit personal configuration/account/project flags without changing active work configuration or ADC.

Bundled instructions always have visual equivalents. Navigation, backgrounding and disposal stop speech. Generation is a development-only operation; normal builds verify and reuse recordings. See [testing notes](testing.md) for current checks, historical checks and remaining physical-device validation.


## Companion grounding and Home size (0.12.1)

Home gives the companion a 240 dp display height, one-third larger than its
previous 180 dp default. The existing scrollable layout accommodates small
screens and large text; other screens keep their current companion sizes.

The four model hooves share the same ground plane. The fixed three-quarter
camera projects the rear hooves higher on screen. The shared painter therefore
uses a soft, angled ground shadow spanning both pairs: center (502, 872), size
400×100, rotation −14.5°, blur sigma 8 and color 0x1839234F in the 1000-unit
canvas. It stays on the ground during reactions, shares the companion's scale
and mirroring, and is omitted from head portraits. Model geometry, rendered
assets, framing bounds, timing, gestures and persistence are unchanged.

## Revision-five companion artwork (0.12.0)

The approved horse-reference revision replaces the production companion library.
It keeps the longer body and straighter hind legs, adds a deeper rounded muzzle,
and restores eyelid-attached lashes plus a hinged lower jaw and moving tongue.
The happy expression uses the existing feedback control; idle stays relaxed.
All actions, equipment IDs, unlocks, four mane colors and static/animated screen
boundaries remain unchanged. The source is still Blender; the app still displays
bundled rendered clips with the same quality and memory contract.

Historical models, references, review galleries and the prior APK are retained
outside bundled assets for future refinement. The APK contains only the current
complete library. Source and APK checks reject stale/unreferenced files,
duplicate ZIP entries and authoring/review material. Normal builds also reject
the timing entrypoint; an explicit local profiling mode writes a separate APK.

## Playful Spark rendering (0.10.0)

The user-selected C concept guides the editable model: fuller cheeks, a shorter
muzzle, larger eyes, outward ears, compact limbs/body and a curled tail. Remove
all forelock/top-of-head mane; neck locks begin behind and below the ears.
Headwear follows the head bone; wings stay at the shoulders and flow backward.
Pink remains the default, with the existing blue, mint and gold choices and all
saved equipment IDs/unlocks preserved.

A relaxed smile and one happy smile shape share the existing blink/expression
control. No full facial rig or speech animation is added. Idle is still an
eight-second, 480-sample loop: staggered lateral weight shifts, a head tilt of
at most 2.5°, individual ear flicks, a small tail swish and irregular blinks.
Body movement stays below 1% of standing height; all four hooves stay fixed.
There is no breathing, torso scaling, bounce, stepping or idle wing flapping.
Quiet endpoint rests give matching position and velocity across repetitions.

Existing animated companions use the new loop. Learning questions and the
2048 win panel retain static idle artwork and their existing triggered
feedback. Item cards remain static. Reduced motion, visibility/background
cancellation, reaction priority, retry and the shared 64 MiB managed decoded
image cap remain in the existing Flutter player. Action durations, rendered
WebP segment format, public interfaces and save schema are unchanged. The cap
excludes engine-internal codec/GPU memory.

## Gentle foal rendering (0.8.0)

The selected shaded-cartoon Gentle foal is shared by Home, learning feedback, rewards, My unicorn, Tap Challenge and the 2048 win panel. Existing pink/blue/mint/gold, flower/bow/star, feather/butterfly/rainbow and celebration IDs remain unchanged. Choice pictures share the production art. All assets and the recoloring shader are bundled offline.

A continuous painted skin follows neck/head, four leg/knee chains, ear and tail joints. Separate source parts remain available for editing. This avoids exposed cutout outlines at joints. Hair colors retain the original shading. Idle runs for eight seconds; happy feedback lasts 550 ms. Simple celebration, hop, bow and twirl each finish after 1.4 seconds. Every reaction is bounded, including older callers that omit `boundedCelebration`. Hidden/backgrounded reactions cancel without replay. Reduced motion uses a static neutral/happy expression; learning-game idle remains off.

Twirl uses sixteen ordered generated views, with separate front/rear/side equipment artwork and tracked attachments. Angular spacing and proportions are approximate, not a geometrically exact model; this is recorded in the production artwork notes. The future dinosaur is a separate companion rather than a unicorn transformation.

One shared, retryable asset cache keeps four skin colors, equipment/turn atlases and two small eye patches. It does not grow with outfit or route count. Image decoding and color-skin preparation occur before painting; missing art offers a local retry and never changes player data.
