package io.wyn.wyn.core.data

import android.content.Context
import android.content.res.Configuration
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.util.Locale

/**
 * This phone's theme and language choice (web wynos.theme.v1 / wynos.lang.v1).
 * null means "follow the phone". The signed-in account's saved choice wins
 * and is cached here (web ThemeSync / LanguageSync).
 */
class DevicePreferences(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    var theme by mutableStateOf(ThemePreference.of(prefs.getString(THEME, null))); private set
    var language by mutableStateOf(AppLanguage.of(prefs.getString(LANGUAGE, null))); private set

    fun applyTheme(value: ThemePreference?) {
        theme = value
        prefs.edit().apply { if (value == null) remove(THEME) else putString(THEME, value.wire) }.apply()
    }

    /** True when the language shown changes (the screen must be rebuilt). */
    fun applyLanguage(value: AppLanguage?): Boolean {
        if (value == language) return false
        language = value
        // Written at once: the screen is rebuilt right after and reads it back.
        prefs.edit().apply { if (value == null) remove(LANGUAGE) else putString(LANGUAGE, value.wire) }.commit()
        return true
    }

    companion object {
        private const val FILE = "wynos.device"
        private const val THEME = "theme"
        private const val LANGUAGE = "language"

        /** web deviceLanguage(): English for en-*, Thai for any other phone language. */
        fun deviceLanguage(locale: Locale = Locale.getDefault()): AppLanguage =
            if (locale.language == "en") AppLanguage.English else AppLanguage.Thai

        /** The context in the chosen language; unchanged when following the phone. */
        fun wrap(base: Context): Context {
            val chosen = AppLanguage.of(base.getSharedPreferences(FILE, Context.MODE_PRIVATE).getString(LANGUAGE, null)) ?: return base
            val locale = Locale.forLanguageTag(chosen.wire)
            val config = Configuration(base.resources.configuration).apply { setLocale(locale) }
            return base.createConfigurationContext(config)
        }
    }
}
