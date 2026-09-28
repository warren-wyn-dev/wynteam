package io.wyn.wyn.core.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.storage.storage
import io.ktor.http.ContentType
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.Instant
import kotlin.time.Duration.Companion.hours

/** web ConversationRow (chat_inbox / message_requests views). */
data class Conversation(
    val id: String,
    val status: String,
    val requestedBy: String?,
    val createdAt: String,
    val otherUserId: String,
    val otherUsername: String,
    val otherDisplayName: String? = null,
    val otherAvatarUrl: String? = null,
    val lastMessageText: String? = null,
    val lastMessageImageUrl: String? = null,
    val lastMessageDeletedAt: String? = null,
    val lastMessageAt: String? = null,
    val lastMessageSenderId: String? = null,
    val myLastReadAt: String? = null,
) {
    val otherLabel: String get() = otherDisplayName?.trim()?.takeIf { it.isNotEmpty() } ?: otherUsername

    /** web isUnread(): the other person wrote last, after I last read. */
    fun isUnread(userId: String): Boolean {
        val last = lastMessageAt ?: return false
        if (lastMessageSenderId == userId) return false
        val read = myLastReadAt ?: return true
        return instantMillis(last) > instantMillis(read)
    }
}

/** web MessageRow. */
data class ChatMessage(
    val id: String,
    val conversationId: String,
    val senderId: String,
    val text: String? = null,
    val imagePath: String? = null,
    val replyToId: String? = null,
    val replyText: String? = null,
    val replyImage: Boolean = false,
    val replyDeleted: Boolean = false,
    val deletedAt: String? = null,
    val editedAt: String? = null,
    val createdAt: String,
    /** Client-only: shown while it is being sent. */
    val pending: Boolean = false,
)

/** web ConversationMeta. */
data class ConversationMeta(val status: String, val requestedBy: String?, val otherLastReadAt: String?)

const val CHAT_PAGE_SIZE = 30

/** Direct messages, mirroring web/lib/phase3-data.ts (1:1 chat, Web Beta 1). */
interface ChatRepository {
    /** chat_lockdown_status: whether chat is open for me (or with this person). */
    suspend fun allowed(otherUserId: String? = null): Boolean
    suspend fun inbox(): List<Conversation>
    suspend fun requests(): List<Conversation>
    suspend fun accept(conversationId: String)
    suspend fun decline(conversationId: String)
    suspend fun otherUserId(conversationId: String): String?
    suspend fun existingConversation(otherUserId: String): String?
    suspend fun startConversation(otherUserId: String): String
    suspend fun meta(userId: String, conversationId: String): ConversationMeta?
    suspend fun messages(conversationId: String, before: String? = null): List<ChatMessage>
    suspend fun send(userId: String, conversationId: String, text: String?, image: PickedImage?): ChatMessage
    suspend fun markRead(conversationId: String)
    suspend fun delete(message: ChatMessage)
    /** A short-lived link to a private chat photo. */
    suspend fun imageUrl(path: String): String?
    /** web fetchWynii(): null when the two have not started one. */
    suspend fun wynii(conversationId: String): WyniiPet?
    /** web startWynii(): start_conversation_wynii, then the new pet. */
    suspend fun startWynii(conversationId: String): WyniiPet
}

private const val MESSAGE_COLUMNS =
    "id,conversation_id,sender_id,text,image_url,reply_to_message_id,shared_content_type,shared_content_id,deleted_at,created_at,view_once,viewed_at,edited_at," +
        "reply_to:messages!reply_to_message_id(text,image_url,deleted_at)"
private const val CHAT_BUCKET = "chat-media"

class SupabaseChatRepository(private val clientOrNull: SupabaseClient?) : ChatRepository {
    private val client: SupabaseClient get() = clientOrNull ?: throw NotConfiguredException()

    override suspend fun allowed(otherUserId: String?): Boolean =
        client.postgrest.rpc("chat_lockdown_status", buildJsonObject { put("p_other_user_id", otherUserId) })
            .decodeAs<JsonElement>().let { (it as? JsonPrimitive)?.content == "true" }

