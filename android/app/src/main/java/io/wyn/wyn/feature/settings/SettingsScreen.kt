package io.wyn.wyn.feature.settings

import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.wyn.wyn.R
import io.wyn.wyn.core.data.AppLanguage
import io.wyn.wyn.core.data.INTERACTION_CHOICES
import io.wyn.wyn.core.data.LEGAL_TYPES
import io.wyn.wyn.core.data.LIKES_CHOICES
import io.wyn.wyn.core.data.MIN_PASSWORD_LENGTH
import io.wyn.wyn.core.data.Person
import io.wyn.wyn.core.data.PrivacyField
import io.wyn.wyn.core.data.ThemePreference
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.notifications.SettingsGroup
import io.wyn.wyn.feature.notifications.SettingsSwitchRow
import io.wyn.wyn.feature.profile.PersonRow
import io.wyn.wyn.feature.profile.PillButton
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalDate

private val Danger = Color(0xFFB12D25)

/** What Settings opens outside itself. */
data class SettingsActions(
    val onClose: () -> Unit,
    val onNotifications: () -> Unit,
    val onSignOut: () -> Unit,
    val onForgotPassword: () -> Unit,
    val onOpenProfile: (String) -> Unit,
)

/** web settings-route.tsx. */
@Composable
fun SettingsScreen(vm: SettingsViewModel, actions: SettingsActions, versionLabel: String) {
    val c = Wyn.colors
    val context = LocalContext.current
    val activity = androidx.activity.compose.LocalActivity.current
    val scope = rememberCoroutineScope()
    var pendingExport by remember { mutableStateOf<String?>(null) }
    val saveExport = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri: Uri? ->
        val json = pendingExport
        pendingExport = null
        if (uri == null || json == null) return@rememberLauncherForActivityResult
        scope.launch {
            val ok = withContext(Dispatchers.IO) {
                runCatching { context.contentResolver.openOutputStream(uri)?.use { it.write(json.toByteArray()) } != null }.getOrDefault(false)
            }
            if (!ok) vm.exportSaveFailed()
        }
    }
    LaunchedEffect(vm.deleted) { if (vm.deleted) actions.onSignOut() }
    BackHandler(enabled = vm.section != SettingsSection.Root) { vm.back() }
    val title = stringResource(
        when (vm.section) {
            SettingsSection.Root -> R.string.settings
            SettingsSection.Privacy -> R.string.settings_privacy
            SettingsSection.Account -> R.string.settings_account
            SettingsSection.Password -> R.string.settings_password
            SettingsSection.Theme -> R.string.settings_theme
            SettingsSection.Language -> R.string.settings_language
            SettingsSection.Legal -> R.string.settings_legal
        },
    )
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding().imePadding()) {
        Box(Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 8.dp)) {
            val back = stringResource(R.string.back)
            Icon(
                WynIcons.Back, contentDescription = back, tint = c.text,
                modifier = Modifier.align(Alignment.CenterStart).size(44.dp).clip(CircleShape)
                    .clickable(role = Role.Button, onClickLabel = back) { if (!vm.back()) actions.onClose() }.padding(10.dp),
            )
            Text(title, color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold, modifier = Modifier.align(Alignment.Center))
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 14.dp, end = 14.dp, top = 10.dp, bottom = 30.dp).navigationBarsPadding()) {
            vm.error?.let { Text(it.text().orEmpty(), color = Danger, fontSize = 13.sp, modifier = Modifier.padding(horizontal = 6.dp, vertical = 6.dp)) }
            when (vm.section) {
                SettingsSection.Root -> Root(vm, actions, versionLabel)
                SettingsSection.Privacy -> Privacy(vm)
                SettingsSection.Account -> Account(vm, actions) {
                    vm.exportData { json ->
                        pendingExport = json
                        saveExport.launch("wynos-data-${LocalDate.now()}.json")
                    }
                }
                SettingsSection.Password -> Password(vm, actions)
                SettingsSection.Theme -> Choices(
                    ThemePreference.entries.map { it to themeLabels(it) }, vm.theme, vm::chooseTheme,
                    if (vm.themeSaveFailed) stringResource(R.string.settings_theme_save_failed) else null,
                )
                SettingsSection.Language -> Choices(
                    AppLanguage.entries.map { it to (languageName(it) to null) }, vm.language,
                    { value -> if (vm.chooseLanguage(value)) activity?.recreate() },
                    if (vm.languageSaveFailed) stringResource(R.string.settings_language_save_failed) else null,
                )
                SettingsSection.Legal -> SettingsGroup {
                    LEGAL_TYPES.forEachIndexed { index, type ->
                        if (index > 0) HorizontalDivider(color = c.border, thickness = 1.dp)
                        NavRow(stringResource(legalLabel(type)), enabled = !vm.busy) { vm.openDocument(type) }
                    }
                }
            }
        }
    }
    vm.confirm?.let { question ->
        val (text, action, danger) = when (question) {
            SettingsConfirm.SignOut -> Triple(stringResource(R.string.settings_sign_out_confirm), stringResource(R.string.settings_sign_out), true)
            SettingsConfirm.DeleteAccount -> Triple(stringResource(R.string.settings_delete_confirm), stringResource(R.string.settings_delete), true)
            SettingsConfirm.DeleteAccountAgain -> Triple(stringResource(R.string.settings_delete_confirm_again), stringResource(R.string.settings_delete), true)
        }
        AlertDialog(
            onDismissRequest = { vm.ask(null) },
            containerColor = c.bg,
            title = { Text(text, color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold) },
            confirmButton = {
                TextButton(onClick = {
                    if (question == SettingsConfirm.SignOut) { vm.ask(null); actions.onSignOut() } else vm.confirmNow()
                }) { Text(action, color = if (danger) Danger else c.text, fontWeight = FontWeight.Bold) }
            },
            dismissButton = { TextButton(onClick = { vm.ask(null) }) { Text(stringResource(R.string.cancel), color = c.textSecondary) } },
        )
    }
    vm.document?.let { doc -> LegalDialog(doc.title, doc.version, doc.content, english = vm.language == AppLanguage.English, onClose = vm::closeDocument) }
}

