package online.wynos.food.data

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.ZoneId

class FoodDisplayFormatTest {
    private val bangkok = ZoneId.of("Asia/Bangkok")

    @Test fun thaiDatesUseReadableThaiMonthBuddhistYearAndLocalTime() {
        assertEquals(
            "8 ต.ค. 2569 · 18:36 น.",
            FoodDisplayFormat.orderDate("2026-10-08T11:36:00Z", "th", bangkok),
        )
        assertEquals(
            "8 Oct 2026 · 18:36",
            FoodDisplayFormat.orderDate("2026-10-08T11:36:00+00:00", "en", bangkok),
        )
    }

    @Test fun invalidOrMissingTimestampsNeverThrowOrDisplayGarbageCutoff() {
        assertEquals("", FoodDisplayFormat.orderDate("", "th", bangkok))
        assertEquals("unknown", FoodDisplayFormat.orderDate("unknown", "th", bangkok))
        assertEquals(
            "8 ต.ค. 2569 · 18:36 น.",
            FoodDisplayFormat.orderDate("2026-10-08T18:36:00", "th", bangkok),
        )
    }
}
