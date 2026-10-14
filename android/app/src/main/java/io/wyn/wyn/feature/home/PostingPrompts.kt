package io.wyn.wyn.feature.home

import java.time.LocalDate
import kotlin.math.abs

/** Same keys, ordering and local-day rotation as web/lib/posting-prompts.ts. */
internal data class PostingPrompt(val key: String, val thai: String, val english: String) {
    fun localized(englishLocale: Boolean) = if (englishLocale) english else thai
}

internal object PostingPrompts {
    val first = listOf(
        PostingPrompt("first-intro", "แนะนำตัวสั้น ๆ ให้ทุกคนรู้จักคุณ", "Introduce yourself to everyone"),
        PostingPrompt("first-today", "เล่าเรื่องหนึ่งอย่างเกี่ยวกับวันนี้", "Share one thing about your day"),
        PostingPrompt("first-question", "ถามคำถามที่คุณอยากฟังความคิดเห็นจากคนอื่น", "Ask a question and hear what others think"),
    )

    val daily = listOf(
        PostingPrompt("daily-now", "วันนี้มีอะไรเกิดขึ้นกับคุณบ้าง?", "What happened in your day today?"),
        PostingPrompt("daily-listening", "ช่วงนี้คุณกำลังฟังเพลงอะไรอยู่?", "What have you been listening to lately?"),
        PostingPrompt("daily-smallwin", "วันนี้มีเรื่องเล็ก ๆ อะไรที่ทำให้คุณรู้สึกดี?", "What's a small thing that made you happy today?"),
        PostingPrompt("daily-question", "มีคำถามอะไรที่อยากถามคนบน WYNOS ไหม?", "Anything you want to ask people on WYNOS?"),
        PostingPrompt("daily-photo", "วันนี้มีรูปไหนที่อยากแชร์?", "Any photo you'd like to share today?"),
        PostingPrompt("daily-interest", "ช่วงนี้คุณกำลังสนใจเรื่องอะไรเป็นพิเศษ?", "What are you especially interested in lately?"),
        PostingPrompt("daily-weekend", "ถ้ามีเวลาว่างตอนนี้ คุณอยากทำอะไร?", "What would you do if you had some free time?"),
    )

    /** Web uses Math.abs(localDayNumber(date)) % DAILY_PROMPTS.length. */
    fun forDay(date: LocalDate = LocalDate.now()): PostingPrompt =
        daily[abs(date.dayOfYear) % daily.size]

    fun byKey(key: String?): PostingPrompt? =
        if (key == "daily") forDay() else first.firstOrNull { it.key == key } ?: daily.firstOrNull { it.key == key }
}
