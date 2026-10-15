package online.wynos.food.push

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import online.wynos.food.BuildConfig
import online.wynos.food.MainActivity
import online.wynos.food.R

/**
 * Device-only notification diagnostic for the explicitly opted-in DEBUG build.
 * Posts a local OS notification without using Firebase, any backend or personal data.
 * It cannot be triggered from a release APK.
 */
internal object ZokyLocalNotificationQa {
    private const val CHANNEL_ID = "zoky_device_preview"

    @SuppressLint("MissingPermission")
    fun post(context: Context): String {
        if (!BuildConfig.FCM_DEVICE_PREVIEW_ALLOWED || !ZokyPushConsent.enabled(context)) {
            return "ต้องเปิดการทดสอบ Firebase บนอุปกรณ์ก่อน"
        }
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return "Android ยังไม่อนุญาตการแจ้งเตือนของ Zoky"
        }
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            return "Android ปิดการแจ้งเตือนของ Zoky อยู่ โปรดเปิดใน Settings"
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Zoky · ทดสอบการแจ้งเตือน",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "FCM device preview only; no account-linked push service"
                }
            )
            if (manager.getNotificationChannel(CHANNEL_ID)?.importance ==
                NotificationManager.IMPORTANCE_NONE
            ) {
                return "หมวดแจ้งเตือนทดสอบของ Zoky ถูกปิดอยู่ใน Settings"
            }
        }

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("zoky_open_messages", true)
        }
        val pending = PendingIntent.getActivity(
            context, 701, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_zoky_notification)
            .setContentTitle("Zoky · ทดสอบในเครื่อง")
            .setContentText("แจ้งเตือนนี้สร้างบน Android โดยตรง ไม่ได้ส่งผ่าน Firebase")
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()

        return try {
            NotificationManagerCompat.from(context).notify(77001, notification)
            // notify() has no delivery acknowledgement; never claim it was displayed.
            "สั่งแสดงแจ้งเตือนในเครื่องแล้ว กรุณาปัดแถบแจ้งเตือน Android ลงมาตรวจสอบ"
        } catch (_: SecurityException) {
            "Android ปฏิเสธการแจ้งเตือน โปรดตรวจสอบสิทธิ์ของ Zoky"
        } catch (_: RuntimeException) {
            "Android ไม่สามารถสร้างการแจ้งเตือนทดสอบได้"
        }
    }
}
