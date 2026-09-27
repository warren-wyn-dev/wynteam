package io.wyn.wyn.feature.shell

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.min
import androidx.compose.ui.unit.sp
import io.wyn.wyn.R
import io.wyn.wyn.core.data.ProfileSummary
import io.wyn.wyn.core.design.VerifiedBadge
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons

/** Where the drawer's rows lead. */
data class DrawerActions(
    val onProfile: () -> Unit,
    val onExploreClubs: () -> Unit,
    val onCreateClub: () -> Unit,
    val onMyClubs: () -> Unit,
    val onBookmarks: () -> Unit,
    val onSettings: () -> Unit,
)

private enum class DrawerPanel { Feedback, Help }

const val FEEDBACK_MAX = 1000

/** web HomeDrawer: me, four destinations, and Feedback / Help. Swipe left, tap outside or Back to close. */
@Composable
fun HomeDrawer(open: Boolean, me: ProfileSummary?, actions: DrawerActions, onClose: () -> Unit) {
    val state = remember { MutableTransitionState(false) }
    state.targetState = open
    if (!state.currentState && !state.targetState) return
    var panel by rememberSaveable { mutableStateOf<DrawerPanel?>(null) }
    BackHandler(enabled = open) { if (panel != null) panel = null else onClose() }
    fun go(action: () -> Unit) {
        onClose()
        action()
    }
    Box(Modifier.fillMaxSize()) {
        AnimatedVisibility(state, enter = fadeIn(tween(180)), exit = fadeOut(tween(180))) {
            Box(
                Modifier.fillMaxSize().background(Color(0x6112120F))
                    .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onClose),
            )
        }
        AnimatedVisibility(
            state,
            enter = slideInHorizontally(tween(220)) { -it },
            exit = slideOutHorizontally(tween(220)) { -it },
        ) {
            BoxWithConstraints(Modifier.fillMaxHeight()) {
                val width = min(maxWidth * 0.84f, min(380.dp, maxWidth - 48.dp))
                val c = Wyn.colors
                Box(
                    Modifier.width(width).fillMaxHeight().background(c.bg)
                        .semantics { contentDescription = "drawer" }
                        .pointerInput(panel) {
                            var total = 0f
                            detectHorizontalDragGestures(
                                onDragStart = { total = 0f },
                                onDragEnd = { if (panel == null && total < -90.dp.toPx()) onClose() },
                            ) { _, amount -> total += amount }
                        },
                ) {
                    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(start = 14.dp, end = 14.dp, top = 10.dp, bottom = 14.dp)) {
                        Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
                            Identity(me) { go(actions.onProfile) }
                            Column(
                                Modifier.padding(top = 16.dp).fillMaxWidth().clip(RoundedCornerShape(19.dp)).border(1.dp, c.border, RoundedCornerShape(19.dp))
                                    .padding(horizontal = 12.dp, vertical = 3.dp),
                            ) {
                                MenuRow(WynIcons.Compass, stringResource(R.string.clubs_explore_title), first = true) { go(actions.onExploreClubs) }
                                MenuRow(WynIcons.Plus, stringResource(R.string.clubs_create)) { go(actions.onCreateClub) }
                                MenuRow(WynIcons.UsersRound, stringResource(R.string.my_clubs_title)) { go(actions.onMyClubs) }
                                MenuRow(WynIcons.Bookmark, stringResource(R.string.bookmarks_title)) { go(actions.onBookmarks) }
                            }
                        }
                        HorizontalDivider(color = c.border, thickness = 1.dp)
                        Row(Modifier.fillMaxWidth().padding(start = 2.dp, end = 2.dp, top = 14.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            FooterButton(WynIcons.MessageCircle, stringResource(R.string.drawer_feedback), Modifier.weight(1f)) { panel = DrawerPanel.Feedback }
                            FooterButton(WynIcons.CircleHelp, stringResource(R.string.drawer_help), Modifier.weight(1f)) { panel = DrawerPanel.Help }
                        }
                    }
                    panel?.let { current ->
                        Panel(current, onBack = { panel = null }, onSettings = { panel = null; go(actions.onSettings) })
                    }
                }
            }
        }
    }
}

