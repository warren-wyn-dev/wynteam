package online.wynos.food.data

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

/** Visible to the owning WYNOS Account only through authenticated RLS-protected reads. */
data class FoodOrderSummary(
    val id: String,
    val number: String,
    val status: String,
    val paymentStatus: String,
    val total: String,
    val createdAt: String,
) {
    companion object {
        fun fromJson(row: JsonObject): FoodOrderSummary? {
            fun value(key: String) = (row[key] as? JsonPrimitive)?.contentOrNull
            val id = value("id")?.takeIf { it.isNotBlank() } ?: return null
            return FoodOrderSummary(
                id = id,
                number = value("order_number") ?: id.take(8),
                status = value("status") ?: "unknown",
                paymentStatus = value("payment_status") ?: "unknown",
                total = value("total") ?: "—",
                createdAt = value("created_at") ?: "",
            )
        }
    }
}
