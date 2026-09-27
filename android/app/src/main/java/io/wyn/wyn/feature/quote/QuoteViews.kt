package io.wyn.wyn.feature.quote

import androidx.activity.compose.BackHandler
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import io.wyn.wyn.R
import io.wyn.wyn.core.data.FeedRow
import io.wyn.wyn.core.data.QuoteEngagement
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.core.design.WynTextField
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.home.FeedText
import io.wyn.wyn.feature.home.RichText
import io.wyn.wyn.feature.home.rememberEnglish

private val LinkBlue = Color(0xFF1D9BF0)
private val ActionGrey = Color(0xFF8B919B)
private val LikeRed = Color(0xFFFF3B30)
private val MetaGrey = Color(0xFF78787D)
private val DangerRed = Color(0xFFB42318)

/** web QuoteFeedCard: the Quote author's words above a framed preview of the quoted post. */
@Composable
fun QuoteCard(
    row: FeedRow,
    engagement: QuoteEngagement?,
    loadFailed: Boolean,
    images: List<String>,
    onRetry: () -> Unit,
    onLike: () -> Unit,
    onComment: () -> Unit,
    onRepost: () -> Unit,
    onShare: () -> Unit,
    onSave: () -> Unit,
    onMore: () -> Unit,
    onOpenOriginal: () -> Unit,
    onOpenAuthor: (String) -> Unit,
) {
    val c = Wyn.colors
    val english = rememberEnglish()
    Row(Modifier.fillMaxWidth().background(c.bg).padding(start = 16.dp, end = 16.dp, top = 8.dp)) {
        WynAvatar(
            row.redropperAvatarUrl, 40,
            modifier = Modifier.padding(top = 1.dp).clickable { row.redropperId?.let(onOpenAuthor) },
            contentDescription = row.quoteAuthorLabel,
        )
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            if (row.quoteReposterId != null) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(bottom = 2.dp)) {
                    Icon(WynIcons.RepostSmall, contentDescription = null, tint = Color(0xFF737378), modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(5.dp))
                    Text(
                        stringResource(R.string.reposted_by, row.quoteReposterUsername ?: "WYNOS", row.quoteRepostedAt?.let { FeedText.relativeTime(it, english) }.orEmpty()),
                        color = Color(0xFF737378), fontSize = 14.sp, fontWeight = FontWeight.Medium, maxLines = 1,
                    )
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.heightIn(min = 26.dp)) {
                Row(Modifier.weight(1f).clickable { row.redropperId?.let(onOpenAuthor) }, verticalAlignment = Alignment.CenterVertically) {
                    Text(row.quoteAuthorLabel, color = c.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                    if (row.redropperIsVerified) Text(" ✓", color = LinkBlue, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    Text(" · ${FeedText.relativeTime(row.createdAt, english)}", color = MetaGrey, fontSize = 14.sp, maxLines = 1)
                }
                val options = stringResource(R.string.quote_options)
                Box(Modifier.size(28.dp, 26.dp).clickable(role = Role.Button, onClick = onMore).semantics { contentDescription = options }, contentAlignment = Alignment.Center) {
                    Icon(WynIcons.More, contentDescription = null, tint = Color(0xFF73767E), modifier = Modifier.size(20.dp))
                }
            }
            RichText(row.quoteText.orEmpty(), compact = false, onTag = {}, modifier = Modifier.padding(top = 3.dp, bottom = 10.dp))
            OriginalPreview(row, images, onOpenOriginal)
            if (engagement != null) {
                QuoteActions(engagement, onLike, onComment, onRepost, onShare, onSave)
            } else {
                Text(
                    stringResource(if (loadFailed) R.string.quote_activity_retry else R.string.quote_activity_loading),
                    color = c.textSecondary, fontSize = 13.sp,
                    modifier = Modifier.heightIn(min = 44.dp).padding(vertical = 12.dp).clickable(enabled = loadFailed, onClick = onRetry),
                )
            }
        }
    }
}

