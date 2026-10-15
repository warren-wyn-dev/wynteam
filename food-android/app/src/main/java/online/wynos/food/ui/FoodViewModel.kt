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
import online.wynos.food.data.FoodStoreReviewFeed
import online.wynos.food.data.FoodPromotionNotice
import online.wynos.food.data.FoodOrderChatMessage
import online.wynos.food.data.SupabaseFoodGateway
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class FoodOrderStatusNotice(val orderId: String, val number: String, val status: String)

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
    val orderStatusNotice: FoodOrderStatusNotice? = null,
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
    val reviewedStoreId: String? = null,
    val reviewFeed: FoodStoreReviewFeed? = null,
    val reviewFeedLoading: Boolean = false,
    val reviewFeedFailed: Boolean = false,
    val promotions: List<FoodPromotionNotice> = emptyList(),
    val promotionsLoading: Boolean = false,
    val promotionsFailed: Boolean = false,
    val chatEnabled: Boolean = false,
    val chatOrderId: String? = null,
    val chatMessages: List<FoodOrderChatMessage> = emptyList(),
    val chatLoading: Boolean = false,
    val chatFailed: Boolean = false,
    val chatSending: Boolean = false,
    val chatSendFailed: Boolean = false,
    val accountLoading: Boolean = false,
    val accountBusy: Boolean = false,
    val accountEmail: String? = null,
    val accountFailed: Boolean = false,
    val resetEmailSent: Boolean = false,
    val accountDeletionEnabled: Boolean = false,
    val accountDeletionBusy: Boolean = false,
    val signupEnabled: Boolean = false,
    val registrationEmailSent: Boolean = false,
    val stagingOrderCreationEnabled: Boolean = false,
    val stagingMobilePaymentEnabled: Boolean = false,
    val stagingOrderBusy: Boolean = false,
    val stagingOrderFailed: Boolean = false,
    val stagingOrderUncertain: Boolean = false,
    val stagingOrderCreatedId: String? = null,
    val stagingOrderAttemptId: String? = null,
)

class FoodViewModel(private val gateway: FoodGateway = SupabaseFoodGateway()) : ViewModel() {
    private val mutableState = MutableStateFlow(FoodUiState(
        configured = gateway.configured,
        addressWritesEnabled = gateway.addressWritesEnabled,
        signupEnabled = gateway.signupEnabled,
        accountDeletionEnabled = gateway.accountDeletionEnabled,
        stagingOrderCreationEnabled = gateway.stagingOrderCreationEnabled,
        stagingMobilePaymentEnabled = gateway.stagingMobilePaymentEnabled,
        chatEnabled = gateway.chatEnabled,
    ))
    val uiState = mutableState.asStateFlow()

    // A request must belong to the currently active account AND current input generation.
    // A matching email is not sufficient: the user might sign out and sign back in.
    private var accountGeneration = 0L
    private var addressGeneration = 0L
    private var orderGeneration = 0L
    private var orderDetailGeneration = 0L
    private var quoteGeneration = 0L
    private var reviewGeneration = 0L
    private var promotionsGeneration = 0L
    private var chatGeneration = 0L
    // The staging RPC has a buyer-scoped durable idempotency key. Still restrict
    // the preview to one attempt/session until full order/payment E2E is verified.
    private var stagingOrderAttemptConsumed = false

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
        reviewGeneration++
        promotionsGeneration++
        chatGeneration++
        mutableState.update { it.copy(selectedOrderId = null, orderDetail = null,
            orderDetailLoading = false, orderDetailFailed = false, orderStatusNotice = null,
            reviewedStoreId = null, reviewFeed = null,
            reviewFeedLoading = false, reviewFeedFailed = false,
            promotions = emptyList(), promotionsLoading = false, promotionsFailed = false,
            chatOrderId = null, chatMessages = emptyList(), chatLoading = false,
            chatFailed = false, chatSending = false, chatSendFailed = false) }
        invalidateQuote()
        stagingOrderAttemptConsumed = false
        mutableState.update {
            it.copy(stagingOrderBusy = false, stagingOrderFailed = false,
                stagingOrderUncertain = false, stagingOrderCreatedId = null,
                stagingOrderAttemptId = null)
        }
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

