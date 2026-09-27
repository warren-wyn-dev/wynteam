package io.wyn.wyn.core.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray

/** Counts and viewer flags for one Quote, keyed by its redrops.id, never the quoted Drop (web QuoteEngagement). */
data class QuoteEngagement(
    val quoteId: String,
    val likeCount: Int = 0,
    val commentCount: Int = 0,
    val repostCount: Int = 0,
    val liked: Boolean = false,
    val saved: Boolean = false,
    val reposted: Boolean = false,
)

data class QuoteComment(
    val id: String,
    val quoteId: String,
    val authorId: String,
    val authorUsername: String,
    val authorDisplayName: String?,
    val authorAvatarUrl: String?,
    val authorVerified: Boolean,
    val text: String,
    val createdAt: String,
) {
    val authorLabel: String get() = authorDisplayName?.trim()?.takeIf { it.isNotEmpty() } ?: authorUsername
}

const val QUOTE_COMMENT_PAGE = 30

/** Quote posts, mirroring web/lib/quote-actions.ts and web/lib/quote-feed-data.ts. */
interface QuoteRepository {
    suspend fun engagement(quoteIds: List<String>): Map<String, QuoteEngagement>
    suspend fun setLiked(userId: String, quoteId: String, liked: Boolean)
    suspend fun setSaved(userId: String, quoteId: String, saved: Boolean)
    suspend fun setReposted(userId: String, quoteId: String, reposted: Boolean)
    /** A new Quote of a Drop: redrops row with quote_text. */
    suspend fun quoteDrop(userId: String, dropId: String, text: String)
    suspend fun deleteQuote(userId: String, quoteId: String)
    suspend fun report(quoteId: String, category: String, detail: String?)
    suspend fun fetchQuote(quoteId: String): FeedRow?
    /** Quotes that the given people reposted, newest first, for their followers' Following feed. */
    suspend fun repostRows(userIds: List<String>, limit: Int): List<FeedRow>
    /** Quotes [userId] liked, newest like first, as (row, liked at). Callers check can_view_likes first. */
    suspend fun likedRows(userId: String, limit: Int): List<Pair<FeedRow, String>>
    suspend fun fetchImages(dropId: String, fallback: String?): List<String>
    suspend fun comments(quoteId: String, page: Int): List<QuoteComment>
    suspend fun addComment(userId: String, quoteId: String, text: String)
    suspend fun removeComment(userId: String, commentId: String)
}

class SupabaseQuoteRepository(private val clientOrNull: SupabaseClient?) : QuoteRepository {
    private val client: SupabaseClient get() = clientOrNull ?: throw NotConfiguredException()

    override suspend fun engagement(quoteIds: List<String>): Map<String, QuoteEngagement> {
        val ids = quoteIds.filter { it.isNotEmpty() }.distinct()
        if (ids.isEmpty()) return emptyMap()
        val out = LinkedHashMap<String, QuoteEngagement>()
        // Postgres bounds this at 100 ids per call.
        for (chunk in ids.chunked(100)) {
            val rows = client.postgrest.rpc(
                "get_quote_engagement",
                buildJsonObject { putJsonArray("p_quote_ids") { chunk.forEach { add(JsonPrimitive(it)) } } },
            ).decodeList<JsonObject>()
            for (row in rows) {
                val id = row.text("quote_id") ?: continue
                out[id] = QuoteEngagement(
                    quoteId = id,
                    likeCount = row.int("like_count") ?: 0,
                    commentCount = row.int("comment_count") ?: 0,
                    repostCount = row.int("redrop_count") ?: 0,
                    liked = row.bool("liked_by_me"),
                    saved = row.bool("saved_by_me"),
                    reposted = row.bool("redropped_by_me"),
                )
            }
        }
        return out
    }

    private suspend fun toggle(table: String, userId: String, quoteId: String, remove: Boolean) {
        if (remove) {
            client.from(table).delete { filter { eq("quote_id", quoteId); eq("user_id", userId) } }
        } else {
            client.from(table).insert(buildJsonObject { put("quote_id", quoteId); put("user_id", userId) })
        }
    }

    override suspend fun setLiked(userId: String, quoteId: String, liked: Boolean) = toggle("quote_likes", userId, quoteId, !liked)
    override suspend fun setSaved(userId: String, quoteId: String, saved: Boolean) = toggle("quote_saves", userId, quoteId, !saved)
    override suspend fun setReposted(userId: String, quoteId: String, reposted: Boolean) = toggle("quote_reposts", userId, quoteId, !reposted)

    override suspend fun quoteDrop(userId: String, dropId: String, text: String) {
        val body = text.trim()
        require(body.isNotEmpty() && body.length <= MAX_CAPTION)
        client.from("redrops").insert(buildJsonObject { put("drop_id", dropId); put("redropper_id", userId); put("quote_text", body) })
    }

    override suspend fun deleteQuote(userId: String, quoteId: String) {
        client.from("redrops").delete {
            filter { eq("id", quoteId); eq("redropper_id", userId); filterNot("quote_text", io.github.jan.supabase.postgrest.query.filter.FilterOperator.IS, "null") }
        }
    }

