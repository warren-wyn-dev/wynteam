package io.wyn.wyn.feature.profile

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import io.wyn.wyn.R
import io.wyn.wyn.core.data.ExternalUrl
import io.wyn.wyn.core.data.FollowKind
import io.wyn.wyn.core.data.Person
import io.wyn.wyn.core.data.ProfileSummary
import io.wyn.wyn.core.data.ProfileTab
import io.wyn.wyn.core.design.DarkWynColors
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.VerifiedBadge
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.home.EmptyState
import io.wyn.wyn.feature.home.FeedOverlays
import io.wyn.wyn.feature.home.FeedSkeleton
import io.wyn.wyn.feature.home.HomeNavigation
import io.wyn.wyn.feature.home.RichText
import io.wyn.wyn.feature.home.feedRows
import io.wyn.wyn.feature.home.sharePost
import java.text.NumberFormat
import java.util.Locale

private val HandleGrey = Color(0xFF697081)
private val StatGrey = Color(0xFF6F7480)
private val TabGrey = Color(0xFF72798A)
private val WebsiteBlue = Color(0xFF1677E7)
private val OwnActionBorder = Color(0xFFD4DBE7)
private val TabLine = Color(0xFFE3E6ED)

/** Where Profile can go; screens from later milestones are wired by the app. */
data class ProfileNavigation(
    val feed: HomeNavigation = HomeNavigation(),
    val onBack: (() -> Unit)? = null,
    val onEdit: () -> Unit = {},
    val onFollows: (FollowKind) -> Unit = {},
    val onMessage: () -> Unit = {},
    val onSettings: () -> Unit = {},
    val onTag: (String) -> Unit = {},
)

/** web followButtonLabel(). */
@Composable
fun followLabel(busy: Boolean, following: Boolean, requested: Boolean): String = stringResource(
    when {
        busy -> R.string.follow_busy
        following -> R.string.following_label
        requested -> R.string.follow_requested
        else -> R.string.follow
    },
)

private fun count(value: Int): String = NumberFormat.getIntegerInstance(Locale.forLanguageTag("th-TH")).format(value)

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun ProfileScreen(vm: ProfileViewModel, nav: ProfileNavigation, accounts: AccountSwitcher? = null) {
    val c = Wyn.colors
    val context = LocalContext.current
    val summary = vm.summary
    fun shareProfile() {
        val url = vm.profileUrl() ?: return
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_SUBJECT, summary?.profile?.label)
            putExtra(Intent.EXTRA_TEXT, url)
        }
        context.startActivity(Intent.createChooser(send, null))
    }
    Box(Modifier.fillMaxSize().background(c.bg)) {
        when {
            summary == null && vm.summaryLoading -> Column {
                ProfileTopBar(nav.onBack, onMore = null)
                FeedSkeleton()
            }
            summary == null -> Column {
                ProfileTopBar(nav.onBack, onMore = null)
                EmptyState(stringResource(if (vm.summaryFailed) R.string.profile_not_found else R.string.profile_load_failed), stringResource(R.string.retry)) {
                    vm.reloadSummary()
                }
            }
            else -> PullToRefreshBox(isRefreshing = vm.refreshing, onRefresh = vm::refreshAll, modifier = Modifier.fillMaxSize()) {
                LazyColumn(Modifier.fillMaxSize()) {
                    item(key = "hero") {
                        Hero(summary, vm.own, nav.onBack, onMore = { vm.openProfileSheet(ProfileSheet.Menu) })
                    }
                    item(key = "header") { Header(vm, summary, nav, ::shareProfile) }
                    if (!vm.own && !summary.blockedBy && vm.suggestions.isNotEmpty()) {
                        item(key = "suggestions") { Suggestions(vm, nav.feed.onOpenProfile) }
                    }
                    if (!summary.blockedBy) {
                        stickyHeader(key = "tabs") { ProfileTabs(vm.mode, vm::select) }
                        val snapshot = vm.snapshot
                        when {
                            vm.mode == ProfileTab.Likes && !vm.likesAllowed -> item(key = "likes-hidden") {
                                EmptyState(stringResource(R.string.profile_likes_hidden), null) {}
                            }
                            snapshot == null && vm.error != null -> item(key = "error") {
                                EmptyState(vm.error.text().orEmpty(), stringResource(R.string.retry)) { vm.load() }
                            }
                            snapshot == null -> item(key = "loading") { FeedSkeleton() }
                            snapshot.rows.isEmpty() -> item(key = "empty") {
                                EmptyState(
                                    stringResource(
                                        when (vm.mode) {
                                            ProfileTab.Posts -> R.string.profile_no_posts
                                            ProfileTab.Reposts -> R.string.profile_no_reposts
                                            ProfileTab.Likes -> R.string.profile_no_likes
                                        },
                                    ),
                                    null,
                                ) {}
                            }
                            else -> {
                                feedRows(vm, snapshot, nav.feed) { row -> sharePost(context, vm, row) }
                                if (snapshot.hasMore) item(key = "more") { MoreButton(vm.loadingMore, vm::loadMore) }
                            }
                        }
                    }
                    item(key = "end") { Spacer(Modifier.height(24.dp)) }
                }
            }
        }
        FeedOverlays(vm, nav.feed, { row -> sharePost(context, vm, row) }, summary?.profile?.avatarUrl.takeIf { vm.own }, summary?.profile?.label.takeIf { vm.own })
        ProfileSheets(vm, accounts, onShare = ::shareProfile, onSettings = nav.onSettings)
        ProfileConfirmDialog(vm)
    }
}

