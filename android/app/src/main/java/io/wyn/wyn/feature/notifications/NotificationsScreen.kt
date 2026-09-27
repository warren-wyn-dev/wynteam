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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.wyn.wyn.R
import io.wyn.wyn.core.data.NotificationItem
import io.wyn.wyn.core.design.DarkWynColors
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.home.EmptyState
import io.wyn.wyn.feature.home.FeedSkeleton
import io.wyn.wyn.feature.home.FeedText
import io.wyn.wyn.feature.home.rememberEnglish
import io.wyn.wyn.feature.profile.PillButton
import java.time.LocalDate
import java.time.ZoneId

private val Sapphire = Color(0xFF1B3A6B)
private val CommentGreen = Color(0xFF3A5A40)
private val RepostBrown = Color(0xFF8A6D3A)
private val MessageInk = Color(0xFF2B2A26)

/** web actorLabel(). */
fun actorLabel(row: NotificationItem): String =
    row.actorDisplayName?.trim()?.takeIf { it.isNotEmpty() } ?: row.actorUsername?.let { "@$it" } ?: "WYNOS"

/** web messageFor(): the sentence for each notification type. */
@Composable
fun notificationMessage(row: NotificationItem): String {
    val actor = actorLabel(row)
    val club = row.clubName ?: "Club"
    val reason = row.reason?.takeIf { it.isNotBlank() }
    return when (row.type) {
        "like_drop" -> stringResource(R.string.notif_like_drop, actor)
        "comment_drop" -> stringResource(R.string.notif_comment_drop, actor)
        "like_pop" -> stringResource(R.string.notif_like_pop, actor)
        "comment_pop" -> stringResource(R.string.notif_comment_pop, actor)
        "follow" -> stringResource(R.string.notif_follow, actor)
        "follow_request" -> stringResource(R.string.notif_follow_request, actor)
        "follow_request_accepted" -> stringResource(R.string.notif_follow_accepted, actor)
        "redrop" -> stringResource(R.string.notif_redrop, actor)
        "mention_drop" -> stringResource(R.string.notif_mention_drop, actor)
        "mention_club_post" -> stringResource(R.string.notif_mention_club_post, actor, club)
        "club_join_request" -> stringResource(R.string.notif_club_join_request, actor, club)
        "club_join_approved" -> stringResource(R.string.notif_club_join_approved, actor, club)
        "club_post_like" -> stringResource(R.string.notif_club_post_like, actor, club)
        "club_post_comment" -> stringResource(R.string.notif_club_post_comment, actor, club)
        "club_post_new" -> stringResource(R.string.notif_club_post_new, actor, club)
        "club_post_pinned" -> stringResource(R.string.notif_club_post_pinned, actor, club)
        "club_announcement" -> stringResource(R.string.notif_club_announcement, actor, club)
        "club_invite" -> stringResource(R.string.notif_club_invite, actor, club)
        "message_request" -> stringResource(R.string.notif_message_request, actor)
        "new_message" -> stringResource(R.string.notif_new_message, actor)
        "moderation_warning" -> if (reason != null) stringResource(R.string.notif_moderation_warning_reason, reason) else stringResource(R.string.notif_moderation_warning)
        "moderation_content_removed" -> if (reason != null) stringResource(R.string.notif_content_removed_reason, reason) else stringResource(R.string.notif_content_removed)
        "appeal_approved" -> stringResource(R.string.notif_appeal_approved)
        "appeal_rejected" -> if (reason != null) stringResource(R.string.notif_appeal_rejected_reason, reason) else stringResource(R.string.notif_appeal_rejected)
        "system" -> reason ?: stringResource(R.string.notif_system)
        else -> stringResource(R.string.notif_other, actor)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(vm: NotificationsViewModel, onBack: () -> Unit, onOpen: (NotificationItem) -> Unit) {
    val c = Wyn.colors
    val english = rememberEnglish()
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding()) {
        Row(Modifier.fillMaxWidth().height(68.dp).padding(start = 14.dp, end = 14.dp, top = 5.dp), verticalAlignment = Alignment.CenterVertically) {
            val back = stringResource(R.string.notifications_close)
            Icon(
                WynIcons.Back, contentDescription = back, tint = c.text,
                modifier = Modifier.size(36.dp, 44.dp).clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button, onClickLabel = back, onClick = onBack).padding(horizontal = 4.dp, vertical = 8.dp),
            )
            Spacer(Modifier.width(6.dp))
            Text(stringResource(R.string.notifications_title), color = c.text, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
        vm.error?.let { error ->
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(error.text().orEmpty(), color = c.accent, fontSize = 13.sp, modifier = Modifier.weight(1f))
                PillButton(stringResource(R.string.retry), filled = false, outlined = true, height = 32.dp, fontSize = 12, onClick = vm::retry)
            }
        }
        PullToRefreshBox(isRefreshing = vm.refreshing, onRefresh = vm::pullToRefresh, modifier = Modifier.weight(1f)) {
            val visible = vm.visible
            val today = remember { LocalDate.now() }
            val sections = remember(visible) { NotificationRules.sections(visible, today, ZoneId.systemDefault()) }
            LazyColumn(Modifier.fillMaxSize()) {
                when {
                    vm.loading && vm.rows.isEmpty() -> item(key = "loading") { FeedSkeleton() }
                    visible.isEmpty() -> item(key = "empty") {
                        EmptyState(stringResource(if (vm.tab == NotificationTab.Mentions) R.string.notifications_no_mentions else R.string.notifications_empty), null) {}
                    }
                    else -> {
                        for (section in sections) {
                            item(key = "label:${section.bucket}") {
                                Text(
                                    stringResource(
                                        when (section.bucket) {
                                            DayBucket.Today -> R.string.notifications_today
                                            DayBucket.Yesterday -> R.string.notifications_yesterday
                                            DayBucket.Older -> R.string.notifications_earlier
                                        },
                                    ),
                                    color = c.textSecondary, fontSize = 14.sp, fontWeight = FontWeight.Medium,
                                    modifier = Modifier.padding(start = 34.dp, end = 34.dp, top = 2.dp, bottom = 8.dp),
                                )
                            }
                            items(section.groups, key = { it.head.id }) { group ->
                                NotificationRow(group, unread = group.items.any { it.id in vm.unreadSnapshot }, english = english) { onOpen(group.head) }
                            }
                        }
                        if (vm.tab == NotificationTab.All) {
                            item(key = "end") {
                                if (vm.hasMore) {
                                    Box(Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) {
                                        PillButton(stringResource(R.string.see_more), filled = false, enabled = !vm.loading, height = 38.dp, fontSize = 13, onClick = vm::loadMore)
                                    }
                                } else {
                                    Text(
                                        stringResource(R.string.notifications_end), color = c.textSecondary, fontSize = 14.sp, textAlign = TextAlign.Center,
                                        modifier = Modifier.fillMaxWidth().padding(top = 40.dp, bottom = 24.dp),
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NotificationRow(group: NotificationGroup, unread: Boolean, english: Boolean, onClick: () -> Unit) {
    val c = Wyn.colors
    val row = group.head
    val message = notificationMessage(row)
    val actor = actorLabel(row)
    val more = if (group.extraActorCount > 0) stringResource(R.string.notifications_and_others, group.extraActorCount) else null
    val ink = if (c.bg == DarkWynColors.bg) c.text else MessageInk
    Row(
        Modifier.fillMaxWidth().heightIn(min = 64.dp).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(46.dp)) {
            Box(Modifier.size(46.dp).border(1.dp, Sapphire.copy(alpha = 0.2f), CircleShape), contentAlignment = Alignment.Center) {
                WynAvatar(row.actorAvatarUrl, 40)
            }
            TypeBadge(row.type, Modifier.align(Alignment.BottomEnd).offset(2.dp, 2.dp))
        }
        Column(Modifier.weight(1f).padding(top = 1.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                buildAnnotatedString {
                    if (row.actorId != null && message.startsWith(actor)) {
                        withStyle(SpanStyle(fontWeight = FontWeight.Bold, color = c.text)) { append(actor) }
                        append(message.substring(actor.length))
                    } else {
                        append(message)
                    }
                    if (more != null) withStyle(SpanStyle(color = c.textSecondary, fontStyle = FontStyle.Normal)) { append(" $more") }
                },
                color = ink, fontSize = 15.sp, lineHeight = 20.sp,
            )
            row.contentPreview?.takeIf { it.isNotBlank() }?.let {
                Text("“$it”", color = c.textSecondary, fontSize = 13.sp, lineHeight = 17.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Text(FeedText.relativeTime(row.createdAt, english), color = c.textSecondary, fontSize = 13.sp, lineHeight = 17.sp)
        }
        Box(Modifier.width(10.dp).align(Alignment.Top).padding(top = 12.dp)) {
            if (unread) Box(Modifier.size(7.dp).clip(CircleShape).background(if (c.bg == DarkWynColors.bg) c.link else Sapphire))
        }
    }
}

@Composable
private fun TypeBadge(type: String, modifier: Modifier) {
    val (icon: ImageVector, color: Color) = when {
        type.contains("like") -> WynIcons.HeartFilled to Wyn.colors.like
        type == "redrop" -> WynIcons.RepostSmall to RepostBrown
        type == "follow" || type == "follow_request_accepted" -> WynIcons.UserPlus to Sapphire
        type.contains("comment") -> WynIcons.Comment to CommentGreen
        else -> return
    }
    Box(modifier.size(18.dp).clip(CircleShape).background(Wyn.colors.bg).padding(1.5.dp).clip(CircleShape).background(color), contentAlignment = Alignment.Center) {
        Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(10.dp))
    }
}
