package online.wynos.food.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FoodHomeDeliveryLabelTest {
    private fun address(
        id: String, label: String, place: String = "", default: Boolean = false,
    ) = FoodCustomerAddress(
        id = id, label = label, recipientName = "QA", recipientPhone = "0800000000",
        address = "Street", deliveryNote = null, isDefault = default,
        latitude = 16.0, longitude = 103.0, placeName = place,
    )

    @Test fun showsDefaultSavedPlaceExactlyAsWebsite() {
        val addresses = listOf(
            address("1", "Work", "Office A"),
            address("2", "Home", "My Home", default = true),
        )
        assertEquals("My Home", FoodHomeDeliveryLabel.fromAddresses(addresses))
    }

    @Test fun fallsBackToDefaultLabelThenFirstAddress() {
        assertEquals(
            "Home", FoodHomeDeliveryLabel.fromAddresses(
                listOf(address("2", "Home", default = true), address("1", "Work")),
            ),
        )
        assertEquals("First", FoodHomeDeliveryLabel.fromAddresses(
            listOf(address("1", "First"), address("2", "Second")),
        ))
    }

    @Test fun neverLeaksAnOldAddressForAnEmptyOrUnlabeledAccount() {
        assertNull(FoodHomeDeliveryLabel.fromAddresses(emptyList()))
        assertNull(FoodHomeDeliveryLabel.fromAddresses(listOf(address("1", " ", " "))))
    }
}