@Composable
private fun OriginalPreview(row: FeedRow, images: List<String>, onOpen: () -> Unit) {
    val c = Wyn.colors
    val label = stringResource(R.string.quote_view_original, row.authorLabel)
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(15.dp)).border(1.dp, c.border, RoundedCornerShape(15.dp)).background(c.bg)
            .clickable(onClickLabel = label, onClick = onOpen),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(start = 12.dp, end = 12.dp, top = 10.dp, bottom = 4.dp)) {
            WynAvatar(row.authorAvatarUrl, 30)
            Spacer(Modifier.width(9.dp))
            Text(row.authorLabel, color = c.text, fontSize = 13.5.sp, fontWeight = FontWeight.Bold, maxLines = 1)
            if (row.authorIsVerified) Text(" ✓", color = LinkBlue, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            row.authorUsername?.let { Text(" @$it", color = Color(0xFF7C7E85), fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis) }
        }
        row.caption?.takeIf { it.isNotBlank() }?.let { caption ->
            Text(
                buildAnnotatedString {
                    var last = 0
                    Regex("#[\\p{L}\\p{N}_]+").findAll(caption).forEach { m ->
                        append(caption.substring(last, m.range.first))
                        withStyle(SpanStyle(color = LinkBlue)) { append(m.value) }
                        last = m.range.last + 1
                    }
                    append(caption.substring(last))
                },
                color = c.text, fontSize = 14.sp, lineHeight = 19.sp,
                modifier = Modifier.padding(start = 12.dp, end = 12.dp, top = 2.dp, bottom = 11.dp),
            )
        }
        images.firstOrNull()?.let { url ->
            Box(Modifier.fillMaxWidth().aspectRatio(row.mediaAspectRatio(images.size > 1))) {
                AsyncImage(url, stringResource(R.string.quote_original_image), contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize().background(c.surface))
                if (images.size > 1) {
                    Text(
                        "1/${images.size}", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.align(Alignment.TopEnd).padding(8.dp).clip(RoundedCornerShape(999.dp)).background(Color(0x99000000)).padding(horizontal = 8.dp, vertical = 2.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun QuoteActions(e: QuoteEngagement, onLike: () -> Unit, onComment: () -> Unit, onRepost: () -> Unit, onShare: () -> Unit, onSave: () -> Unit) {
    val c = Wyn.colors
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(18.dp),
        modifier = Modifier.fillMaxWidth().heightIn(min = 44.dp).padding(top = 4.dp, bottom = 6.dp),
    ) {
        Action(if (e.liked) WynIcons.HeartFilled else WynIcons.Heart, e.likeCount, if (e.liked) LikeRed else ActionGrey, stringResource(if (e.liked) R.string.unlike else R.string.like), onLike)
        Action(WynIcons.Comment, e.commentCount, ActionGrey, stringResource(R.string.comments), onComment, 24)
        Action(WynIcons.Repost, e.repostCount, if (e.reposted) c.text else ActionGrey, stringResource(R.string.repost), onRepost)
        Action(WynIcons.Share, 0, ActionGrey, stringResource(R.string.share), onShare)
        Spacer(Modifier.weight(1f))
        Action(if (e.saved) WynIcons.SaveFilled else WynIcons.Save, 0, if (e.saved) c.text else ActionGrey, stringResource(if (e.saved) R.string.unsave else R.string.save), onSave)
    }
}

@Composable
private fun Action(icon: ImageVector, count: Int, tint: Color, label: String, onClick: () -> Unit, size: Int = 22) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.heightIn(min = 34.dp).clickable(role = Role.Button, onClick = onClick).semantics { contentDescription = label },
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(size.dp))
        if (count > 0) {
            Spacer(Modifier.width(5.dp))
            Text(count.toString(), color = tint, fontSize = 13.sp, fontWeight = FontWeight.Medium)
        }
    }
}

// ---- Sheets --------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuoteSheets(controller: QuoteController, userId: String, onDeleted: (FeedRow) -> Unit) {
    val sheet = controller.sheet ?: return
    val c = Wyn.colors
    ModalBottomSheet(
        onDismissRequest = { if (!controller.busy) controller.open(null) },
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = c.bg, shape = RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp),
        dragHandle = { Box(Modifier.padding(top = 10.dp, bottom = 8.dp).size(38.dp, 4.dp).clip(RoundedCornerShape(999.dp)).background(c.border)) },
    ) {
        Column(Modifier.padding(start = 18.dp, end = 18.dp, bottom = 16.dp)) {
            val row = sheet.row
            val own = row.redropperId == userId
            when (sheet) {
                is QuoteSheet.Menu -> if (own) {
                    SheetRow(WynIcons.Trash, stringResource(R.string.quote_delete), DangerRed) { controller.open(QuoteSheet.ConfirmDelete(row)) }
                    Text(stringResource(R.string.quote_delete_hint), color = c.textSecondary, fontSize = 13.sp, modifier = Modifier.padding(horizontal = 4.dp, vertical = 6.dp))
                } else {
                    SheetRow(WynIcons.Flag, stringResource(R.string.quote_report), c.text) { controller.open(QuoteSheet.Report(row)) }
                }
                is QuoteSheet.ConfirmDelete -> {
                    Text(stringResource(R.string.quote_delete_title), color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                    Text(stringResource(R.string.quote_delete_hint), color = c.textSecondary, fontSize = 14.sp, modifier = Modifier.padding(top = 6.dp, bottom = 12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        SheetButton(stringResource(R.string.back), c.text, !controller.busy, Modifier.weight(1f)) { controller.open(QuoteSheet.Menu(row)) }
                        SheetButton(stringResource(R.string.quote_delete_confirm), DangerRed, !controller.busy, Modifier.weight(1f)) { controller.delete(onDeleted) }
                    }
                }
                is QuoteSheet.Report -> {
                    Text(stringResource(R.string.quote_report), color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp))
                    val labels = mapOf("spam" to R.string.quote_reason_spam, "scam" to R.string.quote_reason_scam, "harassment" to R.string.quote_reason_harassment, "other" to R.string.quote_reason_other)
                    QuoteReportReasons.forEach { key ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth().heightIn(min = 46.dp).selectable(controller.reportReason == key, role = Role.RadioButton) { controller.chooseReason(key) },
                        ) {
                            RadioButton(controller.reportReason == key, onClick = null, colors = RadioButtonDefaults.colors(selectedColor = c.link), modifier = Modifier.padding(end = 8.dp))
                            Text(stringResource(labels.getValue(key)), color = c.text, fontSize = 14.sp)
                        }
                    }
                    if (controller.reportReason == "other") {
                        WynTextField(stringResource(R.string.report_detail), controller.reportDetail, controller::updateReportDetail, stringResource(R.string.report_detail), singleLine = false, minHeight = 96)
                    }
                    SheetButton(stringResource(R.string.report_send), c.bg, !controller.busy, Modifier.fillMaxWidth().padding(top = 8.dp), filled = true, onClick = controller::submitReport)
                }
                is QuoteSheet.Repost -> {
                    val reposted = controller.engagement[row.redropId]?.reposted == true
                    Choice(WynIcons.Repost, stringResource(if (reposted) R.string.undo_repost else R.string.repost), !controller.busy) { controller.toggleRepost(row) }
                    if (row.canRedrop) {
                        Choice(WynIcons.Pencil, stringResource(R.string.quote_original), !controller.busy) { controller.startQuote(row) }
                    }
                }
            }
            ErrorText(controller.error.text())
            if (sheet !is QuoteSheet.ConfirmDelete) {
                Text(
                    stringResource(R.string.cancel), color = c.textSecondary, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp).clickable(enabled = !controller.busy) { controller.open(null) }.padding(12.dp),
                )
            }
        }
    }
}

