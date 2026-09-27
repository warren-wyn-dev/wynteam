package io.wyn.wyn.core.data

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull

/** One Home feed row: the web's HomeFeedRow (web/lib/feed.ts), from the home_feed view or ranked RPC. */
data class FeedRow(
    val id: String,
    val authorId: String,
    val createdAt: String,
    val contentType: String = "drop",
    val authorUsername: String? = null,
    val authorDisplayName: String? = null,
    val authorAvatarUrl: String? = null,
    val authorIsVerified: Boolean = false,
    val caption: String? = null,
    val imageUrl: String? = null,
    val imageWidth: Int? = null,
    val imageHeight: Int? = null,
    val imageCount: Int = 0,
    val imageAspectRatio: String? = null,
    val likeCount: Int = 0,
    val commentCount: Int = 0,
    val redropCount: Int = 0,
    val redropId: String? = null,
    val redropperId: String? = null,
    val redropperUsername: String? = null,
    val redropperDisplayName: String? = null,
    val redropperAvatarUrl: String? = null,
    val redropperIsVerified: Boolean = false,
    val quoteText: String? = null,
    /** A standard repost of this Quote (not of its original Drop). */
    val quoteReposterId: String? = null,
    val quoteReposterUsername: String? = null,
    val quoteRepostedAt: String? = null,
    val location: String? = null,
    val audience: String? = null,
) {
    /** The web's authorLabel(). */
    val authorLabel: String
        get() = authorDisplayName?.trim()?.takeIf { it.isNotEmpty() }
            ?: authorUsername?.trim()?.takeIf { it.isNotEmpty() }
            ?: "WYNOS"

    /** Only public posts can be reposted. */
    val canRedrop: Boolean get() = audience == null || audience == "everyone"

    /** The web's feedIdentity(): a Drop, each repost of it, and each repost of a Quote are separate rows. */
    val key: String get() = "$id:${redropId.orEmpty()}:${quoteReposterId.orEmpty()}"

    /** web isQuotePost(): an authored Quote, shown with its own card and its own likes. */
    val isQuote: Boolean get() = redropId != null && redropperId != null && !quoteText.isNullOrBlank()

    /** The Quote author's label (web quote-feed-card quoteName). */
    val quoteAuthorLabel: String
        get() = redropperDisplayName?.trim()?.takeIf { it.isNotEmpty() } ?: redropperUsername ?: "WYNOS"

    /** When this row entered the timeline (a Quote repost sorts by when it was reposted). */
    val timelineAt: String get() = quoteRepostedAt ?: createdAt

    /** Mirrors web postMediaAspectRatio(). */
    fun mediaAspectRatio(multiple: Boolean): Float {
        if (!multiple) return clampedRatio(imageWidth, imageHeight)
        return when (imageAspectRatio) {
            "original" -> clampedRatio(imageWidth, imageHeight)
            "1:1" -> 1f
            "16:9" -> 16f / 9f
            else -> 4f / 5f
        }
    }

    companion object {
        fun clampedRatio(width: Int?, height: Int?): Float {
            if (width == null || height == null || width <= 0 || height <= 0) return 1f
            return (width.toFloat() / height).coerceIn(0.8f, 1.91f)
        }

        /** Lenient parse of one row; null when it is not a usable Drop (the web's rankedDropRows filter). */
        fun parse(element: JsonElement?): FeedRow? {
            val obj = element as? JsonObject ?: return null
            val row = (obj["row_data"] as? JsonObject) ?: obj
            if (row.text("content_type") != "drop") return null
            val id = row.text("id") ?: return null
            val createdAt = row.text("created_at") ?: return null
            return FeedRow(
                id = id,
                authorId = row.text("author_id").orEmpty(),
                createdAt = createdAt,
                authorUsername = row.text("author_username"),
                authorDisplayName = row.text("author_display_name"),
                authorAvatarUrl = row.text("author_avatar_url"),
                authorIsVerified = row.bool("author_is_verified"),
                caption = row.text("caption"),
                imageUrl = row.text("image_url"),
                imageWidth = row.int("image_width"),
                imageHeight = row.int("image_height"),
                imageCount = row.int("image_count") ?: 0,
                imageAspectRatio = row.text("image_aspect_ratio"),
                likeCount = row.int("like_count") ?: 0,
                commentCount = row.int("comment_count") ?: 0,
                redropCount = row.int("redrop_count") ?: 0,
                redropId = row.text("redrop_id"),
                redropperId = row.text("redropper_id"),
                redropperUsername = row.text("redropper_username"),
                redropperDisplayName = row.text("redropper_display_name"),
                redropperAvatarUrl = row.text("redropper_avatar_url"),
                redropperIsVerified = row.bool("redropper_is_verified"),
                quoteText = row.text("quote_text"),
                location = row.text("location"),
                audience = row.text("audience"),
            )
        }

        fun parseList(element: JsonElement?, limit: Int): List<FeedRow> =
            (element as? JsonArray).orEmpty().asSequence().mapNotNull(::parse).take(limit).toList()
    }
}

/** What the signed-in viewer has done to the rows on screen (web HomeViewerState). */
data class ViewerState(
    val liked: Set<String> = emptySet(),
    val saved: Set<String> = emptySet(),
    val redropped: Set<String> = emptySet(),
    val following: Set<String> = emptySet(),
    val requested: Set<String> = emptySet(),
    val privateAuthors: Set<String> = emptySet(),
)

/** The signed-in person's own summary for the header and quick compose. */
data class HomeIdentity(val username: String?, val displayName: String?, val avatarUrl: String?)

enum class FollowState { Following, Requested, None }

/** web predictFollowState(): what a tap on "follow" will do, applied before the request returns. */
fun predictFollowState(following: Boolean, requested: Boolean, isPrivate: Boolean): FollowState = when {
    following -> FollowState.None
    isPrivate -> if (requested) FollowState.None else FollowState.Requested
    else -> FollowState.Following
}

internal fun JsonObject.text(key: String): String? =
    (this[key] as? JsonPrimitive)?.takeIf { it !is JsonNull && it.isString }?.content

internal fun JsonObject.int(key: String): Int? =
    (this[key] as? JsonPrimitive)?.takeIf { it !is JsonNull }?.let { it.content.toIntOrNull() ?: it.doubleOrNull?.toInt() }

internal fun JsonObject.bool(key: String): Boolean =
    (this[key] as? JsonPrimitive)?.takeIf { it !is JsonNull }?.booleanOrNull ?: false