    private suspend fun list(view: String): List<Conversation> =
        client.from(view).select {
            order("conversation_created_at", Order.DESCENDING)
            range(0L, (CHAT_PAGE_SIZE - 1).toLong())
        }.decodeList<JsonObject>().map(::parseConversation)

    override suspend fun inbox(): List<Conversation> =
        list("chat_inbox").sortedByDescending { instantMillis(it.lastMessageAt ?: it.createdAt) }

    override suspend fun requests(): List<Conversation> = list("message_requests")

    override suspend fun accept(conversationId: String) {
        client.postgrest.rpc("accept_message_request", buildJsonObject { put("p_conversation_id", conversationId) })
    }

    override suspend fun decline(conversationId: String) {
        client.postgrest.rpc("delete_message_request", buildJsonObject { put("p_conversation_id", conversationId) })
    }

    override suspend fun otherUserId(conversationId: String): String? =
        client.from("chat_inbox").select(Columns.list("other_user_id")) { filter { eq("conversation_id", conversationId) } }
            .decodeList<JsonObject>().firstOrNull()?.text("other_user_id")
            ?: client.from("message_requests").select(Columns.list("other_user_id")) { filter { eq("conversation_id", conversationId) } }
                .decodeList<JsonObject>().firstOrNull()?.text("other_user_id")

    override suspend fun existingConversation(otherUserId: String): String? =
        // RLS only returns conversations I am part of; the pair is unique.
        client.from("conversations").select(Columns.list("id")) {
            filter { or { eq("user_a_id", otherUserId); eq("user_b_id", otherUserId) } }
        }.decodeList<JsonObject>().firstOrNull()?.text("id")

    override suspend fun startConversation(otherUserId: String): String =
        client.postgrest.rpc("get_or_create_conversation", buildJsonObject { put("p_other_user_id", otherUserId) })
            .decodeAs<JsonElement>().let { (it as? JsonPrimitive)?.content } ?: error("no conversation")

    override suspend fun meta(userId: String, conversationId: String): ConversationMeta? {
        val row = client.from("conversations").select(
            Columns.list("status", "requested_by", "user_a_id", "user_b_id", "user_a_last_read_at", "user_b_last_read_at"),
        ) { filter { eq("id", conversationId) } }.decodeList<JsonObject>().firstOrNull() ?: return null
        val amA = row.text("user_a_id") == userId
        return ConversationMeta(
            status = row.text("status") ?: "active",
            requestedBy = row.text("requested_by"),
            otherLastReadAt = row.text(if (amA) "user_b_last_read_at" else "user_a_last_read_at"),
        )
    }

    override suspend fun messages(conversationId: String, before: String?): List<ChatMessage> =
        client.from("messages").select(Columns.raw(MESSAGE_COLUMNS)) {
            filter {
                eq("conversation_id", conversationId)
                if (before != null) lt("created_at", before)
            }
            order("created_at", Order.DESCENDING)
            limit(CHAT_PAGE_SIZE.toLong())
        }.decodeList<JsonObject>().map(::parseMessage)

    override suspend fun send(userId: String, conversationId: String, text: String?, image: PickedImage?): ChatMessage {
        val body = text?.trim()?.takeIf { it.isNotEmpty() }
        var path: String? = null
        if (image != null) {
            require(image.bytes.size <= IMAGE_MAX_BYTES)
            path = "$conversationId/$userId-${System.currentTimeMillis()}.${image.extension}"
            client.storage.from(CHAT_BUCKET).upload(path, image.bytes) {
                upsert = false
                contentType = ContentType.parse(image.contentType)
            }
        }
        require(body != null || path != null) { "empty message" }
        return try {
            insertMessage(userId, conversationId, body, path)
        } catch (e: Exception) {
            // A photo that never became a message should not stay in the private bucket.
            path?.let { uploaded -> runCatching { client.storage.from(CHAT_BUCKET).delete(listOf(uploaded)) } }
            throw e
        }
    }

