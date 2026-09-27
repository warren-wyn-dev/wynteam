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
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import io.wyn.wyn.core.data.PreferencesAccountStore
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
                    Repositories.supabase(SupabaseProvider.client),
                    onExit = ::finish,
                )
            }
        }
    }
}

@Composable
fun WynosApp(
    vm: AccountFlowViewModel,
    repos: Repositories,
    onExit: () -> Unit,
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
            SignedInApp(vm, userId, repos)
        }
    }
}
