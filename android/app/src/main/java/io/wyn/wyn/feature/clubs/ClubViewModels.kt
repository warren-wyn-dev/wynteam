package io.wyn.wyn.feature.clubs

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.wyn.wyn.R
import io.wyn.wyn.core.data.CLUB_CATEGORY_MAX
import io.wyn.wyn.core.data.CLUB_DESCRIPTION_MAX
import io.wyn.wyn.core.data.CLUB_MESSAGE_MAX
import io.wyn.wyn.core.data.CLUB_NAME_MAX
import io.wyn.wyn.core.data.CLUB_REPORT_DETAIL_MAX
import io.wyn.wyn.core.data.Club
import io.wyn.wyn.core.data.ClubChannel
import io.wyn.wyn.core.data.ClubDetail
import io.wyn.wyn.core.data.ClubEvent
import io.wyn.wyn.core.data.ClubInvitePreview
import io.wyn.wyn.core.data.ClubMember
import io.wyn.wyn.core.data.ClubMembership
import io.wyn.wyn.core.data.ClubMessage
import io.wyn.wyn.core.data.ClubPost
import io.wyn.wyn.core.data.ClubPostPage
import io.wyn.wyn.core.data.ClubRepository
import io.wyn.wyn.core.data.ClubSections
import io.wyn.wyn.core.data.EngagementChange
import io.wyn.wyn.core.data.EngagementSync
import io.wyn.wyn.core.data.MODERATOR_ROLES
import io.wyn.wyn.core.data.PickedImage
import io.wyn.wyn.core.data.instantMillis
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.feature.home.ReportCategories
import io.wyn.wyn.feature.home.Toast
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.time.Instant
import kotlin.coroutines.cancellation.CancellationException

/** How long a Club poll stays open (web ClubPoll `remaining`). */
sealed interface PollTime {
    data object None : PollTime
    data object Closed : PollTime
    data class Days(val n: Int) : PollTime
    data class Hours(val n: Int) : PollTime
    data class Minutes(val n: Int) : PollTime
}

fun pollTime(expiresAt: String?, now: Instant = Instant.now()): PollTime {
    if (expiresAt == null) return PollTime.None
    val ms = instantMillis(expiresAt) - now.toEpochMilli()
    if (ms <= 0) return PollTime.Closed
    val days = (ms / 86_400_000).toInt()
    if (days >= 1) return PollTime.Days(days)
    val hours = (ms / 3_600_000).toInt()
    if (hours >= 1) return PollTime.Hours(hours)
    return PollTime.Minutes(maxOf(1, (ms / 60_000).toInt()))
}

fun ClubPost.pollClosed(now: Instant = Instant.now()) = pollTime(pollExpiresAt, now) == PollTime.Closed

/** A post's percentage for one option, when results are visible. */
fun ClubPost.pollPercent(index: Int): Int? {
    val counts = pollOptionCounts ?: return null
    val total = pollTotalVotes ?: return null
    if (total <= 0) return 0
    return Math.round((counts.getOrElse(index) { 0 }.toDouble() / total) * 100).toInt()
}

/** Who may do what with a Club post (web ClubPostCard). */
fun ClubPost.own(userId: String) = authorId == userId
fun ClubPost.canModerate() = myRole in MODERATOR_ROLES
fun ClubPost.canDelete(userId: String) = own(userId) || canModerate()
fun ClubPost.canPin(userId: String) = !own(userId) && canModerate()

/** What a report is about (web ReportTarget). */
data class ClubReportTarget(val type: String, val id: String, val label: UiText)

/** The report sheet shared by Club, post and message reports (web ReportSheet). */
class ClubReport(private val scope: CoroutineScope, private val repo: ClubRepository) {
    var target by mutableStateOf<ClubReportTarget?>(null); private set
    var category by mutableStateOf(ReportCategories.first()); private set
    var detail by mutableStateOf(""); private set
    var busy by mutableStateOf(false); private set
    var error by mutableStateOf<UiText?>(null); private set

    fun open(next: ClubReportTarget?) {
        target = next
        category = ReportCategories.first()
        detail = ""
        error = null
    }

    fun choose(value: String) { category = value }
    fun updateDetail(value: String) { detail = value.take(CLUB_REPORT_DETAIL_MAX) }

