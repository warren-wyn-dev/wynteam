package online.wynos.food.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodHomeBannerParserTest {
    @Test fun displaysOnlyValidBannerEntries() {
        val rows = FoodHomeBannerParser.parse("""[{"id":"a","title":"โปรวันนี้","subtitle":"ลดเพิ่ม","image_path":"2026/promo.png","destination_store_id":"s1"},{"id":"b","title":"missing photo"}]""")
        assertEquals(1, rows.size)
        assertEquals("โปรวันนี้", rows[0].title)
        assertEquals("s1", rows[0].destinationStoreId)
    }

    @Test fun missingOptionalBannersIsNotAnError() {
        assertTrue(FoodHomeBannerParser.parse("{}").isEmpty())
    }
}