// ---- Hero: cover and top bar ------------------------------------------------------

@Composable
private fun ProfileTopBar(onBack: (() -> Unit)?, onMore: (() -> Unit)?, own: Boolean = false) {
    Row(
        Modifier.fillMaxWidth().statusBarsPadding().height(58.dp).padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        if (onBack != null) TopButton(WynIcons.Back, stringResource(R.string.back), 25, onBack) else Spacer(Modifier.size(42.dp))
        if (onMore != null) TopButton(WynIcons.More, stringResource(if (own) R.string.profile_my_options else R.string.profile_more), 26, onMore)
    }
}

@Composable
private fun TopButton(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, size: Int, onClick: () -> Unit) {
    Box(
        Modifier.size(42.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.44f)).clickable(role = Role.Button, onClickLabel = label, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = label, tint = Color.White, modifier = Modifier.size(size.dp))
    }
}

@Composable
private fun Hero(summary: ProfileSummary, own: Boolean, onBack: (() -> Unit)?, onMore: () -> Unit) {
    val cover = summary.profile.coverUrl?.let(ExternalUrl::normalize)
    // The cover runs under the status bar; its 156dp start below it (none inside the tab shell).
    Box(Modifier.fillMaxWidth().clipToBounds()) {
        Box(Modifier.matchParentSize()) {
            if (cover != null) {
                AsyncImage(cover, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize().background(Color(0xFF111111)))
            } else {
                DefaultCover()
            }
        }
        Spacer(Modifier.statusBarsPadding().height(156.dp))
        ProfileTopBar(onBack, onMore, own)
    }
}

