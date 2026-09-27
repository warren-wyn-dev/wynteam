package io.wyn.wyn.core.data

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow

/**
 * A like, save, repost or comment made on one screen, so every other
 * screen showing the same post updates too (the web's drop-engagement-sync).
 * Null fields did not change.
 */
data class EngagementChange(
    val userId: String,
    val dropId: String,
    val liked: Boolean? = null,
    val likeCount: Int? = null,
    val saved: Boolean? = null,
    val reposted: Boolean? = null,
    val repostCount: Int? = null,
    val commentCount: Int? = null,
    val source: String,
)

class EngagementSync {
    private val flow = MutableSharedFlow<EngagementChange>(extraBufferCapacity = 64)
    val changes: SharedFlow<EngagementChange> get() = flow
    fun publish(change: EngagementChange) {
        flow.tryEmit(change)
    }
}

fun ViewerState.patched(change: EngagementChange): ViewerState {
    fun Set<String>.set(on: Boolean?) = when (on) {
        null -> this
        true -> this + change.dropId
        false -> this - change.dropId
    }
    return copy(liked = liked.set(change.liked), saved = saved.set(change.saved), redropped = redropped.set(change.reposted))
}

fun FeedRow.patched(change: EngagementChange): FeedRow = if (id != change.dropId) this else copy(
    likeCount = change.likeCount ?: likeCount,
    redropCount = change.repostCount ?: redropCount,
    commentCount = change.commentCount ?: commentCount,
)
