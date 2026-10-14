package online.wynos.merchant

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.google.android.gms.tasks.Tasks
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Native FCM transport. Registration is intentionally opt-in.
 * A Firebase *client* API key is NOT a Supabase service-role key.
 */
object MerchantPush {
    private const val PREF = "wynos_merchant_android_push"
    private const val CHANNEL = "merchant_orders"
    val configured: Boolean get() =
        BuildConfig.FIREBASE_APP_ID.isNotBlank() &&
        BuildConfig.FIREBASE_PROJECT_ID.isNotBlank() &&
        BuildConfig.FIREBASE_SENDER_ID.isNotBlank() &&
        BuildConfig.FIREBASE_API_KEY.isNotBlank()

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREF, Context.MODE_PRIVATE)

    fun isEnabled(context: Context): Boolean =
        configured && preferences(context).getBoolean("wanted", false)

    @Synchronized
    fun initialize(context: Context) {
        check(configured) { "ยังไม่ได้ตั้งค่า Firebase สำหรับ WYNOS Merchant Android" }
        if (FirebaseApp.getApps(context).none { it.name == FirebaseApp.DEFAULT_APP_NAME }) {
            val options = FirebaseOptions.Builder()
                .setApplicationId(BuildConfig.FIREBASE_APP_ID)
                .setProjectId(BuildConfig.FIREBASE_PROJECT_ID)
                .setGcmSenderId(BuildConfig.FIREBASE_SENDER_ID)
                .setApiKey(BuildConfig.FIREBASE_API_KEY)
                .build()
            FirebaseApp.initializeApp(context, options)
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(NotificationChannel(
            CHANNEL, "ออเดอร์ WYNOS Merchant", NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "แจ้งเตือนออเดอร์และกิจกรรมร้านค้า"
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        })
    }

    /** Must be called on an IO thread after the explicit OS permission flow. */
    fun enable(context: Context, api: MerchantApi) {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            throw IllegalStateException("กรุณาอนุญาตการแจ้งเตือนก่อนเปิด Push")
        }
        initialize(context)
        FirebaseMessaging.getInstance().isAutoInitEnabled = true
        try {
            val token = Tasks.await(FirebaseMessaging.getInstance().token)
            require(!token.isNullOrBlank()) { "ไม่สามารถขอ FCM token ได้" }
            // Never persist consent before the RLS-protected backend accepted the token.
            api.registerPushToken(token)
            preferences(context).edit().putBoolean("wanted", true)
                .putString("token", token).apply()
        } catch (failure: Exception) {
            // Failed RLS/account registration must not leave background FCM
            // enabled for a device that the current user did not activate.
            FirebaseMessaging.getInstance().isAutoInitEnabled = false
            runCatching { Tasks.await(FirebaseMessaging.getInstance().deleteToken()) }
            throw failure
        }
    }

    /** Revocation precedes logout; failures prevent a privacy-leaking account switch. */
    fun disable(context: Context, api: MerchantApi) {
        val prefs = preferences(context)
        if (!prefs.getBoolean("wanted", false)) return
        val token = prefs.getString("token", null).orEmpty()
        if (token.isNotBlank()) api.unregisterPushToken(token)
        prefs.edit().remove("token").putBoolean("wanted", false).commit()
        if (configured) {
            runCatching {
                initialize(context)
                FirebaseMessaging.getInstance().isAutoInitEnabled = false
                Tasks.await(FirebaseMessaging.getInstance().deleteToken())
            }
        }
    }

    fun handleTokenRefresh(context: Context, token: String) {
        if (!isEnabled(context) || token.isBlank()) return
        // onNewToken is dispatched by Firebase; do not do synchronous HTTP on
        // the Android main thread or log the device token.
        Thread {
            runCatching {
                val api = MerchantApi(context.applicationContext)
                if (api.hasSession) {
                    api.registerPushToken(token)
                    preferences(context).edit().putString("token", token).apply()
                }
            }
        }.start()
    }

    fun displayGenericNotification(context: Context) {
        if (!isEnabled(context) || !MerchantApi(context).hasSession) return
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        initialize(context)
        val intent = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pending = PendingIntent.getActivity(context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = Notification.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("WYNOS Merchant")
            .setContentText("มีการแจ้งเตือนใหม่สำหรับร้านค้า แตะเพื่อเปิดแอป")
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), notification)
    }
}

/** Initialize the Firebase default app for OS-created FCM services, even if the
 * Android process was started to deliver a message instead of showing an Activity.
 */
class MerchantAndroidApplication : android.app.Application() {
    override fun onCreate() {
        super.onCreate()
        if (MerchantPush.configured) runCatching { MerchantPush.initialize(this) }
    }
}

/** Data-only FCM payloads are displayed without putting customer PII on the lockscreen. */
class MerchantMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        MerchantPush.handleTokenRefresh(applicationContext, token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        MerchantPush.displayGenericNotification(applicationContext)
    }
}
