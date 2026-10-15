package online.wynos.food

import android.os.Bundle
import android.content.Intent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import online.wynos.food.ui.FoodApp
import online.wynos.food.ui.theme.WynosFoodTheme

class MainActivity : ComponentActivity() {
    private var notificationNavigationSequence by mutableIntStateOf(0)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A background Firebase Console notification opens the launcher Activity
        // rather than the app-owned foreground PendingIntent.
        handleNotificationNavigation(intent)
        // Android 15+ enforces edge-to-edge. Consume safe drawing insets once
        // so the header and sign-in button never overlap system status icons.
        enableEdgeToEdge()
        setContent {
            WynosFoodTheme {
                Box(
                    Modifier.fillMaxSize()
                        .background(Color.White)
                        .windowInsetsPadding(WindowInsets.safeDrawing)
                ) {
                    FoodApp(notificationNavigationSequence = notificationNavigationSequence)
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationNavigation(intent)
    }

    @Suppress("DEPRECATION")
    private fun handleNotificationNavigation(incoming: Intent?) {
        if (incoming == null) return
        // FCM custom data extras are String values, while app-created
        // PendingIntents carry a Boolean. Do not cast one to the other.
        val explicitTarget = incoming.extras?.get(
            ZokyNotificationTapRouting.OPEN_MESSAGES_EXTRA
        )
        if (ZokyNotificationTapRouting.shouldOpenMessages(
                explicitTarget = explicitTarget,
                hasFcmMessageId = incoming.hasExtra(ZokyNotificationTapRouting.FCM_MESSAGE_ID_EXTRA),
                debugPreviewAllowed = BuildConfig.FCM_DEVICE_PREVIEW_ALLOWED,
                optedIn = online.wynos.food.push.ZokyPushConsent.enabled(this),
            )
        ) {
            notificationNavigationSequence++
        }
    }
}
