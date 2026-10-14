package online.wynos.food.ui

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.test.resetMain
import online.wynos.food.data.FoodCartDraft
import online.wynos.food.data.FoodCustomerAddress
import online.wynos.food.data.FoodGateway
import online.wynos.food.data.FoodHomeBanner
import online.wynos.food.data.FoodMenu
import online.wynos.food.data.FoodOrderSummary
import online.wynos.food.data.FoodOrderDetail
import online.wynos.food.data.FoodServerQuote
import online.wynos.food.data.FoodStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigDecimal

@OptIn(ExperimentalCoroutinesApi::class)
class FoodViewModelTest {
    private val menu = FoodMenu("menu-1", "Food", "Meals", null, "60", emptyList())
    private val store = FoodStore("store-1", "Store", null, true, "10", listOf(menu))
    private val quote = FoodServerQuote(
        BigDecimal("60"), BigDecimal("10"), BigDecimal.ZERO, BigDecimal.ZERO,
        BigDecimal("70"), null, false, null,
    )
    private val address = FoodCustomerAddress(
        "address-1", "Home", "Test", "0812345678", "Street", null, true, 16.0, 103.0,
    )

    private class FakeGateway : FoodGateway {
        override val configured = true
        var allowSignup = false
        override val signupEnabled: Boolean get() = allowSignup
        var allowDeletion = false
        override val accountDeletionEnabled: Boolean get() = allowDeletion
        var deletionCalls = 0
        override suspend fun deleteMyAccount() {
            deletionCalls++
        }
        var accountOnRestore: String? = "qa@example.com"
        var signupResult: String? = null
        var signupCalls = 0
        override suspend fun signUp(email: String, password: String): String? {
            signupCalls++
            return signupResult
        }
        val quoteDeferred = CompletableDeferred<FoodServerQuote>()
        var addressDeferred: CompletableDeferred<List<FoodCustomerAddress>>? = null
        var ordersDeferred: CompletableDeferred<List<FoodOrderSummary>>? = null
        var selectedOrders: List<FoodOrderSummary> = emptyList()
        var orderDetailDeferred: CompletableDeferred<FoodOrderDetail?>? = null
        override suspend fun catalog(): List<FoodStore> = emptyList()
        override suspend fun homeBanners(): List<FoodHomeBanner> = emptyList()
        override suspend fun accountEmail(): String? = accountOnRestore
        override suspend fun orderHistory(): List<FoodOrderSummary> = ordersDeferred?.await() ?: selectedOrders
        override suspend fun orderDetail(orderId: String): FoodOrderDetail? = orderDetailDeferred?.await()
        override suspend fun addresses(): List<FoodCustomerAddress> = addressDeferred?.await() ?: emptyList()
        override suspend fun quote(cart: FoodCartDraft, address: FoodCustomerAddress?): FoodServerQuote =
            quoteDeferred.await()
        override suspend fun signIn(email: String, password: String): String? = email
        override suspend fun signOut() {}
        override suspend fun resetPassword(email: String) {}
    }

