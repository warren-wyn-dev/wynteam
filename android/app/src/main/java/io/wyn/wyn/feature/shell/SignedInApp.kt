package io.wyn.wyn.feature.shell

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import io.github.jan.supabase.SupabaseClient
import io.wyn.wyn.R
import io.wyn.wyn.core.data.ComposerRepository
import io.wyn.wyn.core.data.EngagementSync
import io.wyn.wyn.core.data.FeedRepository
import io.wyn.wyn.core.data.FollowKind
import io.wyn.wyn.core.data.PostRepository
import io.wyn.wyn.core.data.ProfileRepository
import io.wyn.wyn.core.data.QuoteRepository
import io.wyn.wyn.core.data.SupabaseComposerRepository
import io.wyn.wyn.core.data.SupabaseFeedRepository
import io.wyn.wyn.core.data.SupabasePostRepository
import io.wyn.wyn.core.data.SupabaseProfileRepository
import io.wyn.wyn.core.data.SupabaseQuoteRepository
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.core.data.NotificationItem
import io.wyn.wyn.core.data.NotificationRepository
import io.wyn.wyn.core.data.SupabaseNotificationRepository
import io.wyn.wyn.core.push.PushController
import io.wyn.wyn.core.push.PushEvents
import io.wyn.wyn.core.push.PushTarget
import io.wyn.wyn.feature.notifications.NotificationSettingsScreen
import io.wyn.wyn.feature.notifications.NotificationSettingsViewModel
import io.wyn.wyn.feature.notifications.NotificationsScreen
import io.wyn.wyn.feature.notifications.NotificationsViewModel
import io.wyn.wyn.feature.notifications.PushPromptHost
import io.wyn.wyn.feature.notifications.UnreadBadge
import androidx.compose.foundation.border
import androidx.lifecycle.compose.LifecycleResumeEffect
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import io.wyn.wyn.feature.auth.AccountFlowViewModel
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.compose.ComposerExit
import io.wyn.wyn.feature.compose.ComposerScreen
import io.wyn.wyn.feature.compose.ComposerViewModel
import io.wyn.wyn.feature.compose.DraftsScreen
import io.wyn.wyn.feature.compose.DraftsViewModel
import io.wyn.wyn.feature.compose.PhotoReader
import io.wyn.wyn.feature.home.HomeNavigation
import io.wyn.wyn.feature.home.HomeScreen
import io.wyn.wyn.feature.home.HomeViewModel
import io.wyn.wyn.feature.post.PostDetailScreen
import io.wyn.wyn.feature.post.PostDetailViewModel
import io.wyn.wyn.feature.profile.AccountSwitcher
import io.wyn.wyn.feature.profile.EditProfileScreen
import io.wyn.wyn.feature.profile.EditProfileViewModel
import io.wyn.wyn.feature.profile.FollowListScreen
import io.wyn.wyn.feature.profile.FollowListViewModel
import io.wyn.wyn.feature.profile.ProfileNavigation
import io.wyn.wyn.feature.profile.ProfileScreen
import io.wyn.wyn.feature.profile.ProfileViewModel
import io.wyn.wyn.feature.quote.QuoteDetailScreen
import io.wyn.wyn.feature.quote.QuoteDetailViewModel

/** Every data source the signed-in app uses; tests pass fakes. */
data class Repositories(
    val feed: FeedRepository,
    val posts: PostRepository,
    val composer: ComposerRepository,
    val quotes: QuoteRepository,
    val profiles: ProfileRepository,
    val notifications: NotificationRepository,
    val push: PushController? = null,
) {
    companion object {
        fun supabase(client: SupabaseClient?, push: PushController? = null): Repositories {
            val quotes = SupabaseQuoteRepository(client)
            return Repositories(
                feed = SupabaseFeedRepository(client, quotes),
                posts = SupabasePostRepository(client),
                composer = SupabaseComposerRepository(client) { bytes, type -> PhotoReader.describe(bytes, type) },
                quotes = quotes,
                profiles = SupabaseProfileRepository(client, quotes),
                notifications = SupabaseNotificationRepository(client),
                push = push,
            )
        }
    }
}

/** A screen above the tabs. Saved as text so it survives process death. */
private sealed interface Screen {
    data class Post(val id: String) : Screen
    data class Quote(val id: String) : Screen
    data class Profile(val id: String) : Screen
    data class Follows(val id: String, val kind: FollowKind) : Screen
    data object EditProfile : Screen
    data object Settings : Screen
    data object Notifications : Screen
    data object NotificationSettings : Screen
    data object Drafts : Screen
    data class Coming(val message: Int) : Screen

