package io.wyn.wyn.feature.chat

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.wyn.wyn.R
import io.wyn.wyn.core.data.CHAT_PAGE_SIZE
import io.wyn.wyn.core.data.ChatMessage
import io.wyn.wyn.core.data.ChatRepository
import io.wyn.wyn.core.data.Conversation
import io.wyn.wyn.core.data.ConversationMeta
import io.wyn.wyn.core.data.FeedRepository
import io.wyn.wyn.core.data.FollowState
import io.wyn.wyn.core.data.PickedImage
import io.wyn.wyn.core.data.Profile
import io.wyn.wyn.core.data.ProfileRepository
import io.wyn.wyn.core.data.ProfileSummary
import io.wyn.wyn.core.data.predictFollowState
import io.wyn.wyn.feature.auth.UiText
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

/** web conversationPreview(). */
fun previewKind(row: Conversation): Preview = when {
    row.lastMessageDeletedAt != null -> Preview.Deleted
    !row.lastMessageText.isNullOrBlank() -> Preview.Text(row.lastMessageText)
    row.lastMessageImageUrl != null -> Preview.Photo
    row.status == "pending" -> Preview.Waiting
    else -> Preview.Start
}

sealed interface Preview {
    data object Deleted : Preview
    data class Text(val text: String) : Preview
    data object Photo : Preview
    data object Waiting : Preview
    data object Start : Preview
}

enum class InboxView { Inbox, Requests }

/** web chat-inbox-parity.tsx: conversations, search, and message requests. */
class ChatInboxViewModel(private val repo: ChatRepository, val userId: String) : ViewModel() {
    /** Null while checking; false when chat is closed for everyone (lockdown). */
    var allowed by mutableStateOf<Boolean?>(null); private set
    var rows by mutableStateOf<List<Conversation>>(emptyList()); private set
    var requests by mutableStateOf<List<Conversation>>(emptyList()); private set
    var loading by mutableStateOf(true); private set
    var error by mutableStateOf<UiText?>(null); private set
    var view by mutableStateOf(InboxView.Inbox); private set
    var searchOpen by mutableStateOf(false); private set
    var query by mutableStateOf(""); private set
    var confirmDecline by mutableStateOf<Conversation?>(null); private set
    private var job: Job? = null

    init {
        load()
    }

    val unreadCount: Int get() = rows.count { it.isUnread(userId) }

    fun load() {
        if (job?.isActive == true) return
        job = viewModelScope.launch {
            try {
                val open = repo.allowed()
                allowed = open
                if (!open) {
                    rows = emptyList(); requests = emptyList()
                } else {
                    rows = repo.inbox()
                    requests = repo.requests()
                }
                error = null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.chat_load_failed)
            } finally {
                loading = false
            }
        }
    }

    fun show(value: InboxView) {
        view = value
        error = null
    }

    fun toggleSearch() {
        searchOpen = !searchOpen
        if (!searchOpen) query = ""
    }

    fun updateQuery(value: String) {
        query = value.take(100)
    }

    /** Names, usernames and the last message, like the web's search. */
    fun visible(previewText: (Conversation) -> String): List<Conversation> {
        val q = query.trim().lowercase()
        if (q.isEmpty()) return rows
        return rows.filter { row ->
            row.otherLabel.lowercase().contains(q) || row.otherUsername.lowercase().contains(q) || previewText(row).lowercase().contains(q)
        }
    }

    fun accept(row: Conversation) = decide(row, accept = true)

    fun askDecline(row: Conversation) {
        confirmDecline = row
    }

    fun dismissDecline() {
        confirmDecline = null
    }

    fun decline() {
        val row = confirmDecline ?: return
        confirmDecline = null
        decide(row, accept = false)
    }

    private fun decide(row: Conversation, accept: Boolean) {
        viewModelScope.launch {
            try {
                if (accept) repo.accept(row.id) else repo.decline(row.id)
                val remaining = requests.size
                job?.cancel()
                job = null
                load()
                if (remaining <= 1) view = InboxView.Inbox
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.chat_request_failed)
            }
        }
    }
}

sealed interface ChatConfirm {
    data class DeleteMessage(val message: ChatMessage) : ChatConfirm
    data object DeclineRequest : ChatConfirm
    data object CancelFollowRequest : ChatConfirm
}

/**
 * web ConversationInner (Web Beta 1): the thread, sending text and a photo,
 * deleting your own message, read receipts, message requests, and a new
 * conversation that only exists once the first message is sent.
 */