    @Test fun accountDeletionCannotCallRpcWithoutStagingOptIn() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val fake = FakeGateway()
            val vm = FoodViewModel(fake)
            runCurrent()
            vm.deleteAccount()
            runCurrent()
            assertEquals(0, fake.deletionCalls)
            assertEquals("qa@example.com", vm.uiState.value.accountEmail)
        } finally {
            Dispatchers.resetMain()
        }
    }

    @Test fun stagingAccountDeletionClearsPrivateState() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val fake = FakeGateway().apply { allowDeletion = true }
            val vm = FoodViewModel(fake)
            runCurrent()
            assertTrue(vm.addToCart(store, menu, emptyMap(), 1, "private note"))
            vm.deleteAccount()
            runCurrent()
            assertEquals(1, fake.deletionCalls)
            assertNull(vm.uiState.value.accountEmail)
            assertTrue(vm.uiState.value.cart.lines.isEmpty())
            assertTrue(vm.uiState.value.orders.isEmpty())
            assertTrue(vm.uiState.value.addresses.isEmpty())
            assertNull(vm.uiState.value.selectedAddressId)
            assertNull(vm.uiState.value.quote)
            assertFalse(vm.uiState.value.accountDeletionBusy)
        } finally {
            Dispatchers.resetMain()
        }
    }

    @Test fun registrationRemainsDisabledWithoutStagingFlag() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val fake = FakeGateway().apply { accountOnRestore = null }
            val vm = FoodViewModel(fake)
            runCurrent()
            vm.registerAccount("person@example.com", "long-password", "long-password")
            runCurrent()
            assertEquals(0, fake.signupCalls)
            assertFalse(vm.uiState.value.signupEnabled)
            assertFalse(vm.uiState.value.registrationEmailSent)
        } finally {
            Dispatchers.resetMain()
        }
    }

    @Test fun nativeRegistrationWaitsForEmailConfirmationWhenNoSession() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val fake = FakeGateway().apply {
                accountOnRestore = null
                allowSignup = true
            }
            val vm = FoodViewModel(fake)
            runCurrent()
            vm.registerAccount("person@example.com", "long-password", "long-password")
            runCurrent()
            assertEquals(1, fake.signupCalls)
            assertTrue(vm.uiState.value.registrationEmailSent)
            assertNull(vm.uiState.value.accountEmail)
            assertFalse(vm.uiState.value.accountBusy)
        } finally {
            Dispatchers.resetMain()
        }
    }

    @Test fun invalidRegistrationDoesNotCallBackend() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val fake = FakeGateway().apply { accountOnRestore = null; allowSignup = true }
            val vm = FoodViewModel(fake)
            runCurrent()
            vm.registerAccount("bad-email", "short", "different")
            runCurrent()
            assertEquals(0, fake.signupCalls)
        } finally {
            Dispatchers.resetMain()
        }
    }

    @Test fun oldQuoteCannotReturnAfterCartChange() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val fake = FakeGateway()
            val vm = FoodViewModel(fake)
            runCurrent()
            assertTrue(vm.addToCart(store, menu, emptyMap(), 1, ""))
            vm.requestServerQuote()
            runCurrent()
            assertTrue(vm.uiState.value.quoteLoading)
            val identity = vm.uiState.value.cart.lines.first().identity
            vm.updateCartLine(identity, 2)
            assertFalse(vm.uiState.value.quoteLoading)
            fake.quoteDeferred.complete(quote)
            runCurrent()
            assertNull(vm.uiState.value.quote)
            assertFalse(vm.uiState.value.quoteFailed)
        } finally {
            Dispatchers.resetMain()
        }
    }

    @Test fun obsoleteQuoteFailureCannotBlockRetry() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val fake = FakeGateway()
            val vm = FoodViewModel(fake)
            runCurrent()
            vm.addToCart(store, menu, emptyMap(), 1, "")
            vm.requestServerQuote()
            runCurrent()
            vm.clearCart()
            fake.quoteDeferred.completeExceptionally(IllegalStateException("connection"))
            runCurrent()
            assertNull(vm.uiState.value.quote)
            assertFalse(vm.uiState.value.quoteLoading)
            assertFalse(vm.uiState.value.quoteFailed)
        } finally {
            Dispatchers.resetMain()
        }
    }

    @Test fun signingOutDiscardsLateAddressAndOrderResponses() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val fake = FakeGateway().apply {
                addressDeferred = CompletableDeferred()
                ordersDeferred = CompletableDeferred()
            }
            val vm = FoodViewModel(fake)
            runCurrent()
            assertTrue(vm.uiState.value.addressesLoading)
            assertTrue(vm.uiState.value.ordersLoading)
            vm.signOut()
            runCurrent()
            fake.addressDeferred!!.complete(listOf(address))
            fake.ordersDeferred!!.complete(emptyList())
            runCurrent()
            assertNull(vm.uiState.value.accountEmail)
            assertTrue(vm.uiState.value.addresses.isEmpty())
            assertNull(vm.uiState.value.selectedAddressId)
            assertFalse(vm.uiState.value.addressesLoading)
            assertFalse(vm.uiState.value.ordersLoading)
        } finally {
            Dispatchers.resetMain()
        }
    }

    @Test fun addressRefreshInvalidatesPriceEvenIfSameAddressIsSelected() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val fake = FakeGateway()
            val vm = FoodViewModel(fake)
            runCurrent()
            vm.addToCart(store, menu, emptyMap(), 1, "")
            vm.requestServerQuote()
            runCurrent()
            fake.quoteDeferred.complete(quote)
            runCurrent()
            assertEquals(quote, vm.uiState.value.quote)
            vm.refreshAddresses()
            assertNull(vm.uiState.value.quote)
            assertFalse(vm.uiState.value.quoteLoading)
        } finally {
            Dispatchers.resetMain()
        }
    }
    private val existingOrder = FoodOrderSummary(
        "00000000-0000-0000-0000-000000000001",
        "WF-001", "preparing", "paid", "75", "2026-10-14T04:00:00Z",
    )

    private val existingDetail = FoodOrderDetail(
        id = "00000000-0000-0000-0000-000000000001",
        number = "WF-001",
        status = "preparing",
        paymentStatus = "paid",
        recipientName = "QA",
        recipientPhone = "0812345678",
        shippingAddress = "Street",
        note = null,
        subtotal = "65",
        deliveryFee = "10",
        campaignDiscount = "0",
        deliveryDiscount = "0",
        total = "75",
        createdAt = "2026-10-14T04:00:00Z",
        items = emptyList(),
        events = emptyList(),
    )

    @Test fun signOutClearsPrivateOrderDetailWhileRequestIsInFlight() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val fake = FakeGateway().apply {
                selectedOrders = listOf(existingOrder)
                orderDetailDeferred = CompletableDeferred()
            }
            val vm = FoodViewModel(fake)
            runCurrent()
            vm.openOrderDetails(existingOrder.id)
            runCurrent()
            assertTrue(vm.uiState.value.orderDetailLoading)
            vm.signOut()
            runCurrent()
            fake.orderDetailDeferred!!.complete(existingDetail)
            runCurrent()
            assertNull(vm.uiState.value.selectedOrderId)
            assertNull(vm.uiState.value.orderDetail)
            assertFalse(vm.uiState.value.orderDetailLoading)
        } finally {
            Dispatchers.resetMain()
        }
    }

    @Test fun closeOrderDetailDiscardsLateResponse() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        try {
            val fake = FakeGateway().apply {
                selectedOrders = listOf(existingOrder)
                orderDetailDeferred = CompletableDeferred()
            }
            val vm = FoodViewModel(fake)
            runCurrent()
            vm.openOrderDetails(existingOrder.id)
            runCurrent()
            vm.closeOrderDetails()
            fake.orderDetailDeferred!!.complete(existingDetail)
            runCurrent()
            assertNull(vm.uiState.value.selectedOrderId)
            assertNull(vm.uiState.value.orderDetail)
        } finally {
            Dispatchers.resetMain()
        }
    }

}
