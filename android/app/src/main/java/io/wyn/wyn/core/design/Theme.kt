package io.wyn.wyn.core.design

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/** Light, dark, or follow the phone: the same three choices as the web (WYN-188). */
enum class ThemeChoice { System, Light, Dark }

val LocalWynColors = staticCompositionLocalOf { LightWynColors }

// Compact native Android typography; do not override system accessibility font scale.
private val WynTypography = Typography(
    bodyLarge = TextStyle(fontSize = 15.sp, lineHeight = 21.sp),
    bodyMedium = TextStyle(fontSize = 14.sp, lineHeight = 20.sp),
    titleLarge = TextStyle(fontSize = 20.sp, lineHeight = 26.sp, fontWeight = FontWeight.SemiBold),
    titleMedium = TextStyle(fontSize = 16.sp, lineHeight = 22.sp, fontWeight = FontWeight.SemiBold),
    labelLarge = TextStyle(fontSize = 14.sp, lineHeight = 20.sp, fontWeight = FontWeight.Medium),
)

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
        MaterialTheme(colorScheme = scheme, typography = WynTypography, content = content)
    }
}

object Wyn {
    val colors: WynColors
        @Composable get() = LocalWynColors.current
}
