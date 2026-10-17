# Install Learning Corner on an Android phone with ADB

APK/emulator validation updated September 19, 2026; USB setup reviewed September 15.

## Your system

| Item | Finding |
| --- | --- |
| Computer | Ubuntu 24.04.5 LTS |
| ADB executable | `/home/jvidals/Android/Sdk/platform-tools/adb` |
| ADB version | Android Debug Bridge 1.0.41; Platform Tools 36.0.2-14143358 |
| Shell PATH | `adb` was not found by `command -v adb`; use the path below |
| USB permissions | `jvidals` already belongs to `plugdev` |
| Android USB rules | `/usr/lib/udev/rules.d/51-android.rules` exists and grants matching devices access through `plugdev` and `uaccess` |
| Connected devices | No device installation during 0.20.2; prior 0.20.0 disposable-emulator results are historical |
| APK | `/home/jvidals/Documents/ScriptWork/learning_game/artifacts/learning-corner.apk` (version 0.21.0+45, about 671 MB) |
| App package | `com.rainbowgarden.rainbow_garden` |

ADB is available without installing another copy. The existing USB setup looks ready, but detection of your specific phone still needs checking when it is plugged in. The APK requires Android 7.0 / API 24 or newer.

The previous **0.18.1+36** APK removes counting item boxes and replaces Letter Sounds alphabet-name recordings with phonics cues.
Offline in-place upgrade on the isolated LearningGardenWriting emulator preserved
player progress, Writing and 2048. New rounds and parent settings passed installed-app
checks. The new phoneme recordings still need human pronunciation and physical-speaker
listening review. [Current validation](docs/testing.md).

The earlier **0.15.2+31** APK added audio-startup protection. It passed in-place
upgrade and native playback checks on the isolated LearningGardenWriting emulator,
preserving visible progress and restoring its muted sound setting. No phone was
installed to; listening on the affected phone remains necessary to confirm the
missing beginning is resolved. [Audio validation](docs/testing.md).

The **0.15.0+29** APK added AMOLED dark mode. An offline `install -r` upgrade from
0.14.0 on the verified disposable emulator retained the player, XP, moves,
sound and Writing progress. System appearance changes, per-player overrides and
restart persistence passed. See [dark-mode validation](docs/testing.md).

The previous **0.14.0+28** APK combines the new rewards and finished Writing refresh.
Offline in-place upgrade from 0.13.0 preserved the player, progress, settings and
Writing position; polish equip/removal, future gifts and independent mane/polish
survived restart. The installed checksum matched the distributable. The
disposable emulator was stopped with its data preserved; no phone was used.
Verify the device serial and use the approved installation script with
`install -r` to preserve progress. See [validation notes](docs/testing.md).

The previous **0.18.3+38** APK updates only the two counting activity icons. Build/signature/offline asset checks passed; no device installation was performed for this icon-only release.

The previous **0.19.0+39** APK adds continuous rounds and optional reward review. The verified isolated emulator passed an offline install-r upgrade, direct/automatic replay, reward-sheet return, root navigation and restart with Writing/2048 preserved. Final test progress is 560 XP/level 6 and three gifts, with original sound off and Tap Next restored on. The installed SHA-256 matches `945a59d8dbcceb97e63000f7e8c362d32c2cbae9d85ead91fa7b359fe94d30a9`. No phone was installed; the emulator was stopped preserving its data. [Validation](docs/testing.md).

The previous **Learning Corner 0.19.1+40** APK updates the app name and Home wording. Package identity, original signing key and all bundled assets were verified against 0.19.0. SHA-256: `cec00b4b7c7dba53e1614d10ca4b576247caf45bf58779f550e46ea6764099a4`. Use `install -r` for updates; no migration or uninstall is needed. No device installation was performed in this naming session. [Validation](docs/testing.md).

The previous **Learning Corner 0.19.2+41** APK adds the saved-player Home greeting. App identity/signing key and bundled content are unchanged. SHA-256: `8e9d2942b0e173d7c47b44e334d2b4ff698cf320d9d366226094610199bd5a39`. No device installation was performed in this session. [Validation](docs/testing.md).

The previous **Learning Corner 0.20.0+42** APK adds independent parent-controlled number-game ranges and automatic settings saves. Number hunt/Number Order cap at 100; How many?/Make a group cap at 20. Original signing key and all bundled content are unchanged. SHA-256: `67367fcac685e7b1578eb39140248ed3eb1bf9dd7edc3ace9bd084c21dd07e7b`. The approved `install -r` succeeded on the verified disposable emulator; installed version and exact checksum match the distributable. Independent ranges and immediate Settings changes survived restart; Writing, 2048, 560 XP and three gifts were preserved. Original System appearance and Tap Next on were restored, and the emulator was stopped with data retained. No phone or user AVD was touched. [Validation](docs/testing.md).

The previous **Learning Corner 0.20.1+43** APK moves each range/settings shortcut inside its Numbers activity card. SHA-256: `dfaa231e622140ef2df9c4ffd9a846d3d9b23e35f3db87bd7f68a84b10a6ca58`. Same signing key and bundled assets verified; use the approved `install -r` script to preserve saves. No device installation was performed for this layout-only release. [Validation](docs/testing.md).

The current **Learning Corner 0.20.2+44** APK restores compact uniform Numbers cards, with a settings icon above the range replacing the play arrows. SHA-256: `711018b573aa33507cfb37034c3216eaffd05744504b8e4790b0da969d2812f3`. Same signing key, application identity and all bundled assets verified; use the approved `install -r` script to preserve progress. No device installation was performed for this layout release. [Validation](docs/testing.md).

