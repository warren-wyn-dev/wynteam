package io.wyn.wyn.feature.clubs

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import io.wyn.wyn.R
import io.wyn.wyn.core.data.Club
import io.wyn.wyn.core.data.ClubMessage
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.compose.PhotoReader
import io.wyn.wyn.feature.compose.PhotoRejected
import io.wyn.wyn.feature.home.FeedText
import io.wyn.wyn.feature.home.rememberEnglish
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/** web ClubDetailGoldenInner. */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun ClubScreen(vm: ClubViewModel, onBack: () -> Unit, onOpenProfile: (String) -> Unit, onOpenPost: (String) -> Unit) {
    val c = Wyn.colors
    val context = LocalContext.current
    val detail = vm.detail
    if (detail == null) {
        Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding()) {
            ClubTopBar("", onBack)
            if (vm.loading) ClubLoading() else ClubEmpty(vm.error.text() ?: stringResource(R.string.club_not_found))
        }
        return
    }
    val club = detail.club
    val approved = vm.approved
    Column(Modifier.fillMaxSize().background(c.bg).imePadding()) {
        PullToRefreshBox(
            isRefreshing = vm.refreshing,
            onRefresh = { if (vm.tab == ClubTab.Posts) vm.pull() },
            modifier = Modifier.weight(1f),
        ) {
            LazyColumn(Modifier.fillMaxSize()) {
                item(key = "banner") { Banner(club, onBack) }
                item(key = "meta") {
                    Meta(vm, club, onShare = { shareLink(context, club.name, vm.shareUrl) })
                }
                stickyHeader(key = "tabs") { Tabs(vm.tab, vm::select) }
                when (vm.tab) {
                    ClubTab.Posts -> posts(vm, onOpenProfile, onOpenPost)
                    ClubTab.Chat -> chat(vm.chat, onOpenProfile)
                    ClubTab.About -> about(vm, club, onOpenProfile)
                }
            }
            ClubToast(vm.toast, vm::dismissToast, Modifier.align(Alignment.BottomCenter))
        }
        if (vm.tab == ClubTab.Chat && approved) ChatComposer(vm.chat)
    }
    ClubMenu(vm)
    vm.postMenu?.let { post ->
        val current = vm.posts.firstOrNull { it.id == post.id } ?: post
        ClubSheet(onDismiss = { vm.openPostMenu(null) }) {
            SheetRow(WynIcons.Share, stringResource(R.string.share), first = true) {
                vm.openPostMenu(null)
                shareLink(context, current.authorLabel, vm.postShareUrl(current))
            }
            SheetRow(
                if (current.saved) WynIcons.BookmarkFilled else WynIcons.Bookmark,
                stringResource(if (current.saved) R.string.club_post_unsave else R.string.club_post_save),
            ) { vm.saveFromMenu(current) }
            if (current.canDelete(vm.userId)) {
                SheetRow(WynIcons.Trash, stringResource(R.string.club_post_delete), danger = true) { vm.askDelete(current) }
            }
            if (current.canPin(vm.userId)) {
                SheetRow(WynIcons.Pin, stringResource(if (current.pinned) R.string.club_post_unpin else R.string.club_post_pin)) { vm.togglePin(current) }
            }
            if (!current.own(vm.userId)) {
                SheetRow(WynIcons.Flag, stringResource(R.string.club_post_report)) { vm.reportPost(current) }
            }
        }
    }
    ClubReportSheet(vm.report)
    vm.confirm?.let { confirm ->
        val (title, action) = when (confirm) {
            ClubConfirm.Leave -> stringResource(R.string.club_leave_confirm) to stringResource(R.string.club_leave)
            ClubConfirm.CancelRequest -> stringResource(R.string.club_cancel_request_confirm) to stringResource(R.string.club_cancel_request)
            is ClubConfirm.DeletePost -> stringResource(R.string.club_post_delete_confirm) to stringResource(R.string.delete)
            is ClubConfirm.DeleteMessage -> stringResource(R.string.club_chat_delete_confirm) to stringResource(R.string.delete)
        }
        ClubConfirmDialog(title, action, vm::confirmNow, vm::dismissConfirm)
    }
}

