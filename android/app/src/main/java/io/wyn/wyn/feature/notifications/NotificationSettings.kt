package io.wyn.wyn.feature.notifications

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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.viewModelScope
import io.wyn.wyn.R
import io.wyn.wyn.core.data.NotificationPrefs
import io.wyn.wyn.core.data.NotificationRepository
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.core.push.PushBlock
import io.wyn.wyn.core.push.PushController
import io.wyn.wyn.core.push.PushResult
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.profile.PillButton
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

/** web settings-route.tsx "การแจ้งเตือน": this phone's Push switch and what to be notified about. */
class NotificationSettingsViewModel(
    private val repo: NotificationRepository,
    private val push: PushController?,
    val userId: String,
) : ViewModel() {
    var prefs by mutableStateOf<NotificationPrefs?>(null); private set
    var loadFailed by mutableStateOf(false); private set
    var busy by mutableStateOf(false); private set
    var error by mutableStateOf<UiText?>(null); private set
    /** Null while this phone is being checked. */
    var pushEnabled by mutableStateOf<Boolean?>(null); private set
    var pushBlocked by mutableStateOf<PushBlock?>(null); private set
    var pushBusy by mutableStateOf(false); private set
    var pushError by mutableStateOf<UiText?>(null); private set

    init {
        load()
    }

    fun load() {
        loadFailed = false
        viewModelScope.launch {
            try {
                prefs = repo.prefs()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                loadFailed = true
            }
        }
    }

    /** Re-checked whenever the screen shows again (after the phone's settings, too). */
    fun checkPush(allowed: Boolean) {
        val controller = push
        if (controller == null || !controller.configured) {
            pushBlocked = PushBlock.NotConfigured
            pushEnabled = false
            return
        }
        pushBlocked = if (allowed) null else PushBlock.Denied
        if (!allowed) {
            pushEnabled = false
            return
        }
        viewModelScope.launch {
            val enabled = controller.enabledHere(userId)
            if (enabled == null) pushBlocked = PushBlock.Temporary else pushEnabled = enabled
        }
    }

    fun toggle(key: String, value: Boolean) {
        val current = prefs ?: return
        if (busy) return
        prefs = current.with(key, value)
        busy = true
        error = null
        viewModelScope.launch {
            try {
                repo.setPref(userId, key, value)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                prefs = current
                error = UiText(R.string.notification_settings_save_failed)
            } finally {
                busy = false
            }
        }
    }

    /** Called after Android answered the permission question (for "on"). */
    fun setPush(on: Boolean, allowed: Boolean) {
        val controller = push ?: return
        if (pushBusy) return
        pushError = null
        if (on && !allowed) {
            pushError = UiText(pushReasonText(PushBlock.Denied))
            pushEnabled = false
            return
        }
        pushBusy = true
        viewModelScope.launch {
            try {
                if (on) {
                    when (val result = controller.enable(userId)) {
                        PushResult.Ok -> { pushEnabled = true; pushBlocked = null }
                        is PushResult.Blocked -> { pushEnabled = false; pushError = UiText(pushReasonText(result.reason)) }
                    }
                } else if (controller.disable(userId)) {
                    pushEnabled = false
                } else {
                    pushError = UiText(R.string.push_off_failed)
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                pushError = UiText(R.string.push_toggle_failed)
            } finally {
                pushBusy = false
            }
        }
    }
}

private val prefLabels = listOf(
    "likes" to R.string.pref_likes, "comments" to R.string.pref_comments, "follows" to R.string.pref_follows,
    "messages" to R.string.pref_messages, "club" to R.string.pref_club, "trending" to R.string.pref_trending, "system" to R.string.pref_system,
)

@Composable
fun NotificationSettingsScreen(vm: NotificationSettingsViewModel, push: PushController?, onBack: () -> Unit) {
    val c = Wyn.colors
    val context = LocalContext.current
    var wantOn by androidx.compose.runtime.remember { mutableStateOf(false) }
    val askPermission = push?.let { controller -> rememberNotificationPermission(controller) { allowed -> vm.setPush(wantOn, allowed) } }
    LifecycleResumeEffect(Unit) {
        vm.checkPush(io.wyn.wyn.core.push.notificationsAllowed(context))
        onPauseOrDispose {}
    }
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding()) {
        Box(Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 8.dp)) {
            val back = stringResource(R.string.back)
            Icon(
                WynIcons.Back, contentDescription = back, tint = c.text,
                modifier = Modifier.align(Alignment.CenterStart).size(44.dp).clip(CircleShape).clickable(role = Role.Button, onClickLabel = back, onClick = onBack).padding(10.dp),
            )
            Text(stringResource(R.string.notifications_title), color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold, modifier = Modifier.align(Alignment.Center))
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp)) {
            SectionTitle(stringResource(R.string.settings_this_device))
            Group {
                val blocked = vm.pushBlocked
                SettingRow(
                    title = stringResource(R.string.push_title),
                    description = when {
                        vm.pushEnabled == null && blocked == null -> stringResource(R.string.push_checking)
                        blocked != null -> stringResource(pushReasonText(blocked))
                        else -> stringResource(R.string.push_available)
                    },
                    checked = vm.pushEnabled == true,
                    enabled = !vm.pushBusy && (blocked == null || blocked == PushBlock.Denied) && push != null,
                ) { on ->
                    wantOn = on
                    if (on) askPermission?.invoke() else vm.setPush(false, allowed = true)
                }
            }
            vm.pushError?.let { ErrorText(it.text()) }
            if (vm.pushBlocked == PushBlock.Denied) {
                Spacer(Modifier.height(10.dp))
                PillButton(stringResource(R.string.push_open_settings), filled = false, height = 36.dp, fontSize = 13) { openNotificationSettings(context) }
            }
            if (vm.pushBlocked == PushBlock.Temporary) {
                Spacer(Modifier.height(10.dp))
                PillButton(stringResource(R.string.push_check_again), filled = false, height = 36.dp, fontSize = 13) {
                    vm.checkPush(io.wyn.wyn.core.push.notificationsAllowed(context))
                }
            }
            Spacer(Modifier.height(18.dp))
            SectionTitle(stringResource(R.string.notify_when))
            val prefs = vm.prefs
            when {
                prefs != null -> Group {
                    prefLabels.forEachIndexed { index, (key, label) ->
                        if (index > 0) HorizontalDivider(color = c.border, thickness = 1.dp)
                        SettingRow(stringResource(label), null, prefs[key], enabled = !vm.busy) { vm.toggle(key, it) }
                    }
                }
                vm.loadFailed -> Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(stringResource(R.string.notification_settings_load_failed), color = c.accent, fontSize = 13.sp, modifier = Modifier.weight(1f))
                    PillButton(stringResource(R.string.retry), filled = false, height = 32.dp, fontSize = 12, onClick = vm::load)
                }
            }
            vm.error?.let { ErrorText(it.text()) }
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(text, color = Wyn.colors.textSecondary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 4.dp, bottom = 8.dp))
}

