package online.wynos.food.ui

import org.junit.Assert.assertEquals
import org.junit.Test

/** Store grid breakpoints must match web/app/food/food-app.css. */
class FoodHomeVisualParityTest {
    @Test fun phoneStoreGridUsesTwoColumnsLikeWebsite() {
        listOf(320f, 360f, 390f, 430f, 600f, 679f).forEach { width ->
            assertEquals("Incorrect grid at ${width}dp", 2, homeGridColumnsForWidth(width))
        }
    }

    @Test fun compactHomeUsesSmallScreenTokensWithoutChangingGridCount() {
        listOf(320f, 360f, 390f, 399f).forEach { width ->
            assertEquals("Expected compact Home at ${width}dp", true, compactFoodHomeForWidth(width))
            assertEquals("Compact Home must still use two columns at ${width}dp", 2, homeGridColumnsForWidth(width))
        }
        listOf(400f, 430f, 680f).forEach { width ->
            assertEquals("Expected standard Home at ${width}dp", false, compactFoodHomeForWidth(width))
        }
    }

    @Test fun wideStoreGridUsesThreeColumnsLikeWebsite() {
        listOf(680f, 720f, 800f).forEach { width ->
            assertEquals("Incorrect grid at ${width}dp", 3, homeGridColumnsForWidth(width))
        }
    }
}
