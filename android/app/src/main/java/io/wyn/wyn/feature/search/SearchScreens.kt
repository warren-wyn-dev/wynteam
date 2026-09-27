package io.wyn.wyn.feature.search

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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import io.wyn.wyn.R
import io.wyn.wyn.core.data.Club
import io.wyn.wyn.core.data.Person
import io.wyn.wyn.core.data.RankedHashtag
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.clubs.ClubTopBar
import io.wyn.wyn.feature.clubs.memberCount
import io.wyn.wyn.feature.home.FeedOverlays
import io.wyn.wyn.feature.home.FeedViewModel
import io.wyn.wyn.feature.home.HomeNavigation
import io.wyn.wyn.feature.home.feedRows
import io.wyn.wyn.feature.home.sharePost
import io.wyn.wyn.feature.profile.MoreButton
import io.wyn.wyn.feature.profile.PersonRow
import io.wyn.wyn.feature.profile.PillButton

private val Sapphire = Color(0xFF1D6FE0)

/** What the search screens open. */
data class SearchNavigation(
    val feed: HomeNavigation,
    val onBack: () -> Unit,
    val onOpenProfile: (String) -> Unit,
    val onOpenClub: (String) -> Unit,
    val onTrending: () -> Unit,
)

/** web SearchInner. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun SearchScreen(vm: SearchViewModel, posts: SearchPostsViewModel, nav: SearchNavigation, myAvatar: String?, myName: String?) {
    val c = Wyn.colors
    val context = LocalContext.current
    // The posts list follows the query shown (web DropResults per query).
    LaunchedEffect(vm.query) { posts.select(vm.query) }
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding().imePadding()) {
        SearchHeader(vm, nav.onBack)
        LazyColumn(Modifier.weight(1f).fillMaxSize()) {
            if (!searchable(vm.query)) {
                discovery(vm, nav)
            } else {
                stickyHeader(key = "tabs") { Tabs(vm.tab, vm::select) }
                when (vm.tab) {
                    SearchTab.All -> all(vm, posts, nav) { row -> sharePost(context, posts, row) }
                    SearchTab.Users -> users(vm, nav)
                    SearchTab.Posts -> posts(posts, vm.query, nav) { row -> sharePost(context, posts, row) }
                    SearchTab.Clubs -> clubs(vm, nav)
                }
            }
        }
    }
    FeedOverlays(posts, nav.feed, { row -> sharePost(context, posts, row) }, myAvatar, myName)
    vm.confirmCancel?.let { person ->
        AlertDialog(
            onDismissRequest = vm::dismissConfirm,
            containerColor = c.bg,
            title = { Text(stringResource(R.string.follow_cancel_confirm, person.username), color = c.text, fontWeight = FontWeight.Bold, fontSize = 17.sp) },
            confirmButton = { TextButton(onClick = { vm.follow(person, confirmed = true) }) { Text(stringResource(R.string.follow_cancel), color = Color(0xFFE0203D), fontWeight = FontWeight.Bold) } },
            dismissButton = { TextButton(onClick = vm::dismissConfirm) { Text(stringResource(R.string.cancel), color = c.textSecondary) } },
        )
    }
}

@Composable
private fun SearchHeader(vm: SearchViewModel, onBack: () -> Unit) {
    val c = Wyn.colors
    Row(
        Modifier.fillMaxWidth().height(64.dp).padding(start = 6.dp, end = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        val leave = stringResource(R.string.search_leave)
        Icon(
            WynIcons.Back, contentDescription = leave, tint = c.text,
            modifier = Modifier.size(44.dp).clip(CircleShape).clickable(role = Role.Button, onClickLabel = leave, onClick = onBack).padding(8.dp),
        )
        val label = stringResource(R.string.search_field_label)
        BasicTextField(
            value = vm.draft,
            onValueChange = vm::updateDraft,
            singleLine = true,
            textStyle = TextStyle(color = c.text, fontSize = 15.5.sp, fontWeight = FontWeight.Medium),
            cursorBrush = SolidColor(c.text),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text, imeAction = ImeAction.Search, autoCorrectEnabled = false),
            keyboardActions = KeyboardActions(onSearch = { vm.submitNow() }),
            modifier = Modifier.weight(1f).semantics { contentDescription = label },
            decorationBox = { inner ->
                Row(
                    Modifier.fillMaxWidth().height(44.dp).clip(RoundedCornerShape(999.dp)).border(1.dp, c.border, RoundedCornerShape(999.dp))
                        .background(c.surface).padding(horizontal = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    val search = stringResource(R.string.search)
                    Icon(
                        WynIcons.Search, contentDescription = search, tint = c.textSecondary,
                        modifier = Modifier.size(28.dp).clip(CircleShape).clickable(role = Role.Button, onClick = vm::submitNow).padding(4.dp),
                    )
                    Spacer(Modifier.width(6.dp))
                    Box(Modifier.weight(1f)) {
                        if (vm.draft.isEmpty()) Text(stringResource(R.string.search_placeholder), color = c.textMuted, fontSize = 15.5.sp, maxLines = 1)
                        inner()
                    }
                    if (vm.draft.isNotEmpty()) {
                        val clear = stringResource(R.string.search_clear)
                        Icon(
                            WynIcons.Close, contentDescription = clear, tint = c.textSecondary,
                            modifier = Modifier.size(28.dp).clip(CircleShape).clickable(role = Role.Button, onClick = vm::clear).padding(5.dp),
                        )
                    }
                }
            },
        )
    }
}

@Composable
private fun Tabs(selected: SearchTab, onSelect: (SearchTab) -> Unit) {
    val c = Wyn.colors
    Column(Modifier.fillMaxWidth().background(c.bg)) {
        Row(Modifier.fillMaxWidth().height(46.dp)) {
            listOf(
                SearchTab.All to R.string.search_tab_all,
                SearchTab.Users to R.string.search_tab_users,
                SearchTab.Posts to R.string.search_tab_posts,
                SearchTab.Clubs to R.string.search_tab_clubs,
            ).forEach { (tab, label) ->
                val active = tab == selected
                Box(Modifier.weight(1f).fillMaxSize().selectable(active, role = Role.Tab) { onSelect(tab) }, contentAlignment = Alignment.Center) {
                    Text(stringResource(label), color = if (active) c.text else c.textSecondary, fontSize = 14.sp, fontWeight = if (active) FontWeight.Bold else FontWeight.Medium)
                    if (active) Box(Modifier.align(Alignment.BottomCenter).size(34.dp, 2.dp).clip(RoundedCornerShape(999.dp)).background(c.text))
                }
            }
        }
        HorizontalDivider(color = c.border, thickness = 1.dp)
    }
}

// ---- Discovery -------------------------------------------------------------------

private fun LazyListScope.discovery(vm: SearchViewModel, nav: SearchNavigation) {
    if (vm.discoveryLoading && vm.hashtags.isEmpty() && vm.suggested.isEmpty()) {
        item(key = "discovery-loading") { Loading() }
        return
    }
    item(key = "trend-title") { SectionTitle(stringResource(R.string.search_trending_title), Modifier.padding(start = 40.dp, end = 40.dp, top = 18.dp, bottom = 6.dp)) }
    if (vm.hashtags.isEmpty()) {
        item(key = "trend-empty") { Empty(stringResource(R.string.trending_empty)) }
    } else {
        itemsIndexed(vm.hashtags, key = { _, it -> "tag:" + it.tag }) { index, tag -> HashtagRow(index + 1, tag, showMore = true) }
    }
    item(key = "top100") {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 42.dp).padding(bottom = 10.dp).clickable(role = Role.Button, onClick = nav.onTrending),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(stringResource(R.string.search_top100_link), color = Sapphire, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.width(2.dp))
            Icon(WynIcons.ChevronRight, contentDescription = null, tint = Sapphire, modifier = Modifier.size(14.dp))
        }
    }
    item(key = "suggest-title") { SectionTitle(stringResource(R.string.search_suggested_title), Modifier.padding(start = 40.dp, end = 40.dp, bottom = 10.dp)) }
    if (vm.suggested.isEmpty()) {
        item(key = "suggest-empty") { Empty(stringResource(R.string.search_suggested_empty)) }
    } else {
        items(vm.suggested, key = { "suggest:" + it.id }) { person -> Person(vm, person, nav, horizontalPadding = 32.dp, minHeight = 68.dp) }
    }
    vm.followError?.let { error -> item(key = "suggest-error") { Box(Modifier.padding(horizontal = 16.dp)) { ErrorText(error.text()) } } }
    item(key = "discovery-end") { Spacer(Modifier.height(28.dp)) }
}

@Composable
private fun SectionTitle(title: String, modifier: Modifier = Modifier, action: String? = null, onAction: (() -> Unit)? = null) {
    val c = Wyn.colors
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(title, color = c.text, fontSize = 17.sp, lineHeight = 21.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
        if (action != null && onAction != null) {
            Text(
                action, color = Sapphire, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.heightIn(min = 32.dp).clip(RoundedCornerShape(8.dp)).clickable(role = Role.Button, onClick = onAction).padding(horizontal = 4.dp, vertical = 7.dp),
            )
        }
    }
}

/** flutter-rank-row: rank, #tag, "N โพสต์ · กำลังนิยมใน ไทย". */
@Composable
fun HashtagRow(rank: Int, tag: RankedHashtag, showMore: Boolean) {
    val c = Wyn.colors
    Column {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 62.dp).padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(rank.toString(), color = c.textMuted, fontSize = 17.sp, fontWeight = FontWeight.Medium, textAlign = TextAlign.End, modifier = Modifier.width(28.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text("#${tag.tag}", color = c.text, fontSize = 14.5.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(stringResource(R.string.hashtag_meta, memberCount(tag.postCount)), color = c.textSecondary, fontSize = 12.sp)
            }
            if (showMore) Icon(WynIcons.More, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(16.dp))
            else Spacer(Modifier.width(28.dp))
        }
        HorizontalDivider(color = c.border, thickness = 1.dp)
    }
}

