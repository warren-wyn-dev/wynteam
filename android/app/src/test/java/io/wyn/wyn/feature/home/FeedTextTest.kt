package io.wyn.wyn.feature.home

import io.wyn.wyn.core.data.FeedRow
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.ZoneOffset

class FeedTextTest {
    @Test fun trailingHashtagsSplitFromTheProse() {
        val split = FeedText.splitCaption("สวัสดี\n\n#WYNOS #Startup\n#Thai")
        assertEquals("สวัสดี", split.prose)
        assertEquals("#WYNOS #Startup\n#Thai", split.tags)
        assertFalse(split.truncated)
    }

    @Test fun longProseCutsAt190GraphemesNotCodeUnits() {
        val thai = "กิ้".repeat(200) // one grapheme, three code units
        val split = FeedText.splitCaption(thai)
        assertTrue(split.truncated)
        assertEquals(190, FeedText.graphemes(split.prose).size)
    }

    @Test fun compactCollapsesTheBlankLineBeforeTags() {
        assertEquals("text\n#tag", FeedText.compact("text\n\n#tag\n"))
    }

    @Test fun relativeTimeMatchesTheWeb() {
        val now = Instant.parse("2026-09-27T10:00:00Z")
        assertEquals("เมื่อสักครู่", FeedText.relativeTime("2026-09-27T09:59:30Z", false, now))
        assertEquals("5 นาที", FeedText.relativeTime("2026-09-27T09:55:00Z", false, now))
        assertEquals("2 ชม.", FeedText.relativeTime("2026-09-27 08:00:00+00", false, now))
        assertEquals("3 วัน", FeedText.relativeTime("2026-09-24T10:00:00Z", false, now))
        assertEquals("4 ก.ย.", FeedText.relativeTime("2026-09-04T10:00:00.000Z", false, now, ZoneOffset.UTC))
        assertEquals("2h", FeedText.relativeTime("2026-09-27T08:00:00Z", true, now))
        assertEquals("Sep 4", FeedText.relativeTime("2026-09-04T10:00:00Z", true, now, ZoneOffset.UTC))
        assertEquals("", FeedText.relativeTime("not a date", false, now))
    }

    @Test fun rankedRowsKeepOnlyDropsAndClampRatios() {
        val raw = Json.parseToJsonElement(
            """[{"row_data":{"id":"a","content_type":"drop","created_at":"2026-09-27T10:00:00Z","author_id":"u","image_width":4000,"image_height":1000,"like_count":"3"}},
                {"id":"b","content_type":"pop","created_at":"2026-09-27T10:00:00Z"},
                {"id":"c","content_type":"drop"}]""",
        ) as JsonElement
        val rows = FeedRow.parseList(raw, 10)
        assertEquals(listOf("a"), rows.map { it.id })
        assertEquals(3, rows[0].likeCount)
        assertEquals(1.91f, rows[0].mediaAspectRatio(false))
        assertEquals(0.8f, rows[0].copy(imageAspectRatio = "4:5").mediaAspectRatio(true))
        assertNull(rows[0].audience)
        assertTrue(rows[0].canRedrop)
    }
}
