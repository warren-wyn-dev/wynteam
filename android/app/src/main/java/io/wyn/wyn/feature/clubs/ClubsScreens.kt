package io.wyn.wyn.feature.clubs

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
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import io.wyn.wyn.R
import io.wyn.wyn.core.data.CLUB_NAME_MAX
import io.wyn.wyn.core.data.Club
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.core.design.WynPrimaryButton
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.compose.PhotoReader
import io.wyn.wyn.feature.compose.PhotoRejected
import io.wyn.wyn.feature.home.FeedText
import io.wyn.wyn.feature.home.rememberEnglish
import io.wyn.wyn.feature.profile.PillButton
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** web ExploreClubs: the Clubs tab. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExploreClubsScreen(vm: ExploreClubsViewModel, onOpen: (String) -> Unit, onCreate: () -> Unit) {
    val c = Wyn.colors
    Column(Modifier.fillMaxSize().background(c.bg)) {
        ClubTopBar(stringResource(R.string.clubs_explore_title), onBack = null)
        PullToRefreshBox(isRefreshing = vm.refreshing, onRefresh = { vm.load(pull = true) }, modifier = Modifier.weight(1f)) {
            LazyColumn(Modifier.fillMaxSize()) {
                if (vm.loading && vm.sections == null) {
                    item(key = "loading") { ClubLoading() }
                    return@LazyColumn
                }
                item(key = "hero") { Hero(onCreate) }
                item(key = "search") { SearchField(vm.query, vm::updateQuery) }
                vm.error?.let { error ->
                    item(key = "error") { Text(error.text().orEmpty(), color = c.textSecondary, fontSize = 13.sp, modifier = Modifier.padding(horizontal = 24.dp, vertical = 6.dp)) }
                }
                section(vm, "popular", R.string.clubs_popular, vm.popular, R.string.clubs_popular_empty, onOpen)
                section(vm, "newest", R.string.clubs_newest, vm.newest, R.string.clubs_newest_empty, onOpen)
                item(key = "end") { Spacer(Modifier.height(32.dp)) }
            }
        }
    }
}

