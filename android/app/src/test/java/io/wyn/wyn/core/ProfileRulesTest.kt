package io.wyn.wyn.core

import io.wyn.wyn.core.data.ExternalUrl
import io.wyn.wyn.core.data.FeedRow
import io.wyn.wyn.core.data.mergePostsAndQuotes
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ProfileRulesTest {
    @Test fun websitesAreNormalizedLikeTheWeb() {
        assertEquals("https://example.com/", ExternalUrl.normalize("example.com"))
        assertEquals("http://Shop.example.com/a?b=1".replace("Shop", "shop"), ExternalUrl.normalize(" http://Shop.example.com/a?b=1 "))
        assertNull(ExternalUrl.normalize("javascript:alert(1)"))
        assertNull(ExternalUrl.normalize("ftp://example.com"))
        assertNull(ExternalUrl.normalize("hello"))
        assertNull(ExternalUrl.normalize("https://example.com/" + "a".repeat(300)))
        assertEquals("wynos.online", ExternalUrl.label("https://wynos.online/"))
        assertEquals("wynos.online/shop", ExternalUrl.label("https://wynos.online/shop/"))
    }

    @Test fun postsAndQuotesMergeNewestFirstThenPage() {
        fun drop(id: String, at: String) = FeedRow(id = id, authorId = "a", createdAt = at)
        fun quote(id: String, at: String) = FeedRow(id = "d", authorId = "a", createdAt = at, redropId = id, redropperId = "a", quoteText = "q")
        val posts = listOf(drop("p1", "2026-09-03T00:00:00Z"), drop("p2", "2026-09-01T00:00:00Z"))
        val quotes = listOf(quote("q1", "2026-09-02T00:00:00Z"), FeedRow(id = "x", authorId = "a", createdAt = "2026-09-04T00:00:00Z", redropId = "r"))
        val merged = mergePostsAndQuotes(posts, quotes, page = 0, pageSize = 2)
        assertEquals(listOf("p1", "d"), merged.map { it.id })
        assertEquals(listOf("p2"), mergePostsAndQuotes(posts, quotes, page = 1, pageSize = 2).map { it.id })
    }
}
