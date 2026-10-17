package com.rainbowgarden.rainbow_garden

import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Playback-only speaker warmup. Never changes the bundled recording or its target pause. */
internal object PromptAudio {
    const val LEAD_IN_MS = 300

    fun withLeadIn(wav: ByteArray): ByteArray {
        // The bundled generator produces canonical 44-byte, mono 24 kHz PCM16 headers.
        // Reject an unexpected format rather than shifting or corrupting speech samples.
        require(wav.size >= 44) { "Truncated prompt WAV" }
        val header = ByteBuffer.wrap(wav).order(ByteOrder.LITTLE_ENDIAN)
        fun tag(offset: Int, value: String) =
            value.indices.all { wav[offset + it] == value[it].code.toByte() }
        require(tag(0, "RIFF") && tag(8, "WAVE") && tag(12, "fmt ") && tag(36, "data"))
        require(header.getInt(4) == wav.size - 8 && header.getInt(16) == 16)
        require(header.getShort(20).toInt() == 1 && header.getShort(22).toInt() == 1)
        require(header.getInt(24) == 24000 && header.getInt(28) == 48000)
        require(header.getShort(32).toInt() == 2 && header.getShort(34).toInt() == 16)
        require(header.getInt(40) == wav.size - 44 && wav.size % 2 == 0)
        val silenceBytes = 24000 * 2 * LEAD_IN_MS / 1000
        val padded = ByteArray(wav.size + silenceBytes)
        wav.copyInto(padded, 0, 0, 44)
        wav.copyInto(padded, 44 + silenceBytes, 44)
        ByteBuffer.wrap(padded).order(ByteOrder.LITTLE_ENDIAN).apply {
            putInt(4, padded.size - 8)
            putInt(40, padded.size - 44)
        }
        return padded
    }
}