    fun submit() {
        val current = target ?: return
        if (busy) return
        if (category == "other" && detail.isBlank()) {
            error = UiText(R.string.report_detail_required)
            return
        }
        busy = true
        error = null
        scope.launch {
            try {
                repo.report(current.type, current.id, category, if (category == "other") detail.trim() else null)
                target = null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.report_failed)
            } finally {
                busy = false
            }
        }
    }
}

/** web ExploreClubs. */
class ExploreClubsViewModel(private val repo: ClubRepository, val userId: String) : ViewModel() {
    var sections by mutableStateOf<ClubSections?>(null); private set
    var query by mutableStateOf(""); private set
    var loading by mutableStateOf(true); private set
    var refreshing by mutableStateOf(false); private set
    var joining by mutableStateOf<String?>(null); private set
    var error by mutableStateOf<UiText?>(null); private set
    private var job: Job? = null

    init {
        load()
    }

    fun load(pull: Boolean = false) {
        if (job?.isActive == true) return
        if (pull) refreshing = true
        job = viewModelScope.launch {
            try {
                error = null
                sections = repo.explore(userId)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.clubs_load_failed)
            } finally {
                loading = false
                refreshing = false
            }
        }
    }

    fun updateQuery(value: String) { query = value }

    private fun matches(club: Club): Boolean {
        val q = query.trim().lowercase()
        return q.isEmpty() || club.name.lowercase().contains(q)
    }

    val popular: List<Club> get() = sections?.popular.orEmpty().filter(::matches)
    val newest: List<Club> get() = sections?.newest.orEmpty().filter(::matches)
    fun pending(club: Club) = club.id in sections?.pending.orEmpty()

    fun join(club: Club) {
        if (joining != null) return
        joining = club.id
        error = null
        viewModelScope.launch {
            try {
                repo.join(userId, club)
                job?.join()
                sections = repo.explore(userId)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.clubs_join_failed)
            } finally {
                joining = null
            }
        }
    }
}

/** web MyClubs. */
class MyClubsViewModel(private val repo: ClubRepository, val userId: String) : ViewModel() {
    var rows by mutableStateOf<List<Club>>(emptyList()); private set
    var loading by mutableStateOf(true); private set
    var refreshing by mutableStateOf(false); private set
    var error by mutableStateOf<UiText?>(null); private set
    private var job: Job? = null

    init {
        load()
    }

    fun load(pull: Boolean = false) {
        if (job?.isActive == true) return
        if (pull) refreshing = true else if (error != null) loading = true
        job = viewModelScope.launch {
            try {
                rows = repo.myClubs(userId)
                error = null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.my_clubs_failed)
            } finally {
                loading = false
                refreshing = false
            }
        }
    }
}

/** web CreateClubInner. */
class CreateClubViewModel(private val repo: ClubRepository, val userId: String) : ViewModel() {
    var name by mutableStateOf(""); private set
    var description by mutableStateOf(""); private set
    var category by mutableStateOf(""); private set
    var privacy by mutableStateOf("public"); private set
    var icon by mutableStateOf<PickedImage?>(null); private set
    var saving by mutableStateOf(false); private set
    var error by mutableStateOf<UiText?>(null); private set
    /** Set once the Club exists; the screen then opens it. */
    var createdId by mutableStateOf<String?>(null); private set

    fun updateName(value: String) { name = value.take(CLUB_NAME_MAX) }
    fun updateDescription(value: String) { description = value.take(CLUB_DESCRIPTION_MAX) }
    fun updateCategory(value: String) { category = value.take(CLUB_CATEGORY_MAX) }
    fun choosePrivacy(value: String) { if (value == "public" || value == "private") privacy = value }
    fun pickIcon(value: PickedImage) { icon = value; error = null }
    fun showError(value: UiText?) { error = value }

    val canSubmit: Boolean get() = name.isNotBlank() && !saving

    fun submit() {
        if (!canSubmit) return
        saving = true
        error = null
        viewModelScope.launch {
            try {
                createdId = repo.create(userId, name, description, category, privacy, icon)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.create_club_failed)
                saving = false
            }
        }
    }
}

enum class ClubTab { Posts, Chat, About }

/** A confirm the web asks with window.confirm(). */
sealed interface ClubConfirm {
    data object Leave : ClubConfirm
    data object CancelRequest : ClubConfirm
    data class DeletePost(val post: ClubPost) : ClubConfirm
    data class DeleteMessage(val message: ClubMessage) : ClubConfirm
}