@Composable
private fun Person(vm: SearchViewModel, person: Person, nav: SearchNavigation, horizontalPadding: androidx.compose.ui.unit.Dp = 16.dp, minHeight: androidx.compose.ui.unit.Dp = 64.dp, follow: Boolean = true) {
    PersonRow(
        person, vm.userId, vm.followBusy == person.id,
        onFollow = if (follow) ({ vm.follow(person) }) else null,
        onOpen = nav.onOpenProfile, horizontalPadding = horizontalPadding, minHeight = minHeight,
    )
}

// ---- Results ---------------------------------------------------------------------

private fun LazyListScope.status(vm: SearchViewModel, empty: Boolean, emptyText: Int, loading: @Composable () -> Unit = { Loading() }): Boolean {
    when {
        vm.loading && empty -> item(key = "loading") { loading() }
        vm.error != null && empty -> item(key = "error") {
            Column(Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(vm.error.text().orEmpty(), color = Wyn.colors.textSecondary, fontSize = 15.sp, textAlign = TextAlign.Center)
                Spacer(Modifier.height(12.dp))
                PillButton(stringResource(R.string.retry), filled = false, outlined = true, onClick = vm::load)
            }
        }
        empty -> item(key = "empty") { Empty(stringResource(emptyText, vm.query)) }
        else -> return false
    }
    return true
}

