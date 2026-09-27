package io.wyn.wyn.feature.quote

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import io.wyn.wyn.R
import io.wyn.wyn.core.data.FeedRow
import io.wyn.wyn.core.data.QuoteEngagement
import io.wyn.wyn.core.data.QuoteRepository
import io.wyn.wyn.feature.auth.UiText
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

/** web quote-feed-card.tsx report reasons (a shorter list than a Drop's). */
val QuoteReportReasons = listOf("spam", "scam", "harassment", "other")

sealed interface QuoteSheet {
    val row: FeedRow
    data class Menu(override val row: FeedRow) : QuoteSheet
    data class ConfirmDelete(override val row: FeedRow) : QuoteSheet
    data class Report(override val row: FeedRow) : QuoteSheet
    data class Repost(override val row: FeedRow) : QuoteSheet
}

/**
 * Everything a Quote card can do (web quote-feed-card.tsx + quote-redrop-composer.tsx).
 * Every action targets the Quote's own redrops.id, never the quoted Drop,
 * except "quote the original", which creates a new Quote of that Drop.
 */
class QuoteController(
    private val scope: CoroutineScope,
    private val repo: QuoteRepository,
    private val userId: String,
    private val onToast: (UiText) -> Unit,
    private val onChanged: () -> Unit = {},
) {
    var engagement by mutableStateOf<Map<String, QuoteEngagement>>(emptyMap()); private set
    var failed by mutableStateOf<Set<String>>(emptySet()); private set
    var sheet by mutableStateOf<QuoteSheet?>(null); private set
    var busy by mutableStateOf(false); private set
    var error by mutableStateOf<UiText?>(null); private set
    var reportReason by mutableStateOf(QuoteReportReasons.first()); private set
    var reportDetail by mutableStateOf(""); private set

    /** The Drop being quoted in the composer, and the text so far. */
    var quoting by mutableStateOf<FeedRow?>(null); private set
    var quoteText by mutableStateOf(""); private set
    var quoteDiscardPrompt by mutableStateOf(false); private set

    private val inFlight = mutableSetOf<String>()

    /** Loads counts for these Quotes; a failure leaves a retry, never the original Drop's counts. */
    suspend fun load(rows: List<FeedRow>) {
        val ids = rows.filter { it.isQuote }.mapNotNull { it.redropId }.distinct()
        if (ids.isEmpty()) return
        try {
            val fresh = repo.engagement(ids)
            engagement = engagement + fresh
            failed = (failed - ids.toSet()) + ids.filterNot { it in fresh }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            failed = failed + ids
        }
    }

    /** Keeps the comment count in step after adding or removing a comment here. */
    fun adjustComments(quoteId: String, delta: Int) = update(quoteId) { it.copy(commentCount = (it.commentCount + delta).coerceAtLeast(0)) }

    fun retry(row: FeedRow) {
        scope.launch { load(listOf(row)) }
    }

    private fun update(id: String, transform: (QuoteEngagement) -> QuoteEngagement) {
        val current = engagement[id] ?: return
        engagement = engagement + (id to transform(current))
    }

    private fun act(row: FeedRow, kind: String, change: (QuoteEngagement) -> QuoteEngagement, call: suspend (QuoteEngagement) -> Unit, failure: Int) {
        val id = row.redropId ?: return
        val before = engagement[id] ?: return
        if (!inFlight.add("$kind:$id")) return
        update(id, change)
        scope.launch {
            try {
                call(before)
                onChanged()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                engagement = engagement + (id to before)
                load(listOf(row))
                onToast(UiText(failure))
            } finally {
                inFlight.remove("$kind:$id")
            }
        }
    }

    fun toggleLike(row: FeedRow) = act(
        row, "like",
        { it.copy(liked = !it.liked, likeCount = (it.likeCount + if (it.liked) -1 else 1).coerceAtLeast(0)) },
        { before -> repo.setLiked(userId, before.quoteId, !before.liked) },
        R.string.quote_like_failed,
    )

    fun toggleSave(row: FeedRow) = act(
        row, "save",
        { it.copy(saved = !it.saved) },
        { before ->
            repo.setSaved(userId, before.quoteId, !before.saved)
            onToast(UiText(if (before.saved) R.string.post_unsaved else R.string.post_saved))
        },
        R.string.quote_save_failed,
    )

    fun toggleRepost(row: FeedRow) {
        act(
            row, "repost",
            { it.copy(reposted = !it.reposted, repostCount = (it.repostCount + if (it.reposted) -1 else 1).coerceAtLeast(0)) },
            { before ->
                repo.setReposted(userId, before.quoteId, !before.reposted)
                sheet = null
            },
            R.string.quote_repost_failed,
        )
    }

    fun open(value: QuoteSheet?) {
        error = null
        sheet = value
        if (value is QuoteSheet.Report) {
            reportReason = QuoteReportReasons.first()
            reportDetail = ""
        }
    }

    fun chooseReason(value: String) {
        reportReason = value
        error = null
    }

    fun updateReportDetail(value: String) {
        reportDetail = value.take(1000)
        error = null
    }

    fun submitReport() {
        val row = sheet?.row ?: return
        val id = row.redropId ?: return
        if (busy || row.redropperId == userId) return
        if (reportReason == "other" && reportDetail.isBlank()) {
            error = UiText(R.string.report_detail_required)
            return
        }
        busy = true
        scope.launch {
            try {
                repo.report(id, reportReason, if (reportReason == "other") reportDetail.trim() else null)
                sheet = null
                onToast(UiText(R.string.report_sent))
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.report_failed)
            } finally {
                busy = false
            }
        }
    }

    /** Only the Quote's author can delete it; the quoted Drop is untouched. */
    fun delete(onDeleted: (FeedRow) -> Unit) {
        val row = sheet?.row ?: return
        val id = row.redropId ?: return
        if (busy || row.redropperId != userId) return
        busy = true
        scope.launch {
            try {
                repo.deleteQuote(userId, id)
                sheet = null
                onDeleted(row)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.quote_delete_failed)
            } finally {
                busy = false
            }
        }
    }

    // ---- Quote composer ------------------------------------------------------------

    /** Quoting is only for public posts, as on the web. */
    fun startQuote(row: FeedRow) {
        if (!row.canRedrop) return
        sheet = null
        quoting = row
        quoteText = ""
        error = null
        quoteDiscardPrompt = false
    }

    fun updateQuoteText(value: String) {
        quoteText = value.take(500)
        error = null
    }

    fun requestCloseQuote() {
        if (busy) return
        if (quoteText.isBlank()) quoting = null else quoteDiscardPrompt = true
    }

    fun keepQuoting() {
        quoteDiscardPrompt = false
    }

    fun discardQuote() {
        quoteDiscardPrompt = false
        quoting = null
        quoteText = ""
    }

    fun submitQuote(onPublished: () -> Unit) {
        val row = quoting ?: return
        if (busy || quoteText.isBlank()) return
        busy = true
        error = null
        scope.launch {
            try {
                repo.quoteDrop(userId, row.id, quoteText)
                quoting = null
                quoteText = ""
                onToast(UiText(R.string.quote_published))
                onPublished()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.quote_failed)
            } finally {
                busy = false
            }
        }
    }
}
