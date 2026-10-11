package com.worldradio.world_radio

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Full-screen wake-up screen (works over the lock screen) with Snooze / Stop buttons. */
class AlarmActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var clock: TextView

    private val closeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) = finish()
    }

    private val tick = object : Runnable {
        override fun run() {
            clock.text = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
            handler.postDelayed(this, 10_000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val dp = resources.displayMetrics.density
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.BLACK)
            setPadding((32 * dp).toInt(), 0, (32 * dp).toInt(), 0)
        }
        clock = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 96f
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            gravity = Gravity.CENTER
        }
        val station = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 20f
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            letterSpacing = 0.1f
            gravity = Gravity.CENTER
            text = AlarmService.stationName.ifBlank { "Alarm" }.uppercase(Locale.ROOT)
            setPadding(0, (8 * dp).toInt(), 0, (56 * dp).toInt())
        }
        // Brutalist square buttons: filled white, or black with a white 2dp border.
        fun button(label: String, filled: Boolean, action: String) = Button(this).apply {
            text = label
            textSize = 18f
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            letterSpacing = 0.1f
            isAllCaps = true
            stateListAnimator = null
            setTextColor(if (filled) Color.BLACK else Color.WHITE)
            background = GradientDrawable().apply {
                setColor(if (filled) Color.WHITE else Color.BLACK)
                setStroke((2 * dp).toInt(), Color.WHITE)
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, (64 * dp).toInt()
            ).apply { topMargin = (16 * dp).toInt() }
            setOnClickListener {
                startService(Intent(this@AlarmActivity, AlarmService::class.java).setAction(action))
                finish()
            }
        }
        root.addView(clock)
        root.addView(station)
        root.addView(button("Snooze · ${AlarmScheduler.SNOOZE_MINUTES} min", false, AlarmService.ACTION_SNOOZE))
        root.addView(button("Stop", true, AlarmService.ACTION_STOP))
        setContentView(root)

        ContextCompat.registerReceiver(
            this, closeReceiver, IntentFilter(AlarmService.ACTION_CLOSED),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
    }

    override fun onResume() {
        super.onResume()
        if (!AlarmService.isRinging) finish()
        handler.post(tick)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(tick)
    }

    override fun onDestroy() {
        unregisterReceiver(closeReceiver)
        super.onDestroy()
    }
}