    private suspend fun insertMessage(userId: String, conversationId: String, body: String?, path: String?): ChatMessage =
        client.from("messages").insert(
            buildJsonObject {
                put("conversation_id", conversationId)
                put("sender_id", userId)
                put("text", body)
                put("image_url", path)
                put("reply_to_message_id", null as String?)
            },
        ) { select(Columns.raw(MESSAGE_COLUMNS)) }.decodeSingle<JsonObject>().let(::parseMessage)

    override suspend fun markRead(conversationId: String) {
        client.postgrest.rpc("mark_conversation_read", buildJsonObject { put("p_conversation_id", conversationId) })
    }

    override suspend fun delete(message: ChatMessage) {
        client.postgrest.rpc("delete_message", buildJsonObject { put("p_message_id", message.id) })
        message.imagePath?.let { runCatching { client.storage.from(CHAT_BUCKET).delete(listOf(it)) } }
    }

    override suspend fun imageUrl(path: String): String? =
        runCatching { client.storage.from(CHAT_BUCKET).createSignedUrl(path, 1.hours) }.getOrNull()

    override suspend fun wynii(conversationId: String): WyniiPet? =
        client.from("conversation_wynii").select(Columns.raw(WYNII_COLUMNS)) { filter { eq("conversation_id", conversationId) } }
            .decodeList<JsonObject>().firstOrNull()?.let { row ->
                WyniiPet(
                    conversationId = row.text("conversation_id").orEmpty(),
                    userAId = row.text("user_a_id").orEmpty(),
                    userBId = row.text("user_b_id").orEmpty(),
                    ageDays = row.int("age_days") ?: 0,
                    cycleStartedAt = row.text("cycle_started_at"),
                    userADone = row.bool("user_a_done"),
                    userBDone = row.bool("user_b_done"),
                    nextCycleAt = row.text("next_cycle_at").orEmpty(),
                    lastCompletedAt = row.text("last_completed_at"),
                )
            }

    override suspend fun startWynii(conversationId: String): WyniiPet {
        client.postgrest.rpc("start_conversation_wynii", buildJsonObject { put("p_conversation_id", conversationId) })
        return wynii(conversationId) ?: error("no wynii")
    }
}

private const val WYNII_COLUMNS =
    "conversation_id,user_a_id,user_b_id,age_days,cycle_started_at,user_a_done,user_b_done,next_cycle_at,last_completed_at,created_at,updated_at"

internal fun parseConversation(row: JsonObject) = Conversation(
    id = row.text("conversation_id").orEmpty(),
    status = row.text("status") ?: "pending",
    requestedBy = row.text("requested_by"),
    createdAt = row.text("conversation_created_at").orEmpty(),
    otherUserId = row.text("other_user_id").orEmpty(),
    otherUsername = row.text("other_username").orEmpty(),
    otherDisplayName = row.text("other_display_name"),
    otherAvatarUrl = row.text("other_avatar_url"),
    lastMessageText = row.text("last_message_text"),
    lastMessageImageUrl = row.text("last_message_image_url"),
    lastMessageDeletedAt = row.text("last_message_deleted_at"),
    lastMessageAt = row.text("last_message_at"),
    lastMessageSenderId = row.text("last_message_sender_id"),
    myLastReadAt = row.text("my_last_read_at"),
)

internal fun parseMessage(row: JsonObject): ChatMessage {
    val reply = relation(row["reply_to"])
    return ChatMessage(
        id = row.text("id").orEmpty(),
        conversationId = row.text("conversation_id").orEmpty(),
        senderId = row.text("sender_id").orEmpty(),
        text = row.text("text"),
        imagePath = row.text("image_url"),
        replyToId = row.text("reply_to_message_id"),
        replyText = reply.text("text"),
        replyImage = reply.text("image_url") != null,
        replyDeleted = reply.text("deleted_at") != null,
        deletedAt = row.text("deleted_at"),
        editedAt = row.text("edited_at"),
        createdAt = row.text("created_at").orEmpty(),
    )
}

internal fun instantMillis(value: String): Long = runCatching { Instant.parse(value).toEpochMilli() }.getOrDefault(0L)