/** Like and save for Club post cards, shared by the Club page and Home (web ClubPostCard). */
abstract class ClubPostsViewModel(
    protected val repo: ClubRepository,
    val userId: String,
    private val sync: EngagementSync,
    private val source: String,
) : ViewModel() {
    var posts by mutableStateOf<List<ClubPost>>(emptyList()); protected set
    var toast by mutableStateOf<Toast?>(null); protected set
    private val inFlight = mutableSetOf<String>()

    init {
        viewModelScope.launch {
            sync.changes.collect { change ->
                if (change.userId != userId || change.source == source) return@collect
                posts = posts.map { post ->
                    if (post.id != change.dropId) post else post.copy(
                        liked = change.liked ?: post.liked,
                        likeCount = change.likeCount ?: post.likeCount,
                        saved = change.saved ?: post.saved,
                    )
                }
            }
        }
    }

    protected fun replace(post: ClubPost) {
        posts = posts.map { if (it.id == post.id) post else it }
    }

    /** Called when a like fails; Home reloads, the Club page rolls back. */
    protected open fun onLikeFailed(previous: ClubPost) = replace(previous)

    fun toggleLike(post: ClubPost) {
        val key = "like:${post.id}"
        if (!inFlight.add(key)) return
        val current = posts.firstOrNull { it.id == post.id } ?: post
        val count = maxOf(0, current.likeCount + if (current.liked) -1 else 1)
        replace(current.copy(liked = !current.liked, likeCount = count))
        sync.publish(EngagementChange(userId, current.id, liked = !current.liked, likeCount = count, source = source))
        viewModelScope.launch {
            try {
                repo.setLiked(userId, current.id, !current.liked)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                sync.publish(EngagementChange(userId, current.id, liked = current.liked, likeCount = current.likeCount, source = source))
                onLikeFailed(current)
                toast = Toast(UiText(R.string.club_like_failed))
            } finally {
                inFlight.remove(key)
            }
        }
    }

    fun toggleSave(post: ClubPost) {
        val key = "save:${post.id}"
        if (!inFlight.add(key)) return
        val current = posts.firstOrNull { it.id == post.id } ?: post
        replace(current.copy(saved = !current.saved))
        viewModelScope.launch {
            try {
                repo.setSaved(userId, current.id, !current.saved)
                sync.publish(EngagementChange(userId, current.id, saved = !current.saved, source = source))
                toast = if (!current.saved) {
                    Toast(UiText(R.string.club_saved), UiText(R.string.undo)) { undoSave(current.id) }
                } else {
                    Toast(UiText(R.string.club_unsaved))
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                replace(current)
                toast = Toast(UiText(R.string.club_save_failed))
            } finally {
                inFlight.remove(key)
            }
        }
    }

    private fun undoSave(postId: String) {
        val key = "save:$postId"
        if (!inFlight.add(key)) return
        toast = null
        posts.firstOrNull { it.id == postId }?.let { replace(it.copy(saved = false)) }
        viewModelScope.launch {
            try {
                repo.setSaved(userId, postId, false)
                sync.publish(EngagementChange(userId, postId, saved = false, source = source))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                posts.firstOrNull { it.id == postId }?.let { replace(it.copy(saved = true)) }
                toast = Toast(UiText(R.string.club_undo_failed))
            } finally {
                inFlight.remove(key)
            }
        }
    }

    fun showToast(value: Toast?) { toast = value }
    fun dismissToast() { toast = null }
}

/** Home "คลับของฉัน": posts from every Club I can read (web fetchClubHomePosts). */
class ClubFeedViewModel(repo: ClubRepository, userId: String, sync: EngagementSync) :
    ClubPostsViewModel(repo, userId, sync, "home-club") {
    var loaded by mutableStateOf(false); private set
    var loading by mutableStateOf(false); private set
    var refreshing by mutableStateOf(false); private set
    var error by mutableStateOf<UiText?>(null); private set
    private var job: Job? = null

    /** Entering the tab always revalidates in the background (web home-screen). */
    fun load(pull: Boolean = false) {
        if (job?.isActive == true) return
        if (pull) refreshing = true else if (!loaded) loading = true
        job = viewModelScope.launch {
            try {
                posts = repo.posts(userId, null)
                loaded = true
                error = null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.clubs_load_failed)
            } finally {
                loading = false
                refreshing = false
            }
        }
    }

    override fun onLikeFailed(previous: ClubPost) {
        replace(previous)
        load()
    }
}

