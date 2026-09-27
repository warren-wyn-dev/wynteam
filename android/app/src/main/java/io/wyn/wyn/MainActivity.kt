package io.wyn.wyn

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import io.wyn.wyn.core.design.WynosTheme
import io.wyn.wyn.feature.welcome.WelcomeScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            WynosTheme {
                WelcomeScreen(onCreateAccount = {}, onSignIn = {}, onGoogle = {})
            }
        }
    }
}
