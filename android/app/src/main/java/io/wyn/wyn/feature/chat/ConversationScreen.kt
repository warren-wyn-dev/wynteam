package io.wyn.wyn.feature.chat

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import io.wyn.wyn.R
import io.wyn.wyn.core.data.ChatMessage
import io.wyn.wyn.core.data.ChatRepository
import io.wyn.wyn.core.data.instantMillis
import io.wyn.wyn.core.design.DarkWynColors
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.compose.PhotoReader
import io.wyn.wyn.feature.compose.PhotoRejected
import io.wyn.wyn.feature.home.SnackBar
import io.wyn.wyn.feature.home.rememberEnglish
import io.wyn.wyn.feature.profile.PillButton
import io.wyn.wyn.feature.profile.followLabel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private val ReadBlue = Color(0xFF1677E7)

/** web chatDateLabel / chatTimeLabel. */
object ChatTime {
    fun dayKey(value: String, zone: ZoneId = ZoneId.systemDefault()): String =
        runCatching { Instant.parse(value).atZone(zone).toLocalDate().toString() }.getOrDefault(value)

    fun dateLabel(value: String, english: Boolean, zone: ZoneId = ZoneId.systemDefault()): String {
        val date = runCatching { Instant.parse(value).atZone(zone) }.getOrNull() ?: return ""
        val locale = if (english) Locale.ENGLISH else Locale.forLanguageTag("th-TH")
        return DateTimeFormatter.ofPattern(if (english) "d MMMM yyyy" else "d MMMM yyyy", locale).format(date)
    }

    fun timeLabel(value: String, zone: ZoneId = ZoneId.systemDefault()): String =
        runCatching { DateTimeFormatter.ofPattern("HH:mm").format(Instant.parse(value).atZone(zone)) }.getOrDefault("")
}