## 1. Prepare the phone once

1. In **Settings → About phone**, find **Build number** and tap it seven times. On some phones it is under **Software information**. Enter the phone's PIN if asked.
2. Open **Developer options** and enable **USB debugging**.
3. Connect the unlocked phone with a USB cable that supports data.
4. Accept **Allow USB debugging?** on the phone. You can select **Always allow from this computer** for your own development computer.

Menu locations vary by manufacturer. These steps follow Android's [hardware-device setup guide](https://developer.android.com/studio/run/device) and [USB debugging documentation](https://developer.android.com/tools/adb#Enabling).

## 2. Detect the phone

Run this in a terminal on your computer:

```bash
cd /home/jvidals/Documents/ScriptWork/learning_game
export ADB_BIN="$HOME/Android/Sdk/platform-tools/adb"
"$ADB_BIN" start-server
"$ADB_BIN" devices -l
```

Expected output resembles:

```text
List of devices attached
PHONE_SERIAL    device usb:... product:... model:... device:...
```

The status must be **`device`**. If it says **`unauthorized`**, unlock the phone and accept the USB debugging prompt, then run the command again. Replace `PHONE_SERIAL` below with the first column for your phone. An entry such as `emulator-5554` is an emulator.

## 3. Install and launch the game

With exactly one device connected, use the existing project script:

```bash
./tools/install_apk.sh
```

If a phone and an emulator, or multiple phones, are connected, select your phone explicitly:

```bash
./tools/install_apk.sh PHONE_SERIAL
```

The script uses the exported `ADB_BIN`, installs `artifacts/learning-corner.apk`, and launches Learning Corner. You should see `Success` from installation and the game open on the phone.

The equivalent direct commands are:

```bash
"$ADB_BIN" -s PHONE_SERIAL install -r artifacts/learning-corner.apk
"$ADB_BIN" -s PHONE_SERIAL shell am start -n com.rainbowgarden.rainbow_garden/.MainActivity
```

`install -r` replaces the existing app while retaining its data. **Version 0.4.0 intentionally clears old flowers**, starts the companion adventure at level 1, and preserves the saved number range. The 0.17.0 upgrade preserves XP, rewards and settings while retiring Adventure moves/plays/destination scores and introducing Tap Challenge. Updates must use the same signing key; current test APKs use this computer's Android debug key. See the official [ADB installation reference](https://developer.android.com/tools/adb#move).

You can unplug the phone after installation. The game and all its audio work offline. To test that, enable airplane mode and disable Wi-Fi before opening it.

## 4. Build and install the next version

From the project root, with the phone authorized:

```bash
export FLUTTER_BIN="$HOME/snap/flutter/common/flutter/bin/flutter"
export ADB_BIN="$HOME/Android/Sdk/platform-tools/adb"
./tools/build_apk.sh
./tools/install_apk.sh PHONE_SERIAL
```

This Flutter path avoids the snap-launcher failure encountered in this environment. The build script refreshes `artifacts/learning-corner.apk` and its checksum. Building can require internet for development dependencies; installation over USB and playing the game do not.

## Optional: copy the APK to Downloads

If you want a copy on the phone to open manually:

```bash
"$ADB_BIN" -s PHONE_SERIAL push artifacts/learning-corner.apk /sdcard/Download/learning-corner.apk
```

This only copies the file. Open it in the phone's Files app to install it; Android may request permission for that file manager to install apps. The `install` commands above install directly. See the [ADB file-copy reference](https://developer.android.com/tools/adb#copyfiles).

## Troubleshooting

| Symptom | Next step |
| --- | --- |
| `adb: command not found` | Export `ADB_BIN` as above and use `"$ADB_BIN"`, or use the full executable path. |
| Empty device list | Unlock the phone, check USB debugging, reconnect, and try a known data cable and a direct USB port. If needed, select File transfer in the phone's USB notification. Run `lsusb` to see whether Linux detects the phone at all. |
| `unauthorized` | Accept the phone's USB debugging prompt. If it never appears, reconnect; if necessary, revoke USB debugging authorizations in Developer options and reconnect to authorize again. |
| `offline` | Unlock and reconnect the phone. If it persists, restart ADB with the commands below. |
| `more than one device/emulator` | Supply the phone serial to the script, or use `-s PHONE_SERIAL` with direct ADB commands. |
| `no permissions` | Your `plugdev` membership is already configured. Reconnect the phone and check its vendor ID with `lsusb`; the installed udev rules may need support for that specific device. Use ADB as your normal user. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | The installed app uses a different signing key. Rebuild with the original key to retain its data. Uninstalling would remove saved player progress and settings, so do not use that as an automatic fix. |
| `INSTALL_FAILED_VERSION_DOWNGRADE` | Use a newer build; increase the build number after `+` in `pubspec.yaml` and rebuild. |
| App cannot launch after phone reboot | Unlock the phone once so Android can open its app storage, then retry the launch command. |

To restart ADB if the connection gets stuck (this briefly disconnects all ADB sessions):

```bash
"$ADB_BIN" kill-server
"$ADB_BIN" start-server
"$ADB_BIN" devices -l
```

To use plain `adb` in the current terminal, optionally run:

```bash
export PATH="$HOME/Android/Sdk/platform-tools:$PATH"
```

The exports above apply to the current terminal. Repeat them in a new terminal, or add your preferred exports to `~/.bashrc` yourself. No shell startup files or USB rules were changed during this review.
