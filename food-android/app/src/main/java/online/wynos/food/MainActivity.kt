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
        if (intent?.getBooleanExtra("zoky_open_messages", false) == true) {
            notificationNavigationSequence++
        }
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
        if (intent.getBooleanExtra("zoky_open_messages", false)) {
            notificationNavigationSequence++
        }
    }
}
