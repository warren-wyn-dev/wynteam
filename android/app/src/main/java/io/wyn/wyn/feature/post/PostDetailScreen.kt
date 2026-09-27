package io.wyn.wyn.feature.post

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
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
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import io.wyn.wyn.R
import io.wyn.wyn.core.data.ActivityPerson
import io.wyn.wyn.core.data.Comment
import io.wyn.wyn.core.data.FeedRow
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.core.design.WynTextField
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.home.FeedText
import io.wyn.wyn.feature.home.RichText
import io.wyn.wyn.feature.home.SnackBar
import io.wyn.wyn.feature.home.rememberEnglish
import kotlinx.coroutines.delay

private val LikeRed = Color(0xFFFF3B30)

@Composable
fun PostDetailScreen(vm: PostDetailViewModel, onBack: () -> Unit, onOpenAuthor: (String) -> Unit = {}) {
    val c = Wyn.colors
    val context = LocalContext.current
    LaunchedEffect(vm.deleted) { if (vm.deleted) onBack() }
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding().imePadding()) {
        DetailHeader(onBack)
        val row = vm.row
        when {
            row == null && vm.loading -> DetailSkeleton()
            row == null -> Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                Text(vm.error.text() ?: stringResource(R.string.post_not_found), color = c.textSecondary, fontSize = 15.sp)
            }
            else -> {
                LazyColumn(Modifier.weight(1f)) {
                    item(key = "post") {
                        PostBody(vm, row, onOpenAuthor) {
                            val send = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, vm.shareUrl())
                            }
                            context.startActivity(Intent.createChooser(send, null))
                        }
                    }
                    if (vm.error != null) item(key = "error") { Box(Modifier.padding(horizontal = 16.dp)) { ErrorText(vm.error.text()) } }
                    if (vm.comments.isEmpty()) {
                        item(key = "empty") {
                            Text(
                                stringResource(R.string.comments_empty), color = c.textSecondary, fontSize = 14.sp, textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth().padding(top = 28.dp, bottom = 40.dp),
                            )
                        }
                    }
                    vm.threads.forEachIndexed { index, (comment, replies) ->
                        item(key = comment.id) {
                            Column {
                                if (index > 0) HorizontalDivider(color = c.border, thickness = 1.dp)
                                CommentRow(comment, false, vm, onOpenAuthor)
                                replies.forEach { CommentRow(it, true, vm, onOpenAuthor) }
                            }
                        }
                    }
                    item(key = "footer") {
                        if (vm.hasMoreComments) {
                            Text(
                                stringResource(if (vm.loadingMore) R.string.loading_more else R.string.comments_more), color = c.text, fontSize = 14.sp,
                                fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth().clickable(enabled = !vm.loadingMore, onClick = vm::loadMoreComments).padding(20.dp),
                            )
                        } else if (vm.comments.isNotEmpty()) {
                            Text(
                                stringResource(R.string.comments_end), color = c.textMuted, fontSize = 13.sp, textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 24.dp, bottom = 28.dp),
                            )
                        }
                    }
                }
                Composer(vm)
            }
        }
    }
    DetailDialogs(vm)
    val toast = vm.toast
    LaunchedEffect(toast) { if (toast != null) { delay(4000); vm.dismissToast() } }
    if (toast != null) {
        Box(Modifier.fillMaxSize().padding(bottom = 90.dp, start = 14.dp, end = 14.dp), contentAlignment = Alignment.BottomCenter) {
            SnackBar(toast.text.text().orEmpty(), toast.actionLabel.text(), toast.action)
        }
    }
}

@Composable
private fun DetailHeader(onBack: () -> Unit) {
    val c = Wyn.colors
    val back = stringResource(R.string.back)
    Box(Modifier.fillMaxWidth().height(56.dp)) {
        Box(
            Modifier.size(48.dp, 56.dp).clickable(role = Role.Button, onClick = onBack).semantics { contentDescription = back },
            contentAlignment = Alignment.Center,
        ) { Icon(WynIcons.Back, contentDescription = null, tint = c.text, modifier = Modifier.size(22.dp)) }
        Text(stringResource(R.string.post_title), color = c.text, fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.align(Alignment.Center))
    }
    HorizontalDivider(color = c.border, thickness = 1.dp)
}

