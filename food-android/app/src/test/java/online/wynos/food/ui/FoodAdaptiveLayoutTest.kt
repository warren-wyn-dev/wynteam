package online.wynos.food.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodAdaptiveLayoutTest {
    @Test fun phoneBreakpointsUseFluidWidthAndCompactComponents() {
        val tight = foodAdaptiveLayout(320f)
        assertEquals(FoodWindowBucket.TIGHT, tight.bucket)
        assertEquals(12f, tight.horizontalPaddingDp, .001f)
        for (width in listOf(360f, 390f, 412f, 430f)) {
            val layout = foodAdaptiveLayout(width)
            assertEquals(FoodWindowBucket.COMPACT, layout.bucket)
            assertEquals(width, layout.maxContentWidthDp, .001f)
            assertEquals(16f, layout.horizontalPaddingDp, .001f)
            assertEquals(44f, layout.searchVisualHeightDp, .001f)
            assertEquals(44f, layout.filterVisualSizeDp, .001f)
            assertTrue(layout.heroHeightDp in 140f..172f)
            assertTrue(layout.menuImageSizeDp in 84f..120f)
        }
    }

    @Test fun foodImagesStaySquareAndScaleMonotonicallyOnPhones() {
        val sizes = listOf(320f, 360f, 390f, 430f, 600f)
            .map { foodAdaptiveLayout(it).menuImageSizeDp }
        assertTrue(sizes.zipWithNext().all { (a, b) -> a <= b })
        assertEquals(88f, foodAdaptiveLayout(360f).menuImageSizeDp, .01f)
        assertEquals(94f, foodAdaptiveLayout(390f).menuImageSizeDp, .01f)
        assertEquals(102f, foodAdaptiveLayout(430f).menuImageSizeDp, .01f)
    }

    @Test fun tabletsCenterBoundedContentAndDontStretchCards() {
        val medium = foodAdaptiveLayout(720f)
        val expanded = foodAdaptiveLayout(1200f)
        assertEquals(FoodWindowBucket.MEDIUM, medium.bucket)
        assertEquals(720f, medium.maxContentWidthDp, .001f)
        assertEquals(FoodWindowBucket.EXPANDED, expanded.bucket)
        assertEquals(960f, expanded.maxContentWidthDp, .001f)
        assertEquals(720f, expanded.navigationMaxWidthDp, .001f)
        assertEquals(120f, expanded.menuImageSizeDp, .001f)
        assertEquals(200f, expanded.heroHeightDp, .001f)
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
