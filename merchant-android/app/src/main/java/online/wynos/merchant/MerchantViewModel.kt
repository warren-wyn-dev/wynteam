package online.wynos.merchant

import android.app.Application
import android.net.Uri
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneId

enum class MerchantPage { HOME, ORDERS, MENU, MORE, REPORTS, FINANCE, STORE, HISTORY, FEEDBACK, PROMOTIONS, CAMPAIGNS, ADS, NOTIFICATIONS, STAFF, HELP }

data class MerchantState(
    val configured: Boolean = true,
    val signedIn: Boolean = false,
    val busy: Boolean = false,
    val error: String = "",
    val notice: String = "",
    val page: MerchantPage = MerchantPage.HOME,
    val orderFilter: String = "new",
    val stores: List<JSONObject> = emptyList(),
    val store: JSONObject? = null,
    val orders: List<JSONObject> = emptyList(),
    val menu: List<JSONObject> = emptyList(),
    val sales: JSONObject? = null,
    val finance: JSONObject? = null,
    val financeFrom: String = "",
    val financeTo: String = "",
    val history: List<JSONObject> = emptyList(),
    val historyStatus: String = "all",
    val historySearch: String = "",
    val historyDays: Int? = null,
    val historyHasMore: Boolean = false,
    val hasMoreOrders: Boolean = false,
    val selectedOrder: JSONObject? = null,
    val selectedMenu: JSONObject? = null,
    val readiness: JSONObject? = null,
    val audit: List<JSONObject> = emptyList(),
    val staff: List<JSONObject> = emptyList(),
    val reviews: JSONObject? = null,
    val promotions: JSONObject? = null,
    val platformCampaigns: JSONObject? = null,
    val ads: JSONObject? = null,
    val stripeStatus: JSONObject? = null,
    val notifications: List<JSONObject> = emptyList(),
    val slipBitmap: Bitmap? = null,
    val slipPreviewOrderId: String? = null,
    val slipPreviewPath: String? = null,
)

fun JSONArray.asObjects(): List<JSONObject> =
    (0 until length()).mapNotNull { optJSONObject(it) }

fun isRecentCompleted(order: JSONObject, now: Long = System.currentTimeMillis()): Boolean {
    val timestamp = when (order.optString("status")) {
        "delivered" -> order.optString("delivered_at")
        "cancelled" -> order.optString("cancelled_at")
        else -> return false
    }
    val instant = runCatching { java.time.Instant.parse(timestamp) }.getOrNull() ?: return false
    val age = now - instant.toEpochMilli()
    return age >= 0 && age < 86_400_000
}

class MerchantViewModel(application: Application) : AndroidViewModel(application) {
    private val api = MerchantApi(application)
    private val prefs = application.getSharedPreferences("merchant_preferences", 0)
    var state by mutableStateOf(MerchantState(configured = api.configured))
        private set

    init {
        if (api.hasSession && api.configured) refresh()
    }

    /** Network calls stay off main thread and never expose credentials to Compose state. */
    private fun execute(message: String = "", work: () -> Unit) {
        if (state.busy) return
        state = state.copy(busy = true, error = "", notice = "")
        viewModelScope.launch {
            try {
                withContext(Dispatchers.IO) { work() }
                if (message.isNotBlank()) state = state.copy(notice = message)
            } catch (error: Exception) {
                state = state.copy(error = error.message ?: "ดำเนินการไม่สำเร็จ")
            } finally {
                state = state.copy(busy = false)
            }
        }
    }

    fun signIn(email: String, password: String) = execute {
        api.signIn(email, password)
        loadSnapshot()
    }

    fun signOut() = execute {
        api.signOut()
        state = MerchantState(configured = api.configured)
    }

    fun refresh() = execute {
        api.verifyMerchantAccess()
        loadSnapshot()
    }