@Composable
private fun PostBody(vm: PostDetailViewModel, row: FeedRow, onOpenAuthor: (String) -> Unit, onShare: () -> Unit) {
    val c = Wyn.colors
    val english = rememberEnglish()
    val viewer = vm.viewer
    Column(Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.heightIn(min = 46.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.weight(1f).clickable { onOpenAuthor(row.authorId) },
            ) {
                WynAvatar(row.authorAvatarUrl, 44)
                Spacer(Modifier.width(10.dp))
                Column(Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            row.authorLabel + if (row.authorIsVerified) " ✓" else "", color = c.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                            maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false),
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(FeedText.relativeTime(row.createdAt, english), color = c.textMuted, fontSize = 13.sp, maxLines = 1)
                    }
                    Text("@${row.authorUsername ?: "wynos"}", color = c.textMuted, fontSize = 13.sp, maxLines = 1)
                }
            }
            if (!vm.isOwn) {
                val following = row.authorId in viewer.following
                val requested = row.authorId in viewer.requested
                Box(
                    Modifier.heightIn(min = 36.dp).clip(RoundedCornerShape(999.dp)).border(1.dp, c.text, RoundedCornerShape(999.dp))
                        .clickable(enabled = !vm.followBusy, role = Role.Button, onClick = vm::toggleFollow).padding(horizontal = 12.dp, vertical = 8.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        stringResource(if (following) R.string.following_label else if (requested) R.string.follow_requested else R.string.follow),
                        color = c.text, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                    )
                }
            }
            val more = stringResource(R.string.more)
            Box(
                Modifier.size(40.dp).clickable(role = Role.Button) { vm.open(DetailDialog.More) }.semantics { contentDescription = more },
                contentAlignment = Alignment.Center,
            ) { Icon(WynIcons.MoreVertical, contentDescription = null, tint = c.text, modifier = Modifier.size(18.dp)) }
        }
        row.caption?.takeIf { it.isNotBlank() }?.let {
            RichText(it, compact = false, onTag = {}, modifier = Modifier.padding(top = 10.dp, bottom = 12.dp))
        }
        Gallery(vm.images, row.mediaAspectRatio(vm.images.size > 1))
        Actions(vm, row, onShare)
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(top = 2.dp, bottom = 10.dp).fillMaxWidth().height(54.dp).clip(RoundedCornerShape(18.dp)).background(c.surface)
                .clickable { vm.open(DetailDialog.Activity) }.padding(start = 14.dp, end = 12.dp),
        ) {
            Icon(WynIcons.Poll, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(22.dp))
            Spacer(Modifier.width(27.dp))
            Text(stringResource(R.string.view_activity), color = c.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            Icon(WynIcons.ChevronRight, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(27.dp))
        }
    }
    HorizontalDivider(color = c.border, thickness = 1.dp)
}

/** The web's detail gallery: full-width photos you swipe through, with dots. */
@Composable
private fun Gallery(urls: List<String>, ratio: Float) {
    if (urls.isEmpty()) return
    val c = Wyn.colors
    val pager = rememberPagerState { urls.size }
    HorizontalPager(pager, modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp))) { page ->
        AsyncImage(
            model = urls[page], contentDescription = null, contentScale = ContentScale.Fit,
            modifier = Modifier.fillMaxWidth().aspectRatio(ratio).clip(RoundedCornerShape(18.dp)).background(c.surface),
        )
    }
    if (urls.size > 1) {
        Row(Modifier.fillMaxWidth().height(20.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
            urls.indices.forEach { i ->
                val active = i == pager.currentPage
                Box(Modifier.padding(horizontal = 2.5.dp).size(if (active) 7.dp else 5.dp).clip(CircleShape).background(if (active) c.text else c.borderStrong))
            }
        }
    }
}

