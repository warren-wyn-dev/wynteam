package io.wyn.wyn.feature.account

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.wyn.wyn.R
import io.wyn.wyn.core.data.SavedAccount
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.Gap
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynOutlineButton
import io.wyn.wyn.feature.auth.AccountFlowViewModel
import io.wyn.wyn.feature.auth.AuthPage
import io.wyn.wyn.feature.auth.LogoMark
import io.wyn.wyn.feature.auth.text

/**
 * M1's signed-in screen: who is signed in, the saved accounts to switch
 * between, add account and sign out. The feed replaces it in M2; these
 * controls then move to Profile and Settings as on the web.
 */
@Composable
fun AccountHomeScreen(vm: AccountFlowViewModel) {
    val c = Wyn.colors
    val active = vm.savedAccounts.firstOrNull { it.userId == vm.activeUserId }
    val others = vm.savedAccounts.filter { it.userId != vm.activeUserId }
    AuthPage {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 24.dp)) {
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { LogoMark(48) }
            Gap(24)
            if (active != null) {
                AccountRow(active, current = true, onClick = null)
            }
            Gap(8)
            Text(stringResource(R.string.home_next_milestone), color = c.textSecondary, fontSize = 13.sp, lineHeight = 19.sp)
            if (others.isNotEmpty()) {
                Gap(24)
                Text(stringResource(R.string.accounts_switch), color = c.textSecondary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                Gap(8)
                others.forEach { account ->
                    AccountRow(account, current = false, onClick = { vm.switchTo(account.userId) }.takeIf { !vm.homeBusy })
                    Gap(8)
                }
            }
            ErrorText(vm.homeMessage.text())
        }
        Column(Modifier.padding(horizontal = 20.dp, vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            WynOutlineButton(stringResource(R.string.accounts_add), vm::addAccount, enabled = !vm.homeBusy)
            WynOutlineButton(stringResource(R.string.sign_out), vm::signOut, enabled = !vm.homeBusy)
            Text(
                stringResource(R.string.version_label), color = c.textMuted, fontSize = 11.sp,
                modifier = Modifier.align(Alignment.CenterHorizontally),
            )
        }
    }
}

@Composable
private fun AccountRow(account: SavedAccount, current: Boolean, onClick: (() -> Unit)?) {
    val c = Wyn.colors
    val name = account.displayName ?: account.username ?: stringResource(R.string.member)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .border(1.dp, c.border, RoundedCornerShape(12.dp))
            .then(if (onClick != null) Modifier.clickable(role = Role.Button, onClick = onClick) else Modifier)
            .padding(12.dp),
    ) {
        Box(Modifier.size(44.dp).clip(CircleShape).background(c.border), contentAlignment = Alignment.Center) {
            Text(name.take(1).uppercase(), color = c.textSecondary, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        }
        Column(Modifier.weight(1f).padding(start = 12.dp)) {
            Text(name, color = c.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
            account.username?.let { Text("@$it", color = c.textMuted, fontSize = 13.sp, maxLines = 1) }
        }
        if (current) Text(stringResource(R.string.accounts_current), color = c.textSecondary, fontSize = 12.sp)
    }
}
