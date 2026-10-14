package online.wynos.merchant

import android.content.Context
import android.net.Uri
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.ByteArrayOutputStream
import java.net.URI
import java.util.UUID
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener
import java.io.IOException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import java.time.LocalDate

/** Encrypt session locally using an Android Keystore AES-GCM key. */
internal class MerchantSessionStore(context: Context) {
    private val prefs = context.getSharedPreferences("merchant_session", Context.MODE_PRIVATE)
    private val alias = "wynos_merchant_session_key_v1"

    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getKey(alias, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256).build()
        )
        return generator.generateKey()
    }

    fun save(value: JSONObject) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val record = JSONObject()
            .put("iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .put("body", Base64.encodeToString(cipher.doFinal(value.toString().toByteArray()), Base64.NO_WRAP))
        prefs.edit().putString("encrypted", record.toString()).apply()
    }

    fun load(): JSONObject? {
        return try {
            val raw = prefs.getString("encrypted", null) ?: return null
            val record = JSONObject(raw)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(),
                GCMParameterSpec(128, Base64.decode(record.getString("iv"), Base64.NO_WRAP)))
            val bytes = cipher.doFinal(Base64.decode(record.getString("body"), Base64.NO_WRAP))
            JSONObject(String(bytes, Charsets.UTF_8))
        } catch (_: Exception) {
            clear()
            null
        }
    }

    fun clear() { prefs.edit().remove("encrypted").apply() }
}

/** Same auth/RLS/RPC contracts as the existing merchant web; public key only. */
class MerchantApi(context: Context) {
    private val appContext = context.applicationContext
    private val http = OkHttpClient.Builder().build()
    private val vault = MerchantSessionStore(context.applicationContext)
    private var session: JSONObject? = vault.load()
    private val base = BuildConfig.SUPABASE_URL.trimEnd('/')
    private val key = BuildConfig.SUPABASE_PUBLISHABLE_KEY
    private val jsonType = "application/json; charset=utf-8".toMediaType()

    val hasSession: Boolean get() = session?.optString("access_token")?.isNotBlank() == true
    val configured: Boolean get() = base.startsWith("https://") && key.isNotBlank()

