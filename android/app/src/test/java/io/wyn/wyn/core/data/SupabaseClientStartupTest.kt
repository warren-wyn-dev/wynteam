package io.wyn.wyn.core.data

import org.robolectric.RuntimeEnvironment
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
        val client = SupabaseProvider.createClient(
            RuntimeEnvironment.getApplication(),
            "https://test-only.supabase.co",
            "sb_publishable_test_only_no_network_calls",
        )
        assertNotNull(client)
    }
}
