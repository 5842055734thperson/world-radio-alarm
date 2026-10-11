package com.worldradio.world_radio

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import java.util.Calendar

/**
 * Stores radio alarms (JSON written by the Flutter UI) and schedules them with
 * AlarmManager.setAlarmClock, which fires exactly even in Doze mode.
 */
object AlarmScheduler {
    private const val PREFS = "radio_alarms"
    private const val KEY_ALARMS = "alarms"
    private const val KEY_SCHEDULED = "scheduled_ids"

    const val ACTION_FIRE = "com.worldradio.world_radio.ALARM_FIRE"
    const val EXTRA_ALARM_ID = "alarmId"
    const val EXTRA_URL = "streamUrl"
    const val EXTRA_NAME = "stationName"

    const val SNOOZE_REQUEST = 900000
    const val TEST_REQUEST = 900001
    const val SNOOZE_MINUTES = 10

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun loadRaw(ctx: Context): String = prefs(ctx).getString(KEY_ALARMS, "[]") ?: "[]"

    fun save(ctx: Context, json: String) {
        prefs(ctx).edit().putString(KEY_ALARMS, json).apply()
        rescheduleAll(ctx)
    }

    /** Cancels every previously scheduled alarm and schedules the next ring of each enabled one. */
    fun rescheduleAll(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val p = prefs(ctx)
        for (id in p.getStringSet(KEY_SCHEDULED, emptySet()) ?: emptySet()) {
            am.cancel(firePendingIntent(ctx, id.toInt(), -1, "", ""))
        }
        val scheduled = mutableSetOf<String>()
        val alarms = JSONArray(loadRaw(ctx))
        for (i in 0 until alarms.length()) {
            val a = alarms.getJSONObject(i)
            if (!a.optBoolean("enabled", true)) continue
            val days = mutableSetOf<Int>()
            a.optJSONArray("days")?.let { for (d in 0 until it.length()) days.add(it.getInt(d)) }
            val at = nextTrigger(a.getInt("hour"), a.getInt("minute"), days) ?: continue
            val id = a.getInt("id")
            scheduleAt(ctx, id, at, id, a.optString("streamUrl"), a.optString("stationName"))
            scheduled.add(id.toString())
        }
        p.edit().putStringSet(KEY_SCHEDULED, scheduled).apply()
    }

    /** One-shot alarms switch themselves off after ringing; repeating ones move to their next day. */
    fun onFired(ctx: Context, alarmId: Int) {
        if (alarmId >= 0) {
            val alarms = JSONArray(loadRaw(ctx))
            for (i in 0 until alarms.length()) {
                val a = alarms.getJSONObject(i)
                val days = a.optJSONArray("days")
                if (a.getInt("id") == alarmId && (days == null || days.length() == 0)) {
                    a.put("enabled", false)
                }
            }
            prefs(ctx).edit().putString(KEY_ALARMS, alarms.toString()).apply()
        }
        rescheduleAll(ctx)
    }

    fun scheduleAt(ctx: Context, requestCode: Int, atMillis: Long, alarmId: Int, url: String, name: String) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val fire = firePendingIntent(ctx, requestCode, alarmId, url, name)
        val show = PendingIntent.getActivity(
            ctx, 0, Intent(ctx, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            am.setAlarmClock(AlarmManager.AlarmClockInfo(atMillis, show), fire)
        } catch (e: SecurityException) {
            // Exact alarms not allowed: fall back to an inexact (but Doze-safe) alarm.
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, fire)
        }
    }

    private fun firePendingIntent(ctx: Context, requestCode: Int, alarmId: Int, url: String, name: String): PendingIntent {
        val intent = Intent(ctx, AlarmReceiver::class.java)
            .setAction(ACTION_FIRE)
            .putExtra(EXTRA_ALARM_ID, alarmId)
            .putExtra(EXTRA_URL, url)
            .putExtra(EXTRA_NAME, name)
        return PendingIntent.getBroadcast(
            ctx, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** Next ring time; [days] are ISO weekdays (1 = Monday … 7 = Sunday), empty = once. */
    fun nextTrigger(hour: Int, minute: Int, days: Set<Int>, now: Long = System.currentTimeMillis()): Long? {
        val cal = Calendar.getInstance()
        for (i in 0..7) {
            cal.timeInMillis = now
            cal.add(Calendar.DAY_OF_MONTH, i)
            cal.set(Calendar.HOUR_OF_DAY, hour)
            cal.set(Calendar.MINUTE, minute)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            if (cal.timeInMillis <= now) continue
            val iso = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
            if (days.isEmpty() || iso in days) return cal.timeInMillis
        }
        return null
    }
}
