package io.wyn.wyn.feature.home

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.wyn.wyn.R
import io.wyn.wyn.core.data.EngagementChange
import io.wyn.wyn.core.data.EngagementSync
import io.wyn.wyn.core.data.FeedRepository
import io.wyn.wyn.core.data.QuoteRepository
import io.wyn.wyn.feature.quote.QuoteController
import io.wyn.wyn.core.data.patched
import io.wyn.wyn.core.data.FeedRow
import io.wyn.wyn.core.data.FollowState
import io.wyn.wyn.core.data.HomeIdentity
import io.wyn.wyn.core.data.ViewerState
import io.wyn.wyn.core.data.predictFollowState
import io.wyn.wyn.feature.auth.UiText
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

enum class FeedMode { ForYou, Following, Clubs }

data class FeedSnapshot(
    val rows: List<FeedRow>,
    val viewer: ViewerState,
    val images: Map<String, List<String>>,
    val page: Int = 0,
    val hasMore: Boolean = false,
)

sealed interface PostSheet {
    val row: FeedRow
    data class More(override val row: FeedRow) : PostSheet
    data class Repost(override val row: FeedRow) : PostSheet
    data class Report(override val row: FeedRow) : PostSheet
}

data class Toast(val text: UiText, val actionLabel: UiText? = null, val action: (() -> Unit)? = null)

/** The web's report categories, in the same order. */
val ReportCategories = listOf(
    "spam", "scam", "harassment", "hate", "sexual_content", "violence", "privacy", "illegal_content", "copyright", "other",
)

/**
 * A feed of post cards with tabs of type [K], following web
 * home-screen.tsx and profile-route.tsx: one cached snapshot per tab,
 * optimistic like/save/repost/follow with rollback, hide with undo, report,
 * and "see more" paging where the tab has a page size.
 */