    fun registerAccount(email: String, password: String, confirmation: String) {
        val state = mutableState.value
        if (!gateway.configured || !gateway.signupEnabled || state.accountBusy ||
            state.accountEmail != null || !FoodSignupValidation.canSubmit(email, password, confirmation)) return
        invalidateAccountRequests()
        val generation = accountGeneration
        mutableState.update {
            it.copy(accountBusy = true, accountFailed = false, resetEmailSent = false,
                registrationEmailSent = false, accountLoading = false)
        }
        viewModelScope.launch {
            try {
                val activeEmail = gateway.signUp(email.trim(), password)
                if (generation != accountGeneration) return@launch
                mutableState.update {
                    it.copy(accountBusy = false, accountEmail = activeEmail,
                        registrationEmailSent = activeEmail == null)
                }
                if (activeEmail != null) {
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

    fun signIn(email: String, password: String) {
        if (!gateway.configured || email.isBlank() || password.isEmpty() || mutableState.value.accountBusy) return
        invalidateAccountRequests()
        val generation = accountGeneration
        mutableState.update {
            it.copy(accountBusy = true, accountFailed = false, resetEmailSent = false,
                registrationEmailSent = false, accountLoading = false, orders = emptyList(), addresses = emptyList(),
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

    fun deleteAccount() {
        val state = mutableState.value
        if (!gateway.accountDeletionEnabled || state.accountEmail == null ||
            state.accountBusy || state.accountDeletionBusy || state.stagingOrderBusy) return
        invalidateAccountRequests()
        val generation = accountGeneration
        mutableState.update {
            it.copy(accountBusy = true, accountDeletionBusy = true, accountFailed = false)
        }
        viewModelScope.launch {
            try {
                gateway.deleteMyAccount()
                if (generation != accountGeneration) return@launch
                // Never retain private order/address/cart contents after deletion.
                mutableState.update {
                    it.copy(accountBusy = false, accountDeletionBusy = false,
                        accountEmail = null, accountFailed = false,
                        orders = emptyList(), ordersLoading = false, ordersFailed = false,
                        orderStatusNotice = null,
                        selectedOrderId = null, orderDetail = null,
                        orderDetailLoading = false, orderDetailFailed = false,
                        addresses = emptyList(), addressesLoading = false,
                        addressesFailed = false, selectedAddressId = null,
                        addressBusy = false, addressMutationError = false,
                        addressMutationSuccess = false, cart = FoodCartDraft(),
                        quote = null, quoteLoading = false, quoteFailed = false,
                        resetEmailSent = false, registrationEmailSent = false)
                }
                refreshCatalog()
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                if (generation == accountGeneration) {
                    mutableState.update {
                        it.copy(accountBusy = false, accountDeletionBusy = false,
                            accountFailed = true)
                    }
                }
            }
        }
    }

    fun signOut() {
        if (mutableState.value.accountBusy || mutableState.value.stagingOrderBusy) return
        invalidateAccountRequests()
        val generation = accountGeneration
        mutableState.update { it.copy(accountBusy = true, accountFailed = false) }
        viewModelScope.launch {
            try {
                gateway.signOut()
                if (generation != accountGeneration) return@launch
                mutableState.update { it.copy(
                    accountBusy = false, accountEmail = null, accountLoading = false,
                    registrationEmailSent = false, resetEmailSent = false,
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

    /**
     * Debug/staging disposable orders only. Never production checkout.
     *
     * No automatic retry on timeout: a network failure may happen after
     * creation. Store the attempt ID for reconciliation, never create a new
     * attempt for the same uncertain result.
     */
    fun submitStagingOrder(customerNote: String = "") {
        val state = mutableState.value
        if (!gateway.stagingOrderCreationEnabled || !state.stagingOrderCreationEnabled ||
            stagingOrderAttemptConsumed || state.accountEmail == null || state.accountBusy ||
            state.stagingOrderBusy || state.addressBusy || customerNote.length > 800) return
        val address = state.addresses.firstOrNull { it.id == state.selectedAddressId } ?: return
        if (!online.wynos.food.data.FoodCheckoutReviewGuard.canReview(
                state.cart, state.quote, address, state.quoteLoading, state.addressesLoading,
            )) return
        val draft = state.cart
        val session = accountGeneration
        val attemptId = java.util.UUID.randomUUID().toString()
        stagingOrderAttemptConsumed = true // BEFORE launching the network request
        mutableState.update {
            it.copy(stagingOrderBusy = true, stagingOrderFailed = false,
                stagingOrderUncertain = false, stagingOrderCreatedId = null,
                stagingOrderAttemptId = attemptId)
        }
        viewModelScope.launch {
            try {
                val id = gateway.createOrderStaging(draft, address, customerNote.trim(), attemptId)
                if (session != accountGeneration) return@launch
                mutableState.update {
                    it.copy(stagingOrderBusy = false, stagingOrderCreatedId = id)
                }
                // Keep the review visible with its staging order ID. No retries.
                // Cart editing invalidates the quote normally; this is not payment.
                refreshOrders()
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                if (session == accountGeneration) {
                    mutableState.update {
                        it.copy(stagingOrderBusy = false, stagingOrderFailed = true,
                            stagingOrderUncertain = true)
                    }
                }
            }
        }
    }

    /**
     * Acquires a test-mode Stripe client secret only for the freshly created
     * staging order. The secret is never stored in ViewModel StateFlow.
     * A successful PaymentSheet callback is NOT payment confirmation.
     */
    suspend fun prepareStagingMobilePayment(orderId: String): online.wynos.food.data.FoodMobilePaymentIntent {
        val state = mutableState.value
        check(gateway.stagingMobilePaymentEnabled && state.stagingMobilePaymentEnabled &&
            state.accountEmail != null && !state.accountBusy &&
            state.stagingOrderCreatedId == orderId && !state.stagingOrderBusy &&
            !state.stagingOrderUncertain
        ) { "staging_mobile_payment_disabled" }
        val generation = accountGeneration
        val credentials = gateway.createStagingPaymentIntent(orderId)
        check(generation == accountGeneration && mutableState.value.accountEmail != null &&
            mutableState.value.stagingOrderCreatedId == orderId
        ) { "account_changed" }
        return credentials
    }

    fun refreshPromotionInbox() {
        val current = mutableState.value
        if (!gateway.configured || current.accountEmail.isNullOrBlank()) return
        val generation = ++promotionsGeneration
        val session = accountGeneration
        mutableState.update { it.copy(promotionsLoading = true, promotionsFailed = false) }
        viewModelScope.launch {
            try {
                val rows = gateway.promotionInbox()
                if (generation != promotionsGeneration || session != accountGeneration) return@launch
                mutableState.update {
                    if (it.accountEmail.isNullOrBlank()) it
                    else it.copy(promotions = rows, promotionsLoading = false,
                        promotionsFailed = false)
                }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                if (generation == promotionsGeneration && session == accountGeneration) {
                    mutableState.update {
                        it.copy(promotionsLoading = false, promotionsFailed = true)
                    }
                }
            }
        }
    }

    /** Explicit, authenticated read acknowledgment; never changes an offer's eligibility. */
    fun markPromotionRead(id: String) {
        val current = mutableState.value
        if (current.accountEmail == null ||
            current.promotions.none { it.id == id && it.isUnread }) return
        val session = accountGeneration
        viewModelScope.launch {
            try {
                gateway.markPromotionRead(id)
                if (session == accountGeneration) refreshPromotionInbox()
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                // Keep unread in the UI if the server did not acknowledge the update.
                if (session == accountGeneration) {
                    mutableState.update { it.copy(promotionsFailed = true) }
                }
            }
        }
    }

    /** This is available only in a disposable staging debug build with RLS installed. */
    fun openOrderChat(orderId: String) {
        val current = mutableState.value
        if (!gateway.chatEnabled || current.accountEmail == null ||
            current.orders.none { it.id == orderId }) return
        chatGeneration++
        mutableState.update {
            it.copy(chatOrderId = orderId, chatMessages = emptyList(),
                chatLoading = false, chatFailed = false, chatSendFailed = false)
        }
        refreshOrderChat()
    }

    fun closeOrderChat() {
        chatGeneration++
        mutableState.update {
            it.copy(chatOrderId = null, chatMessages = emptyList(),
                chatLoading = false, chatFailed = false, chatSending = false,
                chatSendFailed = false)
        }
    }

    fun refreshOrderChat() {
        val current = mutableState.value
        val orderId = current.chatOrderId ?: return
        if (!gateway.chatEnabled || current.accountEmail == null || current.chatLoading ||
            current.orders.none { it.id == orderId }) return
        val account = accountGeneration
        val generation = ++chatGeneration
        mutableState.update { it.copy(chatLoading = true, chatFailed = false) }
        viewModelScope.launch {
            try {
                val rows = gateway.orderChatMessages(orderId)
                if (account != accountGeneration || generation != chatGeneration) return@launch
                mutableState.update {
                    if (it.chatOrderId != orderId || it.accountEmail == null) it
                    else it.copy(chatMessages = rows, chatLoading = false)
                }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                if (account == accountGeneration && generation == chatGeneration) {
                    mutableState.update { it.copy(chatLoading = false, chatFailed = true) }
                }
            }
        }
    }

    fun sendOrderChat(body: String) {
        val current = mutableState.value
        val orderId = current.chatOrderId ?: return
        val message = body.trim()
        if (!gateway.chatEnabled || current.accountEmail == null || current.chatSending ||
            current.orders.none { it.id == orderId } ||
            message.isBlank() || message.length > 1200) return
        val account = accountGeneration
        val generation = chatGeneration
        val clientId = java.util.UUID.randomUUID().toString()
        mutableState.update { it.copy(chatSending = true, chatSendFailed = false) }
        viewModelScope.launch {
            try {
                gateway.sendOrderChatMessage(orderId, message, clientId)
                if (account != accountGeneration || generation != chatGeneration) return@launch
                mutableState.update { it.copy(chatSending = false, chatSendFailed = false) }
                refreshOrderChat()
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                if (account == accountGeneration && generation == chatGeneration) {
                    mutableState.update { it.copy(chatSending = false, chatSendFailed = true) }
                }
            }
        }
    }

    fun refreshStoreReviews(storeId: String) {
        if (!gateway.configured || runCatching { java.util.UUID.fromString(storeId) }.isFailure) return
        val generation = ++reviewGeneration
        val account = accountGeneration
        mutableState.update {
            it.copy(reviewedStoreId = storeId, reviewFeed = null,
                reviewFeedLoading = true, reviewFeedFailed = false)
        }
        viewModelScope.launch {
            try {
                val feed = gateway.storeReviewFeed(storeId)
                if (generation != reviewGeneration || account != accountGeneration) return@launch
                mutableState.update {
                    if (it.reviewedStoreId != storeId) it
                    else it.copy(reviewFeed = feed, reviewFeedLoading = false,
                        reviewFeedFailed = false)
                }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                if (generation == reviewGeneration && account == accountGeneration) {
                    mutableState.update {
                        if (it.reviewedStoreId != storeId) it
                        else it.copy(reviewFeed = null, reviewFeedLoading = false,
                            reviewFeedFailed = true)
                    }
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

    fun dismissOrderStatusNotice() {
        mutableState.update { it.copy(orderStatusNotice = null) }
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
                    else {
                        // Foreground Orders polling only: notify about a genuine change
                        // to an already visible order, not initial history load.
                        val oldStatuses = state.orders.associate { it.id to it.status }
                        val changed = orders.firstOrNull { updated ->
                            val previous = oldStatuses[updated.id]
                            previous != null && previous != updated.status &&
                                updated.status != "unknown"
                        }
                        state.copy(
                            orders = orders,
                            ordersLoading = false,
                            orderStatusNotice = changed?.let {
                                FoodOrderStatusNotice(it.id, it.number, it.status)
                            } ?: state.orderStatusNotice,
                        )
                    }
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
