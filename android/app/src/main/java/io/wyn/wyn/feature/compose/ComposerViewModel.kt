package io.wyn.wyn.feature.compose

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.github.jan.supabase.exceptions.RestException
import io.wyn.wyn.R
import io.wyn.wyn.core.data.AspectChoice
import io.wyn.wyn.core.data.Audience
import io.wyn.wyn.core.data.ComposerRepository
import io.wyn.wyn.core.data.DraftInput
import io.wyn.wyn.core.data.FeedRepository
import io.wyn.wyn.core.data.HomeIdentity
import io.wyn.wyn.core.data.MAX_CAPTION
import io.wyn.wyn.core.data.MAX_POLL_OPTIONS
import io.wyn.wyn.core.data.MAX_POLL_OPTION_LENGTH
import io.wyn.wyn.core.data.MAX_POST_IMAGES
import io.wyn.wyn.core.data.POLL_DURATION_DAYS
import io.wyn.wyn.core.data.PickedImage
import io.wyn.wyn.core.data.PublicationStateUnknownException
import io.wyn.wyn.feature.auth.UiText
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.IOException
import java.util.UUID
import kotlin.coroutines.cancellation.CancellationException

enum class ComposeMode { Image, Poll }
enum class AutosaveStatus { Idle, Saving, Saved, Error }

/** Where the composer goes after it closes. */
enum class ComposerExit { Closed, Published, Drafts }

/**
 * web beta4-composer.tsx: text, up to 9 photos with an aspect choice, or a
 * poll; audience; autosaved drafts; and publishing that can never create a
 * duplicate post from a retry.
 */