@Composable
private fun SheetRow(icon: ImageVector, label: String, tint: Color, onClick: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().heightIn(min = 54.dp).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 4.dp),
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(21.dp))
        Spacer(Modifier.width(14.dp))
        Text(label, color = tint, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun SheetButton(label: String, color: Color, enabled: Boolean, modifier: Modifier, filled: Boolean = false, onClick: () -> Unit) {
    val c = Wyn.colors
    Box(
        modifier.heightIn(min = 46.dp).clip(RoundedCornerShape(12.dp))
            .then(if (filled) Modifier.background(c.text) else Modifier.border(1.dp, c.border, RoundedCornerShape(12.dp)))
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Text(label, color = color, fontSize = 15.sp, fontWeight = FontWeight.Bold) }
}

@Composable
private fun Choice(icon: ImageVector, label: String, enabled: Boolean, onClick: () -> Unit) {
    val c = Wyn.colors
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().heightIn(min = 61.dp).clip(RoundedCornerShape(14.dp)).clickable(enabled = enabled, role = Role.Button, onClick = onClick).padding(horizontal = 14.dp, vertical = 10.dp),
    ) {
        Icon(icon, contentDescription = null, tint = c.text, modifier = Modifier.size(28.dp))
        Spacer(Modifier.width(18.dp))
        Text(label, color = c.text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
    }
}

// ---- Quote composer (web quote-redrop-composer.tsx) -------------------------------------

@Composable
fun QuoteComposer(controller: QuoteController, avatarUrl: String?, name: String, onPublished: () -> Unit) {
    val row = controller.quoting ?: return
    val c = Wyn.colors
    val english = rememberEnglish()
    BackHandler { if (controller.quoteDiscardPrompt) controller.keepQuoting() else controller.requestCloseQuote() }
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding().imePadding()) {
        Box(Modifier.fillMaxWidth().height(70.dp).padding(horizontal = 16.dp)) {
            Text(
                stringResource(R.string.cancel), color = c.text, fontSize = 15.5.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.align(Alignment.CenterStart).clickable(enabled = !controller.busy) { controller.requestCloseQuote() }.padding(vertical = 14.dp),
            )
            Text(stringResource(R.string.quote), color = c.text, fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.align(Alignment.Center))
            val enabled = !controller.busy && controller.quoteText.isNotBlank()
            Box(
                Modifier.align(Alignment.CenterEnd).widthIn(min = 72.dp).height(42.dp).clip(RoundedCornerShape(999.dp))
                    .background(if (enabled) c.text else c.border).clickable(enabled = enabled, role = Role.Button) { controller.submitQuote(onPublished) }
                    .padding(horizontal = 18.dp),
                contentAlignment = Alignment.Center,
            ) {
                if (controller.busy) CircularProgressIndicator(color = c.bg, strokeWidth = 2.dp, modifier = Modifier.size(16.dp))
                else Text(stringResource(R.string.publish), color = if (enabled) c.bg else c.textMuted, fontSize = 15.sp, fontWeight = FontWeight.Bold)
            }
        }
        HorizontalDivider(color = c.border, thickness = 1.dp)
        controller.error?.let { Box(Modifier.padding(horizontal = 16.dp)) { ErrorText(it.text()) } }
        Row(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp)) {
            WynAvatar(avatarUrl, 44)
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text(name, color = c.text, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                val focus = remember { FocusRequester() }
                LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
                val placeholder = stringResource(R.string.quote_placeholder)
                BasicTextField(
                    value = controller.quoteText, onValueChange = controller::updateQuoteText, enabled = !controller.busy,
                    textStyle = TextStyle(color = c.text, fontSize = 16.sp, lineHeight = 22.sp), cursorBrush = SolidColor(c.text),
                    modifier = Modifier.fillMaxWidth().padding(top = 4.dp, bottom = 12.dp).heightIn(min = 44.dp, max = 220.dp).focusRequester(focus)
                        .semantics { contentDescription = placeholder },
                    decorationBox = { inner -> Box { if (controller.quoteText.isEmpty()) Text(placeholder, color = c.textMuted, fontSize = 16.sp); inner() } },
                )
                Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(15.dp)).border(1.dp, c.border, RoundedCornerShape(15.dp)).padding(12.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        WynAvatar(row.authorAvatarUrl, 32)
                        Spacer(Modifier.width(9.dp))
                        Column {
                            Text(row.authorLabel + if (row.authorIsVerified) " ✓" else "", color = c.text, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                            Text("@${row.authorUsername ?: "wynos"} · ${FeedText.relativeTime(row.createdAt, english)}", color = c.textMuted, fontSize = 12.sp)
                        }
                    }
                    row.caption?.takeIf { it.isNotBlank() }?.let { Text(it, color = c.text, fontSize = 14.sp, lineHeight = 20.sp, modifier = Modifier.padding(top = 8.dp)) }
                    row.imageUrl?.let { url ->
                        AsyncImage(url, stringResource(R.string.quote_original_image), contentScale = ContentScale.Crop,
                            modifier = Modifier.padding(top = 8.dp).fillMaxWidth().aspectRatio(16f / 9f).clip(RoundedCornerShape(12.dp)).background(c.surface))
                    }
                }
                if (controller.quoteText.length > 400) {
                    Text((500 - controller.quoteText.length).toString(), color = c.textMuted, fontSize = 13.sp, modifier = Modifier.padding(top = 8.dp))
                }
            }
        }
    }
    if (controller.quoteDiscardPrompt) {
        AlertDialog(
            onDismissRequest = controller::keepQuoting,
            containerColor = c.bg,
            title = { Text(stringResource(R.string.quote_discard_title), color = c.text, fontWeight = FontWeight.Bold) },
            confirmButton = { TextButton(onClick = controller::discardQuote) { Text(stringResource(R.string.discard), color = DangerRed, fontWeight = FontWeight.Bold) } },
            dismissButton = { TextButton(onClick = controller::keepQuoting) { Text(stringResource(R.string.cancel), color = c.textSecondary) } },
        )
    }
}
