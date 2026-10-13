package online.wynos.food.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.serialization.json.JsonObject
import online.wynos.food.BuildConfig
import kotlinx.serialization.json.JsonElement

/** A minimal auth + anonymous catalog surface; deliberately NO order/payment writes. */
interface FoodGateway {
    val configured: Boolean
    suspend fun catalog(): List<FoodStore>
    suspend fun homeBanners(): List<FoodHomeBanner>
    suspend fun accountEmail(): String?
    suspend fun orderHistory(): List<FoodOrderSummary>
    suspend fun signIn(email: String, password: String): String?
    suspend fun signOut()
    suspend fun resetPassword(email: String)
}

class SupabaseFoodGateway : FoodGateway {
    override val configured: Boolean
        get() = BuildConfig.SUPABASE_URL.startsWith("https://") &&
            BuildConfig.SUPABASE_PUBLISHABLE_KEY.isNotBlank()

    private val client: SupabaseClient? by lazy {
        if (!configured) null else createSupabaseClient(
            supabaseUrl = BuildConfig.SUPABASE_URL,
            supabaseKey = BuildConfig.SUPABASE_PUBLISHABLE_KEY,
        ) {
            install(Auth)
            install(Postgrest)
        }
    }

    private fun requireClient(): SupabaseClient =
        client ?: throw IllegalStateException("Supabase client is not configured")

    override suspend fun catalog(): List<FoodStore> {
        // Reuse the public read-only RPC used by web guest browsing.
        // Never read food_stores / food_menu_items anonymously.
        val response = requireClient().postgrest.rpc("food_public_catalog").decodeAs<JsonElement>()
        return FoodCatalogParser.parse(response)
    }

    override suspend fun homeBanners(): List<FoodHomeBanner> {
        // Same public, admin-controlled homepage banners RPC used by web.
        val response = requireClient().postgrest.rpc("food_active_home_banners").decodeAs<JsonElement>()
        return FoodHomeBannerParser.parse(response)
    }

    override suspend fun accountEmail(): String? {
        val auth = requireClient().auth
        auth.awaitInitialization()
        return auth.currentUserOrNull()?.email
    }

    override suspend fun orderHistory(): List<FoodOrderSummary> {
        val supabase = requireClient()
        val auth = supabase.auth
        auth.awaitInitialization()
        val owner = auth.currentUserOrNull()?.id ?: return emptyList()
        // Defense in depth: filter by buyer_id, with server RLS still mandatory.
        val rows = supabase.from("food_orders").select(
            Columns.list("id", "order_number", "status", "payment_status", "total", "created_at")
        ) {
            filter { eq("buyer_id", owner) }
            limit(50)
        }.decodeList<JsonObject>()
        return rows.mapNotNull(FoodOrderSummary::fromJson).sortedByDescending { it.createdAt }
    }

    override suspend fun signIn(email: String, password: String): String? {
        val auth = requireClient().auth
        auth.signInWith(Email) {
            this.email = email
            this.password = password
        }
        return auth.currentUserOrNull()?.email
    }

    override suspend fun signOut() {
        requireClient().auth.signOut()
    }

    override suspend fun resetPassword(email: String) {
        // Uses the existing WYNOS Account email-recovery page; no new auth backend.
        requireClient().auth.resetPasswordForEmail(email, redirectUrl = "https://wynos.online/reset-password")
    }
}