@Composable
private fun Hero(onCreate: () -> Unit) {
    val c = Wyn.colors
    Column(Modifier.fillMaxWidth().padding(start = 24.dp, end = 24.dp, top = 24.dp)) {
        Text(
            stringResource(R.string.clubs_hero_title) + " " + stringResource(R.string.clubs_hero_title_2),
            color = c.text, fontSize = 20.sp, lineHeight = 26.sp, fontWeight = FontWeight.Bold,
        )
        Text(
            stringResource(R.string.clubs_hero_body), color = c.textSecondary, fontSize = 13.sp, lineHeight = 18.sp,
            modifier = Modifier.padding(top = 8.dp, bottom = 16.dp),
        )
        Row(
            Modifier.fillMaxWidth().heightIn(min = 44.dp).clip(RoundedCornerShape(999.dp)).background(c.text).clickable(role = Role.Button, onClick = onCreate),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            Icon(WynIcons.Plus, contentDescription = null, tint = c.bg, modifier = Modifier.size(17.dp))
            Spacer(Modifier.width(7.dp))
            Text(stringResource(R.string.clubs_create), color = c.bg, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun SearchField(value: String, onChange: (String) -> Unit) {
    val c = Wyn.colors
    val hint = stringResource(R.string.clubs_search)
    BasicTextField(
        value = value,
        onValueChange = onChange,
        singleLine = true,
        textStyle = TextStyle(color = c.text, fontSize = 16.sp),
        cursorBrush = SolidColor(c.text),
        modifier = Modifier.fillMaxWidth().padding(start = 24.dp, end = 24.dp, top = 20.dp).semantics { contentDescription = hint },
        decorationBox = { inner ->
            Row(
                Modifier.fillMaxWidth().height(42.dp).clip(RoundedCornerShape(999.dp)).border(1.dp, c.border, RoundedCornerShape(999.dp))
                    .background(c.surface).padding(horizontal = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(WynIcons.Search, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(8.dp))
                Box(Modifier.weight(1f)) {
                    if (value.isEmpty()) Text(hint, color = c.textMuted, fontSize = 16.sp)
                    inner()
                }
            }
        },
    )
}

private fun LazyListScope.section(
    vm: ExploreClubsViewModel,
    key: String,
    title: Int,
    clubs: List<Club>,
    empty: Int,
    onOpen: (String) -> Unit,
) {
    item(key = "title:$key") {
        Text(
            stringResource(title), color = Wyn.colors.textSecondary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.8.sp,
            modifier = Modifier.padding(start = 24.dp, end = 24.dp, top = 24.dp, bottom = 8.dp),
        )
    }
    if (clubs.isEmpty()) {
        item(key = "empty:$key") {
            val query = vm.query.trim()
            Text(
                if (query.isNotEmpty()) stringResource(R.string.clubs_no_match, vm.query) else stringResource(empty),
                color = Wyn.colors.textSecondary, fontSize = 13.sp, modifier = Modifier.padding(horizontal = 24.dp, vertical = 6.dp),
            )
        }
    } else {
        items(clubs, key = { "$key:${it.id}" }) { club ->
            ExploreRow(club, vm.pending(club), vm.joining == club.id, enabled = vm.joining == null, onOpen = { onOpen(club.id) }, onJoin = { vm.join(club) })
        }
    }
}

@Composable
private fun ExploreRow(club: Club, pending: Boolean, joining: Boolean, enabled: Boolean, onOpen: () -> Unit, onJoin: () -> Unit) {
    val c = Wyn.colors
    Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).padding(horizontal = 24.dp), verticalAlignment = Alignment.CenterVertically) {
        Row(Modifier.weight(1f).clickable(role = Role.Button, onClick = onOpen), verticalAlignment = Alignment.CenterVertically) {
            ClubAvatar(club)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(club.name, color = c.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(stringResource(R.string.clubs_members, memberCount(club.memberCount)), color = c.textSecondary, fontSize = 13.sp, modifier = Modifier.padding(top = 2.dp))
            }
        }
        Spacer(Modifier.width(10.dp))
        if (pending) {
            Text(
                stringResource(R.string.clubs_pending), color = c.textSecondary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.clip(RoundedCornerShape(999.dp)).background(c.border).padding(horizontal = 12.dp, vertical = 6.dp),
            )
        } else {
            Box(
                Modifier.heightIn(min = 32.dp).width(72.dp).clip(RoundedCornerShape(999.dp)).border(1.dp, c.text, RoundedCornerShape(999.dp)).background(c.bg)
                    .clickable(enabled = enabled, role = Role.Button, onClick = onJoin),
                contentAlignment = Alignment.Center,
            ) {
                if (joining) {
                    CircularProgressIndicator(color = c.text, strokeWidth = 2.dp, modifier = Modifier.size(12.dp))
                } else {
                    Text(stringResource(R.string.clubs_join), color = c.text, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

/** web MyClubs (Home menu → "Club ของฉัน"). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyClubsScreen(vm: MyClubsViewModel, onBack: () -> Unit, onOpen: (String) -> Unit) {
    val c = Wyn.colors
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding()) {
        ClubTopBar(stringResource(R.string.my_clubs_title), onBack)
        PullToRefreshBox(isRefreshing = vm.refreshing, onRefresh = { vm.load(pull = true) }, modifier = Modifier.weight(1f)) {
            LazyColumn(Modifier.fillMaxSize()) {
                when {
                    vm.loading -> item(key = "loading") { ClubLoading() }
                    vm.error != null -> item(key = "error") {
                        Column(Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(vm.error.text().orEmpty(), color = c.textSecondary, fontSize = 15.sp, textAlign = TextAlign.Center)
                            Spacer(Modifier.height(12.dp))
                            PillButton(stringResource(R.string.retry), filled = false, outlined = true) { vm.load() }
                        }
                    }
                    vm.rows.isEmpty() -> item(key = "empty") { ClubEmpty(stringResource(R.string.my_clubs_empty)) }
                    else -> items(vm.rows, key = { it.id }) { club ->
                        Column {
                            Row(
                                Modifier.fillMaxWidth().heightIn(min = 66.dp).clickable(role = Role.Button) { onOpen(club.id) }.padding(horizontal = 16.dp, vertical = 10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                ClubAvatar(club)
                                Column(Modifier.weight(1f)) {
                                    Text(club.name, color = c.text, fontSize = 15.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                    Text(stringResource(R.string.clubs_members, memberCount(club.memberCount)), color = c.textSecondary, fontSize = 13.sp, modifier = Modifier.padding(top = 2.dp))
                                }
                                Icon(WynIcons.ChevronRight, contentDescription = null, tint = c.text, modifier = Modifier.size(18.dp))
                            }
                            HorizontalDivider(color = c.border, thickness = 1.dp)
                        }
                    }
                }
            }
        }
    }
}

/** web CreateClubInner. */
@Composable
fun CreateClubScreen(vm: CreateClubViewModel, onBack: () -> Unit, onCreated: (String) -> Unit) {
    val c = Wyn.colors
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            try {
                vm.pickIcon(withContext(Dispatchers.IO) { PhotoReader.read(context, uri) })
            } catch (e: PhotoRejected) {
                vm.showError(UiText(e.reason))
            } catch (e: Exception) {
                vm.showError(UiText(R.string.photo_wrong_type))
            }
        }
    }
    LaunchedEffect(vm.createdId) { vm.createdId?.let(onCreated) }
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding().imePadding()) {
        ClubTopBar(stringResource(R.string.clubs_create), onBack)
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 20.dp, bottom = 34.dp).navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Column {
                Text(stringResource(R.string.create_club_intro_title), color = c.text, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Text(stringResource(R.string.create_club_intro_body), color = c.textSecondary, fontSize = 13.sp, lineHeight = 19.5.sp, modifier = Modifier.padding(top = 6.dp))
            }
            val pickLabel = stringResource(if (vm.icon != null) R.string.create_club_change_image else R.string.create_club_pick_image)
            val dashed = c.textSecondary
            Box(
                Modifier.align(Alignment.CenterHorizontally).size(112.dp).clip(CircleShape).background(c.surface)
                    .drawBehind {
                        drawCircle(dashed, style = Stroke(width = 1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx()))))
                    }
                    .clickable(enabled = !vm.saving, role = Role.Button, onClickLabel = pickLabel) {
                        picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    },
                contentAlignment = Alignment.Center,
            ) {
                val icon = vm.icon
                if (icon != null) {
                    AsyncImage(icon.bytes, contentDescription = pickLabel, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                } else {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Icon(WynIcons.Camera, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(26.dp))
                        Text(pickLabel, color = c.textSecondary, fontSize = 12.sp, textAlign = TextAlign.Center)
                    }
                }
            }
            ClubField(stringResource(R.string.create_club_name), vm.name, vm::updateName, stringResource(R.string.create_club_name), counter = "${vm.name.trim().length}/$CLUB_NAME_MAX")
            ClubField(stringResource(R.string.create_club_description), vm.description, vm::updateDescription, stringResource(R.string.create_club_description_hint), singleLine = false)
            ClubField(stringResource(R.string.create_club_category), vm.category, vm::updateCategory, stringResource(R.string.create_club_category_hint))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                PrivacyChoice(WynIcons.Users, R.string.club_public, R.string.club_public_hint, vm.privacy == "public", Modifier.weight(1f)) { vm.choosePrivacy("public") }
                PrivacyChoice(WynIcons.Lock, R.string.club_private, R.string.club_private_hint, vm.privacy == "private", Modifier.weight(1f)) { vm.choosePrivacy("private") }
            }
            ErrorText(vm.error.text())
            WynPrimaryButton(
                stringResource(if (vm.saving) R.string.create_club_saving else R.string.clubs_create), vm::submit,
                enabled = vm.canSubmit, modifier = Modifier.heightIn(min = 48.dp),
            )
        }
    }
}

@Composable
private fun ClubField(label: String, value: String, onChange: (String) -> Unit, placeholder: String, counter: String? = null, singleLine: Boolean = true) {
    val c = Wyn.colors
    Column {
        Row(Modifier.padding(bottom = 6.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(label, color = c.text, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            if (counter != null) Text(" $counter", color = c.textSecondary, fontSize = 12.sp)
        }
        BasicTextField(
            value = value,
            onValueChange = onChange,
            singleLine = singleLine,
            textStyle = TextStyle(color = c.text, fontSize = 16.sp),
            cursorBrush = SolidColor(c.text),
            modifier = Modifier.fillMaxWidth().semantics { contentDescription = label },
            decorationBox = { inner ->
                Box(
                    Modifier.fillMaxWidth().heightIn(min = if (singleLine) 48.dp else 96.dp).clip(RoundedCornerShape(14.dp))
                        .border(1.dp, c.borderStrong, RoundedCornerShape(14.dp)).padding(horizontal = 14.dp, vertical = if (singleLine) 0.dp else 12.dp),
                    contentAlignment = if (singleLine) Alignment.CenterStart else Alignment.TopStart,
                ) {
                    if (value.isEmpty()) Text(placeholder, color = c.textMuted, fontSize = 16.sp)
                    inner()
                }
            },
        )
    }
}

@Composable
private fun PrivacyChoice(icon: ImageVector, title: Int, hint: Int, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val c = Wyn.colors
    val shape = RoundedCornerShape(16.dp)
    Row(
        modifier.heightIn(min = 82.dp).clip(shape).border(if (selected) 2.dp else 1.dp, if (selected) c.text else c.border, shape).background(c.bg)
            .selectable(selected, role = Role.RadioButton, onClick = onClick).padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(9.dp),
    ) {
        Icon(icon, contentDescription = null, tint = c.text, modifier = Modifier.size(19.dp))
        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(stringResource(title), color = c.text, fontSize = 14.sp, fontWeight = FontWeight.Bold)
            Text(stringResource(hint), color = c.textSecondary, fontSize = 11.5.sp, lineHeight = 15.5.sp)
        }
    }
}

/** web ClubPostRoute: the post alone, titled with its Club. */
@Composable
fun ClubPostScreen(vm: ClubPostViewModel, onBack: () -> Unit) {
    val c = Wyn.colors
    val english = rememberEnglish()
    val page = vm.page
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding()) {
        ClubTopBar(page?.clubName ?: stringResource(R.string.club_post_title), onBack)
        when {
            page == null && vm.loading -> ClubLoading()
            page == null -> ClubEmpty(stringResource(R.string.club_post_missing))
            else -> Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp).navigationBarsPadding()) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    WynAvatar(page.authorAvatarUrl, 40)
                    Spacer(Modifier.width(10.dp))
                    Column {
                        Text(page.authorLabel, color = c.text, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                        Text(FeedText.relativeTime(page.createdAt, english), color = c.textSecondary, fontSize = 12.sp)
                    }
                }
                page.content?.takeIf { it.isNotEmpty() }?.let {
                    Text(it, color = c.text, fontSize = 15.sp, lineHeight = 22.sp, modifier = Modifier.padding(top = 12.dp))
                }
                page.imageUrls.forEach { url ->
                    AsyncImage(url, contentDescription = null, contentScale = ContentScale.FillWidth, modifier = Modifier.padding(top = 12.dp).fillMaxWidth().clip(RoundedCornerShape(12.dp)))
                }
            }
        }
    }
}

