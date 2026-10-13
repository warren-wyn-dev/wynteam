package online.wynos.food.data

import java.math.BigDecimal

/** Offline draft only. NEVER treated as server-confirmed checkout totals. */
data class SelectedOption(val groupId: String, val choiceId: String, val name: String, val price: String)

data class FoodCartLine(
    val menuId: String,
    val name: String,
    val basePrice: String,
    val options: List<SelectedOption>,
    val quantity: Int,
    val note: String = "",
) {
    val identity: String get() = menuId + ":" + options.joinToString("|") { it.groupId + "/" + it.choiceId } + ":" + note

    fun estimatedTotal(): BigDecimal {
        val unit = (basePrice.toBigDecimalOrNull() ?: BigDecimal.ZERO) +
            options.fold(BigDecimal.ZERO) { sum, choice -> sum + (choice.price.toBigDecimalOrNull() ?: BigDecimal.ZERO) }
        return unit * quantity.toBigDecimal()
    }
}

data class FoodCartDraft(
    val storeId: String? = null,
    val lines: List<FoodCartLine> = emptyList(),
) {
    val itemCount: Int get() = lines.sumOf { it.quantity }
    val estimatedSubtotal: BigDecimal get() = lines.fold(BigDecimal.ZERO) { sum, line -> sum + line.estimatedTotal() }

    fun add(store: FoodStore, menu: FoodMenu, selection: Map<String, Set<String>>, quantity: Int, note: String = ""): FoodCartDraft {
        require(store.isOpen && menu.isAvailable()) { "unavailable" }
        require(store.menu.any { it.id == menu.id }) { "not_in_store" }
        require(storeId == null || storeId == store.id) { "different_store" }
        require(quantity in 1..99) { "invalid_quantity" }
        require(note.length <= 250) { "note_too_long" }
        require(selection.keys.all { key -> menu.optionGroups.any { it.id == key } }) { "unknown_group" }

        val picked = menu.optionGroups.flatMap { group ->
            val ids = selection[group.id].orEmpty()
            require(ids.size <= group.maxSelect) { "too_many_options" }
            require(!group.required || ids.isNotEmpty()) { "required_option_missing" }
            require(ids.all { id -> group.choices.any { it.id == id } }) { "unknown_option" }
            group.choices.filter { it.id in ids }.map { SelectedOption(group.id, it.id, it.name, it.price) }
        }
        require(menu.price.toBigDecimalOrNull()?.let { it >= BigDecimal.ZERO } == true) { "invalid_price" }
        require(picked.all { it.price.toBigDecimalOrNull()?.let { n -> n >= BigDecimal.ZERO } == true }) { "invalid_option_price" }

        val incoming = FoodCartLine(menu.id, menu.name, menu.price, picked, quantity, note.trim())
        val existing = lines.find { it.identity == incoming.identity }
        val updated = if (existing == null) lines + incoming else {
            val combined = existing.quantity + quantity
            require(combined <= 99) { "quantity_limit" }
            lines.map { if (it.identity == incoming.identity) it.copy(quantity = combined) else it }
        }
        require(updated.size <= 50) { "cart_limit" }
        return FoodCartDraft(store.id, updated)
    }

    fun clear() = FoodCartDraft()
}
