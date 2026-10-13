package online.wynos.food.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import online.wynos.food.R

/**
 * The same OFL Anuphan typeface as food.wynos.online:
 * see web/app/food/layout.tsx and web/app/food/food-app.css.
 * The font is bundled offline. Never load the website in a WebView.
 */
private val Anuphan = FontFamily(
    Font(R.font.anuphan, FontWeight.Normal),
    Font(R.font.anuphan, FontWeight.Medium),
    Font(R.font.anuphan, FontWeight.SemiBold),
    Font(R.font.anuphan, FontWeight.Bold),
)

private val defaults = Typography()
private val FoodTypography = Typography(
    displayLarge = defaults.displayLarge.copy(fontFamily = Anuphan),
    displayMedium = defaults.displayMedium.copy(fontFamily = Anuphan),
    displaySmall = defaults.displaySmall.copy(fontFamily = Anuphan),
    headlineLarge = defaults.headlineLarge.copy(fontFamily = Anuphan),
    headlineMedium = defaults.headlineMedium.copy(fontFamily = Anuphan),
    headlineSmall = defaults.headlineSmall.copy(fontFamily = Anuphan),
    titleLarge = defaults.titleLarge.copy(fontFamily = Anuphan),
    titleMedium = defaults.titleMedium.copy(fontFamily = Anuphan),
    titleSmall = defaults.titleSmall.copy(fontFamily = Anuphan),
    bodyLarge = defaults.bodyLarge.copy(fontFamily = Anuphan),
    bodyMedium = defaults.bodyMedium.copy(fontFamily = Anuphan),
    bodySmall = defaults.bodySmall.copy(fontFamily = Anuphan),
    labelLarge = defaults.labelLarge.copy(fontFamily = Anuphan),
    labelMedium = defaults.labelMedium.copy(fontFamily = Anuphan),
    labelSmall = defaults.labelSmall.copy(fontFamily = Anuphan),
)

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
        typography = FoodTypography,
        content = content,
    )
}