open class FeedViewModel<K : Any>(
    private val repo: FeedRepository,
    val userId: String,
    private val sync: EngagementSync,
    quotes: QuoteRepository?,
    initial: K,
    private val source: String,
    private val fetchRows: suspend (tab: K, page: Int) -> List<FeedRow>,
    private val pageSize: (K) -> Int? = { null },
) : ViewModel() {
    var mode by mutableStateOf(initial); private set
    private val cache = mutableMapOf<K, FeedSnapshot>()
    var snapshot by mutableStateOf<FeedSnapshot?>(null); private set
    var loading by mutableStateOf(false); private set
    var loadingMore by mutableStateOf(false); private set
    var refreshing by mutableStateOf(false); private set
    var error by mutableStateOf<UiText?>(null); private set
    var toast by mutableStateOf<Toast?>(null); protected set
    var sheet by mutableStateOf<PostSheet?>(null); private set
    var hidden by mutableStateOf<Pair<FeedRow, Int>?>(null); private set
    var reportCategory by mutableStateOf(ReportCategories.first()); private set
    var reportDetail by mutableStateOf(""); private set
    var reportError by mutableStateOf<UiText?>(null); private set
    var busy by mutableStateOf(false); private set
    private val inFlight = mutableSetOf<String>()
    private var loadJob: Job? = null

    /** Quote cards: their own likes, saves, reposts, menu and the quote composer. */
    val quote: QuoteController? = quotes?.let { QuoteController(viewModelScope, it, userId, onToast = { text -> toast = Toast(text) }) }

    init {
        viewModelScope.launch {
            sync.changes.collect { change ->
                if (change.userId != userId || change.source == source) return@collect
                for ((key, cached) in cache.toMap()) {
                    cache[key] = cached.copy(viewer = cached.viewer.patched(change), rows = cached.rows.map { it.patched(change) })
                }
                snapshot = cache[mode] ?: snapshot
            }
        }
        load(initial)
    }

    fun select(next: K) {
        if (next == mode) return
        mode = next
        val cached = cache[next]
        if (cached != null) {
            snapshot = cached
            error = null
        } else {
            load(next)
        }
    }

    private suspend fun fetch(target: K, page: Int = 0, before: List<FeedRow> = emptyList()): FeedSnapshot {
        val fresh = fetchRows(target, page)
        val rows = (before + fresh).distinctBy { it.key }
        val viewer = repo.loadViewer(userId, rows)
        val images = repo.fetchImages(rows)
        // A Quote's counts are its own, loaded separately; a failure only affects those cards.
        quote?.load(fresh)
        val size = pageSize(target)
        return FeedSnapshot(rows, viewer, images, page, size != null && fresh.size == size)
    }

    /** web ProfileFeed "ดูเพิ่มเติม": the next page, appended. */
    fun loadMore() {
        val current = snapshot ?: return
        if (!current.hasMore || loadingMore) return
        val target = mode
        loadingMore = true
        viewModelScope.launch {
            try {
                val next = fetch(target, current.page + 1, current.rows)
                cache[target] = next
                if (mode == target) snapshot = next
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                toast = Toast(UiText(R.string.feed_load_failed))
            } finally {
                loadingMore = false
            }
        }
    }

    fun load(target: K = mode) {
        loadJob?.cancel()
        loading = cache[target] == null
        error = null
        if (cache[target] == null && target == mode) snapshot = null
        loadJob = viewModelScope.launch {
            try {
                val next = fetch(target)
                cache[target] = next
                if (mode == target) snapshot = next
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                if (mode == target) error = UiText(R.string.feed_load_failed)
            } finally {
                if (mode == target) loading = false
            }
        }
    }

    fun refresh() {
        if (refreshing) return
        val target = mode
        refreshing = true
        viewModelScope.launch {
            try {
                val next = fetch(target)
                cache[target] = next
                if (mode == target) {
                    snapshot = next
                    error = null
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                if (mode == target) error = UiText(R.string.feed_refresh_failed)
            } finally {
                refreshing = false
            }
        }
    }

    private fun update(transform: (FeedSnapshot) -> FeedSnapshot) {
        val current = snapshot ?: return
        val next = transform(current)
        snapshot = next
        cache[mode] = next
        // Other tabs can show the same post: keep their likes, saves and counts in step.
        val counts = next.rows.associate { it.id to (it.likeCount to it.redropCount) }
        for ((key, other) in cache.toMap()) {
            if (key == mode) continue
            cache[key] = other.copy(
                viewer = other.viewer.mergedWith(next),
                rows = other.rows.map { row -> counts[row.id]?.let { (likes, reposts) -> row.copy(likeCount = likes, redropCount = reposts) } ?: row },
            )
        }
    }

    /** Takes [source]'s answer for the posts and authors it shows; keeps ours for the rest. */
    private fun ViewerState.mergedWith(source: FeedSnapshot): ViewerState {
        val posts = source.rows.map { it.id }.toSet()
        val authors = source.rows.map { it.authorId }.toSet()
        fun Set<String>.take(from: Set<String>, scope: Set<String>) = (this - scope) + (from intersect scope)
        val v = source.viewer
        return copy(
            liked = liked.take(v.liked, posts),
            saved = saved.take(v.saved, posts),
            redropped = redropped.take(v.redropped, posts),
            following = following.take(v.following, authors),
            requested = requested.take(v.requested, authors),
        )
    }

    private fun ViewerState.with(liked: Set<String> = this.liked, saved: Set<String> = this.saved, redropped: Set<String> = this.redropped) =
        copy(liked = liked, saved = saved, redropped = redropped)

    private fun Set<String>.toggle(id: String, on: Boolean) = if (on) this + id else this - id

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

    fun toggleLike(row: FeedRow) {
        val viewer = snapshot?.viewer ?: return
        val liked = row.id in viewer.liked
        guarded("like:${row.id}") {
            val delta = if (liked) -1 else 1
            update { s -> s.copy(viewer = s.viewer.with(liked = s.viewer.liked.toggle(row.id, !liked)), rows = s.rows.map { if (it.id == row.id) it.copy(likeCount = (it.likeCount + delta).coerceAtLeast(0)) else it }) }
            try {
                repo.setLiked(userId, row.id, !liked)
                sync.publish(EngagementChange(userId, row.id, liked = !liked, likeCount = (row.likeCount + delta).coerceAtLeast(0), source = source))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                update { s -> s.copy(viewer = s.viewer.with(liked = s.viewer.liked.toggle(row.id, liked)), rows = s.rows.map { if (it.id == row.id) it.copy(likeCount = (it.likeCount - delta).coerceAtLeast(0)) else it }) }
                toast = Toast(UiText(R.string.like_failed))
            }
        }
    }

    /** Double-tap on a photo only ever likes. */
    fun likeFromPhoto(row: FeedRow) {
        if (snapshot?.viewer?.liked?.contains(row.id) == false) toggleLike(row)
    }

    fun toggleSave(row: FeedRow) {
        val viewer = snapshot?.viewer ?: return
        val saved = row.id in viewer.saved
        guarded("save:${row.id}") {
            update { s -> s.copy(viewer = s.viewer.with(saved = s.viewer.saved.toggle(row.id, !saved))) }
            try {
                repo.setSaved(userId, row.id, !saved)
                sync.publish(EngagementChange(userId, row.id, saved = !saved, source = source))
                toast = if (!saved) {
                    Toast(UiText(R.string.post_saved), UiText(R.string.undo)) { undoSave(row) }
                } else {
                    Toast(UiText(R.string.post_unsaved))
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                update { s -> s.copy(viewer = s.viewer.with(saved = s.viewer.saved.toggle(row.id, saved))) }
                toast = Toast(UiText(R.string.save_failed))
            }
        }
    }

    private fun undoSave(row: FeedRow) {
        toast = null
        guarded("save:${row.id}") {
            update { s -> s.copy(viewer = s.viewer.with(saved = s.viewer.saved - row.id)) }
            try {
                repo.setSaved(userId, row.id, false)
                sync.publish(EngagementChange(userId, row.id, saved = false, source = source))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                update { s -> s.copy(viewer = s.viewer.with(saved = s.viewer.saved + row.id)) }
                toast = Toast(UiText(R.string.undo_failed))
            }
        }
    }

    fun toggleRepost(row: FeedRow) {
        val viewer = snapshot?.viewer ?: return
        val active = row.id in viewer.redropped
        guarded("redrop:${row.id}") {
            busy = true
            val delta = if (active) -1 else 1
            update { s -> s.copy(viewer = s.viewer.with(redropped = s.viewer.redropped.toggle(row.id, !active)), rows = s.rows.map { if (it.id == row.id) it.copy(redropCount = (it.redropCount + delta).coerceAtLeast(0)) else it }) }
            try {
                repo.setRedropped(userId, row.id, !active)
                sync.publish(EngagementChange(userId, row.id, reposted = !active, repostCount = (row.redropCount + delta).coerceAtLeast(0), source = source))
                sheet = null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                update { s -> s.copy(viewer = s.viewer.with(redropped = s.viewer.redropped.toggle(row.id, active)), rows = s.rows.map { if (it.id == row.id) it.copy(redropCount = (it.redropCount - delta).coerceAtLeast(0)) else it }) }
                toast = Toast(UiText(R.string.repost_failed))
            } finally {
                busy = false
            }
        }
    }

    fun removeMyRepost(row: FeedRow) {
        val redropId = row.redropId ?: return
        sheet = null
        viewModelScope.launch {
            try {
                repo.deleteRedrop(userId, redropId)
                refresh()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                toast = Toast(UiText(R.string.err_generic))
            }
        }
    }

    fun toggleFollow(row: FeedRow) {
        val viewer = snapshot?.viewer ?: return
        val author = row.authorId
        if (author == userId) return
        val following = author in viewer.following
        val requested = author in viewer.requested
        val isPrivate = author in viewer.privateAuthors
        fun apply(state: FollowState) = update { s ->
            s.copy(
                viewer = s.viewer.copy(
                    following = s.viewer.following.toggle(author, state == FollowState.Following),
                    requested = s.viewer.requested.toggle(author, state == FollowState.Requested),
                ),
            )
        }
        guarded("follow:$author") {
            apply(predictFollowState(following, requested, isPrivate))
            try {
                apply(repo.toggleFollow(userId, author, following, requested, isPrivate))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                apply(if (following) FollowState.Following else if (requested) FollowState.Requested else FollowState.None)
                toast = Toast(UiText(R.string.follow_failed))
            }
        }
    }

    fun hide(row: FeedRow) {
        val current = snapshot ?: return
        val index = current.rows.indexOfFirst { it.key == row.key }.coerceAtLeast(0)
        update { s -> s.copy(rows = s.rows.filterNot { it.key == row.key }) }
        hidden = row to index
        sheet = null
        viewModelScope.launch {
            try {
                repo.hide(userId, row.id)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                hidden = null
                refresh()
            }
        }
    }

    fun undoHide() {
        val (row, index) = hidden ?: return
        hidden = null
        update { s -> s.copy(rows = s.rows.toMutableList().apply { add(index.coerceAtMost(size), row) }) }
        viewModelScope.launch {
            try {
                repo.unhide(userId, row.id)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                refresh()
            }
        }
    }

    fun dismissHidden() {
        hidden = null
    }

    fun openSheet(value: PostSheet?) {
        sheet = value
        if (value is PostSheet.Report) {
            reportCategory = ReportCategories.first()
            reportDetail = ""
            reportError = null
        }
    }

    fun chooseReportCategory(value: String) {
        reportCategory = value
        reportError = null
    }

    fun updateReportDetail(value: String) {
        reportDetail = value.take(1000)
        reportError = null
    }

    fun submitReport() {
        val row = (sheet as? PostSheet.Report)?.row ?: return
        if (busy) return
        if (reportCategory == "other" && reportDetail.isBlank()) {
            reportError = UiText(R.string.report_detail_required)
            return
        }
        busy = true
        viewModelScope.launch {
            try {
                repo.report(row.id, reportCategory, if (reportCategory == "other") reportDetail.trim() else null)
                sheet = null
                toast = Toast(UiText(R.string.report_sent))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                reportError = UiText(R.string.report_failed)
            } finally {
                busy = false
            }
        }
    }

    fun dismissToast() {
        toast = null
    }

    /** The web's share link for a post; a Quote links to its own page. */
    fun shareUrl(row: FeedRow) = if (row.isQuote) "https://wynos.online/quote/${row.redropId}" else "https://wynos.online/drop/${row.id}"

    /** Removes a deleted Quote from every tab. */
    fun removeQuote(row: FeedRow) {
        for ((key, cached) in cache.toMap()) cache[key] = cached.copy(rows = cached.rows.filterNot { it.redropId == row.redropId })
        snapshot = cache[mode] ?: snapshot
    }
}

/** Home: For You / Following / My Clubs, plus who is signed in for the quick composer. */
class HomeViewModel(
    repo: FeedRepository,
    userId: String,
    sync: EngagementSync = EngagementSync(),
    quotes: QuoteRepository? = null,
) : FeedViewModel<FeedMode>(
    repo, userId, sync, quotes, FeedMode.ForYou, "home",
    fetchRows = { mode, _ ->
        when (mode) {
            FeedMode.ForYou -> repo.fetchRanked()
            FeedMode.Following -> repo.fetchFollowing(userId)
            FeedMode.Clubs -> emptyList() // Club posts arrive with the Clubs milestone (M6).
        }
    },
) {
    private val identities = repo
    var identity by mutableStateOf<HomeIdentity?>(null); private set

    init {
        reloadIdentity()
    }

    /** After editing the profile, the quick composer shows the new photo and name. */
    fun reloadIdentity() {
        viewModelScope.launch { runCatching { identities.fetchIdentity(userId) }.getOrNull()?.let { identity = it } }
    }
}