    private fun loadSnapshot() {
        val stores = api.stores().asObjects()
        val preferred = prefs.getString("selected_store", null)
        val selected = stores.find { it.optString("id") == preferred } ?: stores.firstOrNull()
        val storeId = selected?.optString("id").orEmpty()
        val changingStore = storeId != state.store?.optString("id").orEmpty()
        val menu = if (selected != null) api.menu(storeId).asObjects() else emptyList()
        val orderRows = if (selected != null) api.orders(storeId).asObjects() else emptyList()
        val sales = if (selected != null) runCatching { api.sales(storeId) }.getOrNull() else null
        state = state.copy(
            signedIn = true, stores = stores, store = selected,
            menu = menu, orders = orderRows.take(100), sales = sales,
            hasMoreOrders = orderRows.size > 100,
            finance = if (changingStore) null else state.finance,
            financeFrom = if (changingStore) "" else state.financeFrom,
            financeTo = if (changingStore) "" else state.financeTo,
            readiness = if (changingStore) null else state.readiness,
            audit = if (changingStore) emptyList() else state.audit,
            staff = if (changingStore) emptyList() else state.staff,
            reviews = if (changingStore) null else state.reviews,
            promotions = if (changingStore) null else state.promotions,
            platformCampaigns = if (changingStore) null else state.platformCampaigns,
            ads = if (changingStore) null else state.ads,
            stripeStatus = if (changingStore) null else state.stripeStatus,
            notifications = if (changingStore) emptyList() else state.notifications,
            history = if (changingStore) emptyList() else state.history,
            historyHasMore = if (changingStore) false else state.historyHasMore,
            slipBitmap = if (changingStore) null else state.slipBitmap,
            slipPreviewOrderId = if (changingStore) null else state.slipPreviewOrderId,
            slipPreviewPath = if (changingStore) null else state.slipPreviewPath,
            selectedOrder = state.selectedOrder?.let { prior ->
                orderRows.find { it.optString("id") == prior.optString("id") } },
        )
    }

    fun selectStore(storeId: String) {
        if (state.busy) return
        prefs.edit().putString("selected_store", storeId).apply()
        refresh()
    }

    fun openPage(page: MerchantPage) {
        state = state.copy(page = page, error = "", selectedMenu = null)
        if (page == MerchantPage.HISTORY) loadHistory()
        if (page == MerchantPage.FINANCE) loadFinance()
        if (page == MerchantPage.STORE) loadStoreDetails()
        if (page in setOf(MerchantPage.FEEDBACK, MerchantPage.PROMOTIONS, MerchantPage.CAMPAIGNS,
                MerchantPage.ADS, MerchantPage.NOTIFICATIONS, MerchantPage.STAFF)) loadExtras(page)
    }

    fun orderFilter(filter: String) {
        if (filter in setOf("new", "cooking", "delivery", "done"))
            state = state.copy(orderFilter = filter)
    }

    fun selectOrder(order: JSONObject?) {
        state = state.copy(
            selectedOrder = order, slipBitmap = null,
            slipPreviewOrderId = null, slipPreviewPath = null
        )
        if (order?.optString("payment_status") == "submitted" &&
            order.optString("payment_slip_path").isNotBlank()) previewSlip(order)
    }

