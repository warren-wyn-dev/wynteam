package io.wyn.wyn.core.design

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf

/** Light, dark, or follow the phone: the same three choices as the web (WYN-188). */
enum class ThemeChoice { System, Light, Dark }

val LocalWynColors = staticCompositionLocalOf { LightWynColors }

@Composable
fun WynosTheme(choice: ThemeChoice = ThemeChoice.System, content: @Composable () -> Unit) {
    val dark = when (choice) {
        ThemeChoice.System -> isSystemInDarkTheme()
        ThemeChoice.Light -> false
        ThemeChoice.Dark -> true
    }
    val colors = if (dark) DarkWynColors else LightWynColors
    val scheme = if (dark) {
        darkColorScheme(
            primary = colors.text, onPrimary = colors.bg, background = colors.bg, onBackground = colors.text,
            surface = colors.bg, onSurface = colors.text, surfaceVariant = colors.surface,
            onSurfaceVariant = colors.textSecondary, outline = colors.border, error = colors.accent,
        )
    } else {
        lightColorScheme(
            primary = colors.text, onPrimary = colors.bg, background = colors.bg, onBackground = colors.text,
            surface = colors.bg, onSurface = colors.text, surfaceVariant = colors.surface,
            onSurfaceVariant = colors.textSecondary, outline = colors.border, error = colors.accent,
        )
    }
    CompositionLocalProvider(LocalWynColors provides colors) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}

object Wyn {
    val colors: WynColors
        @Composable get() = LocalWynColors.current
}
