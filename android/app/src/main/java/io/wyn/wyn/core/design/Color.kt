package io.wyn.wyn.core.design

import androidx.compose.ui.graphics.Color

/**
 * Wynos design tokens, copied from web/app/design-system.css (--wyn-*) so
 * both platforms share one palette. White 80–90%, colour only as accents.
 */
data class WynColors(
    val bg: Color,
    val surface: Color,
    val text: Color,
    val textSecondary: Color,
    val textMuted: Color,
    val border: Color,
    val borderStrong: Color,
    val accent: Color,
    val link: Color,
    val like: Color,
)

val LightWynColors = WynColors(
    bg = Color(0xFFFFFFFF),
    surface = Color(0xFFF5F5F5),
    text = Color(0xFF171717),
    textSecondary = Color(0xFF737373),
    textMuted = Color(0xFF9A9A9A),
    border = Color(0xFFE5E5E5),
    borderStrong = Color(0xFFD4D4D4),
    accent = Color(0xFFE0203D),
    link = Color(0xFF0969DA),
    like = Color(0xFFFF3B30),
)

val DarkWynColors = WynColors(
    bg = Color(0xFF000000),
    surface = Color(0xFF111111),
    text = Color(0xFFFFFFFF),
    textSecondary = Color(0xFFA3A3A3),
    textMuted = Color(0xFF666666),
    border = Color(0xFF222222),
    borderStrong = Color(0xFF666666),
    accent = Color(0xFFE0203D),
    link = Color(0xFF5EB1FF),
    like = Color(0xFFFF3B30),
)

/** The rainbow accent used sparingly (announcement edges, highlights). */
val WynRainbow = listOf(
    Color(0xFFFF5F6D), Color(0xFFFFC371), Color(0xFF47E891), Color(0xFF3FA9F5), Color(0xFFA66CFF),
)
