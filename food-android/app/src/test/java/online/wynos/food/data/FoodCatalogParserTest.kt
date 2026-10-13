package online.wynos.food.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodCatalogParserTest {
    @Test fun readsTheSamePublicFieldsAsTheWebsite() {
        val json = """
            [
              {
                "id": "store-one", "name": "ร้านทดสอบ", "description": null, "is_open": true,
                "delivery_fee": 15.00, "address": "not copied into Android model",
                "menu": [
                  {"id": "menu-one", "name": "ผัดไทย", "category": "อาหารไทย",
                   "price": 65.00, "description": "สดใหม่",
                   "options":[{"id":"group-1","name":"ระดับความเผ็ด"}]},
                  {"id": "menu-two", "name": "แกง", "price": "80.50", "options":[]}
                ]
              },
              {"id":"store-two","name":"ร้านปิดชั่วคราว","is_open":false,"menu":[]}
            ]
        """.trimIndent()
        val result = FoodCatalogParser.parse(json)
        assertEquals(2, result.size)
        assertTrue(result[0].isOpen)
        assertEquals("15", result[0].deliveryFee)
        assertEquals("65", result[0].menu[0].price)
        assertEquals(listOf("ระดับความเผ็ด"), result[0].menu[0].optionGroupNames)
        assertEquals("80.5", result[0].menu[1].price)
        assertFalse(result[1].isOpen)
    }

    @Test fun handlesMissingOptionalFieldsAndSkipsMalformedRows() {
        val stores = FoodCatalogParser.parse("""
            [{"id":"a","name":"ร้าน A","menu":[{"id":"m","name":"เมนู","price":20}]},
             {"id":"","name":"invalid"},{"name":"unnamed"}]
        """.trimIndent())
        assertEquals(1, stores.size)
        assertEquals(1, stores.single().menu.size)
        assertFalse(stores.single().isOpen)
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsUnexpectedRpcPayloadInsteadOfShowingFakeData() {
        FoodCatalogParser.parse("""{"error":"not an array"}""")
    }
}
