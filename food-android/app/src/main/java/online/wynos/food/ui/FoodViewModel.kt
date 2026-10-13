package online.wynos.food.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import online.wynos.food.data.FoodGateway
import online.wynos.food.data.FoodStore
import online.wynos.food.data.FoodHomeBanner
import online.wynos.food.data.FoodCartDraft
import online.wynos.food.data.FoodMenu
import online.wynos.food.data.FoodOrderSummary
import online.wynos.food.data.FoodOrderDetail
import online.wynos.food.data.FoodCustomerAddress
import online.wynos.food.data.FoodAddressDraft
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
    val selectedOrderId: String? = null,
    val orderDetail: FoodOrderDetail? = null,
    val orderDetailLoading: Boolean = false,
    val orderDetailFailed: Boolean = false,
    val addresses: List<FoodCustomerAddress> = emptyList(),
    val addressesLoading: Boolean = false,
    val addressesFailed: Boolean = false,
    val addressWritesEnabled: Boolean = false,
    val addressBusy: Boolean = false,
    val addressMutationError: Boolean = false,
    val addressMutationSuccess: Boolean = false,
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
    private val mutableState = MutableStateFlow(FoodUiState(configured = gateway.configured, addressWritesEnabled = gateway.addressWritesEnabled))
    val uiState = mutableState.asStateFlow()

    // A request must belong to the currently active account AND current input generation.
    // A matching email is not sufficient: the user might sign out and sign back in.
    private var accountGeneration = 0L
    private var addressGeneration = 0L
    private var orderGeneration = 0L
    private var orderDetailGeneration = 0L
    private var quoteGeneration = 0L

    private fun invalidateQuote() {
        quoteGeneration++
        mutableState.update {
            it.copy(quote = null, quoteLoading = false, quoteFailed = false)
        }
    }

    private fun invalidateAccountRequests() {
        accountGeneration++
        addressGeneration++
        orderGeneration++
        orderDetailGeneration++
        mutableState.update { it.copy(selectedOrderId = null, orderDetail = null, orderDetailLoading = false, orderDetailFailed = false) }
        invalidateQuote()
    }

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
        val generation = accountGeneration
        mutableState.update { it.copy(accountLoading = true, accountFailed = false) }
        viewModelScope.launch {
            try {
                val email = gateway.accountEmail()
                if (generation != accountGeneration) return@launch
                mutableState.update { it.copy(accountLoading = false, accountEmail = email) }
                if (email != null) {
                    refreshOrders()
                    refreshAddresses()
                }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                if (generation == accountGeneration) {
                    mutableState.update { it.copy(accountLoading = false, accountFailed = true) }
                }
            }
        }
    }

    fun signIn(email: String, password: String) {
        if (!gateway.configured || email.isBlank() || password.isEmpty() || mutableState.value.accountBusy) return
        invalidateAccountRequests()
        val generation = accountGeneration
        mutableState.update {
            it.copy(accountBusy = true, accountFailed = false, resetEmailSent = false,
                accountLoading = false, orders = emptyList(), addresses = emptyList(),
                ordersLoading = false, addressesLoading = false, selectedAddressId = null,
                selectedOrderId = null, orderDetail = null, orderDetailLoading = false, orderDetailFailed = false)
        }
        viewModelScope.launch {
            try {
                val signedInEmail = gateway.signIn(email.trim(), password)
                if (generation != accountGeneration) return@launch
                mutableState.update { it.copy(accountBusy = false, accountEmail = signedInEmail) }
                refreshCatalog()
                if (signedInEmail != null) {
                    refreshOrders()
                    refreshAddresses()
                }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                if (generation == accountGeneration) {
                    mutableState.update { it.copy(accountBusy = false, accountFailed = true) }
                }
            }
        }
    }

    fun signOut() {
        if (mutableState.value.accountBusy) return
        invalidateAccountRequests()
        val generation = accountGeneration
        mutableState.update { it.copy(accountBusy = true, accountFailed = false) }
        viewModelScope.launch {
            try {
                gateway.signOut()
                if (generation != accountGeneration) return@launch
                mutableState.update { it.copy(
                    accountBusy = false, accountEmail = null, accountLoading = false,
                    orders = emptyList(), ordersLoading = false, ordersFailed = false,
                    selectedOrderId = null, orderDetail = null, orderDetailLoading = false, orderDetailFailed = false,
                    cart = FoodCartDraft(), addresses = emptyList(), addressesLoading = false,
                    addressesFailed = false, selectedAddressId = null,
                    addressBusy = false, addressMutationError = false, addressMutationSuccess = false,
                    quote = null, quoteLoading = false, quoteFailed = false,
                ) }
                refreshCatalog()
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                if (generation == accountGeneration) {
                    mutableState.update { it.copy(accountBusy = false, accountFailed = true) }
                }
            }
        }
    }

    fun requestPasswordReset(email: String) {
        if (!gateway.configured || email.isBlank() || mutableState.value.accountBusy) return
        mutableState.update { it.copy(accountBusy = true, accountFailed = false, resetEmailSent = false) }
        viewModelScope.launch {
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
            invalidateQuote()
            mutableState.update { it.copy(cart = next, cartError = false) }
            true
        } catch (_: IllegalArgumentException) {
            mutableState.update { it.copy(cartError = true) }
            false
        }
    }

    fun updateCartLine(identity: String, quantity: Int) {
        try {
            val next = mutableState.value.cart.withQuantity(identity, quantity)
            invalidateQuote()
            mutableState.update { it.copy(cart = next, cartError = false) }
        } catch (_: IllegalArgumentException) {
            mutableState.update { it.copy(cartError = true) }
        }
    }

    fun clearCart() {
        invalidateQuote()
        mutableState.update { it.copy(cart = FoodCartDraft(), cartError = false) }
    }

    fun refreshAddresses() {
        if (!gateway.configured || mutableState.value.accountEmail == null) return
        val session = accountGeneration
        val generation = ++addressGeneration
        invalidateQuote() // Pricing must be rechecked if the stored pin or default has changed.
        mutableState.update { it.copy(addressesLoading = true, addressesFailed = false) }
        viewModelScope.launch {
            try {
                val addresses = gateway.addresses()
                if (session != accountGeneration || generation != addressGeneration) return@launch
                mutableState.update { state ->
                    if (state.accountEmail == null) return@update state
                    val selected = state.selectedAddressId?.takeIf { id -> addresses.any { it.id == id } }
                        ?: addresses.find { it.isDefault }?.id ?: addresses.firstOrNull()?.id
                    state.copy(addresses = addresses, addressesLoading = false, selectedAddressId = selected)
                }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                if (session == accountGeneration && generation == addressGeneration) {
                    mutableState.update { it.copy(addressesLoading = false, addressesFailed = true) }
                }
            }
        }
    }

    fun clearAddressMutationStatus() {
        mutableState.update { it.copy(addressMutationError = false, addressMutationSuccess = false) }
    }

    fun saveAddress(draft: FoodAddressDraft) {
        if (!gateway.addressWritesEnabled || !draft.validate() ||
            mutableState.value.accountEmail == null || mutableState.value.addressBusy) {
            mutableState.update { it.copy(addressMutationError = true, addressMutationSuccess = false) }
            return
        }
        val session = accountGeneration
        mutableState.update { it.copy(addressBusy = true, addressMutationError = false, addressMutationSuccess = false) }
        viewModelScope.launch {
            try {
                val id = gateway.saveAddress(draft)
                if (session != accountGeneration) return@launch
                // Old quote, addresses, and order-related delivery assumptions are no longer valid.
                invalidateQuote()
                mutableState.update {
                    it.copy(addressBusy = false, addressMutationSuccess = true, selectedAddressId = id)
                }
                refreshAddresses()
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                if (session == accountGeneration) {
                    mutableState.update {
                        it.copy(addressBusy = false, addressMutationError = true, addressMutationSuccess = false)
                    }
                }
            }
        }
    }

    fun deleteAddress(id: String) {
        if (!gateway.addressWritesEnabled || mutableState.value.accountEmail == null ||
            mutableState.value.addressBusy || mutableState.value.addresses.none { it.id == id }) return
        val session = accountGeneration
        mutableState.update { it.copy(addressBusy = true, addressMutationError = false, addressMutationSuccess = false) }
        viewModelScope.launch {
            try {
                gateway.deleteAddress(id)
                if (session != accountGeneration) return@launch
                invalidateQuote()
                mutableState.update {
                    it.copy(
                        addressBusy = false, addressMutationSuccess = true,
                        selectedAddressId = it.selectedAddressId?.takeUnless { selected -> selected == id },
                        addresses = it.addresses.filterNot { row -> row.id == id },
                    )
                }
                refreshAddresses()
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                if (session == accountGeneration) {
                    mutableState.update { it.copy(addressBusy = false, addressMutationError = true) }
                }
            }
        }
    }

    fun selectAddress(id: String?) {
        val current = mutableState.value
        if (id != null && current.addresses.none { it.id == id }) return
        if (current.selectedAddressId == id) return
        invalidateQuote()
        mutableState.update { it.copy(selectedAddressId = id) }
    }

    fun requestServerQuote() {
        val state = mutableState.value
        if (!gateway.configured || state.accountEmail == null ||
            state.cart.lines.isEmpty() || state.quoteLoading || state.addressesLoading) return
        val draft = state.cart
        val addressId = state.selectedAddressId
        val address = state.addresses.firstOrNull { it.id == addressId }
        val session = accountGeneration
        val generation = ++quoteGeneration
        mutableState.update { it.copy(quoteLoading = true, quoteFailed = false, quote = null) }
        viewModelScope.launch {
            try {
                val serverQuote = gateway.quote(draft, address)
                if (generation != quoteGeneration || session != accountGeneration) return@launch
                mutableState.update { current ->
                    if (current.cart != draft || current.selectedAddressId != addressId ||
                        current.accountEmail == null) current.copy(quoteLoading = false)
                    else current.copy(quote = serverQuote, quoteLoading = false)
                }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                if (generation == quoteGeneration && session == accountGeneration) {
                    mutableState.update { it.copy(quoteLoading = false, quoteFailed = true) }
                }
            }
        }
    }

    fun openOrderDetails(orderId: String) {
        val current = mutableState.value
        if (!gateway.configured || current.accountEmail == null ||
            current.orders.none { it.id == orderId }) return
        val session = accountGeneration
        val generation = ++orderDetailGeneration
        mutableState.update {
            it.copy(selectedOrderId = orderId, orderDetail = null,
                orderDetailLoading = true, orderDetailFailed = false)
        }
        viewModelScope.launch {
            try {
                val detail = gateway.orderDetail(orderId)
                if (session != accountGeneration || generation != orderDetailGeneration) return@launch
                mutableState.update { state ->
                    if (state.accountEmail == null || state.selectedOrderId != orderId) state
                    else state.copy(orderDetail = detail, orderDetailLoading = false,
                        orderDetailFailed = detail == null)
                }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                if (session == accountGeneration && generation == orderDetailGeneration) {
                    mutableState.update {
                        it.copy(orderDetailLoading = false, orderDetailFailed = true)
                    }
                }
            }
        }
    }

    fun closeOrderDetails() {
        orderDetailGeneration++
        mutableState.update {
            it.copy(selectedOrderId = null, orderDetail = null,
                orderDetailLoading = false, orderDetailFailed = false)
        }
    }

    fun refreshOrders() {
        if (!gateway.configured || mutableState.value.accountEmail == null ||
            mutableState.value.ordersLoading) return
        val session = accountGeneration
        val generation = ++orderGeneration
        mutableState.update { it.copy(ordersLoading = true, ordersFailed = false) }
        viewModelScope.launch {
            try {
                val orders = gateway.orderHistory()
                if (generation != orderGeneration || session != accountGeneration) return@launch
                mutableState.update { state ->
                    if (state.accountEmail == null) state
                    else state.copy(orders = orders, ordersLoading = false)
                }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                if (generation == orderGeneration && session == accountGeneration) {
                    mutableState.update { it.copy(ordersLoading = false, ordersFailed = true) }
                }
            }
        }
    }
}
