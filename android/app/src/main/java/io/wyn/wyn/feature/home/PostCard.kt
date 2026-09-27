package io.wyn.wyn.feature.home

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withLink
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import io.wyn.wyn.R
import io.wyn.wyn.core.data.FeedRow
import io.wyn.wyn.core.data.ViewerState
import io.wyn.wyn.core.design.DarkWynColors
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons
import kotlinx.coroutines.launch

// Web home.css / computed styles (411px viewport).
private val LinkBlue = Color(0xFF1D9BF0)
private val ActionGrey = Color(0xFF8B919B)
private val LikeRed = Color(0xFFFF3B30)
private val MetaGrey = Color(0xFF78787D)
private val RepostLineGrey = Color(0xFF737378)

data class PostCallbacks(
    val onLike: () -> Unit = {},
    val onPhotoLike: () -> Unit = {},
    val onComment: () -> Unit = {},
    val onRepost: () -> Unit = {},
    val onShare: () -> Unit = {},
    val onSave: () -> Unit = {},
    val onFollow: () -> Unit = {},
    val onMore: () -> Unit = {},
    val onOpenPost: () -> Unit = {},
    val onOpenAuthor: () -> Unit = {},
    val onTag: (String) -> Unit = {},
)

@Composable
fun rememberEnglish(): Boolean = LocalConfiguration.current.locales[0].language == "en"

/** One Home feed card (web HomePostCard). */
@Composable
fun PostCard(row: FeedRow, viewer: ViewerState, images: List<String>, userId: String, actions: PostCallbacks) {
    val c = Wyn.colors
    val english = rememberEnglish()
    val time = FeedText.relativeTime(row.createdAt, english)
    val timeAndPlace = row.location?.let { "$time · 📍 $it" } ?: time
    Column(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = if (row.redropId != null) 10.dp else 8.dp)) {
        if (row.redropId != null) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(start = 21.dp, bottom = 1.dp).height(20.dp),
            ) {
                Icon(WynIcons.RepostSmall, contentDescription = null, tint = RepostLineGrey, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(5.dp))
                Text(
                    stringResource(R.string.reposted_by, row.redropperUsername ?: "WYNOS", time),
                    color = RepostLineGrey, fontSize = 14.sp, fontWeight = FontWeight.Medium, maxLines = 1, overflow = TextOverflow.Ellipsis,
                )
            }
        }
        row.quoteText?.takeIf { it.isNotBlank() }?.let { quote ->
            RichText(quote, compact = false, onTag = actions.onTag, modifier = Modifier.padding(bottom = 6.dp))
        }
        Row {
            WynAvatar(
                row.authorAvatarUrl, 40,
                modifier = Modifier.padding(top = 1.dp).clickable(onClick = actions.onOpenAuthor),
                contentDescription = row.authorLabel,
            )
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                AuthorRow(row, viewer, userId, timeAndPlace, actions)
                row.caption?.takeIf { it.isNotBlank() }?.let { Caption(it, actions) }
                if (images.isNotEmpty()) {
                    PostMedia(images, row.mediaAspectRatio(images.size > 1), actions.onPhotoLike)
                }
                ActionRow(row, viewer, actions)
            }
        }
    }
}

