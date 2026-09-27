package io.wyn.wyn.feature.profile

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.viewModelScope
import io.wyn.wyn.R
import io.wyn.wyn.core.data.EngagementSync
import io.wyn.wyn.core.data.FeedRepository
import io.wyn.wyn.core.data.FollowState
import io.wyn.wyn.core.data.PROFILE_POST_PAGE_SIZE
import io.wyn.wyn.core.data.PROFILE_REPOST_PAGE_SIZE
import io.wyn.wyn.core.data.Person
import io.wyn.wyn.core.data.ProfileRepository
import io.wyn.wyn.core.data.ProfileSummary
import io.wyn.wyn.core.data.ProfileTab
import io.wyn.wyn.core.data.QuoteRepository
import io.wyn.wyn.core.data.predictFollowState
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.feature.home.FeedViewModel
import io.wyn.wyn.feature.home.ReportCategories
import io.wyn.wyn.feature.home.Toast
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

/** A question the Profile screen asks before acting, as the web's window.confirm. */
sealed interface ProfileConfirm {
    data object Block : ProfileConfirm
    data object CancelRequest : ProfileConfirm
    data class CancelSuggestionRequest(val person: Person) : ProfileConfirm
}

enum class ProfileSheet { Menu, Report, Accounts }

/**
 * web profile-route.tsx + profile-parity-route.tsx: the header and its
 * actions (follow, mute, block, report, share), suggestions, and the
 * Posts / Reposts / Likes tabs with the same cards as Home.
 */
