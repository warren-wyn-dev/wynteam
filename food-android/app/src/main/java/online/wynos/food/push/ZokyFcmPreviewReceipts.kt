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
    private const val KEY_DISPLAY = "last_notification_post"

    enum class DisplayResult {
        PERMISSION_DENIED,
        APP_NOTIFICATIONS_DISABLED,
        CHANNEL_DISABLED,
        POST_REQUESTED,
        POST_FAILED,
    }

    /**
     * A result of Android's local notification posting call, not proof that
     * the system displayed it, and not a record of background SDK delivery.
     */
    fun displayStatus(context: Context): String {
        if (!BuildConfig.FCM_DEVICE_PREVIEW_ALLOWED || !ZokyPushConsent.enabled(context)) {
            return "ไม่ได้เปิดการทดสอบ"
        }
        val name = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_DISPLAY, null)
        return when (name) {
            DisplayResult.PERMISSION_DENIED.name ->
                "Android ยังไม่อนุญาตให้แสดงแจ้งเตือน"
            DisplayResult.APP_NOTIFICATIONS_DISABLED.name ->
                "Android ปิดการแจ้งเตือนของ Zoky"
            DisplayResult.CHANNEL_DISABLED.name ->
                "Android ปิดหมวดแจ้งเตือนทดสอบ"
            DisplayResult.POST_REQUESTED.name ->
                "สั่งให้ Android แสดงแล้ว (ยังไม่ยืนยันว่าปรากฏ)"
            DisplayResult.POST_FAILED.name ->
                "Android ปฏิเสธคำสั่งแสดงแจ้งเตือน"
            else -> "ยังไม่มีผลการแสดงแจ้งเตือนจากตัวรับ FCM"
        }
    }

    fun recordDisplay(context: Context, result: DisplayResult) {
        if (!BuildConfig.FCM_DEVICE_PREVIEW_ALLOWED || !ZokyPushConsent.enabled(context)) return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_DISPLAY, result.name).apply()
    }

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
            .edit().remove(KEY_COUNT).remove(KEY_DISPLAY).apply()
    }
}