@Composable
private fun Banner(club: Club, onBack: () -> Unit) {
    Box(Modifier.fillMaxWidth().background(Wyn.colors.text)) {
        Box(Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.statusBars).height(140.dp))
        if (club.coverUrl != null) {
            AsyncImage(club.coverUrl, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.matchParentSize())
        }
        Box(
            Modifier.matchParentSize().background(
                Brush.horizontalGradient(0f to Color(0xBD0A0A0A), 0.65f to Color(0x3D0A0A0A), 1f to Color(0x140A0A0A)),
            ),
        )
        val back = stringResource(R.string.back)
        Box(
            Modifier.statusBarsPadding().padding(start = 8.dp, top = 8.dp).size(42.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.82f))
                .clickable(role = Role.Button, onClickLabel = back, onClick = onBack).semantics { contentDescription = back },
            contentAlignment = Alignment.Center,
        ) { Icon(WynIcons.Back, contentDescription = null, tint = Color(0xFF171717), modifier = Modifier.size(28.dp)) }
        Column(Modifier.align(Alignment.BottomStart).padding(start = 24.dp, end = 24.dp, bottom = 38.dp)) {
            Text("CLUB", color = Color.White.copy(alpha = 0.72f), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.8.sp)
            Spacer(Modifier.height(4.dp))
            Text(
                club.name, color = Color.White, fontSize = 22.sp, lineHeight = 24.6.sp, fontWeight = FontWeight.Bold,
                maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.fillMaxWidth(0.9f),
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Meta(vm: ClubViewModel, club: Club, onShare: () -> Unit) {
    val c = Wyn.colors
    val membership = vm.membership
    val status = stringResource(
        when {
            vm.owner -> R.string.club_status_owner
            vm.approved -> R.string.club_status_joined
            vm.pending -> R.string.clubs_pending
            else -> R.string.clubs_join
        },
    )
    Column(Modifier.fillMaxWidth().padding(start = 24.dp, end = 24.dp, top = 16.dp, bottom = 8.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(
                Modifier.size(36.dp).border(1.dp, c.border, CircleShape).padding(1.dp).border(2.dp, c.bg, CircleShape).clip(CircleShape).background(c.surface),
                contentAlignment = Alignment.Center,
            ) {
                if (club.iconUrl != null) {
                    AsyncImage(club.iconUrl, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                } else {
                    Text(club.name.take(1), color = c.text, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                }
            }
            Text(
                club.name, color = c.text, fontSize = 16.sp, lineHeight = 19.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f).padding(top = 5.dp),
            )
            RoundButton(WynIcons.Share, stringResource(R.string.share), onShare)
            RoundButton(WynIcons.MoreVertical, stringResource(R.string.more)) { vm.openMenu(true) }
        }
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            itemVerticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(top = 8.dp),
        ) {
            Text(stringResource(R.string.clubs_members, memberCount(club.memberCount)), color = c.textSecondary, fontSize = 13.sp)
            club.category?.takeIf { it.isNotEmpty() }?.let {
                Text(it, color = c.textSecondary, fontSize = 13.sp, modifier = Modifier.clip(RoundedCornerShape(999.dp)).background(c.border).padding(horizontal = 8.dp, vertical = 2.dp))
            }
            if (club.isPrivate) Icon(WynIcons.Lock, contentDescription = stringResource(R.string.club_private), tint = c.textSecondary, modifier = Modifier.size(13.dp))
            if (membership != null) {
                val enabled = !vm.busy && !vm.owner && !vm.pending
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.heightIn(min = 30.dp).clip(RoundedCornerShape(999.dp)).border(1.dp, c.textSecondary, RoundedCornerShape(999.dp))
                        .clickable(enabled = enabled, role = Role.Button, onClick = vm::onMembershipTap).padding(horizontal = 11.dp),
                ) {
                    val tint = c.textSecondary.copy(alpha = if (enabled) 1f else 0.72f)
                    if (vm.approved && !vm.owner) {
                        Icon(WynIcons.Check, contentDescription = null, tint = tint, modifier = Modifier.size(11.dp))
                        Spacer(Modifier.width(4.dp))
                    }
                    Text(status, color = tint, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
        club.description?.takeIf { it.isNotEmpty() }?.let {
            Text(it, color = c.text, fontSize = 15.sp, lineHeight = 21.75.sp, modifier = Modifier.padding(top = 12.dp))
        }
        if (membership == null) {
            Box(
                Modifier.padding(top = 16.dp).fillMaxWidth().height(44.dp).clip(RoundedCornerShape(999.dp)).background(c.text)
                    .clickable(enabled = !vm.busy, role = Role.Button, onClick = vm::onMembershipTap),
                contentAlignment = Alignment.Center,
            ) { Text(status, color = c.bg, fontSize = 15.sp, fontWeight = FontWeight.SemiBold) }
        }
        ErrorText(vm.error.text())
    }
}

@Composable
private fun RoundButton(icon: ImageVector, label: String, onClick: () -> Unit) {
    val c = Wyn.colors
    Box(
        Modifier.size(36.dp).clip(CircleShape).border(1.dp, c.border, CircleShape).background(c.bg)
            .clickable(role = Role.Button, onClickLabel = label, onClick = onClick).semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) { Icon(icon, contentDescription = null, tint = c.text, modifier = Modifier.size(15.dp)) }
}

@Composable
private fun Tabs(selected: ClubTab, onSelect: (ClubTab) -> Unit) {
    val c = Wyn.colors
    Column(Modifier.fillMaxWidth().background(c.bg).windowInsetsPadding(WindowInsets.statusBars)) {
        Row(Modifier.fillMaxWidth().height(53.dp)) {
            listOf(
                Triple(ClubTab.Posts, WynIcons.FileText, R.string.club_tab_posts),
                Triple(ClubTab.Chat, WynIcons.MessagesSquare, R.string.club_tab_chat),
                Triple(ClubTab.About, WynIcons.Info, R.string.club_tab_about),
            ).forEach { (tab, icon, label) ->
                val active = tab == selected
                val tint = if (active) c.text else c.textSecondary
                Box(Modifier.weight(1f).fillMaxSize().selectable(active, role = Role.Tab) { onSelect(tab) }, contentAlignment = Alignment.Center) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text(stringResource(label), color = tint, fontSize = 13.sp, fontWeight = if (active) FontWeight.SemiBold else FontWeight.Normal)
                    }
                    if (active) Box(Modifier.align(Alignment.BottomCenter).size(34.dp, 2.dp).clip(RoundedCornerShape(999.dp)).background(c.text))
                }
            }
        }
        HorizontalDivider(color = c.border, thickness = 1.dp)
    }
}

private fun LazyListScope.posts(vm: ClubViewModel, onOpenProfile: (String) -> Unit, onOpenPost: (String) -> Unit) {
    val club = vm.detail?.club ?: return
    when {
        club.isPrivate && !vm.approved -> item(key = "locked") { ClubEmpty(stringResource(R.string.club_join_to_see_posts)) }
        vm.posts.isEmpty() -> item(key = "empty") { ClubEmpty(stringResource(R.string.club_posts_empty)) }
        else -> items(vm.posts, key = { "post:" + it.id }) { post ->
            ClubPostCard(
                post,
                ClubPostActions(
                    onLike = { vm.toggleLike(post) },
                    onOpen = { onOpenPost(post.id) },
                    onAuthor = { onOpenProfile(post.authorId) },
                    onMore = { vm.openPostMenu(post) },
                    onVote = { vm.vote(post, it) },
                ),
            )
        }
    }
}

// ---- Chat ----------------------------------------------------------------------

private fun LazyListScope.chat(chat: ClubChat, onOpenProfile: (String) -> Unit) {
    if (!chat.approved) {
        item(key = "chat-locked") { ClubEmpty(stringResource(R.string.club_chat_join)) }
        return
    }
    item(key = "channels") { Channels(chat) }
    when {
        chat.loading -> item(key = "chat-loading") { ClubLoading() }
        chat.messages.isEmpty() -> item(key = "chat-empty") { ClubEmpty(stringResource(R.string.club_chat_empty)) }
        else -> items(chat.messages, key = { "message:" + it.id }) { message ->
            ChatBubble(message, mine = message.authorId == chat.userId, onMore = { chat.onMore(message) }, onAuthor = { onOpenProfile(message.authorId) })
        }
    }
    item(key = "chat-end") { Spacer(Modifier.height(12.dp)) }
}

@Composable
private fun Channels(chat: ClubChat) {
    val c = Wyn.colors
    Column {
        Row(
            Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 14.dp, vertical = 10.dp)
                .semantics { contentDescription = "channels" },
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            chat.channels.forEach { channel ->
                val active = channel.id == chat.channelId
                Box(
                    Modifier.heightIn(min = 34.dp).clip(RoundedCornerShape(999.dp)).border(1.dp, if (active) c.text else c.border, RoundedCornerShape(999.dp))
                        .background(if (active) c.text else c.bg).selectable(active, role = Role.Tab) { chat.select(channel.id) }.padding(horizontal = 13.dp),
                    contentAlignment = Alignment.Center,
                ) { Text("#${channel.name}", color = if (active) c.bg else c.textSecondary, fontSize = 13.sp) }
            }
        }
        HorizontalDivider(color = c.border, thickness = 1.dp)
    }
}

@Composable
private fun ChatBubble(message: ClubMessage, mine: Boolean, onMore: () -> Unit, onAuthor: () -> Unit) = BoxWithConstraints(Modifier.fillMaxWidth()) {
    val c = Wyn.colors
    val english = rememberEnglish()
    // golden-club-bubble: at most 78% of the chat's width (the chat has 14dp sides).
    val maxBubble = (maxWidth - 28.dp) * 0.78f
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 5.dp),
        horizontalArrangement = if (mine) Arrangement.End else Arrangement.Start,
        verticalAlignment = Alignment.Bottom,
    ) {
        if (!mine) {
            WynAvatar(message.authorAvatarUrl, 30, Modifier.clickable(onClick = onAuthor), contentDescription = message.authorLabel)
            Spacer(Modifier.width(8.dp))
        }
        val shape = if (mine) RoundedCornerShape(15.dp, 15.dp, 4.dp, 15.dp) else RoundedCornerShape(15.dp, 15.dp, 15.dp, 4.dp)
        val ink = if (mine) c.bg else c.text
        Column(Modifier.widthIn(max = maxBubble).clip(shape).background(if (mine) c.text else c.surface).padding(horizontal = 10.dp, vertical = 8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.heightIn(min = 20.dp)) {
                Text(
                    if (mine) stringResource(R.string.club_chat_you) else message.authorLabel, color = ink, fontSize = 11.sp, fontWeight = FontWeight.Bold,
                    maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false),
                )
                Spacer(Modifier.width(6.dp))
                val options = stringResource(R.string.club_chat_message_options)
                Box(
                    Modifier.size(24.dp).clip(CircleShape).clickable(role = Role.Button, onClickLabel = options, onClick = onMore).semantics { contentDescription = options },
                    contentAlignment = Alignment.Center,
                ) { Icon(WynIcons.More, contentDescription = null, tint = ink.copy(alpha = 0.65f), modifier = Modifier.size(16.dp)) }
            }
            message.content?.takeIf { it.isNotEmpty() }?.let { Text(it, color = ink, fontSize = 14.sp, lineHeight = 18.9.sp) }
            message.imageUrl?.let { url ->
                AsyncImage(url, contentDescription = null, contentScale = ContentScale.FillWidth, modifier = Modifier.padding(top = 6.dp).widthIn(max = 240.dp).clip(RoundedCornerShape(10.dp)))
            }
            Text(
                FeedText.relativeTime(message.createdAt, english), color = ink.copy(alpha = 0.65f), fontSize = 9.5.sp,
                modifier = Modifier.align(Alignment.End).padding(top = 4.dp),
            )
        }
    }
}