/** The web's default cover: a dark sky, a planet's lit edge and the WYNOS wordmark. */
@Composable
private fun DefaultCover() {
    val density = LocalDensity.current
    Box(Modifier.fillMaxSize().clipToBounds()) {
        Canvas(Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height
            drawRect(
                Brush.radialGradient(
                    0f to Color(0xFF54565B), 0.23f to Color(0xFF202124), 0.45f to Color(0xFF0C0D0F), 0.70f to Color(0xFF050505),
                    center = Offset(w * 0.59f, h * 1.1f), radius = maxOf(w, h),
                ),
            )
            // .wyn-profile-cover-planet: 125% wide, left -43%, top -145% of the cover.
            val d = w * 1.25f
            val left = -0.43f * w
            val top = -1.45f * h
            val r = d / 2
            val center = Offset(left + r, top + r)
            drawIntoCanvas { canvas ->
                val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.BLACK }
                with(density) {
                    paint.setShadowLayer(36.dp.toPx() / 2, 34.dp.toPx(), 14.dp.toPx(), Color.White.copy(alpha = 0.22f).toArgb())
                    canvas.nativeCanvas.drawCircle(center.x, center.y, r, paint)
                    paint.setShadowLayer(16.dp.toPx() / 2, 12.dp.toPx(), 10.dp.toPx(), Color.White.copy(alpha = 0.72f).toArgb())
                    canvas.nativeCanvas.drawCircle(center.x, center.y, r, paint)
                }
            }
            drawCircle(
                Brush.radialGradient(
                    0f to Color(0xFF36373A), 0.54f to Color(0xFF161719), 0.75f to Color(0xFF060606),
                    center = Offset(left + d * 0.62f, top + d * 0.70f), radius = d * 0.75f,
                ),
                radius = r, center = center,
            )
        }
        Column(
            Modifier.align(Alignment.TopEnd).padding(end = 29.dp, top = 83.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(9.dp),
        ) {
            Text("W Y N O S", color = Color.White, fontSize = 14.sp, letterSpacing = 3.sp)
            Text(
                "A BETTER\nTOMORROW TOGETHER", color = Color.White, fontSize = 6.sp, lineHeight = 13.sp,
                letterSpacing = 3.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center,
            )
        }
    }
}

// ---- Header ------------------------------------------------------------------------

