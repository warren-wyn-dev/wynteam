package io.wyn.wyn.feature.clubs

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import io.wyn.wyn.R
import io.wyn.wyn.core.data.ClubPost
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.feature.home.FeedText
import io.wyn.wyn.feature.home.RichText
import io.wyn.wyn.feature.home.rememberEnglish

private val FeedActionGrey = Color(0xFF8B919B)
private val FeedLikeRed = Color(0xFFFF3B30)
private val FeedMetaGrey = Color(0xFF78787D)

/** What a Club post card can do; the Club page and Home fill in what they support. */
data class ClubPostActions(
    val onLike: () -> Unit,
    val onOpen: () -> Unit,
    val onAuthor: () -> Unit,
    val onMore: () -> Unit = {},
    val onVote: (Int) -> Unit = {},
)

/** web ClubPostCard on the Club page (golden-club-post). */
@Composable
fun ClubPostCard(post: ClubPost, actions: ClubPostActions) {
    val c = Wyn.colors
    val english = rememberEnglish()
    Column {
        Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 14.dp)) {
            WynAvatar(post.authorAvatarUrl, 42, Modifier.clickable(role = Role.Button, onClick = actions.onAuthor), contentDescription = post.authorLabel)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Row(Modifier.heightIn(min = 30.dp)) {
                    Column(Modifier.weight(1f).clickable(onClick = actions.onAuthor)) {
                        Text(post.authorLabel, color = c.text, fontSize = 14.5.sp, lineHeight = 17.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(FeedText.relativeTime(post.createdAt, english), color = c.textSecondary, fontSize = 12.sp, lineHeight = 13.sp, modifier = Modifier.padding(top = 2.dp))
                    }
                    val more = stringResource(R.string.more)
                    Box(
                        Modifier.offset(x = 8.dp, y = (-8).dp).size(44.dp).clip(RoundedCornerShape(999.dp))
                            .clickable(role = Role.Button, onClickLabel = more, onClick = actions.onMore).semantics { contentDescription = more },
                        contentAlignment = Alignment.Center,
                    ) { Icon(WynIcons.MoreVertical, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(22.dp)) }
                }
                if (post.pinned) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(top = 4.dp, bottom = 6.dp).clip(RoundedCornerShape(999.dp)).background(c.surface).padding(horizontal = 8.dp, vertical = 3.dp),
                    ) {
                        Icon(WynIcons.Pin, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(12.dp))
                        Spacer(Modifier.width(4.dp))
                        Text(stringResource(R.string.club_pinned), color = c.textSecondary, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    }
                }
                post.content?.takeIf { it.isNotEmpty() }?.let { content ->
                    Text(
                        content, style = TextStyle(color = c.text, fontSize = 15.sp, lineHeight = 21.75.sp),
                        modifier = Modifier.padding(vertical = 8.dp).clickable(onClick = actions.onOpen),
                    )
                }
                if (post.imageUrls.isNotEmpty()) ClubMedia(post.imageUrls, actions.onOpen)
                if (post.pollId != null) ClubPoll(post, actions.onVote)
                post.linkUrl?.let { url -> ClubLink(url) }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(20.dp),
                    modifier = Modifier.padding(top = 8.dp),
                ) {
                    ClubAction(
                        if (post.liked) WynIcons.LucideHeartFilled else WynIcons.LucideHeart, post.likeCount,
                        if (post.liked) c.like else c.textSecondary, stringResource(if (post.liked) R.string.unlike else R.string.like), actions.onLike, 17,
                    )
                    ClubAction(WynIcons.MessageCircle, post.commentCount, c.textSecondary, stringResource(R.string.comments), actions.onOpen, 17)
                }
            }
        }
        HorizontalDivider(color = c.border, thickness = 1.dp)
    }
}

/** web ClubFeedPost: a Club post in Home's "คลับของฉัน", shaped like a Home post. */
@Composable
fun ClubFeedCard(post: ClubPost, actions: ClubPostActions) {
    val c = Wyn.colors
    val english = rememberEnglish()
    Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 9.dp)) {
        WynAvatar(post.authorAvatarUrl, 40, Modifier.padding(top = 1.dp).clickable(onClick = actions.onAuthor), contentDescription = post.authorLabel)
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.heightIn(min = 24.dp).clickable(onClick = actions.onAuthor)) {
                Text(
                    post.authorLabel, color = c.text, fontSize = 14.sp, lineHeight = 18.sp, fontWeight = FontWeight.SemiBold,
                    maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false),
                )
                Text(" · ${FeedText.relativeTime(post.createdAt, english)}", color = FeedMetaGrey, fontSize = 13.5.sp, maxLines = 1)
            }
            post.content?.takeIf { it.isNotBlank() }?.let { content ->
                RichText(
                    content, compact = true, onTag = {}, onBody = actions.onOpen,
                    style = TextStyle(fontSize = 15.sp, lineHeight = 22.5.sp), modifier = Modifier.padding(top = 6.dp),
                )
            }
            if (post.imageUrls.isNotEmpty()) Box(Modifier.padding(top = 8.dp)) { ClubMedia(post.imageUrls, actions.onOpen, feed = true) }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(18.dp),
                modifier = Modifier.fillMaxWidth().padding(top = 4.dp, bottom = 8.dp).heightIn(min = 34.dp),
            ) {
                ClubAction(
                    if (post.liked) WynIcons.LucideHeartFilled else WynIcons.LucideHeart, post.likeCount,
                    if (post.liked) FeedLikeRed else FeedActionGrey, stringResource(if (post.liked) R.string.unlike else R.string.like), actions.onLike, 20,
                )
                ClubAction(WynIcons.MessageCircle, post.commentCount, FeedActionGrey, stringResource(R.string.comments), actions.onOpen, 20)
            }
        }
    }
}

