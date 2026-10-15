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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** A minimal auth + anonymous catalog surface; deliberately NO order/payment writes. */
interface FoodGateway {
    val configured: Boolean
    val addressWritesEnabled: Boolean get() = false
    val signupEnabled: Boolean get() = false
    val accountDeletionEnabled: Boolean get() = false
    val stagingOrderCreationEnabled: Boolean get() = false
    val stagingMobilePaymentEnabled: Boolean get() = false
    val stagingOrderCancelEnabled: Boolean get() = false
    suspend fun cancelOrderStaging(orderId: String) {
        throw IllegalStateException("staging_order_cancel_disabled")
    }
    suspend fun createStagingPaymentIntent(orderId: String): FoodMobilePaymentIntent =
        throw IllegalStateException("staging_mobile_payment_disabled")
    suspend fun createOrderStaging(
        cart: FoodCartDraft,
        address: FoodCustomerAddress,
        customerNote: String = "",
        attemptId: String,
    ): String = throw IllegalStateException("staging_order_creation_disabled")
    suspend fun deleteMyAccount() {
        throw IllegalStateException("account_deletion_disabled")
    }
    suspend fun signUp(email: String, password: String): String? =
        throw IllegalStateException("signup_disabled")
    suspend fun saveAddress(draft: FoodAddressDraft): String =
        throw IllegalStateException("address_writes_disabled")
    suspend fun deleteAddress(id: String) {
        throw IllegalStateException("address_writes_disabled")
    }
    suspend fun catalog(): List<FoodStore>
    suspend fun homeBanners(): List<FoodHomeBanner>
    suspend fun storeReviewFeed(storeId: String): FoodStoreReviewFeed =
        throw UnsupportedOperationException("review_feed_not_configured")
    suspend fun promotionInbox(): List<FoodPromotionNotice> =
        throw UnsupportedOperationException("promotion_inbox_not_configured")
    suspend fun markPromotionRead(id: String) {
        throw UnsupportedOperationException("promotion_read_not_configured")
    }
    val chatEnabled: Boolean get() = false
    suspend fun orderChatMessages(orderId: String): List<FoodOrderChatMessage> =
        throw UnsupportedOperationException("order_chat_not_configured")
    suspend fun sendOrderChatMessage(orderId: String, body: String, clientId: String) {
        throw UnsupportedOperationException("order_chat_not_configured")
    }
    suspend fun accountEmail(): String?
    suspend fun orderHistory(): List<FoodOrderSummary>
    suspend fun orderDetail(orderId: String): FoodOrderDetail? = null
    suspend fun addresses(): List<FoodCustomerAddress>
    suspend fun quote(cart: FoodCartDraft, address: FoodCustomerAddress?): FoodServerQuote
    suspend fun signIn(email: String, password: String): String?
    suspend fun signOut()
    suspend fun resetPassword(email: String)
}

class SupabaseFoodGateway : FoodGateway {
    override val chatEnabled: Boolean get() =
        configured && BuildConfig.CHAT_STAGING_ALLOWED

    override val addressWritesEnabled: Boolean get() =
        configured && BuildConfig.ADDRESS_WRITES_ALLOWED
    override val signupEnabled: Boolean get() =
        configured && BuildConfig.ACCOUNT_SIGNUP_ALLOWED
    override val accountDeletionEnabled: Boolean get() =
        configured && BuildConfig.ACCOUNT_DELETION_ALLOWED
    override val stagingOrderCreationEnabled: Boolean get() =
        configured && BuildConfig.STAGING_ORDER_CREATION_ALLOWED
    override val stagingMobilePaymentEnabled: Boolean get() =
        configured && BuildConfig.STAGING_MOBILE_PAYMENT_ALLOWED
    override val stagingOrderCancelEnabled: Boolean get() =
        configured && BuildConfig.STAGING_ORDER_CANCEL_ALLOWED

    override suspend fun cancelOrderStaging(orderId: String) {
        check(stagingOrderCancelEnabled) { "staging_order_cancel_disabled" }
        // Never send an arbitrary order id; the Postgres RPC also checks buyer_id
        // and only allows pending_acceptance with payment pending/issue.
        java.util.UUID.fromString(orderId)
        val supabase = requireClient()
        supabase.auth.awaitInitialization()
        check(supabase.auth.currentUserOrNull() != null) { "sign_in_required" }
        supabase.postgrest.rpc(
            "food_cancel_order",
            buildJsonObject {
                put("p_order_id", orderId)
                put("p_reason", "ลูกค้ายกเลิกผ่าน Zoky Android Staging")
            },
        )
    }