    private fun previewSlip(order: JSONObject) {
        val id = order.optString("id")
        val path = order.optString("payment_slip_path")
        execute {
            val bytes = api.loadPrivateImage(path)
            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
            var sample = 1
            while (options.outHeight / sample > 1700 || options.outWidth / sample > 1700) sample *= 2
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size,
                BitmapFactory.Options().apply { inSampleSize = sample })
                ?: throw IllegalArgumentException("ไม่สามารถแสดงรูปสลิปได้")
            if (state.selectedOrder?.optString("id") == id &&
                state.selectedOrder?.optString("payment_slip_path") == path) {
                state = state.copy(slipBitmap = bitmap, slipPreviewOrderId = id, slipPreviewPath = path)
            }
        }
    }

    /** Explicitly reviewed payment-slip image required for the submitted flow. */
    fun approveSlipAndAccept(order: JSONObject, reviewed: Boolean, etaMinutes: Int) {
        val orderId = order.optString("id")
        val path = order.optString("payment_slip_path")
        if (!reviewed || state.slipBitmap == null || state.slipPreviewOrderId != orderId ||
            state.slipPreviewPath != path || state.selectedOrder?.optString("id") != orderId ||
            order.optString("status") != "pending_acceptance" ||
            order.optString("payment_status") != "submitted") {
            state = state.copy(error = "กรุณาเปิดดูสลิปและตรวจเงินเข้าก่อนยืนยัน")
            return
        }
        execute("ยืนยันเงินและรับออเดอร์แล้ว") {
            try {
                api.setPaymentStatusWithNote(orderId, "paid")
                api.transition(orderId, "preparing", etaMinutes)
            } finally { loadSnapshot() }
        }
    }

    fun rejectSlip(order: JSONObject) {
        if (order.optString("payment_status") != "submitted") return
        execute("แจ้งว่าสลิปมีปัญหาแล้ว") {
            try {
                api.setPaymentStatusWithNote(order.getString("id"), "issue", "กรุณาตรวจสอบหรือส่งสลิปใหม่")
            } finally { loadSnapshot() }
        }
    }

    fun completeOrder(order: JSONObject, method: String, locationNote: String, photo: Uri?) {
        if (order.optString("status") != "out_for_delivery" || photo == null) {
            state = state.copy(error = "กรุณาแนบรูปยืนยันการจัดส่ง")
            return
        }
        execute("ยืนยันส่งสำเร็จแล้ว") {
            try {
                val path = api.uploadDeliveryImage(order.getString("id"), photo)
                api.completeDelivery(order.getString("id"), method, locationNote, path)
            } finally { loadSnapshot() }
        }
    }
    fun selectMenu(item: JSONObject?) { state = state.copy(selectedMenu = item) }

    fun actionOrder(order: JSONObject, etaMinutes: Int? = null) {
        val next = when (order.optString("status")) {
            "pending_acceptance" -> if (order.optString("payment_status") == "paid") "preparing" else return
            "preparing" -> "ready_for_delivery"
            "ready_for_delivery" -> "out_for_delivery"
            else -> return
        }
        execute("บันทึกสถานะออเดอร์แล้ว") {
            api.transition(order.getString("id"), next, etaMinutes)
            loadSnapshot()
        }
    }

    fun setAvailability(item: JSONObject, value: Boolean) {
        val storeId = state.store?.optString("id") ?: return
        execute("อัปเดตสถานะเมนูแล้ว") {
            api.setMenuAvailability(storeId, item.getString("id"), value)
            loadSnapshot()
        }
    }

    fun saveMenu(item: JSONObject, imageUri: Uri? = null) {
        val storeId = state.store?.optString("id") ?: return
        execute("บันทึกเมนูแล้ว") {
            if (imageUri != null) item.put("image_path", api.uploadMenuImage(storeId, imageUri))
            api.saveMenu(storeId, item)
            loadSnapshot()
            state = state.copy(selectedMenu = null)
        }
    }

    fun deleteMenu(item: JSONObject) {
        val storeId = state.store?.optString("id") ?: return
        execute("ลบเมนูแล้ว") {
            api.deleteMenu(storeId, item.getString("id"))
            loadSnapshot()
            state = state.copy(selectedMenu = null)
        }
    }

    fun soldOutToday(item: JSONObject, soldOut: Boolean) {
        val storeId = state.store?.optString("id") ?: return
        execute(if (soldOut) "ทำเครื่องหมายหมดวันนี้แล้ว" else "เปิดขายวันนี้แล้ว") {
            api.soldOutToday(storeId, item.getString("id"), soldOut)
            loadSnapshot()
        }
    }

    fun reorderMenu(ids: List<String>) {
        val storeId = state.store?.optString("id") ?: return
        execute("บันทึกลำดับเมนูแล้ว") {
            api.reorderMenu(storeId, ids)
            loadSnapshot()
        }
    }

    fun saveCategoryChanges(rows: List<CategoryDraft>) {
        val id = state.store?.optString("id") ?: return
        val clean = rows.map { it.name.trim() }
        if (clean.isEmpty() || clean.any { it.isBlank() } ||
            clean.map { it.lowercase() }.toSet().size != clean.size) {
            state = state.copy(error = "กรุณาตรวจชื่อหมวดหมู่ ไม่ให้ว่างหรือซ้ำกัน")
            return
        }
        execute("บันทึกหมวดหมู่แล้ว") {
            for (row in rows) {
                if (row.original != null && row.original != row.name.trim()) {
                    api.renameMenuCategory(id, row.original, row.name, state.menu)
                }
            }
            api.saveCategoryOrder(id, clean)
            loadSnapshot()
        }
    }

    fun saveCategoryOrder(categories: List<String>) {
        val storeId = state.store?.optString("id") ?: return
        execute("บันทึกลำดับหมวดหมู่แล้ว") {
            api.saveCategoryOrder(storeId, categories)
            loadSnapshot()
        }
    }

    fun saveStore(patch: JSONObject) {
        val storeId = state.store?.optString("id") ?: return
        execute("บันทึกข้อมูลร้านแล้ว") {
            api.updateStore(storeId, patch)
            loadSnapshot()
        }
    }

    fun loadStoreDetails() {
        val storeId = state.store?.optString("id") ?: return
        execute {
            val readiness = runCatching { api.readiness(storeId) }.getOrNull()
            val audit = runCatching { api.audit(storeId).asObjects() }.getOrDefault(emptyList())
            state = state.copy(readiness = readiness, audit = audit)
        }
    }

    /** Backend-backed native merchant tools; Supabase RLS and RPC roles still enforce permissions. */
    fun loadExtras(page: MerchantPage = state.page) {
        val store = state.store ?: return
        val storeId = store.optString("id")
        val accountId = store.optString("merchant_account_id")
        execute {
            when (page) {
                MerchantPage.FEEDBACK -> state = state.copy(reviews = api.storeReviews(storeId))
                MerchantPage.PROMOTIONS -> state = state.copy(promotions = api.campaigns(storeId))
                MerchantPage.CAMPAIGNS -> state = state.copy(platformCampaigns = api.platformCampaigns(storeId))
                MerchantPage.ADS -> state = state.copy(ads = api.advertising(storeId))
                MerchantPage.STAFF -> state = state.copy(staff = api.staff(storeId).asObjects())
                MerchantPage.NOTIFICATIONS -> if (accountId.isNotBlank() && accountId != "null")
                    state = state.copy(notifications = api.notifications(accountId).asObjects())
                else -> Unit
            }
        }
    }

    fun addStaff(username: String, role: String) {
        val id = state.store?.optString("id") ?: return
        execute("เพิ่มพนักงานแล้ว") {
            api.addStaff(id, username, role)
            state = state.copy(staff = api.staff(id).asObjects())
        }
    }

    fun updateStaff(member: JSONObject, role: String, active: Boolean) {
        val id = state.store?.optString("id") ?: return
        execute("อัปเดตพนักงานแล้ว") {
            api.updateStaff(id, member.getString("user_id"), role, active)
            state = state.copy(staff = api.staff(id).asObjects())
        }
    }

    fun replyReview(review: JSONObject, reply: String) {
        val id = state.store?.optString("id") ?: return
        execute("ตอบกลับรีวิวแล้ว") {
            api.replyReview(review.getString("id"), reply)
            state = state.copy(reviews = api.storeReviews(id))
        }
    }

    fun savePromotion(draft: JSONObject) {
        val id = state.store?.optString("id") ?: return
        execute("บันทึกโปรโมชันแล้ว") {
            api.upsertCampaign(id, draft)
            state = state.copy(promotions = api.campaigns(id))
        }
    }

    fun promotionActive(promotion: JSONObject, active: Boolean) {
        val id = state.store?.optString("id") ?: return
        execute("เปลี่ยนสถานะโปรโมชันแล้ว") {
            api.campaignActive(id, promotion.getString("id"), active)
            state = state.copy(promotions = api.campaigns(id))
        }
    }

    fun deletePromotion(promotion: JSONObject) {
        val id = state.store?.optString("id") ?: return
        execute("ลบโปรโมชันแล้ว") {
            api.deleteCampaign(id, promotion.getString("id"))
            state = state.copy(promotions = api.campaigns(id))
        }
    }

    fun joinPlatformCampaign(campaign: JSONObject, join: Boolean) {
        val id = state.store?.optString("id") ?: return
        execute(if (join) "เข้าร่วมแคมเปญแล้ว" else "ออกจากแคมเปญแล้ว") {
            api.platformCampaignJoin(id, campaign.getString("id"), join)
            state = state.copy(platformCampaigns = api.platformCampaigns(id))
        }
    }

    fun adActive(active: Boolean) {
        val id = state.store?.optString("id") ?: return
        execute("บันทึกสถานะโฆษณาแล้ว") {
            api.adActive(id, active)
            state = state.copy(ads = api.advertising(id))
        }
    }

    fun markNotificationRead(notificationId: String) {
        val account = state.store?.optString("merchant_account_id")?.takeIf { it != "null" } ?: return
        execute {
            api.markNotificationRead(notificationId)
            state = state.copy(notifications = api.notifications(account).asObjects())
        }
    }

    fun markAllNotificationsRead() {
        val account = state.store?.optString("merchant_account_id")?.takeIf { it != "null" } ?: return
        execute("อ่านทั้งหมดแล้ว") {
            api.markAllNotificationsRead(account)
            state = state.copy(notifications = api.notifications(account).asObjects())
        }
    }

    fun sendTestNotification() {
        val id = state.store?.optString("id") ?: return
        execute("ส่งการแจ้งเตือนทดสอบแล้ว") { api.sendTestNotification(id) }
    }

    fun togglePublished(published: Boolean) {
        val id = state.store?.optString("id") ?: return
        execute("อัปเดตการเผยแพร่ร้านแล้ว") {
            api.publishStore(id, published)
            loadSnapshot()
            state = state.copy(readiness = api.readiness(id), audit = api.audit(id).asObjects())
        }
    }

    fun loadStripeStatus() {
        val id = state.store?.optString("id") ?: return
        execute { state = state.copy(stripeStatus = api.stripeStatus(id)) }
    }

    fun saveStoreImage(kind: String, uri: Uri?) {
        if (kind !in setOf("logo", "cover", "payment")) return
        val id = state.store?.optString("id") ?: return
        execute("อัปเดตรูปร้านแล้ว") {
            val path = if (uri == null) JSONObject.NULL else api.uploadStoreImage(id, kind, uri)
            val field = if (kind == "payment") "payment_qr_path" else kind + "_path"
            api.updateStore(id, JSONObject().put(field, path))
            loadSnapshot()
        }
    }

    fun adTopup(amount: Double, uri: Uri?) {
        val id = state.store?.optString("id") ?: return
        if (uri == null || !amount.isFinite() || amount < (state.ads?.optDouble("min_topup") ?: Double.MAX_VALUE)) {
            state = state.copy(error = "กรุณาแนบสลิปและเติมเครดิตให้ถึงขั้นต่ำ")
            return
        }
        execute("ส่งสลิปเติมเครดิตแล้ว กรุณารอ WYNOS ตรวจสอบ") {
            api.uploadAdTopup(id, amount, uri)
            state = state.copy(ads = api.advertising(id))
        }
    }

    fun setHistoryStatus(value: String) {
        if (value !in setOf("all", "delivered", "cancelled")) return
        state = state.copy(historyStatus = value)
        loadHistory()
    }

    fun setHistoryDays(value: Int?) {
        if (value != null && value !in setOf(7, 30)) return
        state = state.copy(historyDays = value)
        loadHistory()
    }

    fun setHistorySearch(value: String) { state = state.copy(historySearch = value.take(40)) }

    fun loadHistory(more: Boolean = false) {
        val storeId = state.store?.optString("id") ?: return
        execute {
            val offset = if (more) state.history.size else 0
            val rows = api.history(storeId, state.historyStatus,
                state.historySearch, state.historyDays, offset).asObjects()
            state = state.copy(
                history = (if (more) state.history else emptyList()) + rows.take(30),
                historyHasMore = rows.size > 30
            )
        }
    }

    fun setFinanceRange(from: String, to: String) {
        val start = runCatching { LocalDate.parse(from) }.getOrNull()
        val end = runCatching { LocalDate.parse(to) }.getOrNull()
        if (start == null || end == null || end.isBefore(start) ||
            java.time.temporal.ChronoUnit.DAYS.between(start, end) > 365) {
            state = state.copy(error = "กรุณาเลือกช่วงวันที่ถูกต้อง ไม่เกิน 366 วัน")
            return
        }
        state = state.copy(financeFrom = from, financeTo = to)
        loadFinance()
    }

    fun loadFinance() {
        val storeId = state.store?.optString("id") ?: return
        execute {
            val today = LocalDate.now(ZoneId.of("Asia/Bangkok"))
            val from = runCatching { LocalDate.parse(state.financeFrom) }.getOrNull() ?: today
            val to = runCatching { LocalDate.parse(state.financeTo) }.getOrNull() ?: today
            val summary = api.finance(storeId, from, to)
            val stripe = runCatching { api.stripeStatus(storeId) }.getOrNull()
            state = state.copy(finance = summary, financeFrom = from.toString(),
                financeTo = to.toString(), stripeStatus = stripe)
        }
    }

    /** Financial numbers are ALWAYS calculated server-side, never from the first orders page. */
    fun reloadSales() {
        val storeId = state.store?.optString("id") ?: return
        execute { state = state.copy(sales = api.sales(storeId)) }
    }
}
