package io.wyn.wyn.core.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlin.coroutines.cancellation.CancellationException

/** One comment (web DropCommentRow). */
data class Comment(
    val id: String,
    val dropId: String,
    val authorId: String,
    val text: String,
    val createdAt: String,
    val parentId: String? = null,
    val authorUsername: String = "",
    val authorDisplayName: String? = null,
    val authorAvatarUrl: String? = null,
    val likeCount: Int = 0,
    val likedByMe: Boolean = false,
) {
    val authorLabel: String get() = authorDisplayName?.trim()?.takeIf { it.isNotEmpty() } ?: authorUsername
}

data class ActivityPerson(val id: String, val username: String, val displayName: String?, val avatarUrl: String?, val verified: Boolean) {
    val label: String get() = displayName?.trim()?.takeIf { it.isNotEmpty() } ?: username
}

data class PostActivity(val likes: List<ActivityPerson>, val reposts: List<ActivityPerson>)

const val COMMENT_PAGE_SIZE = 50

/** Post detail reads and writes (web post-detail-route.tsx, lib/home-actions.ts, lib/phase3-data.ts). */
interface PostRepository {
    suspend fun fetchDrop(dropId: String): FeedRow?
    suspend fun fetchImages(dropId: String, fallback: String?): List<String>
    suspend fun fetchComments(userId: String, dropId: String, page: Int): List<Comment>
    suspend fun addComment(userId: String, dropId: String, text: String, parentId: String?): Comment
    suspend fun setCommentLiked(userId: String, commentId: String, liked: Boolean)
    suspend fun deleteComment(userId: String, commentId: String)
    suspend fun fetchActivity(dropId: String): PostActivity
    suspend fun editDrop(dropId: String, caption: String?)
    suspend fun deleteDrop(dropId: String)
    suspend fun recordView(dropId: String)
}

internal const val DROP_SELECT =
    "id,author_id,caption,image_url,image_width,image_height,image_aspect_ratio,created_at,audience," +
        "author:profiles!drops_author_id_fkey(username,display_name,avatar_url,is_verified)," +
        "drop_likes(count),drop_comments(count),redrops(count),drop_images(count)"

private const val COMMENT_SELECT =
    "id,drop_id,author_id,text_content,created_at,parent_comment_id," +
        "author:profiles!drop_comments_author_id_fkey(username,display_name,avatar_url)," +
        "drop_comment_likes(count)"

class SupabasePostRepository(private val clientOrNull: SupabaseClient?) : PostRepository {
    private val client: SupabaseClient get() = clientOrNull ?: throw NotConfiguredException()

    override suspend fun fetchDrop(dropId: String): FeedRow? {
        val row = client.from("drops").select(Columns.raw(DROP_SELECT)) {
            filter { eq("id", dropId); exact("deleted_at", null) }
        }.decodeList<JsonObject>().firstOrNull() ?: return null
        return parseDropCard(row)
    }

    override suspend fun fetchImages(dropId: String, fallback: String?): List<String> {
        val urls = try {
            client.from("drop_images").select(Columns.list("image_url", "position")) {
                filter { eq("drop_id", dropId) }
                order("position", Order.ASCENDING)
            }.decodeList<JsonObject>().mapNotNull { it.text("image_url")?.takeIf(String::isNotEmpty) }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            return listOfNotNull(fallback)
        }
        return (listOfNotNull(fallback?.takeIf { it !in urls }) + urls).distinct()
    }

    override suspend fun fetchComments(userId: String, dropId: String, page: Int): List<Comment> {
        val from = (page * COMMENT_PAGE_SIZE).toLong()
        val raw = client.from("drop_comments").select(Columns.raw(COMMENT_SELECT)) {
            filter { eq("drop_id", dropId) }
            order("created_at", Order.ASCENDING)
            range(from, from + COMMENT_PAGE_SIZE - 1)
        }.decodeList<JsonObject>()
        val ids = raw.mapNotNull { it.text("id") }
        val liked = if (ids.isEmpty()) {
            emptySet()
        } else {
            client.from("drop_comment_likes").select(Columns.list("comment_id")) {
                filter { eq("user_id", userId); isIn("comment_id", ids) }
            }.decodeList<JsonObject>().mapNotNull { it.text("comment_id") }.toSet()
        }
        return raw.map { parseComment(it, it.text("id") in liked) }
    }

    override suspend fun addComment(userId: String, dropId: String, text: String, parentId: String?): Comment {
        val trimmed = text.trim()
        require(trimmed.isNotEmpty())
        val row = client.from("drop_comments").insert(
            buildJsonObject {
                put("drop_id", dropId); put("author_id", userId); put("text_content", trimmed); put("parent_comment_id", parentId)
            },
        ) { select(Columns.raw(COMMENT_SELECT)) }.decodeSingle<JsonObject>()
        return parseComment(row, false)
    }

