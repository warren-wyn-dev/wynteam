package io.wyn.wyn.core.design

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.unit.dp

/**
 * The web's icons, drawn from the same 24×24 SVG paths so both platforms
 * look identical: Lucide (ISC licence) for WynosIcon, plus the Founder's
 * post-action and tab-bar sets (components/ui/post-action-icons.tsx,
 * components/bottom-navigation.tsx). Tint them with Icon(tint = …).
 */
object WynIcons {
    val Menu = stroke(1.8f, "M4 5h16", "M4 12h16", "M4 19h16")
    val Search = stroke(1.8f, "m21 21-4.34-4.34", circle(11f, 11f, 8f))
    val Bell = stroke(
        1.8f,
        "M10.268 21a2 2 0 0 0 3.464 0",
        "M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326",
    )
    val Image = stroke(1.7f, rect(3f, 3f, 18f, 18f, 2f), circle(9f, 9f, 2f), "m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21")
    val More = stroke(2f, circle(12f, 12f, 1f), circle(19f, 12f, 1f), circle(5f, 12f, 1f))
    val RepostSmall = stroke(2f, "m2 9 3-3 3 3", "M13 18H7a2 2 0 0 1-2-2V6", "m22 15-3 3-3-3", "M11 6h6a2 2 0 0 1 2 2v10")
    val Close = stroke(2f, "M18 6 6 18", "m6 6 12 12")
    val Flag = stroke(
        2f,
        "M4 22V4a1 1 0 0 1 .4-.8A6 6 0 0 1 8 2c3 0 5 2 7.333 2q2 0 3.067-.8A1 1 0 0 1 20 4v10a1 1 0 0 1-.4.8A6 6 0 0 1 16 16c-3 0-5-2-8-2a6 6 0 0 0-4 1.528",
    )
    val Back = stroke(2f, "m15 18-6-6 6-6")
    val Poll = stroke(2f, "M3 3v16a2 2 0 0 0 2 2h16", "M18 17V9", "M13 17V5", "M8 17v-3")
    val ChevronRight = stroke(2f, "m9 18 6-6-6-6")
    val MoreVertical = stroke(2f, circle(12f, 12f, 1f), circle(12f, 5f, 1f), circle(12f, 19f, 1f))
    val Trash = stroke(2f, "M10 11v6", "M14 11v6", "M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6", "M3 6h18", "M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2")
    val Send = stroke(
        2f,
        "M14.536 21.686a.5.5 0 0 0 .937-.024l6.5-19a.496.496 0 0 0-.635-.635l-19 6.5a.5.5 0 0 0-.024.937l7.93 3.18a2 2 0 0 1 1.112 1.11z",
        "m21.854 2.147-10.94 10.939",
    )
    val Pencil = stroke(
        2f,
        "M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z",
        "m15 5 4 4",
    )

    // Post actions (Founder-supplied set, 2026-09-22).
    private const val HEART = "M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.6l-1-1a5.5 5.5 0 0 0-7.8 7.8l1 1L12 21l7.8-7.6 1-1a5.5 5.5 0 0 0 0-7.8Z"
    private const val SAVE = "M19 21 12 16l-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"
    val Heart = stroke(2f, HEART)
    val HeartFilled = stroke(2f, HEART, filled = true)
    val Comment = stroke(
        2f,
        "M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5Z",
    )
    val Repost = stroke(2f, "M3 12a9 9 0 0 1 15.4-6.36L21 8", "M21 3v5h-5", "M21 12a9 9 0 0 1-15.4 6.36L3 16", "M8 16H3v5")
    val Share = stroke(
        2f,
        "M12 15.5V3.5m0 0L7.75 7.75M12 3.5l4.25 4.25M4.75 11.75v7.1a2.4 2.4 0 0 0 2.4 2.4h9.7a2.4 2.4 0 0 0 2.4-2.4v-7.1",
    )
    val Save = stroke(2f, SAVE)
    val SaveFilled = stroke(2f, SAVE, filled = true)

    // Bottom navigation ("Tab Bar A", 1.7 stroke; selected tabs fill).
    private val homePaths = arrayOf("m3 11 9-8 9 8", "M5 10v10h14V10")
    private val clubPaths = arrayOf(
        "M17 21v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2", circle(10f, 7f, 4f),
        "M21 21v-2a4 4 0 0 0-3-3.87", "M16 3.13a4 4 0 0 1 0 7.75",
    )
    private const val CHAT =
        "M12 2C6.48 2 2 5.94 2 10.8c0 2.77 1.46 5.24 3.75 6.86-.13 1.13-.5 2.36-1.32 3.62a.5.5 0 0 0 .58.75c1.9-.6 3.36-1.4 4.4-2.11.83.17 1.7.26 2.59.26 5.52 0 10-3.94 10-8.8S17.52 2 12 2Z"
    private val profilePaths = arrayOf(circle(12f, 8f, 4f), "M4 21c0-4 4-6 8-6s8 2 8 6")
    val NavHome = stroke(1.7f, *homePaths)
    val NavHomeSelected = stroke(1.7f, *homePaths, filled = true)
    val NavClub = stroke(1.7f, *clubPaths)
    val NavClubSelected = stroke(1.7f, *clubPaths, filled = true)
    val NavChat = stroke(1.7f, CHAT)
    val NavChatSelected = stroke(1.7f, CHAT, filled = true)
    val NavProfile = stroke(1.7f, *profilePaths)
    val NavProfileSelected = stroke(1.7f, *profilePaths, filled = true)
    val NavAdd = stroke(1.7f, circle(12f, 12f, 9.5f), "M12 7.5v9M7.5 12h9")

    /** The web's DefaultProfileAvatar glyph (40×40 viewBox, filled). */
    val DefaultAvatar: ImageVector = ImageVector.Builder("avatar", 40.dp, 40.dp, 40f, 40f).apply {
        addPath(PathParser().parsePathString(circle(20f, 12.5f, 7f)).toNodes(), fill = SolidColor(Color.Black))
        addPath(PathParser().parsePathString("M4.8 34.8c0-8.7 6.8-13.7 15.2-13.7s15.2 5 15.2 13.7v.7H4.8z").toNodes(), fill = SolidColor(Color.Black))
    }.build()

    private fun stroke(width: Float, vararg paths: String, filled: Boolean = false): ImageVector =
        ImageVector.Builder(defaultWidth = 24.dp, defaultHeight = 24.dp, viewportWidth = 24f, viewportHeight = 24f).apply {
            for (d in paths) {
                addPath(
                    pathData = PathParser().parsePathString(d).toNodes(),
                    fill = if (filled) SolidColor(Color.Black) else null,
                    stroke = SolidColor(Color.Black),
                    strokeLineWidth = width,
                    strokeLineCap = StrokeCap.Round,
                    strokeLineJoin = StrokeJoin.Round,
                )
            }
        }.build()

    private fun circle(cx: Float, cy: Float, r: Float) =
        "M${cx - r} ${cy}a$r $r 0 1 0 ${2 * r} 0a$r $r 0 1 0 ${-2 * r} 0Z"

    private fun rect(x: Float, y: Float, w: Float, h: Float, r: Float) =
        "M${x + r} ${y}h${w - 2 * r}a$r $r 0 0 1 $r ${r}v${h - 2 * r}a$r $r 0 0 1 ${-r} ${r}h${-(w - 2 * r)}a$r $r 0 0 1 ${-r} ${-r}v${-(h - 2 * r)}a$r $r 0 0 1 $r ${-r}Z"
}