/** web ClubDetailGoldenInner: header, membership, posts, chat and about. */
class ClubViewModel(
    repo: ClubRepository,
    userId: String,
    val clubId: String,
    sync: EngagementSync,
) : ClubPostsViewModel(repo, userId, sync, "club:$clubId") {
    var detail by mutableStateOf<ClubDetail?>(null); private set
    var loading by mutableStateOf(true); private set
    var refreshing by mutableStateOf(false); private set
    var error by mutableStateOf<UiText?>(null); private set
    var busy by mutableStateOf(false); private set
    var tab by mutableStateOf(ClubTab.Posts); private set
    var menuOpen by mutableStateOf(false); private set
    var postMenu by mutableStateOf<ClubPost?>(null); private set
    var confirm by mutableStateOf<ClubConfirm?>(null); private set
    private var postBusy by mutableStateOf(false)
    val report = ClubReport(viewModelScope, repo)
    val chat = ClubChat(viewModelScope, repo, userId, clubId, report, onConfirm = { confirm = it })
    val about = ClubAbout(viewModelScope, repo, clubId)

    init {
        viewModelScope.launch {
            try {
                refresh()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.clubs_load_failed)
            } finally {
                loading = false
            }
        }
    }

    val membership: ClubMembership? get() = detail?.membership
    val approved: Boolean get() = membership?.approved == true
    val pending: Boolean get() = membership?.pending == true
    val owner: Boolean get() = membership?.owner == true
    val canManage: Boolean get() = membership?.canManage == true
    val canReadPosts: Boolean get() = detail?.club?.isPrivate == false || approved

    private suspend fun refresh() {
        val next = repo.detail(userId, clubId) ?: run { detail = null; return }
        val readable = !next.club.isPrivate || next.membership?.approved == true
        val nextPosts = if (readable) repo.posts(userId, clubId) else emptyList()
        detail = next
        posts = nextPosts
        chat.setChannels(next.channels, next.membership)
    }

    private fun refreshQuietly() {
        viewModelScope.launch { runCatching { refresh() } }
    }

    fun pull() {
        if (refreshing) return
        refreshing = true
        viewModelScope.launch {
            try {
                refresh()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // Keep what is on screen, like the web's pull-to-refresh.
            } finally {
                refreshing = false
            }
        }
    }

    fun select(next: ClubTab) { tab = next }
    fun openMenu(open: Boolean) { menuOpen = open }
    fun openPostMenu(post: ClubPost?) { postMenu = post }
    fun dismissConfirm() { confirm = null }

    /** The button under the header: join, or ask before leaving or cancelling. */
    fun onMembershipTap() {
        if (busy || owner) return
        when {
            approved -> confirm = ClubConfirm.Leave
            pending -> confirm = ClubConfirm.CancelRequest
            else -> changeMembership()
        }
    }

    fun confirmNow() {
        when (val current = confirm) {
            null -> Unit
            ClubConfirm.Leave, ClubConfirm.CancelRequest -> { confirm = null; changeMembership() }
            is ClubConfirm.DeletePost -> { confirm = null; deletePost(current.post) }
            is ClubConfirm.DeleteMessage -> { confirm = null; chat.delete(current.message) }
        }
    }

    /** web join(): optimistic membership and member count, rolled back on failure. */
    private fun changeMembership() {
        val current = detail ?: return
        if (busy || current.membership?.owner == true) return
        busy = true
        error = null
        val club = current.club
        val membership = current.membership
        val joiningApproved = membership == null && !club.isPrivate
        val delta = when {
            joiningApproved -> 1
            membership?.approved == true -> -1
            else -> 0
        }
        detail = current.copy(
            membership = if (membership != null) null else ClubMembership("member", if (club.isPrivate) "pending" else "approved"),
            club = club.copy(memberCount = maxOf(0, club.memberCount + delta)),
        )
        viewModelScope.launch {
            try {
                if (membership != null) repo.leave(userId, clubId) else repo.join(userId, club)
                refreshQuietly()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                detail = current
                error = UiText(R.string.club_membership_failed)
            } finally {
                busy = false
            }
        }
    }

    fun toggleMute() {
        val current = detail ?: return
        if (!approved || busy) return
        busy = true
        error = null
        viewModelScope.launch {
            try {
                repo.setMuted(userId, clubId, !current.muted)
                menuOpen = false
                refresh()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.club_mute_failed)
            } finally {
                busy = false
            }
        }
    }

    fun manage() {
        menuOpen = false
        tab = ClubTab.About
    }

    fun leaveFromMenu() {
        menuOpen = false
        onMembershipTap()
    }

    fun reportClub() {
        val club = detail?.club ?: return
        menuOpen = false
        report.open(ClubReportTarget("club", clubId, UiText(R.string.club_report_title, listOf(club.name))))
    }

    fun reportPost(post: ClubPost) {
        postMenu = null
        report.open(ClubReportTarget("club_post", post.id, UiText(R.string.club_post_report_title, listOf(post.authorLabel))))
    }

    fun saveFromMenu(post: ClubPost) {
        toggleSave(post)
        postMenu = null
    }

    fun togglePin(post: ClubPost) {
        if (postBusy || !post.canPin(userId)) return
        val current = posts.firstOrNull { it.id == post.id } ?: post
        replace(current.copy(pinned = !current.pinned))
        postMenu = null
        viewModelScope.launch {
            try {
                repo.setPinned(current.id, !current.pinned)
                refreshQuietly()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                replace(current)
            }
        }
    }

    fun askDelete(post: ClubPost) {
        if (postBusy || !post.canDelete(userId)) return
        confirm = ClubConfirm.DeletePost(post)
    }

    private fun deletePost(post: ClubPost) {
        if (postBusy) return
        postBusy = true
        viewModelScope.launch {
            try {
                repo.deletePost(post.id)
                postMenu = null
                refresh()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // The web leaves the post in place when deleting fails.
            } finally {
                postBusy = false
            }
        }
    }

    fun vote(post: ClubPost, option: Int) {
        val pollId = post.pollId ?: return
        if (postBusy || post.own(userId) || post.pollClosed() || option !in post.pollOptions.indices) return
        postBusy = true
        viewModelScope.launch {
            try {
                repo.vote(userId, pollId, option)
                refresh()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // Unchanged, like the web.
            } finally {
                postBusy = false
            }
        }
    }

    val shareUrl: String get() = "https://wynos.online/club/$clubId"
    fun postShareUrl(post: ClubPost) = "https://wynos.online/club-post/${post.id}"
}

