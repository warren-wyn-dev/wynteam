package online.wynos.food.data

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

/**
 * Read-only order details. All records come from authenticated, RLS-protected reads.
 * Neither the client nor these models can change merchant or payment state.
 */
data class FoodOrderItemDetail(
    val name: String,
    val unitPrice: String,
    val quantity: Int,
    val options: List<String>,
    val note: String?,
)

data class FoodOrderEventDetail(
    val type: String,
    val toStatus: String?,
    val createdAt: String,
)

data class FoodOrderDetail(
    val id: String,
    val number: String,
    val status: String,
    val paymentStatus: String,
    val recipientName: String,
    val recipientPhone: String,
    val shippingAddress: String,
    val note: String?,
    val subtotal: String,
    val deliveryFee: String,
    val campaignDiscount: String,
    val deliveryDiscount: String,
    val total: String,
    val createdAt: String,
    val items: List<FoodOrderItemDetail>,
    val events: List<FoodOrderEventDetail>,
) {
    /** Closed and cancelled orders never appear to be still awaiting delivery. */
    val finished get() = status == "delivered" || status == "cancelled"
}

object FoodOrderDetailParser {
    fun fromRows(
        order: JsonObject,
        items: List<JsonObject>,
        events: List<JsonObject>,
    ): FoodOrderDetail {
        fun JsonObject.text(key: String): String? =
            (this[key] as? JsonPrimitive)?.contentOrNull

        val id = order.text("id")?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("missing_order_id")
        val status = order.text("status").orEmpty()
        require(status in setOf(
            "pending_acceptance", "preparing", "ready_for_delivery",
            "out_for_delivery", "delivered", "cancelled"
        )) { "unknown_order_status" }

        return FoodOrderDetail(
            id = id,
            number = order.text("order_number") ?: id.take(8),
            status = status,
            paymentStatus = order.text("payment_status").orEmpty(),
            recipientName = order.text("recipient_name").orEmpty(),
            recipientPhone = order.text("recipient_phone").orEmpty(),
            shippingAddress = order.text("shipping_address").orEmpty(),
            note = order.text("customer_note"),
            subtotal = order.text("subtotal") ?: "—",
            deliveryFee = order.text("delivery_fee") ?: "—",
            campaignDiscount = order.text("campaign_discount") ?: "0",
            deliveryDiscount = order.text("delivery_discount") ?: "0",
            total = order.text("total") ?: "—",
            createdAt = order.text("created_at").orEmpty(),
            items = items.mapNotNull { item ->
                val name = item.text("item_name")?.takeIf { it.isNotBlank() }
                    ?: return@mapNotNull null
                val count = item.text("quantity")?.toIntOrNull() ?: return@mapNotNull null
                if (count !in 1..99) return@mapNotNull null
                val selected = item["selected_options"] as? JsonArray
                FoodOrderItemDetail(
                    name = name,
                    unitPrice = item.text("unit_price") ?: "—",
                    quantity = count,
                    options = selected.orEmpty().mapNotNull { option ->
                        (option as? JsonObject)?.let {
                            it.text("choice_name")?.takeIf(String::isNotBlank)
                                ?: it.text("name")?.takeIf(String::isNotBlank)
                        }
                    },
                    note = item.text("item_note"),
                )
            },
            events = events.mapNotNull { event ->
                val type = event.text("event_type") ?: return@mapNotNull null
                FoodOrderEventDetail(
                    type = type,
                    toStatus = event.text("to_status"),
                    createdAt = event.text("created_at").orEmpty(),
                )
            }.sortedBy { it.createdAt },
        )
    }
}
