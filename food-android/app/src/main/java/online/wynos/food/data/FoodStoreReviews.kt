package online.wynos.food.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull

/** Review contract returned by public.food_store_review_feed (same RPC as Web). */
data class FoodStoreReview(
    val id: String,
    val rating: Int,
    val text: String?,
    val tags: List<String>,
    val reviewerLabel: String,
    val verifiedOrder: Boolean,
    val createdAt: String,
    val merchantReply: String?,
)
data class FoodStoreReviewFeed(
    val average: Double,
    val count: Int,
    val reviews: List<FoodStoreReview>,
) {
    companion object {
        val EMPTY = FoodStoreReviewFeed(0.0, 0, emptyList())
    }
}

object FoodStoreReviewsParser {
    fun parse(raw: String): FoodStoreReviewFeed = parse(Json.parseToJsonElement(raw))

    fun parse(raw: JsonElement): FoodStoreReviewFeed {
        val obj = raw as? JsonObject ?: return FoodStoreReviewFeed.EMPTY
        fun JsonObject.str(key: String): String? =
            (this[key] as? JsonPrimitive)?.contentOrNull?.takeIf(String::isNotBlank)
        val average = (obj["average"] as? JsonPrimitive)?.doubleOrNull
            ?.takeIf { it.isFinite() && it in 0.0..5.0 } ?: 0.0
        val count = (obj["count"] as? JsonPrimitive)?.intOrNull
            ?.coerceAtLeast(0) ?: 0
        val reviews = (obj["reviews"] as? JsonArray)?.mapNotNull { element ->
            val row = element as? JsonObject ?: return@mapNotNull null
            val id = row.str("id") ?: return@mapNotNull null
            val rating = (row["rating"] as? JsonPrimitive)?.intOrNull
                ?.takeIf { it in 1..5 } ?: return@mapNotNull null
            FoodStoreReview(
                id = id,
                rating = rating,
                text = row.str("review_text"),
                tags = (row["tags"] as? JsonArray).orEmpty()
                    .mapNotNull { (it as? JsonPrimitive)?.contentOrNull }
                    .filter(String::isNotBlank).take(12),
                reviewerLabel = row.str("reviewer_label") ?: "ผู้ใช้ WYNOS Food",
                verifiedOrder = (row["verified_order"] as? JsonPrimitive)?.booleanOrNull == true,
                createdAt = row.str("created_at").orEmpty(),
                merchantReply = row.str("merchant_reply"),
            )
        }.orEmpty()
        return FoodStoreReviewFeed(average, count, reviews)
    }
}