/** web ChatTab (Beta1): channels, the newest 150 messages, send, delete or report. */
class ClubChat(
    private val scope: CoroutineScope,
    private val repo: ClubRepository,
    val userId: String,
    private val clubId: String,
    private val report: ClubReport,
    private val onConfirm: (ClubConfirm) -> Unit,
) {
    var channels by mutableStateOf<List<ClubChannel>>(emptyList()); private set
    var channelId by mutableStateOf<String?>(null); private set
    var messages by mutableStateOf<List<ClubMessage>>(emptyList()); private set
    var loading by mutableStateOf(false); private set
    var sending by mutableStateOf(false); private set
    var draft by mutableStateOf(""); private set
    var image by mutableStateOf<PickedImage?>(null); private set
    var error by mutableStateOf<UiText?>(null); private set
    private var membership: ClubMembership? = null
    private var job: Job? = null
    private var lastRead: String? = null

    val approved: Boolean get() = membership?.approved == true
    val canModerate: Boolean get() = membership?.canModerate == true
    val canSend: Boolean get() = !sending && channelId != null && (draft.isNotBlank() || image != null)

    fun setChannels(next: List<ClubChannel>, member: ClubMembership?) {
        channels = next
        membership = member
        if (channelId == null || next.none { it.id == channelId }) channelId = next.firstOrNull()?.id
    }

    fun select(id: String) {
        if (id == channelId) return
        job?.cancel()
        channelId = id
        messages = emptyList()
        lastRead = null
        reload()
    }

    /** Loads the channel; a spinner only the first time, silent afterwards (polling). */
    fun reload() {
        val channel = channelId
        if (channel == null || !approved) {
            messages = emptyList()
            return
        }
        if (job?.isActive == true) return
        if (messages.isEmpty()) loading = true
        job = scope.launch {
            try {
                val next = repo.messages(channel)
                if (channel != channelId) return@launch
                messages = next
                error = null
                val newest = next.lastOrNull()?.id
                if (newest != lastRead) {
                    lastRead = newest
                    runCatching { repo.markChannelRead(channel) }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                if (channel == channelId) error = UiText(R.string.club_chat_load_failed)
            } finally {
                if (channel == channelId) loading = false
            }
        }
    }

    fun updateDraft(value: String) { draft = value.take(CLUB_MESSAGE_MAX) }
    fun attach(value: PickedImage) { image = value; error = null }
    fun showError(value: UiText?) { error = value }

    fun send() {
        val channel = channelId ?: return
        if (!canSend || !approved) return
        sending = true
        error = null
        val text = draft.trim().ifEmpty { null }
        val photo = image
        scope.launch {
            try {
                repo.sendMessage(userId, clubId, channel, text, photo)
                draft = ""
                image = null
                job?.cancel()
                reload()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.club_chat_send_failed)
            } finally {
                sending = false
            }
        }
    }

    /** web: my message or a moderator deletes (after confirming); anyone else reports. */
    fun onMore(message: ClubMessage) {
        if (message.authorId == userId || canModerate) {
            onConfirm(ClubConfirm.DeleteMessage(message))
        } else {
            report.open(ClubReportTarget("club_channel_message", message.id, UiText(R.string.club_chat_report)))
        }
    }

    fun delete(message: ClubMessage) {
        scope.launch {
            try {
                repo.deleteMessage(message.id)
                messages = messages.filterNot { it.id == message.id }
                job?.cancel()
                reload()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.club_chat_delete_failed)
            }
        }
    }
}

