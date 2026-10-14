package online.wynos.food.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.ZoneId
import java.util.Locale

class FoodOrderDisplayTest {
    @Test fun localizedOrderTimestampUsesDeviceTimeZone() {
        val raw = "2026-10-14T11:36:00Z"
        val thai = formatFoodOrderDateTime(raw, Locale.forLanguageTag("th-TH"), ZoneId.of("Asia/Bangkok"))
        val english = formatFoodOrderDateTime(raw, Locale.US, ZoneId.of("UTC"))
        assertTrue(thai.contains("18:36"))
        assertTrue(english.contains("11:36"))
        assertTrue(english.contains("Oct"))
        assertTrue(thai.contains("2026"))
    }

    @Test fun invalidTimestampFallsBackWithoutCrashing() {
        assertEquals("bad", formatFoodOrderDateTime("bad", Locale.US, ZoneId.of("UTC")))
        assertEquals("2026-10-14 18:36",
            formatFoodOrderDateTime("2026-10-14T18:36", Locale.US, ZoneId.of("UTC")))
    }

    @Test fun historyParsesRealStoreReferenceOnlyIfProvided() {
        val json = Json.parseToJsonElement(
            """{"id":"order-1","order_number":"WF001","created_at":"2026-10-14T11:36:00Z","store_id":"store-1"}"""
        ) as JsonObject
        assertEquals("store-1", FoodOrderSummary.fromJson(json)?.storeId)
        assertEquals(null, FoodOrderSummary.fromJson(Json.parseToJsonElement("""{"id":"old-order"}""") as JsonObject)?.storeId)
    }
}
