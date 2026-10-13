package online.wynos.food

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import online.wynos.food.ui.FoodApp
import online.wynos.food.ui.theme.WynosFoodTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            WynosFoodTheme {
                FoodApp()
            }
        }
    }
}
