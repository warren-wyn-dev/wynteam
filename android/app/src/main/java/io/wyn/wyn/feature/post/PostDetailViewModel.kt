package io.wyn.wyn.feature.post

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.wyn.wyn.R
import io.wyn.wyn.core.data.COMMENT_PAGE_SIZE
import io.wyn.wyn.core.data.Comment
import io.wyn.wyn.core.data.EngagementChange
import io.wyn.wyn.core.data.EngagementSync
import io.wyn.wyn.core.data.FeedRepository
import io.wyn.wyn.core.data.FeedRow
import io.wyn.wyn.core.data.FollowState
import io.wyn.wyn.core.data.HomeIdentity
import io.wyn.wyn.core.data.PostActivity
import io.wyn.wyn.core.data.PostRepository
import io.wyn.wyn.core.data.ViewerState
import io.wyn.wyn.core.data.patched
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.feature.home.FeedText
import io.wyn.wyn.feature.home.Toast
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant
import kotlin.coroutines.cancellation.CancellationException

sealed interface DetailDialog {
    data object More : DetailDialog
    data object Activity : DetailDialog
    data object Edit : DetailDialog
    data object DeletePost : DetailDialog
    data class DeleteComment(val comment: Comment) : DetailDialog
    data object Report : DetailDialog
}