private fun LazyListScope.all(vm: SearchViewModel, posts: SearchPostsViewModel, nav: SearchNavigation, share: (io.wyn.wyn.core.data.FeedRow) -> Unit) {
    val empty = vm.allUsers.isEmpty() && vm.allPosts.isEmpty() && vm.allClubs.isEmpty()
    if (status(vm, empty, R.string.search_all_empty)) return
    val sectionPad = Modifier.padding(start = 16.dp, end = 12.dp, top = 16.dp, bottom = 4.dp)
    if (vm.allUsers.isNotEmpty()) {
        item(key = "all-users") {
            SectionTitle(stringResource(R.string.search_section_users), sectionPad, stringResource(R.string.search_see_all).takeIf { vm.allUsers.size > 3 }) { vm.select(SearchTab.Users) }
        }
        items(vm.allUsers.take(3), key = { "all-user:" + it.id }) { person -> Person(vm, person, nav, follow = false) }
    }
    if (vm.allPosts.isNotEmpty()) {
        item(key = "all-posts") {
            SectionTitle(stringResource(R.string.search_section_posts), sectionPad, stringResource(R.string.search_see_all).takeIf { vm.allPosts.size > 2 }) { vm.select(SearchTab.Posts) }
        }
        // The same cards as the Posts tab, from its first page when it is ready.
        val snapshot = posts.snapshot
        if (snapshot != null && snapshot.rows.isNotEmpty()) {
            feedRows(posts, snapshot.copy(rows = snapshot.rows.take(2)), nav.feed, share)
        }
    }
    if (vm.allClubs.isNotEmpty()) {
        item(key = "all-clubs") {
            SectionTitle(stringResource(R.string.search_section_clubs), sectionPad, stringResource(R.string.search_see_all).takeIf { vm.allClubs.size > 2 }) { vm.select(SearchTab.Clubs) }
        }
        items(vm.allClubs.take(2), key = { "all-club:" + it.id }) { club -> ClubRow(club) { nav.onOpenClub(club.id) } }
    }
}

