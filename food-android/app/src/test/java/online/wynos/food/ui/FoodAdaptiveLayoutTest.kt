package online.wynos.food.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodAdaptiveLayoutTest {
    @Test fun phoneBreakpointsUseFluidWidthAndCompactComponents() {
        val tight = foodAdaptiveLayout(320f)
        assertEquals(FoodWindowBucket.TIGHT, tight.bucket)
        assertEquals(12f, tight.horizontalPaddingDp)
        for (width in listOf(360f, 390f, 412f, 430f)) {
            val layout = foodAdaptiveLayout(width)
            assertEquals(FoodWindowBucket.COMPACT, layout.bucket)
            assertEquals(width, layout.maxContentWidthDp)
            assertEquals(16f, layout.horizontalPaddingDp)
            assertEquals(44f, layout.searchVisualHeightDp)
            assertEquals(44f, layout.filterVisualSizeDp)
            assertTrue(layout.heroHeightDp in 140f..172f)
            assertTrue(layout.menuImageSizeDp in 84f..120f)
        }
    }

    @Test fun foodImagesStaySquareAndScaleMonotonicallyOnPhones() {
        val sizes = listOf(320f, 360f, 390f, 430f, 600f)
            .map { foodAdaptiveLayout(it).menuImageSizeDp }
        assertTrue(sizes.zipWithNext().all { (a, b) -> a <= b })
        assertEquals(88f, foodAdaptiveLayout(360f).menuImageSizeDp)
        assertEquals(94f, foodAdaptiveLayout(390f).menuImageSizeDp)
        assertEquals(102f, foodAdaptiveLayout(430f).menuImageSizeDp)
    }

    @Test fun tabletsCenterBoundedContentAndDontStretchCards() {
        val medium = foodAdaptiveLayout(720f)
        val expanded = foodAdaptiveLayout(1200f)
        assertEquals(FoodWindowBucket.MEDIUM, medium.bucket)
        assertEquals(720f, medium.maxContentWidthDp)
        assertEquals(FoodWindowBucket.EXPANDED, expanded.bucket)
        assertEquals(960f, expanded.maxContentWidthDp)
        assertEquals(720f, expanded.navigationMaxWidthDp)
        assertEquals(120f, expanded.menuImageSizeDp)
        assertEquals(200f, expanded.heroHeightDp)
    }

    @Test fun resizableAndVerySmallWindowsNeverGenerateInvalidSizes() {
        for (width in listOf(1f, 280f, 320f, 359f, 599f, 600f, 839f, 840f, 2800f)) {
            val m = foodAdaptiveLayout(width)
            assertTrue(m.menuImageSizeDp > 0f)
            assertTrue(m.storeCoverSizeDp in 96f..124f)
            assertTrue(m.heroHeightDp in 132f..200f)
            assertTrue(m.maxContentWidthDp > 0f)
        }
    }
}
