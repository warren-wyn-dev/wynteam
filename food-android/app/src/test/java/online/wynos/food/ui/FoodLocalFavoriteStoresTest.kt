package online.wynos.food.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodLocalFavoriteStoresTest {
    @Test fun namespacesNormalizeEmailAndKeepAccountsSeparate() {
        val alice = favoriteNamespace(" Alice@Example.COM ")
        assertEquals(alice, favoriteNamespace("alice@example.com"))
        assertNotEquals(alice, favoriteNamespace("bob@example.com"))
        assertEquals(64, alice.length)
        assertFalse(alice.contains("@"))
        assertThrows(IllegalArgumentException::class.java) {
            favoriteNamespace("  ")
        }
    }

    @Test fun favoriteTogglesAreIdempotentAndNeverChangeOtherStores() {
        val first = toggleFavoriteId(emptySet(), "store-a")
        assertEquals(setOf("store-a"), first)
        val two = toggleFavoriteId(first, "store-b")
        assertEquals(setOf("store-a", "store-b"), two)
        val afterRemove = toggleFavoriteId(two, "store-a")
        assertEquals(setOf("store-b"), afterRemove)
        assertEquals(setOf("store-b"), toggleFavoriteId(afterRemove, "  "))
        assertTrue("store-a" in first)
    }
}