@Composable
private fun Actions(vm: PostDetailViewModel, row: FeedRow, onShare: () -> Unit) {
    val c = Wyn.colors
    val liked = row.id in vm.viewer.liked
    val saved = row.id in vm.viewer.saved
    val reposted = row.id in vm.viewer.redropped
    Row(Modifier.fillMaxWidth().padding(top = 6.dp).height(48.dp)) {
        DetailAction(if (liked) WynIcons.HeartFilled else WynIcons.Heart, row.likeCount, if (liked) LikeRed else c.text, stringResource(if (liked) R.string.unlike else R.string.like), vm::toggleLike)
        DetailAction(WynIcons.Comment, row.commentCount, c.text, stringResource(R.string.comments)) {}
        if (row.canRedrop) {
            DetailAction(WynIcons.Repost, row.redropCount, c.text, stringResource(if (reposted) R.string.undo_repost else R.string.repost), vm::toggleRepost)
        }
        DetailAction(WynIcons.Share, null, c.text, stringResource(R.string.share), onShare)
        DetailAction(if (saved) WynIcons.SaveFilled else WynIcons.Save, null, c.text, stringResource(if (saved) R.string.unsave_long else R.string.save), vm::toggleSave)
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.DetailAction(icon: ImageVector, count: Int?, tint: Color, label: String, onClick: () -> Unit) {
    Row(
        Modifier.weight(1f).fillMaxSize().clickable(role = Role.Button, onClickLabel = label, onClick = onClick).semantics { contentDescription = label },
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(24.dp))
        if (count != null) {
            Spacer(Modifier.width(6.dp))
            Text(count.toString(), color = tint, fontSize = 13.sp)
        }
    }
}

@Composable
private fun CommentRow(comment: Comment, isReply: Boolean, vm: PostDetailViewModel, onOpenAuthor: (String) -> Unit) {
    val c = Wyn.colors
    val english = rememberEnglish()
    Row(
        Modifier.fillMaxWidth().heightIn(min = 64.dp).padding(start = if (isReply) 52.dp else 16.dp, end = 16.dp, top = 12.dp, bottom = 12.dp),
    ) {
        WynAvatar(comment.authorAvatarUrl, if (isReply) 32 else 34, modifier = Modifier.clickable { onOpenAuthor(comment.authorId) })
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(comment.authorLabel, color = c.text, fontSize = 13.5.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                Spacer(Modifier.width(6.dp))
                Text(FeedText.relativeTime(comment.createdAt, english), color = c.textMuted, fontSize = 12.sp, maxLines = 1)
            }
            Text(comment.text, color = c.text, fontSize = 14.sp, lineHeight = 20.sp, modifier = Modifier.padding(top = 3.dp, bottom = 5.dp))
            if (!isReply) {
                Text(
                    stringResource(R.string.reply), color = c.textSecondary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clickable(role = Role.Button) { vm.replyTo(comment) },
                )
            }
        }
        if (comment.authorId == vm.userId) {
            val delete = stringResource(R.string.delete_comment)
            Box(
                Modifier.size(38.dp).clickable(role = Role.Button) { vm.open(DetailDialog.DeleteComment(comment)) }.semantics { contentDescription = delete },
                contentAlignment = Alignment.Center,
            ) { Icon(WynIcons.Trash, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(16.dp)) }
        }
        val likeLabel = stringResource(if (comment.likedByMe) R.string.unlike_comment else R.string.like_comment)
        Column(
            Modifier.width(38.dp).heightIn(min = 38.dp).clickable(role = Role.Button) { vm.toggleCommentLike(comment) }.semantics { contentDescription = likeLabel },
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            val tint = if (comment.likedByMe) LikeRed else c.textSecondary
            Icon(if (comment.likedByMe) WynIcons.HeartFilled else WynIcons.Heart, contentDescription = null, tint = tint, modifier = Modifier.size(16.dp))
            if (comment.likeCount > 0) Text(comment.likeCount.toString(), color = tint, fontSize = 10.sp)
        }
    }
}