@Composable
private fun ChatComposer(chat: ClubChat) {
    val c = Wyn.colors
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            try {
                chat.attach(withContext(Dispatchers.IO) { PhotoReader.read(context, uri) })
            } catch (e: PhotoRejected) {
                chat.showError(UiText(e.reason))
            } catch (e: Exception) {
                chat.showError(UiText(R.string.photo_wrong_type))
            }
        }
    }
    Column(Modifier.fillMaxWidth().background(c.bg).navigationBarsPadding()) {
        chat.error?.let { Box(Modifier.padding(horizontal = 14.dp)) { ErrorText(it.text()) } }
        HorizontalDivider(color = c.border, thickness = 1.dp)
        Row(
            Modifier.fillMaxWidth().heightIn(min = 58.dp).padding(horizontal = 10.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            val attach = stringResource(R.string.club_chat_attach)
            Box(
                Modifier.size(42.dp).clip(CircleShape).clickable(enabled = !chat.sending, role = Role.Button, onClickLabel = attach) {
                    picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                }.semantics { contentDescription = attach },
                contentAlignment = Alignment.Center,
            ) { Icon(WynIcons.ImagePlus, contentDescription = null, tint = c.text, modifier = Modifier.size(20.dp)) }
            val hint = stringResource(if (chat.image != null) R.string.club_chat_attached else R.string.club_chat_hint)
            BasicTextField(
                value = chat.draft,
                onValueChange = chat::updateDraft,
                singleLine = true,
                textStyle = TextStyle(color = c.text, fontSize = 16.sp),
                cursorBrush = SolidColor(c.text),
                modifier = Modifier.weight(1f).semantics { contentDescription = hint },
                decorationBox = { inner ->
                    Box(
                        Modifier.fillMaxWidth().height(42.dp).clip(RoundedCornerShape(999.dp)).border(1.dp, c.border, RoundedCornerShape(999.dp))
                            .background(c.surface).padding(horizontal = 14.dp),
                        contentAlignment = Alignment.CenterStart,
                    ) {
                        if (chat.draft.isEmpty()) Text(hint, color = c.textMuted, fontSize = 16.sp, maxLines = 1)
                        inner()
                    }
                },
            )
            val send = stringResource(R.string.club_chat_send)
            Box(
                Modifier.size(42.dp).clip(CircleShape).background(c.text.copy(alpha = if (chat.canSend) 1f else 0.4f))
                    .clickable(enabled = chat.canSend, role = Role.Button, onClickLabel = send, onClick = chat::send).semantics { contentDescription = send },
                contentAlignment = Alignment.Center,
            ) { Icon(WynIcons.Send, contentDescription = null, tint = c.bg, modifier = Modifier.size(20.dp)) }
        }
    }
}

