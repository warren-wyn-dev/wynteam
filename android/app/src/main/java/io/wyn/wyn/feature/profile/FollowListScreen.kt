package io.wyn.wyn.feature.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.wyn.wyn.R
import io.wyn.wyn.core.data.FollowKind
import io.wyn.wyn.core.data.Person
import io.wyn.wyn.core.design.DarkWynColors
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.VerifiedBadge
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.home.EmptyState

/** web profile-follow-list-route.tsx. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FollowListScreen(vm: FollowListViewModel, onBack: () -> Unit, onOpenProfile: (String) -> Unit) {
    val c = Wyn.colors
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding()) {
        Box(Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 8.dp)) {
            val back = stringResource(R.string.back)
            Icon(
                WynIcons.Back, contentDescription = back, tint = c.text,
                modifier = Modifier.align(Alignment.CenterStart).size(44.dp).clip(CircleShape).clickable(role = Role.Button, onClickLabel = back, onClick = onBack).padding(10.dp),
            )
            Text(
                stringResource(if (vm.kind == FollowKind.Followers) R.string.profile_followers else R.string.tab_following),
                color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold, modifier = Modifier.align(Alignment.Center),
            )
        }
        Row(Modifier.fillMaxWidth().height(48.dp)) {
            listOf(FollowKind.Following to R.string.tab_following, FollowKind.Followers to R.string.profile_followers).forEach { (kind, label) ->
                val active = kind == vm.kind
                Box(Modifier.weight(1f).fillMaxSize().selectable(active, role = Role.Tab) { vm.select(kind) }, contentAlignment = Alignment.Center) {
                    Text(stringResource(label), color = if (active) c.text else Color(0xFF72798A), fontSize = 15.sp, fontWeight = if (active) FontWeight.Bold else FontWeight.SemiBold)
                    if (active) Box(Modifier.align(Alignment.BottomCenter).size(120.dp, 2.dp).background(c.text))
                }
            }
        }
        Box(Modifier.fillMaxWidth().height(1.dp).background(if (c.bg == DarkWynColors.bg) c.border else Color(0xFFE3E6ED)))
        PullToRefreshBox(isRefreshing = vm.refreshing, onRefresh = { vm.load(pull = true) }, modifier = Modifier.weight(1f)) {
            val people = vm.people
            LazyColumn(Modifier.fillMaxSize()) {
                when {
                    people == null || (vm.loading && people.isEmpty()) -> item(key = "loading") {
                        Box(Modifier.fillMaxWidth().padding(48.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = c.textSecondary, strokeWidth = 2.dp) }
                    }
                    people.isEmpty() -> item(key = "empty") {
                        EmptyState(
                            vm.error.text() ?: stringResource(if (vm.kind == FollowKind.Followers) R.string.followers_empty else R.string.following_none),
                            null,
                        ) {}
                    }
                    else -> {
                        items(people, key = { it.id }) { person -> PersonRow(person, vm, onOpenProfile) }
                        vm.error?.let { item(key = "error") { Box(Modifier.padding(horizontal = 16.dp)) { ErrorText(it.text()) } } }
                    }
                }
            }
        }
    }
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
private fun PersonRow(person: Person, vm: FollowListViewModel, onOpen: (String) -> Unit) {
    val c = Wyn.colors
    Row(Modifier.fillMaxWidth().heightIn(min = 64.dp).padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Row(Modifier.weight(1f).clickable(role = Role.Button) { onOpen(person.id) }, verticalAlignment = Alignment.CenterVertically) {
            WynAvatar(person.avatarUrl, 44)
            Column(Modifier.weight(1f).padding(start = 12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(person.label, color = c.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                    if (person.isVerified) {
                        Box(Modifier.width(4.dp))
                        VerifiedBadge(14, label = stringResource(R.string.verified))
                    }
                }
                Text("@${person.username}", color = c.textSecondary, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        if (person.id != vm.viewerId) {
            val busy = vm.busy == person.id
            PillButton(
                followLabel(busy, person.following, person.requested), filled = !(person.following || person.requested),
                enabled = !busy, height = 34.dp, fontSize = 13, modifier = Modifier.padding(start = 10.dp),
            ) { vm.follow(person) }
        }
    }
}