private fun LazyListScope.users(vm: SearchViewModel, nav: SearchNavigation) {
    if (status(vm, vm.users.rows.isEmpty(), R.string.search_users_empty)) return
    items(vm.users.rows, key = { "user:" + it.id }) { person -> Person(vm, person, nav) }
    vm.error?.let { error -> item(key = "users-error") { Box(Modifier.padding(horizontal = 16.dp)) { ErrorText(error.text()) } } }
    vm.followError?.let { error -> item(key = "follow-error") { Box(Modifier.padding(horizontal = 16.dp)) { ErrorText(error.text()) } } }
    if (vm.users.hasMore) item(key = "users-more") { MoreButton(vm.loading, vm::moreUsers) }
}

private fun LazyListScope.posts(posts: FeedViewModel<String>, query: String, nav: SearchNavigation, share: (io.wyn.wyn.core.data.FeedRow) -> Unit) {
    val snapshot = posts.snapshot
    when {
        snapshot == null && posts.error != null -> item(key = "posts-error") { Empty(posts.error.text().orEmpty()) }
        snapshot == null -> item(key = "posts-loading") { Loading() }
        snapshot.rows.isEmpty() -> item(key = "posts-empty") { Empty(stringResource(R.string.search_posts_empty, query)) }
        else -> {
            feedRows(posts, snapshot, nav.feed, share)
            if (snapshot.hasMore) item(key = "posts-more") { MoreButton(posts.loadingMore, posts::loadMore) }
        }
    }
}

private fun LazyListScope.clubs(vm: SearchViewModel, nav: SearchNavigation) {
    if (status(vm, vm.clubs.rows.isEmpty(), R.string.search_clubs_empty)) return
    items(vm.clubs.rows, key = { "club:" + it.id }) { club -> ClubRow(club) { nav.onOpenClub(club.id) } }
    if (vm.clubs.hasMore) item(key = "clubs-more") { MoreButton(vm.loading, vm::moreClubs) }
}