@Composable
private fun Composer(vm: PostDetailViewModel) {
    val c = Wyn.colors
    Column(Modifier.background(c.bg).navigationBarsPadding()) {
        HorizontalDivider(color = c.border, thickness = 1.dp)
        vm.replyTo?.let { target ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().heightIn(min = 30.dp).padding(start = 20.dp, end = 12.dp, top = 5.dp),
            ) {
                Text(stringResource(R.string.replying_to, target.authorLabel), color = c.textSecondary, fontSize = 12.sp, modifier = Modifier.weight(1f))
                val cancel = stringResource(R.string.cancel_reply)
                Box(Modifier.size(28.dp).clickable { vm.replyTo(null) }.semantics { contentDescription = cancel }, contentAlignment = Alignment.Center) {
                    Icon(WynIcons.Close, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(16.dp))
                }
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(start = 14.dp, end = 9.dp, top = 9.dp, bottom = 9.dp)) {
            WynAvatar(vm.me?.avatarUrl, 36)
            Spacer(Modifier.width(10.dp))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.weight(1f).height(46.dp).clip(RoundedCornerShape(999.dp)).border(1.dp, c.border, RoundedCornerShape(999.dp))
                    .padding(start = 14.dp, end = 5.dp),
            ) {
                val placeholder = stringResource(R.string.comment_placeholder)
                BasicTextField(
                    value = vm.draft, onValueChange = vm::updateDraft, singleLine = true,
                    textStyle = TextStyle(color = c.text, fontSize = 14.sp), cursorBrush = SolidColor(c.text),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                    keyboardActions = KeyboardActions(onSend = { vm.submitComment() }),
                    modifier = Modifier.weight(1f).semantics { contentDescription = placeholder },
                    decorationBox = { inner ->
                        Box { if (vm.draft.isEmpty()) Text(placeholder, color = c.textMuted, fontSize = 14.sp); inner() }
                    },
                )
                val send = stringResource(R.string.send_comment)
                val enabled = !vm.sending && vm.draft.isNotBlank()
                Box(
                    Modifier.size(38.dp).clip(CircleShape).clickable(enabled = enabled, role = Role.Button, onClick = vm::submitComment).semantics { contentDescription = send },
                    contentAlignment = Alignment.Center,
                ) { Icon(WynIcons.Send, contentDescription = null, tint = if (enabled) c.text else c.textMuted, modifier = Modifier.size(22.dp)) }
            }
        }
    }
}

@Composable
private fun DetailSkeleton() {
    val shade = Wyn.colors.surface
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row { Box(Modifier.size(44.dp).clip(CircleShape).background(shade)); Spacer(Modifier.width(10.dp)); Box(Modifier.width(140.dp).height(16.dp).clip(RoundedCornerShape(6.dp)).background(shade)) }
        Box(Modifier.fillMaxWidth().height(16.dp).clip(RoundedCornerShape(6.dp)).background(shade))
        Box(Modifier.fillMaxWidth(0.6f).height(16.dp).clip(RoundedCornerShape(6.dp)).background(shade))
        Box(Modifier.fillMaxWidth().height(260.dp).clip(RoundedCornerShape(18.dp)).background(shade))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DetailDialogs(vm: PostDetailViewModel) {
    val c = Wyn.colors
    when (val dialog = vm.dialog) {
        null -> Unit
        DetailDialog.More -> ModalBottomSheet(
            onDismissRequest = { vm.open(null) }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = c.bg, shape = RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp),
        ) {
            Column(Modifier.padding(bottom = 16.dp)) {
                if (vm.isOwn) {
                    if (vm.canEdit) SheetButton(WynIcons.Pencil, stringResource(R.string.edit), c.text) { vm.open(DetailDialog.Edit) }
                    SheetButton(WynIcons.Trash, stringResource(R.string.delete), Color(0xFFB42318)) { vm.open(DetailDialog.DeletePost) }
                } else {
                    SheetButton(WynIcons.Flag, stringResource(R.string.report_post), c.text) { vm.open(DetailDialog.Report) }
                }
            }
        }
        DetailDialog.Activity -> ActivitySheet(vm)
        DetailDialog.Edit -> TextDialog(stringResource(R.string.edit_post), vm.editCaption, vm::updateEditCaption, null, stringResource(R.string.save), true, vm::saveEdit) { vm.open(null) }
        DetailDialog.Report -> TextDialog(
            stringResource(R.string.report_post), vm.reportText, vm::updateReportText, stringResource(R.string.report_placeholder),
            stringResource(R.string.report_send), vm.reportText.isNotBlank(), vm::submitReport,
        ) { vm.open(null) }
        DetailDialog.DeletePost -> ConfirmDialog(stringResource(R.string.delete_post_title), stringResource(R.string.delete_post_body), vm::deletePost) { vm.open(null) }
        is DetailDialog.DeleteComment -> ConfirmDialog(stringResource(R.string.delete_comment_title), null, { vm.deleteComment(dialog.comment) }) { vm.open(null) }
    }
}

@Composable
private fun SheetButton(icon: ImageVector, label: String, tint: Color, onClick: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().heightIn(min = 54.dp).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 20.dp),
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(19.dp))
        Spacer(Modifier.width(14.dp))
        Text(label, color = tint, fontSize = 15.sp)
    }
}

