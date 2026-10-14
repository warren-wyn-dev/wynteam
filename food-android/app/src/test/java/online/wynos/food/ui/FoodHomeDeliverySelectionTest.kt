package online.wynos.food.ui

import online.wynos.food.data.FoodCustomerAddress
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FoodHomeDeliverySelectionTest {
    private val default = FoodCustomerAddress(
        id = "home-id",
        label = "Home",
        recipientName = "Test",
        recipientPhone = "0000000000",
        address = "Home address",
        deliveryNote = null,
        isDefault = true,
        latitude = 16.0,
        longitude = 103.0,
    )
    private val work = default.copy(
        id = "work-id",
        label = "Work",
        address = "Work address",
        isDefault = false,
    )

    @Test fun headerUsesSelectedAddressRatherThanAlwaysUsingDefault() {
        assertEquals(default, resolvedHomeDeliveryAddress(listOf(default, work), default.id))
        assertEquals(work, resolvedHomeDeliveryAddress(listOf(default, work), work.id))
    }

    @Test fun unknownOrUnselectedAddressDoesNotShowAnotherCustomersAddress() {
        assertNull(resolvedHomeDeliveryAddress(listOf(default, work), null))
        assertNull(resolvedHomeDeliveryAddress(listOf(default, work), "removed-id"))
        assertNull(resolvedHomeDeliveryAddress(emptyList(), default.id))
    }
}
