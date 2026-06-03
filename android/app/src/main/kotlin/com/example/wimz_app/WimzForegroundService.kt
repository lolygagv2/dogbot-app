package com.wimzai.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps the WIM-Z process alive while a live session (drive / two-way audio /
 * WebRTC) is active and the app is backgrounded.
 *
 * Android — especially Samsung/Xiaomi/OnePlus battery optimizers — aggressively
 * kills backgrounded apps, which tears down the WebSocket/WebRTC link and audio
 * threads. iOS handled this with background modes; this foreground service is
 * the Android equivalent. It uses the DATA_SYNC service type: the goal is purely
 * to keep the process resident (the app is continuously exchanging control/video
 * data with the robot), and DATA_SYNC needs no runtime-permission match, so
 * starting it can't throw a SecurityException the way microphone/camera types
 * can if that permission was denied.
 */
class WimzForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "wimz_session"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.wimzai.app.START_SESSION"
        const val ACTION_STOP = "com.wimzai.app.STOP_SESSION"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }
        startAsForeground()
        // Don't auto-restart if the OS kills us — the app re-starts the service
        // when it next has an active session.
        return START_NOT_STICKY
    }

    private fun startAsForeground() {
        createChannel()
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        // Tapping the notification brings the app back to the foreground.
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val contentIntent =
            PendingIntent.getActivity(this, 0, launchIntent, pendingFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("WIM-Z session active")
            .setContentText("Keeping the live link to your robot")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "WIM-Z live session",
                    NotificationManager.IMPORTANCE_LOW
                )
                channel.description =
                    "Keeps the robot link alive while the app is in the background"
                nm.createNotificationChannel(channel)
            }
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }
}
