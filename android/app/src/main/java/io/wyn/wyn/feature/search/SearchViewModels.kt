package io.wyn.wyn.feature.search

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.wyn.wyn.R
import io.wyn.wyn.core.data.Club
import io.wyn.wyn.core.data.DiscoveryRepository
import io.wyn.wyn.core.data.EngagementSync
import io.wyn.wyn.core.data.FeedRepository
import io.wyn.wyn.core.data.FeedRow
import io.wyn.wyn.core.data.FollowState
import io.wyn.wyn.core.data.Person
import io.wyn.wyn.core.data.QuoteRepository
import io.wyn.wyn.core.data.RankedHashtag
import io.wyn.wyn.core.data.SAVED_PAGE
import io.wyn.wyn.core.data.SEARCH_CLUBS_PAGE
import io.wyn.wyn.core.data.SEARCH_PEOPLE_PAGE
import io.wyn.wyn.core.data.SEARCH_POSTS_PAGE
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.feature.home.FeedViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

enum class SearchTab { All, Users, Posts, Clubs }

/** web SEARCH_DEBOUNCE_MS: results follow typing after this pause. */
const val SEARCH_DEBOUNCE_MS = 400L

/** web: a query shorter than 2 characters is not searched yet. */
fun searchable(query: String): Boolean = query.trim().length >= 2

/** A paged list (web UserResults / ClubResults). */
data class Paged<T>(val rows: List<T> = emptyList(), val page: Int = 0, val hasMore: Boolean = false)

/**
 * web SearchInner: discovery (trending hashtags + who to follow) until a
 * query is submitted, then All / User / Posts / Club results.
 */
