package online.wynos.merchant

import android.content.Context
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
    fun history(storeId: String): JSONArray =
        getArray("/rest/v1/food_orders?select=*,food_order_items(*)&store_id=eq." +
            filter(storeId) + "&status=in.(delivered,cancelled)&order=created_at.desc&limit=30")

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
        if (id != null) raw("PATCH", "/rest/v1/food_menu_items?id=eq." + filter(id) +
            "&store_id=eq." + filter(storeId), payload)
        else raw("POST", "/rest/v1/food_menu_items", payload)
    }

    fun updateStore(storeId: String, patch: JSONObject) {
        val allow = setOf("name","description","phone","address","business_hours","delivery_area",
            "delivery_fee","minimum_order","is_open","is_published","promptpay_name","promptpay_id",
            "bank_name","bank_account_name","bank_account_number")
        require(patch.keys().asSequence().all { it in allow }) { "ฟิลด์ข้อมูลร้านไม่ถูกต้อง" }
        raw("PATCH", "/rest/v1/food_stores?id=eq." + filter(storeId), patch)
    }
}