@Composable
private fun Heading(text: String) {
    Text(text, color = Wyn.colors.textSecondary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 6.dp, end = 6.dp, top = 18.dp, bottom = 7.dp))
}

/** web SettingRow with a chevron (or a leading icon / description). */
@Composable
private fun NavRow(
    title: String,
    description: String? = null,
    icon: ImageVector? = null,
    danger: Boolean = false,
    enabled: Boolean = true,
    trailing: (@Composable () -> Unit)? = null,
    onClick: (() -> Unit)?,
) {
    val c = Wyn.colors
    val ink = if (danger) Danger else c.text
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp)
            .then(if (onClick != null) Modifier.clickable(enabled = enabled, role = Role.Button, onClick = onClick) else Modifier)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        if (icon != null) Icon(icon, contentDescription = null, tint = ink, modifier = Modifier.size(19.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(title, color = if (onClick == null && trailing == null) c.textMuted else ink, fontSize = 14.sp, fontWeight = FontWeight.Bold)
            if (description != null) Text(description, color = c.textSecondary, fontSize = 11.sp, lineHeight = 15.sp)
        }
        when {
            trailing != null -> trailing()
            onClick != null -> Icon(WynIcons.ChevronRight, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(20.dp))
        }
    }
}

@Composable
private fun Root(vm: SettingsViewModel, actions: SettingsActions, versionLabel: String) {
    val c = Wyn.colors
    Heading(stringResource(R.string.settings_account))
    SettingsGroup {
        NavRow(stringResource(R.string.settings_account), icon = WynIcons.UserRound) { vm.open(SettingsSection.Account) }
        HorizontalDivider(color = c.border, thickness = 1.dp)
        NavRow(stringResource(R.string.settings_privacy), icon = WynIcons.LockKeyhole) { vm.open(SettingsSection.Privacy) }
    }
    Heading(stringResource(R.string.settings_app))
    SettingsGroup {
        NavRow(stringResource(R.string.notifications_title), icon = WynIcons.Bell, onClick = actions.onNotifications)
        HorizontalDivider(color = c.border, thickness = 1.dp)
        NavRow(stringResource(R.string.settings_theme), stringResource(themeLabels(vm.theme).first), icon = WynIcons.Moon) { vm.open(SettingsSection.Theme) }
        HorizontalDivider(color = c.border, thickness = 1.dp)
        NavRow(stringResource(R.string.settings_language), languageName(vm.language), icon = WynIcons.Globe) { vm.open(SettingsSection.Language) }
    }
    Heading(stringResource(R.string.settings_help_heading))
    SettingsGroup {
        NavRow(stringResource(R.string.settings_help_heading), icon = WynIcons.CircleHelp, onClick = null)
        HorizontalDivider(color = c.border, thickness = 1.dp)
        NavRow(stringResource(R.string.settings_legal), icon = WynIcons.FileText) { vm.open(SettingsSection.Legal) }
    }
    Spacer(Modifier.height(22.dp))
    SettingsGroup {
        NavRow(stringResource(R.string.settings_sign_out), icon = WynIcons.LogOut, danger = true) { vm.ask(SettingsConfirm.SignOut) }
    }
    Text(versionLabel, color = c.textMuted, fontSize = 12.sp, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 18.dp, bottom = 24.dp))
}

