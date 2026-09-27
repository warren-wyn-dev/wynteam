package io.wyn.wyn.feature.welcome

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import io.wyn.wyn.core.design.ThemeChoice
import io.wyn.wyn.core.design.WynosTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Renders the Welcome screen in Thai/English, light/dark (Pixel 7 size). */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class WelcomeScreenshotTest {
    @get:Rule val compose = createComposeRule()

    private fun render(theme: ThemeChoice, name: String) {
        compose.setContent {
            WynosTheme(theme) { WelcomeScreen(onCreateAccount = {}, onSignIn = {}, onGoogle = {}, configured = true) }
        }
        compose.onRoot().captureRoboImage("build/screenshots/welcome-$name.png")
    }

    @Test @Config(qualifiers = "th-w411dp-h914dp-xxhdpi")
    fun thaiLight() {
        render(ThemeChoice.Light, "th-light")
        compose.onNodeWithText("สร้างบัญชีใหม่").assertExists()
    }

    @Test @Config(qualifiers = "en-w411dp-h914dp-night-xxhdpi")
    fun englishDark() {
        render(ThemeChoice.Dark, "en-dark")
        compose.onNodeWithText("Create a new account").assertExists()
    }
}