@Composable
private fun TextDialog(
    title: String, value: String, onChange: (String) -> Unit, placeholder: String?, confirm: String, enabled: Boolean,
    onConfirm: () -> Unit, onCancel: () -> Unit,
) {
    val c = Wyn.colors
    AlertDialog(
        onDismissRequest = onCancel,
        containerColor = c.bg,
        title = { Text(title, color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold) },
        text = { WynTextField(title, value, onChange, placeholder.orEmpty(), singleLine = false, minHeight = 110) },
        confirmButton = { TextButton(onClick = onConfirm, enabled = enabled) { Text(confirm, color = if (enabled) c.text else c.textMuted, fontWeight = FontWeight.Bold) } },
        dismissButton = { TextButton(onClick = onCancel) { Text(stringResource(R.string.cancel), color = c.textSecondary) } },
    )
}

@Composable
private fun ConfirmDialog(title: String, body: String?, onConfirm: () -> Unit, onCancel: () -> Unit) {
    val c = Wyn.colors
    AlertDialog(
        onDismissRequest = onCancel,
        containerColor = c.bg,
        title = { Text(title, color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold) },
        text = body?.let { { Text(it, color = c.textSecondary, fontSize = 14.sp) } },
        confirmButton = { TextButton(onClick = onConfirm) { Text(stringResource(R.string.delete), color = Color(0xFFB42318), fontWeight = FontWeight.Bold) } },
        dismissButton = { TextButton(onClick = onCancel) { Text(stringResource(R.string.cancel), color = c.textSecondary) } },
    )
}

/** web ActivitySheet: who liked and who reposted. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ActivitySheet(vm: PostDetailViewModel) {
    val c = Wyn.colors
    var reposts by remember { mutableStateOf(false) }
    ModalBottomSheet(
        onDismissRequest = { vm.open(null) }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = c.bg, shape = RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp), dragHandle = null,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().height(54.dp).padding(start = 18.dp, end = 8.dp)) {
            Text(stringResource(R.string.post_activity), color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            Box(Modifier.size(44.dp).clickable { vm.open(null) }, contentAlignment = Alignment.Center) {
                Icon(WynIcons.Close, contentDescription = stringResource(R.string.close), tint = c.text, modifier = Modifier.size(20.dp))
            }
        }
        HorizontalDivider(color = c.border, thickness = 1.dp)
        Row(Modifier.fillMaxWidth().height(48.dp)) {
            listOf(false to R.string.like, true to R.string.repost).forEach { (isReposts, label) ->
                val active = reposts == isReposts
                Box(Modifier.weight(1f).fillMaxSize().clickable { reposts = isReposts }, contentAlignment = Alignment.Center) {
                    Text(stringResource(label), color = if (active) c.text else c.textSecondary, fontSize = 13.5.sp, fontWeight = if (active) FontWeight.Bold else FontWeight.Medium)
                    if (active) Box(Modifier.align(Alignment.BottomCenter).size(34.dp, 2.dp).clip(RoundedCornerShape(999.dp)).background(c.text))
                }
            }
        }
        HorizontalDivider(color = c.border, thickness = 1.dp)
        val activity = vm.activity
        val people: List<ActivityPerson>? = activity?.let { if (reposts) it.reposts else it.likes }
        Box(Modifier.fillMaxWidth().heightIn(min = 180.dp, max = 520.dp)) {
            when {
                vm.activityFailed -> Text(stringResource(R.string.activity_load_failed), color = c.textSecondary, modifier = Modifier.align(Alignment.Center))
                people == null -> Text(stringResource(R.string.loading_more), color = c.textSecondary, modifier = Modifier.align(Alignment.Center))
                people.isEmpty() -> Text(
                    stringResource(if (reposts) R.string.no_reposts_yet else R.string.no_likes_yet), color = c.textSecondary,
                    modifier = Modifier.align(Alignment.Center),
                )
                else -> LazyColumn {
                    items(people, key = { it.id }) { person ->
                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().heightIn(min = 64.dp).padding(horizontal = 16.dp, vertical = 10.dp)) {
                            WynAvatar(person.avatarUrl, 42)
                            Spacer(Modifier.width(11.dp))
                            Column {
                                Text(person.label + if (person.verified) " ✓" else "", color = c.text, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                                Text("@${person.username}", color = c.textSecondary, fontSize = 12.sp)
                            }
                        }
                        HorizontalDivider(color = c.border, thickness = 1.dp)
                    }
                }
            }
        }
    }
}
