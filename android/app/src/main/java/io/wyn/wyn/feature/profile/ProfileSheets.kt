package io.wyn.wyn.feature.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.wyn.wyn.R
import io.wyn.wyn.core.data.SavedAccount
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.core.design.WynPrimaryButton
import io.wyn.wyn.core.design.WynTextField
import io.wyn.wyn.feature.auth.MAX_SAVED_ACCOUNTS
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.home.ReportCategories

private val Danger = Color(0xFFE0203D)

/** The accounts on this phone, for the own-profile switcher (web profile-account-switcher). */
data class AccountSwitcher(
    val accounts: List<SavedAccount>,
    val activeId: String?,
    val busy: Boolean,
    val message: UiText?,
    val switchTo: (String) -> Unit,
    val add: () -> Unit,
    val remove: (String) -> Unit,
    val clearMessage: () -> Unit,
)

val ReportLabels = mapOf(
    "spam" to R.string.report_spam, "scam" to R.string.report_scam, "harassment" to R.string.report_harassment,
    "hate" to R.string.report_hate, "sexual_content" to R.string.report_sexual, "violence" to R.string.report_violence,
    "privacy" to R.string.report_privacy, "illegal_content" to R.string.report_illegal, "copyright" to R.string.report_copyright,
    "other" to R.string.report_other,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileSheets(vm: ProfileViewModel, accounts: AccountSwitcher?, onShare: () -> Unit, onSettings: () -> Unit) {
    val sheet = vm.profileSheet ?: return
    val c = Wyn.colors
    ModalBottomSheet(
        onDismissRequest = { if (!vm.action) vm.openProfileSheet(null) },
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = c.bg,
        shape = RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp),
        dragHandle = { Box(Modifier.padding(top = 10.dp, bottom = 8.dp).size(38.dp, 4.dp).clip(RoundedCornerShape(999.dp)).background(c.border)) },
    ) {
        when (sheet) {
            ProfileSheet.Menu -> Column(Modifier.padding(bottom = 12.dp)) {
                Text(
                    stringResource(R.string.profile_options), color = c.text, fontSize = 16.sp, fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(start = 20.dp, end = 20.dp, bottom = 6.dp),
                )
                val summary = vm.summary
                if (vm.own) {
                    MenuRow(WynIcons.Users, stringResource(R.string.accounts_switch_title)) { vm.openProfileSheet(ProfileSheet.Accounts) }
                    MenuRow(WynIcons.Settings, stringResource(R.string.settings)) { vm.openProfileSheet(null); onSettings() }
                    MenuRow(WynIcons.Share, stringResource(R.string.profile_share)) { vm.openProfileSheet(null); onShare() }
                } else if (summary != null) {
                    MenuRow(WynIcons.Flag, stringResource(R.string.report)) { vm.openProfileSheet(ProfileSheet.Report) }
                    MenuRow(if (summary.muted) WynIcons.Volume else WynIcons.VolumeOff, stringResource(if (summary.muted) R.string.profile_unmute else R.string.profile_mute), enabled = !vm.action) { vm.toggleMute() }
                    MenuRow(WynIcons.UserRoundX, stringResource(if (summary.blocked) R.string.profile_unblock else R.string.profile_block), danger = true, enabled = !vm.action) { vm.block() }
                }
                vm.sheetError?.let { Box(Modifier.padding(horizontal = 20.dp)) { ErrorText(it.text()) } }
            }
            ProfileSheet.Report -> ReportUser(vm)
            ProfileSheet.Accounts -> if (accounts != null) AccountsSheet(accounts, onClose = { vm.openProfileSheet(null) })
        }
    }
}

@Composable
private fun MenuRow(icon: ImageVector, label: String, danger: Boolean = false, enabled: Boolean = true, onClick: () -> Unit) {
    val c = Wyn.colors
    val tint = (if (danger) Danger else c.text).copy(alpha = if (enabled) 1f else 0.5f)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().heightIn(min = 54.dp).clickable(enabled = enabled, role = Role.Button, onClick = onClick).padding(horizontal = 20.dp),
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(14.dp))
        Text(label, color = tint, fontSize = 15.sp)
    }
}

