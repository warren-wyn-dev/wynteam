package online.wynos.food.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FoodOrderSummaryTest {
    @Test fun readsSafeOrderSummary() {
        val raw = Json.parseToJsonElement("""{"id":"order-1","order_number":"F123","status":"preparing","payment_status":"paid","total":128.50,"created_at":"2026-10-13T12:30:00Z"}""") as JsonObject
        val result = FoodOrderSummary.fromJson(raw)!!
        assertEquals("F123", result.number)
        assertEquals("128.50", result.total)
    }

    @Test fun refusesRowWithoutId() {
        assertNull(FoodOrderSummary.fromJson(Json.parseToJsonElement("""{"status":"paid"}""") as JsonObject))
    }
}
