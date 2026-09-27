package io.wyn.wyn.feature.notifications

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.wyn.wyn.R
import io.wyn.wyn.core.data.NOTIFICATION_PAGE_SIZE
import io.wyn.wyn.core.data.NotificationItem
import io.wyn.wyn.core.data.NotificationRepository
import io.wyn.wyn.core.data.mergeNewestNotificationPage
import io.wyn.wyn.feature.auth.UiText
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import kotlin.coroutines.cancellation.CancellationException

enum class DayBucket { Today, Yesterday, Older }

/** Several likes (or comments, reposts, follows) on the same thing in one day show as one row. */
data class NotificationGroup(val head: NotificationItem, val items: List<NotificationItem>, val extraActorCount: Int)

data class NotificationSection(val bucket: DayBucket, val groups: List<NotificationGroup>)

/** web notifications-route.tsx grouping rules. */
object NotificationRules {
    private val groupable = setOf("like_drop", "like_pop", "comment_drop", "comment_pop", "redrop", "follow")

    fun isMention(row: NotificationItem) = row.type == "mention_drop" || row.type == "mention_club_post"

    fun bucketFor(createdAt: String, today: LocalDate, zone: ZoneId): DayBucket {
        val day = runCatching { Instant.parse(createdAt).atZone(zone).toLocalDate() }.getOrNull() ?: return DayBucket.Older
        val diff = ChronoUnit.DAYS.between(day, today)
        return when {
            diff <= 0 -> DayBucket.Today
            diff == 1L -> DayBucket.Yesterday
            else -> DayBucket.Older
        }
    }

    private fun groupKey(row: NotificationItem): String? =
        if (row.type in groupable) "${row.type}:${row.dropId ?: row.popId ?: ""}" else null

    fun groupWithinDay(items: List<NotificationItem>): List<NotificationGroup> {
        val groups = mutableListOf<MutableList<NotificationItem>>()
        val indexByKey = HashMap<String, Int>()
        for (row in items) {
            val key = groupKey(row)
            val existing = key?.let(indexByKey::get)
            if (existing == null) {
                if (key != null) indexByKey[key] = groups.size
                groups += mutableListOf(row)
            } else {
                groups[existing] += row
            }
        }
        return groups.map { list ->
            NotificationGroup(list.first(), list, list.drop(1).mapNotNull { it.actorId }.toSet().size)
        }
    }

    fun sections(items: List<NotificationItem>, today: LocalDate, zone: ZoneId): List<NotificationSection> =
        DayBucket.entries.mapNotNull { bucket ->
            val rows = items.filter { bucketFor(it.createdAt, today, zone) == bucket }
            if (rows.isEmpty()) null else NotificationSection(bucket, groupWithinDay(rows))
        }
}

enum class NotificationTab { All, Mentions }

/**
 * web NotificationsInner: newest page first, "see more", unread highlight
 * captured when the screen opened, and marking read only what was shown.
 */
class NotificationsViewModel(
    private val repo: NotificationRepository,
    val userId: String,
    private val onMarkedRead: () -> Unit = {},
) : ViewModel() {
    var rows by mutableStateOf<List<NotificationItem>>(emptyList()); private set
    var unreadSnapshot by mutableStateOf<Set<String>>(emptySet()); private set
    var hasMore by mutableStateOf(false); private set
    var loading by mutableStateOf(true); private set
    var refreshing by mutableStateOf(false); private set
    var loaded by mutableStateOf(false); private set
    var error by mutableStateOf<UiText?>(null); private set
    var tab by mutableStateOf(NotificationTab.All); private set
    private var page by mutableIntStateOf(0)
    private var request = 0
    private var hintJob: Job? = null

    val visible: List<NotificationItem> get() = if (tab == NotificationTab.Mentions) rows.filter(NotificationRules::isMention) else rows

    init {
        load(0, append = false, markExisting = true)
    }

    fun select(value: NotificationTab) {
        tab = value
    }

    fun pullToRefresh() {
        refreshing = true
        load(0, append = false, markExisting = true)
    }

    fun loadMore() {
        if (loading || !hasMore) return
        load(page + 1, append = true, markExisting = false)
    }

    fun retry() = load(0, append = false, markExisting = true)

    /** A push or the app coming back: one quiet re-read of the newest page. */
    fun onHint() {
        hintJob?.cancel()
        hintJob = viewModelScope.launch {
            delay(140)
            load(0, append = false, markExisting = false)
        }
    }

    private fun load(nextPage: Int, append: Boolean, markExisting: Boolean) {
        val id = ++request
        loading = true
        error = null
        viewModelScope.launch {
            try {
                val next = repo.page(nextPage)
                if (id != request) return@launch
                val nextUnread = next.filterNot { it.isRead }.map { it.id }
                val merge = !append && !markExisting && nextPage == 0 && page > 0
                unreadSnapshot = if (append || !markExisting) unreadSnapshot + nextUnread else nextUnread.toSet()
                rows = when {
                    merge -> mergeNewestNotificationPage(rows, next)
                    !append -> next
                    else -> rows + next.filter { row -> rows.none { it.id == row.id } }
                }
                if (!merge || next.size < NOTIFICATION_PAGE_SIZE) {
                    page = nextPage
                    hasMore = next.size == NOTIFICATION_PAGE_SIZE
                }
                loaded = true
                if (!append && markExisting && next.isNotEmpty()) {
                    try {
                        repo.markAllRead(userId, next.first().createdAt)
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        if (id == request) error = UiText(R.string.notifications_mark_failed)
                    } finally {
                        // Even after a failure the badge re-reads the real count.
                        onMarkedRead()
                    }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                if (id == request) error = UiText(R.string.notifications_load_failed)
            } finally {
                if (id == request) {
                    loading = false
                    refreshing = false
                }
            }
        }
    }
}

/**
 * The bell's unread count (web notification-count.ts): read from the server,
 * refreshed by pushes, while the app is open, and after marking read.
 */
class UnreadBadge(private val repo: NotificationRepository, private val userId: String) : ViewModel() {
    var count by mutableIntStateOf(0); private set
    private var job: Job? = null

    fun refresh() {
        if (job?.isActive == true) return
        job = viewModelScope.launch {
            try {
                count = repo.unreadCount(userId)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // Keep the last known count through a flaky network.
            }
        }
    }

    /** Opening the list clears the badge at once; the server count follows. */
    fun markedRead() {
        count = 0
        job?.cancel()
        job = null
        refresh()
    }
}
