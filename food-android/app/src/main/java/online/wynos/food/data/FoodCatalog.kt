package online.wynos.food.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import java.math.BigDecimal

/**
 * Shape matches public.food_public_catalog() from
 * supabase/migrations/20261010120000_food_public_guest_catalog.sql.
 *
 * Only published, non-suspended storefront and menu fields are present.
 * No customer addresses, orders, merchant-only data, or privileged queries.
 */
data class FoodStore(
    val id: String,
    val name: String,
    val description: String?,
    val isOpen: Boolean,
    val deliveryFee: String?,
    val menu: List<FoodMenu>,
)

data class FoodOptionChoice(val id: String, val name: String, val price: String)

data class FoodOptionGroup(
    val id: String,
    val name: String,
    val required: Boolean,
    val maxSelect: Int,
    val choices: List<FoodOptionChoice>,
)

data class FoodMenu(
    val id: String,
    val name: String,
    val category: String,
    val description: String?,
    val price: String,
    val optionGroupNames: List<String>,
    val optionGroups: List<FoodOptionGroup> = emptyList(),
    val soldOutUntil: String? = null,
    val dailyStockLimit: Int? = null,
) {
    fun isAvailable(now: java.time.Instant = java.time.Instant.now()): Boolean {
        if (dailyStockLimit != null && dailyStockLimit <= 0) return false
        val soldOut = soldOutUntil?.let { runCatching { java.time.Instant.parse(it) }.getOrNull() }
        return soldOut == null || !soldOut.isAfter(now)
    }
}


object FoodCatalogParser {
    fun parse(raw: String): List<FoodStore> =
        parse(Json.parseToJsonElement(raw))

    fun parse(raw: JsonElement): List<FoodStore> {
        val array = raw as? JsonArray
            ?: throw IllegalArgumentException("food_public_catalog must be an array")
        return array.mapNotNull { item ->
            val row = item as? JsonObject ?: return@mapNotNull null
            val id = row.text("id")?.takeIf(String::isNotBlank) ?: return@mapNotNull null
            val name = row.text("name")?.takeIf(String::isNotBlank) ?: return@mapNotNull null
            val menus = (row["menu"] as? JsonArray).orEmpty().mapNotNull { menuElement ->
                val menu = menuElement as? JsonObject ?: return@mapNotNull null
                val menuId = menu.text("id")?.takeIf(String::isNotBlank) ?: return@mapNotNull null
                val menuName = menu.text("name")?.takeIf(String::isNotBlank) ?: return@mapNotNull null
                val groups = (menu["options"] as? JsonArray).orEmpty().mapNotNull {
                    (it as? JsonObject)?.text("name")?.takeIf(String::isNotBlank)
                }
                val optionGroups = (menu["options"] as? JsonArray).orEmpty().mapNotNull { groupElement ->
                    val group = groupElement as? JsonObject ?: return@mapNotNull null
                    val groupId = group.text("id")?.takeIf(String::isNotBlank) ?: return@mapNotNull null
                    val groupName = group.text("name")?.takeIf(String::isNotBlank) ?: return@mapNotNull null
                    val choices = (group["choices"] as? JsonArray).orEmpty().mapNotNull { choiceElement ->
                        val choice = choiceElement as? JsonObject ?: return@mapNotNull null
                        val choiceId = choice.text("id")?.takeIf(String::isNotBlank) ?: return@mapNotNull null
                        val choiceName = choice.text("name")?.takeIf(String::isNotBlank) ?: return@mapNotNull null
                        FoodOptionChoice(choiceId, choiceName, choice.text("price").orEmpty().toPriceLabel())
                    }
                    FoodOptionGroup(
                        id = groupId,
                        name = groupName,
                        required = (group["required"] as? JsonPrimitive)?.booleanOrNull == true,
                        maxSelect = (group["max_select"] as? JsonPrimitive)?.intOrNull?.coerceIn(1, 50) ?: 1,
                        choices = choices,
                    )
                }
                FoodMenu(
                    id = menuId,
                    name = menuName,
                    category = menu.text("category").orEmpty(),
                    description = menu.text("description"),
                    price = menu.text("price").orEmpty().toPriceLabel(),
                    optionGroupNames = groups,
                    optionGroups = optionGroups,
                    soldOutUntil = menu.text("sold_out_until"),
                    dailyStockLimit = (menu["daily_stock_limit"] as? JsonPrimitive)?.intOrNull,
                )
            }
            FoodStore(
                id = id,
                name = name,
                description = row.text("description"),
                isOpen = (row["is_open"] as? JsonPrimitive)?.booleanOrNull == true,
                deliveryFee = row.text("delivery_fee")?.toPriceLabel(),
                menu = menus,
            )
        }
    }

    private fun JsonObject.text(field: String): String? =
        (get(field) as? JsonPrimitive)?.contentOrNull

    private fun String.toPriceLabel(): String =
        toBigDecimalOrNull()?.takeIf { it >= BigDecimal.ZERO }
            ?.stripTrailingZeros()?.toPlainString() ?: "—"
}