@Composable
private fun Identity(me: ProfileSummary?, onClick: () -> Unit) {
    val c = Wyn.colors
    val profile = me?.profile
    Row(
        Modifier.fillMaxWidth().heightIn(min = 104.dp).clip(RoundedCornerShape(19.dp)).border(1.dp, c.border, RoundedCornerShape(19.dp))
            .clickable(enabled = me != null, role = Role.Button, onClick = onClick).padding(horizontal = 12.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        WynAvatar(profile?.avatarUrl, 58)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    profile?.label ?: "WYNOS", color = c.text, fontSize = 15.5.sp, lineHeight = 18.6.sp, fontWeight = FontWeight.ExtraBold,
                    maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false),
                )
                if (profile?.isVerified == true) {
                    Spacer(Modifier.width(3.dp))
                    VerifiedBadge(14, label = stringResource(R.string.verified))
                }
            }
            profile?.let { Text("@${it.username}", color = c.textSecondary, fontSize = 12.5.sp, maxLines = 1, overflow = TextOverflow.Ellipsis) }
            val followers = stringResource(R.string.profile_followers)
            val following = stringResource(R.string.drawer_following)
            Text(
                buildAnnotatedString {
                    withStyle(SpanStyle(color = c.text, fontWeight = FontWeight.Bold)) { append((me?.followerCount ?: 0).toString()) }
                    append(" $followers · ")
                    withStyle(SpanStyle(color = c.text, fontWeight = FontWeight.Bold)) { append((me?.followingCount ?: 0).toString()) }
                    append(" $following")
                },
                color = c.textSecondary, fontSize = 12.5.sp, lineHeight = 16.sp, maxLines = 1, modifier = Modifier.padding(top = 6.dp),
            )
        }
        Icon(WynIcons.ChevronRight, contentDescription = null, tint = c.text, modifier = Modifier.size(20.dp))
    }
}

@Composable
private fun MenuRow(icon: ImageVector, label: String, first: Boolean = false, onClick: () -> Unit) {
    val c = Wyn.colors
    if (!first) HorizontalDivider(color = c.border.copy(alpha = 0.62f), thickness = 1.dp)
    Row(
        Modifier.fillMaxWidth().heightIn(min = 58.dp).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(11.dp),
    ) {
        Box(Modifier.size(36.dp).clip(RoundedCornerShape(11.dp)).background(c.surface), contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription = null, tint = c.text, modifier = Modifier.size(22.dp))
        }
        Text(label, color = c.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
        Icon(WynIcons.ChevronRight, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(20.dp))
    }
}

