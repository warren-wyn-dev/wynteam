package io.wyn.wyn.testing

import io.wyn.wyn.core.data.ChatMessage
import io.wyn.wyn.core.data.ChatRepository
import io.wyn.wyn.core.data.Conversation
import io.wyn.wyn.core.data.ConversationMeta
import io.wyn.wyn.core.data.PickedImage
import java.time.Instant

class FakeChatRepository : ChatRepository {
    var open = true
    val blockedWith = mutableSetOf<String>()
    var inboxRows = ChatFixture.inbox
    var requestRows = ChatFixture.requests
    val conversations = mutableMapOf(ChatFixture.CONVERSATION to ChatFixture.messages.toMutableList())
    val metas = mutableMapOf(ChatFixture.CONVERSATION to ConversationMeta("active", null, ChatFixture.messages[2].createdAt))
    val others = mutableMapOf(ChatFixture.CONVERSATION to ChatFixture.OTHER)
    var failSend = false
    var failReads = false
    val writes = mutableListOf<String>()

    override suspend fun allowed(otherUserId: String?) = open && otherUserId !in blockedWith
    override suspend fun inbox(): List<Conversation> { if (failReads) error("offline"); return inboxRows }
    override suspend fun requests() = requestRows
    override suspend fun accept(conversationId: String) {
        writes += "accept:$conversationId"
        requestRows = requestRows.filterNot { it.id == conversationId }
        metas[conversationId]?.let { metas[conversationId] = it.copy(status = "active") }
    }
    override suspend fun decline(conversationId: String) {
        writes += "decline:$conversationId"
        requestRows = requestRows.filterNot { it.id == conversationId }
    }
    override suspend fun otherUserId(conversationId: String) = others[conversationId]
    override suspend fun existingConversation(otherUserId: String) = others.entries.firstOrNull { it.value == otherUserId }?.key
    override suspend fun startConversation(otherUserId: String): String {
        writes += "start:$otherUserId"
        val id = "c-new"
        conversations[id] = mutableListOf()
        metas[id] = ConversationMeta("pending", ChatFixture.ME, null)
        others[id] = otherUserId
        return id
    }
    override suspend fun meta(userId: String, conversationId: String) = metas[conversationId]
    override suspend fun messages(conversationId: String, before: String?): List<ChatMessage> {
        if (failReads) error("offline")
        return conversations[conversationId].orEmpty().sortedByDescending { it.createdAt }
            .filter { before == null || it.createdAt < before }.take(30)
    }
    override suspend fun send(userId: String, conversationId: String, text: String?, image: PickedImage?): ChatMessage {
        if (failSend) error("offline")
        writes += "send:$conversationId:${text.orEmpty()}:${image != null}"
        val message = ChatMessage(
            "sent-${writes.size}", conversationId, userId, text?.trim()?.ifEmpty { null },
            imagePath = image?.let { "$conversationId/$userId-1.${it.extension}" }, createdAt = Instant.now().toString(),
        )
        conversations.getOrPut(conversationId) { mutableListOf() }.add(message)
        return message
    }
    override suspend fun markRead(conversationId: String) { writes += "read:$conversationId" }
    override suspend fun delete(message: ChatMessage) {
        writes += "delete:${message.id}"
    }
    override suspend fun imageUrl(path: String) = "https://example.invalid/$path"

}

object ChatFixture {
    const val ME = "11111111-1111-4111-8111-111111111111"
    const val OTHER = "22222222-2222-4222-8222-222222222222"
    const val CONVERSATION = "c1000000-0000-4000-8000-000000000001"
    private fun ago(minutes: Long) = Instant.now().minusSeconds(minutes * 60).toString()
    val messages = listOf(
        ChatMessage("m1", CONVERSATION, OTHER, "เพิ่งลองร้านกาแฟใหม่แถวบ้าน", createdAt = ago(12)),
        ChatMessage("m2", CONVERSATION, OTHER, "รสชาติดีเกินคาด", createdAt = ago(11)),
        ChatMessage("m4", CONVERSATION, ME, "อยู่ตรงไหนอ่ะ อยากไปลองมั่ง 😍", createdAt = ago(8)),
        ChatMessage("m6", CONVERSATION, ME, "โอเค เดี๋ยวเสาร์นี้ไป", createdAt = ago(3)),
    )
    val inbox = listOf(
        Conversation(CONVERSATION, "active", null, ago(600), OTHER, "mind_coffee", "มายด์", lastMessageText = "แนะนำเลยถ้าผ่านแถวนั้น ☕️", lastMessageAt = ago(5), lastMessageSenderId = OTHER, myLastReadAt = ago(30)),
        Conversation("c2", "active", null, ago(900), "p1", "sky_blue", "Sky", lastMessageImageUrl = "c2/x.jpg", lastMessageAt = ago(60), lastMessageSenderId = ME),
        Conversation("c3", "active", null, ago(3000), "p2", "techdaily", "TechDaily", lastMessageDeletedAt = ago(1440), lastMessageAt = ago(1440), lastMessageSenderId = "p2", myLastReadAt = ago(1000)),
    )
    val requests = listOf(
        Conversation("r1", "pending", "p3", ago(20), "p3", "newfriend", "New Friend", lastMessageText = "สวัสดีครับ", lastMessageAt = ago(20), lastMessageSenderId = "p3"),
    )
}
