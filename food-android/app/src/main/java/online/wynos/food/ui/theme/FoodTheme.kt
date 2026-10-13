package online.wynos.food.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val Brand = Color(0xFFE40036)

private val LightColors = lightColorScheme(
    primary = Brand,
    onPrimary = Color.White,
    background = Color.White,
    onBackground = Color(0xFF16161A),
    surface = Color.White,
    onSurface = Color(0xFF16161A),
    surfaceVariant = Color(0xFFF6F6F8),
    outline = Color(0xFFEBEBEF),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFFF8295),
    onPrimary = Color(0xFF40131D),
    background = Color(0xFF151517),
    surface = Color(0xFF151517),
    onSurface = Color(0xFFF6F6F6),
)

@Composable
fun WynosFoodTheme(
    darkTheme: Boolean = false,
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content,
    )
}