class ComposerViewModel(
    private val repo: ComposerRepository,
    feed: FeedRepository,
    val userId: String,
    draftId: String? = null,
    private val newOperationId: () -> String = { UUID.randomUUID().toString() },
) : ViewModel() {
    var identity by mutableStateOf<HomeIdentity?>(null); private set
    var caption by mutableStateOf(""); private set
    var images by mutableStateOf<List<PickedImage>>(emptyList()); private set
    var existingImageUrl by mutableStateOf<String?>(null); private set
    var mode by mutableStateOf(ComposeMode.Image); private set
    var aspect by mutableStateOf(AspectChoice.Portrait); private set
    var pollOptions by mutableStateOf(listOf("", "")); private set
    var audience by mutableStateOf(Audience.Everyone); private set
    var audienceOpen by mutableStateOf(false); private set
    var busy by mutableStateOf(false); private set
    var error by mutableStateOf<UiText?>(null); private set
    var serverError by mutableStateOf<String?>(null); private set
    var closePrompt by mutableStateOf(false); private set
    var uploadProgress by mutableStateOf<Pair<Int, Int>?>(null); private set
    var draftRecordId by mutableStateOf<String?>(null); private set
    var savingDraft by mutableStateOf(false); private set
    var draftError by mutableStateOf<UiText?>(null); private set
    var autosaveStatus by mutableStateOf(AutosaveStatus.Idle); private set
    var exit by mutableStateOf<ComposerExit?>(null); private set

    private val draftLock = Mutex()
    private var autosaveJob: Job? = null
    private var operationId: String? = null
    private var fingerprint: String? = null
    private var pendingDrafts = false

    init {
        viewModelScope.launch { identity = runCatching { feed.fetchIdentity(userId) }.getOrNull() }
        if (draftId != null) {
            viewModelScope.launch {
                val row = runCatching { repo.fetchDraft(draftId) }.getOrNull() ?: return@launch
                draftRecordId = row.id
                caption = row.caption.orEmpty()
                existingImageUrl = row.imageUrl
                if (!row.pollOptions.isNullOrEmpty()) {
                    mode = ComposeMode.Poll
                    pollOptions = row.pollOptions
                }
                // Loading a saved draft is not an edit: no autosave.
            }
        }
    }

    val pollValid: Boolean
        get() = caption.trim().isNotEmpty() && pollOptions.size >= 2 &&
            pollOptions.all { it.trim().isNotEmpty() && it.trim().length <= MAX_POLL_OPTION_LENGTH } &&
            pollOptions.map { it.trim().lowercase() }.toSet().size == pollOptions.size

    val canPublish: Boolean
        get() = !busy && if (mode == ComposeMode.Poll) pollValid else caption.trim().isNotEmpty() || images.isNotEmpty() || existingImageUrl != null

    val hasContent: Boolean
        get() = caption.trim().isNotEmpty() ||
            if (mode == ComposeMode.Poll) pollOptions.any { it.trim().isNotEmpty() } else images.isNotEmpty() || existingImageUrl != null

    // ---- Editing (each one schedules an autosave, like the web's 800ms debounce) -----------

    private fun edited() {
        error = null
        serverError = null
        autosaveJob?.cancel()
        if (!hasContent || busy) return
        autosaveJob = viewModelScope.launch {
            delay(800)
            autosaveStatus = AutosaveStatus.Saving
            autosaveStatus = try {
                persistDraft()
                AutosaveStatus.Saved
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                AutosaveStatus.Error
            }
        }
    }

    fun updateCaption(value: String) {
        caption = value.take(MAX_CAPTION)
        edited()
    }

    fun addImages(picked: List<PickedImage>) {
        val combined = images + picked
        images = combined.take(MAX_POST_IMAGES)
        edited()
        if (combined.size > MAX_POST_IMAGES) error = UiText(R.string.max_images, listOf(MAX_POST_IMAGES))
    }

    fun rejectPhoto(message: Int) {
        error = UiText(message)
    }

    fun removeImage(index: Int) {
        images = images.filterIndexed { i, _ -> i != index }
        edited()
    }

    fun removeExistingImage() {
        existingImageUrl = null
        edited()
    }

    fun chooseAspect(value: AspectChoice) {
        aspect = value
    }

    fun toggleMode() {
        mode = if (mode == ComposeMode.Poll) ComposeMode.Image else ComposeMode.Poll
        edited()
    }

    fun updatePollOption(index: Int, value: String) {
        pollOptions = pollOptions.mapIndexed { i, v -> if (i == index) value.take(MAX_POLL_OPTION_LENGTH) else v }
        edited()
    }

    fun addPollOption() {
        if (pollOptions.size >= MAX_POLL_OPTIONS) return
        pollOptions = pollOptions + ""
        edited()
    }

    fun removePollOption(index: Int) {
        if (pollOptions.size <= 2) return
        pollOptions = pollOptions.filterIndexed { i, _ -> i != index }
        edited()
    }

    fun openAudience(open: Boolean) {
        if (!busy) audienceOpen = open
    }

    fun chooseAudience(value: Audience) {
        audience = value
        audienceOpen = false
    }

    // ---- Drafts ------------------------------------------------------------------

    /** One save at a time, so there is never a duplicate first draft or a stale overwrite. */
    private suspend fun persistDraft(): String = draftLock.withLock {
        val id = repo.saveDraft(
            userId,
            DraftInput(
                draftId = draftRecordId,
                image = if (mode == ComposeMode.Image) images.firstOrNull() else null,
                existingImageUrl = if (mode == ComposeMode.Image) existingImageUrl else null,
                caption = caption,
                pollOptions = if (mode == ComposeMode.Poll) pollOptions else null,
                pollDurationDays = if (mode == ComposeMode.Poll) POLL_DURATION_DAYS else null,
            ),
        )
        draftRecordId = id
        id
    }

    fun requestClose(toDrafts: Boolean = false) {
        if (busy) return
        pendingDrafts = toDrafts
        if (!hasContent) {
            finishClose()
            return
        }
        draftError = null
        closePrompt = true
    }

    fun dismissClosePrompt() {
        if (!savingDraft) closePrompt = false
    }

    /** "ทิ้ง": close without saving again (an earlier autosave stays in drafts, as on the web). */
    fun discard() {
        finishClose()
    }

    fun saveDraftAndClose() {
        if (savingDraft) return
        savingDraft = true
        draftError = null
        autosaveJob?.cancel()
        viewModelScope.launch {
            try {
                persistDraft()
                finishClose()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                draftError = UiText(R.string.draft_save_failed)
            } finally {
                savingDraft = false
            }
        }
    }

    private fun finishClose() {
        autosaveJob?.cancel()
        closePrompt = false
        exit = if (pendingDrafts) ComposerExit.Drafts else ComposerExit.Closed
    }

    // ---- Publish -----------------------------------------------------------------

    private fun currentFingerprint(): String = listOf(
        mode, caption, audience, aspect, images.map { it.bytes.contentHashCode() to it.bytes.size }, existingImageUrl, pollOptions,
    ).toString()

    fun publish() {
        if (!canPublish) return
        val print = currentFingerprint()
        // A timed-out publication may already exist: its id is reused only for identical content.
        if (mode == ComposeMode.Image && operationId != null && fingerprint != print) {
            error = UiText(R.string.publish_state_unclear_edit)
            return
        }
        if (mode == ComposeMode.Image && operationId == null) {
            operationId = newOperationId()
            fingerprint = print
        }
        autosaveJob?.cancel()
        busy = true
        error = null
        serverError = null
        uploadProgress = null
        viewModelScope.launch {
            try {
                // Let a running draft save finish before publishing and deleting it.
                draftLock.withLock { }
                if (mode == ComposeMode.Poll) {
                    repo.publishPoll(caption, pollOptions, audience)
                } else {
                    val files = images.ifEmpty { listOfNotNull(existingImageUrl?.let { repo.loadDraftImage(userId, it) }) }
                    repo.publishDrop(userId, caption, files, operationId!!, audience, aspect) { done, total ->
                        uploadProgress = if (total > 0) done to total else null
                    }
                }
                operationId = null
                fingerprint = null
                draftRecordId?.let { id -> viewModelScope.launch { runCatching { repo.deleteDraft(id) } } }
                exit = ComposerExit.Published
            } catch (e: CancellationException) {
                throw e
            } catch (e: PublicationStateUnknownException) {
                // Keep the operation id: retrying the same content reconciles instead of duplicating.
                error = UiText(R.string.publish_state_unclear)
            } catch (e: Exception) {
                operationId = null
                fingerprint = null
                when {
                    mode == ComposeMode.Poll && e is IOException -> error = UiText(R.string.poll_connection_lost)
                    e is IOException -> error = UiText(R.string.publish_offline)
                    e is RestException -> serverError = e.description?.takeIf { it.isNotBlank() } ?: e.error
                    else -> error = UiText(R.string.publish_failed)
                }
            } finally {
                busy = false
                uploadProgress = null
            }
        }
    }
}
