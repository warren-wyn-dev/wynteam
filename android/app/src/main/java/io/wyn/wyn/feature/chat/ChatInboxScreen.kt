package io.wyn.wyn.feature.chat

import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.wyn.wyn.R
import io.wyn.wyn.core.data.Conversation
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.home.EmptyState
import io.wyn.wyn.feature.home.FeedSkeleton
import io.wyn.wyn.feature.home.FeedText
import io.wyn.wyn.feature.home.rememberEnglish
import io.wyn.wyn.feature.profile.PillButton

private val UnreadBlue = Color(0xFF1677E7)
private val MenuDot = Color(0xFFE0203D)

/** web conversationPreview() text. */
@Composable
fun previewText(row: Conversation): String = when (val preview = previewKind(row)) {
    Preview.Deleted -> stringResource(R.string.chat_preview_deleted)
    is Preview.Text -> preview.text
    Preview.Photo -> stringResource(R.string.chat_preview_photo)
    Preview.Waiting -> stringResource(R.string.chat_preview_waiting)
    Preview.Start -> stringResource(R.string.chat_preview_start)
}

/** web chat-inbox-parity.tsx: the Chat tab. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatInboxScreen(vm: ChatInboxViewModel, onOpen: (Conversation) -> Unit) {
    val c = Wyn.colors
    val english = rememberEnglish()
    val requests = vm.view == InboxView.Requests
    Column(Modifier.fillMaxSize().background(c.bg)) {
        Row(Modifier.fillMaxWidth().height(76.dp).padding(start = 12.dp, end = 20.dp, top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(48.dp), contentAlignment = Alignment.Center) {
                if (requests) {
                    val back = stringResource(R.string.back)
                    Icon(
                        WynIcons.Back, contentDescription = back, tint = c.text,
                        modifier = Modifier.size(44.dp).clip(CircleShape).clickable(role = Role.Button, onClickLabel = back) { vm.show(InboxView.Inbox) }.padding(9.dp),
                    )
                }
            }
            Text(
                stringResource(if (requests) R.string.chat_requests_title else R.string.chat_title),
                color = c.text, fontSize = 20.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f),
            )
            if (!requests) {
                val search = stringResource(R.string.chat_search)
                Icon(
                    WynIcons.Search, contentDescription = search, tint = c.text,
                    modifier = Modifier.size(44.dp).clip(CircleShape).background(if (vm.searchOpen) c.surface else Color.Transparent)
                        .clickable(role = Role.Button, onClickLabel = search, onClick = vm::toggleSearch).padding(11.dp),
                )
                var menu by remember { mutableStateOf(false) }
                Box {
                    val more = stringResource(R.string.profile_more)
                    Icon(
                        WynIcons.More, contentDescription = more, tint = c.text,
                        modifier = Modifier.size(44.dp).clip(CircleShape).clickable(role = Role.Button, onClickLabel = more) { menu = true }.padding(11.dp),
                    )
                    if (vm.requests.isNotEmpty()) Box(Modifier.align(Alignment.TopEnd).padding(top = 8.dp, end = 6.dp).size(7.dp).clip(CircleShape).background(MenuDot))
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }, containerColor = c.bg) {
                        DropdownMenuItem(
                            leadingIcon = { Icon(WynIcons.MessagesSquare, contentDescription = null, tint = c.text, modifier = Modifier.size(18.dp)) },
                            text = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(stringResource(R.string.chat_requests_title), color = c.text, fontSize = 15.sp)
                                    if (vm.requests.isNotEmpty()) Text("  ${vm.requests.size}", color = c.text, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                }
                            },
                            onClick = { menu = false; vm.show(InboxView.Requests) },
                        )
                    }
                }
            }
        }
        if (vm.searchOpen && !requests) {
            Row(
                Modifier.padding(start = 24.dp, end = 24.dp, bottom = 16.dp).fillMaxWidth().height(52.dp).clip(RoundedCornerShape(999.dp)).background(c.surface).padding(horizontal = 18.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(WynIcons.Search, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(10.dp))
                Box(Modifier.weight(1f)) {
                    if (vm.query.isEmpty()) Text(stringResource(R.string.chat_search), color = c.textSecondary, fontSize = 16.sp)
                    BasicTextField(
                        vm.query, vm::updateQuery, singleLine = true, textStyle = TextStyle(color = c.text, fontSize = 16.sp),
                        cursorBrush = SolidColor(c.text), modifier = Modifier.fillMaxWidth(),
                    )
                }
                val close = stringResource(R.string.chat_search_close)
                Icon(
                    WynIcons.Close, contentDescription = close, tint = c.textSecondary,
                    modifier = Modifier.size(28.dp).clip(CircleShape).clickable(role = Role.Button, onClickLabel = close, onClick = vm::toggleSearch).padding(6.dp),
                )
            }
        }
        vm.error?.let { Text(it.text().orEmpty(), color = c.accent, fontSize = 13.sp, modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp)) }
        PullToRefreshBox(isRefreshing = false, onRefresh = vm::load, modifier = Modifier.weight(1f)) {
            val rows = vm.visible { row -> previewPlain(row) }
            LazyColumn(Modifier.fillMaxSize()) {
                when {
                    vm.loading -> item(key = "loading") { FeedSkeleton() }
                    vm.allowed == false -> item(key = "locked") {
                        Column(Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 64.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(stringResource(R.string.chat_locked_title), color = c.text, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                            Text(stringResource(R.string.chat_locked_body), color = c.textSecondary, fontSize = 13.sp)
                        }
                    }
                    requests && vm.requests.isEmpty() -> item(key = "no-requests") { EmptyState(stringResource(R.string.chat_no_requests), null) {} }
                    requests -> items(vm.requests, key = { it.id }) { row -> RequestRow(row, onOpen = { onOpen(row) }, onAccept = { vm.accept(row) }, onDecline = { vm.askDecline(row) }) }
                    rows.isEmpty() -> item(key = "empty") {
                        EmptyState(stringResource(if (vm.query.isNotBlank()) R.string.chat_no_results else R.string.chat_empty), null) {}
                    }
                    else -> {
                        items(rows, key = { it.id }) { row -> InboxRow(row, row.isUnread(vm.userId), english) { onOpen(row) } }
                        item(key = "end") {
                            Column(Modifier.fillMaxWidth().padding(top = 28.dp, bottom = 32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                Box(Modifier.size(40.dp).clip(CircleShape).background(c.surface), contentAlignment = Alignment.Center) {
                                    Icon(WynIcons.Check, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(18.dp))
                                }
                                Spacer(Modifier.height(10.dp))
                                Text(stringResource(R.string.chat_all_seen), color = c.textSecondary, fontSize = 13.sp)
                            }
                        }
                    }
                }
            }
        }
    }
    vm.confirmDecline?.let {
        AlertDialog(
            onDismissRequest = vm::dismissDecline,
            containerColor = c.bg,
            title = { Text(stringResource(R.string.chat_decline_confirm), color = c.text, fontWeight = FontWeight.Bold, fontSize = 17.sp) },
            confirmButton = { TextButton(onClick = vm::decline) { Text(stringResource(R.string.remove), color = c.accent, fontWeight = FontWeight.Bold) } },
            dismissButton = { TextButton(onClick = vm::dismissDecline) { Text(stringResource(R.string.cancel), color = c.textSecondary) } },
        )
    }
}

/** Search needs a plain string; this matches [previewText] for the cases that have text. */
private fun previewPlain(row: Conversation): String = (previewKind(row) as? Preview.Text)?.text.orEmpty()

