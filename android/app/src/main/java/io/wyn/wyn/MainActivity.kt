package io.wyn.wyn

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import io.wyn.wyn.core.data.EngagementSync
import io.wyn.wyn.core.data.FeedRepository
import io.wyn.wyn.core.data.PostRepository
import io.wyn.wyn.core.data.SupabasePostRepository
import io.wyn.wyn.feature.post.PostDetailScreen
import io.wyn.wyn.feature.post.PostDetailViewModel
import androidx.compose.runtime.saveable.rememberSaveable
import io.wyn.wyn.core.data.PreferencesAccountStore
import io.wyn.wyn.core.data.SupabaseFeedRepository
import io.wyn.wyn.core.data.SupabaseAuthRepository
import io.wyn.wyn.core.data.SupabaseProvider
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynosTheme
import io.wyn.wyn.feature.account.AccountHomeScreen
import io.wyn.wyn.feature.auth.AccountFlowViewModel
import io.wyn.wyn.feature.auth.CheckEmailScreen
import io.wyn.wyn.feature.auth.ForgotPasswordScreen
import io.wyn.wyn.feature.auth.LoginScreen
import io.wyn.wyn.feature.auth.OnboardingScreen
import io.wyn.wyn.feature.auth.Route
import io.wyn.wyn.feature.auth.SessionCheckFailedScreen
import io.wyn.wyn.feature.auth.SignupStep1Screen
import io.wyn.wyn.feature.auth.SignupStep2Screen
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.welcome.InviteState
import io.wyn.wyn.feature.home.HomeNavigation
import io.wyn.wyn.feature.home.HomeScreen
import io.wyn.wyn.feature.home.HomeViewModel
import io.wyn.wyn.feature.shell.MainShell
import io.wyn.wyn.feature.welcome.WelcomeScreen
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val factory = viewModelFactory {
            initializer {
                AccountFlowViewModel(
                    SupabaseAuthRepository(SupabaseProvider.client),
                    PreferencesAccountStore(applicationContext),
                    SupabaseProvider.isConfigured,
                )
            }
        }
        setContent {
            WynosTheme {
                WynosApp(
                    viewModel(factory = factory),
                    SupabaseFeedRepository(SupabaseProvider.client),
                    SupabasePostRepository(SupabaseProvider.client),
                    onExit = ::finish,
                )
            }
        }
    }
}

@Composable
fun WynosApp(vm: AccountFlowViewModel, feed: FeedRepository, posts: PostRepository, onExit: () -> Unit) {
    val back: () -> Unit = { if (!vm.back()) onExit() }
    BackHandler(enabled = vm.stack.size > 1 || (vm.route as? Route.Login)?.addingAccount == true) { back() }
    when (val route = vm.route) {
        Route.Booting -> Box(Modifier.fillMaxSize().background(Wyn.colors.bg))
        Route.SessionCheckFailed -> SessionCheckFailedScreen(vm::boot)
        Route.Welcome -> WelcomeScreen(
            onCreateAccount = { vm.navigate(Route.SignupStep1) },
            onSignIn = { vm.navigate(Route.Login()) },
            onGoogle = vm::signInWithGoogle,
            configured = vm.configured,
            gate = vm.inviteGate,
            error = vm.welcomeError.text(),
            invite = InviteState(vm.inviteCode, vm::updateInviteCode, vm::submitInviteCode, vm.inviteLoading, vm.inviteError.text()),
        )
        is Route.Login -> LoginScreen(vm, back)
        Route.SignupStep1 -> SignupStep1Screen(vm, back)
        Route.SignupStep2 -> SignupStep2Screen(vm, back)
        is Route.CheckEmail -> CheckEmailScreen(route.email, back) { vm.navigate(Route.Login()) }
        Route.ForgotPassword -> ForgotPasswordScreen(vm, back)
        Route.Onboarding -> OnboardingScreen(vm)
        Route.Home -> {
            val userId = vm.activeUserId ?: return
            // One feed and one engagement channel per account: switching accounts starts fresh.
            val sync = remember(userId) { EngagementSync() }
            val home: HomeViewModel = viewModel(key = "home:$userId", factory = viewModelFactory { initializer { HomeViewModel(feed, userId, sync) } })
            var composeNotice by remember { mutableStateOf(false) }
            var openPost by rememberSaveable(userId) { mutableStateOf<String?>(null) }
            MainShell(
                home = {
                    HomeScreen(
                        home,
                        HomeNavigation(
                            onCompose = { composeNotice = true },
                            onQuote = { composeNotice = true },
                            onOpenPost = { openPost = it.id },
                        ),
                    )
                },
                profile = { AccountHomeScreen(vm) },
                onCompose = { composeNotice = true },
            )
            openPost?.let { dropId ->
                BackHandler { openPost = null }
                val detail: PostDetailViewModel = viewModel(
                    key = "post:$userId:$dropId",
                    factory = viewModelFactory { initializer { PostDetailViewModel(posts, feed, userId, dropId, sync) } },
                )
                PostDetailScreen(detail, onBack = { openPost = null })
            }
            if (composeNotice) {
                LaunchedEffect(Unit) { delay(2500); composeNotice = false }
                ComposeComingSoon()
            }
        }
    }
}

/** Until the composer lands (M2c), "post" says so instead of opening an empty screen. */
@Composable
private fun ComposeComingSoon() {
    Box(Modifier.fillMaxSize().padding(bottom = 80.dp, start = 14.dp, end = 14.dp), contentAlignment = androidx.compose.ui.Alignment.BottomCenter) {
        Text(
            stringResource(R.string.coming_compose),
            color = Wyn.colors.bg, fontSize = 13.sp,
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Wyn.colors.text).padding(16.dp),
        )
    }
}
