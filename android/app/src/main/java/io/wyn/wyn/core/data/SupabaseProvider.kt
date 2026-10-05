package io.wyn.wyn.core.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.storage.Storage
import io.wyn.wyn.BuildConfig

/**
 * The one Supabase client for the app: the same project, publishable key
 * and RLS as Wynos Web, so data is shared across platforms. Never a service
 * key. Null when the build has no configuration.
 */
object SupabaseProvider {
    val isConfigured: Boolean
        get() = BuildConfig.SUPABASE_URL.startsWith("https://") && BuildConfig.SUPABASE_PUBLISHABLE_KEY.isNotBlank()

    val client: SupabaseClient? by lazy {
        if (!isConfigured) {
            null
        } else {
            createSupabaseClient(BuildConfig.SUPABASE_URL, BuildConfig.SUPABASE_PUBLISHABLE_KEY) {
                install(Auth)
                install(Postgrest)
                install(Storage)
                install(Realtime)
            }
        }
    }
}
