package com.worldradio.world_radio

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/** Receives alarm fires (starts the ringing service) and reboot/time changes (reschedules). */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.action == AlarmScheduler.ACTION_FIRE) {
            AlarmScheduler.onFired(ctx, intent.getIntExtra(AlarmScheduler.EXTRA_ALARM_ID, -1))
            val ring = Intent(ctx, AlarmService::class.java)
                .setAction(AlarmService.ACTION_START)
                .putExtra(AlarmScheduler.EXTRA_URL, intent.getStringExtra(AlarmScheduler.EXTRA_URL) ?: "")
                .putExtra(AlarmScheduler.EXTRA_NAME, intent.getStringExtra(AlarmScheduler.EXTRA_NAME) ?: "")
            ContextCompat.startForegroundService(ctx, ring)
        } else {
            AlarmScheduler.rescheduleAll(ctx)
        }
    }
}
