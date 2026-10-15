package online.wynos.food.push

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import online.wynos.food.BuildConfig

/**
 * Creates the debug test notification channel immediately after explicit consent.
 *
 * Firebase's SDK posts notification payloads directly while the app is
 * backgrounded, so onMessageReceived() cannot be relied on to create it.
 * This is a device-only test channel; Android retains user-managed preferences.
 */
internal object ZokyFcmPreviewNotificationChannel {
    const val ID = "zoky_device_preview"

    fun ensure(context: Context) {
        if (!BuildConfig.FCM_DEVICE_PREVIEW_ALLOWED || !ZokyPushConsent.enabled(context)) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(
                    ID,
                    "Zoky · ทดสอบการแจ้งเตือน",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply {
                    description = "FCM device preview only; no account-linked push service"
                }
            )
        }
    }

    /**
     * Local-only troubleshooting information. No token or message identifiers.
     * This reflects settings, not confirmation of Firebase cloud delivery.
     */
    fun status(context: Context): String {
        if (!BuildConfig.FCM_DEVICE_PREVIEW_ALLOWED ||
            !ZokyPushConsent.enabled(context)
        ) return "ยังไม่ได้เปิดการทดสอบ FCM"

        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) return "Android ยังไม่อนุญาตสิทธิ์การแจ้งเตือน"

        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            return "Android ปิดการแจ้งเตือนทั้งหมดของ Zoky"
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
            val channel = manager.getNotificationChannel(ID)
                ?: return "ยังไม่พบหมวดแจ้งเตือนทดสอบบนเครื่อง"
            if (channel.importance == NotificationManager.IMPORTANCE_NONE) {
                return "Android ปิดหมวดแจ้งเตือนทดสอบของ Zoky"
            }
            return "หมวดแจ้งเตือนทดสอบพร้อมใช้งาน (ระดับ ${channel.importance})"
        }

        return "อนุญาตการแจ้งเตือนแล้ว"
    }
}
