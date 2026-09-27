package io.wyn.wyn.feature.auth

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.wyn.wyn.R
import io.wyn.wyn.core.design.BackTopbar
import io.wyn.wyn.core.design.DarkWynColors
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.Gap
import io.wyn.wyn.core.design.ScreenTitle
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynPrimaryButton
import io.wyn.wyn.core.design.WynSelect
import io.wyn.wyn.core.design.WynTextField

@Composable
fun UiText?.text(): String? = this?.let { stringResource(it.res, *it.args.toTypedArray()) }

/** The web's AuthPhone: white page, safe areas, content scrolls above the keyboard. */
@Composable
fun AuthPage(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxSize().background(Wyn.colors.bg).safeDrawingPadding().imePadding(),
        content = content,
    )
}

@Composable
private fun ColumnScope.FormBody(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 16.dp),
        content = content,
    )
}

@Composable
private fun FooterLink(prompt: String, action: String, onClick: () -> Unit) {
    val c = Wyn.colors
    Text(
        buildAnnotatedString {
            append("$prompt ")
            withStyle(SpanStyle(color = c.text, fontWeight = FontWeight.Bold)) { append(action) }
        },
        color = c.textSecondary, fontSize = 13.sp, textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().padding(top = 16.dp).clickable(onClick = onClick),
    )
}

@Composable
fun LogoMark(height: Int) {
    val dark = Wyn.colors.bg == DarkWynColors.bg
    Image(
        painter = painterResource(R.drawable.wynos_logo_mark),
        contentDescription = "Wynos",
        colorFilter = if (dark) ColorFilter.colorMatrix(InvertMatrix) else null,
        modifier = Modifier.height(height.dp),
    )
}

private val InvertMatrix = ColorMatrix(
    floatArrayOf(
        -1f, 0f, 0f, 0f, 255f,
        0f, -1f, 0f, 0f, 255f,
        0f, 0f, -1f, 0f, 255f,
        0f, 0f, 0f, 1f, 0f,
    ),
)

// ---- Login (web LoginScreen) ------------------------------------------------------

@Composable
fun LoginScreen(vm: AccountFlowViewModel, onBack: () -> Unit) {
    AuthPage {
        BackTopbar(onBack)
        FormBody {
            Column(Modifier.fillMaxWidth().padding(bottom = 28.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                LogoMark(64)
                Gap(14)
                Text(stringResource(R.string.login_title), color = Wyn.colors.text, fontSize = 32.sp, fontWeight = FontWeight.ExtraBold)
            }
            WynTextField(
                stringResource(R.string.field_email), vm.loginEmail, vm::updateLoginEmail, "you@example.com",
                keyboardType = KeyboardType.Email,
            )
            WynTextField(
                stringResource(R.string.field_password), vm.loginPassword, vm::updateLoginPassword,
                stringResource(R.string.login_password_placeholder), password = true,
            )
            Box(Modifier.fillMaxWidth().padding(bottom = 8.dp), contentAlignment = Alignment.CenterEnd) {
                Text(
                    stringResource(R.string.login_forgot), color = Wyn.colors.text, fontSize = 13.sp, fontWeight = FontWeight.Medium,
                    modifier = Modifier.clickable { vm.navigate(Route.ForgotPassword) },
                )
            }
            WynPrimaryButton(
                stringResource(if (vm.loginLoading) R.string.login_loading else R.string.login_title),
                vm::submitLogin, enabled = !vm.loginLoading,
            )
            ErrorText(vm.loginError.text())
            FooterLink(stringResource(R.string.login_no_account), stringResource(R.string.login_create)) {
                vm.navigate(Route.SignupStep1)
            }
        }
    }
}

// ---- Signup step 1 (web SignupStep1Screen) ----------------------------------------

@Composable
fun SignupStep1Screen(vm: AccountFlowViewModel, onBack: () -> Unit) {
    val c = Wyn.colors
    val months = stringArrayResource(R.array.months)
    val yearLabel = rememberYearLabel()
    AuthPage {
        BackTopbar(onBack, step = "1/2")
        FormBody {
            ScreenTitle(stringResource(R.string.signup1_title), stringResource(R.string.signup1_subtitle))
            WynTextField(
                stringResource(R.string.field_username), vm.username, vm::updateUsername, "username", prefix = "@",
                modifier = Modifier.padding(bottom = 0.dp),
            )
            val status = when (vm.usernameState) {
                UsernameState.Invalid -> R.string.username_hint_format
                UsernameState.Taken -> R.string.err_username_taken
                UsernameState.Available -> R.string.username_available
                UsernameState.Error -> R.string.err_username_check
                UsernameState.Checking -> R.string.username_checking
                UsernameState.Idle -> null
            }
            val statusColor = when (vm.usernameState) {
                UsernameState.Available -> UsernameOk
                UsernameState.Taken, UsernameState.Invalid, UsernameState.Error -> UsernameBad
                else -> c.textSecondary
            }
            Text(
                status?.let { stringResource(it) } ?: "",
                color = statusColor, fontSize = 12.sp, lineHeight = 18.sp,
                modifier = Modifier
                    .padding(start = 2.dp, end = 2.dp, top = 0.dp, bottom = 14.dp)
                    .height(18.dp)
                    .semantics { liveRegion = LiveRegionMode.Polite },
            )
            WynTextField(
                stringResource(R.string.field_display_name), vm.displayName, vm::updateDisplayName,
                stringResource(R.string.display_name_placeholder),
            )
            io.wyn.wyn.core.design.FieldLabel(stringResource(R.string.field_birthday))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth().padding(bottom = 14.dp)) {
                WynSelect(
                    stringResource(R.string.birthday_day), stringResource(R.string.birthday_day), vm.birthDay, (1..31).toList(),
                    { it.toString() }, { vm.updateBirthDate(day = it) }, Modifier.width(74.dp),
                )
                WynSelect(
                    stringResource(R.string.birthday_month), stringResource(R.string.birthday_month), vm.birthMonth, (1..12).toList(),
                    { months[it - 1] }, { vm.updateBirthDate(month = it) }, Modifier.weight(1f),
                )
                WynSelect(
                    stringResource(R.string.birthday_year), stringResource(R.string.birthday_year), vm.birthYear, AuthRules.eligibleBirthYears(),
                    yearLabel, { vm.updateBirthDate(year = it) }, Modifier.width(92.dp),
                )
            }
            Text(
                stringResource(R.string.signup_autofollow), color = c.textSecondary, fontSize = 12.sp, lineHeight = 19.sp,
                modifier = Modifier.padding(start = 2.dp, end = 2.dp, bottom = 12.dp),
            )
            WynPrimaryButton(
                stringResource(if (vm.signupLoading) R.string.loading_generic else R.string.next),
                vm::submitStep1, enabled = !vm.signupLoading, modifier = Modifier.padding(top = 10.dp),
            )
            ErrorText(vm.signupError.text())
        }
    }
}