// ---- About ---------------------------------------------------------------------

private fun LazyListScope.about(vm: ClubViewModel, club: Club, onOpenProfile: (String) -> Unit) {
    val about = vm.about
    item(key = "about-tabs") { AboutTabs(about, aboutTabs(vm.membership)) }
    when {
        about.loading -> item(key = "about-loading") { ClubLoading() }
        about.tab == AboutTab.Details -> item(key = "details") { Details(club) }
        about.tab == AboutTab.Members -> if (about.members.isEmpty()) {
            item(key = "members-empty") { ClubEmpty(stringResource(R.string.about_members_empty)) }
        } else {
            items(about.members, key = { "member:" + it.userId }) { person -> MemberRow(person) { onOpenProfile(person.userId) } }
        }
        about.tab == AboutTab.Events -> if (about.events.isEmpty()) {
            item(key = "events-empty") { ClubEmpty(stringResource(R.string.about_events_empty)) }
        } else {
            items(about.events, key = { "event:" + it.id }) { event -> EventRow(event) }
        }
        else -> item(key = "insights") { Insights(about.insights) }
    }
    about.error?.let { error -> item(key = "about-error") { Box(Modifier.padding(horizontal = 18.dp)) { ErrorText(error.text()) } } }
}

@Composable
private fun MemberRow(person: io.wyn.wyn.core.data.ClubMember, onOpen: () -> Unit) {
    val c = Wyn.colors
    Column {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 64.dp).clickable(role = Role.Button, onClick = onOpen).padding(horizontal = 16.dp, vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            WynAvatar(person.avatarUrl, 42)
            Column(Modifier.weight(1f)) {
                Text(person.label, color = c.text, fontSize = 14.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text("@${person.username} · ${person.role}", color = c.textSecondary, fontSize = 11.5.sp, maxLines = 1)
            }
            Icon(WynIcons.ChevronRight, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(18.dp))
        }
        HorizontalDivider(color = c.border, thickness = 1.dp)
    }
}