/** web post-detail-route.tsx: the post, its actions, activity, and threaded comments. */
class PostDetailViewModel(
    private val posts: PostRepository,
    private val feed: FeedRepository,
    val userId: String,
    val dropId: String,
    private val sync: EngagementSync = EngagementSync(),
    private val now: () -> Instant = Instant::now,
) : ViewModel() {
    private val source = "detail:$dropId"
    var loading by mutableStateOf(true); private set
    var row by mutableStateOf<FeedRow?>(null); private set
    var viewer by mutableStateOf(ViewerState()); private set
    var images by mutableStateOf<List<String>>(emptyList()); private set
    var comments by mutableStateOf<List<Comment>>(emptyList()); private set
    var hasMoreComments by mutableStateOf(false); private set
    var loadingMore by mutableStateOf(false); private set
    var me by mutableStateOf<HomeIdentity?>(null); private set
    var error by mutableStateOf<UiText?>(null); private set
    var toast by mutableStateOf<Toast?>(null); private set
    var draft by mutableStateOf(""); private set
    var replyTo by mutableStateOf<Comment?>(null); private set
    var sending by mutableStateOf(false); private set
    var followBusy by mutableStateOf(false); private set
    var dialog by mutableStateOf<DetailDialog?>(null); private set
    var editCaption by mutableStateOf(""); private set
    var reportText by mutableStateOf(""); private set
    var activity by mutableStateOf<PostActivity?>(null); private set
    var activityFailed by mutableStateOf(false); private set
    var deleted by mutableStateOf(false); private set
    private var commentPage = 0
    private val inFlight = mutableSetOf<String>()

    init {
        viewModelScope.launch {
            sync.changes.collect { change ->
                if (change.userId != userId || change.dropId != dropId || change.source == source) return@collect
                viewer = viewer.patched(change)
                row = row?.patched(change)
            }
        }
        load()
    }

    fun load() {
        loading = true
        error = null
        viewModelScope.launch {
            try {
                val drop = posts.fetchDrop(dropId)
                if (drop == null) {
                    row = null
                    return@launch
                }
                viewer = feed.loadViewer(userId, listOf(drop))
                val first = posts.fetchComments(userId, dropId, 0)
                images = posts.fetchImages(dropId, drop.imageUrl)
                me = runCatching { feed.fetchIdentity(userId) }.getOrNull()
                row = drop
                comments = first
                commentPage = 0
                hasMoreComments = first.size == COMMENT_PAGE_SIZE
                posts.recordView(dropId)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.post_load_failed)
            } finally {
                loading = false
            }
        }
    }

    /** Top-level comments with their replies underneath, in time order. */
    val threads: List<Pair<Comment, List<Comment>>>
        get() {
            val replies = comments.filter { it.parentId != null }.groupBy { it.parentId }
            return comments.filter { it.parentId == null }.map { it to replies[it.id].orEmpty() }
        }

    val isOwn: Boolean get() = row?.authorId == userId

    /** The web allows editing the caption for 30 minutes after posting. */
    val canEdit: Boolean
        get() {
            val created = row?.createdAt?.let(FeedText::parseInstant) ?: return false
            return isOwn && Duration.between(created, now()) < Duration.ofMinutes(30)
        }

    private fun guarded(key: String, block: suspend () -> Unit) {
        if (!inFlight.add(key)) return
        viewModelScope.launch {
            try {
                block()
            } finally {
                inFlight.remove(key)
            }
        }
    }

    private fun Set<String>.toggle(on: Boolean) = if (on) this + dropId else this - dropId

    fun toggleLike() {
        val current = row ?: return
        val liked = dropId in viewer.liked
        guarded("like") {
            val count = (current.likeCount + if (liked) -1 else 1).coerceAtLeast(0)
            viewer = viewer.copy(liked = viewer.liked.toggle(!liked))
            row = row?.copy(likeCount = count)
            try {
                feed.setLiked(userId, dropId, !liked)
                sync.publish(EngagementChange(userId, dropId, liked = !liked, likeCount = count, source = source))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                viewer = viewer.copy(liked = viewer.liked.toggle(liked))
                row = row?.copy(likeCount = current.likeCount)
                toast = Toast(UiText(R.string.activity_failed))
            }
        }
    }

    fun toggleRepost() {
        val current = row ?: return
        val active = dropId in viewer.redropped
        guarded("redrop") {
            val count = (current.redropCount + if (active) -1 else 1).coerceAtLeast(0)
            viewer = viewer.copy(redropped = viewer.redropped.toggle(!active))
            row = row?.copy(redropCount = count)
            try {
                feed.setRedropped(userId, dropId, !active)
                sync.publish(EngagementChange(userId, dropId, reposted = !active, repostCount = count, source = source))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                viewer = viewer.copy(redropped = viewer.redropped.toggle(active))
                row = row?.copy(redropCount = current.redropCount)
                toast = Toast(UiText(R.string.activity_failed))
            }
        }
    }

    fun toggleSave() {
        val saved = dropId in viewer.saved
        guarded("save") {
            viewer = viewer.copy(saved = viewer.saved.toggle(!saved))
            try {
                feed.setSaved(userId, dropId, !saved)
                sync.publish(EngagementChange(userId, dropId, saved = !saved, source = source))
                toast = if (!saved) Toast(UiText(R.string.post_saved), UiText(R.string.undo)) { undoSave() } else Toast(UiText(R.string.post_unsaved))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                viewer = viewer.copy(saved = viewer.saved.toggle(saved))
                toast = Toast(UiText(R.string.activity_failed))
            }
        }
    }

    private fun undoSave() {
        toast = null
        guarded("save") {
            viewer = viewer.copy(saved = viewer.saved - dropId)
            try {
                feed.setSaved(userId, dropId, false)
                sync.publish(EngagementChange(userId, dropId, saved = false, source = source))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                viewer = viewer.copy(saved = viewer.saved + dropId)
                toast = Toast(UiText(R.string.undo_failed))
            }
        }
    }

    fun toggleFollow() {
        val current = row ?: return
        if (isOwn || followBusy) return
        val author = current.authorId
        followBusy = true
        viewModelScope.launch {
            try {
                val state = feed.toggleFollow(userId, author, author in viewer.following, author in viewer.requested, author in viewer.privateAuthors)
                viewer = viewer.copy(
                    following = if (state == FollowState.Following) viewer.following + author else viewer.following - author,
                    requested = if (state == FollowState.Requested) viewer.requested + author else viewer.requested - author,
                )
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.follow_failed_short)
            } finally {
                followBusy = false
            }
        }
    }

    fun updateDraft(value: String) {
        draft = value.take(500)
    }

    fun replyTo(comment: Comment?) {
        replyTo = comment
    }

    fun submitComment() {
        if (draft.isBlank() || sending) return
        sending = true
        error = null
        viewModelScope.launch {
            try {
                val created = posts.addComment(userId, dropId, draft, replyTo?.id)
                comments = comments + created
                draft = ""
                replyTo = null
                val count = (row?.commentCount ?: 0) + 1
                row = row?.copy(commentCount = count)
                sync.publish(EngagementChange(userId, dropId, commentCount = count, source = source))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.comment_failed)
            } finally {
                sending = false
            }
        }
    }

    fun toggleCommentLike(comment: Comment) {
        guarded("comment:${comment.id}") {
            try {
                posts.setCommentLiked(userId, comment.id, !comment.likedByMe)
                comments = comments.map {
                    if (it.id == comment.id) it.copy(likedByMe = !it.likedByMe, likeCount = (it.likeCount + if (it.likedByMe) -1 else 1).coerceAtLeast(0)) else it
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.comment_like_failed)
            }
        }
    }

    fun deleteComment(comment: Comment) {
        if (comment.authorId != userId) return
        error = null
        viewModelScope.launch {
            try {
                posts.deleteComment(userId, comment.id)
                val removed = setOf(comment.id) + comments.filter { it.parentId == comment.id }.map { it.id }
                comments = comments.filterNot { it.id in removed }
                val count = ((row?.commentCount ?: 0) - removed.size).coerceAtLeast(0)
                row = row?.copy(commentCount = count)
                sync.publish(EngagementChange(userId, dropId, commentCount = count, source = source))
                dialog = null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.comment_delete_failed)
            }
        }
    }

    fun loadMoreComments() {
        if (loadingMore || !hasMoreComments) return
        loadingMore = true
        viewModelScope.launch {
            try {
                val next = posts.fetchComments(userId, dropId, commentPage + 1)
                commentPage += 1
                comments = comments + next.filterNot { n -> comments.any { it.id == n.id } }
                hasMoreComments = next.size == COMMENT_PAGE_SIZE
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.comments_more_failed)
            } finally {
                loadingMore = false
            }
        }
    }

    fun open(value: DetailDialog?) {
        dialog = value
        when (value) {
            DetailDialog.Edit -> editCaption = row?.caption.orEmpty()
            DetailDialog.Report -> reportText = ""
            DetailDialog.Activity -> loadActivity()
            else -> Unit
        }
    }

    private fun loadActivity() {
        activity = null
        activityFailed = false
        viewModelScope.launch {
            try {
                activity = posts.fetchActivity(dropId)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                activityFailed = true
            }
        }
    }

    fun updateEditCaption(value: String) {
        editCaption = value.take(500)
    }

    fun updateReportText(value: String) {
        reportText = value.take(500)
    }

    fun saveEdit() {
        val caption = editCaption.trim().ifEmpty { null }
        viewModelScope.launch {
            try {
                posts.editDrop(dropId, caption)
                row = row?.copy(caption = caption)
                dialog = null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.edit_failed)
            }
        }
    }

    fun deletePost() {
        viewModelScope.launch {
            try {
                posts.deleteDrop(dropId)
                dialog = null
                deleted = true
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.delete_post_failed)
            }
        }
    }

    fun submitReport() {
        val text = reportText.trim()
        if (text.isEmpty()) return
        viewModelScope.launch {
            try {
                feed.report(dropId, "other", text)
                dialog = null
                reportText = ""
                toast = Toast(UiText(R.string.report_sent))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.report_failed)
            }
        }
    }

    fun dismissToast() {
        toast = null
    }

    fun shareUrl() = "https://wynos.online/drop/$dropId"
}
