package online.wynos.food.push

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import online.wynos.food.BuildConfig
import online.wynos.food.MainActivity
import online.wynos.food.R

/**
 * FCM device-only QA receiver. Does not send tokens, accounts or message contents to
 * any WYNOS/Supabase endpoint. Full service delivery needs a separate secure backend.
 */
class ZokyFirebaseMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Deliberately do not log/store/upload this device identifier.
        // A future buyer-scoped registration API must be reviewed before enabling.
    }

    @SuppressLint("MissingPermission")
    override fun onMessageReceived(message: RemoteMessage) {
        if (!BuildConfig.FCM_DEVICE_PREVIEW_ALLOWED || !ZokyPushConsent.enabled(this)) return
        // Proof of receipt from FCM, recorded locally without message content or token.
        // This callback is used by foreground notification messages; background
        // console notifications can be posted directly by the Firebase SDK.
        ZokyFcmPreviewReceipts.record(this)
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(
                this, Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) return

        // Device-only test notifications: never show unverified order/payment
        // statements or personal data from a push payload.
        ZokyFcmPreviewNotificationChannel.ensure(this)
        val channelId = ZokyFcmPreviewNotificationChannel.ID
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("zoky_open_messages", true)
        }
        val pending = PendingIntent.getActivity(
            this, 700, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_zoky_notification)
            .setContentTitle("Zoky")
            .setContentText("ได้รับข้อความทดสอบจาก Firebase")
            .setStyle(NotificationCompat.BigTextStyle().bigText(
                "ได้รับข้อความทดสอบจาก Firebase · ยังไม่ได้เชื่อมการแจ้งเตือนออเดอร์จริง"
            ))
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        NotificationManagerCompat.from(this)
            .notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), notification)
    }
}

object ZokyPushConsent {
    private const val PREFS = "zoky_fcm_device_preview"
    private const val KEY = "opted_in"

    fun enabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY, false)

    fun setEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean(KEY, enabled).apply()
    }
}
