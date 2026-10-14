package online.wynos.food.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

/**
 * Buyer-scoped promotion/news inbox (not Messages/chat, and not proof of
 * coupon eligibility). Read only. A copied code must be quoted by the server
 * before any discount appears in checkout.
 */
data class FoodPromotionNotice(
    val id: String,
    val title: String,
    val body: String,
    val couponCode: String?,
    val createdAt: String,
    val readAt: String?,
) {
    /** Server read marker only; copying a coupon never marks it read. */
    val isUnread: Boolean get() = readAt == null
}
object FoodPromotionInboxParser {
    fun parse(raw: String): List<FoodPromotionNotice> = parse(Json.parseToJsonElement(raw))

    fun parse(raw: JsonElement): List<FoodPromotionNotice> {
        val rows = raw as? JsonArray
            ?: throw IllegalArgumentException("invalid_promotion_inbox")
        fun JsonObject.value(field: String) =
            (this[field] as? JsonPrimitive)?.contentOrNull?.trim()
        return rows.mapNotNull { element ->
            val row = element as? JsonObject ?: return@mapNotNull null
            val id = row.value("id")?.takeIf(String::isNotBlank) ?: return@mapNotNull null
            val title = row.value("title")?.takeIf(String::isNotBlank) ?: return@mapNotNull null
            FoodPromotionNotice(
                id = id,
                title = title.take(160),
                body = row.value("body").orEmpty().take(3000),
                couponCode = row.value("coupon_code")?.takeIf(String::isNotBlank)
                    ?.uppercase(java.util.Locale.ROOT)?.take(80),
                createdAt = row.value("created_at").orEmpty(),
                readAt = row.value("read_at")?.takeIf(String::isNotBlank),
            )
        }
    }
}
