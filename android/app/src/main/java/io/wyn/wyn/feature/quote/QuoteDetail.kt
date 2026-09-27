package io.wyn.wyn.feature.quote

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.wyn.wyn.R
import io.wyn.wyn.core.data.FeedRow
import io.wyn.wyn.core.data.QUOTE_COMMENT_PAGE
import io.wyn.wyn.core.data.QuoteComment
import io.wyn.wyn.core.data.QuoteRepository
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.home.FeedText
import io.wyn.wyn.feature.home.SnackBar
import io.wyn.wyn.feature.home.rememberEnglish
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

/** web quote-detail-route.tsx: the Quote itself and its own comments (never the quoted Drop's). */
class QuoteDetailViewModel(private val repo: QuoteRepository, val userId: String, val quoteId: String) : ViewModel() {
    var row by mutableStateOf<FeedRow?>(null); private set
    var images by mutableStateOf<List<String>>(emptyList()); private set
    var loading by mutableStateOf(true); private set
    var notFound by mutableStateOf(false); private set
    var comments by mutableStateOf<List<QuoteComment>>(emptyList()); private set
    var hasMore by mutableStateOf(false); private set
    var commentsLoading by mutableStateOf(true); private set
    var sending by mutableStateOf(false); private set
    var draft by mutableStateOf(""); private set
    var error by mutableStateOf<UiText?>(null); private set
    var toast by mutableStateOf<UiText?>(null); private set
    var deleted by mutableStateOf(false); private set
    private var page = 0

    val quote = QuoteController(viewModelScope, repo, userId, onToast = { toast = it })

    init {
        viewModelScope.launch {
            try {
                val found = repo.fetchQuote(quoteId)
                row = found
                notFound = found == null
                if (found != null) {
                    quote.load(listOf(found))
                    images = runCatching { repo.fetchImages(found.id, found.imageUrl) }.getOrDefault(listOfNotNull(found.imageUrl))
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.post_load_failed)
            } finally {
                loading = false
            }
        }
        viewModelScope.launch { reloadComments() }
    }

    private suspend fun reloadComments() {
        commentsLoading = true
        try {
            val first = repo.comments(quoteId, 0)
            comments = first
            page = 0
            hasMore = first.size == QUOTE_COMMENT_PAGE
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            error = UiText(R.string.quote_comments_failed)
        } finally {
            commentsLoading = false
        }
    }

    fun loadMore() {
        if (commentsLoading || !hasMore) return
        commentsLoading = true
        viewModelScope.launch {
            try {
                val next = repo.comments(quoteId, page + 1)
                comments = comments + next.filterNot { n -> comments.any { it.id == n.id } }
                page += 1
                hasMore = next.size == QUOTE_COMMENT_PAGE
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.quote_comments_more_failed)
            } finally {
                commentsLoading = false
            }
        }
    }

    fun updateDraft(value: String) {
        draft = value.take(500)
    }

    private fun adjustCount(delta: Int) = quote.adjustComments(quoteId, delta)

    fun send() {
        if (draft.isBlank() || sending) return
        sending = true
        error = null
        viewModelScope.launch {
            try {
                repo.addComment(userId, quoteId, draft)
                draft = ""
                reloadComments()
                adjustCount(1)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.comment_failed)
            } finally {
                sending = false
            }
        }
    }

    fun remove(comment: QuoteComment) {
        if (comment.authorId != userId || sending) return
        sending = true
        viewModelScope.launch {
            try {
                repo.removeComment(userId, comment.id)
                comments = comments.filterNot { it.id == comment.id }
                adjustCount(-1)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.quote_comment_delete_failed)
            } finally {
                sending = false
            }
        }
    }

    fun markDeleted() {
        deleted = true
    }

    fun dismissToast() {
        toast = null
    }
}