    override suspend fun setCommentLiked(userId: String, commentId: String, liked: Boolean) {
        if (liked) {
            client.from("drop_comment_likes").upsert(buildJsonObject { put("comment_id", commentId); put("user_id", userId) }) {
                onConflict = "comment_id,user_id"
                ignoreDuplicates = true
            }
        } else {
            client.from("drop_comment_likes").delete { filter { eq("comment_id", commentId); eq("user_id", userId) } }
        }
    }

    override suspend fun deleteComment(userId: String, commentId: String) {
        client.from("drop_comments").delete { filter { eq("id", commentId); eq("author_id", userId) } }
    }

    override suspend fun fetchActivity(dropId: String): PostActivity {
        val likeIds = client.from("drop_likes").select(Columns.list("user_id", "created_at")) {
            filter { eq("drop_id", dropId) }
            order("created_at", Order.DESCENDING)
            limit(100)
        }.decodeList<JsonObject>().mapNotNull { it.text("user_id") }
        val repostIds = client.from("redrops").select(Columns.list("redropper_id", "created_at")) {
            filter { eq("drop_id", dropId) }
            order("created_at", Order.DESCENDING)
            limit(100)
        }.decodeList<JsonObject>().mapNotNull { it.text("redropper_id") }
        val ids = (likeIds + repostIds).distinct()
        if (ids.isEmpty()) return PostActivity(emptyList(), emptyList())
        val people = client.from("profiles").select(Columns.list("id", "username", "display_name", "avatar_url", "is_verified")) {
            filter { isIn("id", ids) }
        }.decodeList<JsonObject>().associate {
            val id = it.text("id").orEmpty()
            id to ActivityPerson(id, it.text("username").orEmpty(), it.text("display_name"), it.text("avatar_url"), it.bool("is_verified"))
        }
        return PostActivity(likeIds.mapNotNull(people::get), repostIds.mapNotNull(people::get))
    }

    override suspend fun editDrop(dropId: String, caption: String?) {
        client.postgrest.rpc("edit_drop", buildJsonObject { put("p_drop_id", dropId); put("p_caption", caption) })
    }

    override suspend fun deleteDrop(dropId: String) {
        client.postgrest.rpc("soft_delete_drop", buildJsonObject { put("p_drop_id", dropId) })
    }

    override suspend fun recordView(dropId: String) {
        runCatching { client.postgrest.rpc("record_drop_view", buildJsonObject { put("p_drop_id", dropId) }) }
            .onFailure { if (it is CancellationException) throw it }
    }

    private fun parseComment(row: JsonObject, liked: Boolean): Comment {
        val author = relation(row["author"])
        return Comment(
            id = row.text("id").orEmpty(),
            dropId = row.text("drop_id").orEmpty(),
            authorId = row.text("author_id").orEmpty(),
            text = row.text("text_content").orEmpty(),
            createdAt = row.text("created_at").orEmpty(),
            parentId = row.text("parent_comment_id"),
            authorUsername = author.text("username").orEmpty(),
            authorDisplayName = author.text("display_name"),
            authorAvatarUrl = author.text("avatar_url"),
            likeCount = firstCount(row["drop_comment_likes"]),
            likedByMe = liked,
        )
    }
}

internal fun relation(value: JsonElement?): JsonObject = when (value) {
    is JsonObject -> value
    is JsonArray -> value.firstOrNull() as? JsonObject ?: JsonObject(emptyMap())
    else -> JsonObject(emptyMap())
}

internal fun firstCount(value: JsonElement?): Int = (value as? JsonArray)?.firstOrNull()?.let { (it as? JsonObject)?.int("count") } ?: 0

/** A drops row selected with [DROP_SELECT] (web asDrop()). */
internal fun parseDropCard(row: JsonObject): FeedRow {
    val author = relation(row["author"])
    return FeedRow(
        id = row.text("id").orEmpty(),
        authorId = row.text("author_id").orEmpty(),
        createdAt = row.text("created_at").orEmpty(),
        authorUsername = author.text("username").orEmpty(),
        authorDisplayName = author.text("display_name"),
        authorAvatarUrl = author.text("avatar_url"),
        authorIsVerified = author.bool("is_verified"),
        caption = row.text("caption"),
        imageUrl = row.text("image_url"),
        imageWidth = row.int("image_width"),
        imageHeight = row.int("image_height"),
        imageAspectRatio = row.text("image_aspect_ratio"),
        imageCount = firstCount(row["drop_images"]),
        likeCount = firstCount(row["drop_likes"]),
        commentCount = firstCount(row["drop_comments"]),
        redropCount = firstCount(row["redrops"]),
        audience = row.text("audience"),
    )
}