enum class AboutTab { Details, Members, Events, Insights }

/** Which About sections a person sees (web AboutTabView choices). */
fun aboutTabs(membership: ClubMembership?): List<AboutTab> = buildList {
    add(AboutTab.Details)
    add(AboutTab.Members)
    if (membership?.approved == true) add(AboutTab.Events)
    if (membership?.canManage == true) add(AboutTab.Insights)
}

/** web AboutTabView: details, members, events (members) and Insights (owner/admin). */
class ClubAbout(private val scope: CoroutineScope, private val repo: ClubRepository, private val clubId: String) {
    var tab by mutableStateOf(AboutTab.Details); private set
    var members by mutableStateOf<List<ClubMember>>(emptyList()); private set
    var events by mutableStateOf<List<ClubEvent>>(emptyList()); private set
    var insights by mutableStateOf<List<Pair<String, String>>?>(null); private set
    var loading by mutableStateOf(false); private set
    var error by mutableStateOf<UiText?>(null); private set
    private var job: Job? = null

    fun select(next: AboutTab) {
        tab = next
        job?.cancel()
        error = null
        if (next == AboutTab.Details) {
            loading = false
            return
        }
        loading = true
        job = scope.launch {
            try {
                when (next) {
                    AboutTab.Members -> members = repo.members(clubId)
                    AboutTab.Events -> events = repo.events(clubId)
                    AboutTab.Insights -> insights = repo.insights(clubId)
                    AboutTab.Details -> Unit
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.about_failed)
            } finally {
                if (tab == next) loading = false
            }
        }
    }
}

/** web ClubPostRoute: one Club post with its photos. */
class ClubPostViewModel(private val repo: ClubRepository, val postId: String) : ViewModel() {
    var page by mutableStateOf<ClubPostPage?>(null); private set
    var loading by mutableStateOf(true); private set

    init {
        viewModelScope.launch {
            try {
                page = repo.post(postId)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                page = null
            } finally {
                loading = false
            }
        }
    }
}

/** web ClubInviteLinkRoute. */
class ClubInviteViewModel(private val repo: ClubRepository, val code: String) : ViewModel() {
    var preview by mutableStateOf<ClubInvitePreview?>(null); private set
    var loading by mutableStateOf(true); private set
    var busy by mutableStateOf(false); private set
    var joinedId by mutableStateOf<String?>(null); private set
    var message by mutableStateOf<UiText?>(null); private set

    init {
        viewModelScope.launch {
            try {
                preview = repo.previewInvite(code)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                preview = null
            } finally {
                loading = false
            }
        }
    }

    fun redeem() {
        if (busy || preview?.status != "valid") return
        busy = true
        message = null
        viewModelScope.launch {
            try {
                joinedId = repo.redeemInvite(code) ?: preview?.clubId
                message = UiText(R.string.invite_joined)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                message = UiText(R.string.invite_failed)
            } finally {
                busy = false
            }
        }
    }
}
