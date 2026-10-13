package online.wynos.food.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import online.wynos.food.data.FoodGateway
import online.wynos.food.data.FoodStore
import online.wynos.food.data.FoodCartDraft
import online.wynos.food.data.FoodMenu
import online.wynos.food.data.FoodOrderSummary
import online.wynos.food.data.SupabaseFoodGateway
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class FoodUiState(
    val configured: Boolean = false,
    val catalogLoading: Boolean = false,
    val catalogFailed: Boolean = false,
    val stores: List<FoodStore> = emptyList(),
    val cart: FoodCartDraft = FoodCartDraft(),
    val cartError: Boolean = false,
    val orders: List<FoodOrderSummary> = emptyList(),
    val ordersLoading: Boolean = false,
    val ordersFailed: Boolean = false,
    val accountLoading: Boolean = false,
    val accountBusy: Boolean = false,
    val accountEmail: String? = null,
    val accountFailed: Boolean = false,
    val resetEmailSent: Boolean = false,
)

class FoodViewModel(private val gateway: FoodGateway = SupabaseFoodGateway()) : ViewModel() {
    private val mutableState = MutableStateFlow(FoodUiState(configured = gateway.configured))
    val uiState = mutableState.asStateFlow()

    init {
        if (gateway.configured) {
            refreshCatalog()
            restoreAccount()
        }
    }

    fun refreshCatalog() {
        if (!gateway.configured) return
        viewModelScope.launch {
            mutableState.update { it.copy(catalogLoading = true, catalogFailed = false) }
            try {
                val stores = gateway.catalog()
                mutableState.update { it.copy(stores = stores, catalogLoading = false) }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.update { it.copy(catalogLoading = false, catalogFailed = true) }
            }
        }
    }

    private fun restoreAccount() {
        viewModelScope.launch {
            mutableState.update { it.copy(accountLoading = true, accountFailed = false) }
            try {
                val email = gateway.accountEmail()
                mutableState.update { it.copy(accountLoading = false, accountEmail = email) }
                if (email != null) refreshOrders()
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.update { it.copy(accountLoading = false, accountFailed = true) }
            }
        }
    }

    fun signIn(email: String, password: String) {
        if (!gateway.configured || email.isBlank() || password.isEmpty() || mutableState.value.accountBusy) return
        viewModelScope.launch {
            mutableState.update { it.copy(accountBusy = true, accountFailed = false, resetEmailSent = false) }
            try {
                val accountEmail = gateway.signIn(email.trim(), password)
                mutableState.update { it.copy(accountBusy = false, accountEmail = accountEmail) }
                refreshCatalog()
                refreshOrders()
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.update { it.copy(accountBusy = false, accountFailed = true) }
            }
        }
    }

    fun signOut() {
        if (mutableState.value.accountBusy) return
        viewModelScope.launch {
            mutableState.update { it.copy(accountBusy = true, accountFailed = false) }
            try {
                gateway.signOut()
                mutableState.update { it.copy(accountBusy = false, accountEmail = null, orders = emptyList(), cart = FoodCartDraft()) }
                refreshCatalog()
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.update { it.copy(accountBusy = false, accountFailed = true) }
            }
        }
    }

    fun requestPasswordReset(email: String) {
        if (!gateway.configured || email.isBlank() || mutableState.value.accountBusy) return
        viewModelScope.launch {
            mutableState.update { it.copy(accountBusy = true, accountFailed = false, resetEmailSent = false) }
            try {
                gateway.resetPassword(email.trim())
                mutableState.update { it.copy(accountBusy = false, resetEmailSent = true) }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.update { it.copy(accountBusy = false, accountFailed = true) }
            }
        }
    }
    fun addToCart(store: FoodStore, menu: FoodMenu, selected: Map<String, Set<String>>, quantity: Int): Boolean {
        return try {
            val next = mutableState.value.cart.add(store, menu, selected, quantity)
            mutableState.update { it.copy(cart = next, cartError = false) }
            true
        } catch (_: IllegalArgumentException) {
            mutableState.update { it.copy(cartError = true) }
            false
        }
    }

    fun clearCart() {
        mutableState.update { it.copy(cart = FoodCartDraft(), cartError = false) }
    }

    fun refreshOrders() {
        if (!gateway.configured || mutableState.value.accountEmail == null) return
        viewModelScope.launch {
            mutableState.update { it.copy(ordersLoading = true, ordersFailed = false) }
            try {
                val orders = gateway.orderHistory()
                mutableState.update { it.copy(orders = orders, ordersLoading = false) }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.update { it.copy(ordersLoading = false, ordersFailed = true) }
            }
        }
    }

}