class ProfileViewModel(
    private val profiles: ProfileRepository,
    feed: FeedRepository,
    userId: String,
    val profileId: String,
    sync: EngagementSync = EngagementSync(),
    quotes: QuoteRepository? = null,
) : FeedViewModel<ProfileTab>(
    feed, userId, sync, quotes, ProfileTab.Posts, "profile:$profileId",
    fetchRows = { tab, page -> profiles.rows(profileId, tab, page) },
    pageSize = { if (it == ProfileTab.Reposts) PROFILE_REPOST_PAGE_SIZE else PROFILE_POST_PAGE_SIZE },
) {
    private val feedRepo = feed
    val own: Boolean get() = profileId == userId

    var summary by mutableStateOf<ProfileSummary?>(null); private set
    var summaryLoading by mutableStateOf(true); private set
    var summaryFailed by mutableStateOf(false); private set
    var likesAllowed by mutableStateOf(true); private set
    var action by mutableStateOf(false); private set
    var actionError by mutableStateOf<UiText?>(null); private set
    var confirm by mutableStateOf<ProfileConfirm?>(null); private set
    var profileSheet by mutableStateOf<ProfileSheet?>(null); private set
    var reportReason by mutableStateOf(ReportCategories.first()); private set
    var reportText by mutableStateOf(""); private set
    var sheetError by mutableStateOf<UiText?>(null); private set

    var suggestions by mutableStateOf<List<Person>>(emptyList()); private set
    var suggestionBusy by mutableStateOf<Set<String>>(emptySet()); private set
    var suggestionError by mutableStateOf<UiText?>(null); private set

    init {
        reloadSummary()
        if (!own) {
            viewModelScope.launch { likesAllowed = runCatching { profiles.canViewLikes(profileId) }.getOrDefault(true) }
            viewModelScope.launch { suggestions = runCatching { profiles.suggestions(userId, profileId) }.getOrDefault(emptyList()) }
        }
    }

    fun reloadSummary() {
        viewModelScope.launch {
            try {
                val next = profiles.summary(userId, profileId)
                summary = next
                summaryFailed = next == null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                if (summary == null) summaryFailed = true
            } finally {
                summaryLoading = false
            }
        }
    }

    /** Pull to refresh: the header and the open tab. */
    fun refreshAll() {
        reloadSummary()
        refresh()
    }

    // ---- Follow -------------------------------------------------------------------

    fun follow(confirmed: Boolean = false) {
        val current = summary ?: return
        if (own || action) return
        val profile = current.profile
        if (current.requested && profile.isPrivate && !confirmed) {
            confirm = ProfileConfirm.CancelRequest
            return
        }
        confirm = null
        val next = predictFollowState(current.following, current.requested, profile.isPrivate)
        action = true
        actionError = null
        summary = current.copy(
            following = next == FollowState.Following,
            requested = next == FollowState.Requested,
            followerCount = (current.followerCount + (if (next == FollowState.Following) 1 else 0) - (if (current.following) 1 else 0)).coerceAtLeast(0),
        )
        viewModelScope.launch {
            try {
                val result = feedRepo.toggleFollow(userId, profile.id, current.following, current.requested, profile.isPrivate)
                summary = summary?.copy(following = result == FollowState.Following, requested = result == FollowState.Requested)
                // The server's counts, including anything else that changed.
                profiles.summary(userId, profileId)?.let { summary = it }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                summary = summary?.copy(following = current.following, requested = current.requested, followerCount = current.followerCount)
                actionError = UiText(R.string.profile_follow_failed)
                toast = Toast(UiText(R.string.follow_failed))
            } finally {
                action = false
            }
        }
    }

    // ---- Menu: mute, block, report -------------------------------------------------

    fun openProfileSheet(value: ProfileSheet?) {
        sheetError = null
        profileSheet = value
        if (value == ProfileSheet.Report) {
            reportReason = ReportCategories.first()
            reportText = ""
        }
    }

    fun dismissConfirm() {
        confirm = null
    }

    private fun afterRelationshipChange() {
        profileSheet = null
        reloadSummary()
        refresh()
    }

    fun toggleMute() {
        val current = summary ?: return
        if (own || action) return
        action = true
        sheetError = null
        viewModelScope.launch {
            try {
                profiles.setMuted(userId, profileId, !current.muted)
                summary = summary?.copy(muted = !current.muted)
                afterRelationshipChange()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                sheetError = UiText(R.string.profile_mute_failed)
            } finally {
                action = false
            }
        }
    }

    fun block(confirmed: Boolean = false) {
        val current = summary ?: return
        if (own || action) return
        if (!current.blocked && !confirmed) {
            confirm = ProfileConfirm.Block
            return
        }
        confirm = null
        action = true
        sheetError = null
        viewModelScope.launch {
            try {
                profiles.setBlocked(profileId, !current.blocked)
                summary = summary?.copy(blocked = !current.blocked, following = false, requested = false)
                afterRelationshipChange()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                val message = UiText(if (current.blocked) R.string.profile_unblock_failed else R.string.profile_block_failed)
                if (profileSheet != null) sheetError = message else actionError = message
            } finally {
                action = false
            }
        }
    }

    fun chooseReportReason(value: String) {
        reportReason = value
        sheetError = null
    }

    fun updateReportText(value: String) {
        reportText = value.take(1000)
        sheetError = null
    }

    fun submitProfileReport() {
        if (own || action) return
        if (reportReason == "other" && reportText.isBlank()) {
            sheetError = UiText(R.string.report_detail_required)
            return
        }
        action = true
        viewModelScope.launch {
            try {
                profiles.report(profileId, reportReason, if (reportReason == "other") reportText.trim() else null)
                profileSheet = null
                toast = Toast(UiText(R.string.report_sent))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                sheetError = UiText(R.string.report_failed)
            } finally {
                action = false
            }
        }
    }

    // ---- Suggestions (web ProfileRecommendations) ------------------------------------

    fun dismissSuggestion(person: Person) {
        val before = suggestions
        suggestions = before.filterNot { it.id == person.id }
        viewModelScope.launch {
            try {
                profiles.dismissSuggestion(userId, person.id)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                suggestions = before
            }
        }
    }

    fun followSuggestion(person: Person, confirmed: Boolean = false) {
        if (person.id in suggestionBusy) return
        if (person.requested && person.isPrivate && !confirmed) {
            confirm = ProfileConfirm.CancelSuggestionRequest(person)
            return
        }
        confirm = null
        suggestionBusy = suggestionBusy + person.id
        suggestionError = null
        viewModelScope.launch {
            try {
                val state = feedRepo.toggleFollow(userId, person.id, person.following, person.requested, person.isPrivate)
                suggestions = suggestions.map {
                    if (it.id == person.id) it.copy(following = state == FollowState.Following, requested = state == FollowState.Requested) else it
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                suggestionError = UiText(R.string.profile_follow_failed)
            } finally {
                suggestionBusy = suggestionBusy - person.id
            }
        }
    }

    /** The web's share link for a profile. */
    fun profileUrl(): String? = summary?.profile?.username?.let { "https://wynos.online/@$it" }
}
