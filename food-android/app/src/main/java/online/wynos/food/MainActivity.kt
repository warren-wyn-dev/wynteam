package online.wynos.food

import android.os.Bundle
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
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
                    FoodApp()
                }
            }
        }
    }
}