@Composable
private fun Group(content: @Composable () -> Unit) {
    val c = Wyn.colors
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).border(1.dp, c.border, RoundedCornerShape(14.dp))) { content() }
}

@Composable
private fun SettingRow(title: String, description: String?, checked: Boolean, enabled: Boolean, onChange: (Boolean) -> Unit) {
    val c = Wyn.colors
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable(enabled = enabled, role = Role.Switch) { onChange(!checked) }
            .padding(horizontal = 14.dp, vertical = 10.dp)
            .semantics { contentDescription = title },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, color = c.text, fontSize = 15.sp, fontWeight = FontWeight.Medium)
            if (description != null) Text(description, color = c.textSecondary, fontSize = 12.sp, lineHeight = 16.sp)
        }
        Spacer(Modifier.width(10.dp))
        Switch(
            checked = checked, onCheckedChange = null, enabled = enabled,
            colors = SwitchDefaults.colors(checkedTrackColor = c.text, checkedThumbColor = c.bg, uncheckedTrackColor = c.border, uncheckedBorderColor = c.border),
        )
    }
}

/**
 * web PushPrompt: asks once, on the main screens, whether to turn on Push.
 * Android's own permission question only opens from the Allow button.
 */
@Composable
fun PushPromptCard(push: PushController, userId: String, onDone: () -> Unit) {
    val c = Wyn.colors
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    var busy by androidx.compose.runtime.remember { mutableStateOf(false) }
    var error by androidx.compose.runtime.remember { mutableStateOf<Int?>(null) }
    val ask = rememberNotificationPermission(push) { allowed ->
        if (!allowed) {
            // "Not now" in Android's question: ask again in a week, not on every screen.
            push.dismissPrompt(System.currentTimeMillis())
            error = pushReasonText(PushBlock.Dismissed)
            busy = false
            return@rememberNotificationPermission
        }
        scope.launch {
            when (val result = push.enable(userId)) {
                PushResult.Ok -> onDone()
                is PushResult.Blocked -> error = pushReasonText(result.reason)
            }
            busy = false
        }
    }
    val label = stringResource(R.string.push_prompt_title)
    Column(
        Modifier.fillMaxWidth().navigationBarsPadding().padding(12.dp)
            .shadow(12.dp, RoundedCornerShape(18.dp)).clip(RoundedCornerShape(18.dp)).background(c.bg)
            .border(1.dp, c.border, RoundedCornerShape(18.dp)).padding(14.dp)
            .semantics { contentDescription = label },
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Box(Modifier.size(40.dp).clip(CircleShape).background(c.surface), contentAlignment = Alignment.Center) {
                Icon(WynIcons.Bell, contentDescription = null, tint = c.text, modifier = Modifier.size(22.dp))
            }
            Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                Text(label, color = c.text, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                Text(stringResource(R.string.push_prompt_body), color = c.textSecondary, fontSize = 13.sp, lineHeight = 18.sp)
            }
            val close = stringResource(R.string.close)
            Icon(
                WynIcons.Close, contentDescription = close, tint = c.textSecondary,
                modifier = Modifier.size(28.dp).clip(CircleShape).clickable(role = Role.Button, onClickLabel = close) {
                    push.dismissPrompt(System.currentTimeMillis()); onDone()
                }.padding(6.dp),
            )
        }
        error?.let { ErrorText(stringResource(it)) }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            PillButton(stringResource(R.string.push_prompt_later), filled = false, outlined = true, height = 40.dp, modifier = Modifier.weight(1f)) {
                push.dismissPrompt(System.currentTimeMillis()); onDone()
            }
            PillButton(stringResource(if (busy) R.string.push_prompt_opening else R.string.push_prompt_allow), filled = true, enabled = !busy, height = 40.dp, modifier = Modifier.weight(1f)) {
                busy = true
                error = null
                ask()
            }
        }
    }
}

/** Shows the Push prompt after a short pause, once per answer (web SHOW_DELAY_MS). */
@Composable
fun PushPromptHost(push: PushController?, userId: String) {
    if (push == null) return
    val context = LocalContext.current
    var show by androidx.compose.runtime.remember(userId) { mutableStateOf(false) }
    LaunchedEffect(userId) {
        kotlinx.coroutines.delay(4000)
        show = push.shouldPrompt(userId, System.currentTimeMillis(), canAskNotificationPermission(context, push))
    }
    if (show) {
        // Above the tab bar, like the web's banner.
        Box(Modifier.fillMaxSize().padding(bottom = 50.dp), contentAlignment = Alignment.BottomCenter) {
            PushPromptCard(push, userId) { show = false }
        }
    }
}