@Composable
private fun Privacy(vm: SettingsViewModel) {
    val c = Wyn.colors
    val privacy = vm.privacy
    if (privacy == null) {
        LoadState(vm)
        return
    }
    Heading(stringResource(R.string.settings_account))
    SettingsGroup {
        SettingsSwitchRow(stringResource(R.string.settings_private), stringResource(R.string.settings_private_hint), privacy.isPrivate, enabled = !vm.busy) {
            vm.setPrivacy(PrivacyField.IsPrivate, it)
        }
    }
    Heading(stringResource(R.string.settings_interactions))
    SettingsGroup {
        SelectRow(stringResource(R.string.settings_who_dm), privacy.dmPermission, INTERACTION_CHOICES, vm.busy) { vm.setPrivacy(PrivacyField.Dm, it) }
        HorizontalDivider(color = c.border, thickness = 1.dp)
        SelectRow(stringResource(R.string.settings_who_mention), privacy.mentionPermission, INTERACTION_CHOICES, vm.busy) { vm.setPrivacy(PrivacyField.Mention, it) }
        HorizontalDivider(color = c.border, thickness = 1.dp)
        SelectRow(stringResource(R.string.settings_who_comment), privacy.commentPermission, INTERACTION_CHOICES, vm.busy) { vm.setPrivacy(PrivacyField.Comment, it) }
        HorizontalDivider(color = c.border, thickness = 1.dp)
        SelectRow(stringResource(R.string.settings_who_likes), privacy.likesVisibility, LIKES_CHOICES, vm.busy) { vm.setPrivacy(PrivacyField.Likes, it) }
    }
    Heading(stringResource(R.string.settings_status))
    SettingsGroup {
        SettingsSwitchRow(stringResource(R.string.settings_online), null, vm.online, enabled = !vm.busy, onChange = vm::toggleOnline)
    }
}

@Composable
private fun LoadState(vm: SettingsViewModel) {
    val c = Wyn.colors
    Column(Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        if (vm.loading) {
            io.wyn.wyn.feature.clubs.ClubLoading()
        } else {
            Text(stringResource(R.string.settings_load_failed), color = c.textSecondary, fontSize = 15.sp, textAlign = TextAlign.Center)
            Spacer(Modifier.height(12.dp))
            PillButton(stringResource(R.string.retry), filled = false, outlined = true, onClick = vm::load)
        }
    }
}

private fun choiceLabel(value: String): Int = when (value) {
    "people_i_follow" -> R.string.permission_following
    "no_one" -> R.string.permission_no_one
    "friends" -> R.string.permission_friends
    "only_me" -> R.string.permission_only_me
    else -> R.string.permission_everyone
}

/** web PermissionSelect: the current choice on the right; tap for the list. */
@Composable
private fun SelectRow(title: String, value: String, choices: List<String>, busy: Boolean, onChange: (String) -> Unit) {
    val c = Wyn.colors
    var open by remember { mutableStateOf(false) }
    Box {
        NavRow(
            title,
            trailing = {
                Text(stringResource(choiceLabel(value)), color = c.textSecondary, fontSize = 12.sp, textAlign = TextAlign.End, modifier = Modifier.widthIn(max = 160.dp))
            },
            enabled = !busy,
        ) { open = true }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }, containerColor = c.bg) {
            choices.forEach { choice ->
                DropdownMenuItem(
                    text = { Text(stringResource(choiceLabel(choice)), color = c.text, fontSize = 14.sp, fontWeight = if (choice == value) FontWeight.Bold else FontWeight.Normal) },
                    onClick = { open = false; if (choice != value) onChange(choice) },
                )
            }
        }
    }
}

