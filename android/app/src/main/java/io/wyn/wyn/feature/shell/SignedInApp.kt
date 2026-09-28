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
import io.wyn.wyn.core.data.ChatRepository
import io.wyn.wyn.core.data.SupabaseChatRepository
import io.wyn.wyn.core.data.ClubRepository
import io.wyn.wyn.core.data.SupabaseClubRepository
import io.wyn.wyn.core.data.DiscoveryRepository
import io.wyn.wyn.core.data.SupabaseDiscoveryRepository
import io.wyn.wyn.core.data.DevicePreferences
import io.wyn.wyn.core.data.SettingsRepository
import io.wyn.wyn.core.data.SupabaseSettingsRepository
import io.wyn.wyn.feature.chat.WyniiViewModel
import io.wyn.wyn.feature.settings.DeviceAppearance
import io.wyn.wyn.feature.settings.InMemoryAppearance
import io.wyn.wyn.feature.settings.SettingsActions
import io.wyn.wyn.feature.settings.SettingsScreen
import io.wyn.wyn.feature.settings.SettingsViewModel
import androidx.compose.ui.platform.LocalContext
import io.wyn.wyn.feature.search.BookmarksScreen
import io.wyn.wyn.feature.search.BookmarksViewModel
import io.wyn.wyn.feature.search.SearchNavigation
import io.wyn.wyn.feature.search.SearchPostsViewModel
import io.wyn.wyn.feature.search.SearchScreen
import io.wyn.wyn.feature.search.SearchViewModel
import io.wyn.wyn.feature.search.TrendingScreen
import io.wyn.wyn.feature.search.TrendingViewModel
import io.wyn.wyn.feature.chat.ChatInboxScreen
import io.wyn.wyn.feature.clubs.ClubFeedViewModel
import io.wyn.wyn.feature.clubs.ClubInviteScreen
import io.wyn.wyn.feature.clubs.ClubInviteViewModel
import io.wyn.wyn.feature.clubs.ClubPostScreen
import io.wyn.wyn.feature.clubs.ClubPostViewModel
import io.wyn.wyn.feature.clubs.ClubScreen
import io.wyn.wyn.feature.clubs.ClubTab
import io.wyn.wyn.feature.clubs.ClubViewModel
import io.wyn.wyn.feature.clubs.CreateClubScreen
import io.wyn.wyn.feature.clubs.CreateClubViewModel
import io.wyn.wyn.feature.clubs.ExploreClubsScreen
import io.wyn.wyn.feature.clubs.ExploreClubsViewModel
import io.wyn.wyn.feature.clubs.MyClubsScreen
import io.wyn.wyn.feature.clubs.MyClubsViewModel
import io.wyn.wyn.feature.chat.ChatInboxViewModel
import io.wyn.wyn.feature.chat.ConversationScreen
import io.wyn.wyn.feature.chat.ConversationViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import io.wyn.wyn.core.data.NotificationRepository
import io.wyn.wyn.core.data.SupabaseNotificationRepository
import io.wyn.wyn.core.push.PushController
import io.wyn.wyn.core.push.PushEvents
import io.wyn.wyn.core.push.PushTarget
import io.wyn.wyn.core.link.AppLink
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
    val chat: ChatRepository,
    val clubs: ClubRepository,
    val discovery: DiscoveryRepository,
    val settings: SettingsRepository,
    val push: PushController? = null,
    /** This phone's theme and language (null in tests: they follow the phone). */
    val device: DevicePreferences? = null,
) {
    companion object {
        fun supabase(client: SupabaseClient?, push: PushController? = null, device: DevicePreferences? = null): Repositories {
            val quotes = SupabaseQuoteRepository(client)
            val profiles = SupabaseProfileRepository(client, quotes)
            val clubs = SupabaseClubRepository(client)
            return Repositories(
                feed = SupabaseFeedRepository(client, quotes),
                posts = SupabasePostRepository(client),
                composer = SupabaseComposerRepository(client) { bytes, type -> PhotoReader.describe(bytes, type) },
                quotes = quotes,
                profiles = profiles,
                notifications = SupabaseNotificationRepository(client),
                chat = SupabaseChatRepository(client),
                clubs = clubs,
                discovery = SupabaseDiscoveryRepository(client, profiles, clubs, quotes),
                settings = SupabaseSettingsRepository(client),
                push = push,
                device = device,
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
    /** A conversation, or a new one with [user] when [id] is null (web /chat/new?user=). */
    data class Conversation(val id: String?, val user: String?) : Screen
    data class Club(val id: String) : Screen
    data class ClubPost(val id: String) : Screen
    data object CreateClub : Screen
    data object MyClubs : Screen
    data class ClubInvite(val code: String) : Screen
    data object Search : Screen
    data object Trending : Screen
    data object Bookmarks : Screen

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
        is Conversation -> "chat:${id ?: "-"}:${user ?: "-"}"
        is Club -> "club:$id"
        is ClubPost -> "club-post:$id"
        CreateClub -> "club-new"
        MyClubs -> "clubs-mine"
        // An invite code is free text; keep it on one line and without ':'.
        is ClubInvite -> "club-invite:" + java.net.URLEncoder.encode(code, "UTF-8")
        Search -> "search"
        Trending -> "trending"
        Bookmarks -> "bookmarks"
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
                "chat" -> if (parts.size == 3) Conversation(parts[1].takeIf { it != "-" }, parts[2].takeIf { it != "-" }) else null
                "club" -> parts.getOrNull(1)?.let(::Club)
                "club-post" -> parts.getOrNull(1)?.let(::ClubPost)
                "club-new" -> CreateClub
                "clubs-mine" -> MyClubs
                "club-invite" -> parts.getOrNull(1)?.let { ClubInvite(java.net.URLDecoder.decode(it, "UTF-8")) }
                "search" -> Search
                "trending" -> Trending
                "bookmarks" -> Bookmarks
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
    appLink: AppLink? = null,
    onAppLinkHandled: () -> Unit = {},
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
    fun replaceTop(screen: Screen) { saved = (stack.dropLast(1) + screen).joinToString("\n") { it.encode() } }
    // null: closed; "" : new post; otherwise the draft being continued.
    var composer by rememberSaveable(userId) { mutableStateOf<String?>(null) }
    var composerSession by rememberSaveable(userId) { mutableIntStateOf(0) }
    var editSession by rememberSaveable(userId) { mutableIntStateOf(0) }
    var clubSession by rememberSaveable(userId) { mutableIntStateOf(0) }
    var settingsSession by rememberSaveable(userId) { mutableIntStateOf(0) }
    val appearance = remember(repos.device) { repos.device?.let(::DeviceAppearance) ?: InMemoryAppearance() }
    val activity = androidx.activity.compose.LocalActivity.current
    // web ThemeSync / LanguageSync: the account's saved choice wins and is kept on this phone;
    // an account that never chose drops the previous account's choice. A failed read keeps it.
    LaunchedEffect(userId) {
        runCatching { repos.settings.theme(userId) }.onSuccess { saved -> if (saved != appearance.theme) appearance.applyTheme(saved) }
        runCatching { repos.settings.language(userId) }.onSuccess { saved -> if (appearance.applyLanguage(saved)) activity?.recreate() }
    }
    fun openComposer(draftId: String?) {
        composerSession += 1
        composer = draftId.orEmpty()
    }
    fun openProfile(id: String) = push(Screen.Profile(id))
    fun openSettings() { settingsSession += 1; push(Screen.Settings) }
    val badge: UnreadBadge = viewModel(key = "badge:$userId", factory = viewModelFactory { initializer { UnreadBadge(repos.notifications, userId) } })
    // web notification-count.ts: while the app is open, a push for this account, and a gentle poll.
    LifecycleResumeEffect(userId) {
        badge.refresh()
        onPauseOrDispose {}
    }
    val inbox: ChatInboxViewModel = viewModel(key = "chat-inbox:$userId", factory = viewModelFactory { initializer { ChatInboxViewModel(repos.chat, userId) } })
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(userId) {
        launch {
            PushEvents.received.collect { recipient ->
                if (recipient == userId) {
                    badge.refresh()
                    inbox.load()
                }
            }
        }
        // Only while the app is on screen, like the web's visible-only polling.
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            var tick = 0
            while (true) {
                delay(12_000)
                badge.refresh()
                if (++tick % 2 == 0) inbox.load()
            }
        }
    }
    fun openNotification(item: NotificationTargetLike) {
        when {
            item.conversationId != null -> push(Screen.Conversation(item.conversationId, item.actorId))
            item.dropId != null -> push(Screen.Post(item.dropId!!))
            // web PopUnavailableRoute: Pops are not part of Web Beta 1.
            item.popId != null -> push(Screen.Coming(R.string.pop_unavailable))
            item.clubPostId != null -> push(Screen.ClubPost(item.clubPostId!!))
            item.clubId != null -> push(Screen.Club(item.clubId!!))
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
    // A wynos.online link opens the same screen the web page shows.
    LaunchedEffect(appLink, userId) {
        when (val link = appLink ?: return@LaunchedEffect) {
            is AppLink.Drop -> push(Screen.Post(link.id))
            is AppLink.Quote -> push(Screen.Quote(link.id))
            is AppLink.Club -> push(Screen.Club(link.id))
            is AppLink.ClubPost -> push(Screen.ClubPost(link.id))
            is AppLink.ClubInvite -> push(Screen.ClubInvite(link.code))
        }
        onAppLinkHandled()
    }
    var shellTab by rememberSaveable(userId) { mutableStateOf(MainTab.Home) }
    var drawerOpen by rememberSaveable(userId) { mutableStateOf(false) }
    val feedNav = HomeNavigation(
        onCompose = { openComposer(null) },
        onNotifications = { push(Screen.Notifications) },
        onOpenPost = { push(Screen.Post(it.id)) },
        onOpenProfile = ::openProfile,
        onOpenQuote = { row -> row.redropId?.let { push(Screen.Quote(it)) } },
        onOpenClubPost = { push(Screen.ClubPost(it)) },
        onExploreClubs = { shellTab = MainTab.Clubs },
        onSearch = { push(Screen.Search) },
        onMenu = { drawerOpen = true },
    )
    // Club likes made on one screen show on the others (web club-engagement-sync).
    val clubSync = remember(userId) { EngagementSync() }
    val clubFeed: ClubFeedViewModel = viewModel(key = "club-feed:$userId", factory = viewModelFactory { initializer { ClubFeedViewModel(repos.clubs, userId, clubSync) } })
    val switcher = AccountSwitcher(
        accounts = vm.savedAccounts, activeId = vm.activeUserId, busy = vm.homeBusy, message = vm.homeMessage,
        switchTo = vm::switchTo, add = vm::addAccount, remove = vm::removeAccount, clearMessage = vm::clearHomeMessage,
    )
    fun profileNav(profileId: String, back: (() -> Unit)?) = ProfileNavigation(
        feed = feedNav,
        onBack = back,
        onEdit = { editSession += 1; push(Screen.EditProfile) },
        onFollows = { kind -> push(Screen.Follows(profileId, kind)) },
        onMessage = { push(Screen.Conversation(null, profileId)) },
        onSettings = { openSettings() },
    )

    MainShell(
        tab = shellTab,
        onTab = { shellTab = it },
        home = { HomeScreen(home, feedNav, notificationCount = badge.count, clubs = clubFeed) },
        profile = { ProfileScreen(me, profileNav(userId, back = null), switcher) },
        onCompose = { openComposer(null) },
        chatUnread = inbox.unreadCount,
        chat = {
            LifecycleResumeEffect(inbox) {
                inbox.load()
                onPauseOrDispose {}
            }
            ChatInboxScreen(inbox, onOpen = { row -> push(Screen.Conversation(row.id, row.otherUserId)) })
        },
        clubs = {
            val explore: ExploreClubsViewModel = viewModel(key = "clubs-explore:$userId", factory = viewModelFactory { initializer { ExploreClubsViewModel(repos.clubs, userId) } })
            ExploreClubsScreen(explore, onOpen = { push(Screen.Club(it)) }, onCreate = { clubSession += 1; push(Screen.CreateClub) })
        },
    )

    // web HomeDrawer: only over the tabs.
    HomeDrawer(
        open = drawerOpen && stack.isEmpty(),
        me = me.summary,
        actions = DrawerActions(
            onProfile = { openProfile(userId) },
            onExploreClubs = { shellTab = MainTab.Clubs },
            onCreateClub = { clubSession += 1; push(Screen.CreateClub) },
            onMyClubs = { push(Screen.MyClubs) },
            onBookmarks = { push(Screen.Bookmarks) },
            onSettings = { openSettings() },
        ),
        onClose = { drawerOpen = false },
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
            Screen.Settings -> {
                val settings: SettingsViewModel = viewModel(
                    key = "settings:$userId:$settingsSession",
                    factory = viewModelFactory { initializer { SettingsViewModel(repos.settings, appearance, userId) } },
                )
                SettingsScreen(
                    settings,
                    SettingsActions(
                        onClose = ::pop,
                        onNotifications = { push(Screen.NotificationSettings) },
                        onSignOut = vm::signOut,
                        onForgotPassword = { vm.navigate(io.wyn.wyn.feature.auth.Route.ForgotPassword) },
                        onOpenProfile = ::openProfile,
                    ),
                    versionLabel = stringResource(R.string.version_label),
                )
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
            is Screen.Coming -> BackTitled("WYNOS", ::pop) { ComingSoon(screen.message) }
            is Screen.Club -> {
                val club: ClubViewModel = viewModel(
                    key = "club:$userId:${screen.id}",
                    factory = viewModelFactory { initializer { ClubViewModel(repos.clubs, userId, screen.id, clubSync) } },
                )
                // web ChatTab: new messages while the chat is on screen (a realtime insert there).
                LaunchedEffect(club, club.tab) {
                    if (club.tab != ClubTab.Chat) return@LaunchedEffect
                    club.chat.reload()
                    lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
                        while (true) {
                            delay(5_000)
                            club.chat.reload()
                        }
                    }
                }
                ClubScreen(club, onBack = ::pop, onOpenProfile = ::openProfile, onOpenPost = { push(Screen.ClubPost(it)) })
            }
            is Screen.ClubPost -> {
                val post: ClubPostViewModel = viewModel(
                    key = "club-post:$userId:${screen.id}",
                    factory = viewModelFactory { initializer { ClubPostViewModel(repos.clubs, screen.id) } },
                )
                ClubPostScreen(post, onBack = ::pop)
            }
            Screen.CreateClub -> {
                val create: CreateClubViewModel = viewModel(
                    key = "club-new:$userId:$clubSession",
                    factory = viewModelFactory { initializer { CreateClubViewModel(repos.clubs, userId) } },
                )
                // web router.replace(`/club/<id>`): the new Club replaces the form.
                CreateClubScreen(create, onBack = ::pop, onCreated = { id -> replaceTop(Screen.Club(id)) })
            }
            Screen.MyClubs -> {
                val mine: MyClubsViewModel = viewModel(key = "clubs-mine:$userId", factory = viewModelFactory { initializer { MyClubsViewModel(repos.clubs, userId) } })
                MyClubsScreen(mine, onBack = ::pop, onOpen = { push(Screen.Club(it)) })
            }
            Screen.Search -> {
                val search: SearchViewModel = viewModel(key = "search:$userId", factory = viewModelFactory { initializer { SearchViewModel(repos.discovery, repos.feed, userId) } })
                val posts: SearchPostsViewModel = viewModel(
                    key = "search-posts:$userId",
                    factory = viewModelFactory { initializer { SearchPostsViewModel(repos.discovery, repos.feed, userId, sync, repos.quotes) } },
                )
                SearchScreen(
                    search, posts,
                    SearchNavigation(
                        feed = feedNav, onBack = ::pop, onOpenProfile = ::openProfile,
                        onOpenClub = { push(Screen.Club(it)) }, onTrending = { push(Screen.Trending) },
                    ),
                    myAvatar = home.identity?.avatarUrl, myName = home.identity?.displayName?.trim()?.takeIf { it.isNotEmpty() } ?: home.identity?.username,
                )
            }
            Screen.Trending -> {
                val trending: TrendingViewModel = viewModel(key = "trending:$userId", factory = viewModelFactory { initializer { TrendingViewModel(repos.discovery) } })
                TrendingScreen(trending, onBack = ::pop)
            }
            Screen.Bookmarks -> {
                val saved: BookmarksViewModel = viewModel(
                    key = "bookmarks:$userId",
                    factory = viewModelFactory { initializer { BookmarksViewModel(repos.discovery, repos.feed, userId, sync, repos.quotes) } },
                )
                // web: every visit reloads (quietly when a list is already on screen).
                LaunchedEffect(saved) { if (saved.snapshot != null) saved.load() }
                BookmarksScreen(
                    saved, feedNav, onBack = ::pop,
                    myAvatar = home.identity?.avatarUrl, myName = home.identity?.displayName?.trim()?.takeIf { it.isNotEmpty() } ?: home.identity?.username,
                )
            }
            is Screen.ClubInvite -> {
                val invite: ClubInviteViewModel = viewModel(
                    key = "club-invite:$userId:${screen.code}",
                    factory = viewModelFactory { initializer { ClubInviteViewModel(repos.clubs, screen.code) } },
                )
                ClubInviteScreen(invite, onBack = ::pop, onOpenClub = { push(Screen.Club(it)) })
            }
            is Screen.Conversation -> {
                val conversation: ConversationViewModel = viewModel(
                    key = "chat:$userId:${screen.id ?: "new:" + screen.user}",
                    factory = viewModelFactory {
                        initializer { ConversationViewModel(repos.chat, repos.profiles, repos.feed, userId, screen.id, screen.user) }
                    },
                )
                LifecycleResumeEffect(conversation) {
                    conversation.onHint()
                    onPauseOrDispose {}
                }
                LaunchedEffect(conversation) {
                    launch { PushEvents.received.collect { recipient -> if (recipient == userId) conversation.onHint() } }
                    lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
                        while (true) {
                            delay(5_000)
                            conversation.onHint()
                        }
                    }
                }
                // web WyniiConversationHeader: only for a conversation that exists.
                val pet: WyniiViewModel? = conversation.conversationId?.let { id ->
                    viewModel(key = "wynii:$userId:$id", factory = viewModelFactory { initializer { WyniiViewModel(repos.chat, userId, id) } })
                }
                ConversationScreen(
                    conversation, repos.chat,
                    onBack = { pop(); inbox.load() },
                    onOpenProfile = ::openProfile,
                    wynii = pet,
                )
            }
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
