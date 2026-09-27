package io.wyn.wyn.feature.welcome

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.wyn.wyn.R
import io.wyn.wyn.core.data.SupabaseProvider
import io.wyn.wyn.core.design.DarkWynColors
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynOutlineButton
import io.wyn.wyn.core.design.WynPrimaryButton
import io.wyn.wyn.core.design.WynTextField
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.feature.auth.InviteGate

/** The invite-code form shown while the invite gate is on. */
data class InviteState(
    val code: String = "",
    val onCodeChange: (String) -> Unit = {},
    val onSubmit: () -> Unit = {},
    val loading: Boolean = false,
    val error: String? = null,
)

/** Mirrors the web's WelcomeScreen (web/components/auth-flow/screens.tsx). */
@Composable
fun WelcomeScreen(
    onCreateAccount: () -> Unit,
    onSignIn: () -> Unit,
    onGoogle: () -> Unit,
    configured: Boolean = SupabaseProvider.isConfigured,
    gate: InviteGate = InviteGate.Open,
    error: String? = null,
    invite: InviteState = InviteState(),
) {
    val c = Wyn.colors
    Column(
        modifier = Modifier.fillMaxSize().background(c.bg).safeDrawingPadding().padding(horizontal = 24.dp, vertical = 32.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Spacer(Modifier.height(8.dp))
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
            Image(
                painter = painterResource(R.drawable.wynos_logo_mark),
                contentDescription = "Wynos",
                // The mark is black; like the web (theme-dark.css), invert it on dark.
                colorFilter = if (c.bg == DarkWynColors.bg) InvertColors else null,
                modifier = Modifier.height(110.dp).padding(bottom = 18.dp),
            )
            Text(
                stringResource(R.string.welcome_headline),
                color = c.text, fontSize = 28.sp, fontWeight = FontWeight.ExtraBold, textAlign = TextAlign.Center,
            )
            Text(
                stringResource(R.string.welcome_subtitle),
                color = c.textSecondary, fontSize = 14.sp, modifier = Modifier.padding(top = 6.dp),
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (!configured) {
                Text(
                    stringResource(R.string.config_missing),
                    color = c.accent, fontSize = 13.sp, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth(),
                )
            }
            if (gate == InviteGate.Blocked) {
                Text(
                    stringResource(R.string.invite_only), color = c.textSecondary, fontSize = 13.sp,
                    textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(bottom = 2.dp),
                )
                WynTextField(stringResource(R.string.invite_code), invite.code, invite.onCodeChange, "")
                WynPrimaryButton(
                    stringResource(if (invite.loading) R.string.invite_checking else R.string.invite_continue),
                    invite.onSubmit, enabled = !invite.loading,
                )
                ErrorText(invite.error)
                WynOutlineButton(stringResource(R.string.welcome_sign_in), onSignIn)
                return@Column
            }
            WynPrimaryButton(stringResource(R.string.welcome_create_account), onCreateAccount, enabled = configured && gate == InviteGate.Open)
            WynOutlineButton(stringResource(R.string.welcome_sign_in), onSignIn, enabled = configured)
            WynOutlineButton(
                stringResource(R.string.welcome_sign_in_google), onGoogle, enabled = configured,
                leading = { Image(painterResource(R.drawable.ic_google), contentDescription = null, modifier = Modifier.size(18.dp)) },
            )
            ErrorText(error)
            Spacer(Modifier.height(6.dp))
            val terms = stringResource(R.string.welcome_terms)
            val privacy = stringResource(R.string.welcome_privacy)
            val prefix = stringResource(R.string.welcome_terms_prefix)
            val and = stringResource(R.string.welcome_and)
            Text(
                buildAnnotatedString {
                    append(prefix); append("\n")
                    withStyle(SpanStyle(color = c.text, fontWeight = FontWeight.Bold)) { append(terms) }
                    append(" $and ")
                    withStyle(SpanStyle(color = c.text, fontWeight = FontWeight.Bold)) { append(privacy) }
                },
                color = c.textMuted, fontSize = 12.sp, lineHeight = 18.sp, textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            Text(
                stringResource(R.string.version_label),
                color = c.textMuted, fontSize = 11.sp, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

private val InvertColors = ColorFilter.colorMatrix(
    ColorMatrix(
        floatArrayOf(
            -1f, 0f, 0f, 0f, 255f,
            0f, -1f, 0f, 0f, 255f,
            0f, 0f, -1f, 0f, 255f,
            0f, 0f, 0f, 1f, 0f,
        ),
    ),
)