    override suspend fun createStagingPaymentIntent(orderId: String): FoodMobilePaymentIntent {
        check(stagingMobilePaymentEnabled) { "staging_mobile_payment_disabled" }
        java.util.UUID.fromString(orderId)
        val supabase = requireClient()
        supabase.auth.awaitInitialization()
        val token = supabase.auth.currentSessionOrNull()?.accessToken
            ?: throw IllegalStateException("sign_in_required")
        // Direct HTTPS to a function belonging to the same configured Supabase
        // staging project; no spoofed browser Origin or Stripe secret on Android.
        return withContext(Dispatchers.IO) {
            val connection = URL(
                "${BuildConfig.SUPABASE_URL}/functions/v1/food-mobile-payment-intent"
            ).openConnection() as HttpURLConnection
            try {
                connection.requestMethod = "POST"
                connection.connectTimeout = 12_000
                connection.readTimeout = 20_000
                connection.setRequestProperty("Authorization", "Bearer $token")
                connection.setRequestProperty("apikey", BuildConfig.SUPABASE_PUBLISHABLE_KEY)
                connection.setRequestProperty("Content-Type", "application/json")
                connection.doOutput = true
                val body = buildJsonObject { put("orderId", orderId) }.toString()
                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
                if (connection.responseCode != 200) {
                    // Do not echo raw server errors or payment secrets into logs.
                    throw IllegalStateException("staging_mobile_payment_unavailable")
                }
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                FoodMobilePaymentIntentParser.parse(response, orderId)
            } finally {
                connection.disconnect()
            }
        }
    }

    override suspend fun createOrderStaging(
        cart: FoodCartDraft,
        address: FoodCustomerAddress,
        customerNote: String,
        attemptId: String,
    ): String {
        check(stagingOrderCreationEnabled) { "staging_order_creation_disabled" }
        val supabase = requireClient()
        supabase.auth.awaitInitialization()
        check(supabase.auth.currentUserOrNull() != null) { "sign_in_required" }
        // Private buyer-scoped attempt table + atomic order RPC must be deployed
        // on the disposable staging project before enabling this debug-only flow.
        // No card charge and no privileged/mobile secret keys.
        val result = supabase.postgrest.rpc(
            "food_create_order_idempotent",
            FoodOrderSubmission.idempotentRequest(cart, address, customerNote, attemptId),
        ).decodeAs<JsonElement>()
        val orderId = (result as? kotlinx.serialization.json.JsonPrimitive)?.content
            ?: throw IllegalStateException("missing_created_order_id")
        java.util.UUID.fromString(orderId)
        return orderId
    }

    private suspend fun requireWritableClient(): SupabaseClient {
        check(addressWritesEnabled) { "address_writes_disabled" }
        val supabase = requireClient()
        supabase.auth.awaitInitialization()
        check(supabase.auth.currentUserOrNull() != null) { "sign_in_required" }
        return supabase
    }

    override suspend fun saveAddress(draft: FoodAddressDraft): String {
        // No direct table writes and no privileged keys. RPC checks auth.uid() ownership.
        val response = requireWritableClient().postgrest.rpc(
            "food_upsert_customer_address_v3", draft.toRpcParams()
        ).decodeAs<JsonElement>()
        val id = (response as? kotlinx.serialization.json.JsonPrimitive)?.content.orEmpty().trim('"')
        require(id.isNotBlank()) { "missing_saved_address_id" }
        return id
    }

    override suspend fun deleteAddress(id: String) {
        require(id.matches(Regex("[0-9a-fA-F-]{36}"))) { "invalid_address_id" }
        requireWritableClient().postgrest.rpc(
            "food_delete_customer_address", kotlinx.serialization.json.buildJsonObject {
                put("p_address_id", id)
            }
        )
    }
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

    override suspend fun storeReviewFeed(storeId: String): FoodStoreReviewFeed {
        require(runCatching { java.util.UUID.fromString(storeId) }.isSuccess) {
            "invalid_store_id"
        }
        // Read-only server RPC with its own access policy; no direct anonymous
        // table read and no review submission. No fabricated reviews on error.
        val response = requireClient().postgrest.rpc(
            "food_store_review_feed",
            buildJsonObject {
                put("p_store_id", storeId)
                put("p_limit", 20)
            },
        ).decodeAs<JsonElement>()
        return FoodStoreReviewFeedParser.parse(response)
    }

