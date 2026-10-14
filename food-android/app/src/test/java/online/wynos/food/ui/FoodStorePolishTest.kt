package online.wynos.food.ui

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Store header must not repeat identical place/address copy. The actual
 * store facts come from published catalog fields, never fake mockup values.
 */
class FoodStorePolishTest {
    @Test fun identicalAddressAndDescriptionShownOnce() {
        assertFalse(shouldShowStoreDescription("หอพักราชาทิพย์", "หอพักราชาทิพย์"))
        assertFalse(shouldShowStoreDescription("  หอพัก ราชาทิพย์  ", "หอพักราชาทิพย์"))
        assertFalse(shouldShowStoreDescription("", "ที่อยู่ร้าน"))
        assertFalse(shouldShowStoreDescription(null, "ที่อยู่ร้าน"))
    }

    @Test fun meaningfulDistinctDescriptionStillVisible() {
        assertTrue(shouldShowStoreDescription("อาหารอีสานปรุงสด", "หอพักราชาทิพย์"))
        assertTrue(shouldShowStoreDescription("มีเมนูอาหารตามสั่ง", null))
    }
}
