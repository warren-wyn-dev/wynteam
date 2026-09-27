package io.wyn.wyn.feature.home

import android.content.Intent
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.wyn.wyn.R
import io.wyn.wyn.core.data.FeedRow
import io.wyn.wyn.core.design.DarkWynColors
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.core.design.WynPrimaryButton
import io.wyn.wyn.feature.auth.text
import kotlinx.coroutines.delay

private val HeaderGrey = Color(0xFF737780)
private val TabGrey = Color(0xFF757A84)

/** Actions the Home screen hands to screens that arrive in later milestones. */
data class HomeNavigation(
    val onCompose: () -> Unit = {},
    val onOpenPost: (FeedRow) -> Unit = {},
    val onOpenAuthor: (FeedRow) -> Unit = {},
    val onSearch: () -> Unit = {},
    val onNotifications: () -> Unit = {},
    val onMenu: () -> Unit = {},
    val onQuote: (FeedRow) -> Unit = {},
)

/** web HomeScreen: header, For You / Following / My Clubs, quick compose and the feed. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(vm: HomeViewModel, nav: HomeNavigation, notificationCount: Int = 0) {
    val c = Wyn.colors
    val context = LocalContext.current
    fun share(row: FeedRow) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_SUBJECT, row.authorLabel)
            putExtra(Intent.EXTRA_TEXT, vm.shareUrl(row))
        }
        context.startActivity(Intent.createChooser(send, null))
    }
    Column(Modifier.fillMaxSize().background(c.bg)) {
        HomeHeader(notificationCount, nav)
        HomeTabs(vm.mode, vm::select)
        val snapshot = vm.snapshot
        PullToRefreshBox(isRefreshing = vm.refreshing, onRefresh = vm::refresh, modifier = Modifier.weight(1f)) {
            val listState = rememberLazyListState()
            LazyColumn(state = listState, modifier = Modifier.fillMaxSize()) {
                if (vm.mode != FeedMode.Clubs) {
                    item(key = "compose") { QuickCompose(vm.identity?.avatarUrl, nav.onCompose) }
                }
                when {
                    vm.mode == FeedMode.Clubs -> item(key = "clubs") {
                        EmptyState(stringResource(R.string.clubs_feed_coming), null) {}
                    }
                    snapshot == null && vm.error != null -> item(key = "error") {
                        EmptyState(vm.error.text().orEmpty(), stringResource(R.string.retry)) { vm.load() }
                    }
                    snapshot == null -> item(key = "loading") { FeedSkeleton() }
                    snapshot.rows.isEmpty() -> item(key = "empty") {
                        EmptyState(
                            stringResource(if (vm.mode == FeedMode.Following) R.string.following_empty else R.string.feed_empty),
                            stringResource(R.string.search_people),
                            nav.onSearch,
                        )
                    }
                    else -> {
                        if (vm.error != null) item(key = "stale") { ErrorText(vm.error.text()) }
                        items(snapshot.rows, key = { it.key }) { row ->
                            Column {
                                if (row.key != snapshot.rows.first().key) HorizontalDivider(color = c.border, thickness = 1.dp)
                                PostCard(
                                    row = row,
                                    viewer = snapshot.viewer,
                                    images = snapshot.images[row.id] ?: listOfNotNull(row.imageUrl),
                                    userId = vm.userId,
                                    actions = PostCallbacks(
                                        onLike = { vm.toggleLike(row) },
                                        onPhotoLike = { vm.likeFromPhoto(row) },
                                        onComment = { nav.onOpenPost(row) },
                                        onRepost = { vm.openSheet(PostSheet.Repost(row)) },
                                        onShare = { share(row) },
                                        onSave = { vm.toggleSave(row) },
                                        onFollow = { vm.toggleFollow(row) },
                                        onMore = { vm.openSheet(PostSheet.More(row)) },
                                        onOpenPost = { nav.onOpenPost(row) },
                                        onOpenAuthor = { nav.onOpenAuthor(row) },
                                    ),
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    vm.sheet?.let { PostSheetHost(it, vm, nav, ::share) }
    Snackbars(vm)
}

@Composable
private fun HomeHeader(notificationCount: Int, nav: HomeNavigation) {
    val c = Wyn.colors
    val dark = c.bg == DarkWynColors.bg
    Box(Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 12.dp)) {
        HeaderButton(WynIcons.Menu, stringResource(R.string.menu), nav.onMenu, Modifier.align(Alignment.CenterStart))
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.align(Alignment.Center)) {
            Image(
                painterResource(R.drawable.wynos_logo_mark), contentDescription = null, modifier = Modifier.size(27.dp),
                colorFilter = if (dark) ColorFilter.colorMatrix(Invert) else null,
            )
            Spacer(Modifier.width(7.dp))
            Text("WYNOS", color = c.text, fontSize = 18.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.2.sp)
        }
        Row(Modifier.align(Alignment.CenterEnd)) {
            HeaderButton(WynIcons.Search, stringResource(R.string.search), nav.onSearch)
            Box {
                HeaderButton(WynIcons.Bell, stringResource(R.string.notifications), nav.onNotifications)
                if (notificationCount > 0) {
                    Badge(if (notificationCount > 9) "9+" else notificationCount.toString(), Modifier.offset(22.dp, 3.dp))
                }
            }
        }
    }
}

@Composable
fun Badge(text: String, modifier: Modifier = Modifier) {
    Box(
        modifier
            .heightIn(min = 17.dp)
            .clip(RoundedCornerShape(999.dp))
            .background(Wyn.colors.bg)
            .padding(2.dp)
            .clip(RoundedCornerShape(999.dp))
            .background(Color(0xFFFF453A))
            .padding(horizontal = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold, lineHeight = 13.sp)
    }
}

private val Invert = ColorMatrix(floatArrayOf(-1f, 0f, 0f, 0f, 255f, 0f, -1f, 0f, 0f, 255f, 0f, 0f, -1f, 0f, 255f, 0f, 0f, 0f, 1f, 0f))

@Composable
private fun HeaderButton(icon: ImageVector, label: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).clickable(role = Role.Button, onClickLabel = label, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = HeaderGrey, modifier = Modifier.size(23.dp))
    }
}

@Composable
private fun HomeTabs(mode: FeedMode, onSelect: (FeedMode) -> Unit) {
    val c = Wyn.colors
    val labels = listOf(FeedMode.ForYou to R.string.tab_for_you, FeedMode.Following to R.string.tab_following, FeedMode.Clubs to R.string.tab_my_clubs)
    Column {
        Row(Modifier.fillMaxWidth().height(37.dp)) {
            labels.forEach { (key, label) ->
                val active = key == mode
                Column(
                    Modifier.weight(1f).fillMaxSize().selectable(active, role = Role.Tab) { onSelect(key) }.padding(horizontal = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.SpaceBetween,
                ) {
                    Spacer(Modifier.height(1.dp))
                    Text(
                        stringResource(label), color = if (active) c.text else TabGrey, fontSize = 18.sp,
                        fontWeight = if (active) FontWeight.Bold else FontWeight.SemiBold, maxLines = 1,
                    )
                    Box(
                        Modifier.fillMaxWidth().height(2.dp).clip(RoundedCornerShape(999.dp))
                            .background(if (active) c.text else Color.Transparent),
                    )
                }
            }
        }
        HorizontalDivider(color = c.border, thickness = 1.dp)
    }
}

@Composable
private fun QuickCompose(avatarUrl: String?, onCompose: () -> Unit) {
    val c = Wyn.colors
    val prompt = stringResource(R.string.quick_compose)
    Column {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().height(65.dp).clickable(onClickLabel = prompt, onClick = onCompose).padding(horizontal = 16.dp),
        ) {
            WynAvatar(avatarUrl, 38)
            Spacer(Modifier.width(12.dp))
            Text(prompt, color = c.textSecondary, fontSize = 15.sp, modifier = Modifier.weight(1f))
            Icon(WynIcons.Image, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(22.dp))
        }
        HorizontalDivider(color = c.border, thickness = 1.dp)
    }
}

@Composable
private fun EmptyState(message: String, action: String?, onAction: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(message, color = Wyn.colors.textSecondary, fontSize = 15.sp, textAlign = TextAlign.Center)
        if (action != null) {
            Spacer(Modifier.height(16.dp))
            WynPrimaryButton(action, onAction, modifier = Modifier.width(220.dp))
        }
    }
}

/** The web's FeedSkeleton: grey placeholders in the shape of posts. */
@Composable
private fun FeedSkeleton() {
    val shade = Wyn.colors.surface
    Column(Modifier.semantics { contentDescription = "loading" }) {
        repeat(3) {
            Row(Modifier.padding(16.dp)) {
                Box(Modifier.size(40.dp).clip(RoundedCornerShape(999.dp)).background(shade))
                Spacer(Modifier.width(10.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Box(Modifier.width(120.dp).height(14.dp).clip(RoundedCornerShape(6.dp)).background(shade))
                    Box(Modifier.fillMaxWidth().height(14.dp).clip(RoundedCornerShape(6.dp)).background(shade))
                    Box(Modifier.fillMaxWidth(0.7f).height(14.dp).clip(RoundedCornerShape(6.dp)).background(shade))
                }
            }
        }
    }
}

// ---- Sheets --------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PostSheetHost(sheet: PostSheet, vm: HomeViewModel, nav: HomeNavigation, share: (FeedRow) -> Unit) {
    val c = Wyn.colors
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = { vm.openSheet(null) },
        sheetState = state,
        containerColor = c.bg,
        shape = RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp),
        dragHandle = { Box(Modifier.padding(top = 10.dp, bottom = 8.dp).size(38.dp, 4.dp).clip(RoundedCornerShape(999.dp)).background(c.border)) },
    ) {
        val row = sheet.row
        val viewer = vm.snapshot?.viewer
        when (sheet) {
            is PostSheet.More -> Column(Modifier.padding(bottom = 10.dp)) {
                SheetRow(WynIcons.Share, stringResource(R.string.share), first = true) { share(row); vm.openSheet(null) }
                val saved = viewer?.saved?.contains(row.id) == true
                SheetRow(if (saved) WynIcons.SaveFilled else WynIcons.Save, stringResource(if (saved) R.string.unsave_long else R.string.save)) {
                    vm.toggleSave(row); vm.openSheet(null)
                }
                if (row.authorId != vm.userId) {
                    SheetRow(WynIcons.Close, stringResource(R.string.not_interested)) { vm.hide(row) }
                    SheetRow(WynIcons.Flag, stringResource(R.string.report_post)) { vm.openSheet(PostSheet.Report(row)) }
                }
                if (row.redropId != null && row.redropperUsername != null && row.redropperUsername == vm.identity?.username) {
                    SheetRow(WynIcons.RepostSmall, stringResource(R.string.remove_repost)) { vm.removeMyRepost(row) }
                }
            }
            is PostSheet.Repost -> Column(Modifier.padding(start = 18.dp, end = 18.dp, bottom = 16.dp)) {
                val reposted = viewer?.redropped?.contains(row.id) == true
                RepostChoice(WynIcons.Repost, stringResource(if (reposted) R.string.undo_repost else R.string.repost), !vm.busy) { vm.toggleRepost(row) }
                RepostChoice(WynIcons.Pencil, stringResource(R.string.quote), !vm.busy) { vm.openSheet(null); nav.onQuote(row) }
            }
            is PostSheet.Report -> ReportForm(vm)
        }
    }
}

