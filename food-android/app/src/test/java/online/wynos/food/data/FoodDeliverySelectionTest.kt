package online.wynos.food.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FoodDeliverySelectionTest {
    private fun address(id: String, label: String, default: Boolean = false) =
        FoodCustomerAddress(
            id = id, label = label, recipientName = "Person", recipientPhone = "0812345678",
            address = "Full address", deliveryNote = null, isDefault = default,
            latitude = 16.0, longitude = 103.0,
        )

    @Test fun chosenAddressOverridesBackendDefaultForThisSession() {
        val list = listOf(address("home", "บ้าน", true), address("office", "ที่ทำงาน"))
        assertEquals("ที่ทำงาน", FoodDeliverySelection.label(list, "office"))
        assertEquals("home", FoodDeliverySelection.current(list, "missing")?.id)
        assertEquals("บ้าน", FoodDeliverySelection.label(list, null))
    }

    @Test fun noAddressReturnsNullAndDoesNotInventDeliveryDestination() {
        assertNull(FoodDeliverySelection.current(emptyList(), null))
        assertNull(FoodDeliverySelection.label(emptyList(), "unavailable"))
        assertEquals("Full address", FoodDeliverySelection.label(
            listOf(address("home", "  ")), "home",
        ))
    }
}