@Composable
private fun FooterButton(icon: ImageVector, label: String, modifier: Modifier, onClick: () -> Unit) {
    val c = Wyn.colors
    Row(
        modifier.heightIn(min = 45.dp).clip(RoundedCornerShape(999.dp)).background(c.surface).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Icon(icon, contentDescription = null, tint = c.text, modifier = Modifier.size(19.dp))
        Spacer(Modifier.width(7.dp))
        Text(label, color = c.text, fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
    }
}

@Composable
private fun Panel(panel: DrawerPanel, onBack: () -> Unit, onSettings: () -> Unit) {
    val c = Wyn.colors
    val context = LocalContext.current
    var feedback by rememberSaveable { mutableStateOf("") }
    var status by rememberSaveable { mutableStateOf<Int?>(null) }
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding().navigationBarsPadding().imePadding().padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 18.dp)) {
        Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            val back = stringResource(R.string.drawer_back_to_menu)
            Icon(
                WynIcons.Back, contentDescription = back, tint = c.text,
                modifier = Modifier.size(44.dp).clip(RoundedCornerShape(999.dp)).clickable(role = Role.Button, onClickLabel = back, onClick = onBack).padding(10.dp),
            )
            Text(stringResource(if (panel == DrawerPanel.Help) R.string.drawer_help else R.string.drawer_feedback), color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold)
        }
        HorizontalDivider(color = c.border, thickness = 1.dp)
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(top = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            if (panel == DrawerPanel.Help) {
                Text(stringResource(R.string.help_faq), color = c.text, fontSize = 19.sp, fontWeight = FontWeight.Bold)
                HelpItem(stringResource(R.string.help_what_q), stringResource(R.string.help_what_a))
                HelpItem(stringResource(R.string.help_terms_q), stringResource(R.string.help_terms_a), stringResource(R.string.help_terms_action), onSettings)
            } else {
                Text(stringResource(R.string.feedback_title), color = c.text, fontSize = 19.sp, fontWeight = FontWeight.Bold)
                Text(stringResource(R.string.feedback_body), color = c.textSecondary, fontSize = 13.sp, lineHeight = 20.8.sp)
                Text(stringResource(R.string.feedback_label), color = c.text, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                val hint = stringResource(R.string.feedback_hint)
                BasicTextField(
                    value = feedback,
                    onValueChange = { feedback = it.take(FEEDBACK_MAX); status = null },
                    textStyle = TextStyle(color = c.text, fontSize = 16.sp),
                    cursorBrush = SolidColor(c.text),
                    modifier = Modifier.fillMaxWidth().semantics { contentDescription = hint },
                    decorationBox = { inner ->
                        Box(Modifier.fillMaxWidth().heightIn(min = 130.dp).clip(RoundedCornerShape(13.dp)).border(1.dp, c.border, RoundedCornerShape(13.dp)).padding(12.dp)) {
                            if (feedback.isEmpty()) Text(hint, color = c.textMuted, fontSize = 16.sp)
                            inner()
                        }
                    },
                )
                val ready = feedback.isNotBlank()
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    PanelButton(stringResource(R.string.feedback_copy), ready, Modifier.weight(1f)) { status = copyFeedback(context, feedback.trim()) }
                    PanelButton(stringResource(R.string.feedback_share), ready, Modifier.weight(1.35f)) {
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_SUBJECT, context.getString(R.string.feedback_share_title))
                            putExtra(Intent.EXTRA_TEXT, feedback.trim())
                        }
                        status = runCatching { context.startActivity(Intent.createChooser(send, null)) }
                            .fold({ R.string.feedback_shared }, { R.string.feedback_share_failed })
                    }
                }
                status?.let { Text(stringResource(it), color = c.text, fontSize = 13.sp, lineHeight = 20.8.sp) }
            }
        }
    }
}

private fun copyFeedback(context: Context, text: String): Int = runCatching {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    clipboard.setPrimaryClip(ClipData.newPlainText("WYNOS", text))
}.fold({ R.string.feedback_copied }, { R.string.feedback_copy_failed })

@Composable
private fun HelpItem(question: String, answer: String, action: String? = null, onAction: (() -> Unit)? = null) {
    val c = Wyn.colors
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(13.dp)).border(1.dp, c.border, RoundedCornerShape(13.dp)).padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(question, color = c.text, fontSize = 13.5.sp, fontWeight = FontWeight.Bold)
        Text(answer, color = c.textSecondary, fontSize = 13.sp, lineHeight = 20.8.sp)
        if (action != null && onAction != null) PanelButton(action, true, Modifier, onAction)
    }
}

@Composable
private fun PanelButton(label: String, enabled: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val c = Wyn.colors
    Box(
        modifier.heightIn(min = 44.dp).clip(RoundedCornerShape(12.dp)).border(1.dp, c.border, RoundedCornerShape(12.dp)).background(c.surface)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick).padding(horizontal = 10.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) { Text(label, color = c.text.copy(alpha = if (enabled) 1f else 0.45f), fontSize = 12.sp, fontWeight = FontWeight.SemiBold) }
}
