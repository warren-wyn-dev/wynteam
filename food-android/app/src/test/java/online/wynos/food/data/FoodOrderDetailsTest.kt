package online.wynos.food.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodOrderDetailsTest {
    private fun obj(value: String): JsonObject = Json.parseToJsonElement(value) as JsonObject

    private val order = obj(
        """{"id":"00000000-0000-0000-0000-000000000123","order_number":"WF-123",
          "status":"preparing","payment_status":"paid",
          "recipient_name":"QA","recipient_phone":"0812345678",
          "shipping_address":"12/3 Street","customer_note":"no chilli",
          "subtotal":75,"delivery_fee":10,"campaign_discount":5,
          "delivery_discount":0,"total":80,"created_at":"2026-10-14T03:00:00Z"}"""
    )

    @Test fun parsesOwnerOrderItemsAndSortedTimeline() {
        val item = obj(
            """{"item_name":"Pad Thai","unit_price":75,"quantity":1,
              "selected_options":[{"group_id":"spice","choice_name":"Mild"}],
              "item_note":"Separate sauce"}"""
        )
        val late = obj("""{"event_type":"preparing","to_status":"preparing","created_at":"2026-10-14T03:05:00Z"}""")
        val early = obj("""{"event_type":"created","to_status":"pending_acceptance","created_at":"2026-10-14T03:00:00Z"}""")
        val detail = FoodOrderDetailParser.fromRows(order, listOf(item), listOf(late, early))
        assertEquals("WF-123", detail.number)
        assertEquals("paid", detail.paymentStatus)
        assertEquals("Mild", detail.items.single().options.single())
        assertEquals("Separate sauce", detail.items.single().note)
        assertEquals("created", detail.events.first().type)
        assertEquals("preparing", detail.events.last().toStatus)
        assertFalse(detail.finished)
    }

    @Test fun cancelledAndDeliveredAreTerminal() {
        assertTrue(FoodOrderDetailParser.fromRows(order.copyWith("cancelled"), emptyList(), emptyList()).finished)
        assertTrue(FoodOrderDetailParser.fromRows(order.copyWith("delivered"), emptyList(), emptyList()).finished)
    }

    @Test fun invalidItemRowsAreSafelySkipped() {
        val item = obj("""{"item_name":"Bad","quantity":0,"unit_price":100}""")
        assertTrue(FoodOrderDetailParser.fromRows(order, listOf(item), emptyList()).items.isEmpty())
    }

    @Test(expected = IllegalArgumentException::class)
    fun refusesUnknownOrderStatus() {
        FoodOrderDetailParser.fromRows(order.copyWith("untrusted_status"), emptyList(), emptyList())
    }

    private fun JsonObject.copyWith(status: String) = obj(this.toString().replace(
        "\"status\":\"preparing\"", "\"status\":\"$status\""
    ))
}
