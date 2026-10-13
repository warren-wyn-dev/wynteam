package online.wynos.food.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonNull
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodAddressManagementTest {
    private val valid = FoodAddressDraft(
        label = "Home", recipientName = "QA", recipientPhone = "0812345678",
        addressLine1 = "12/3", subdistrict = "Talat", district = "Mueang",
        province = "Maha Sarakham", postalCode = "44000",
        latitude = 16.184, longitude = 103.302,
    )

    @Test fun validStructuredAddressUsesWebV3Contract() {
        assertTrue(valid.validate())
        val json = valid.toRpcParams()
        assertEquals(JsonNull, json["p_address_id"])
        assertEquals("12/3", json["p_address_line1"]?.toString()?.trim('"'))
        assertEquals("44000", json["p_postal_code"]?.toString()?.trim('"'))
        assertTrue(json.containsKey("p_latitude"))
        assertTrue(json.containsKey("p_longitude"))
        assertEquals(JsonNull, json["p_place_id"])
        assertFalse(json.containsKey("user_id")) // never allow client-selected owner
    }

    @Test fun refusesAddressesWithoutValidPins() {
        assertFalse(valid.copy(latitude = null).validate())
        assertFalse(valid.copy(longitude = 181.0).validate())
        assertFalse(valid.copy(latitude = Double.NaN).validate())
        assertFalse(valid.copy(latitude = Double.POSITIVE_INFINITY).validate())
    }

    @Test fun rejectsMalformedAddressAndPostalCode() {
        assertFalse(valid.copy(postalCode = "4400").validate())
        assertFalse(valid.copy(postalCode = "44AA0").validate())
        assertFalse(valid.copy(addressLine1 = "").validate())
        assertFalse(valid.copy(subdistrict = "").validate())
        assertFalse(valid.copy(recipientName = " ").validate())
        assertFalse(valid.copy(deliveryNote = "a".repeat(501)).validate())
    }

    @Test(expected = IllegalArgumentException::class)
    fun cannotSubmitInvalidAddress() {
        valid.copy(longitude = null).toRpcParams()
    }

    @Test fun editingReusesStructuredAddressAndOwnedId() {
        val rows = Json.parseToJsonElement(
            """[{"id":"00000000-0000-0000-0000-000000000001","label":"Home","recipient_name":"QA","recipient_phone":"081","address":"12/3 ตำบลตลาด","address_line1":"12/3","subdistrict":"Talat","district":"Mueang","province":"Maha Sarakham","postal_code":"44000","latitude":16.184,"longitude":103.302,"is_default":true}]"""
        ) as kotlinx.serialization.json.JsonArray
        val address = FoodAddressParser.parse(rows.map { it as JsonObject }).single()
        val draft = FoodAddressDraft.fromAddress(address)
        assertEquals("12/3", draft.addressLine1)
        assertEquals("Talat", draft.subdistrict)
        assertEquals("44000", draft.postalCode)
        assertEquals(address.id, draft.id)
        assertTrue(draft.isDefault)
        assertTrue(draft.validate())
    }
}