@Composable
private fun AboutTabs(about: ClubAbout, tabs: List<AboutTab>) {
    val c = Wyn.colors
    Row(
        Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 14.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        tabs.forEach { tab ->
            val active = tab == about.tab
            Box(
                Modifier.heightIn(min = 34.dp).clip(RoundedCornerShape(10.dp)).border(1.dp, if (active) c.text else c.border, RoundedCornerShape(10.dp))
                    .background(if (active) c.text else c.bg).selectable(active, role = Role.Tab) { about.select(tab) }.padding(horizontal = 12.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    stringResource(
                        when (tab) {
                            AboutTab.Details -> R.string.about_details
                            AboutTab.Members -> R.string.about_members
                            AboutTab.Events -> R.string.about_events
                            AboutTab.Insights -> R.string.about_insights
                        },
                    ),
                    color = if (active) c.bg else c.textSecondary, fontSize = 12.5.sp,
                )
            }
        }
    }
}

@Composable
private fun Details(club: Club) {
    val c = Wyn.colors
    Column(Modifier.fillMaxWidth().padding(start = 18.dp, end = 18.dp, top = 10.dp, bottom = 28.dp)) {
        Text(stringResource(R.string.about_details), color = c.text, fontSize = 15.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 12.dp, bottom = 7.dp))
        Text(club.description?.takeIf { it.isNotEmpty() } ?: stringResource(R.string.about_no_description), color = c.textSecondary, fontSize = 13.5.sp, lineHeight = 20.sp)
        Column(Modifier.padding(vertical = 16.dp).fillMaxWidth().clip(RoundedCornerShape(14.dp)).border(1.dp, c.border, RoundedCornerShape(14.dp))) {
            DetailRow(stringResource(R.string.create_club_category), club.category?.takeIf { it.isNotEmpty() } ?: "—")
            HorizontalDivider(color = c.border, thickness = 1.dp)
            DetailRow(stringResource(R.string.about_privacy), stringResource(if (club.isPrivate) R.string.club_private else R.string.club_public))
            HorizontalDivider(color = c.border, thickness = 1.dp)
            DetailRow(stringResource(R.string.about_members), memberCount(club.memberCount))
        }
        Text(stringResource(R.string.about_rules), color = c.text, fontSize = 15.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 12.dp, bottom = 7.dp))
        Text(club.rules?.takeIf { it.isNotEmpty() } ?: stringResource(R.string.about_no_rules), color = c.textSecondary, fontSize = 13.5.sp, lineHeight = 20.sp)
    }
}

