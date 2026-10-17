# First spoken prompt investigation — September 18, 2026

## Follow-up: speaker onset protection in 0.15.2

The user clarified that **the beginning is missing**, using the **phone speaker**.
Bluetooth is not involved. This supports a cold-output/startup hypothesis but does
not by itself prove a device-specific root cause.

Implemented two protections: defer automatic entry speech until the actual route
transition and visible frame finish, and prepend **300 ms of silence** to each
recording in memory for playback through the same MediaPlayer output stream.
A wall-clock delay by itself would leave that output stream cold. Android's
[documented warmup guidance](https://developer.android.com/ndk/guides/audio/audio-latency#minimize_warmup_latency)
describes feeding silence before desired audio. The 300 ms duration is a bounded
mitigation to test on the affected phone, not a measured hardware guarantee.

`PromptAudio.kt` accepts the existing canonical 24 kHz mono PCM16 WAV format,
updates only the playback buffer's RIFF/data lengths, and inserts zero samples
before the complete original sample sequence. Assets on disk and in the APK,
including the target-pause-v2 interior pauses, remain byte-identical. MediaPlayer
still prepares asynchronously and releases on completion/cancellation/background.
No continuous silent track, background service, permission or runtime package was
added. A stale native error callback cannot stop a newer player.

The new `test/audio_startup_test.dart` covers transition timing and cancellation.
The dependency-free JVM check is `tools/test_prompt_audio.sh`; all 205 recordings
preserve every PCM sample and nine malformed formats are rejected. All 509 Flutter
tests passed. See [current validation](testing.md) and
[APK report](../artifacts/audio-startup-0152/apk-verification.json).

Phone listening remains necessary: open a voiced activity after force-closing the
app or leaving audio idle, check that the entire introductory phrase is audible,
then compare Listen again. Repeat across letters, numbers and words. The emulator
and byte-level tests do not establish perceived audio onset on the Pixel.

The remainder records the **pre-patch investigation**, including its baseline
source line numbers and historical diagnostic trace.

Scope: investigate the reported clipped voice when a learning game opens, with
successful Listen again playback after a few seconds. Production code, recordings,
version and distributable APK remain unchanged. Audible clipping has not been
reproduced on a physical device in this session.

## Confirmed findings

- `lib/screens/game_page.dart:200` calls `_playPrompt()` directly from `initState`,
  before the first game frame and before `didChangeDependencies` establishes actual
  route visibility. `_visible` and `_foreground` initially default to true.
- A widget diagnostic using the real Home → category → game navigation observed
  the first play request at the initial route frame for Uppercase letters,
  Lowercase letters, Letter friends, Number hunt and Sight Words. The entrance
  animation remained `forward` through 450 ms and was `completed` at the 500 ms
  sample. These are test-clock observations at 50 ms intervals, not phone timings
  or measurements of when sound reaches the speaker.
- In all five activities the command sequence was `stop`, then one `play`.
  No subsequent stop interrupted the first prompt during the sampled entrance.
  Listen again requested exactly the same clip after the transition completed.
  Ordinary navigation cancellation was therefore **not reproduced** as the cause.
- Android creates a fresh MediaPlayer for every request, including Listen again,
  opens the complete bundled WAV, calls `prepareAsync`, and starts only in
  `OnPreparedListener` (`MainActivity.kt:138–158`). It does not seek, trim the start,
  or start before preparation. This follows Android's documented
  [MediaPlayer preparation lifecycle](https://developer.android.com/media/platform/mediaplayer/state-resources).
- Offline verification passed for all **205 recordings**, with zero generation
  required. This checks file integrity/format against the existing manifest;
  it does not prove subjective speech quality. The target-pause processing and
  bundled audio were not changed.

## Interpretation and next experiment

The reported timing suspicion is plausible: the automatic prompt is requested
while the new screen is still being established. The trace establishes that
ordering, but does **not** establish that the route transition drops audio samples.
Android also documents [audio pipeline warmup latency](https://developer.android.com/ndk/guides/audio/audio-latency),
which is a separate possible factor; it is not evidence of clipping on this phone.
Both initial and replay requests construct a fresh player, so a reused/prepared
MediaPlayer does not explain replay succeeding.

The smallest candidate change is to schedule the first automatic prompt after
the route entrance has completed and its visible frame has been painted. Bind it
to the actual transition rather than guessing a multi-second delay. Cancel the
pending prompt on mute, correct answer, explicit replay, route coverage, Back,
backgrounding and disposal; preserve silent Letter friends unmute and existing
Next/Play again behavior. A post-frame callback alone would still run during the
entrance animation. This change remains a proposed experiment, not a verified fix.

To distinguish causes, establish whether the beginning is missing or the clip
starts and then cuts off, and whether output is the phone speaker or Bluetooth.
Then compare cold entry versus Listen again on that output with native
prepare/start/completion/error/lifecycle timestamps. Confirm a candidate fix by
listening on the affected device; widget tests cannot do that.

## Checks in this session

- **65 tests passed**: five navigation/audio diagnostic cases plus existing
  `voice_toggle_test.dart`, `identification_voice_test.dart` and
  `sight_words_widgets_test.dart`.
- **205 bundled recordings verified offline** with
  `python3 tools/generate_audio.py --verify`.
- Diagnostic Dart formatting passed. No production Dart changes were made, and
  full analysis/full-suite tests/APK build or device installation were not run.
- No phone, emulator, host limits, cloud configuration or skill sources changed.
  Shell calls used normal reviewed escalation after the sandbox failed with its
  existing bwrap loopback error.

Evidence: [diagnostic source](../artifacts/audio-entry-investigation/entry_trace_test.dart)
and [test output](../artifacts/audio-entry-investigation/tests.log).

Reproduce from the project root:

```bash
/home/jvidals/snap/flutter/common/flutter/bin/flutter test --no-pub \
  artifacts/audio-entry-investigation/entry_trace_test.dart \
  test/voice_toggle_test.dart test/identification_voice_test.dart \
  test/sight_words_widgets_test.dart --reporter expanded
```

The diagnostic is intentionally outside the regular test directory: it records
the current early-start behavior for investigation, rather than treating that
behavior as a permanent product requirement.
