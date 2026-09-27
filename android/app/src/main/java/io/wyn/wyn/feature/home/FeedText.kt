package io.wyn.wyn.feature.home

import java.text.BreakIterator
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** A caption split like the web's splitHomeCaption: prose (max 190 graphemes) and the trailing hashtag block. */
data class HomeCaption(val prose: String, val tags: String, val truncated: Boolean)

object FeedText {
    const val CAPTION_LIMIT = 190

    fun splitCaption(value: String): HomeCaption {
        val lines = value.trim().split(Regex("\\r?\\n"))
        var tagStart = lines.size
        while (tagStart > 0) {
            val line = lines[tagStart - 1].trim()
            if (line.isEmpty()) {
                if (tagStart < lines.size) {
                    tagStart -= 1
                    continue
                }
                break
            }
            if (line.startsWith("#")) {
                tagStart -= 1
                continue
            }
            break
        }
        val prose = lines.subList(0, tagStart).joinToString("\n").trimEnd().replace(Regex("\\n{3,}"), "\n\n")
        val tags = lines.subList(tagStart, lines.size).joinToString("\n").trim()
        val graphemes = graphemes(prose)
        val truncated = graphemes.size > CAPTION_LIMIT
        val visible = if (truncated) graphemes.take(CAPTION_LIMIT).joinToString("").trimEnd() else prose
        return HomeCaption(visible, tags, truncated)
    }

    /** Thai combining marks and emoji count as one character, like Intl.Segmenter on the web. */
    fun graphemes(text: String): List<String> {
        val iterator = BreakIterator.getCharacterInstance(Locale("th"))
        iterator.setText(text)
        val out = ArrayList<String>()
        var start = iterator.first()
        var end = iterator.next()
        while (end != BreakIterator.DONE) {
            out += text.substring(start, end)
            start = end
            end = iterator.next()
        }
        return out
    }

    /** RichPostText compact mode: a blank line before a hashtag line collapses. */
    fun compact(value: String): String = value.trimEnd().replace(Regex("\\r?\\n(?:[ \\t]*\\r?\\n)+(?=[ \\t]*#)"), "\n")

    /** URLs, #hashtags and @mentions, as the web's tokenPattern finds them. */
    val tokenPattern = Regex("((?:https?://\\S+)|(?:#[\\p{L}\\p{M}\\p{N}_]+)|(?:@[\\p{L}\\p{M}\\p{N}_.]+))")

    /** web relativeTimeTh(), plus the English the web's dictionary shows ("5m", "2h", "3d", "Sep 4"). */
    fun relativeTime(iso: String, english: Boolean, now: Instant = Instant.now(), zone: ZoneId = ZoneId.systemDefault()): String {
        val then = parseInstant(iso) ?: return ""
        val seconds = Duration.between(then, now).seconds.coerceAtLeast(0)
        if (seconds < 60) return if (english) "now" else "เมื่อสักครู่"
        val minutes = seconds / 60
        if (minutes < 60) return if (english) "${minutes}m" else "$minutes นาที"
        val hours = minutes / 60
        if (hours < 24) return if (english) "${hours}h" else "$hours ชม."
        val days = hours / 24
        if (days < 7) return if (english) "${days}d" else "$days วัน"
        val date = then.atZone(zone).toLocalDate()
        return if (english) {
            DateTimeFormatter.ofPattern("MMM d", Locale.ENGLISH).format(date)
        } else {
            "${date.dayOfMonth} ${THAI_SHORT_MONTHS[date.monthValue - 1]}"
        }
    }

    /** ISO-8601 or Postgres ("2026-09-27 10:00:00.123+00") timestamps; null when unreadable. */
    fun parseInstant(value: String): Instant? = runCatching { Instant.parse(normalizeIso(value)) }.getOrNull()

    private fun normalizeIso(value: String): String {
        var text = value.trim().replace(' ', 'T')
        if (Regex("[+-]\\d{2}$").containsMatchIn(text)) text += ":00"
        if (!text.endsWith("Z") && !Regex("[+-]\\d{2}:\\d{2}$").containsMatchIn(text)) text += "Z"
        return java.time.OffsetDateTime.parse(text).toInstant().toString()
    }

    private val THAI_SHORT_MONTHS = listOf(
        "ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค.",
    )
}
