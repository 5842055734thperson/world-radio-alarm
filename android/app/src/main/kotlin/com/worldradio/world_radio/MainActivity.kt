package com.worldradio.world_radio

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "world_radio/alarms")
            .setMethodCallHandler { call, result ->
                val ctx = applicationContext
                try {
                    when (call.method) {
                        "getAlarms" -> result.success(AlarmScheduler.loadRaw(ctx))
                        "saveAlarms" -> {
                            AlarmScheduler.save(ctx, call.arguments as String)
                            result.success(null)
                        }
                        "testAlarm" -> {
                            val a = JSONObject(call.arguments as String)
                            AlarmScheduler.scheduleAt(
                                ctx, AlarmScheduler.TEST_REQUEST,
                                System.currentTimeMillis() + 5_000, -1,
                                a.optString("streamUrl"), a.optString("stationName")
                            )
                            result.success(null)
                        }
                        "canScheduleExact" -> {
                            val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                            result.success(
                                Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
                            )
                        }
                        "notificationsAllowed" -> {
                            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            val granted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                                PackageManager.PERMISSION_GRANTED
                            result.success(granted && nm.areNotificationsEnabled())
                        }
                        "requestNotifications" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
                            }
                            result.success(null)
                        }
                        "canFullScreen" -> {
                            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            result.success(
                                Build.VERSION.SDK_INT < 34 || nm.canUseFullScreenIntent()
                            )
                        }
                        "isIgnoringBattery" -> {
                            val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
                            result.success(pm.isIgnoringBatteryOptimizations(packageName))
                        }
                        "requestIgnoreBattery" -> {
                            startActivity(
                                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                    .setData(Uri.parse("package:$packageName"))
                            )
                            result.success(null)
                        }
                        "openExactAlarmSettings" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                startActivity(
                                    Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                                        .setData(Uri.parse("package:$packageName"))
                                )
                            }
                            result.success(null)
                        }
                        "openFullScreenSettings" -> {
                            if (Build.VERSION.SDK_INT >= 34) {
                                startActivity(
                                    Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
                                        .setData(Uri.parse("package:$packageName"))
                                )
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("alarm_error", e.message, null)
                }
            }
    }
}
