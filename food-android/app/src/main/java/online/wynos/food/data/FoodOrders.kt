package online.wynos.food.data

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Visible to the owning WYNOS Account only through authenticated RLS-protected reads. */
data class FoodOrderSummary(
    val id: String,
    val number: String,
    val status: String,
    val paymentStatus: String,
    val total: String,
    val createdAt: String,
    val storeId: String? = null,
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
                storeId = value("store_id")?.takeIf(String::isNotBlank),
            )
        }
    }
}

/** Format the stored UTC/offset timestamp in the device's timezone and active UI locale. */
fun formatFoodOrderDateTime(
    raw: String,
    locale: Locale,
    zone: ZoneId,
): String {
    val instant = runCatching { Instant.parse(raw) }.getOrNull()
        ?: runCatching { OffsetDateTime.parse(raw).toInstant() }.getOrNull()
        ?: return raw.replace('T', ' ').take(16)
    return DateTimeFormatter.ofPattern("d MMM yyyy, HH:mm", locale)
        .withZone(zone)
        .format(instant)
}
