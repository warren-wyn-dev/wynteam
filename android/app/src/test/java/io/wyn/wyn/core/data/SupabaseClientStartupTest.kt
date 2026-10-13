package io.wyn.wyn.core.data

import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.storage.Storage
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Smoke test the exact production plugin combination in an Android-like
 * Robolectric context. Uses only a made-up URL / publishable client key and
 * does not perform HTTP requests or touch production data.
 */
@RunWith(RobolectricTestRunner::class)
class SupabaseClientStartupTest {
    @Test
    fun createsSupabaseClientWithAndroidPluginCombination() {
        val client = createSupabaseClient(
            "https://test-only.supabase.co",
            "sb_publishable_test_only_no_network_calls",
        ) {
            install(Auth)
            install(Postgrest)
            install(Storage)
            install(Realtime)
        }
        assertNotNull(client)
    }
}
