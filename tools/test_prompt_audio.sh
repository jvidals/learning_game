#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Uses the project's existing Kotlin compiler/runtime; no test library or downloads required.
(cd android && ./gradlew :app:compileReleaseUnitTestKotlin --offline)
kotlin_stdlib=$(find "${GRADLE_USER_HOME:-$HOME/.gradle}/caches/modules-2/files-2.1/org.jetbrains.kotlin/kotlin-stdlib" -name 'kotlin-stdlib-*.jar' -print -quit)
"${JAVA_HOME:-/usr/local/android-studio/jbr}/bin/java" \
  -cp "build/app/tmp/kotlin-classes/release:build/app/tmp/kotlin-classes/releaseUnitTest:$kotlin_stdlib" \
  com.rainbowgarden.rainbow_garden.PromptAudioCheckKt "$PWD/assets/audio"