@Composable
private fun AuthorRow(row: FeedRow, viewer: ViewerState, userId: String, time: String, actions: PostCallbacks) {
    val c = Wyn.colors
    val following = row.authorId in viewer.following
    val requested = row.authorId in viewer.requested
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.heightIn(min = 26.dp)) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.weight(1f).clickable(onClick = actions.onOpenAuthor),
        ) {
            Text(
                row.authorLabel, color = c.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false),
            )
            if (row.authorIsVerified) {
                Text(" ✓", color = LinkBlue, fontSize = 13.sp, fontWeight = FontWeight.Bold)
            }
            Text(" · $time", color = MetaGrey, fontSize = 14.sp, maxLines = 1)
        }
        if (row.authorId != userId && !following) {
            val dark = c.bg == DarkWynColors.bg
            Box(
                Modifier
                    .height(26.dp)
                    .clip(RoundedCornerShape(999.dp))
                    .background(if (dark) Color(0xFF111111) else Color(0xFFF5F5F5))
                    .clickable(role = Role.Button, onClick = actions.onFollow)
                    .padding(horizontal = 11.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    stringResource(if (requested) R.string.follow_requested else R.string.follow),
                    color = c.text, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                )
            }
        }
        val more = stringResource(R.string.more)
        Box(
            Modifier.padding(start = 4.dp).size(28.dp, 26.dp).clickable(role = Role.Button, onClick = actions.onMore).semantics { contentDescription = more },
            contentAlignment = Alignment.Center,
        ) {
            Icon(WynIcons.More, contentDescription = null, tint = Color(0xFF737373), modifier = Modifier.size(16.dp))
        }
    }
}

@Composable
private fun Caption(caption: String, actions: PostCallbacks) {
    val split = remember(caption) { FeedText.splitCaption(caption) }
    Column(Modifier.padding(top = 4.dp)) {
        if (split.prose.isNotEmpty()) {
            // The web caption stops 10px short of the post column (319 of 329px).
            RichText(split.prose, compact = true, onTag = actions.onTag, onBody = actions.onOpenPost, modifier = Modifier.padding(end = 10.dp))
        }
        if (split.truncated) {
            val more = stringResource(R.string.see_more)
            Text(
                buildAnnotatedString {
                    if (split.tags.isNotEmpty()) {
                        append(richText(split.tags, actions.onTag))
                        append(" ")
                    }
                    append("… $more")
                },
                style = CaptionStyle.copy(color = RepostLineGrey, fontSize = 15.sp),
                modifier = Modifier.clickable(onClick = actions.onOpenPost),
            )
        } else if (split.tags.isNotEmpty()) {
            RichText(split.tags, compact = true, onTag = actions.onTag, modifier = Modifier.padding(top = 4.dp))
        }
    }
}

private val CaptionStyle = TextStyle(fontSize = 16.sp, lineHeight = 21.sp)

/** The web's RichPostText: URLs, #tags and @mentions in link blue; the rest is plain text. */
@Composable
fun RichText(value: String, compact: Boolean, onTag: (String) -> Unit, modifier: Modifier = Modifier, onBody: (() -> Unit)? = null) {
    val text = if (compact) FeedText.compact(value) else value
    Text(
        richText(text, onTag),
        style = CaptionStyle.copy(color = Wyn.colors.text),
        modifier = if (onBody != null) modifier.clickable(onClick = onBody) else modifier,
    )
}

private fun richText(text: String, onTag: (String) -> Unit): AnnotatedString = buildAnnotatedString {
    var last = 0
    for (match in FeedText.tokenPattern.findAll(text)) {
        append(text.substring(last, match.range.first))
        val token = match.value
        val link = if (token.startsWith("http", ignoreCase = true)) {
            LinkAnnotation.Url(token, TextLinkStyles(SpanStyle(color = LinkBlue)))
        } else {
            LinkAnnotation.Clickable(token, TextLinkStyles(SpanStyle(color = LinkBlue))) { onTag(token) }
        }
        withLink(link) { append(token) }
        last = match.range.last + 1
    }
    append(text.substring(last))
}

