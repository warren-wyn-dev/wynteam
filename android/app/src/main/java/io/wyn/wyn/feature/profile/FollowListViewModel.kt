package io.wyn.wyn.feature.profile

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.wyn.wyn.R
import io.wyn.wyn.core.data.FeedRepository
import io.wyn.wyn.core.data.FollowKind
import io.wyn.wyn.core.data.FollowState
import io.wyn.wyn.core.data.Person
import io.wyn.wyn.core.data.ProfileRepository
import io.wyn.wyn.feature.auth.UiText
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

/** web profile-follow-list-route.tsx: following / followers of one profile, with follow buttons. */
class FollowListViewModel(
    private val profiles: ProfileRepository,
    private val feed: FeedRepository,
    val viewerId: String,
    val profileId: String,
    initial: FollowKind,
) : ViewModel() {
    var kind by mutableStateOf(initial); private set
    private val cache = mutableMapOf<FollowKind, List<Person>>()
    var people by mutableStateOf<List<Person>?>(null); private set
    var loading by mutableStateOf(false); private set
    var refreshing by mutableStateOf(false); private set
    var busy by mutableStateOf<String?>(null); private set
    var error by mutableStateOf<UiText?>(null); private set
    var confirmCancel by mutableStateOf<Person?>(null); private set
    private var job: Job? = null

    init {
        load()
    }

    fun select(next: FollowKind) {
        if (next == kind) return
        kind = next
        people = cache[next]
        error = null
        load()
    }

    fun load(pull: Boolean = false) {
        val target = kind
        job?.cancel()
        if (pull) refreshing = true else loading = cache[target] == null
        error = null
        job = viewModelScope.launch {
            try {
                val next = profiles.people(viewerId, profileId, target)
                cache[target] = next
                if (kind == target) people = next
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                if (kind == target) {
                    error = UiText(R.string.follow_list_failed)
                    if (people == null) people = emptyList()
                }
            } finally {
                loading = false
                refreshing = false
            }
        }
    }

    fun dismissConfirm() {
        confirmCancel = null
    }

    fun follow(person: Person, confirmed: Boolean = false) {
        if (person.id == viewerId || busy != null) return
        // The web asks before cancelling a request to a private account everywhere else; keep it here too.
        if (person.requested && person.isPrivate && !confirmed) {
            confirmCancel = person
            return
        }
        confirmCancel = null
        busy = person.id
        error = null
        viewModelScope.launch {
            try {
                val next = feed.toggleFollow(viewerId, person.id, person.following, person.requested, person.isPrivate)
                val ownFollowing = profileId == viewerId && kind == FollowKind.Following
                people = people.orEmpty()
                    .filterNot { ownFollowing && it.id == person.id && next == FollowState.None }
                    .map { if (it.id == person.id) it.copy(following = next == FollowState.Following, requested = next == FollowState.Requested) else it }
                cache[kind] = people.orEmpty()
                load()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.follow_update_failed)
            } finally {
                busy = null
            }
        }
    }
}