@Composable
private fun ClubAction(icon: ImageVector, count: Int, tint: Color, label: String, onClick: () -> Unit, iconSize: Int) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.heightIn(min = 38.dp).clickable(role = Role.Button, onClickLabel = label, onClick = onClick).semantics { contentDescription = label },
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(iconSize.dp))
        if (count > 0) {
            Spacer(Modifier.width(5.dp))
            Text(count.toString(), color = tint, fontSize = 13.sp)
        }
    }
}

/** golden-club-media: one square photo, or a row of 82%-wide squares. */
@Composable
private fun ClubMedia(urls: List<String>, onOpen: () -> Unit, feed: Boolean = false) {
    val c = Wyn.colors
    val shape = RoundedCornerShape(16.dp)
    if (urls.size == 1) {
        AsyncImage(
            urls.first(), contentDescription = null, contentScale = ContentScale.Crop,
            modifier = Modifier.padding(top = if (feed) 0.dp else 8.dp).fillMaxWidth().aspectRatio(1f).clip(shape).background(c.surface).clickable(onClick = onOpen),
        )
        return
    }
    BoxWithConstraints(Modifier.padding(top = if (feed) 0.dp else 8.dp).fillMaxWidth()) {
        val width = maxWidth * 0.82f
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            urls.forEach { url ->
                AsyncImage(
                    url, contentDescription = null, contentScale = ContentScale.Crop,
                    modifier = Modifier.width(width).aspectRatio(1f).clip(shape).background(c.surface).clickable(onClick = onOpen),
                )
            }
        }
    }
}

@Composable
private fun ClubLink(url: String) {
    val c = Wyn.colors
    val uri = LocalUriHandler.current
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(top = 8.dp).fillMaxWidth().heightIn(min = 44.dp).clip(RoundedCornerShape(10.dp))
            .border(1.dp, c.border, RoundedCornerShape(10.dp))
            .clickable(role = Role.Button) { if (url.startsWith("https://") || url.startsWith("http://")) runCatching { uri.openUri(url) } }
            .padding(horizontal = 10.dp),
    ) {
        Icon(WynIcons.Link, contentDescription = null, tint = c.text, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(7.dp))
        Text(url, color = c.text, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** web ClubPoll: options with results once they are visible, and time left. */
@Composable
private fun ClubPoll(post: ClubPost, onVote: (Int) -> Unit) {
    val c = Wyn.colors
    val time = pollTime(post.pollExpiresAt)
    val closed = time == PollTime.Closed
    val visible = post.pollTotalVotes != null && post.pollOptionCounts != null
    Column(Modifier.padding(top = 8.dp).padding(horizontal = 12.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        post.pollOptions.forEachIndexed { index, option ->
            val mine = post.pollMyVote == index
            val pct = post.pollPercent(index) ?: 0
            val shape = RoundedCornerShape(12.dp)
            Box(
                Modifier.fillMaxWidth().height(44.dp).clip(shape).border(1.dp, if (mine) c.text else c.border, shape).background(c.bg)
                    .clickable(enabled = !closed, role = Role.Button) { onVote(index) },
            ) {
                if (visible) {
                    Box(Modifier.fillMaxHeight().fillMaxWidth(pct / 100f).background(c.text.copy(alpha = if (mine) 0.34f else 0.14f)))
                }
                Row(Modifier.fillMaxWidth().fillMaxHeight().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                    if (mine) {
                        Icon(WynIcons.Check, contentDescription = null, tint = c.text, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(5.dp))
                    }
                    Text(option, color = c.text, fontSize = 14.sp, fontWeight = FontWeight.Medium, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                    if (visible) Text("$pct%", color = c.text, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
        val remaining = pollTimeLabel(time)
        val total = post.pollTotalVotes ?: 0
        val summary = when {
            !visible -> remaining
            total > 0 -> stringResource(R.string.poll_votes, total, remaining)
            else -> stringResource(R.string.poll_no_votes, remaining)
        }
        if (summary.isNotEmpty()) Text(summary, color = c.textSecondary, fontSize = 11.5.sp)
    }
}

@Composable
private fun pollTimeLabel(time: PollTime): String = when (time) {
    PollTime.None -> ""
    PollTime.Closed -> stringResource(R.string.poll_closed)
    is PollTime.Days -> stringResource(R.string.poll_days_left, time.n)
    is PollTime.Hours -> stringResource(R.string.poll_hours_left, time.n)
    is PollTime.Minutes -> stringResource(R.string.poll_minutes_left, time.n)
}