    fun encode(): String = when (this) {
        is Post -> "post:$id"
        is Quote -> "quote:$id"
        is Profile -> "profile:$id"
        is Follows -> "follows:$id:${kind.name}"
        EditProfile -> "edit"
        Settings -> "settings"
        Notifications -> "notifications"
        NotificationSettings -> "notification-settings"
        Drafts -> "drafts"
        is Coming -> "coming:$message"
    }

    companion object {
        fun decode(value: String): Screen? {
            val parts = value.split(':')
            return when (parts[0]) {
                "post" -> parts.getOrNull(1)?.let(::Post)
                "quote" -> parts.getOrNull(1)?.let(::Quote)
                "profile" -> parts.getOrNull(1)?.let(::Profile)
                "follows" -> if (parts.size == 3) runCatching { Follows(parts[1], FollowKind.valueOf(parts[2])) }.getOrNull() else null
                "edit" -> EditProfile
                "settings" -> Settings
                "notifications" -> Notifications
                "notification-settings" -> NotificationSettings
                "drafts" -> Drafts
                "coming" -> parts.getOrNull(1)?.toIntOrNull()?.let(::Coming)
                else -> null
            }
        }
    }
}

/**
 * The signed-in app: the five tabs with a stack of screens above them
 * (post, Quote, profile, follow lists, edit profile, drafts, composer).
 */
