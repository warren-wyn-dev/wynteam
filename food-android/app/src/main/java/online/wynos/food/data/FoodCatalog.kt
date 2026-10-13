package online.wynos.food.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
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

data class FoodMenu(
    val id: String,
    val name: String,
    val category: String,
    val description: String?,
    val price: String,
    val optionGroupNames: List<String>,
)

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
                FoodMenu(
                    id = menuId,
                    name = menuName,
                    category = menu.text("category").orEmpty(),
                    description = menu.text("description"),
                    price = menu.text("price").orEmpty().toPriceLabel(),
                    optionGroupNames = groups,
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
