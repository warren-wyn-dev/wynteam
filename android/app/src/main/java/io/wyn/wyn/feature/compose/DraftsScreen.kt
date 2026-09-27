package io.wyn.wyn.feature.compose

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import coil3.compose.AsyncImage
import io.wyn.wyn.R
import io.wyn.wyn.core.data.ComposerRepository
import io.wyn.wyn.core.data.Draft
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.feature.home.FeedText
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant
import kotlin.coroutines.cancellation.CancellationException

/** web drafts-route.tsx: saved drafts, newest first; open one to keep writing, or delete it. */
class DraftsViewModel(private val repo: ComposerRepository, private val userId: String) : ViewModel() {
    var drafts by mutableStateOf<List<Draft>>(emptyList()); private set
    var loading by mutableStateOf(true); private set
    var failed by mutableStateOf(false); private set
    var pendingDelete by mutableStateOf<Draft?>(null); private set
    var deleting by mutableStateOf(false); private set

    init {
        load()
    }

    fun load() {
        loading = true
        failed = false
        viewModelScope.launch {
            try {
                drafts = repo.fetchDrafts(userId)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                failed = true
            } finally {
                loading = false
            }
        }
    }

    fun askDelete(draft: Draft?) {
        if (!deleting) pendingDelete = draft
    }

    fun confirmDelete() {
        val target = pendingDelete ?: return
        deleting = true
        viewModelScope.launch {
            try {
                repo.deleteDraft(target.id)
                drafts = drafts.filterNot { it.id == target.id }
                pendingDelete = null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                failed = true
                pendingDelete = null
            } finally {
                deleting = false
            }
        }
    }
}

object DraftText {
    /** web draftPreviewText(). */
    fun preview(draft: Draft, poll: (String?) -> String, photo: String, empty: String): String = when {
        !draft.pollOptions.isNullOrEmpty() -> poll(draft.caption?.trim()?.takeIf { it.isNotEmpty() })
        !draft.caption.isNullOrBlank() -> draft.caption.trim()
        draft.imageUrl != null -> photo
        else -> empty
    }

    /** web relativeLabel(): "N นาทีที่แล้ว" style. */
    fun age(iso: String, english: Boolean, now: Instant = Instant.now()): String {
        val then = FeedText.parseInstant(iso) ?: return ""
        val minutes = Duration.between(then, now).toMinutes().coerceAtLeast(0)
        return when {
            minutes < 1 -> if (english) "Just now" else "เมื่อสักครู่"
            minutes < 60 -> if (english) "${minutes}m ago" else "$minutes นาทีที่แล้ว"
            minutes / 60 < 24 -> if (english) "${minutes / 60}h ago" else "${minutes / 60} ชั่วโมงที่แล้ว"
            else -> if (english) "${minutes / 1440}d ago" else "${minutes / 1440} วันที่แล้ว"
        }
    }
}

@Composable
fun DraftsScreen(vm: DraftsViewModel, onBack: () -> Unit, onOpen: (String) -> Unit) {
    val c = Wyn.colors
    val english = io.wyn.wyn.feature.home.rememberEnglish()
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding()) {
        Box(Modifier.fillMaxWidth().height(56.dp)) {
            val back = stringResource(R.string.back)
            Box(
                Modifier.size(48.dp, 56.dp).clickable(role = Role.Button, onClick = onBack).semantics { contentDescription = back },
                contentAlignment = Alignment.Center,
            ) { Icon(WynIcons.Back, contentDescription = null, tint = c.text, modifier = Modifier.size(22.dp)) }
            Text(stringResource(R.string.drafts_page_title), color = c.text, fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.align(Alignment.Center))
        }
        HorizontalDivider(color = c.border, thickness = 1.dp)
        when {
            vm.failed && vm.drafts.isEmpty() -> Message(stringResource(R.string.drafts_load_failed), stringResource(R.string.retry), vm::load)
            vm.loading && vm.drafts.isEmpty() -> Message(stringResource(R.string.loading_more), null) {}
            vm.drafts.isEmpty() -> Message(stringResource(R.string.drafts_empty), null) {}
            else -> LazyColumn {
                items(vm.drafts, key = { it.id }) { draft ->
                    val poll = stringResource(R.string.draft_poll)
                    val pollEmpty = stringResource(R.string.draft_poll_empty)
                    val text = DraftText.preview(
                        draft,
                        { question -> if (question != null) "$poll: $question" else pollEmpty },
                        stringResource(R.string.draft_photo), stringResource(R.string.draft_empty),
                    )
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().heightIn(min = 72.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.weight(1f).clickable { onOpen(draft.id) }.padding(horizontal = 16.dp, vertical = 12.dp),
                        ) {
                            if (draft.imageUrl != null) {
                                AsyncImage(draft.imageUrl, null, contentScale = ContentScale.Crop, modifier = Modifier.size(48.dp).clip(RoundedCornerShape(10.dp)).background(c.surface))
                            } else {
                                Box(Modifier.size(48.dp).clip(RoundedCornerShape(10.dp)).background(c.surface))
                            }
                            Spacer(Modifier.width(12.dp))
                            Column {
                                Text(text, color = c.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis)
                                Text(DraftText.age(draft.updatedAt, english), color = c.textMuted, fontSize = 13.sp)
                            }
                        }
                        val delete = stringResource(R.string.delete_draft)
                        Text(
                            stringResource(R.string.delete), color = Color(0xFFB42318), fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.clickable(role = Role.Button) { vm.askDelete(draft) }.semantics { contentDescription = delete }.padding(16.dp),
                        )
                    }
                    HorizontalDivider(color = c.border, thickness = 1.dp)
                }
            }
        }
    }
    vm.pendingDelete?.let {
        AlertDialog(
            onDismissRequest = { vm.askDelete(null) },
            containerColor = c.bg,
            title = { Text(stringResource(R.string.delete_draft_title), color = c.text, fontWeight = FontWeight.Bold) },
            text = { Text(stringResource(R.string.delete_draft_body), color = c.textSecondary) },
            confirmButton = { TextButton(onClick = vm::confirmDelete, enabled = !vm.deleting) { Text(stringResource(R.string.delete), color = Color(0xFFB42318), fontWeight = FontWeight.Bold) } },
            dismissButton = { TextButton(onClick = { vm.askDelete(null) }, enabled = !vm.deleting) { Text(stringResource(R.string.cancel), color = c.textSecondary) } },
        )
    }
}

@Composable
private fun Message(text: String, action: String?, onAction: () -> Unit) {
    val c = Wyn.colors
    Column(Modifier.fillMaxWidth().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(text, color = c.textSecondary, fontSize = 15.sp, textAlign = TextAlign.Center)
        if (action != null) {
            Text(action, color = c.text, fontSize = 15.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 12.dp).clickable(onClick = onAction).padding(8.dp))
        }
    }
}
