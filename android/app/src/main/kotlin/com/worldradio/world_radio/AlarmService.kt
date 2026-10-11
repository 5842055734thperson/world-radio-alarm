package com.worldradio.world_radio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer

/**
 * Rings an alarm: plays the radio stream with a slow fade-in and falls back to
 * the phone's own alarm tone when the stream cannot start (no internet, dead link).
 */
class AlarmService : Service() {
    companion object {
        const val ACTION_START = "com.worldradio.world_radio.ALARM_START"
        const val ACTION_STOP = "com.worldradio.world_radio.ALARM_STOP"
        const val ACTION_SNOOZE = "com.worldradio.world_radio.ALARM_SNOOZE"
        const val ACTION_CLOSED = "com.worldradio.world_radio.ALARM_CLOSED"
        private const val CHANNEL = "alarm_ring"
        private const val NOTIF_ID = 4711
        private const val STREAM_TIMEOUT_MS = 20_000L
        private const val MAX_RING_MS = 60 * 60 * 1000L

        @Volatile var isRinging = false
        @Volatile var stationName = ""
    }

    private val handler = Handler(Looper.getMainLooper())
    private var player: ExoPlayer? = null
    private var fallback: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var url = ""
    private var volume = 0.1f

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> { stopRinging(); return START_NOT_STICKY }
            ACTION_SNOOZE -> {
                AlarmScheduler.scheduleAt(
                    this, AlarmScheduler.SNOOZE_REQUEST,
                    System.currentTimeMillis() + AlarmScheduler.SNOOZE_MINUTES * 60_000L,
                    -1, url, stationName
                )
                stopRinging()
                return START_NOT_STICKY
            }
        }

        url = intent?.getStringExtra(AlarmScheduler.EXTRA_URL) ?: ""
        stationName = intent?.getStringExtra(AlarmScheduler.EXTRA_NAME) ?: ""
        startInForeground(buildNotification(stationName.ifBlank { "Alarm" }))

        releasePlayers()
        handler.removeCallbacksAndMessages(null)
        isRinging = true
        acquireWakeLock()
        try {
            startActivity(Intent(this, AlarmActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: Exception) {
            // Background activity starts may be blocked; the full-screen notification covers it.
        }
        if (url.isBlank()) playFallback() else playStream()
        handler.postDelayed({ stopRinging() }, MAX_RING_MS)
        return START_NOT_STICKY
    }

    private fun playStream() {
        val attrs = AudioAttributes.Builder()
            .setUsage(C.USAGE_ALARM)
            .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
            .build()
        val p = ExoPlayer.Builder(this).setAudioAttributes(attrs, false).build()
        p.addListener(object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) {
                handler.post { playFallback() }
            }
        })
        volume = 0.1f
        p.volume = volume
        p.setMediaItem(MediaItem.fromUri(url))
        p.prepare()
        p.playWhenReady = true
        player = p

        // Gentle fade-in over ~30 seconds.
        handler.post(object : Runnable {
            override fun run() {
                val current = player ?: return
                if (current.isPlaying) volume = (volume + 0.03f).coerceAtMost(1f)
                current.volume = volume
                if (volume < 1f) handler.postDelayed(this, 1000)
            }
        })
        // Stream did not start in time: use the alarm tone so the user still wakes up.
        handler.postDelayed({ if (player?.isPlaying != true) playFallback() }, STREAM_TIMEOUT_MS)
    }

    private fun playFallback() {
        if (fallback != null || !isRinging) return
        player?.release()
        player = null
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        try {
            fallback = MediaPlayer().apply {
                setAudioAttributes(
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(this@AlarmService, uri)
                isLooping = true
                prepare()
                start()
            }
        } catch (_: Exception) {
            fallback = null
        }
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, buildNotification("Stream unavailable · playing alarm tone"))
    }

    private fun stopRinging() {
        isRinging = false
        handler.removeCallbacksAndMessages(null)
        releasePlayers()
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        sendBroadcast(Intent(ACTION_CLOSED).setPackage(packageName))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION") stopForeground(true)
        }
        stopSelf()
    }

    private fun releasePlayers() {
        player?.release()
        player = null
        fallback?.let {
            try { it.stop() } catch (_: Exception) {}
            it.release()
        }
        fallback = null
    }

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "WorldRadio:alarm").apply {
            acquire(MAX_RING_MS + 60_000L)
        }
    }

    private fun startInForeground(n: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIF_ID, n)
        }
    }

    private fun buildNotification(text: String): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL, "Alarm", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Ringing radio alarm"
                setSound(null, null)
                setBypassDnd(true)
            }
            nm.createNotificationChannel(ch)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val screen = PendingIntent.getActivity(
            this, 1,
            Intent(this, AlarmActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            flags
        )
        val stop = PendingIntent.getService(
            this, 2, Intent(this, AlarmService::class.java).setAction(ACTION_STOP), flags
        )
        val snooze = PendingIntent.getService(
            this, 3, Intent(this, AlarmService::class.java).setAction(ACTION_SNOOZE), flags
        )
        return NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Good morning ⏰")
            .setContentText(text)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setContentIntent(screen)
            .setFullScreenIntent(screen, true)
            .addAction(0, "Snooze (${AlarmScheduler.SNOOZE_MINUTES} min)", snooze)
            .addAction(0, "Stop", stop)
            .build()
    }

    override fun onDestroy() {
        isRinging = false
        handler.removeCallbacksAndMessages(null)
        releasePlayers()
        wakeLock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }
}
