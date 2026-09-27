package io.wyn.wyn.core.push

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.edit
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.wyn.wyn.BuildConfig
import io.wyn.wyn.MainActivity
import io.wyn.wyn.R
import io.wyn.wyn.core.data.SupabaseProvider
import io.wyn.wyn.core.data.SupabasePushTokenRepository
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Firebase for Push, configured from local.properties / the environment
 * (the Firebase Android app registered for io.wyn.wyn). Nothing is committed;
 * a build without the values simply has Push unavailable.
 */
object FirebasePush {
    val configured: Boolean
        get() = BuildConfig.FIREBASE_APP_ID.isNotBlank() && BuildConfig.FIREBASE_API_KEY.isNotBlank() &&
            BuildConfig.FIREBASE_PROJECT_ID.isNotBlank() && BuildConfig.FIREBASE_SENDER_ID.isNotBlank()

    @Volatile private var started = false

    fun start(context: Context): Boolean {
        if (!configured) return false
        if (started) return true
        synchronized(this) {
            if (!started) {
                if (FirebaseApp.getApps(context).isEmpty()) {
                    FirebaseApp.initializeApp(
                        context,
                        FirebaseOptions.Builder()
                            .setApplicationId(BuildConfig.FIREBASE_APP_ID)
                            .setApiKey(BuildConfig.FIREBASE_API_KEY)
                            .setProjectId(BuildConfig.FIREBASE_PROJECT_ID)
                            .setGcmSenderId(BuildConfig.FIREBASE_SENDER_ID)
                            .build(),
                    )
                }
                started = true
            }
        }
        return true
    }
}

class FirebaseDeviceToken(private val context: Context) : DeviceToken {
    override val configured: Boolean get() = FirebasePush.configured

    override suspend fun token(): String? {
        if (!FirebasePush.start(context)) return null
        return suspendCancellableCoroutine { cont ->
            FirebaseMessaging.getInstance().token
                .addOnSuccessListener { cont.resume(it?.takeIf(String::isNotBlank)) }
                .addOnFailureListener { cont.resumeWithException(it) }
        }
    }

    override suspend fun delete() {
        if (!FirebasePush.start(context)) return
        suspendCancellableCoroutine { cont ->
            FirebaseMessaging.getInstance().deleteToken()
                .addOnSuccessListener { cont.resume(Unit) }
                .addOnFailureListener { cont.resumeWithException(it) }
        }
    }
}

class PreferencesPushMemory(context: Context) : PushMemory {
    private val prefs = context.getSharedPreferences("wynos_push", Context.MODE_PRIVATE)
    override var wanted: Set<String>
        get() = prefs.getStringSet("wanted", emptySet()).orEmpty().toSet()
        set(value) = prefs.edit { putStringSet("wanted", value) }
    override var off: Set<String>
        get() = prefs.getStringSet("off", emptySet()).orEmpty().toSet()
        set(value) = prefs.edit { putStringSet("off", value) }
    override var promptDismissedAt: Long?
        get() = prefs.getLong("prompt_dismissed_at", -1L).takeIf { it >= 0 }
        set(value) = prefs.edit { if (value == null) remove("prompt_dismissed_at") else putLong("prompt_dismissed_at", value) }
    override var lastToken: String?
        get() = prefs.getString("last_token", null)
        set(value) = prefs.edit { if (value == null) remove("last_token") else putString("last_token", value) }
    override var permissionAsked: Boolean
        get() = prefs.getBoolean("permission_asked", false)
        set(value) = prefs.edit { putBoolean("permission_asked", value) }
}

fun notificationsAllowed(context: Context): Boolean =
    NotificationManagerCompat.from(context).areNotificationsEnabled() &&
        (Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)

object PushSetup {
    @Volatile private var controller: PushController? = null

    fun controller(context: Context): PushController = controller ?: synchronized(this) {
        controller ?: PushController(
            SupabasePushTokenRepository(SupabaseProvider.client),
            FirebaseDeviceToken(context.applicationContext),
            PreferencesPushMemory(context.applicationContext),
            permissionGranted = { notificationsAllowed(context.applicationContext) },
        ).also { controller = it }
    }
}

/** Where a notification leads (web notifications-route open()). IDs are checked to be UUIDs. */
data class PushTarget(
    val recipientId: String?,
    val type: String?,
    val actorId: String? = null,
    val dropId: String? = null,
    val popId: String? = null,
    val clubId: String? = null,
    val clubPostId: String? = null,
    val conversationId: String? = null,
) {
    companion object {
        private val uuid = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
        private fun id(value: String?) = value?.takeIf { uuid.matches(it) }

        fun from(get: (String) -> String?): PushTarget? {
            val target = PushTarget(
                recipientId = id(get("recipient_id")),
                type = get("type")?.takeIf { it.length <= 64 && it.all { c -> c.isLetterOrDigit() || c == '_' } },
                actorId = id(get("actor_id")),
                dropId = id(get("drop_id")),
                popId = id(get("pop_id")),
                clubId = id(get("club_id")),
                clubPostId = id(get("club_post_id")),
                conversationId = id(get("conversation_id")),
            )
            return target.takeIf { it.recipientId != null && it.type != null }
        }

        fun from(extras: Bundle?): PushTarget? = extras?.let { bundle -> from { bundle.getString(it) } }
    }
}

/** Push arrivals and taps, for the open app (badge refresh, navigation). */
object PushEvents {
    private val arrivals = MutableSharedFlow<String>(extraBufferCapacity = 16)
    val received: SharedFlow<String> get() = arrivals
    fun arrived(recipientId: String) {
        arrivals.tryEmit(recipientId)
    }
}

const val PUSH_CHANNEL_ID = "wynos_default"

fun ensurePushChannel(context: Context) {
    if (Build.VERSION.SDK_INT < 26) return
    val manager = context.getSystemService(NotificationManager::class.java) ?: return
    if (manager.getNotificationChannel(PUSH_CHANNEL_ID) != null) return
    manager.createNotificationChannel(
        NotificationChannel(PUSH_CHANNEL_ID, context.getString(R.string.push_channel_name), NotificationManager.IMPORTANCE_DEFAULT),
    )
}

/**
 * Receives FCM. In the background Android shows the notification itself;
 * in the foreground it is shown here too (as the web's service worker does),
 * but only when it is for the account signed in right now.
 */
class WynosMessagingService : FirebaseMessagingService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private fun activeUserId(): String? = runCatching { SupabaseProvider.client?.auth?.currentUserOrNull()?.id }.getOrNull()

    override fun onNewToken(token: String) {
        scope.launch { PushSetup.controller(applicationContext).onNewToken(activeUserId(), token) }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val target = PushTarget.from { message.data[it] } ?: return
        if (target.recipientId != activeUserId()) return
        PushEvents.arrived(target.recipientId!!)
        val notification = message.notification ?: return
        if (!notificationsAllowed(this)) return
        ensurePushChannel(this)
        val open = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            message.data.forEach { (key, value) -> putExtra(key, value) }
        }
        val pending = PendingIntent.getActivity(this, message.data["notification_id"].hashCode(), open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val built = NotificationCompat.Builder(this, PUSH_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_wynos)
            .setContentTitle(notification.title)
            .setContentText(notification.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(notification.body))
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        try {
            NotificationManagerCompat.from(this).notify(message.data["notification_id"]?.hashCode() ?: 0, built)
        } catch (e: SecurityException) {
            // Permission withdrawn between the check and here.
        }
    }
}
