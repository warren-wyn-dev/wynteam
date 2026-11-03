package io.wyn.wyn.core.data

import android.content.Context
import com.russhwolf.settings.SharedPreferencesSettings
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.SettingsCodeVerifierCache
import io.github.jan.supabase.auth.SettingsSessionManager
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.storage.Storage
import io.wyn.wyn.BuildConfig

/**
 * The Android app uses the SAME Supabase project and public client key as
 * WYNOS Web. Never use an elevated/service key in an APK.
 *
 * Explicit Android Settings avoid the no-argument Settings() initialization
 * failure observed in supabase-kt 3.1.4 when constructing the Auth plugin.
 */
object SupabaseProvider {
    @Volatile private var applicationContext: Context? = null

    fun initialize(context: Context) {
        applicationContext = context.applicationContext
    }

    val isConfigured: Boolean
        get() = BuildConfig.SUPABASE_URL.startsWith("https://") && BuildConfig.SUPABASE_PUBLISHABLE_KEY.isNotBlank()

    val client: SupabaseClient? by lazy {
        if (!isConfigured) null
        else createClient(
            checkNotNull(applicationContext) { "Initialize SupabaseProvider in WynosApplication first" },
            BuildConfig.SUPABASE_URL,
            BuildConfig.SUPABASE_PUBLISHABLE_KEY,
        )
    }

    /** Injection seam for a network-free Android/Robolectric client-init smoke test. */
    internal fun createClient(context: Context, url: String, key: String): SupabaseClient {
        // Application-private SharedPreferences. Do not back up session tokens.
        val prefs = context.applicationContext.getSharedPreferences("wynos.supabase.auth.v1", Context.MODE_PRIVATE)
        val settings = SharedPreferencesSettings(prefs)
        return createSupabaseClient(url, key) {
            install(Auth) {
                sessionManager = SettingsSessionManager(settings = settings)
                codeVerifierCache = SettingsCodeVerifierCache(settings = settings)
            }
            install(Postgrest)
            install(Storage)
            install(Realtime)
        }
    }
}
