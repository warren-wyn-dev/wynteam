package online.wynos.food

/**
 * Routes Android notification taps to the existing Messages screen.
 *
 * Foreground test notifications use a Boolean extra from the app's PendingIntent.
 * Background notification messages handled by the Firebase SDK may open the
 * launcher with FCM message metadata and/or a custom data String extra.
 *
 * The metadata fallback is strictly DEBUG + user opt-in. Ordinary app launches
 * and release builds are unaffected; this never executes an order/payment action.
 */
internal object ZokyNotificationTapRouting {
    const val OPEN_MESSAGES_EXTRA = "zoky_open_messages"
    const val FCM_MESSAGE_ID_EXTRA = "google.message_id"

    fun shouldOpenMessages(
        explicitTarget: Any?,
        hasFcmMessageId: Boolean,
        debugPreviewAllowed: Boolean,
        optedIn: Boolean,
    ): Boolean {
        val explicitlyRequested = when (explicitTarget) {
            is Boolean -> explicitTarget
            is String -> explicitTarget.equals("true", ignoreCase = true)
            else -> false
        }
        return explicitlyRequested ||
            (debugPreviewAllowed && optedIn && hasFcmMessageId)
    }
}