@Composable
fun SignedInApp(
    vm: AccountFlowViewModel,
    userId: String,
    repos: Repositories,
    pushTarget: PushTarget? = null,
    onPushTargetHandled: () -> Unit = {},
) {
    // One feed and one engagement channel per account: switching accounts starts fresh.
    val sync = remember(userId) { EngagementSync() }
    val home: HomeViewModel = viewModel(key = "home:$userId", factory = viewModelFactory { initializer { HomeViewModel(repos.feed, userId, sync, repos.quotes) } })
    val me: ProfileViewModel = viewModel(
        key = "profile:$userId:$userId",
        factory = viewModelFactory { initializer { ProfileViewModel(repos.profiles, repos.feed, userId, userId, sync, repos.quotes) } },
    )
    var saved by rememberSaveable(userId) { mutableStateOf("") }
    val stack = saved.split('\n').filter { it.isNotEmpty() }.mapNotNull(Screen::decode)
    fun push(screen: Screen) { saved = (stack + screen).joinToString("\n") { it.encode() } }
    fun pop() { saved = stack.dropLast(1).joinToString("\n") { it.encode() } }
    // null: closed; "" : new post; otherwise the draft being continued.
    var composer by rememberSaveable(userId) { mutableStateOf<String?>(null) }
    var composerSession by rememberSaveable(userId) { mutableIntStateOf(0) }
    var editSession by rememberSaveable(userId) { mutableIntStateOf(0) }
    fun openComposer(draftId: String?) {
        composerSession += 1
        composer = draftId.orEmpty()
    }
    fun openProfile(id: String) = push(Screen.Profile(id))
    val badge: UnreadBadge = viewModel(key = "badge:$userId", factory = viewModelFactory { initializer { UnreadBadge(repos.notifications, userId) } })
    // web notification-count.ts: while the app is open, a push for this account, and a gentle poll.
    LifecycleResumeEffect(userId) {
        badge.refresh()
        onPauseOrDispose {}
    }
    LaunchedEffect(userId) {
        launch { PushEvents.received.collect { recipient -> if (recipient == userId) badge.refresh() } }
        while (true) {
            delay(12_000)
            badge.refresh()
        }
    }
    fun openNotification(item: NotificationTargetLike) {
        when {
            item.conversationId != null -> push(Screen.Coming(R.string.coming_chat))
            item.dropId != null -> push(Screen.Post(item.dropId!!))
            item.popId != null -> push(Screen.Coming(R.string.coming_pops))
            item.clubPostId != null || item.clubId != null -> push(Screen.Coming(R.string.coming_clubs))
            item.actorId != null -> push(Screen.Profile(item.actorId!!))
        }
    }
    // A tapped push for this account opens where the notification leads.
    LaunchedEffect(pushTarget, userId) {
        val target = pushTarget ?: return@LaunchedEffect
        if (target.recipientId == userId) {
            badge.refresh()
            openNotification(NotificationTargetLike.of(target))
        }
        onPushTargetHandled()
    }
    val feedNav = HomeNavigation(
        onCompose = { openComposer(null) },
        onNotifications = { push(Screen.Notifications) },
        onOpenPost = { push(Screen.Post(it.id)) },
        onOpenProfile = ::openProfile,
        onOpenQuote = { row -> row.redropId?.let { push(Screen.Quote(it)) } },
    )
    val switcher = AccountSwitcher(
        accounts = vm.savedAccounts, activeId = vm.activeUserId, busy = vm.homeBusy, message = vm.homeMessage,
        switchTo = vm::switchTo, add = vm::addAccount, remove = vm::removeAccount, clearMessage = vm::clearHomeMessage,
    )
    fun profileNav(profileId: String, back: (() -> Unit)?) = ProfileNavigation(
        feed = feedNav,
        onBack = back,
        onEdit = { editSession += 1; push(Screen.EditProfile) },
        onFollows = { kind -> push(Screen.Follows(profileId, kind)) },
        onMessage = { push(Screen.Coming(R.string.coming_chat)) },
        onSettings = { push(Screen.Settings) },
    )

    MainShell(
        home = { HomeScreen(home, feedNav, notificationCount = badge.count) },
        profile = { ProfileScreen(me, profileNav(userId, back = null), switcher) },
        onCompose = { openComposer(null) },
    )

    stack.lastOrNull()?.let { screen ->
        BackHandler { pop() }
        when (screen) {
            is Screen.Post -> {
                val detail: PostDetailViewModel = viewModel(
                    key = "post:$userId:${screen.id}",
                    factory = viewModelFactory { initializer { PostDetailViewModel(repos.posts, repos.feed, userId, screen.id, sync) } },
                )
                PostDetailScreen(detail, onBack = ::pop, onOpenAuthor = ::openProfile)
            }
            is Screen.Quote -> {
                val detail: QuoteDetailViewModel = viewModel(
                    key = "quote:$userId:${screen.id}",
                    factory = viewModelFactory { initializer { QuoteDetailViewModel(repos.quotes, userId, screen.id) } },
                )
                val identity = home.identity
                QuoteDetailScreen(
                    detail,
                    onBack = ::pop,
                    onOpenDrop = { dropId -> push(Screen.Post(dropId)) },
                    myAvatar = identity?.avatarUrl,
                    myName = identity?.displayName?.trim()?.takeIf { it.isNotEmpty() } ?: identity?.username ?: stringResource(R.string.your_account),
                )
            }
            is Screen.Profile -> {
                val profile: ProfileViewModel = if (screen.id == userId) me else viewModel(
                    key = "profile:$userId:${screen.id}",
                    factory = viewModelFactory { initializer { ProfileViewModel(repos.profiles, repos.feed, userId, screen.id, sync, repos.quotes) } },
                )
                ProfileScreen(profile, profileNav(screen.id, back = ::pop), switcher.takeIf { screen.id == userId })
            }
            is Screen.Follows -> {
                val list: FollowListViewModel = viewModel(
                    key = "follows:$userId:${screen.id}",
                    factory = viewModelFactory { initializer { FollowListViewModel(repos.profiles, repos.feed, userId, screen.id, screen.kind) } },
                )
                FollowListScreen(list, onBack = ::pop, onOpenProfile = ::openProfile)
            }
            Screen.EditProfile -> {
                val profile = me.summary?.profile
                if (profile == null) {
                    LaunchedEffect(Unit) { pop() }
                } else {
                    val edit: EditProfileViewModel = viewModel(
                        key = "edit:$userId:$editSession",
                        factory = viewModelFactory { initializer { EditProfileViewModel(repos.profiles, userId, profile) } },
                    )
                    fun close() {
                        pop()
                        me.reloadSummary()
                        home.reloadIdentity()
                    }
                    LaunchedEffect(edit.done) { if (edit.done) close() }
                    EditProfileScreen(edit, onClose = ::close)
                }
            }
            Screen.Settings -> BackTitled(stringResource(R.string.settings), ::pop) {
                SettingsRoot(vm, onNotifications = { push(Screen.NotificationSettings) })
            }
            Screen.Notifications -> {
                val list: NotificationsViewModel = viewModel(
                    key = "notifications:$userId",
                    factory = viewModelFactory { initializer { NotificationsViewModel(repos.notifications, userId, onMarkedRead = badge::markedRead) } },
                )
                LifecycleResumeEffect(list) {
                    list.onHint()
                    onPauseOrDispose {}
                }
                LaunchedEffect(list) { PushEvents.received.collect { recipient -> if (recipient == userId) list.onHint() } }
                NotificationsScreen(list, onBack = ::pop, onOpen = { openNotification(NotificationTargetLike.of(it)) })
            }
            Screen.NotificationSettings -> {
                val settings: NotificationSettingsViewModel = viewModel(
                    key = "notification-settings:$userId",
                    factory = viewModelFactory { initializer { NotificationSettingsViewModel(repos.notifications, repos.push, userId) } },
                )
                NotificationSettingsScreen(settings, repos.push, onBack = ::pop)
            }
            Screen.Drafts -> {
                val drafts: DraftsViewModel = viewModel(
                    key = "drafts:$userId:$composerSession",
                    factory = viewModelFactory { initializer { DraftsViewModel(repos.composer, userId) } },
                )
                DraftsScreen(drafts, onBack = ::pop, onOpen = { id -> pop(); openComposer(id) })
            }
            is Screen.Coming -> BackTitled("", ::pop) { ComingSoon(screen.message) }
        }
    }

    // web PushPrompt: main screens only, never above another screen or the composer.
    if (stack.isEmpty() && composer == null) PushPromptHost(repos.push, userId)

    composer?.let { draftId ->
        val compose: ComposerViewModel = viewModel(
            key = "composer:$userId:$composerSession",
            factory = viewModelFactory { initializer { ComposerViewModel(repos.composer, repos.feed, userId, draftId.ifEmpty { null }) } },
        )
        LaunchedEffect(compose.exit) {
            when (compose.exit) {
                null -> Unit
                ComposerExit.Published -> { composer = null; home.refresh(); me.refresh() }
                ComposerExit.Drafts -> { composer = null; composerSession += 1; push(Screen.Drafts) }
                ComposerExit.Closed -> composer = null
            }
        }
        ComposerScreen(compose)
    }
}

