package online.wynos.food.data

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.put
import java.math.BigDecimal

/** Customer-owned address. Must be read with authenticated RLS AND user_id filtering. */
data class FoodCustomerAddress(
    val id: String,
    val label: String,
    val recipientName: String,
    val recipientPhone: String,
    val address: String,
    val deliveryNote: String?,
    val isDefault: Boolean,
    val latitude: Double?,
    val longitude: Double?,
    val addressLine1: String = "",
    val moo: String = "",
    val soi: String = "",
    val road: String = "",
    val subdistrict: String = "",
    val district: String = "",
    val province: String = "",
    val postalCode: String = "",
    val buildingName: String = "",
    val floor: String = "",
    val room: String = "",
    val landmark: String = "",
) {
    val validPin: Boolean get() =
        latitude != null && longitude != null &&
            latitude.isFinite() && longitude.isFinite() &&
            latitude in -90.0..90.0 && longitude in -180.0..180.0
}

object FoodAddressParser {
    fun parse(raw: List<JsonObject>): List<FoodCustomerAddress> = raw.mapNotNull { r ->
        fun text(key: String) = (r[key] as? JsonPrimitive)?.contentOrNull
        fun number(key: String) = (r[key] as? JsonPrimitive)?.doubleOrNull
        val id = text("id")?.takeIf { it.isNotBlank() } ?: return@mapNotNull null
        FoodCustomerAddress(
            id = id, label = text("label").orEmpty(),
            recipientName = text("recipient_name").orEmpty(),
            recipientPhone = text("recipient_phone").orEmpty(),
            address = text("address").orEmpty(),
            deliveryNote = text("delivery_note"),
            isDefault = text("is_default") == "true",
            latitude = number("latitude"), longitude = number("longitude"),
            addressLine1 = text("address_line1").orEmpty().ifBlank { text("address").orEmpty() },
            moo = text("moo").orEmpty(), soi = text("soi").orEmpty(),
            road = text("road").orEmpty(), subdistrict = text("subdistrict").orEmpty(),
            district = text("district").orEmpty(), province = text("province").orEmpty(),
            postalCode = text("postal_code").orEmpty(),
            buildingName = text("building_name").orEmpty(),
            floor = text("floor").orEmpty(), room = text("room").orEmpty(),
            landmark = text("landmark").orEmpty(),
        )
    }.sortedWith(compareByDescending<FoodCustomerAddress> { it.isDefault }.thenBy { it.label })
}

/** Server is authoritative for delivery fees, promotions, discounts and order totals. */
data class FoodServerQuote(
    val subtotal: BigDecimal,
    val deliveryFee: BigDecimal,
    val campaignDiscount: BigDecimal,
    val deliveryDiscount: BigDecimal,
    val total: BigDecimal,
    val campaignName: String?,
    val needsLocation: Boolean,
    val deliveryDistanceKm: Double?,
) {
    companion object {
        fun parse(raw: JsonElement): FoodServerQuote {
            val data = raw as? JsonObject ?: throw IllegalArgumentException("invalid_quote")
            fun money(k: String): BigDecimal {
                val v = (data[k] as? JsonPrimitive)?.contentOrNull
                val n = v?.toBigDecimalOrNull() ?: throw IllegalArgumentException("invalid_$k")
                require(n >= BigDecimal.ZERO && n.scale() <= 4) { "invalid_$k" }
                return n
            }
            val discount = money("campaign_discount")
            val deliveryDiscount = money("delivery_discount")
            val subtotal = money("subtotal")
            val delivery = money("delivery_fee")
            val total = money("total")
            val calculated = (subtotal + delivery - discount - deliveryDiscount).max(BigDecimal.ZERO)
            require(calculated.subtract(total).abs() <= BigDecimal("0.01")) { "inconsistent_quote" }
            return FoodServerQuote(
                subtotal, delivery, discount, deliveryDiscount, total,
                (data["campaign_name"] as? JsonPrimitive)?.contentOrNull,
                (data["delivery_needs_location"] as? JsonPrimitive)?.booleanOrNull == true,
                (data["delivery_distance_km"] as? JsonPrimitive)?.doubleOrNull,
            )
        }
    }
}

/**
 * Exact website quote contract: JSON p_items with IDs, selected_options, quantity.
 * Ignore client display names / prices / notes; the server resolves prices.
 */
object FoodQuoteRequest {
    fun fromCart(cart: FoodCartDraft, address: FoodCustomerAddress?): JsonObject {
        require(!cart.storeId.isNullOrBlank() && cart.lines.isNotEmpty()) { "empty_cart" }
        require(cart.lines.size <= 50) { "cart_limit" }
        val coordinates = address?.takeIf { it.validPin }
        return buildJsonObject {
            put("p_store_id", cart.storeId)
            put("p_items", buildJsonArray {
                cart.lines.forEach { line ->
                    require(line.quantity in 1..99) { "invalid_quantity" }
                    add(buildJsonObject {
                        put("menu_item_id", line.menuId)
                        put("quantity", line.quantity)
                        put("selected_options", buildJsonArray {
                            line.options.forEach { choice ->
                                add(buildJsonObject {
                                    put("group_id", choice.groupId)
                                    put("choice_id", choice.choiceId)
                                })
                            }
                        })
                    })
                }
            })
            if (coordinates == null) {
                put("p_latitude", JsonNull)
                put("p_longitude", JsonNull)
            } else {
                put("p_latitude", coordinates.latitude!!)
                put("p_longitude", coordinates.longitude!!)
            }
        }
    }
}
