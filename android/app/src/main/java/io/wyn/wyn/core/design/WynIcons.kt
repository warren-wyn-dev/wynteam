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
    val Globe = stroke(
        2.1f,
        "M21.54 15H17a2 2 0 0 0-2 2v4.54",
        "M7 3.34V5a3 3 0 0 0 3 3a2 2 0 0 1 2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2c0-1.1.9-2 2-2h3.17",
        "M11 21.95V18a2 2 0 0 0-2-2a2 2 0 0 1-2-2v-1a2 2 0 0 0-2-2H2.05",
        circle(12f, 12f, 10f),
    )
    val Users = stroke(2.1f, "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2", "M16 3.128a4 4 0 0 1 0 7.744", "M22 21v-2a4 4 0 0 0-3-3.87", circle(9f, 7f, 4f))
    val LockKeyhole = stroke(2.1f, circle(12f, 16f, 1f), rect(3f, 10f, 18f, 12f, 2f), "M7 10V7a5 5 0 0 1 10 0v3")
    val ImagePlus = stroke(
        2.1f, "M16 5h6", "M19 2v6", "M21 11.5V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h7.5",
        "m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21", circle(9f, 9f, 2f),
    )
    val Camera = stroke(
        2.1f,
        "M13.997 4a2 2 0 0 1 1.76 1.05l.486.9A2 2 0 0 0 18.003 7H20a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2h1.997a2 2 0 0 0 1.759-1.048l.489-.904A2 2 0 0 1 10.004 4z",
        circle(12f, 13f, 3f),
    )
    val Check = stroke(2f, "M20 6 9 17l-5-5")
    val Plus = stroke(2f, "M5 12h14", "M12 5v14")
    val PollBold = stroke(2.1f, "M3 3v16a2 2 0 0 0 2 2h16", "M18 17V9", "M13 17V5", "M8 17v-3")
    val Link = stroke(2.1f, "M9 17H7A5 5 0 0 1 7 7h2", "M15 7h2a5 5 0 1 1 0 10h-2", "M8 12h8")
    val UserRoundX = stroke(2f, "m16.5 16.5 5 5", "M2 21a8 8 0 0 1 11.531-7.18", "m21.5 16.5-5 5", circle(10f, 8f, 5f))
    val Volume = stroke(
        2f,
        "M11 4.702a.705.705 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.705.705 0 0 0 11 19.298z",
        "M16 9a5 5 0 0 1 0 6", "M19.364 18.364a9 9 0 0 0 0-12.728",
    )
    val VolumeOff = stroke(
        2f,
        "M11 4.702a.7.7 0 0 0-1.203-.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 .997.413l3.383 3.384A.7.7 0 0 0 11 19.298z",
        "m16.5 14.5 5-5", "m16.5 9.5 5 5",
    )
    val Settings = stroke(
        2f,
        "M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915 2.34 2.34 0 0 1 2.33 4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915",
        circle(12f, 12f, 3f),
    )
    val UserPlus = stroke(2f, "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2", circle(9f, 7f, 4f), "M19 8v6", "M22 11h-6")
    val CheckCheck = stroke(2.4f, "M18 6 7 17l-5-5", "m22 10-7.5 7.5L13 16")
    val MessagesSquare = stroke(
        1.9f,
        "M16 10a2 2 0 0 1-2 2H6.828a2 2 0 0 0-1.414.586l-2.202 2.202A.71.71 0 0 1 2 14.286V4a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z",
        "M20 9a2 2 0 0 1 2 2v10.286a.71.71 0 0 1-1.212.502l-2.202-2.202A2 2 0 0 0 17.172 19H10a2 2 0 0 1-2-2v-1",
    )
    val CirclePlus = stroke(1.8f, circle(12f, 12f, 10f), "M8 12h8", "M12 8v8")
    val UserRound = stroke(1.8f, circle(12f, 8f, 5f), "M20 21a8 8 0 0 0-16 0")
    val CheckCircle = stroke(2f, circle(12f, 12f, 10f), "m16 9-5.5 5.5L8 12")
    val FileText = stroke(
        2f,
        "M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z",
        "M14 2v5a1 1 0 0 0 1 1h5", "M10 9H8", "M16 13H8", "M16 17H8",
    )
    val Pencil = stroke(
        2f,
        "M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z",
        "m15 5 4 4",
    )
    val Pin = stroke(
        2f,
        "M12 17v5",
        "M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z",
    )
    val BellOff = stroke(
        2f,
        "M10.268 21a2 2 0 0 0 3.464 0",
        "M17 17H4a1 1 0 0 1-.74-1.673C4.59 13.956 6 12.499 6 8a6 6 0 0 1 .258-1.742",
        "m2 2 20 20",
        "M8.668 3.01A6 6 0 0 1 18 8c0 2.687.77 4.653 1.707 6.05",
    )
    val Compass = stroke(
        1.85f, circle(12f, 12f, 10f),
        "m16.24 7.76-1.804 5.411a2 2 0 0 1-1.265 1.265L7.76 16.24l1.804-5.411a2 2 0 0 1 1.265-1.265z",
    )
    val UsersRound = stroke(1.85f, "M18 21a8 8 0 0 0-16 0", circle(10f, 8f, 5f), "M22 20c0-3.37-2-6.5-4-8a5 5 0 0 0-.45-8.3")
    val CircleHelp = stroke(1.9f, circle(12f, 12f, 10f), "M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3", "M12 17h.01")
    val Info = stroke(2f, circle(12f, 12f, 10f), "M12 16v-4", "M12 8h.01")
    val LogOut = stroke(2f, "m16 17 5-5-5-5", "M21 12H9", "M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4")
    val CalendarDays = stroke(
        2f, "M8 2v3", "M16 2v3", rect(3f, 3f, 18f, 18f, 2f), "M3 9h18",
        "M8 13h.01", "M12 13h.01", "M16 13h.01", "M8 17h.01", "M12 17h.01", "M16 17h.01",
    )
    val Lock = stroke(2f, rect(3f, 11f, 18f, 11f, 2f), "M7 11V7a5 5 0 0 1 10 0v4")
    private const val BOOKMARK =
        "M17 3a2 2 0 0 1 2 2v15a1 1 0 0 1-1.496.868l-4.512-2.578a2 2 0 0 0-1.984 0l-4.512 2.578A1 1 0 0 1 5 20V5a2 2 0 0 1 2-2z"
    val Bookmark = stroke(2f, BOOKMARK)
    val BookmarkFilled = stroke(2f, BOOKMARK, filled = true)
    private const val LUCIDE_HEART =
        "M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5"
    val LucideHeart = stroke(2f, LUCIDE_HEART)
    val LucideHeartFilled = stroke(2f, LUCIDE_HEART, filled = true)
    val MessageCircle = stroke(
        2f,
        "M2.992 16.342a2 2 0 0 1 .094 1.167l-1.065 3.29a1 1 0 0 0 1.236 1.168l3.413-.998a2 2 0 0 1 1.099.092 10 10 0 1 0-4.777-4.719",
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
