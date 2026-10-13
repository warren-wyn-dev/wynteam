package online.wynos.food.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import online.wynos.food.data.FoodGateway
import online.wynos.food.data.FoodStore
import online.wynos.food.data.FoodHomeBanner
import online.wynos.food.data.FoodCartDraft
import online.wynos.food.data.FoodMenu
import online.wynos.food.data.FoodOrderSummary
import online.wynos.food.data.FoodCustomerAddress
import online.wynos.food.data.FoodServerQuote
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
    val banners: List<FoodHomeBanner> = emptyList(),
    val cart: FoodCartDraft = FoodCartDraft(),
    val cartError: Boolean = false,
    val orders: List<FoodOrderSummary> = emptyList(),
    val ordersLoading: Boolean = false,
    val ordersFailed: Boolean = false,
    val addresses: List<FoodCustomerAddress> = emptyList(),
    val addressesLoading: Boolean = false,
    val addressesFailed: Boolean = false,
    val selectedAddressId: String? = null,
    val quote: FoodServerQuote? = null,
    val quoteLoading: Boolean = false,
    val quoteFailed: Boolean = false,
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
                val banners = try { gateway.homeBanners() } catch (cancel: CancellationException) {
                    throw cancel
                } catch (_: Exception) { emptyList() }
                mutableState.update { it.copy(banners = banners) }
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
                if (email != null) {
                    refreshOrders()
                    refreshAddresses()
                }
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
                refreshAddresses()
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
                mutableState.update { it.copy(
                    accountBusy = false, accountEmail = null, orders = emptyList(),
                    cart = FoodCartDraft(), addresses = emptyList(), selectedAddressId = null,
                    quote = null, quoteLoading = false, quoteFailed = false,
                ) }
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
    fun addToCart(store: FoodStore, menu: FoodMenu, selected: Map<String, Set<String>>, quantity: Int, note: String): Boolean {
        return try {
            val next = mutableState.value.cart.add(store, menu, selected, quantity, note)
            mutableState.update { it.copy(cart = next, cartError = false, quote = null, quoteFailed = false) }
            true
        } catch (_: IllegalArgumentException) {
            mutableState.update { it.copy(cartError = true) }
            false
        }
    }

    fun clearCart() {
        mutableState.update { it.copy(cart = FoodCartDraft(), cartError = false, quote = null, quoteFailed = false) }
    }

    fun refreshAddresses() {
        if (!gateway.configured || mutableState.value.accountEmail == null) return
        viewModelScope.launch {
            mutableState.update { it.copy(addressesLoading = true, addressesFailed = false) }
            try {
                val addresses = gateway.addresses()
                mutableState.update { state ->
                    val selected = state.selectedAddressId?.takeIf { id -> addresses.any { it.id == id } }
                        ?: addresses.find { it.isDefault }?.id ?: addresses.firstOrNull()?.id
                    state.copy(
                        addresses = addresses, addressesLoading = false,
                        selectedAddressId = selected, quote = null, quoteFailed = false,
                    )
                }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.update { it.copy(addressesLoading = false, addressesFailed = true) }
            }
        }
    }

    fun selectAddress(id: String?) {
        mutableState.update { state ->
            if (id != null && state.addresses.none { it.id == id }) state else state.copy(
                selectedAddressId = id, quote = null, quoteFailed = false,
            )
        }
    }

    fun requestServerQuote() {
        val state = mutableState.value
        if (!gateway.configured || state.accountEmail == null ||
            state.cart.lines.isEmpty() || state.quoteLoading) return
        val draft = state.cart
        val addressId = state.selectedAddressId
        val address = state.addresses.firstOrNull { it.id == addressId }
        viewModelScope.launch {
            mutableState.update { it.copy(quoteLoading = true, quoteFailed = false, quote = null) }
            try {
                val serverQuote = gateway.quote(draft, address)
                mutableState.update { current ->
                    if (current.cart != draft || current.selectedAddressId != addressId ||
                        current.accountEmail == null) current.copy(quoteLoading = false)
                    else current.copy(quote = serverQuote, quoteLoading = false)
                }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.update { current ->
                    current.copy(quoteLoading = false, quoteFailed = true)
                }
            }
        }
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
