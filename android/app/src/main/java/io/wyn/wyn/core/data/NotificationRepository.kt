package io.wyn.wyn.core.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Count
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.Instant

/** web NotificationRow. */
data class NotificationItem(
    val id: String,
    val type: String,
    val createdAt: String,
    val isRead: Boolean = false,
    val actorId: String? = null,
    val actorUsername: String? = null,
    val actorDisplayName: String? = null,
    val actorAvatarUrl: String? = null,
    val dropId: String? = null,
    val popId: String? = null,
    val clubId: String? = null,
    val clubName: String? = null,
    val clubPostId: String? = null,
    val reason: String? = null,
    val conversationId: String? = null,
    val contentPreview: String? = null,
)

/** web NotificationSettings, with the same defaults (everything on). */
data class NotificationPrefs(
    val likes: Boolean = true,
    val comments: Boolean = true,
    val follows: Boolean = true,
    val messages: Boolean = true,
    val club: Boolean = true,
    val trending: Boolean = true,
    val system: Boolean = true,
) {
    operator fun get(key: String): Boolean = when (key) {
        "likes" -> likes
        "comments" -> comments
        "follows" -> follows
        "messages" -> messages
        "club" -> club
        "trending" -> trending
        else -> system
    }

    fun with(key: String, value: Boolean): NotificationPrefs = when (key) {
        "likes" -> copy(likes = value)
        "comments" -> copy(comments = value)
        "follows" -> copy(follows = value)
        "messages" -> copy(messages = value)
        "club" -> copy(club = value)
        "trending" -> copy(trending = value)
        else -> copy(system = value)
    }

    companion object {
        val KEYS = listOf("likes", "comments", "follows", "messages", "club", "trending", "system")
    }
}

const val NOTIFICATION_PAGE_SIZE = 30

/** Notifications, mirroring web/lib/phase3-data.ts and notification-count.ts. */
interface NotificationRepository {
    suspend fun page(page: Int): List<NotificationItem>
    suspend fun unreadCount(userId: String): Int
    /** Marks only what existed when the list was opened (up to [newestSeenAt]); later ones stay unread. */
    suspend fun markAllRead(userId: String, newestSeenAt: String?)
    suspend fun prefs(): NotificationPrefs
    suspend fun setPref(userId: String, key: String, value: Boolean)
}

private const val NOTIFICATION_SELECT =
    "id,type,drop_id,pop_id,club_id,club_post_id,reason,moderation_action_id,moderation_action_type,conversation_id,is_read,created_at," +
        "actor:profiles!notifications_actor_id_fkey(id,username,display_name,avatar_url),club:clubs(name),drop:drops(caption),pop:pops(caption)"

class SupabaseNotificationRepository(private val clientOrNull: SupabaseClient?) : NotificationRepository {
    private val client: SupabaseClient get() = clientOrNull ?: throw NotConfiguredException()

    override suspend fun page(page: Int): List<NotificationItem> {
        val from = (page * NOTIFICATION_PAGE_SIZE).toLong()
        return client.from("notifications").select(Columns.raw(NOTIFICATION_SELECT)) {
            // Direct messages belong to Chat, never the notification centre.
            filter { neq("type", "new_message") }
            order("created_at", Order.DESCENDING)
            range(from, from + NOTIFICATION_PAGE_SIZE - 1)
        }.decodeList<JsonObject>().map(::parseNotification)
    }

    override suspend fun unreadCount(userId: String): Int =
        client.from("notifications").select(Columns.list("id")) {
            head = true
            count(Count.EXACT)
            filter { eq("recipient_id", userId); eq("is_read", false); neq("type", "new_message") }
        }.countOrNull()?.toInt()?.coerceAtLeast(0) ?: 0

    override suspend fun markAllRead(userId: String, newestSeenAt: String?) {
        client.from("notifications").update(buildJsonObject { put("is_read", true) }) {
            filter {
                eq("recipient_id", userId)
                eq("is_read", false)
                neq("type", "new_message")
                if (newestSeenAt != null) lte("created_at", newestSeenAt)
            }
        }
    }

    override suspend fun prefs(): NotificationPrefs {
        val row = client.from("notification_settings").select().decodeList<JsonObject>().firstOrNull() ?: return NotificationPrefs()
        var prefs = NotificationPrefs()
        for (key in NotificationPrefs.KEYS) {
            val value = (row[key] as? JsonPrimitive)?.content
            if (value == "true" || value == "false") prefs = prefs.with(key, value == "true")
        }
        return prefs
    }

    override suspend fun setPref(userId: String, key: String, value: Boolean) {
        require(key in NotificationPrefs.KEYS)
        client.from("notification_settings").upsert(buildJsonObject { put("user_id", userId); put(key, value) }) { onConflict = "user_id" }
    }
}

internal fun parseNotification(row: JsonObject): NotificationItem {
    val actor = relation(row["actor"])
    val club = relation(row["club"])
    val drop = relation(row["drop"])
    val pop = relation(row["pop"])
    return NotificationItem(
        id = row.text("id").orEmpty(),
        type = row.text("type").orEmpty(),
        createdAt = row.text("created_at").orEmpty(),
        isRead = row.bool("is_read"),
        actorId = actor.text("id"),
        actorUsername = actor.text("username"),
        actorDisplayName = actor.text("display_name"),
        actorAvatarUrl = actor.text("avatar_url"),
        dropId = row.text("drop_id"),
        popId = row.text("pop_id"),
        clubId = row.text("club_id"),
        clubName = club.text("name"),
        clubPostId = row.text("club_post_id"),
        reason = row.text("reason"),
        conversationId = row.text("conversation_id"),
        contentPreview = drop.text("caption") ?: pop.text("caption"),
    )
}

/**
 * web mergeNewestNotificationPage(): a background re-read of the newest page
 * keeps older pages the person already loaded. A short fresh page is the whole list.
 */
fun mergeNewestNotificationPage(current: List<NotificationItem>, next: List<NotificationItem>): List<NotificationItem> {
    if (next.size < NOTIFICATION_PAGE_SIZE) return next
    val fresh = next.map { it.id }.toSet()
    val oldestFresh = instantOf(next.last().createdAt)
    return next + current.filter { it.id !in fresh && instantOf(it.createdAt) <= oldestFresh }
}

private fun instantOf(value: String): Long = runCatching { Instant.parse(value).toEpochMilli() }.getOrDefault(0L)

/** This device's FCM tokens in the shared push_tokens table (platform "android"). */
interface PushTokenRepository {
    suspend fun register(userId: String, token: String)
    suspend fun unregister(token: String)
    suspend fun isRegistered(userId: String, token: String): Boolean
}

class SupabasePushTokenRepository(private val clientOrNull: SupabaseClient?) : PushTokenRepository {
    private val client: SupabaseClient get() = clientOrNull ?: throw NotConfiguredException()

    override suspend fun register(userId: String, token: String) {
        client.from("push_tokens").upsert(
            buildJsonObject {
                put("user_id", userId)
                put("token", token)
                put("platform", "android")
                put("updated_at", Instant.now().toString())
            },
        ) { onConflict = "token" }
    }

    override suspend fun unregister(token: String) {
        client.from("push_tokens").delete { filter { eq("token", token) } }
    }

    override suspend fun isRegistered(userId: String, token: String): Boolean =
        client.from("push_tokens").select(Columns.list("token")) { filter { eq("user_id", userId); eq("token", token) } }
            .decodeList<JsonObject>().isNotEmpty()
}
