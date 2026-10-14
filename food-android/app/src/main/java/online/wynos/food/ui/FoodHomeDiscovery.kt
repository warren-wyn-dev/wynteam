package online.wynos.food.ui

import online.wynos.food.data.FoodStore

/**
 * Native discovery uses only fields from the real published food_public_catalog.
 * Ratings, ETA, distance, personalised recommendations and promotions are NOT
 * available from this RPC and must never be synthesized in the UI.
 */
internal fun visibleHomeStores(
    stores: List<FoodStore>,
    search: String,
    filter: String,
): List<FoodStore> {
    val text = search.trim()
    val matched = stores.distinctBy { it.id }.filter { store ->
        (text.isEmpty() ||
            store.name.contains(text, ignoreCase = true) ||
            store.menu.any { it.name.contains(text, ignoreCase = true) }) &&
            when {
                filter == "open" -> store.isOpen
                filter.startsWith("category:") -> {
                    val category = filter.removePrefix("category:")
                    store.menu.any { it.category.trim() == category }
                }
                else -> true
            }
    }
    // Unknown delivery fees are always last, never misrepresented as free.
    return if (filter == "fee") {
        matched.sortedWith(
            compareBy<FoodStore> { it.deliveryFee?.toBigDecimalOrNull() == null }
                .thenBy { it.deliveryFee?.toBigDecimalOrNull() }
        )
    } else matched
}

/** Only actual menu categories in the published catalog may appear as filters. */
internal fun publishedHomeCategories(stores: List<FoodStore>): List<String> =
    stores.flatMap { store -> store.menu.map { it.category.trim() } }
        .filter { it.isNotBlank() }
        .distinct()
        .take(12)

internal fun canSortHomeByDeliveryFee(stores: List<FoodStore>): Boolean =
    stores.any { it.deliveryFee?.toBigDecimalOrNull() != null }