@Composable
private fun InboxRow(row: Conversation, unread: Boolean, english: Boolean, onClick: () -> Unit) {
    val c = Wyn.colors
    Row(
        Modifier.fillMaxWidth().heightIn(min = 80.dp).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        WynAvatar(row.otherAvatarUrl, 54, contentDescription = row.otherLabel)
        Column(Modifier.weight(1f).padding(horizontal = 12.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(row.otherLabel, color = c.text, fontSize = 16.sp, fontWeight = if (unread) FontWeight.ExtraBold else FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(previewText(row), color = c.textSecondary, fontSize = 15.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(row.lastMessageAt?.let { FeedText.relativeTime(it, english) }.orEmpty(), color = c.textSecondary, fontSize = 14.sp)
            if (unread) {
                val label = stringResource(R.string.chat_unread)
                Box(Modifier.size(9.dp).clip(CircleShape).background(UnreadBlue).semantics { contentDescription = label })
            }
        }
    }
}

@Composable
private fun RequestRow(row: Conversation, onOpen: () -> Unit, onAccept: () -> Unit, onDecline: () -> Unit) {
    val c = Wyn.colors
    Column(Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
        Row(
            Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = onOpen).padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            WynAvatar(row.otherAvatarUrl, 48, contentDescription = row.otherLabel)
            Column(Modifier.weight(1f).padding(start = 12.dp)) {
                Text(row.otherLabel, color = c.text, fontSize = 15.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(previewText(row), color = c.textSecondary, fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        Row(Modifier.padding(start = 76.dp, end = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            PillButton(stringResource(R.string.chat_accept), filled = true, height = 34.dp, fontSize = 13, onClick = onAccept)
            PillButton(stringResource(R.string.remove), filled = false, outlined = true, height = 34.dp, fontSize = 13, onClick = onDecline)
        }
    }
}
