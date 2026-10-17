package com.rainbowgarden.rainbow_garden

import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Dependency-free JVM check; run with tools/test_prompt_audio.sh. */
fun main(args: Array<String>) {
    val files = File(args.single()).listFiles()!!.filter { it.extension == "wav" }
    check(files.size == 221) { "Expected every bundled recording" }
    val silenceBytes = 14400 // 300 ms * 24,000 mono samples/s * 2 bytes/sample.
    for (file in files) {
        val original = file.readBytes()
        val preserved = original.copyOf()
        val padded = PromptAudio.withLeadIn(original)
        check(original.contentEquals(preserved)) { "Modified source: $file" }
        check(padded.size == original.size + silenceBytes)
        check(padded.sliceArray(44 until 44 + silenceBytes).all { it == 0.toByte() })
        check(padded.copyOfRange(44 + silenceBytes, padded.size)
            .contentEquals(original.copyOfRange(44, original.size))) { "Changed PCM: $file" }
        val header = ByteBuffer.wrap(padded).order(ByteOrder.LITTLE_ENDIAN)
        check(header.getInt(4) == padded.size - 8 && header.getInt(40) == padded.size - 44)
        for (index in 0 until 44) {
            if (index !in 4..7 && index !in 40..43) check(padded[index] == original[index])
        }
    }
    val good = files.first().readBytes()
    var rejected = 0
    val invalid = listOf(
        byteArrayOf(), good.copyOf(43), good.copyOf(good.size - 1),
        good.copyOf().apply { this[0] = 0 },
        good.copyOf().apply { this[20] = 3 }, // Float samples cannot use this PCM16 path.
        good.copyOf().apply { this[22] = 2 }, // Stereo is not the bundled format.
        good.copyOf().apply { this[24] = 0 },
        good.copyOf().apply { this[34] = 8 },
        good.copyOf().apply { this[40] = (this[40].toInt() xor 1).toByte() },
    )
    for (wav in invalid) {
        try { PromptAudio.withLeadIn(wav) }
        catch (_: IllegalArgumentException) { rejected++; continue }
        error("Accepted malformed/unsupported recording")
    }
    println("${files.size} recordings: exact PCM preservation, 300 ms silence and valid headers passed; $rejected malformed formats rejected.")
}
