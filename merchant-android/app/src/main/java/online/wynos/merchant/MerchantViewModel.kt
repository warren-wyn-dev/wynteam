package online.wynos.merchant

import android.app.Application
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

enum class MerchantPage { HOME, ORDERS, MENU, MORE, REPORTS, FINANCE, STORE, HISTORY }

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
    val history: List<JSONObject> = emptyList(),
    val hasMoreOrders: Boolean = false,
    val selectedOrder: JSONObject? = null,
    val selectedMenu: JSONObject? = null,
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
        val menu = if (selected != null) api.menu(storeId).asObjects() else emptyList()
        val orderRows = if (selected != null) api.orders(storeId).asObjects() else emptyList()
        val sales = if (selected != null) runCatching { api.sales(storeId) }.getOrNull() else null
        state = state.copy(
            signedIn = true, stores = stores, store = selected,
            menu = menu, orders = orderRows.take(100), sales = sales,
            hasMoreOrders = orderRows.size > 100,
            selectedOrder = state.selectedOrder?.let { prior ->
                orderRows.find { it.optString("id") == prior.optString("id") } },
        )
    }

    fun selectStore(storeId: String) {
        prefs.edit().putString("selected_store", storeId).apply()
        refresh()
    }

    fun openPage(page: MerchantPage) {
        state = state.copy(page = page, error = "", selectedMenu = null)
        if (page == MerchantPage.HISTORY) loadHistory()
        if (page == MerchantPage.FINANCE) loadFinance()
    }

    fun orderFilter(filter: String) {
        if (filter in setOf("new", "cooking", "delivery", "done"))
            state = state.copy(orderFilter = filter)
    }

    fun selectOrder(order: JSONObject?) { state = state.copy(selectedOrder = order) }
    fun selectMenu(item: JSONObject?) { state = state.copy(selectedMenu = item) }

    fun actionOrder(order: JSONObject) {
        val next = when (order.optString("status")) {
            "pending_acceptance" -> if (order.optString("payment_status") == "paid") "preparing" else return
            "preparing" -> "ready_for_delivery"
            "ready_for_delivery" -> "out_for_delivery"
            else -> return
        }
        execute("บันทึกสถานะออเดอร์แล้ว") {
            api.transition(order.getString("id"), next)
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

    fun saveMenu(item: JSONObject) {
        val storeId = state.store?.optString("id") ?: return
        execute("บันทึกเมนูแล้ว") {
            api.saveMenu(storeId, item)
            loadSnapshot()
            state = state.copy(selectedMenu = null)
        }
    }

    fun saveStore(patch: JSONObject) {
        val storeId = state.store?.optString("id") ?: return
        execute("บันทึกข้อมูลร้านแล้ว") {
            api.updateStore(storeId, patch)
            loadSnapshot()
        }
    }

    fun loadHistory() {
        val storeId = state.store?.optString("id") ?: return
        execute {
            state = state.copy(history = api.history(storeId).asObjects())
        }
    }

    fun loadFinance() {
        val storeId = state.store?.optString("id") ?: return
        execute {
            val today = LocalDate.now(ZoneId.of("Asia/Bangkok"))
            state = state.copy(finance = api.finance(storeId, today.withDayOfMonth(1), today))
        }
    }

    /** Financial numbers are ALWAYS calculated server-side, never from the first orders page. */
    fun reloadSales() {
        val storeId = state.store?.optString("id") ?: return
        execute { state = state.copy(sales = api.sales(storeId)) }
    }
}
