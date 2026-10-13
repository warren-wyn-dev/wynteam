package online.wynos.food.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodCheckoutModelsTest {
    private val menu = FoodMenu("menu-1","Test food","Main",null,"60",emptyList())
    private val store = FoodStore("store-1","Test",null,true,"10",listOf(menu))
    private val cart = FoodCartDraft().add(store,menu,emptyMap(),2, "ไม่ใส่ผัก")

    @Test fun quoteRequestIncludesServerIdsButNotClientPricesOrNotes() {
        val request = FoodQuoteRequest.fromCart(cart, null).toString()
        assertTrue(request.contains("store-1"))
        assertTrue(request.contains("menu-1"))
        assertFalse(request.contains("ไม่ใส่ผัก"))
        assertFalse(request.contains("basePrice"))
        assertTrue(request.contains("p_latitude"))
    }
    @Test fun readOnlyQuoteHasDiscountAndServerTotal() {
        val json = Json.parseToJsonElement("""{"subtotal":120,"delivery_fee":15,"campaign_discount":40,"delivery_discount":0,"total":95,"delivery_needs_location":false,"campaign_name":"New"}""")
        val quote = FoodServerQuote.parse(json)
        assertEquals("95", quote.total.stripTrailingZeros().toPlainString())
        assertEquals("New", quote.campaignName)
    }
    @Test(expected = IllegalArgumentException::class)
    fun rejectsInconsistentQuote() {
        FoodServerQuote.parse(Json.parseToJsonElement("""{"subtotal":100,"delivery_fee":10,"campaign_discount":0,"delivery_discount":0,"total":1}"""))
    }
    @Test fun addressParserPrefersDefaultWithoutInventingPins() {
        val rows = Json.parseToJsonElement("""[{"id":"a1","label":"บ้าน","recipient_name":"A","recipient_phone":"081","address":"A Rd","is_default":true},{"id":"a2","label":"ที่ทำงาน","address":"B Rd","latitude":150,"longitude":180}]""") as kotlinx.serialization.json.JsonArray
        val parsed = FoodAddressParser.parse(rows.map { it as JsonObject })
        assertEquals("a1", parsed.first().id)
        assertFalse(parsed[0].validPin)
        assertFalse(parsed[1].validPin)
    }
    @Test(expected = IllegalArgumentException::class)
    fun refusesEmptyCartQuote() {
        FoodQuoteRequest.fromCart(FoodCartDraft(), null)
    }
}