@Composable
private fun Header(vm: ProfileViewModel, summary: ProfileSummary, nav: ProfileNavigation, onShare: () -> Unit) {
    val c = Wyn.colors
    val context = LocalContext.current
    val profile = summary.profile
    Column(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, bottom = 4.dp)) {
        Row(Modifier.heightIn(min = 62.dp), horizontalArrangement = Arrangement.spacedBy(11.dp)) {
            Box(
                Modifier
                    .layout { measurable, constraints ->
                        val lift = 34.dp.roundToPx()
                        val placeable = measurable.measure(constraints)
                        layout(placeable.width, placeable.height - lift) { placeable.place(0, -lift) }
                    }
                    .size(96.dp).clip(CircleShape).background(c.bg).padding(3.dp),
            ) {
                WynAvatar(profile.avatarUrl, 90, contentDescription = stringResource(R.string.profile_photo_of, profile.username))
            }
            Column(Modifier.weight(1f).padding(top = 15.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        profile.label, color = c.text, fontSize = 17.sp, lineHeight = 21.sp, fontWeight = FontWeight.ExtraBold,
                        maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false),
                    )
                    if (profile.isVerified) VerifiedBadge(16, label = stringResource(R.string.verified))
                }
                Text(
                    "@${profile.username}", color = HandleGrey, fontSize = 14.sp, lineHeight = 18.sp,
                    maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = 3.dp),
                )
            }
            if (vm.own) {
                Row(Modifier.padding(top = 16.dp), horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                    RoundAction(WynIcons.Pencil, stringResource(R.string.profile_edit), 21, nav.onEdit)
                    RoundAction(WynIcons.Share, stringResource(R.string.profile_share), 22, onShare)
                }
            }
        }
        Column(Modifier.padding(top = 10.dp)) {
            profile.bio?.takeIf { it.isNotBlank() }?.let { bio ->
                RichText(bio, compact = false, onTag = nav.onTag, style = TextStyle(fontSize = 16.sp, lineHeight = 22.sp))
            }
            profile.website?.let(ExternalUrl::normalize)?.let { site ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(top = 8.dp).clip(RoundedCornerShape(6.dp)).clickable(role = Role.Button) {
                        runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(site))) }
                    },
                ) {
                    Icon(WynIcons.Link, contentDescription = null, tint = WebsiteBlue, modifier = Modifier.size(19.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(ExternalUrl.label(site), color = WebsiteBlue, fontSize = 15.sp, fontWeight = FontWeight.Medium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            if (!summary.blockedBy) {
                Row(Modifier.padding(top = 11.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    Stat(summary.followingCount, stringResource(R.string.tab_following)) { nav.onFollows(FollowKind.Following) }
                    Stat(summary.followerCount, stringResource(R.string.profile_followers)) { nav.onFollows(FollowKind.Followers) }
                }
            }
        }
        if (!vm.own && !summary.blocked && !summary.blockedBy) {
            Row(Modifier.padding(top = 14.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                val soft = summary.following || summary.requested
                PillButton(followLabel(vm.action, summary.following, summary.requested), filled = !soft, enabled = !vm.action, modifier = Modifier.weight(1f)) { vm.follow() }
                PillButton(stringResource(R.string.profile_message), filled = false, outlined = true, enabled = !vm.action, icon = WynIcons.Send, modifier = Modifier.weight(1f), onClick = nav.onMessage)
            }
        }
        if (!vm.own && summary.blocked) {
            Row(Modifier.padding(top = 14.dp)) {
                PillButton(stringResource(R.string.profile_unblock), filled = false, enabled = !vm.action, modifier = Modifier.weight(1f)) { vm.block() }
            }
        }
        if (summary.blockedBy) Notice(stringResource(R.string.profile_blocked_by))
        if (!summary.blockedBy && profile.isPrivate && !vm.own && !summary.following) Notice(stringResource(R.string.profile_private_notice, profile.label))
        vm.actionError?.let { ErrorText(it.text()) }
    }
}

@Composable
private fun Notice(message: String) {
    Text(
        message, color = Wyn.colors.textSecondary, fontSize = 14.sp, lineHeight = 20.sp,
        modifier = Modifier.padding(top = 12.dp).fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Wyn.colors.surface).padding(12.dp),
    )
}

@Composable
private fun RoundAction(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, size: Int, onClick: () -> Unit) {
    val c = Wyn.colors
    val dark = c.bg == DarkWynColors.bg
    Box(
        Modifier.size(40.dp).clip(CircleShape).border(1.dp, if (dark) c.border else OwnActionBorder, CircleShape).background(c.bg)
            .clickable(role = Role.Button, onClickLabel = label, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = label, tint = c.text, modifier = Modifier.size(size.dp))
    }
}

@Composable
private fun Stat(value: Int, label: String, onClick: () -> Unit) {
    val c = Wyn.colors
    Text(
        buildAnnotatedString {
            withStyle(SpanStyle(color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold)) { append(count(value)) }
            append(" ")
            withStyle(SpanStyle(color = StatGrey, fontSize = 14.sp)) { append(label) }
        },
        modifier = Modifier.heightIn(min = 28.dp).clip(RoundedCornerShape(6.dp)).clickable(role = Role.Button, onClick = onClick),
    )
}

@Composable
fun PillButton(
    label: String,
    filled: Boolean,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    outlined: Boolean = false,
    icon: androidx.compose.ui.graphics.vector.ImageVector? = null,
    height: Dp = 44.dp,
    fontSize: Int = 14,
    onClick: () -> Unit,
) {
    val c = Wyn.colors
    val shape = RoundedCornerShape(999.dp)
    val background = when {
        filled -> c.text
        outlined -> c.bg
        else -> c.surface
    }
    val content = if (filled) c.bg else c.text
    Row(
        modifier.height(height).clip(shape).background(background).border(1.dp, if (filled) c.text else c.border, shape)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick).padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        if (icon != null) {
            Icon(icon, contentDescription = null, tint = content, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(7.dp))
        }
        Text(label, color = content.copy(alpha = if (enabled) 1f else 0.6f), fontSize = fontSize.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
    }
}

// ---- Suggestions (web ProfileRecommendations) ---------------------------------------

@Composable
private fun Suggestions(vm: ProfileViewModel, onOpen: (String) -> Unit) {
    val c = Wyn.colors
    Column(Modifier.fillMaxWidth().padding(top = 8.dp)) {
        Text(stringResource(R.string.profile_suggestions), color = c.text, fontSize = 14.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 16.dp, end = 16.dp, bottom = 8.dp))
        LazyRow(
            contentPadding = androidx.compose.foundation.layout.PaddingValues(start = 16.dp, end = 16.dp, bottom = 14.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            items(vm.suggestions, key = { it.id }) { person -> SuggestionCard(person, person.id in vm.suggestionBusy, vm, onOpen) }
        }
        vm.suggestionError?.let { Box(Modifier.padding(horizontal = 16.dp)) { ErrorText(it.text()) } }
    }
}

@Composable
private fun SuggestionCard(person: Person, busy: Boolean, vm: ProfileViewModel, onOpen: (String) -> Unit) {
    val c = Wyn.colors
    Box(Modifier.size(132.dp, 190.dp).clip(RoundedCornerShape(14.dp)).border(1.dp, c.border, RoundedCornerShape(14.dp)).background(c.bg).padding(12.dp)) {
        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
            Column(
                Modifier.fillMaxWidth().clickable(role = Role.Button) { onOpen(person.id) }.padding(top = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                WynAvatar(person.avatarUrl, 56)
                Text(person.label, color = c.text, fontSize = 13.5.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = 5.dp))
                Text("@${person.username}", color = c.textSecondary, fontSize = 11.5.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Spacer(Modifier.weight(1f))
            PillButton(
                followLabel(busy, person.following, person.requested), filled = !(person.following || person.requested),
                enabled = !busy, height = 34.dp, fontSize = 12, modifier = Modifier.fillMaxWidth(),
            ) { vm.followSuggestion(person) }
        }
        val hide = stringResource(R.string.profile_hide_suggestion)
        Icon(
            WynIcons.Close, contentDescription = hide, tint = c.textSecondary,
            modifier = Modifier.align(Alignment.TopEnd).padding(0.dp).size(26.dp).clip(CircleShape)
                .clickable(role = Role.Button, onClickLabel = hide) { vm.dismissSuggestion(person) }.padding(5.dp),
        )
    }
}

// ---- Tabs ----------------------------------------------------------------------------

@Composable
private fun ProfileTabs(selected: ProfileTab, onSelect: (ProfileTab) -> Unit) {
    val c = Wyn.colors
    val dark = c.bg == DarkWynColors.bg
    Column(Modifier.fillMaxWidth().background(c.bg)) {
        Row(Modifier.fillMaxWidth().height(50.dp)) {
            listOf(ProfileTab.Posts to R.string.profile_tab_posts, ProfileTab.Reposts to R.string.profile_tab_reposts, ProfileTab.Likes to R.string.profile_tab_likes)
                .forEach { (tab, label) ->
                    val active = tab == selected
                    Box(
                        Modifier.weight(1f).fillMaxSize().selectable(active, role = Role.Tab) { onSelect(tab) },
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            stringResource(label), color = if (active) c.text else TabGrey, fontSize = 15.sp,
                            fontWeight = if (active) FontWeight.Bold else FontWeight.SemiBold,
                        )
                        if (active) Box(Modifier.align(Alignment.BottomCenter).size(120.dp, 2.dp).background(c.text))
                    }
                }
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(if (dark) c.border else TabLine))
    }
}

@Composable
fun MoreButton(loading: Boolean, onClick: () -> Unit) {
    Box(Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
        PillButton(stringResource(R.string.see_more), filled = false, enabled = !loading, height = 38.dp, fontSize = 13, onClick = onClick)
    }
}