@Composable
private fun DetailRow(label: String, value: String) {
    val c = Wyn.colors
    Row(Modifier.fillMaxWidth().heightIn(min = 44.dp).padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, color = c.textSecondary, fontSize = 12.sp, modifier = Modifier.weight(1f))
        Text(value, color = c.text, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    }
}

/** Event start in the phone's time zone, like toLocaleString("th-TH"). */
fun eventTime(iso: String, english: Boolean, zone: ZoneId = ZoneId.systemDefault()): String = runCatching {
    val locale = if (english) Locale.ENGLISH else Locale.forLanguageTag("th-TH")
    DateTimeFormatter.ofLocalizedDateTime(FormatStyle.SHORT).withLocale(locale).format(Instant.parse(iso).atZone(zone))
}.getOrDefault(iso)

@Composable
private fun EventRow(event: io.wyn.wyn.core.data.ClubEvent) {
    val c = Wyn.colors
    val english = rememberEnglish()
    Column(Modifier.padding(horizontal = 14.dp)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(WynIcons.CalendarDays, contentDescription = null, tint = c.text, modifier = Modifier.size(20.dp))
            Column(Modifier.weight(1f)) {
                Text(event.title, color = c.text, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                Text(eventTime(event.startsAt, english), color = c.textSecondary, fontSize = 11.sp, modifier = Modifier.padding(top = 2.dp))
                val place = stringResource(if (event.locationType == "online") R.string.event_online else R.string.event_place)
                Text(stringResource(R.string.event_location, place, event.location), color = c.textSecondary, fontSize = 12.5.sp, modifier = Modifier.padding(top = 4.dp))
                event.description?.let { Text(it, color = c.textSecondary, fontSize = 12.5.sp, modifier = Modifier.padding(top = 4.dp)) }
            }
        }
        HorizontalDivider(color = c.border, thickness = 1.dp)
    }
}