/** route-club-row: a rounded-square photo, name and "N สมาชิก · category". */
@Composable
private fun ClubRow(club: Club, onOpen: () -> Unit) {
    val c = Wyn.colors
    Column {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 68.dp).clickable(role = Role.Button, onClick = onOpen).padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(11.dp),
        ) {
            Box(Modifier.size(46.dp).clip(RoundedCornerShape(13.dp)).background(c.surface), contentAlignment = Alignment.Center) {
                if (club.iconUrl != null) {
                    AsyncImage(club.iconUrl, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                } else {
                    Text(club.name.take(1), color = c.text, fontSize = 16.sp, fontWeight = FontWeight.ExtraBold)
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(club.name, color = c.text, fontSize = 15.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                val meta = stringResource(R.string.clubs_members, memberCount(club.memberCount)) + (club.category?.takeIf { it.isNotEmpty() }?.let { " · $it" } ?: "")
                Text(meta, color = c.textSecondary, fontSize = 13.sp, maxLines = 1)
            }
        }
        HorizontalDivider(color = c.border, thickness = 1.dp)
    }
}

@Composable
private fun Loading() = io.wyn.wyn.feature.clubs.ClubLoading()

@Composable
private fun Empty(message: String) = io.wyn.wyn.feature.clubs.ClubEmpty(message)

// ---- Trending and Bookmarks -------------------------------------------------------

/** web TrendingInner: "อันดับแฮชแท็ก (Top 100)". */
@Composable
fun TrendingScreen(vm: TrendingViewModel, onBack: () -> Unit) {
    val c = Wyn.colors
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding()) {
        ClubTopBar(stringResource(R.string.trending_title), onBack)
        LazyColumn(Modifier.weight(1f)) {
            when {
                vm.error != null -> item(key = "error") {
                    Column(Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(vm.error.text().orEmpty(), color = c.textSecondary, fontSize = 15.sp, textAlign = TextAlign.Center)
                        Spacer(Modifier.height(12.dp))
                        PillButton(stringResource(R.string.retry), filled = false, outlined = true, enabled = !vm.loading, onClick = vm::load)
                    }
                }
                vm.loading && vm.hashtags.isEmpty() -> item(key = "loading") { Loading() }
                vm.hashtags.isEmpty() -> item(key = "empty") { Empty(stringResource(R.string.trending_empty)) }
                else -> itemsIndexed(vm.hashtags, key = { _, it -> it.tag }) { index, tag -> HashtagRow(index + 1, tag, showMore = false) }
            }
        }
    }
}

/** web BookmarksInner: "บันทึกไว้". */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BookmarksScreen(vm: BookmarksViewModel, nav: HomeNavigation, onBack: () -> Unit, myAvatar: String?, myName: String?) {
    val c = Wyn.colors
    val context = LocalContext.current
    fun share(row: io.wyn.wyn.core.data.FeedRow) = sharePost(context, vm, row)
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding()) {
        ClubTopBar(stringResource(R.string.bookmarks_title), onBack)
        PullToRefreshBox(isRefreshing = vm.refreshing, onRefresh = vm::refresh, modifier = Modifier.weight(1f)) {
            LazyColumn(Modifier.fillMaxSize()) {
                val snapshot = vm.snapshot
                when {
                    snapshot == null && vm.error != null -> item(key = "error") {
                        Column(Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(stringResource(R.string.bookmarks_failed), color = c.textSecondary, fontSize = 15.sp, textAlign = TextAlign.Center)
                            Spacer(Modifier.height(12.dp))
                            PillButton(stringResource(R.string.retry), filled = false, outlined = true) { vm.load() }
                        }
                    }
                    snapshot == null -> item(key = "loading") { Loading() }
                    snapshot.rows.isEmpty() -> item(key = "empty") { Empty(stringResource(R.string.bookmarks_empty)) }
                    else -> {
                        feedRows(vm, snapshot, nav, ::share)
                        if (snapshot.hasMore) item(key = "more") { MoreButton(vm.loadingMore, vm::loadMore) }
                    }
                }
            }
        }
    }
    FeedOverlays(vm, nav, ::share, myAvatar, myName)
}