@Composable
private fun Account(vm: SettingsViewModel, actions: SettingsActions, onExport: () -> Unit) {
    val c = Wyn.colors
    Heading(stringResource(R.string.settings_security))
    SettingsGroup {
        NavRow(stringResource(R.string.settings_password), stringResource(R.string.settings_password_hint), icon = WynIcons.LockKeyhole) { vm.open(SettingsSection.Password) }
        HorizontalDivider(color = c.border, thickness = 1.dp)
        PeopleList(stringResource(R.string.settings_blocked), vm.blocked, vm.userId, stringResource(R.string.settings_unblock), actions.onOpenProfile, vm::unblock)
        HorizontalDivider(color = c.border, thickness = 1.dp)
        PeopleList(stringResource(R.string.settings_muted), vm.muted, vm.userId, stringResource(R.string.settings_unmute), actions.onOpenProfile, vm::unmute)
    }
    Heading(stringResource(R.string.settings_my_data))
    SettingsGroup {
        NavRow(
            stringResource(R.string.settings_export), enabled = !vm.busy,
            trailing = { Icon(WynIcons.Download, contentDescription = null, tint = c.text, modifier = Modifier.size(19.dp)) },
            onClick = onExport,
        )
        HorizontalDivider(color = c.border, thickness = 1.dp)
        NavRow(
            stringResource(R.string.settings_delete), danger = true, enabled = !vm.busy,
            trailing = { Icon(WynIcons.Trash, contentDescription = null, tint = Danger, modifier = Modifier.size(19.dp)) },
        ) { vm.ask(SettingsConfirm.DeleteAccount) }
    }
    Row(Modifier.padding(horizontal = 5.dp, vertical = 9.dp), horizontalArrangement = Arrangement.spacedBy(7.dp)) {
        Icon(WynIcons.ShieldCheck, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(16.dp))
        Text(stringResource(R.string.settings_safety), color = c.textSecondary, fontSize = 12.sp, lineHeight = 17.sp)
    }
}

@Composable
private fun PeopleList(title: String, people: List<Person>, viewerId: String, action: String, onOpen: (String) -> Unit, onAction: (Person) -> Unit) {
    val c = Wyn.colors
    Column(Modifier.padding(top = 12.dp, bottom = 2.dp)) {
        Text(title, color = c.text, fontSize = 13.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 14.dp, end = 14.dp, bottom = 8.dp))
        if (people.isEmpty()) {
            Text(stringResource(R.string.settings_none), color = c.textSecondary, fontSize = 13.sp, modifier = Modifier.padding(start = 14.dp, end = 14.dp, top = 8.dp, bottom = 14.dp))
        }
        people.forEach { person ->
            PersonRow(person, viewerId, busy = false, onFollow = null, onOpen = onOpen) {
                PillButton(action, filled = false, height = 34.dp, fontSize = 13) { onAction(person) }
            }
        }
    }
}

@Composable
private fun Password(vm: SettingsViewModel, actions: SettingsActions) {
    val c = Wyn.colors
    val shape = RoundedCornerShape(18.dp)
    if (vm.passwordSaved) {
        Column(Modifier.padding(vertical = 8.dp).fillMaxWidth().clip(shape).border(1.dp, c.border, shape).padding(horizontal = 16.dp, vertical = 18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(stringResource(R.string.password_saved_title), color = c.text, fontSize = 19.sp, fontWeight = FontWeight.Bold)
            Text(stringResource(R.string.password_saved_body), color = c.textSecondary, fontSize = 12.sp, lineHeight = 19.sp)
            SubmitButton(stringResource(R.string.password_back_to_account), true) { vm.back() }
        }
        return
    }
    Heading(stringResource(R.string.password_security_heading))
    Column(Modifier.padding(vertical = 8.dp).fillMaxWidth().clip(shape).border(1.dp, c.border, shape).padding(horizontal = 16.dp, vertical = 18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(stringResource(R.string.password_hint_current), color = c.textSecondary, fontSize = 12.sp, lineHeight = 19.sp)
        PasswordField(stringResource(R.string.password_current), vm.currentPassword, vm::updateCurrent, !vm.passwordBusy)
        PasswordField(stringResource(R.string.password_new), vm.newPassword, vm::updateNew, !vm.passwordBusy)
        Text(stringResource(R.string.password_rule, MIN_PASSWORD_LENGTH), color = c.textSecondary, fontSize = 12.sp, lineHeight = 19.sp)
        PasswordField(stringResource(R.string.password_confirm), vm.confirmPassword, vm::updateConfirm, !vm.passwordBusy)
        vm.passwordError?.let { Text(it.text().orEmpty(), color = Danger, fontSize = 13.sp, lineHeight = 19.sp) }
        Spacer(Modifier.height(4.dp))
        SubmitButton(stringResource(if (vm.passwordBusy) R.string.password_checking else R.string.password_save), !vm.passwordBusy, vm::submitPassword)
        Text(
            stringResource(R.string.password_forgot), color = c.text, fontSize = 13.sp, textDecoration = TextDecoration.Underline,
            modifier = Modifier.heightIn(min = 44.dp).clickable(enabled = !vm.passwordBusy, role = Role.Button, onClick = actions.onForgotPassword).padding(vertical = 12.dp),
        )
    }
}

@Composable
private fun PasswordField(label: String, value: String, onChange: (String) -> Unit, enabled: Boolean) {
    val c = Wyn.colors
    Text(label, color = c.text, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 10.dp))
    BasicTextField(
        value = value, onValueChange = onChange, enabled = enabled, singleLine = true,
        textStyle = TextStyle(color = c.text, fontSize = 16.sp),
        cursorBrush = SolidColor(c.text),
        visualTransformation = PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, autoCorrectEnabled = false),
        modifier = Modifier.fillMaxWidth().semantics { contentDescription = label },
        decorationBox = { inner ->
            Box(
                Modifier.fillMaxWidth().height(52.dp).clip(RoundedCornerShape(14.dp)).border(1.dp, c.border, RoundedCornerShape(14.dp)).padding(horizontal = 14.dp),
                contentAlignment = Alignment.CenterStart,
            ) { inner() }
        },
    )
}

