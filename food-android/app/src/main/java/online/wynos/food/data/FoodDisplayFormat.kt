package online.wynos.food.data

import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Stable readable dates for order cards, replacing raw database ISO timestamps. */
object FoodDisplayFormat {
    private val thaiMonths = listOf(
        "ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.",
        "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค.",
    )
    private val english = DateTimeFormatter.ofPattern("d MMM uuuu · HH:mm", Locale.ENGLISH)

    fun orderDate(
        raw: String,
        language: String,
        zone: ZoneId = ZoneId.systemDefault(),
    ): String {
        if (raw.isBlank()) return ""
        val date: ZonedDateTime = runCatching { Instant.parse(raw).atZone(zone) }
            .recoverCatching { OffsetDateTime.parse(raw).atZoneSameInstant(zone) }
            .recoverCatching { LocalDateTime.parse(raw).atZone(zone) }
            .getOrNull() ?: return raw
        if (language != "th") return date.format(english)
        val month = thaiMonths[date.monthValue - 1]
        val day = date.dayOfMonth
        val year = date.year + 543
        val clock = "%02d:%02d".format(Locale.ROOT, date.hour, date.minute)
        return "$day $month $year · $clock น."
    }
}