/** "new_members" → "New Members", like the web's replaceAll("_", " ") + capitalize. */
fun insightLabel(key: String): String = key.split('_').filter { it.isNotEmpty() }.joinToString(" ") { word -> word.replaceFirstChar { it.uppercase() } }

@Composable
private fun Insights(values: List<Pair<String, String>>?) {
    val c = Wyn.colors
    if (values.isNullOrEmpty()) {
        ClubEmpty(stringResource(R.string.about_insights_empty))
        return
    }
    Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        values.chunked(2).forEach { pair ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                pair.forEach { (key, value) ->
                    Column(
                        Modifier.weight(1f).heightIn(min = 82.dp).clip(RoundedCornerShape(14.dp)).border(1.dp, c.border, RoundedCornerShape(14.dp)).padding(12.dp),
                        verticalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text(insightLabel(key), color = c.textSecondary, fontSize = 11.sp)
                        Text(value, color = c.text, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                    }
                }
                if (pair.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun ClubMenu(vm: ClubViewModel) {
    if (!vm.menuOpen) return
    val muted = vm.detail?.muted == true
    ClubSheet(onDismiss = { vm.openMenu(false) }) {
        var first = true
        fun takeFirst(): Boolean = first.also { first = false }
        if (vm.approved) {
            SheetRow(
                if (muted) WynIcons.Bell else WynIcons.BellOff,
                stringResource(if (muted) R.string.club_unmute else R.string.club_mute), first = takeFirst(), enabled = !vm.busy, onClick = vm::toggleMute,
            )
        }
        if (vm.canManage) SheetRow(WynIcons.Info, stringResource(R.string.club_manage), first = takeFirst(), onClick = vm::manage)
        if (vm.approved && !vm.canManage) SheetRow(WynIcons.LogOut, stringResource(R.string.club_leave), first = takeFirst(), danger = true, enabled = !vm.busy, onClick = vm::leaveFromMenu)
        if (vm.pending) SheetRow(WynIcons.Close, stringResource(R.string.club_cancel_request), first = takeFirst(), enabled = !vm.busy, onClick = vm::leaveFromMenu)
        if (!vm.owner) SheetRow(WynIcons.Flag, stringResource(R.string.club_report), first = takeFirst(), onClick = vm::reportClub)
    }
}