@Composable
private fun SubmitButton(label: String, enabled: Boolean, onClick: () -> Unit) {
    val c = Wyn.colors
    Box(
        Modifier.fillMaxWidth().heightIn(min = 54.dp).clip(RoundedCornerShape(18.dp)).background(c.text.copy(alpha = if (enabled) 1f else 0.5f))
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Text(label, color = c.bg, fontSize = 14.sp, fontWeight = FontWeight.Bold) }
}

private fun themeLabels(value: ThemePreference): Pair<Int, Int> = when (value) {
    ThemePreference.System -> R.string.theme_system to R.string.theme_system_hint
    ThemePreference.Light -> R.string.theme_light to R.string.theme_light_hint
    ThemePreference.Dark -> R.string.theme_dark to R.string.theme_dark_hint
}

/** web languageNames: each language in its own script. */
private fun languageName(value: AppLanguage): String = if (value == AppLanguage.Thai) "ไทย" else "English"

/** A radio list (web ThemePicker / LanguagePicker). Labels are string ids or plain text. */
@Composable
private fun <T> Choices(options: List<Pair<T, Pair<Any, Any?>>>, current: T, onChoose: (T) -> Unit, failure: String?) {
    val c = Wyn.colors
    Spacer(Modifier.height(8.dp))
    SettingsGroup {
        options.forEachIndexed { index, (value, labels) ->
            if (index > 0) HorizontalDivider(color = c.border, thickness = 1.dp)
            val title = (labels.first as? Int)?.let { stringResource(it) } ?: labels.first.toString()
            val hint = (labels.second as? Int)?.let { stringResource(it) }
            Row(
                Modifier.fillMaxWidth().heightIn(min = 56.dp).selectable(value == current, role = Role.RadioButton) { onChoose(value) }.padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(title, color = c.text, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                    if (hint != null) Text(hint, color = c.textSecondary, fontSize = 11.sp)
                }
                if (value == current) Icon(WynIcons.Check, contentDescription = null, tint = c.text, modifier = Modifier.size(20.dp))
            }
        }
    }
    failure?.let { Text(it, color = c.textSecondary, fontSize = 12.sp, lineHeight = 17.sp, modifier = Modifier.padding(horizontal = 5.dp, vertical = 9.dp)) }
}

private fun legalLabel(type: String): Int = when (type) {
    "terms_of_service" -> R.string.legal_terms
    "privacy_policy" -> R.string.legal_privacy
    "community_guidelines" -> R.string.legal_community
    "copyright_policy" -> R.string.legal_copyright
    "report_policy" -> R.string.legal_report
    else -> R.string.legal_appeal
}

@Composable
private fun LegalDialog(title: String, version: String, content: String, english: Boolean, onClose: () -> Unit) {
    val c = Wyn.colors
    AlertDialog(
        onDismissRequest = onClose,
        containerColor = c.bg,
        title = { Text(title, color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(stringResource(R.string.legal_version, version), color = c.textSecondary, fontSize = 12.sp)
                if (english) Text("This document is currently available in Thai only.", color = c.textSecondary, fontSize = 12.sp)
                Text(content, color = c.text, fontSize = 14.sp, lineHeight = 21.sp)
            }
        },
        confirmButton = { TextButton(onClick = onClose) { Text(stringResource(R.string.close), color = c.text, fontWeight = FontWeight.Bold) } },
    )
}