class SearchViewModel(
    private val repo: DiscoveryRepository,
    private val feed: FeedRepository,
    val userId: String,
) : ViewModel() {
    var draft by mutableStateOf(""); private set
    /** The query being shown; empty shows discovery. */
    var query by mutableStateOf(""); private set
    var tab by mutableStateOf(SearchTab.All); private set

    // Discovery
    var hashtags by mutableStateOf<List<RankedHashtag>>(emptyList()); private set
    var suggested by mutableStateOf<List<Person>>(emptyList()); private set
    var discoveryLoading by mutableStateOf(true); private set

    // All
    var allUsers by mutableStateOf<List<Person>>(emptyList()); private set
    var allPosts by mutableStateOf<List<FeedRow>>(emptyList()); private set
    var allClubs by mutableStateOf<List<Club>>(emptyList()); private set

    // Users / Clubs tabs
    var users by mutableStateOf(Paged<Person>()); private set
    var clubs by mutableStateOf(Paged<Club>()); private set

    var loading by mutableStateOf(false); private set
    var error by mutableStateOf<UiText?>(null); private set
    var followBusy by mutableStateOf<String?>(null); private set
    var followError by mutableStateOf<UiText?>(null); private set
    var confirmCancel by mutableStateOf<Person?>(null); private set

    private var debounce: Job? = null
    private var job: Job? = null

    init {
        loadDiscovery()
    }

    private fun loadDiscovery() {
        viewModelScope.launch {
            try {
                hashtags = repo.trending(6)
                suggested = repo.suggested(userId, 10)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // web: discovery quietly shows its empty states.
            } finally {
                discoveryLoading = false
            }
        }
    }

    fun updateDraft(value: String) {
        draft = value
        debounce?.cancel()
        val trimmed = value.trim()
        if (trimmed == query) return
        if (trimmed.isNotEmpty() && trimmed.length < 2) return
        debounce = viewModelScope.launch {
            delay(SEARCH_DEBOUNCE_MS)
            show(trimmed, tab)
        }
    }

    /** Enter or the search icon: no waiting for the pause. */
    fun submitNow() {
        val trimmed = draft.trim()
        if (trimmed.isNotEmpty() && trimmed.length < 2) return
        debounce?.cancel()
        show(trimmed, tab)
    }

    fun clear() {
        debounce?.cancel()
        draft = ""
        show("", tab)
    }

    fun select(next: SearchTab) {
        if (next == tab) return
        show(query, next)
    }

    private fun show(nextQuery: String, nextTab: SearchTab) {
        val changed = nextQuery != query || nextTab != tab
        query = nextQuery
        tab = nextTab
        if (changed) load()
    }

    /** Loads what the current tab shows; posts come from [SearchPostsViewModel]. */
    fun load() {
        job?.cancel()
        error = null
        val q = query
        if (!searchable(q)) {
            loading = false
            return
        }
        val target = tab
        loading = true
        job = viewModelScope.launch {
            try {
                when (target) {
                    SearchTab.All -> coroutineScope {
                        val people = async { repo.searchPeople(userId, q, 0) }
                        val posts = async { repo.searchPosts(q, 0) }
                        val found = async { repo.searchClubs(q, 0) }
                        allUsers = people.await()
                        allPosts = posts.await()
                        allClubs = found.await()
                    }
                    SearchTab.Users -> users = repo.searchPeople(userId, q, 0).let { Paged(it, 0, it.size == SEARCH_PEOPLE_PAGE) }
                    SearchTab.Clubs -> clubs = repo.searchClubs(q, 0).let { Paged(it, 0, it.size == SEARCH_CLUBS_PAGE) }
                    SearchTab.Posts -> Unit
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(
                    when (target) {
                        SearchTab.Users -> R.string.search_people_failed
                        SearchTab.Clubs -> R.string.search_clubs_failed
                        else -> R.string.search_failed
                    },
                )
            } finally {
                if (tab == target && query == q) loading = false
            }
        }
    }

    fun moreUsers() {
        val q = query
        if (loading || !users.hasMore) return
        loading = true
        viewModelScope.launch {
            try {
                val next = repo.searchPeople(userId, q, users.page + 1)
                if (q == query) users = Paged(users.rows + next, users.page + 1, next.size == SEARCH_PEOPLE_PAGE)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.search_people_failed)
            } finally {
                loading = false
            }
        }
    }

    fun moreClubs() {
        val q = query
        if (loading || !clubs.hasMore) return
        loading = true
        viewModelScope.launch {
            try {
                val next = repo.searchClubs(q, clubs.page + 1)
                if (q == query) clubs = Paged(clubs.rows + next, clubs.page + 1, next.size == SEARCH_CLUBS_PAGE)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.search_clubs_failed)
            } finally {
                loading = false
            }
        }
    }

    fun dismissConfirm() { confirmCancel = null }

    /** web follow() in UserResults and Discovery; asks before cancelling a private request. */
    fun follow(person: Person, confirmed: Boolean = false) {
        if (person.id == userId || followBusy != null) return
        if (person.requested && person.isPrivate && !confirmed) {
            confirmCancel = person
            return
        }
        confirmCancel = null
        followBusy = person.id
        followError = null
        viewModelScope.launch {
            try {
                val state = feed.toggleFollow(userId, person.id, person.following, person.requested, person.isPrivate)
                fun List<Person>.patched() = map {
                    if (it.id == person.id) it.copy(following = state == FollowState.Following, requested = state == FollowState.Requested) else it
                }
                suggested = suggested.patched()
                users = users.copy(rows = users.rows.patched())
                allUsers = allUsers.patched()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                followError = UiText(R.string.follow_update_failed)
            } finally {
                followBusy = null
            }
        }
    }
}

/** Posts results with Home's cards and actions, one cached page set per query (web DropResults). */
class SearchPostsViewModel(
    repo: DiscoveryRepository,
    feed: FeedRepository,
    userId: String,
    sync: EngagementSync,
    quotes: QuoteRepository?,
) : FeedViewModel<String>(
    feed, userId, sync, quotes, "", "search",
    fetchRows = { query, page -> if (searchable(query)) repo.searchPosts(query, page) else emptyList() },
    pageSize = { SEARCH_POSTS_PAGE },
)

/** web TrendingInner: the top 100 hashtags. */
class TrendingViewModel(private val repo: DiscoveryRepository) : ViewModel() {
    var hashtags by mutableStateOf<List<RankedHashtag>>(emptyList()); private set
    var loading by mutableStateOf(true); private set
    var error by mutableStateOf<UiText?>(null); private set

    init {
        load()
    }

    fun load() {
        loading = true
        error = null
        viewModelScope.launch {
            try {
                hashtags = repo.trending(100)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.trending_failed)
            } finally {
                loading = false
            }
        }
    }
}

/** web BookmarksInner: saved Drops and Quotes with Home's cards. */
class BookmarksViewModel(
    repo: DiscoveryRepository,
    feed: FeedRepository,
    userId: String,
    sync: EngagementSync,
    quotes: QuoteRepository?,
) : FeedViewModel<Unit>(
    feed, userId, sync, quotes, Unit, "bookmarks",
    fetchRows = { _, page -> repo.saved(userId, page) },
    pageSize = { SAVED_PAGE },
)