@Composable
private fun ReportUser(vm: ProfileViewModel) {
    val c = Wyn.colors
    Column(
        Modifier.verticalScroll(rememberScrollState()).padding(start = 18.dp, end = 18.dp, bottom = 14.dp, top = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(stringResource(R.string.profile_report_title), color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
        Column(Modifier.border(1.dp, c.border, RoundedCornerShape(14.dp)).clip(RoundedCornerShape(14.dp))) {
            ReportCategories.forEachIndexed { index, key ->
                if (index > 0) HorizontalDivider(color = c.border, thickness = 1.dp)
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 46.dp)
                        .selectable(vm.reportReason == key, role = Role.RadioButton) { vm.chooseReportReason(key) }
                        .padding(horizontal = 4.dp),
                ) {
                    RadioButton(selected = vm.reportReason == key, onClick = null, colors = RadioButtonDefaults.colors(selectedColor = c.link), modifier = Modifier.padding(horizontal = 8.dp))
                    Text(stringResource(ReportLabels.getValue(key)), color = c.text, fontSize = 14.sp)
                }
            }
        }
        if (vm.reportReason == "other") {
            WynTextField(stringResource(R.string.report_detail), vm.reportText, vm::updateReportText, stringResource(R.string.report_detail), singleLine = false, minHeight = 96)
        }
        ErrorText(vm.sheetError.text())
        WynPrimaryButton(stringResource(R.string.report_send), vm::submitProfileReport, enabled = !vm.action)
    }
}

@Composable
private fun AccountsSheet(switcher: AccountSwitcher, onClose: () -> Unit) {
    val c = Wyn.colors
    var managing by remember { mutableStateOf(false) }
    Column(Modifier.padding(start = 18.dp, end = 18.dp, bottom = 16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.accounts_switch_title), color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                Text(stringResource(R.string.accounts_count, switcher.accounts.size, MAX_SAVED_ACCOUNTS), color = c.textSecondary, fontSize = 12.sp)
            }
            val close = stringResource(R.string.close)
            Icon(
                WynIcons.Close, contentDescription = close, tint = c.text,
                modifier = Modifier.size(36.dp).clip(RoundedCornerShape(999.dp)).clickable(role = Role.Button, onClickLabel = close, onClick = onClose).padding(8.dp),
            )
        }
        Spacer(Modifier.size(10.dp))
        switcher.accounts.forEach { account ->
            val current = account.userId == switcher.activeId
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().heightIn(min = 60.dp).clip(RoundedCornerShape(12.dp))
                    .clickable(enabled = !switcher.busy && !managing, role = Role.Button) { if (current) onClose() else switcher.switchTo(account.userId) }
                    .padding(horizontal = 6.dp, vertical = 8.dp),
            ) {
                WynAvatar(account.avatarUrl, 44)
                Column(Modifier.weight(1f).padding(start = 12.dp)) {
                    Text(
                        account.displayName?.trim()?.takeIf { it.isNotEmpty() } ?: account.username ?: stringResource(R.string.member),
                        color = c.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis,
                    )
                    account.username?.let { Text("@$it", color = c.textSecondary, fontSize = 13.sp, maxLines = 1) }
                }
                when {
                    current -> Icon(WynIcons.CheckCircle, contentDescription = stringResource(R.string.accounts_current), tint = c.text, modifier = Modifier.size(21.dp))
                    managing -> Text(
                        stringResource(R.string.accounts_remove), color = Danger, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickable(enabled = !switcher.busy, role = Role.Button) { switcher.remove(account.userId) }.padding(8.dp),
                    )
                }
            }
        }
        ErrorText(switcher.message.text())
        Spacer(Modifier.size(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            PillButton(stringResource(R.string.accounts_use_other), filled = true, enabled = !switcher.busy, modifier = Modifier.weight(1f)) { switcher.add() }
            PillButton(
                stringResource(if (managing) R.string.done else R.string.accounts_manage), filled = false, outlined = true,
                enabled = !switcher.busy && switcher.accounts.size > 1, modifier = Modifier.weight(1f),
            ) { managing = !managing }
        }
    }
}

@Composable
fun ProfileConfirmDialog(vm: ProfileViewModel) {
    val question = vm.confirm ?: return
    val c = Wyn.colors
    val username = vm.summary?.profile?.username.orEmpty()
    val (title, action) = when (question) {
        ProfileConfirm.Block -> stringResource(R.string.profile_block_confirm, username) to stringResource(R.string.profile_block)
        ProfileConfirm.CancelRequest -> stringResource(R.string.follow_cancel_confirm, username) to stringResource(R.string.follow_cancel)
        is ProfileConfirm.CancelSuggestionRequest -> stringResource(R.string.follow_cancel_confirm, question.person.username) to stringResource(R.string.follow_cancel)
    }
    AlertDialog(
        onDismissRequest = vm::dismissConfirm,
        containerColor = c.bg,
        title = { Text(title, color = c.text, fontWeight = FontWeight.Bold, fontSize = 17.sp) },
        confirmButton = {
            TextButton(onClick = {
                when (question) {
                    ProfileConfirm.Block -> vm.block(confirmed = true)
                    ProfileConfirm.CancelRequest -> vm.follow(confirmed = true)
                    is ProfileConfirm.CancelSuggestionRequest -> vm.followSuggestion(question.person, confirmed = true)
                }
            }) { Text(action, color = Danger, fontWeight = FontWeight.Bold) }
        },
        dismissButton = { TextButton(onClick = vm::dismissConfirm) { Text(stringResource(R.string.cancel), color = c.textSecondary) } },
    )
}