/** Buddhist-era years except in English (as on the web); the stored value stays Gregorian. */
@Composable
private fun rememberYearLabel(): (Int) -> String {
    val english = LocalConfiguration.current.locales[0].language == "en"
    return { year -> if (english) year.toString() else (year + AuthRules.BUDDHIST_ERA_OFFSET).toString() }
}

private val UsernameOk = androidx.compose.ui.graphics.Color(0xFF15803D)
private val UsernameBad = androidx.compose.ui.graphics.Color(0xFFDC2626)

// ---- Signup step 2 (web SignupStep2Screen) ----------------------------------------

@Composable
fun SignupStep2Screen(vm: AccountFlowViewModel, onBack: () -> Unit) {
    AuthPage {
        BackTopbar(onBack, step = "2/2")
        FormBody {
            ScreenTitle(stringResource(R.string.signup2_title), stringResource(R.string.signup2_subtitle))
            WynTextField(stringResource(R.string.field_email), vm.email, vm::updateEmail, "you@example.com", keyboardType = KeyboardType.Email)
            WynTextField(
                stringResource(R.string.field_password), vm.password, vm::updatePassword,
                stringResource(R.string.password_placeholder, AuthRules.MIN_SIGNUP_PASSWORD_LENGTH), password = true,
            )
            WynTextField(
                stringResource(R.string.field_confirm_password), vm.confirmPassword, vm::updateConfirmPassword,
                stringResource(R.string.confirm_password_placeholder), password = true,
            )
            WynPrimaryButton(
                stringResource(if (vm.signupLoading) R.string.signup2_loading else R.string.signup2_submit),
                vm::submitStep2, enabled = !vm.signupLoading, modifier = Modifier.padding(top = 10.dp),
            )
            ErrorText(vm.signupError.text())
            FooterLink(stringResource(R.string.signup_have_account), stringResource(R.string.welcome_sign_in)) {
                vm.navigate(Route.Login())
            }
        }
    }
}

@Composable
fun CheckEmailScreen(email: String, onBack: () -> Unit, onLogin: () -> Unit) {
    AuthPage {
        BackTopbar(onBack)
        Column(Modifier.padding(horizontal = 20.dp, vertical = 32.dp).semantics { liveRegion = LiveRegionMode.Polite }) {
            Text(stringResource(R.string.check_email_title), color = Wyn.colors.text, fontSize = 28.sp, fontWeight = FontWeight.ExtraBold)
            Gap(12)
            Text(stringResource(R.string.check_email_body, email), color = Wyn.colors.textSecondary, fontSize = 15.sp, lineHeight = 25.sp)
            Gap(20)
            WynPrimaryButton(stringResource(R.string.go_to_login), onLogin)
        }
    }
}

// ---- Forgot password (web ForgotPasswordScreen) -----------------------------------

@Composable
fun ForgotPasswordScreen(vm: AccountFlowViewModel, onBack: () -> Unit) {
    AuthPage {
        BackTopbar(onBack)
        FormBody {
            ScreenTitle(stringResource(R.string.forgot_title), stringResource(R.string.forgot_subtitle))
            if (vm.resetSent) {
                Text(stringResource(R.string.forgot_sent, vm.resetEmail.trim()), color = Wyn.colors.text, fontSize = 13.sp)
            } else {
                WynTextField(stringResource(R.string.field_email), vm.resetEmail, vm::updateResetEmail, "you@example.com", keyboardType = KeyboardType.Email)
                WynPrimaryButton(
                    stringResource(if (vm.resetLoading) R.string.forgot_loading else R.string.forgot_submit),
                    vm::submitReset, enabled = !vm.resetLoading, modifier = Modifier.padding(top = 10.dp),
                )
                ErrorText(vm.resetError.text())
            }
        }
    }
}

@Composable
fun SessionCheckFailedScreen(onRetry: () -> Unit) {
    AuthPage {
        Column(
            Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("WYNOS", color = Wyn.colors.text, fontSize = 24.sp, fontWeight = FontWeight.ExtraBold)
            Gap(10)
            Text(stringResource(R.string.err_session_check), color = Wyn.colors.textSecondary, fontSize = 14.sp, textAlign = TextAlign.Center)
            Gap(20)
            WynPrimaryButton(stringResource(R.string.retry), onRetry)
        }
    }
}