@Composable
fun ConversationScreen(
    vm: ConversationViewModel,
    chat: ChatRepository,
    onBack: () -> Unit,
    onOpenProfile: (String) -> Unit,
    /** The other person is online now (web presence). */
    online: Boolean = false,
) {
    val c = Wyn.colors
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val english = rememberEnglish()
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            try {
                vm.attach(withContext(Dispatchers.IO) { PhotoReader.read(context, uri) })
                vm.showError(null)
            } catch (e: PhotoRejected) {
                vm.showError(UiText(e.reason))
            } catch (e: Exception) {
                vm.showError(UiText(R.string.photo_wrong_type))
            }
        }
    }
    LaunchedEffect(vm.closed) { if (vm.closed) onBack() }
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding().imePadding()) {
        // Header: back, avatar, name and @username.
        Row(Modifier.fillMaxWidth().height(72.dp).padding(start = 12.dp, end = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            val back = stringResource(R.string.back)
            Icon(
                WynIcons.Back, contentDescription = back, tint = c.text,
                modifier = Modifier.size(44.dp).clip(CircleShape).clickable(role = Role.Button, onClickLabel = back, onClick = onBack).padding(7.dp),
            )
            val person = vm.other
            if (person != null) {
                Row(
                    Modifier.weight(1f).clip(RoundedCornerShape(12.dp)).clickable(role = Role.Button) { onOpenProfile(person.id) }.padding(start = 6.dp, top = 4.dp, bottom = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box {
                        WynAvatar(person.avatarUrl, 44, contentDescription = stringResource(R.string.profile_photo_of, person.username))
                        if (online) OnlineDot(11.dp, Modifier.align(Alignment.BottomEnd).offset(1.dp, 1.dp))
                    }
                    Column(Modifier.padding(start = 10.dp)) {
                        Text(person.label, color = c.text, fontSize = 16.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        // web conversation header: "online" takes the @username's place while they are online.
                        if (online) {
                            Text(stringResource(R.string.chat_online), color = c.text, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
                        } else {
                            Text("@${person.username}", color = c.textSecondary, fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                    }
                }
            } else {
                Spacer(Modifier.weight(1f))
            }
        }
        val listState = rememberLazyListState()
        val ordered = vm.ordered
        LaunchedEffect(ordered.lastOrNull()?.id) { if (ordered.isNotEmpty()) listState.scrollToItem(listState.layoutInfo.totalItemsCount.coerceAtLeast(1) - 1) }
        LazyColumn(Modifier.weight(1f).fillMaxWidth(), state = listState) {
            val person = vm.other
            when {
                vm.loading && ordered.isEmpty() && person == null -> item(key = "loading") {
                    Box(Modifier.fillMaxWidth().padding(48.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = c.textSecondary, strokeWidth = 2.dp) }
                }
                person != null && ordered.isEmpty() -> item(key = "hero") { ProfileHero(vm, onOpenProfile) }
            }
            if (vm.hasMore) item(key = "older") {
                Box(Modifier.fillMaxWidth().padding(12.dp), contentAlignment = Alignment.Center) {
                    PillButton(stringResource(if (vm.loadingMore) R.string.chat_loading else R.string.chat_older), filled = false, enabled = !vm.loadingMore, height = 36.dp, fontSize = 13, onClick = vm::loadOlder)
                }
            }
            ordered.forEachIndexed { index, message ->
                item(key = message.id) {
                    val previous = ordered.getOrNull(index - 1)
                    Column {
                        if (previous == null || ChatTime.dayKey(previous.createdAt) != ChatTime.dayKey(message.createdAt)) {
                            Text(
                                ChatTime.dateLabel(message.createdAt, english), color = c.textSecondary, fontSize = 14.sp, textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth().padding(top = 18.dp, bottom = 10.dp),
                            )
                        }
                        MessageRow(vm, chat, message)
                    }
                }
            }
            item(key = "bottom") { Spacer(Modifier.height(12.dp)) }
        }
        vm.error?.let { Text(it.text().orEmpty(), color = c.accent, fontSize = 13.sp, modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) }
        when {
            vm.recipientPending -> RequestBar(stringResource(R.string.chat_request_accept_hint)) {
                PillButton(stringResource(R.string.chat_accept), filled = true, height = 40.dp, modifier = Modifier.weight(1f), onClick = vm::accept)
                PillButton(stringResource(R.string.remove), filled = false, outlined = true, height = 40.dp, modifier = Modifier.weight(1f)) { vm.decline() }
            }
            vm.requesterPending -> RequestBar(stringResource(R.string.chat_request_waiting)) {}
            else -> Composer(vm, onPick = { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) })
        }
    }
    vm.confirm?.let { question ->
        val (title, action) = when (question) {
            is ChatConfirm.DeleteMessage -> stringResource(R.string.chat_delete_confirm) to stringResource(R.string.remove)
            ChatConfirm.DeclineRequest -> stringResource(R.string.chat_decline_confirm) to stringResource(R.string.remove)
            ChatConfirm.CancelFollowRequest -> stringResource(R.string.follow_cancel_confirm, vm.other?.username.orEmpty()) to stringResource(R.string.follow_cancel)
        }
        AlertDialog(
            onDismissRequest = vm::dismissConfirm,
            containerColor = c.bg,
            title = { Text(title, color = c.text, fontWeight = FontWeight.Bold, fontSize = 17.sp) },
            confirmButton = { TextButton(onClick = vm::confirmNow) { Text(action, color = c.accent, fontWeight = FontWeight.Bold) } },
            dismissButton = { TextButton(onClick = vm::dismissConfirm) { Text(stringResource(R.string.cancel), color = c.textSecondary) } },
        )
    }
    vm.toast?.let { toast ->
        LaunchedEffect(toast) { delay(4000); vm.dismissToast() }
        Box(Modifier.fillMaxSize().padding(bottom = 90.dp, start = 14.dp, end = 14.dp), contentAlignment = Alignment.BottomCenter) {
            SnackBar(toast.text().orEmpty(), null, null)
        }
    }
}

@Composable
private fun ProfileHero(vm: ConversationViewModel, onOpenProfile: (String) -> Unit) {
    val c = Wyn.colors
    val person = vm.other ?: return
    Column(Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 36.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Column(Modifier.clip(RoundedCornerShape(16.dp)).clickable(role = Role.Button) { onOpenProfile(person.id) }.padding(8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            WynAvatar(person.avatarUrl, 112)
            Spacer(Modifier.height(14.dp))
            Text(person.label, color = c.text, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Text("@${person.username}", color = c.textSecondary, fontSize = 16.sp)
        }
        Spacer(Modifier.height(24.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            PillButton(stringResource(R.string.chat_view_profile), filled = false, icon = WynIcons.UserRound, height = 50.dp, fontSize = 15, modifier = Modifier.weight(1f)) { onOpenProfile(person.id) }
            val summary = vm.summary
            // Already following: nothing left to invite (web conversation-profile-actions).
            if (summary?.following != true) {
                PillButton(
                    followLabel(vm.followBusy, false, summary?.requested == true), filled = summary?.requested != true,
                    enabled = !vm.followBusy && summary != null, icon = WynIcons.CirclePlus, height = 50.dp, fontSize = 15, modifier = Modifier.weight(1f),
                ) { vm.toggleFollow() }
            }
        }
    }
}

@Composable
private fun MessageRow(vm: ConversationViewModel, chat: ChatRepository, message: ChatMessage) {
    val c = Wyn.colors
    val mine = message.senderId == vm.userId
    val dark = c.bg == DarkWynColors.bg
    val bubble = if (mine) c.text else c.surface
    val ink = if (mine) c.bg else c.text
    val otherRead = vm.meta?.otherLastReadAt
    val read = mine && otherRead != null && instantMillis(message.createdAt) <= instantMillis(otherRead)
    val canDelete = mine && message.deletedAt == null && !message.pending
    Row(
        Modifier.fillMaxWidth().padding(start = 12.dp, end = 16.dp, top = 6.dp, bottom = 6.dp),
        horizontalArrangement = if (mine) Arrangement.End else Arrangement.Start,
        verticalAlignment = Alignment.Top,
    ) {
        if (mine && vm.revealed == message.id && canDelete) {
            val label = stringResource(R.string.chat_delete_message)
            Icon(
                WynIcons.Trash, contentDescription = label, tint = c.accent,
                modifier = Modifier.padding(end = 6.dp, top = 10.dp).size(30.dp).clip(CircleShape).background(c.surface)
                    .clickable(role = Role.Button, onClickLabel = label) { vm.askDelete(message) }.padding(8.dp),
            )
        }
        if (!mine) {
            WynAvatar(vm.other?.avatarUrl, 34)
            Spacer(Modifier.width(8.dp))
        }
        Column(horizontalAlignment = if (mine) Alignment.End else Alignment.Start) {
            Column(
                Modifier.widthIn(max = 280.dp).clip(RoundedCornerShape(20.dp)).background(bubble)
                    .then(if (canDelete) Modifier.clickable(role = Role.Button) { vm.toggleReveal(message) } else Modifier)
                    .padding(horizontal = 15.dp, vertical = 10.dp),
            ) {
                if (message.deletedAt != null) {
                    Text(stringResource(R.string.chat_preview_deleted), color = ink.copy(alpha = 0.7f), fontSize = 15.sp, fontStyle = FontStyle.Italic)
                } else {
                    if (message.replyToId != null) {
                        Text(
                            when {
                                message.replyDeleted -> stringResource(R.string.chat_reply_deleted)
                                !message.replyText.isNullOrBlank() -> message.replyText
                                message.replyImage -> stringResource(R.string.chat_photo)
                                else -> stringResource(R.string.chat_message)
                            },
                            color = ink.copy(alpha = 0.7f), fontSize = 13.sp, maxLines = 2, overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.padding(bottom = 6.dp).clip(RoundedCornerShape(8.dp)).background(ink.copy(alpha = 0.08f)).padding(8.dp),
                        )
                    }
                    message.text?.let { Text(it, color = ink, fontSize = 16.sp, lineHeight = 22.sp) }
                    message.imagePath?.let { path -> ChatImage(chat, path) }
                }
            }
            Row(Modifier.padding(top = 4.dp, start = 2.dp, end = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    if (message.pending) stringResource(R.string.chat_sending)
                    else ChatTime.timeLabel(message.createdAt) + if (message.editedAt != null) stringResource(R.string.chat_edited) else "",
                    color = c.textSecondary, fontSize = 12.sp,
                )
                if (mine && !message.pending) {
                    val label = stringResource(if (read) R.string.chat_read else R.string.chat_sent)
                    Icon(
                        if (read) WynIcons.CheckCheck else WynIcons.Check, contentDescription = label,
                        tint = if (read) (if (dark) c.link else c.text) else c.textSecondary,
                        modifier = Modifier.padding(start = 6.dp).size(14.dp),
                    )
                }
            }
        }
    }
}

/** A private chat photo, through a short-lived signed link. */
@Composable
private fun ChatImage(chat: ChatRepository, path: String) {
    val c = Wyn.colors
    val url by produceState<String?>(null, path) { value = runCatching { chat.imageUrl(path) }.getOrNull() }
    val current = url
    if (current == null) {
        Text(stringResource(R.string.chat_image_loading), color = c.textSecondary, fontSize = 13.sp, modifier = Modifier.padding(vertical = 6.dp))
    } else {
        AsyncImage(
            current, contentDescription = stringResource(R.string.chat_photo), contentScale = ContentScale.Crop,
            modifier = Modifier.padding(top = 4.dp).size(250.dp, 290.dp).clip(RoundedCornerShape(14.dp)).background(c.border),
        )
    }
}

@Composable
private fun RequestBar(message: String, actions: @Composable androidx.compose.foundation.layout.RowScope.() -> Unit) {
    val c = Wyn.colors
    Column(Modifier.fillMaxWidth().navigationBarsPadding().border(1.dp, c.border).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(message, color = c.textSecondary, fontSize = 14.sp, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { actions() }
    }
}

@Composable
private fun Composer(vm: ConversationViewModel, onPick: () -> Unit) {
    val c = Wyn.colors
    Column(Modifier.fillMaxWidth().navigationBarsPadding().padding(start = 12.dp, end = 12.dp, top = 8.dp, bottom = 10.dp)) {
        vm.photo?.let {
            Row(
                Modifier.padding(start = 52.dp, bottom = 8.dp).clip(RoundedCornerShape(999.dp)).background(c.surface).padding(start = 12.dp, end = 4.dp, top = 4.dp, bottom = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(stringResource(R.string.chat_photo_attached), color = c.text, fontSize = 13.sp)
                val remove = stringResource(R.string.chat_remove_photo)
                Icon(
                    WynIcons.Close, contentDescription = remove, tint = c.textSecondary,
                    modifier = Modifier.padding(start = 4.dp).size(26.dp).clip(CircleShape).clickable(role = Role.Button, onClickLabel = remove) { vm.attach(null) }.padding(6.dp),
                )
            }
        }
        Row(verticalAlignment = Alignment.Bottom) {
            val attach = stringResource(R.string.chat_attach_photo)
            Icon(
                WynIcons.ImagePlus, contentDescription = attach, tint = c.text,
                modifier = Modifier.padding(bottom = 6.dp).size(44.dp).clip(CircleShape)
                    .clickable(enabled = !vm.sending, role = Role.Button, onClickLabel = attach, onClick = onPick).padding(10.dp),
            )
            Spacer(Modifier.width(8.dp))
            Row(
                Modifier.weight(1f).heightIn(min = 54.dp).clip(RoundedCornerShape(27.dp)).background(c.surface).border(1.dp, c.border, RoundedCornerShape(27.dp))
                    .padding(start = 18.dp, end = 5.dp, top = 5.dp, bottom = 5.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.weight(1f).padding(vertical = 8.dp)) {
                    if (vm.draft.isEmpty()) Text(stringResource(R.string.chat_placeholder), color = c.textSecondary, fontSize = 16.sp)
                    BasicTextField(
                        vm.draft, vm::updateDraft, enabled = !vm.sending, maxLines = 6,
                        textStyle = TextStyle(color = c.text, fontSize = 16.sp, lineHeight = 22.sp),
                        cursorBrush = SolidColor(c.text), modifier = Modifier.fillMaxWidth(),
                    )
                }
                val send = stringResource(R.string.send_comment)
                Box(
                    Modifier.size(44.dp).clip(CircleShape).background(if (vm.canSend) c.text else c.textMuted)
                        .clickable(enabled = vm.canSend, role = Role.Button, onClickLabel = send, onClick = vm::send),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(WynIcons.Send, contentDescription = send, tint = c.bg, modifier = Modifier.size(18.dp))
                }
            }
        }
    }
}