/** web ClubInviteLinkRoute. */
@Composable
fun ClubInviteScreen(vm: ClubInviteViewModel, onBack: () -> Unit, onOpenClub: (String) -> Unit) {
    val c = Wyn.colors
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding()) {
        ClubTopBar(stringResource(R.string.invite_title), onBack)
        val preview = vm.preview
        when {
            vm.loading -> ClubLoading()
            preview == null || preview.status == "not_found" -> ClubEmpty(stringResource(R.string.invite_missing))
            preview.status != "valid" -> ClubEmpty(
                stringResource(
                    when (preview.status) {
                        "expired" -> R.string.invite_expired
                        "revoked" -> R.string.invite_revoked
                        "exhausted" -> R.string.invite_exhausted
                        else -> R.string.invite_unusable
                    },
                ),
            )
            else -> Column(
                Modifier.fillMaxWidth().padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                preview.iconUrl?.let {
                    AsyncImage(it, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.size(76.dp).clip(CircleShape))
                }
                Text(preview.clubName ?: "Club", color = c.text, fontSize = 20.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
                Text(
                    stringResource(if (preview.clubPrivacy == "private") R.string.club_private_label else R.string.club_public_label),
                    color = c.textSecondary, fontSize = 13.sp,
                )
                if (vm.joinedId == null) {
                    WynPrimaryButton(stringResource(if (vm.busy) R.string.invite_joining else R.string.invite_join), vm::redeem, enabled = !vm.busy)
                }
                vm.message?.let { Text(it.text().orEmpty(), color = c.textSecondary, fontSize = 14.sp, textAlign = TextAlign.Center) }
                (vm.joinedId ?: preview.clubId)?.let { id ->
                    PillButton(stringResource(R.string.invite_open_club), filled = false, outlined = true) { onOpenClub(id) }
                }
            }
        }
    }
}