/** web PostMediaCarousel: one full-width photo, or a peeking row where side photos shrink to 86%. */
@Composable
private fun PostMedia(urls: List<String>, ratio: Float, onDoubleTap: () -> Unit) {
    val burst = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    val tap = Modifier.pointerInput(urls) {
        detectTapGestures(onDoubleTap = {
            onDoubleTap()
            scope.launch {
                burst.snapTo(0f)
                burst.animateTo(1f, tween(700))
                burst.snapTo(0f)
            }
        })
    }
    Box(Modifier.padding(top = 8.dp).fillMaxWidth().then(tap)) {
        if (urls.size == 1) {
            Photo(urls[0], Modifier.fillMaxWidth().aspectRatio(ratio))
        } else {
            BoxWithConstraints {
                val itemWidth = (maxWidth - 16.dp) * 0.82f
                val state = rememberLazyListState()
                val front by remember { derivedStateOf { state.firstVisibleItemIndex + if (state.firstVisibleItemScrollOffset > 0) 1 else 0 } }
                LazyRow(
                    state = state,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    flingBehavior = rememberSnapFlingBehavior(state),
                ) {
                    itemsIndexed(urls) { index, url ->
                        val scale = if (index == front.coerceAtMost(urls.lastIndex)) 1f else 0.86f
                        Photo(
                            url,
                            Modifier
                                .width(itemWidth)
                                .aspectRatio(ratio)
                                .graphicsLayer {
                                    scaleX = scale
                                    scaleY = scale
                                    transformOrigin = if (index > front) TransformOrigin(0f, 0.5f) else TransformOrigin(1f, 0.5f)
                                },
                        )
                    }
                }
            }
        }
        if (burst.value > 0f) {
            val t = burst.value
            val scale = if (t < 0.35f) 0.4f + (1.15f - 0.4f) * (t / 0.35f) else 1.15f - 0.15f * ((t - 0.35f) / 0.65f)
            val alpha = if (t < 0.35f) t / 0.35f else 1f - (t - 0.35f) / 0.65f
            Icon(
                WynIcons.HeartFilled, contentDescription = null, tint = Color.White,
                modifier = Modifier.align(Alignment.Center).size(72.dp).graphicsLayer { scaleX = scale; scaleY = scale; this.alpha = alpha },
            )
        }
    }
}

@Composable
private fun Photo(url: String, modifier: Modifier) {
    AsyncImage(
        model = url,
        contentDescription = null,
        contentScale = ContentScale.Crop,
        modifier = modifier.clip(RoundedCornerShape(14.dp)).background(Wyn.colors.surface),
    )
}

/** web PostActions (modernFeed): muted icons, zero counts hidden, save pushed to the end. */
@Composable
private fun ActionRow(row: FeedRow, viewer: ViewerState, actions: PostCallbacks) {
    val c = Wyn.colors
    val liked = row.id in viewer.liked
    val saved = row.id in viewer.saved
    val reposted = row.id in viewer.redropped
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(18.dp),
        modifier = Modifier.fillMaxWidth().padding(top = 4.dp, bottom = 8.dp).heightIn(min = 34.dp),
    ) {
        Action(
            if (liked) WynIcons.HeartFilled else WynIcons.Heart, row.likeCount, if (liked) LikeRed else ActionGrey,
            stringResource(if (liked) R.string.unlike else R.string.like), actions.onLike,
        )
        Action(WynIcons.Comment, row.commentCount, ActionGrey, stringResource(R.string.comments), actions.onComment, iconSize = 24)
        if (row.canRedrop) {
            Action(WynIcons.Repost, row.redropCount, if (reposted) c.text else ActionGrey, stringResource(R.string.repost), actions.onRepost)
        }
        Action(WynIcons.Share, 0, ActionGrey, stringResource(R.string.share), actions.onShare)
        Spacer(Modifier.weight(1f))
        Action(
            if (saved) WynIcons.SaveFilled else WynIcons.Save, 0, if (saved) c.text else ActionGrey,
            stringResource(if (saved) R.string.unsave else R.string.save), actions.onSave,
        )
    }
}

@Composable
private fun Action(icon: ImageVector, count: Int, tint: Color, label: String, onClick: () -> Unit, iconSize: Int = 22) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .heightIn(min = 34.dp)
            .clickable(role = Role.Button, onClickLabel = label, onClick = onClick)
            .semantics { contentDescription = label },
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(iconSize.dp))
        if (count > 0) {
            Spacer(Modifier.width(5.dp))
            Text(count.toString(), color = tint, fontSize = 13.sp, fontWeight = FontWeight.Medium)
        }
    }
}
