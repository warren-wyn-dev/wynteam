package io.wyn.wyn.feature.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class AuthRulesTest {
    private val today = LocalDate.of(2026, 9, 27)

    @Test fun usernamesMatchTheWebPattern() {
        assertTrue(AuthRules.isUsernameFormatValid("abc"))
        assertTrue(AuthRules.isUsernameFormatValid("a_b_0123456789_xyzw"))
        assertFalse(AuthRules.isUsernameFormatValid("ab"))
        assertFalse(AuthRules.isUsernameFormatValid("a".repeat(21)))
        assertFalse(AuthRules.isUsernameFormatValid("Upper"))
        assertFalse(AuthRules.isUsernameFormatValid("dot.name"))
        assertTrue("wynos" in AuthRules.reservedUsernames)
    }

    @Test fun emailsMatchTheWebPattern() {
        assertTrue(AuthRules.isEmailValid("a@b.co"))
        assertFalse(AuthRules.isEmailValid("a@b"))
        assertFalse(AuthRules.isEmailValid("a b@c.co"))
    }

    @Test fun birthDatesNeedARealDateAndThirteenYears() {
        assertEquals("2013-09-27", AuthRules.parseBirthDate(2013, 9, 27, today))
        assertNull(AuthRules.parseBirthDate(2013, 9, 28, today))
        assertNull(AuthRules.parseBirthDate(2001, 2, 29, today))
        assertEquals("2000-02-29", AuthRules.parseBirthDate(2000, 2, 29, today))
        assertNull(AuthRules.parseBirthDate(null, 1, 1, today))
    }

    @Test fun birthYearsRunNewestFirstTo1900() {
        val years = AuthRules.eligibleBirthYears(today)
        assertEquals(2013, years.first())
        assertEquals(1900, years.last())
    }
}