    private fun raw(
        method: String, path: String, body: JSONObject? = null,
        bearer: String? = session?.optString("access_token"), retry: Boolean = true
    ): Any {
        check(configured) { "กรุณาตั้งค่า Supabase URL และ Publishable Key สำหรับ Android" }
        val builder = Request.Builder().url(base + path)
            .header("apikey", key).header("Accept", "application/json")
        if (!bearer.isNullOrBlank()) builder.header("Authorization", "Bearer $bearer")
        val requestBody = (body?.toString() ?: "{}").toRequestBody(jsonType)
        when (method) {
            "POST" -> builder.post(requestBody)
            "PATCH" -> builder.patch(requestBody)
            "DELETE" -> builder.delete()
            else -> builder.get()
        }
        http.newCall(builder.build()).execute().use { response ->
            if (response.code == 401 && retry && hasSession) {
                refresh()
                return raw(method, path, body, session?.optString("access_token"), false)
            }
            val value = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                val obj = runCatching { JSONObject(value) }.getOrNull()
                val message = obj?.optString("message")?.ifBlank { null }
                    ?: obj?.optString("msg")?.ifBlank { null }
                    ?: "HTTP " + response.code
                throw IOException(message)
            }
            return if (value.isBlank()) JSONObject() else JSONTokener(value).nextValue() ?: JSONObject()
        }
    }

    @Synchronized
    private fun refresh() {
        val token = session?.optString("refresh_token")?.takeIf { it.isNotBlank() }
            ?: throw IOException("กรุณาเข้าสู่ระบบอีกครั้ง")
        try {
            val next = raw("POST", "/auth/v1/token?grant_type=refresh_token",
                JSONObject().put("refresh_token", token), bearer = null, retry = false) as JSONObject
            session = next
            vault.save(next)
        } catch (e: Exception) {
            clearLocalSession()
            throw e
        }
    }

    private fun clearLocalSession() { session = null; vault.clear() }

    fun signIn(email: String, password: String) {
        val credentials = raw("POST", "/auth/v1/token?grant_type=password",
            JSONObject().put("email", email.trim()).put("password", password),
            bearer = null, retry = false) as JSONObject
        session = credentials
        vault.save(credentials)
        try { verifyMerchantAccess() } catch (e: Exception) { clearLocalSession(); throw e }
    }

    /** Mirrors web/lib/merchant-account.ts; reject inactive or non-merchant users. */
    fun verifyMerchantAccess() {
        if (!hasSession) throw IOException("กรุณาเข้าสู่ระบบ")
        val userId = (raw("GET", "/auth/v1/user") as JSONObject).getString("id")
        val identities = getArray("/rest/v1/merchant_users?select=user_id,active,identity_mode&user_id=eq.$userId&limit=1")
        if (identities.length() == 0 || !identities.getJSONObject(0).optBoolean("active")) {
            clearLocalSession()
            throw IOException("บัญชีนี้ยังไม่มีสิทธิ์ใช้ WYNOS Merchant")
        }
        val access = raw("POST", "/rest/v1/rpc/food_has_merchant_access",
            JSONObject().put("p_store_id", JSONObject.NULL))
        if (access != true) throw IOException("บัญชีไม่มีสิทธิ์เข้าถึงร้านค้า")
    }

    fun signOut() {
        runCatching { if (hasSession) raw("POST", "/auth/v1/logout", JSONObject(), retry = false) }
        clearLocalSession()
    }

    private fun getArray(path: String): JSONArray = raw("GET", path) as JSONArray
    private fun rpc(name: String, params: JSONObject): Any = raw("POST", "/rest/v1/rpc/$name", params)
    private fun filter(id: String): String {
        require(Regex("[a-fA-F0-9-]{36}").matches(id)) { "รหัสรายการไม่ถูกต้อง" }
        return id
    }

    fun stores(): JSONArray = getArray("/rest/v1/food_stores?select=*&order=created_at.asc")
    fun menu(storeId: String): JSONArray =
        getArray("/rest/v1/food_menu_items?select=*&store_id=eq." + filter(storeId) +
            "&order=sort_order.asc,created_at.asc")
    fun orders(storeId: String, offset: Int = 0): JSONArray =
        getArray("/rest/v1/food_orders?select=*,food_order_items(*),food_delivery_proofs(*)&store_id=eq." +
            filter(storeId) + "&order=created_at.desc&offset=" + offset.coerceAtLeast(0) + "&limit=101")
    fun history(storeId: String, status: String = "all", search: String = "",
                days: Int? = null, offset: Int = 0): JSONArray {
        require(status in setOf("all", "delivered", "cancelled")) { "สถานะประวัติไม่ถูกต้อง" }
        require(days == null || days in setOf(7, 30)) { "ช่วงวันที่ไม่ถูกต้อง" }
        val number = search.filter { it.isLetterOrDigit() }.take(40)
        val statusFilter = if (status == "all") "status=in.(delivered,cancelled)" else "status=eq.$status"
        val query = StringBuilder("/rest/v1/food_orders?select=*,food_order_items(*)&store_id=eq.")
            .append(filter(storeId)).append("&").append(statusFilter)
            .append("&order=created_at.desc&offset=").append(offset.coerceAtLeast(0)).append("&limit=31")
        if (number.isNotEmpty()) query.append("&order_number=ilike.")
            .append(Uri.encode("*" + number + "*"))
        if (days != null) query.append("&created_at=gte.")
            .append(Uri.encode(java.time.Instant.now().minus(java.time.Duration.ofDays(days.toLong())).toString()))
        return getArray(query.toString())
    }

    fun sales(storeId: String): JSONObject =
        rpc("merchant_sales_report", JSONObject().put("p_store_id", filter(storeId))) as JSONObject
    fun finance(storeId: String, from: LocalDate, to: LocalDate): JSONObject =
        rpc("merchant_finance_summary", JSONObject().put("p_store_id", filter(storeId))
            .put("p_from", from.toString()).put("p_to", to.toString())) as JSONObject
    fun readiness(storeId: String): JSONObject =
        rpc("food_store_publish_readiness", JSONObject().put("p_store_id", filter(storeId))) as JSONObject
    fun audit(storeId: String): JSONArray =
        rpc("merchant_store_audit_history", JSONObject().put("p_store_id", filter(storeId))
            .put("p_limit", 60)) as JSONArray

    fun transition(orderId: String, status: String, etaMinutes: Int? = null) {
        rpc("food_transition_order", JSONObject().put("p_order_id", filter(orderId))
            .put("p_status", status).put("p_eta_minutes", etaMinutes ?: JSONObject.NULL)
            .put("p_note", JSONObject.NULL))
    }

    fun setPaymentStatus(orderId: String, status: String) {
        require(status in setOf("paid", "issue")) { "สถานะการเงินไม่รองรับ" }
        rpc("food_set_payment_status", JSONObject().put("p_order_id", filter(orderId))
            .put("p_status", status).put("p_note", JSONObject.NULL))
    }

    fun setMenuAvailability(storeId: String, itemId: String, available: Boolean) {
        raw("PATCH", "/rest/v1/food_menu_items?id=eq." + filter(itemId) +
            "&store_id=eq." + filter(storeId), JSONObject().put("is_available", available))
    }

    fun saveMenu(storeId: String, draft: JSONObject) {
        require(draft.optString("name").isNotBlank()) { "กรุณาใส่ชื่อเมนู" }
        require(draft.optDouble("price", Double.NaN).isFinite() && draft.optDouble("price") >= 0) { "ราคาไม่ถูกต้อง" }
        val id = draft.optString("id").takeIf { it.isNotBlank() }
        val payload = JSONObject().put("store_id", filter(storeId))
            .put("name", draft.getString("name").trim())
            .put("category", draft.optString("category").ifBlank { "อาหาร" })
            .put("description", draft.optString("description"))
            .put("price", draft.getDouble("price"))
            .put("options", draft.optJSONArray("options") ?: JSONArray())
            .put("is_available", draft.optBoolean("is_available", true))
            .put("daily_stock_limit", draft.opt("daily_stock_limit") ?: JSONObject.NULL)
            .put("sold_out_until", draft.opt("sold_out_until") ?: JSONObject.NULL)
            .put("image_path", draft.opt("image_path") ?: JSONObject.NULL)
        if (id != null) raw("PATCH", "/rest/v1/food_menu_items?id=eq." + filter(id) +
            "&store_id=eq." + filter(storeId), payload)
        else raw("POST", "/rest/v1/food_menu_items", payload)
    }

    /** Signed private slip retrieval. URL origin is pinned to configured Supabase. */
    fun loadPrivateImage(path: String): ByteArray {
        val encoded = objectPath(path)
        val signing = raw(
            "POST",
            "/storage/v1/object/sign/food-private/$encoded",
            JSONObject().put("expiresIn", 300),
        ) as JSONObject
        val signed = signing.optString("signedURL")
        if (!signed.startsWith("/object/sign/food-private/")) throw IOException("ลิงก์สลิปไม่ถูกต้อง")
        val url = base + "/storage/v1" + signed
        val parsed = URI(url)
        if (parsed.scheme != "https" || parsed.host != URI(base).host ||
            parsed.rawPath?.startsWith("/storage/v1/object/sign/food-private/") != true) {
            throw IOException("โดเมนรูปภาพไม่ถูกต้อง")
        }
        // OkHttp redirects could escape this origin; disable them for signed private media.
        val safeHttp = http.newBuilder().followRedirects(false).build()
        safeHttp.newCall(Request.Builder().url(url).get().build()).execute().use { response ->
            if (!response.isSuccessful) throw IOException("โหลดสลิปไม่สำเร็จ (HTTP " + response.code + ")")
            val body = response.body ?: throw IOException("สลิปว่างเปล่า")
            val bytes = body.byteStream().use { stream ->
                val limit = 8 * 1024 * 1024
                val output = ByteArrayOutputStream()
                val chunk = ByteArray(8192)
                while (true) {
                    val read = stream.read(chunk)
                    if (read < 0) break
                    if (output.size() + read > limit) throw IOException("รูปมีขนาดเกิน 8 MB")
                    output.write(chunk, 0, read)
                }
                output.toByteArray()
            }
            if (bytes.isEmpty() || bytes.size > 8 * 1024 * 1024) throw IOException("สลิปมีขนาดไม่ถูกต้อง")
            return bytes
        }
    }

    private fun objectPath(path: String): String {
        require(path.isNotBlank() && path.length < 800 && !path.startsWith("/") &&
            path.split("/").all { it.isNotBlank() && it != "." && it != ".." }) {
            "ตำแหน่งไฟล์ไม่ถูกต้อง"
        }
        return path.split("/").joinToString("/") { Uri.encode(it) }
    }

    /**
     * Native image picker input, re-encoded to JPEG to remove EXIF GPS/location metadata.
     * Uses the SAME private storage bucket/path policy as the merchant web.
     */
    fun uploadDeliveryImage(orderId: String, uri: Uri): String =
        uploadImage("food-private", "delivery/" + filter(orderId), uri)

    fun uploadStoreImage(storeId: String, uri: Uri): String =
        uploadImage("food-public", "stores/" + filter(storeId) + "/profile", uri)

    fun uploadMenuImage(storeId: String, uri: Uri): String =
        uploadImage("food-public", "stores/" + filter(storeId) + "/menu", uri)

    fun uploadAdTopup(storeId: String, amount: Double, uri: Uri) {
        require(amount.isFinite() && amount > 0) { "ยอดเติมเครดิตไม่ถูกต้อง" }
        val path = uploadImage("food-private", "ads/" + filter(storeId), uri)
        rpc("merchant_request_ad_topup", JSONObject()
            .put("p_store_id", filter(storeId)).put("p_amount", amount).put("p_slip_path", path))
    }

    private fun uploadImage(bucket: String, prefix: String, uri: Uri): String {
        require(bucket == "food-private" || bucket == "food-public")
        val resolver = appContext.contentResolver
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
            ?: throw IOException("อ่านรูปไม่สำเร็จ")
        if (options.outWidth <= 0 || options.outHeight <= 0) throw IOException("ไฟล์นี้ไม่ใช่รูปภาพ")
        var sample = 1
        while (options.outWidth / sample > 1600 || options.outHeight / sample > 1600) sample *= 2
        val decoded = resolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream, null, BitmapFactory.Options().apply { inSampleSize = sample })
        } ?: throw IOException("อ่านรูปไม่สำเร็จ")
        val output = ByteArrayOutputStream()
        try {
            val max = maxOf(decoded.width, decoded.height)
            val scaled = if (max > 1600) {
                Bitmap.createScaledBitmap(decoded,
                    (decoded.width * 1600L / max).toInt().coerceAtLeast(1),
                    (decoded.height * 1600L / max).toInt().coerceAtLeast(1), true)
            } else decoded
            try {
                if (!scaled.compress(Bitmap.CompressFormat.JPEG, 84, output)) throw IOException("แปลงรูปไม่สำเร็จ")
            } finally {
                if (scaled !== decoded) scaled.recycle()
            }
        } finally { decoded.recycle() }
        val bytes = output.toByteArray()
        if (bytes.isEmpty() || bytes.size > 8 * 1024 * 1024) throw IOException("รูปใหญ่เกิน 8 MB")
        val path = prefix + "/" + UUID.randomUUID().toString() + ".jpg"
        val request = Request.Builder().url("$base/storage/v1/object/$bucket/$path")
            .header("apikey", key)
            .header("Authorization", "Bearer " + (session?.optString("access_token") ?: ""))
            .header("cache-control", "max-age=300")
            .post(bytes.toRequestBody("image/jpeg".toMediaType())).build()
        http.newCall(request).execute().use { response ->
            if (!response.isSuccessful) throw IOException("อัปโหลดรูปไม่สำเร็จ (HTTP " + response.code + ")")
        }
        return path
    }

    fun completeDelivery(orderId: String, method: String, locationNote: String, imagePath: String) {
        require(method == "direct" || method == "dropoff") { "ประเภทการจัดส่งไม่ถูกต้อง" }
        require(imagePath.startsWith("delivery/" + filter(orderId) + "/")) { "รูปไม่ตรงกับออเดอร์" }
        if (method == "dropoff") require(locationNote.isNotBlank()) { "กรุณาระบุจุดวางสินค้า" }
        rpc("food_complete_delivery", JSONObject().put("p_order_id", orderId)
            .put("p_method", method)
            .put("p_location_note", if (method == "dropoff") locationNote.trim() else JSONObject.NULL)
            .put("p_image_path", imagePath))
    }

    fun setPaymentStatusWithNote(orderId: String, status: String, note: String? = null) {
        require(status in setOf("paid", "issue")) { "สถานะการเงินไม่รองรับ" }
        rpc("food_set_payment_status", JSONObject().put("p_order_id", filter(orderId))
            .put("p_status", status)
            .put("p_note", note ?: JSONObject.NULL))
    }

    fun deleteMenu(storeId: String, itemId: String) {
        raw("DELETE", "/rest/v1/food_menu_items?id=eq." + filter(itemId) +
            "&store_id=eq." + filter(storeId))
    }

    fun soldOutToday(storeId: String, itemId: String, soldOut: Boolean) {
        val tomorrow = LocalDate.now(java.time.ZoneId.of("Asia/Bangkok"))
            .plusDays(1).atStartOfDay(java.time.ZoneId.of("Asia/Bangkok"))
            .toOffsetDateTime().toString()
        raw("PATCH", "/rest/v1/food_menu_items?id=eq." + filter(itemId) +
            "&store_id=eq." + filter(storeId),
            JSONObject().put("sold_out_until", if (soldOut) tomorrow else JSONObject.NULL))
    }

    /** Mirrors web sort update; updates are store-scoped, protected by database RLS. */
    fun reorderMenu(storeId: String, orderedIds: List<String>) {
        require(orderedIds.size == orderedIds.toSet().size) { "รายการเมนูซ้ำกัน" }
        orderedIds.forEachIndexed { index, id ->
            raw("PATCH", "/rest/v1/food_menu_items?id=eq." + filter(id) +
                "&store_id=eq." + filter(storeId), JSONObject().put("sort_order", index))
        }
    }

    fun saveCategoryOrder(storeId: String, names: List<String>) {
        val clean = names.map { it.trim() }.filter { it.isNotBlank() }.distinct()
        require(clean.isNotEmpty()) { "กรุณากำหนดหมวดหมู่อย่างน้อย 1 รายการ" }
        raw("PATCH", "/rest/v1/food_stores?id=eq." + filter(storeId),
            JSONObject().put("menu_category_order", JSONArray(clean)))
    }

    /** These APIs mirror web/lib/merchant-core.ts, merchant-campaigns.ts and merchant-ads.ts. */
    fun staff(storeId: String): JSONArray =
        rpc("merchant_staff_members", JSONObject().put("p_store_id", filter(storeId))) as JSONArray

    fun addStaff(storeId: String, username: String, role: String) {
        require(role in setOf("admin", "manager", "orders", "support", "delivery"))
        val clean = username.trim().removePrefix("@")
        require(clean.matches(Regex("[A-Za-z0-9_.]{1,40}"))) { "กรุณาระบุ @username ที่ถูกต้อง" }
        rpc("merchant_add_staff_by_username", JSONObject()
            .put("p_store_id", filter(storeId)).put("p_username", clean).put("p_role", role))
    }

    fun updateStaff(storeId: String, userId: String, role: String, active: Boolean) {
        require(role in setOf("admin", "manager", "orders", "support", "delivery"))
        rpc("merchant_update_staff_member", JSONObject().put("p_store_id", filter(storeId))
            .put("p_user_id", filter(userId)).put("p_role", role).put("p_active", active))
    }

    fun storeReviews(storeId: String): JSONObject =
        rpc("merchant_store_reviews", JSONObject().put("p_store_id", filter(storeId))
            .put("p_limit", 50)) as JSONObject

    fun replyReview(reviewId: String, reply: String) {
        require(reply.isNotBlank() && reply.length <= 1000) { "ข้อความตอบกลับไม่ถูกต้อง" }
        rpc("food_reply_store_review", JSONObject()
            .put("p_review_id", filter(reviewId)).put("p_reply", reply.trim()))
    }

    fun campaigns(storeId: String): JSONObject =
        rpc("merchant_food_campaigns", JSONObject().put("p_store_id", filter(storeId))) as JSONObject

    fun upsertCampaign(storeId: String, draft: JSONObject) {
        val kind = draft.optString("campaign_type")
        val scope = draft.optString("scope")
        require(kind in setOf("percentage", "fixed", "free_delivery")) { "ประเภทส่วนลดไม่ถูกต้อง" }
        require(scope in setOf("store", "items")) { "ขอบเขตส่วนลดไม่ถูกต้อง" }
        val name = draft.optString("name").trim()
        require(name.isNotEmpty() && name.length <= 80) { "กรุณากรอกชื่อโปรโมชัน" }
        val amount = draft.optDouble("discount_value")
        require(amount >= 0.0 && (kind != "percentage" || amount <= 100.0)) { "ส่วนลดไม่ถูกต้อง" }
        rpc("merchant_upsert_food_campaign", JSONObject()
            .put("p_store_id", filter(storeId))
            .put("p_name", name)
            .put("p_campaign_type", kind)
            .put("p_scope", if (kind == "free_delivery") "store" else scope)
            .put("p_discount_value", if (kind == "free_delivery") 0 else amount)
            .put("p_min_subtotal", draft.optDouble("min_subtotal", 0.0))
            .put("p_max_discount", draft.opt("max_discount") ?: JSONObject.NULL)
            .put("p_starts_at", draft.optString("starts_at").ifBlank {
                java.time.Instant.now().toString()
            })
            .put("p_ends_at", draft.opt("ends_at") ?: JSONObject.NULL)
            .put("p_usage_limit", draft.opt("usage_limit") ?: JSONObject.NULL)
            .put("p_item_ids", if (kind == "free_delivery" || scope == "store") JSONArray()
                else draft.optJSONArray("item_ids") ?: JSONArray())
            .put("p_campaign_id", draft.opt("id") ?: JSONObject.NULL))
    }

    fun campaignActive(storeId: String, campaignId: String, active: Boolean) {
        rpc("merchant_set_food_campaign_active", JSONObject()
            .put("p_store_id", filter(storeId))
            .put("p_campaign_id", filter(campaignId)).put("p_active", active))
    }

    fun deleteCampaign(storeId: String, campaignId: String) {
        rpc("merchant_delete_food_campaign", JSONObject()
            .put("p_store_id", filter(storeId)).put("p_campaign_id", filter(campaignId)))
    }

    fun platformCampaigns(storeId: String): JSONObject =
        rpc("merchant_platform_campaigns", JSONObject().put("p_store_id", filter(storeId))) as JSONObject

    fun platformCampaignJoin(storeId: String, campaignId: String, join: Boolean) {
        rpc(if (join) "merchant_join_platform_campaign" else "merchant_leave_platform_campaign",
            JSONObject().put("p_store_id", filter(storeId)).put("p_campaign_id", filter(campaignId)))
    }

    fun advertising(storeId: String): JSONObject =
        rpc("merchant_ad_account", JSONObject().put("p_store_id", filter(storeId))) as JSONObject

    fun adActive(storeId: String, active: Boolean) {
        rpc("merchant_set_ad_active", JSONObject().put("p_store_id", filter(storeId))
            .put("p_active", active))
    }

    fun stripeStatus(storeId: String): JSONObject =
        rpc("merchant_stripe_status", JSONObject().put("p_store_id", filter(storeId))) as JSONObject

    fun notifications(merchantAccountId: String): JSONArray =
        getArray("/rest/v1/merchant_notifications?select=*&merchant_account_id=eq." +
            filter(merchantAccountId) + "&order=created_at.desc&limit=50")

    fun markNotificationRead(notificationId: String) {
        raw("PATCH", "/rest/v1/merchant_notifications?id=eq." + filter(notificationId),
            JSONObject().put("read_at", java.time.Instant.now().toString()))
    }

    fun markAllNotificationsRead(merchantAccountId: String) {
        raw("PATCH", "/rest/v1/merchant_notifications?merchant_account_id=eq." +
            filter(merchantAccountId) + "&read_at=is.null",
            JSONObject().put("read_at", java.time.Instant.now().toString()))
    }

    fun sendTestNotification(storeId: String) {
        rpc("merchant_send_test_notification", JSONObject().put("p_store_id", filter(storeId)))
    }

    fun publishStore(storeId: String, publish: Boolean) {
        if (publish) {
            val current = rpc("merchant_store_readiness",
                JSONObject().put("p_store_id", filter(storeId))) as JSONObject
            require(current.optBoolean("ready")) { "ร้านยังไม่ผ่านเกณฑ์ความพร้อมเผยแพร่" }
        }
        updateStore(storeId, JSONObject().put("is_published", publish))
    }

    fun updateStore(storeId: String, patch: JSONObject) {
        val allow = setOf("name","description","phone","address","business_hours","business_schedule",
            "special_closed_dates","temporary_closed_until","temporary_closed_reason",
            "prep_time_min_minutes","prep_time_max_minutes","menu_category_order",
            "delivery_area","delivery_fee","minimum_order","latitude","longitude",
            "pickup_latitude","pickup_longitude","pickup_note","delivery_radius_km",
            "delivery_base_km","delivery_fee_per_km","promptpay_name","promptpay_id",
            "bank_name","bank_account_name","bank_account_number","payment_qr_path",
            "scheduled_orders_enabled","scheduled_min_notice_minutes","scheduled_max_days",
            "tax_invoice_enabled","tax_legal_name","tax_id","tax_branch","tax_address",
            "logo_path","cover_path","is_open","is_published")
        require(patch.keys().asSequence().all { it in allow }) { "ฟิลด์ข้อมูลร้านไม่ถูกต้อง" }
        raw("PATCH", "/rest/v1/food_stores?id=eq." + filter(storeId), patch)
    }
}