@Composable
fun QuoteDetailScreen(vm: QuoteDetailViewModel, onBack: () -> Unit, onOpenDrop: (String) -> Unit, myAvatar: String?, myName: String) {
    val c = Wyn.colors
    val context = LocalContext.current
    val english = rememberEnglish()
    LaunchedEffect(vm.deleted) { if (vm.deleted) onBack() }
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding().imePadding()) {
        Box(Modifier.fillMaxWidth().height(56.dp)) {
            val back = stringResource(R.string.back)
            Box(Modifier.size(48.dp, 56.dp).clickable(role = Role.Button, onClick = onBack).semantics { contentDescription = back }, contentAlignment = Alignment.Center) {
                Icon(WynIcons.Back, contentDescription = null, tint = c.text, modifier = Modifier.size(22.dp))
            }
            Text(stringResource(R.string.post_title), color = c.text, fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.align(Alignment.Center))
        }
        HorizontalDivider(color = c.border, thickness = 1.dp)
        val row = vm.row
        when {
            vm.loading -> Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) { Text(stringResource(R.string.loading_more), color = c.textSecondary) }
            row == null -> Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                Text(vm.error.text() ?: stringResource(R.string.post_not_found), color = c.textSecondary)
            }
            else -> {
                LazyColumn(Modifier.weight(1f)) {
                    item(key = "quote") {
                        QuoteCard(
                            row, vm.quote.engagement[vm.quoteId], vm.quoteId in vm.quote.failed, vm.images,
                            onRetry = { vm.quote.retry(row) },
                            onLike = { vm.quote.toggleLike(row) },
                            onComment = {},
                            onRepost = { vm.quote.open(QuoteSheet.Repost(row)) },
                            onShare = {
                                val send = Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_TEXT, "https://wynos.online/quote/${vm.quoteId}") }
                                context.startActivity(Intent.createChooser(send, null))
                            },
                            onSave = { vm.quote.toggleSave(row) },
                            onMore = { vm.quote.open(QuoteSheet.Menu(row)) },
                            onOpenOriginal = { onOpenDrop(row.id) },
                            onOpenAuthor = {},
                        )
                        HorizontalDivider(color = c.border, thickness = 1.dp)
                        Text(stringResource(R.string.quote_comments_title), color = c.text, fontSize = 15.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 16.dp, top = 14.dp, bottom = 8.dp))
                        ErrorText(vm.error.text())
                    }
                    if (vm.comments.isEmpty() && !vm.commentsLoading) {
                        item(key = "empty") {
                            Text(stringResource(R.string.quote_comments_empty), color = c.textSecondary, fontSize = 14.sp, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(28.dp))
                        }
                    }
                    items(vm.comments, key = { it.id }) { comment ->
                        Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).padding(start = 16.dp, end = 16.dp, top = 12.dp)) {
                            WynAvatar(comment.authorAvatarUrl, 36)
                            Spacer(Modifier.width(8.dp))
                            Column(Modifier.weight(1f)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(comment.authorLabel + if (comment.authorVerified) " ✓" else "", color = c.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
                                    Spacer(Modifier.width(8.dp))
                                    Text(FeedText.relativeTime(comment.createdAt, english), color = c.textMuted, fontSize = 13.sp)
                                }
                                Text(comment.text, color = c.text, fontSize = 15.sp, lineHeight = 21.sp, modifier = Modifier.padding(top = 4.dp))
                            }
                            if (comment.authorId == vm.userId) {
                                val delete = stringResource(R.string.quote_comment_delete)
                                Box(Modifier.size(38.dp).clickable(enabled = !vm.sending) { vm.remove(comment) }.semantics { contentDescription = delete }, contentAlignment = Alignment.Center) {
                                    Icon(WynIcons.Trash, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(17.dp))
                                }
                            }
                        }
                    }
                    if (vm.hasMore) {
                        item(key = "more") {
                            Text(
                                stringResource(R.string.quote_comments_more), color = c.text, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth().clickable(enabled = !vm.commentsLoading, onClick = vm::loadMore).padding(20.dp),
                            )
                        }
                    }
                }
                Column(Modifier.background(c.bg).navigationBarsPadding()) {
                    HorizontalDivider(color = c.border, thickness = 1.dp)
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(start = 12.dp, end = 12.dp, top = 8.dp, bottom = 8.dp)) {
                        val placeholder = stringResource(R.string.quote_comment_placeholder)
                        BasicTextField(
                            value = vm.draft, onValueChange = vm::updateDraft, singleLine = true,
                            textStyle = TextStyle(color = c.text, fontSize = 15.sp), cursorBrush = SolidColor(c.text),
                            modifier = Modifier.weight(1f).height(42.dp).clip(RoundedCornerShape(999.dp)).border(1.dp, c.border, RoundedCornerShape(999.dp))
                                .background(c.surface).padding(horizontal = 14.dp, vertical = 11.dp).semantics { contentDescription = placeholder },
                            decorationBox = { inner -> Box { if (vm.draft.isEmpty()) Text(placeholder, color = c.textMuted, fontSize = 15.sp); inner() } },
                        )
                        Spacer(Modifier.width(7.dp))
                        val enabled = !vm.sending && vm.draft.isNotBlank()
                        val send = stringResource(R.string.send_comment)
                        Box(
                            Modifier.size(40.dp).clip(CircleShape).background(c.text).clickable(enabled = enabled, onClick = vm::send).semantics { contentDescription = send },
                            contentAlignment = Alignment.Center,
                        ) { Icon(WynIcons.Send, contentDescription = null, tint = c.bg, modifier = Modifier.size(19.dp)) }
                    }
                }
            }
        }
    }
    QuoteSheets(vm.quote, vm.userId) { vm.markDeleted() }
    QuoteComposer(vm.quote, myAvatar, myName) {}
    val toast = vm.toast
    LaunchedEffect(toast) { if (toast != null) { delay(3500); vm.dismissToast() } }
    if (toast != null) {
        Box(Modifier.fillMaxSize().padding(bottom = 80.dp, start = 14.dp, end = 14.dp), contentAlignment = Alignment.BottomCenter) {
            SnackBar(toast.text().orEmpty(), null, null)
        }
    }
}
