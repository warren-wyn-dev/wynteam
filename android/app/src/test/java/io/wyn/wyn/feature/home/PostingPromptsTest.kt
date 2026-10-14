package io.wyn.wyn.feature.home

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate

class PostingPromptsTest {
    @Test fun keysMatchWebAndFirstPostHasThreeSuggestions() {
        assertEquals(listOf("first-intro", "first-today", "first-question"), PostingPrompts.first.map { it.key })
        assertEquals(listOf(
            "daily-now", "daily-listening", "daily-smallwin",
            "daily-question", "daily-photo", "daily-interest", "daily-weekend",
        ), PostingPrompts.daily.map { it.key })
    }

    @Test fun dailyRotationUsesLocalDayOfYearLikeWeb() {
        assertEquals("daily-listening", PostingPrompts.forDay(LocalDate.of(2026, 1, 1)).key)
        assertEquals("daily-smallwin", PostingPrompts.forDay(LocalDate.of(2026, 1, 2)).key)
        assertEquals("daily-now", PostingPrompts.forDay(LocalDate.of(2026, 1, 7)).key)
    }

    @Test fun unknownKeyDoesNotCreateAnAccidentalDraft() {
        assertNull(PostingPrompts.byKey("unknown"))
        assertEquals(PostingPrompts.first[0], PostingPrompts.byKey("first-intro"))
        assertEquals("Introduce yourself to everyone", PostingPrompts.first[0].localized(true))
    }
}
