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

/** Read-only reviewer data returned by public.food_store_review_feed(). */
data class FoodStoreReview(
    val id: String,
    val rating: Int,
    val text: String?,
    val tags: List<String>,
    val reviewerLabel: String,
    val verifiedOrder: Boolean,
    val createdAt: String?,
    val merchantReply: String?,
)
data class FoodStoreReviewFeed(
    val average: Double,
    val count: Int,
    val reviews: List<FoodStoreReview>,
)

/**
 * Strict server-result parsing. An absent/unavailable RPC is an error, NOT
 * "zero reviews": UI must distinguish a network/backend failure from empty.
 * Never infer a five-star rating or a verified purchase on the client.
 */
object FoodStoreReviewFeedParser {
    fun parse(raw: String): FoodStoreReviewFeed = parse(Json.parseToJsonElement(raw))

    fun parse(raw: JsonElement): FoodStoreReviewFeed {
        val response = raw as? JsonObject
            ?: throw IllegalArgumentException("invalid_store_review_feed")
        fun JsonObject.value(name: String): JsonPrimitive? = this[name] as? JsonPrimitive
        val count = response.value("count")?.intOrNull
            ?: throw IllegalArgumentException("invalid_review_count")
        require(count >= 0) { "invalid_review_count" }
        val average = response.value("average")?.doubleOrNull ?: 0.0
        require(average.isFinite() && average in 0.0..5.0) { "invalid_average" }
        val rows = response["reviews"] as? JsonArray
            ?: throw IllegalArgumentException("invalid_review_rows")
        val parsed = rows.mapNotNull { element ->
            val row = element as? JsonObject ?: return@mapNotNull null
            val id = row.value("id")?.contentOrNull?.trim().orEmpty()
            val rating = row.value("rating")?.intOrNull ?: return@mapNotNull null
            if (id.isBlank() || rating !in 1..5) return@mapNotNull null
            val tags = (row["tags"] as? JsonArray).orEmpty()
                .mapNotNull { (it as? JsonPrimitive)?.contentOrNull }
                .filter(String::isNotBlank).distinct().take(8)
            fun safeOptional(field: String): String? =
                row.value(field)?.contentOrNull?.trim()?.takeIf(String::isNotEmpty)
                    ?.take(1500)
            FoodStoreReview(
                id = id, rating = rating,
                text = safeOptional("review_text"),
                tags = tags,
                reviewerLabel = safeOptional("reviewer_label") ?: "WYNOS Food",
                verifiedOrder = row.value("verified_order")?.booleanOrNull == true,
                createdAt = safeOptional("created_at"),
                merchantReply = safeOptional("merchant_reply"),
            )
        }
        return FoodStoreReviewFeed(average = average, count = count, reviews = parsed)
    }
}
