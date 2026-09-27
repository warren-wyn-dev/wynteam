package io.wyn.wyn.feature.auth

import java.time.LocalDate

/**
 * Signup rules copied from the web (web/lib/auth-repository.ts,
 * web/lib/signup-password-policy.ts, web/components/auth-flow/screens.tsx).
 * The database constraints stay the real enforcement; these are the fast
 * first checks and must match the web exactly.
 */
object AuthRules {
    const val MIN_SIGNUP_PASSWORD_LENGTH = 12
    const val MIN_ONBOARDING_AGE = 13
    const val MIN_BIRTH_YEAR = 1900
    const val BUDDHIST_ERA_OFFSET = 543
    const val AVATAR_MAX_BYTES = 10 * 1024 * 1024

    val reservedUsernames = setOf(
        "admin", "administrator", "support", "help", "wynos", "wyn",
        "official", "root", "api", "moderator", "staff", "security", "system",
        "null", "undefined", "everyone", "here", "channel", "settings",
        "about", "terms", "privacy", "www", "app",
    )

    private val usernamePattern = Regex("^[a-z0-9_]{3,20}$")
    private val emailPattern = Regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")

    fun isUsernameFormatValid(username: String) = usernamePattern.matches(username)

    fun isEmailValid(email: String) = emailPattern.matches(email)

    /** "YYYY-MM-DD" when it is a real date, not in the future, and at least [MIN_ONBOARDING_AGE] years ago. */
    fun parseBirthDate(year: Int?, month: Int?, day: Int?, today: LocalDate = LocalDate.now()): String? {
        if (year == null || month == null || day == null) return null
        val date = runCatching { LocalDate.of(year, month, day) }.getOrNull() ?: return null
        if (date.isAfter(today) || date.plusYears(MIN_ONBOARDING_AGE.toLong()).isAfter(today)) return null
        return date.toString()
    }

    /** Newest first, Gregorian (the label shows Buddhist era). */
    fun eligibleBirthYears(today: LocalDate = LocalDate.now()): List<Int> =
        (today.year - MIN_ONBOARDING_AGE downTo MIN_BIRTH_YEAR).toList()
}