    override suspend fun report(quoteId: String, category: String, detail: String?) {
        client.postgrest.rpc(
            "submit_report",
            buildJsonObject { put("p_target_type", "redrop"); put("p_target_id", quoteId); put("p_category", category); put("p_detail", detail) },
        )
    }

    override suspend fun fetchQuote(quoteId: String): FeedRow? {
        val rows = client.from("home_feed").select {
            filter { eq("redrop_id", quoteId); eq("content_type", "drop") }
        }.decodeAs<JsonElement>()
        return FeedRow.parseList(rows, 1).firstOrNull()?.takeIf { it.isQuote }
    }

    private suspend fun visibleQuotes(quoteIds: List<String>): Map<String, FeedRow> {
        val out = HashMap<String, FeedRow>()
        for (chunk in quoteIds.filter { it.isNotEmpty() }.distinct().chunked(80)) {
            val rows = client.from("home_feed").select {
                filter {
                    isIn("redrop_id", chunk)
                    eq("content_type", "drop")
                    filterNot("quote_text", io.github.jan.supabase.postgrest.query.filter.FilterOperator.IS, "null")
                }
            }.decodeAs<JsonElement>()
            FeedRow.parseList(rows, Int.MAX_VALUE).filter { it.isQuote }.forEach { out[it.redropId!!] = it }
        }
        return out
    }

    override suspend fun repostRows(userIds: List<String>, limit: Int): List<FeedRow> {
        val ids = userIds.filter { it.isNotEmpty() }.distinct()
        if (ids.isEmpty()) return emptyList()
        val reposts = client.from("quote_reposts").select(Columns.list("quote_id", "user_id", "created_at")) {
            filter { isIn("user_id", ids) }
            order("created_at", Order.DESCENDING)
            range(0L, (limit - 1).toLong())
        }.decodeList<JsonObject>()
        if (reposts.isEmpty()) return emptyList()
        val quotes = visibleQuotes(reposts.mapNotNull { it.text("quote_id") })
        val usernames = client.from("profiles").select(Columns.list("id", "username")) {
            filter { isIn("id", reposts.mapNotNull { it.text("user_id") }.distinct()) }
        }.decodeList<JsonObject>().associate { (it.text("id") ?: "") to (it.text("username") ?: "ผู้ใช้ WYNOS") }
        return reposts.mapNotNull { share ->
            val quote = quotes[share.text("quote_id")] ?: return@mapNotNull null
            val user = share.text("user_id").orEmpty()
            quote.copy(quoteReposterId = user, quoteReposterUsername = usernames[user] ?: "ผู้ใช้ WYNOS", quoteRepostedAt = share.text("created_at"))
        }
    }

    override suspend fun likedRows(userId: String, limit: Int): List<Pair<FeedRow, String>> {
        val likes = client.from("quote_likes").select(Columns.list("quote_id", "created_at")) {
            filter { eq("user_id", userId) }
            order("created_at", Order.DESCENDING)
            range(0L, (limit - 1).toLong())
        }.decodeList<JsonObject>()
        if (likes.isEmpty()) return emptyList()
        val quotes = visibleQuotes(likes.mapNotNull { it.text("quote_id") })
        return likes.mapNotNull { like -> quotes[like.text("quote_id")]?.let { it to like.text("created_at").orEmpty() } }
    }

    override suspend fun fetchImages(dropId: String, fallback: String?): List<String> {
        val urls = client.from("drop_images").select(Columns.list("image_url", "position")) {
            filter { eq("drop_id", dropId) }
            order("position", Order.ASCENDING)
        }.decodeList<JsonObject>().mapNotNull { it.text("image_url")?.takeIf(String::isNotEmpty) }
        return (urls + listOfNotNull(fallback)).distinct()
    }

    override suspend fun comments(quoteId: String, page: Int): List<QuoteComment> {
        val from = (page * QUOTE_COMMENT_PAGE).toLong()
        return client.from("quote_comments").select(
            Columns.raw("id,quote_id,author_id,text_content,created_at,author:profiles!quote_comments_author_id_fkey(username,display_name,avatar_url,is_verified)"),
        ) {
            filter { eq("quote_id", quoteId) }
            order("created_at", Order.DESCENDING)
            range(from, from + QUOTE_COMMENT_PAGE - 1)
        }.decodeList<JsonObject>().map { row ->
            val author = relation(row["author"])
            QuoteComment(
                id = row.text("id").orEmpty(),
                quoteId = row.text("quote_id").orEmpty(),
                authorId = row.text("author_id").orEmpty(),
                authorUsername = author.text("username") ?: "WYNOS",
                authorDisplayName = author.text("display_name"),
                authorAvatarUrl = author.text("avatar_url"),
                authorVerified = author.bool("is_verified"),
                text = row.text("text_content").orEmpty(),
                createdAt = row.text("created_at").orEmpty(),
            )
        }
    }

    override suspend fun addComment(userId: String, quoteId: String, text: String) {
        val body = text.trim()
        require(body.isNotEmpty() && body.length <= 500)
        client.from("quote_comments").insert(buildJsonObject { put("quote_id", quoteId); put("author_id", userId); put("text_content", body) })
    }

    override suspend fun removeComment(userId: String, commentId: String) {
        client.from("quote_comments").delete { filter { eq("id", commentId); eq("author_id", userId) } }
    }
}
