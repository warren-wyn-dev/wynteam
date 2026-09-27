package io.wyn.wyn.feature.shell

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.selection.selectable
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.wyn.wyn.R
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.feature.home.Badge

enum class MainTab { Home, Clubs, Post, Chat, Profile }

private val NavGrey = Color(0xFF9A9A9A)

/**
 * The signed-in app: the web's five-tab bottom navigation. Tabs whose
 * milestone has not shipped yet say so instead of showing a fake screen.
 */
@Composable
fun MainShell(
    home: @Composable () -> Unit,
    profile: @Composable () -> Unit,
    onCompose: () -> Unit,
    chatUnread: Int = 0,
    initialTab: MainTab = MainTab.Home,
) {
    var tab by rememberSaveable { mutableStateOf(initialTab) }
    Column(Modifier.fillMaxSize().background(Wyn.colors.bg).statusBarsPadding()) {
        // Screens below use safe-area padding; the tab bar already covers the navigation bar.
        Box(Modifier.weight(1f).consumeWindowInsets(WindowInsets.navigationBars)) {
            when (tab) {
                MainTab.Home -> home()
                MainTab.Profile -> profile()
                MainTab.Clubs -> ComingSoon(R.string.coming_clubs)
                MainTab.Chat -> ComingSoon(R.string.coming_chat)
                MainTab.Post -> ComingSoon(R.string.coming_compose)
            }
        }
        BottomNav(tab, chatUnread) { next -> if (next == MainTab.Post) onCompose() else tab = next }
    }
}

@Composable
private fun BottomNav(selected: MainTab, chatUnread: Int, onSelect: (MainTab) -> Unit) {
    val c = Wyn.colors
    Column(Modifier.background(c.bg).navigationBarsPadding()) {
        HorizontalDivider(color = c.border, thickness = 1.dp)
        Row(Modifier.fillMaxWidth().height(49.dp)) {
            NavItem(MainTab.Home, selected, R.string.nav_home, WynIcons.NavHome, WynIcons.NavHomeSelected, onSelect)
            NavItem(MainTab.Clubs, selected, R.string.nav_clubs, WynIcons.NavClub, WynIcons.NavClubSelected, onSelect)
            NavItem(MainTab.Post, selected, R.string.nav_post, WynIcons.NavAdd, WynIcons.NavAdd, onSelect)
            NavItem(MainTab.Chat, selected, R.string.nav_chat, WynIcons.NavChat, WynIcons.NavChatSelected, onSelect, badge = chatUnread)
            NavItem(MainTab.Profile, selected, R.string.nav_profile, WynIcons.NavProfile, WynIcons.NavProfileSelected, onSelect)
        }
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.NavItem(
    tab: MainTab,
    selected: MainTab,
    label: Int,
    icon: ImageVector,
    selectedIcon: ImageVector,
    onSelect: (MainTab) -> Unit,
    badge: Int = 0,
) {
    val c = Wyn.colors
    val active = tab == selected
    val tint = if (active) c.text else NavGrey
    Column(
        Modifier.weight(1f).fillMaxSize().selectable(active, role = Role.Tab) { onSelect(tab) }.padding(top = 3.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box {
            Icon(if (active) selectedIcon else icon, contentDescription = null, tint = tint, modifier = Modifier.size(28.dp))
            if (badge > 0) Badge(if (badge > 9) "9+" else badge.toString(), Modifier.padding(start = 15.dp).align(Alignment.TopStart))
        }
        Spacer(Modifier.height(1.dp))
        Text(stringResource(label), color = tint, fontSize = 10.sp, lineHeight = 11.sp, fontWeight = if (active) FontWeight.Bold else FontWeight.Medium)
    }
}

@Composable
fun ComingSoon(message: Int) {
    Box(Modifier.fillMaxSize().padding(32.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(stringResource(message), color = Wyn.colors.textSecondary, fontSize = 15.sp, textAlign = TextAlign.Center)
        }
    }
}
