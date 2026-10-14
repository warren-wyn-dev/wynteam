package online.wynos.food.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class FoodPromotionInboxParserTest {
    @Test fun parsesActualBuyerPromotionAndCopiesCodeOnlyAsText() {
        val rows = FoodPromotionInboxParser.parse(
            """[{"id":"notice-a","title":"โปรโมชัน WYNOS Food",
                "body":"รับสิทธิ์เมื่อครบเงื่อนไข","coupon_code":" welcome40 ",
                "created_at":"2026-10-15T03:00:00Z","read_at":null},
                {"id":"notice-b","title":"ข่าวสาร","body":"แจ้งข่าว",
                 "coupon_code":null,"read_at":"2026-10-14T00:00:00Z"}]"""
        )
        assertEquals(2, rows.size)
        assertEquals("WELCOME40", rows[0].couponCode)
        assertEquals("โปรโมชัน WYNOS Food", rows[0].title)
        assertNull(rows[0].readAt)
        assertNull(rows[1].couponCode)
        assertEquals("2026-10-14T00:00:00Z", rows[1].readAt)
    }

    @Test fun rejectsNonArrayPayloadAndUnknownRecords() {
        assertThrows(IllegalArgumentException::class.java) {
            FoodPromotionInboxParser.parse("""{"id":"notice"}""")
        }
        val rows = FoodPromotionInboxParser.parse(
            """[{"id":"one","body":"no title"},{"id":"two","title":"Valid","body":""}]"""
        )
        assertEquals(1, rows.size)
        assertEquals("two", rows.single().id)
    }
}
