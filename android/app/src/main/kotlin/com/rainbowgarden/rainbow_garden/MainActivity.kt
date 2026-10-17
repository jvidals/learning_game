package com.rainbowgarden.rainbow_garden

import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.HapticFeedbackConstants
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.MediaDataSource
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import org.json.JSONObject
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    companion object {
        // A failed SharedPreferences commit can still change its in-memory map.
        // Keep the exact migration until it is durable, including across activity recreation.
        private var pendingProfileMigration: String? = null
    }
    private var player: MediaPlayer? = null
    private var pendingAudio: MethodChannel.Result? = null
    private val storageWorker = Executors.newSingleThreadExecutor()
    private val feedbackHandler = Handler(Looper.getMainLooper())
    private var finishingFeedback: Runnable? = null

    private fun stopFeedback() {
        finishingFeedback?.let { feedbackHandler.removeCallbacks(it) }
        finishingFeedback = null
    }

    private fun playFeedback(kind: String?) {
        stopFeedback()
        if (!hasWindowFocus()) return
        val light = if (Build.VERSION.SDK_INT >= 27) HapticFeedbackConstants.CLOCK_TICK
            else HapticFeedbackConstants.KEYBOARD_TAP
        val cue = when (kind) {
            "confirm", "placement" -> if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.CONFIRM
                else HapticFeedbackConstants.VIRTUAL_KEY
            "retry" -> if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.REJECT
                else HapticFeedbackConstants.VIRTUAL_KEY
            else -> light
        }
        val played = window.decorView.performHapticFeedback(cue)
        if (played && kind == "placement") {
            // A soft tail extends only successful card placements. Each pulse
            // uses system-controlled touch feedback, without VIBRATE permission.
            val finish = Runnable {
                finishingFeedback = null
                if (hasWindowFocus()) {
                    try { window.decorView.performHapticFeedback(light) }
                    catch (_: Exception) { /* Optional feedback. */ }
                }
            }
            finishingFeedback = finish
            feedbackHandler.postDelayed(finish, 80L)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val preferences = getSharedPreferences("garden", MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rainbow_garden/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "loadProfiles" -> storageWorker.execute {
                        try {
                            // The new key is authoritative even when its content is malformed.
                            if (!preferences.contains("profiles") || pendingProfileMigration != null) {
                                val initial = JSONObject(pendingProfileMigration ?: call.arguments as String)
                                if (pendingProfileMigration == null) {
                                    val first = initial.getJSONArray("players").getJSONObject(0)
                                    val min = preferences.all["numberMin"] as? Int
                                    val max = preferences.all["numberMax"] as? Int
                                    val valid = min != null && max != null && min >= 0 && max <= 100 && max - min >= 2
                                    val settings = JSONObject()
                                        .put("min", if (valid) min else 0)
                                        .put("max", if (valid) max else 10)
                                        .put("tapNext", preferences.all["tapNext"] as? Boolean ?: true)
                                        .put("haptics", preferences.all["haptics"] as? Boolean ?: true)
                                        .put("orderingLowercase", preferences.all["orderingLowercase"] as? Boolean ?: false)
                                        .put("soundOn", preferences.all["soundOn"] as? Boolean ?: true)
                                    val packs = if (!preferences.contains("enabledSightWordPacks")) listOf("pack1")
                                        else (preferences.all["enabledSightWordPacks"] as? Set<*>)?.toList() ?: emptyList<Any>()
                                    settings.put("enabledSightWordPacks", JSONArray(packs))
                                    first.put("settings", settings)
                                    if (preferences.contains("adventure")) {
                                        // Preserve even malformed adventure text for profile-scoped recovery.
                                        first.put("progress", preferences.all["adventure"] as? String
                                            ?: throw IllegalStateException("Invalid legacy adventure type"))
                                    }
                                }
                                pendingProfileMigration = initial.toString()
                                val editor = preferences.edit().putString("profiles", pendingProfileMigration)
                                for (key in listOf("adventure", "flowers", "numberMin", "numberMax", "relaxed",
                                    "tapNext", "haptics", "orderingLowercase", "soundOn", "enabledSightWordPacks")) {
                                    editor.remove(key)
                                }
                                if (!editor.commit()) throw IllegalStateException("Migration failed")
                                pendingProfileMigration = null
                            }
                            val document = preferences.all["profiles"] as? String
                                ?: throw IllegalStateException("Invalid profiles document")
                            runOnUiThread { result.success(document) }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("load_failed", "Could not open players", null) }
                        }
                    }
                    "saveProfiles" -> {
                        val document = call.arguments as? String
                        if (document == null) result.error("invalid_profiles", "Expected profiles document", null)
                        else storageWorker.execute {
                            val saved = try {
                                val committed = preferences.edit().putString("profiles", document).commit()
                                if (committed) pendingProfileMigration = null
                                committed
                            } catch (_: Exception) { false }
                            runOnUiThread {
                                if (saved) result.success(null)
                                else result.error("save_failed", "Could not save players", null)
                            }
                        }
                    }
                    "feedback" -> {
                        try {
                            playFeedback(call.arguments as? String)
                        } catch (_: Exception) { /* Optional feedback never interrupts play. */ }
                        result.success(null)
                    }
                    "play" -> {
                        val clip = call.arguments as? String
                        if (clip == null || !clip.matches(Regex("[a-z0-9_]+"))) {
                            result.error("invalid_clip", "Unknown audio clip", null)
                        } else {
                            stopAudio()
                            pendingAudio = result
                            try {
                                val key = FlutterInjector.instance().flutterLoader()
                                    .getLookupKeyForAsset("assets/audio/$clip.wav")
                                val next = MediaPlayer()
                                player = next
                                next.setAudioAttributes(AudioAttributes.Builder()
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                    .setUsage(AudioAttributes.USAGE_GAME).build())
                                // Silence must travel through the same output stream as speech:
                                // delaying start() alone leaves the speaker pipeline cold.
                                val audio = assets.open(key).use { PromptAudio.withLeadIn(it.readBytes()) }
                                next.setDataSource(object : MediaDataSource() {
                                    override fun getSize(): Long = audio.size.toLong()
                                    override fun readAt(position: Long, buffer: ByteArray,
                                                        offset: Int, size: Int): Int {
                                        if (size == 0) return 0
                                        if (position < 0 || position >= audio.size) return -1
                                        val count = minOf(size, audio.size - position.toInt())
                                        audio.copyInto(buffer, offset, position.toInt(), position.toInt() + count)
                                        return count
                                    }
                                    override fun close() { /* Immutable memory; released with the player. */ }
                                })
                                // Small bundled clips; preparation is async to keep taps responsive.
                                next.setOnPreparedListener {
                                    if (player === it) {
                                        it.start()
                                        pendingAudio?.success(null)
                                        pendingAudio = null
                                    }
                                }
                                next.setOnCompletionListener { if (player === it) stopAudio() }
                                next.setOnErrorListener { failed, _, _ ->
                                    if (player === failed) {
                                        pendingAudio?.error("audio_failed", "Could not prepare bundled audio", null)
                                        pendingAudio = null
                                        stopAudio()
                                    }
                                    true
                                }
                                next.prepareAsync()
                            } catch (error: Exception) {
                                pendingAudio?.error("audio_failed", "Could not play bundled audio", null)
                                pendingAudio = null
                                stopAudio()
                            }
                        }
                    }
                    "stop" -> { stopFeedback(); stopAudio(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }

    private fun stopAudio() {
        // Replay/back may cancel a clip while it is preparing. This is normal.
        pendingAudio?.success(null)
        pendingAudio = null
        player?.release()
        player = null
    }

    override fun onPause() {
        stopFeedback()
        stopAudio()
        super.onPause()
    }

    override fun onDestroy() {
        stopFeedback()
        stopAudio()
        storageWorker.shutdown()
        super.onDestroy()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus) stopFeedback()
    }
}