/** What a notification or a push points at (web notifications-route open()). */
private data class NotificationTargetLike(
    val conversationId: String?,
    val dropId: String?,
    val popId: String?,
    val clubPostId: String?,
    val clubId: String?,
    val actorId: String?,
) {
    companion object {
        fun of(item: NotificationItem) = NotificationTargetLike(item.conversationId, item.dropId, item.popId, item.clubPostId, item.clubId, item.actorId)
        fun of(target: PushTarget) = NotificationTargetLike(target.conversationId, target.dropId, target.popId, target.clubPostId, target.clubId, target.actorId)
    }
}

/** Settings until M7: notifications, accounts on this phone, sign out and the version. */
@Composable
private fun SettingsRoot(vm: AccountFlowViewModel, onNotifications: () -> Unit) {
    val c = Wyn.colors
    Column(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(12.dp)) {
        androidx.compose.foundation.layout.Row(
            Modifier.fillMaxWidth().clip(androidx.compose.foundation.shape.RoundedCornerShape(14.dp))
                .border(1.dp, c.border, androidx.compose.foundation.shape.RoundedCornerShape(14.dp))
                .clickable(role = Role.Button, onClick = onNotifications).padding(horizontal = 14.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(WynIcons.Bell, contentDescription = null, tint = c.text, modifier = Modifier.size(19.dp))
            Text(stringResource(R.string.notifications_title), color = c.text, fontSize = 15.sp, modifier = Modifier.weight(1f).padding(start = 12.dp))
            Icon(WynIcons.ChevronRight, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(18.dp))
        }
        io.wyn.wyn.feature.profile.PillButton(stringResource(R.string.sign_out_label), filled = false, outlined = true, enabled = !vm.homeBusy, modifier = Modifier.fillMaxWidth()) { vm.signOut() }
        io.wyn.wyn.core.design.ErrorText(vm.homeMessage.text())
        Text(stringResource(R.string.version_label), color = c.textMuted, fontSize = 11.sp, modifier = Modifier.align(Alignment.CenterHorizontally))
    }
}

/** A plain back bar above a screen that has none of its own. */
@Composable
private fun BackTitled(title: String, onBack: () -> Unit, content: @Composable () -> Unit) {
    val c = Wyn.colors
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding()) {
        Box(Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 8.dp)) {
            val back = stringResource(R.string.back)
            Icon(
                WynIcons.Back, contentDescription = back, tint = c.text,
                modifier = Modifier.align(Alignment.CenterStart).size(44.dp).clip(CircleShape).clickable(role = Role.Button, onClickLabel = back, onClick = onBack).padding(10.dp),
            )
            Text(title, color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold, modifier = Modifier.align(Alignment.Center))
        }
        Box(Modifier.weight(1f)) { content() }
    }
}