class ConversationViewModel(
    private val repo: ChatRepository,
    private val profiles: ProfileRepository,
    private val feed: FeedRepository,
    val userId: String,
    startConversationId: String?,
    otherUserHint: String?,
) : ViewModel() {
    var conversationId by mutableStateOf(startConversationId); private set
    val composeMode: Boolean get() = conversationId == null
    var otherId by mutableStateOf(otherUserHint); private set
    var other by mutableStateOf<Profile?>(null); private set
    var summary by mutableStateOf<ProfileSummary?>(null); private set
    /** Newest first, as loaded. */
    var messages by mutableStateOf<List<ChatMessage>>(emptyList()); private set
    var meta by mutableStateOf<ConversationMeta?>(null); private set
    var loading by mutableStateOf(true); private set
    var loadingMore by mutableStateOf(false); private set
    var hasMore by mutableStateOf(false); private set
    var draft by mutableStateOf(""); private set
    var photo by mutableStateOf<PickedImage?>(null); private set
    var sending by mutableStateOf(false); private set
    var followBusy by mutableStateOf(false); private set
    var error by mutableStateOf<UiText?>(null); private set
    var toast by mutableStateOf<UiText?>(null); private set
    var revealed by mutableStateOf<String?>(null); private set
    var confirm by mutableStateOf<ChatConfirm?>(null); private set
    var closed by mutableStateOf(false); private set
    /** This conversation cannot be used (blocked, chat closed, or not found): nothing can be sent. */
    var blocked by mutableStateOf(false); private set
    private var refreshJob: Job? = null

    /** Oldest first, for display. */
    val ordered: List<ChatMessage> get() = messages.asReversed()
    val recipientPending: Boolean get() = meta?.status == "pending" && meta?.requestedBy != userId
    val requesterPending: Boolean get() = meta?.status == "pending" && meta?.requestedBy == userId

    init {
        viewModelScope.launch { open() }
    }

    private suspend fun open() {
        try {
            val id = otherId ?: conversationId?.let { repo.otherUserId(it) }
            otherId = id
            if (composeMode) {
                if (id == null) throw ChatBlocked(R.string.chat_no_person)
                if (!repo.allowed(id)) throw ChatBlocked(R.string.chat_cannot_open)
                // An existing conversation (either direction) opens instead of a fresh composer.
                repo.existingConversation(id)?.let { existing -> conversationId = existing }
                loadPerson(id)
                if (composeMode) return
            } else if (id != null) {
                if (!repo.allowed(id)) throw ChatBlocked(R.string.chat_cannot_open)
                loadPerson(id)
            }
            refresh()
        } catch (e: CancellationException) {
            throw e
        } catch (e: ChatBlocked) {
            blocked = true
            error = UiText(e.reason)
        } catch (e: Exception) {
            error = UiText(R.string.chat_conversation_failed)
        } finally {
            loading = false
        }
    }

    private suspend fun loadPerson(id: String) {
        val next = profiles.summary(userId, id)
        summary = next
        other = next?.profile
    }

    private suspend fun refresh() {
        val id = conversationId ?: return
        val next = repo.messages(id)
        // Keep a message still being sent at the top until it arrives.
        messages = messages.filter { it.pending } + next
        meta = repo.meta(userId, id)
        hasMore = next.size == CHAT_PAGE_SIZE && messages.size <= CHAT_PAGE_SIZE
        runCatching { repo.markRead(id) }
    }

    /** A push, the screen coming back, or the regular check while open. */
    fun onHint() {
        if (composeMode || refreshJob?.isActive == true || sending) return
        refreshJob = viewModelScope.launch {
            try {
                val id = conversationId ?: return@launch
                val newest = repo.messages(id)
                val older = messages.filter { m -> !m.pending && newest.none { it.id == m.id } && (newest.isEmpty() || m.createdAt < newest.last().createdAt) }
                messages = messages.filter { it.pending } + newest + older
                meta = repo.meta(userId, id)
                runCatching { repo.markRead(id) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // The next check tries again.
            }
        }
    }

    fun loadOlder() {
        val id = conversationId ?: return
        val oldest = messages.lastOrNull { !it.pending } ?: return
        if (loadingMore) return
        loadingMore = true
        viewModelScope.launch {
            try {
                val older = repo.messages(id, oldest.createdAt)
                messages = messages + older.filter { item -> messages.none { it.id == item.id } }
                hasMore = older.size == CHAT_PAGE_SIZE
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                toast = UiText(R.string.chat_older_failed)
            } finally {
                loadingMore = false
            }
        }
    }

    fun updateDraft(value: String) {
        draft = value.take(MESSAGE_MAX)
    }

    fun attach(image: PickedImage?) {
        photo = image
    }

    fun showError(value: UiText?) {
        error = value
    }

    val canSend: Boolean get() = !blocked && !loading && !sending && (draft.isNotBlank() || photo != null) && (!composeMode || otherId != null)

    fun send() {
        if (!canSend) return
        val text = draft.trim()
        val image = photo
        val temp = ChatMessage(
            id = "pending-${System.nanoTime()}", conversationId = conversationId.orEmpty(), senderId = userId,
            text = text.ifEmpty { null }, imagePath = null, createdAt = java.time.Instant.now().toString(), pending = true,
        )
        messages = listOf(temp) + messages
        draft = ""
        photo = null
        sending = true
        error = null
        viewModelScope.launch {
            try {
                // A new conversation (and, when needed, the message request) is created only now, at the first send.
                val id = conversationId ?: repo.startConversation(otherId ?: error("no person"))
                val created = repo.send(userId, id, text, image)
                val wasCompose = conversationId == null
                conversationId = id
                messages = messages.filterNot { it.id == temp.id }.let { rest -> if (rest.any { it.id == created.id }) rest else listOf(created) + rest }
                if (wasCompose) refresh() else runCatching { repo.markRead(id) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                messages = messages.filterNot { it.id == temp.id }
                draft = text
                photo = image
                error = UiText(R.string.chat_send_failed)
                toast = UiText(R.string.chat_send_failed_restored)
            } finally {
                sending = false
            }
        }
    }

    /** Web Beta 1: tapping your own message shows its delete button. */
    fun toggleReveal(message: ChatMessage) {
        if (message.senderId != userId || message.deletedAt != null || message.pending) return
        revealed = if (revealed == message.id) null else message.id
    }

    fun askDelete(message: ChatMessage) {
        if (message.senderId == userId) confirm = ChatConfirm.DeleteMessage(message)
    }

    fun dismissConfirm() {
        confirm = null
    }

    fun confirmNow() {
        when (val question = confirm) {
            is ChatConfirm.DeleteMessage -> delete(question.message)
            ChatConfirm.DeclineRequest -> decline(confirmed = true)
            ChatConfirm.CancelFollowRequest -> toggleFollow(confirmed = true)
            null -> Unit
        }
        confirm = null
    }

    private fun delete(message: ChatMessage) {
        if (message.senderId != userId) return
        viewModelScope.launch {
            try {
                repo.delete(message)
                val now = java.time.Instant.now().toString()
                messages = messages.map { if (it.id == message.id) it.copy(text = null, imagePath = null, deletedAt = now) else it }
                revealed = null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.chat_delete_failed)
            }
        }
    }

    fun accept() {
        val id = conversationId ?: return
        viewModelScope.launch {
            try {
                repo.accept(id)
                refresh()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.chat_accept_failed)
            }
        }
    }

    fun decline(confirmed: Boolean = false) {
        val id = conversationId ?: return
        if (!confirmed) {
            confirm = ChatConfirm.DeclineRequest
            return
        }
        viewModelScope.launch {
            try {
                repo.decline(id)
                closed = true
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.chat_decline_failed)
            }
        }
    }

    fun toggleFollow(confirmed: Boolean = false) {
        val person = other ?: return
        val current = summary ?: return
        if (followBusy) return
        if (current.requested && person.isPrivate && !confirmed) {
            confirm = ChatConfirm.CancelFollowRequest
            return
        }
        val next = predictFollowState(current.following, current.requested, person.isPrivate)
        followBusy = true
        summary = current.copy(following = next == FollowState.Following, requested = next == FollowState.Requested)
        viewModelScope.launch {
            try {
                val result = feed.toggleFollow(userId, person.id, current.following, current.requested, person.isPrivate)
                summary = summary?.copy(following = result == FollowState.Following, requested = result == FollowState.Requested)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                summary = summary?.copy(following = current.following, requested = current.requested)
                toast = UiText(R.string.follow_failed)
            } finally {
                followBusy = false
            }
        }
    }

    fun dismissToast() {
        toast = null
    }

    private class ChatBlocked(val reason: Int) : Exception()

    companion object {
        /** The database has no limit; this only stops a runaway paste. */
        const val MESSAGE_MAX = 5000
    }
}
