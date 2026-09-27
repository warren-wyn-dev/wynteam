package io.wyn.wyn

import android.os.Bundle
import android.content.Intent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import io.wyn.wyn.core.push.PushSetup
import io.wyn.wyn.core.push.PushTarget
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import io.wyn.wyn.core.data.PreferencesAccountStore
import io.wyn.wyn.core.data.DevicePreferences
import io.wyn.wyn.core.data.ThemePreference
import io.wyn.wyn.core.design.ThemeChoice
import io.wyn.wyn.core.data.SupabaseAuthRepository
import io.wyn.wyn.core.data.SupabaseProvider
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynosTheme
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
import io.wyn.wyn.feature.welcome.WelcomeScreen
import io.wyn.wyn.feature.shell.Repositories
import io.wyn.wyn.feature.shell.SignedInApp

class MainActivity : ComponentActivity() {
    /** The chosen language applies before any screen is built. */
    override fun attachBaseContext(newBase: android.content.Context) {
        super.attachBaseContext(DevicePreferences.wrap(newBase))
    }

    /** A tapped push waiting to be opened (its data arrives as extras). */
    private var pushTarget by mutableStateOf<PushTarget?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        if (savedInstanceState == null) pushTarget = PushTarget.from(intent?.extras)
        val push = PushSetup.controller(applicationContext)
        val factory = viewModelFactory {
            initializer {
                AccountFlowViewModel(
                    SupabaseAuthRepository(SupabaseProvider.client),
                    PreferencesAccountStore(applicationContext),
                    SupabaseProvider.isConfigured,
                    push,
                )
            }
        }
        val device = DevicePreferences(applicationContext)
        val repos = Repositories.supabase(SupabaseProvider.client, push, device)
        setContent {
            WynosTheme(device.theme.toChoice()) {
                WynosApp(
                    viewModel(factory = factory),
                    repos,
                    onExit = ::finish,
                    pushTarget = pushTarget,
                    onPushTargetHandled = { pushTarget = null },
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        PushTarget.from(intent.extras)?.let { pushTarget = it }
    }
}

private fun ThemePreference?.toChoice(): ThemeChoice = when (this) {
    ThemePreference.Light -> ThemeChoice.Light
    ThemePreference.Dark -> ThemeChoice.Dark
    else -> ThemeChoice.System
}

@Composable
fun WynosApp(
    vm: AccountFlowViewModel,
    repos: Repositories,
    onExit: () -> Unit,
    pushTarget: PushTarget? = null,
    onPushTargetHandled: () -> Unit = {},
) {
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
            SignedInApp(vm, userId, repos, pushTarget, onPushTargetHandled)
        }
    }
}
