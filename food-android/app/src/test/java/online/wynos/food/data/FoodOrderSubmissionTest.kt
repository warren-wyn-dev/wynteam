package online.wynos.food.data

import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodOrderSubmissionTest {
    private val storeId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    private val menuId = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
    private val address = FoodCustomerAddress(
        id = "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
        label = "Home", recipientName = " Jane ", recipientPhone = " 0800000000 ",
        address = " 123 Main Road ", deliveryNote = "Gate",
        isDefault = true, latitude = 13.75, longitude = 100.5,
    )
    private val cart = FoodCartDraft(storeId, listOf(FoodCartLine(
        menuId = menuId, name = "Client display only", basePrice = "99999",
        options = listOf(SelectedOption("group1", "choice1", "Add egg", "999")),
        quantity = 2, note = "no ice",
    )))

    @Test fun onlyIdsOptionsQuantityAndNotesAreSubmittedWithDelivery() {
        val req = FoodOrderSubmission.request(cart, address, " Leave by door ")
        assertEquals(storeId, req["p_store_id"]!!.jsonPrimitive.content)
        assertEquals("Jane", req["p_recipient_name"]!!.jsonPrimitive.content)
        assertEquals("0800000000", req["p_recipient_phone"]!!.jsonPrimitive.content)
        assertEquals("123 Main Road", req["p_shipping_address"]!!.jsonPrimitive.content)
        assertEquals("Leave by door", req["p_customer_note"]!!.jsonPrimitive.content)
        assertEquals("13.75", req["p_latitude"]!!.jsonPrimitive.content)
        assertEquals("100.5", req["p_longitude"]!!.jsonPrimitive.content)
        val items = req["p_items"]!!.jsonArray
        assertEquals(1, items.size)
        val item = items[0].jsonObject
        assertEquals(menuId, item["menu_item_id"]!!.jsonPrimitive.content)
        assertEquals("2", item["quantity"]!!.jsonPrimitive.content)
        assertEquals("no ice", item["note"]!!.jsonPrimitive.content)
        val option = item["selected_options"]!!.jsonArray[0].jsonObject
        assertEquals("group1", option["group_id"]!!.jsonPrimitive.content)
        assertEquals("choice1", option["choice_id"]!!.jsonPrimitive.content)
        assertFalse(req.containsKey("total"))
        assertFalse(item.containsKey("price"))
        assertFalse(item.containsKey("name"))
        assertFalse(item.containsKey("unit_price"))
        assertFalse(item.containsKey("basePrice"))
    }

    @Test fun idempotentOrderAttemptIsExplicitAndDoesNotCarryClientPrices() {
        val attemptId = "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
        val req = FoodOrderSubmission.idempotentRequest(
            cart, address, "store note", attemptId,
        )
        assertEquals(attemptId, req["p_attempt_id"]!!.jsonPrimitive.content)
        assertFalse(req.containsKey("total"))
        assertFalse(req.containsKey("amount"))
        assertFalse(req.containsKey("client_secret"))
        val item = req["p_items"]!!.jsonArray[0].jsonObject
        assertFalse(item.containsKey("unit_price"))
        assertEquals("no ice", item["note"]!!.jsonPrimitive.content)
    }

    @Test fun idempotentOrderAttemptMustHaveAUuid() {
        try {
            FoodOrderSubmission.idempotentRequest(cart, address, attemptId = "invalid")
            throw AssertionError("expected invalid attempt ID")
        } catch (_: IllegalArgumentException) { }
    }

    @Test fun rejectsMissingDeliveryPin() {
        try {
            FoodOrderSubmission.request(cart, address.copy(latitude = null))
            throw AssertionError("expected invalid pin")
        } catch (expected: IllegalArgumentException) {
            assertTrue(expected.message.orEmpty().contains("valid_delivery_pin_required"))
        }
    }

    @Test fun rejectsInvalidCustomerFieldsAndNotes() {
        listOf(
            address.copy(recipientName = ""),
            address.copy(recipientPhone = ""),
            address.copy(address = " "),
        ).forEach {
            try {
                FoodOrderSubmission.request(cart, it)
                throw AssertionError("expected invalid address")
            } catch (_: IllegalArgumentException) { }
        }
        try {
            FoodOrderSubmission.request(cart, address, "a".repeat(801))
            throw AssertionError("expected invalid note")
        } catch (_: IllegalArgumentException) { }
    }

    @Test fun rejectsInvalidItemsBeforeNetworkWrite() {
        listOf(
            FoodCartDraft(storeId, emptyList()),
            FoodCartDraft("not-a-uuid", cart.lines),
            FoodCartDraft(storeId, cart.lines.map { it.copy(quantity = 0) }),
            FoodCartDraft(storeId, cart.lines.map { it.copy(menuId = "not-a-uuid") }),
            FoodCartDraft(storeId, cart.lines.map { it.copy(note = "x".repeat(251)) }),
        ).forEach { bad ->
            try {
                FoodOrderSubmission.request(bad, address)
                throw AssertionError("expected invalid cart")
            } catch (_: IllegalArgumentException) { }
        }
    }
}
