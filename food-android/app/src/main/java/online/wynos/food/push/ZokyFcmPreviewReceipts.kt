package online.wynos.food.push

import android.content.Context
import online.wynos.food.BuildConfig

/**
 * Local, device-only DEBUG FCM troubleshooting counter.
 *
 * Records only how often FirebaseMessagingService.onMessageReceived ran.
 * Never stores payloads, FCM tokens, sender IDs, account IDs or message content.
 * Firebase Console notification messages in the background may bypass the
 * callback and appear directly in the Android notification shade instead.
 */
internal object ZokyFcmPreviewReceipts {
    private const val PREFS = "zoky_fcm_preview_receipts"
    private const val KEY_COUNT = "callback_count"

    fun count(context: Context): Int =
        if (BuildConfig.FCM_DEVICE_PREVIEW_ALLOWED)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getInt(KEY_COUNT, 0)
        else 0

    fun record(context: Context) {
        if (!BuildConfig.FCM_DEVICE_PREVIEW_ALLOWED || !ZokyPushConsent.enabled(context)) return
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        // Saturate to avoid wrapping into a negative value after repeated QA.
        val current = preferences.getInt(KEY_COUNT, 0)
        preferences.edit().putInt(KEY_COUNT, if (current == Int.MAX_VALUE) current else current + 1).apply()
    }

    fun clear(context: Context) {
        if (!BuildConfig.FCM_DEVICE_PREVIEW_ALLOWED) return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().remove(KEY_COUNT).apply()
    }
}
