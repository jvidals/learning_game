package com.rainbowgarden.rainbow_garden

import android.content.ContentValues
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.hardware.display.DisplayManager
import android.os.Environment
import android.provider.MediaStore
import android.util.AtomicFile
import java.io.File
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.HapticFeedbackConstants
import android.view.WindowManager
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
        private const val SHORTCUT_EXTRA = "learning_corner.shortcut"
        // A failed SharedPreferences commit can still change its in-memory map.
        // Keep the exact migration until it is durable, including across activity recreation.
        private var pendingProfileMigration: String? = null
    }
    private var player: MediaPlayer? = null
    private var pendingAudio: MethodChannel.Result? = null
    private val storageWorker = Executors.newSingleThreadExecutor()
    private val feedbackHandler = Handler(Looper.getMainLooper())
    private var finishingFeedback: Runnable? = null
    private var deviceChannel: MethodChannel? = null
    private var pendingShortcut: String? = null
    private var sketchDisplayListener: DisplayManager.DisplayListener? = null
    private var previousRotationAnimation: Int? = null
    private var lastSentRotation = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        // A restored activity must not reopen the shortcut that originally launched it.
        if (savedInstanceState == null) pendingShortcut = validatedShortcut(intent)
        super.onCreate(savedInstanceState)
        pendingShortcut?.let { reportShortcutUsed(it) }
        publishShortcuts()
    }

    private fun validatedShortcut(intent: Intent): String? {
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        return try {
            // Any app can start this exported activity, so accept only the two shortcut ids.
            val id = intent.getStringExtra(SHORTCUT_EXTRA)
            if (id == "sketchPad" || id == "game2048") id else null
        } catch (_: Exception) {
            null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val id = validatedShortcut(intent) ?: return
        pendingShortcut = id
        reportShortcutUsed(id)
        deviceChannel?.invokeMethod("shortcutRequested", null)
    }

    private fun reportShortcutUsed(id: String) {
        if (Build.VERSION.SDK_INT < 25) return
        try {
            getSystemService(ShortcutManager::class.java)?.reportShortcutUsed(id)
        } catch (_: Exception) { /* Launcher integration is best effort. */ }
    }

    private fun publishShortcuts() {
        if (Build.VERSION.SDK_INT < 25) return
        try {
            fun shortcut(id: String, label: String, longLabel: String, icon: Int, rank: Int) =
                ShortcutInfo.Builder(this, id)
                    .setShortLabel(label)
                    .setLongLabel(longLabel)
                    .setIcon(Icon.createWithResource(this, icon))
                    .setRank(rank)
                    .setIntent(Intent(Intent.ACTION_VIEW).setClass(this, MainActivity::class.java)
                        .putExtra(SHORTCUT_EXTRA, id)
                        .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP))
                    .build()
            getSystemService(ShortcutManager::class.java)?.setDynamicShortcuts(listOf(
                shortcut("sketchPad", "Sketch Pad", "Open Sketch Pad", R.drawable.ic_shortcut_sketch, 0),
                shortcut("game2048", "2048", "Play 2048", R.drawable.ic_shortcut_2048, 1)
            ))
        } catch (_: Exception) { /* Launcher integration is best effort. */ }
    }

    private fun displayRotation(): Int {
        return if (Build.VERSION.SDK_INT >= 30) display?.rotation ?: 0
        else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.rotation
        }
    }

    private fun setSketchWindow(active: Boolean) {
        val manager = getSystemService(DISPLAY_SERVICE) as DisplayManager
        if (active) {
            if (sketchDisplayListener != null) return
            lastSentRotation = displayRotation()
            val listener = object : DisplayManager.DisplayListener {
                override fun onDisplayAdded(displayId: Int) {}
                override fun onDisplayRemoved(displayId: Int) {}
                override fun onDisplayChanged(displayId: Int) {
                    if (sketchDisplayListener !== this) return
                    val rotation = displayRotation()
                    if (rotation != lastSentRotation) {
                        lastSentRotation = rotation
                        deviceChannel?.invokeMethod("displayRotationChanged", rotation)
                    }
                }
            }
            manager.registerDisplayListener(listener, feedbackHandler)
            sketchDisplayListener = listener
            val attributes = window.attributes
            previousRotationAnimation = attributes.rotationAnimation
            attributes.rotationAnimation = WindowManager.LayoutParams.ROTATION_ANIMATION_CROSSFADE
            window.attributes = attributes
        } else {
            sketchDisplayListener?.let { manager.unregisterDisplayListener(it) }
            sketchDisplayListener = null
            previousRotationAnimation?.let {
                val attributes = window.attributes
                attributes.rotationAnimation = it
                window.attributes = attributes
            }
            previousRotationAnimation = null
        }
    }

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
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rainbow_garden/device")
        deviceChannel = channel
        channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeShortcut" -> {
                        result.success(pendingShortcut)
                        pendingShortcut = null
                    }
                    "displayRotation" -> result.success(displayRotation())
                    "setSketchWindow" -> {
                        val active = call.arguments as? Boolean
                        if (active == null) {
                            result.error("invalid_sketch_window", "Expected active boolean", null)
                        } else {
                            try {
                                setSketchWindow(active)
                                result.success(null)
                            } catch (_: Exception) {
                                result.error("sketch_window_failed", "Could not update Sketch window", null)
                            }
                        }
                    }
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
                    "loadSketch", "saveSketch", "deleteSketch" -> {
                        val id = call.argument<Any>("playerId") as? String
                        if (id == null || !id.matches(Regex("^[A-Za-z0-9_-]{1,100}$"))) {
                            result.error("invalid_player", "Invalid sketch player ID", null)
                        } else storageWorker.execute {
                            try {
                                val directory = File(filesDir, "sketch")
                                if (!directory.isDirectory && !directory.mkdirs()) {
                                    throw IllegalStateException("Could not create sketch directory")
                                }
                                val pngFile = AtomicFile(File(directory, "$id.png"))
                                val settingsFile = AtomicFile(File(directory, "$id.json"))
                                when (call.method) {
                                    "loadSketch" -> {
                                        val snapshot = hashMapOf<String, Any?>(
                                            "png" to readSketchFile(pngFile),
                                            "settings" to readSketchFile(settingsFile)?.let {
                                                String(it, Charsets.UTF_8)
                                            }
                                        )
                                        runOnUiThread { result.success(snapshot) }
                                    }
                                    "saveSketch" -> {
                                        val png = call.argument<ByteArray>("png")
                                            ?: throw IllegalArgumentException("Expected sketch PNG")
                                        val settings = call.argument<String>("settings")
                                            ?: throw IllegalArgumentException("Expected sketch settings")
                                        if (png.size > 25 * 1024 * 1024) {
                                            throw IllegalArgumentException("Sketch PNG is too large")
                                        }
                                        writeSketchFile(pngFile, png)
                                        writeSketchFile(settingsFile, settings.toByteArray(Charsets.UTF_8))
                                        runOnUiThread { result.success(null) }
                                    }
                                    "deleteSketch" -> {
                                        pngFile.delete()
                                        settingsFile.delete()
                                        runOnUiThread { result.success(null) }
                                    }
                                }
                            } catch (_: Exception) {
                                runOnUiThread { result.error("sketch_failed", "Could not access sketch", null) }
                            }
                        }
                    }
                    "canSaveToGallery" -> result.success(Build.VERSION.SDK_INT >= 29)
                    "saveToGallery" -> {
                        if (Build.VERSION.SDK_INT < 29) {
                            result.error("unsupported", "Gallery export requires Android 10", null)
                        } else storageWorker.execute {
                            var inserted: android.net.Uri? = null
                            try {
                                val png = call.argument<ByteArray>("png")
                                    ?: throw IllegalArgumentException("Expected sketch PNG")
                                if (png.size > 25 * 1024 * 1024) {
                                    throw IllegalArgumentException("Sketch PNG is too large")
                                }
                                // Restored URIs may be missing or no longer writable by this install.
                                // Never delete the previous photo when replacement fails.
                                try {
                                    val replaceUri = call.argument<String>("replaceUri")
                                    if (replaceUri != null) {
                                        val uri = android.net.Uri.parse(replaceUri)
                                        if (uri.scheme == "content" && uri.authority == "media") {
                                            val exists = contentResolver.query(uri,
                                                arrayOf(MediaStore.Images.Media._ID), null, null, null
                                            )?.use { it.count == 1 && it.moveToFirst() } ?: false
                                            if (exists) {
                                                val output = contentResolver.openOutputStream(uri, "wt")
                                                    ?: throw IllegalStateException("Could not open gallery image")
                                                output.use { it.write(png) }
                                                try {
                                                    contentResolver.update(uri, ContentValues().apply {
                                                        put(MediaStore.Images.Media.DATE_MODIFIED,
                                                            System.currentTimeMillis() / 1000)
                                                    }, null, null)
                                                } catch (_: Exception) { /* Timestamp is best-effort. */ }
                                                runOnUiThread { result.success(uri.toString()) }
                                                return@execute
                                            }
                                        }
                                    }
                                } catch (_: Exception) { /* Fall back to a new photo. */ }
                                val requestedName = call.argument<String>("name") ?: "Sketch.png"
                                var name = requestedName.replace(Regex("[^A-Za-z0-9 ._-]"), "_")
                                    .take(80).trim()
                                if (!name.endsWith(".png", ignoreCase = true)) {
                                    name = name.take(76) + ".png"
                                }
                                if (name == ".png") name = "Sketch.png"
                                val values = ContentValues().apply {
                                    put(MediaStore.Images.Media.DISPLAY_NAME, name)
                                    put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                                    put(MediaStore.Images.Media.RELATIVE_PATH,
                                        Environment.DIRECTORY_PICTURES + "/Learning Corner")
                                    put(MediaStore.Images.Media.IS_PENDING, 1)
                                }
                                val uri = contentResolver.insert(
                                    MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                                    values
                                ) ?: throw IllegalStateException("Could not create gallery image")
                                inserted = uri
                                val output = contentResolver.openOutputStream(uri)
                                    ?: throw IllegalStateException("Could not open gallery image")
                                output.use { it.write(png) }
                                val published = contentResolver.update(uri, ContentValues().apply {
                                    put(MediaStore.Images.Media.IS_PENDING, 0)
                                }, null, null)
                                if (published == 0) throw IllegalStateException("Could not publish gallery image")
                                runOnUiThread { result.success(uri.toString()) }
                            } catch (_: Exception) {
                                inserted?.let { uri ->
                                    try { contentResolver.delete(uri, null, null) }
                                    catch (_: Exception) { /* Preserve the original export failure. */ }
                                }
                                runOnUiThread { result.error("sketch_failed", "Could not save to Gallery", null) }
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

    private fun readSketchFile(file: AtomicFile): ByteArray? {
        // Older AtomicFile implementations may retain only the backup after a
        // crash. Let readFully restore it instead of treating the page as empty.
        if (!file.baseFile.exists() && !File(file.baseFile.path + ".bak").exists()) return null
        return file.readFully()
    }

    private fun writeSketchFile(file: AtomicFile, bytes: ByteArray) {
        val output = file.startWrite()
        try {
            output.write(bytes)
            file.finishWrite(output)
        } catch (error: Exception) {
            file.failWrite(output)
            throw error
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
        setSketchWindow(false)
        deviceChannel = null
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