    override suspend fun promotionInbox(): List<FoodPromotionNotice> {
        val supabase = requireClient()
        val auth = supabase.auth
        auth.awaitInitialization()
        val owner = auth.currentUserOrNull()?.id ?: throw IllegalStateException("sign_in_required")
        // Same read as the Web promotion center: limit to the logged-in buyer,
        // with server-side RLS as the mandatory second layer of protection.
        val rows = supabase.from("food_notifications").select(
            Columns.list("id", "title", "body", "coupon_code", "created_at", "read_at")
        ) {
            filter { eq("recipient_id", owner) }
            order("created_at", io.github.jan.supabase.postgrest.query.Order.DESCENDING)
            limit(30)
        }.decodeAs<JsonElement>()
        return FoodPromotionInboxParser.parse(rows)
    }

    override suspend fun markPromotionRead(id: String) {
        require(runCatching { java.util.UUID.fromString(id) }.isSuccess) {
            "invalid_notification_id"
        }
        val supabase = requireClient()
        supabase.auth.awaitInitialization()
        val owner = supabase.auth.currentUserOrNull()?.id
            ?: throw IllegalStateException("sign_in_required")
        // A user's own read marker only. Table RLS must independently enforce
        // recipient_id = auth.uid(), even if the client filter were removed.
        supabase.from("food_notifications").update({
            set("read_at", java.time.Instant.now().toString())
        }) {
            filter {
                eq("id", id)
                eq("recipient_id", owner)
            }
        }
    }

    override suspend fun orderChatMessages(orderId: String): List<FoodOrderChatMessage> {
        check(chatEnabled) { "order_chat_staging_disabled" }
        java.util.UUID.fromString(orderId)
        val supabase = requireClient()
        supabase.auth.awaitInitialization()
        val owner = supabase.auth.currentUserOrNull()?.id
            ?: throw IllegalStateException("sign_in_required")
        val rows = supabase.from("food_order_chat_messages").select(
            Columns.list("id", "body", "sender_id", "created_at")
        ) {
            filter { eq("order_id", orderId) }
            order("created_at", io.github.jan.supabase.postgrest.query.Order.ASCENDING)
            limit(100)
        }.decodeList<JsonObject>()
        return rows.mapNotNull { row ->
            val id = (row["id"] as? kotlinx.serialization.json.JsonPrimitive)?.content
            val body = (row["body"] as? kotlinx.serialization.json.JsonPrimitive)?.content
            val sender = (row["sender_id"] as? kotlinx.serialization.json.JsonPrimitive)?.content
            val timestamp = (row["created_at"] as? kotlinx.serialization.json.JsonPrimitive)?.content
            if (id.isNullOrBlank() || body.isNullOrBlank() || sender.isNullOrBlank()) null
            else FoodOrderChatMessage(id, body, timestamp.orEmpty(), sender == owner)
        }
    }