@Composable
private fun SheetRow(icon: ImageVector, label: String, first: Boolean = false, onClick: () -> Unit) {
    val c = Wyn.colors
    Column {
        if (!first) HorizontalDivider(color = c.border, thickness = 1.dp)
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().heightIn(min = 54.dp).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 20.dp),
        ) {
            Icon(icon, contentDescription = null, tint = c.text, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(14.dp))
            Text(label, color = c.text, fontSize = 15.sp)
        }
    }
}

@Composable
private fun RepostChoice(icon: ImageVector, label: String, enabled: Boolean, onClick: () -> Unit) {
    val c = Wyn.colors
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 61.dp)
            .clip(RoundedCornerShape(14.dp))
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
    ) {
        Icon(icon, contentDescription = null, tint = c.text.copy(alpha = if (enabled) 1f else 0.55f), modifier = Modifier.size(28.dp))
        Spacer(Modifier.width(18.dp))
        Text(label, color = c.text.copy(alpha = if (enabled) 1f else 0.55f), fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun ReportForm(vm: HomeViewModel) {
    val c = Wyn.colors
    val labels = mapOf(
        "spam" to R.string.report_spam, "scam" to R.string.report_scam, "harassment" to R.string.report_harassment,
        "hate" to R.string.report_hate, "sexual_content" to R.string.report_sexual, "violence" to R.string.report_violence,
        "privacy" to R.string.report_privacy, "illegal_content" to R.string.report_illegal, "copyright" to R.string.report_copyright,
        "other" to R.string.report_other,
    )
    Column(Modifier.padding(start = 18.dp, end = 18.dp, bottom = 14.dp, top = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(stringResource(R.string.report_post), color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
        Column(Modifier.border(1.dp, c.border, RoundedCornerShape(14.dp)).clip(RoundedCornerShape(14.dp))) {
            ReportCategories.forEachIndexed { index, key ->
                if (index > 0) HorizontalDivider(color = c.border, thickness = 1.dp)
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 46.dp)
                        .selectable(vm.reportCategory == key, role = Role.RadioButton) { vm.chooseReportCategory(key) }
                        .padding(horizontal = 4.dp),
                ) {
                    RadioButton(
                        selected = vm.reportCategory == key, onClick = null,
                        colors = RadioButtonDefaults.colors(selectedColor = c.link), modifier = Modifier.padding(horizontal = 8.dp),
                    )
                    Text(stringResource(labels.getValue(key)), color = c.text, fontSize = 14.sp)
                }
            }
        }
        if (vm.reportCategory == "other") {
            io.wyn.wyn.core.design.WynTextField(
                stringResource(R.string.report_detail), vm.reportDetail, vm::updateReportDetail, stringResource(R.string.report_detail),
                singleLine = false, minHeight = 96,
            )
        }
        ErrorText(vm.reportError.text())
        WynPrimaryButton(stringResource(R.string.report_send), vm::submitReport, enabled = !vm.busy)
    }
}

/** The web's Toast and the "not interested" undo bar. */
@Composable
private fun Snackbars(vm: HomeViewModel) {
    val toast = vm.toast
    val hidden = vm.hidden
    LaunchedEffect(toast) {
        if (toast != null) {
            delay(4000)
            vm.dismissToast()
        }
    }
    LaunchedEffect(hidden) {
        if (hidden != null) {
            delay(6000)
            vm.dismissHidden()
        }
    }
    Box(Modifier.fillMaxSize().padding(bottom = 14.dp, start = 14.dp, end = 14.dp), contentAlignment = Alignment.BottomCenter) {
        when {
            hidden != null -> SnackBar(stringResource(R.string.not_interested_done), stringResource(R.string.undo), vm::undoHide)
            toast != null -> SnackBar(toast.text.text().orEmpty(), toast.actionLabel.text(), toast.action)
        }
    }
}

@Composable
fun SnackBar(message: String, action: String?, onAction: (() -> Unit)?) {
    val c = Wyn.colors
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).clip(RoundedCornerShape(14.dp)).background(c.text).padding(start = 16.dp, end = 6.dp, top = 8.dp, bottom = 8.dp),
    ) {
        Text(message, color = c.bg, fontSize = 13.sp, modifier = Modifier.weight(1f))
        if (action != null && onAction != null) {
            Text(
                action, color = c.bg, fontSize = 13.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickable(onClick = onAction).padding(horizontal = 10.dp, vertical = 8.dp),
            )
        }
    }
}
