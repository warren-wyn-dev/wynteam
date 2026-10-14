package online.wynos.food.ui

/**
 * Responsive geometry for WYNOS Food native UI.
 *
 * Width is the current, inset-adjusted COMPOSABLE viewport in dp (not physical
 * device pixels). All values below are visual geometry; minimum interactive
 * hit targets and system bar insets remain the responsibility of composables.
 * Independent of Android UI classes so widths can be regression tested.
 */
internal enum class FoodWindowBucket { TIGHT, COMPACT, MEDIUM, EXPANDED }

internal data class FoodAdaptiveLayout(
    val bucket: FoodWindowBucket,
    val horizontalPaddingDp: Float,
    val maxContentWidthDp: Float,
    val headerMaxWidthDp: Float,
    val navigationMaxWidthDp: Float,
    val searchVisualHeightDp: Float,
    val filterVisualSizeDp: Float,
    val heroHeightDp: Float,
    val storeCoverSizeDp: Float,
    val menuImageSizeDp: Float,
    val featuredGapDp: Float,
    val navVisualHeightDp: Float,
)

private fun Float.between(min: Float, max: Float): Float = coerceIn(min, max)

/**
 * Keep geometry stable across 320 / 360 / 390 / 412 / 430 and window resizing.
 * Desktop/foldable viewports center bounded content instead of stretching it.
 */
internal fun foodAdaptiveLayout(widthDp: Float): FoodAdaptiveLayout {
    val window = widthDp.coerceAtLeast(280f)
    val bucket = when {
        window < 360f -> FoodWindowBucket.TIGHT
        window < 600f -> FoodWindowBucket.COMPACT
        window < 840f -> FoodWindowBucket.MEDIUM
        else -> FoodWindowBucket.EXPANDED
    }
    val edge = when (bucket) {
        FoodWindowBucket.TIGHT -> 12f
        FoodWindowBucket.COMPACT -> 16f
        else -> 24f
    }
    val maxContent = when (bucket) {
        FoodWindowBucket.TIGHT, FoodWindowBucket.COMPACT -> window
        FoodWindowBucket.MEDIUM -> 720f
        FoodWindowBucket.EXPANDED -> 960f
    }
    val inner = maxContent.coerceAtMost(window)
    val hero = ((inner - edge * 2) / 2.30f).between(
        if (bucket == FoodWindowBucket.TIGHT) 132f else 140f,
        if (bucket == FoodWindowBucket.EXPANDED || bucket == FoodWindowBucket.MEDIUM) 200f else 172f,
    )
    return FoodAdaptiveLayout(
        bucket = bucket,
        horizontalPaddingDp = edge,
        maxContentWidthDp = maxContent,
        headerMaxWidthDp = if (window < 840f) minOf(window, 720f) else 960f,
        navigationMaxWidthDp = if (window < 600f) window else 720f,
        searchVisualHeightDp = 44f,
        filterVisualSizeDp = 44f,
        heroHeightDp = hero,
        storeCoverSizeDp = (inner * .26f + 14f).between(96f, 124f),
        menuImageSizeDp = (inner * .20f + 16f).between(84f, 120f),
        featuredGapDp = if (window < 360f) 8f else 10f,
        navVisualHeightDp = if (window < 360f) 62f else 66f,
    )
}