    override suspend fun sendOrderChatMessage(orderId: String, body: String, clientId: String) {
        check(chatEnabled) { "order_chat_staging_disabled" }
        java.util.UUID.fromString(orderId)
        java.util.UUID.fromString(clientId)
        val message = body.trim()
        require(message.isNotEmpty() && message.length <= 1200) { "invalid_chat_text" }
        val supabase = requireClient()
        supabase.auth.awaitInitialization()
        val owner = supabase.auth.currentUserOrNull()?.id
            ?: throw IllegalStateException("sign_in_required")
        // RLS checks order ownership/merchant role, sender and tenant. Never
        // trust this client-side gating as the only access control.
        supabase.from("food_order_chat_messages").insert(buildJsonObject {
            put("order_id", orderId)
            put("sender_id", owner)
            put("client_id", clientId)
            put("body", message)
        })
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
            Columns.list("id", "order_number", "store_id", "status", "payment_status", "total", "created_at")
        ) {
            filter { eq("buyer_id", owner) }
            limit(50)
        }.decodeList<JsonObject>()
        return rows.mapNotNull(FoodOrderSummary::fromJson).sortedByDescending { it.createdAt }
    }

    override suspend fun orderDetail(orderId: String): FoodOrderDetail? {
        // A user may select only their own order; RLS also protects each related row.
        require(orderId.matches(Regex("[0-9a-fA-F-]{36}"))) { "invalid_order_id" }
        val supabase = requireClient()
        supabase.auth.awaitInitialization()
        val owner = supabase.auth.currentUserOrNull()?.id ?: return null
        val orders = supabase.from("food_orders").select(
            Columns.list(
                "id", "order_number", "status", "payment_status",
                "recipient_name", "recipient_phone", "shipping_address", "customer_note",
                "subtotal", "delivery_fee", "campaign_discount", "delivery_discount",
                "total", "created_at",
            )
        ) {
            filter {
                eq("id", orderId)
                eq("buyer_id", owner)
            }
            limit(1)
        }.decodeList<JsonObject>()
        val order = orders.firstOrNull() ?: return null
        val items = supabase.from("food_order_items").select(
            Columns.list("item_name", "unit_price", "quantity", "selected_options", "item_note")
        ) {
            filter { eq("order_id", orderId) }
            limit(100)
        }.decodeList<JsonObject>()
        val events = supabase.from("food_order_events").select(
            Columns.list("event_type", "to_status", "created_at")
        ) {
            filter { eq("order_id", orderId) }
            limit(100)
        }.decodeList<JsonObject>()
        // No privileged key, writes, payment requests or client-authoritative statuses.
        return FoodOrderDetailParser.fromRows(order, items, events)
    }

    override suspend fun addresses(): List<FoodCustomerAddress> {
        val supabase = requireClient()
        supabase.auth.awaitInitialization()
        val owner = supabase.auth.currentUserOrNull()?.id ?: return emptyList()
        val rows = supabase.from("food_customer_addresses").select(
            Columns.list(
                "id", "label", "recipient_name", "recipient_phone",
                "address", "delivery_note", "is_default", "latitude", "longitude",
                "address_line1", "moo", "soi", "road", "subdistrict",
                "district", "province", "postal_code", "building_name",
                "floor", "room", "landmark", "place_id", "place_name",
            )
        ) {
            filter { eq("user_id", owner) }
            limit(50)
        }.decodeList<JsonObject>()
        // Must also have Postgres RLS; buyer-owned rows only.
        return FoodAddressParser.parse(rows)
    }

    override suspend fun quote(cart: FoodCartDraft, address: FoodCustomerAddress?): FoodServerQuote {
        val supabase = requireClient()
        supabase.auth.awaitInitialization()
        require(supabase.auth.currentUserOrNull() != null) { "sign_in_required" }
        // Quote RPC only: does not create an order, payment, or customer mutation.
        val response = supabase.postgrest.rpc(
            "food_quote_order",
            FoodQuoteRequest.fromCart(cart, address),
        ).decodeAs<JsonElement>()
        return FoodServerQuote.parse(response)
    }

    override suspend fun signUp(email: String, password: String): String? {
        // This is intentionally unavailable in production-configured and release APKs.
        // Use the existing WYNOS Auth identity, never a separate Food users table.
        check(signupEnabled) { "signup_disabled" }
        val auth = requireClient().auth
        auth.signUpWith(Email) {
            this.email = email
            this.password = password
        }
        // Supabase may require email confirmation (null session) or sign in immediately
        // depending on the explicitly configured staging auth policy.
        return auth.currentUserOrNull()?.email
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

    override suspend fun deleteMyAccount() {
        // An irreversible shared WYNOS Account action, never Food-only deletion.
        // Staging debug opt-in is enforced in BuildConfig; it is off in every release.
        check(accountDeletionEnabled) { "account_deletion_disabled" }
        val supabase = requireClient()
        supabase.auth.awaitInitialization()
        check(supabase.auth.currentUserOrNull() != null) { "sign_in_required" }
        // No arbitrary user ID: existing SECURITY DEFINER RPC uses auth.uid().
        supabase.postgrest.rpc("delete_my_account")
        // The deleted account may no longer be recognized by remote sign-out.
        // Clear local session even when remote revocation fails (SDK 3.1.4).
        try {
            supabase.auth.signOut()
        } catch (cancel: kotlinx.coroutines.CancellationException) {
            throw cancel
        } catch (_: Exception) {
            // Remote sign-out may return "user not found" after the RPC succeeds.
        } finally {
            supabase.auth.clearSession()
        }
    }

    override suspend fun resetPassword(email: String) {
        // Uses the existing WYNOS Account email-recovery page; no new auth backend.
        requireClient().auth.resetPasswordForEmail(email, redirectUrl = "https://wynos.online/reset-password")
    }
}
