package io.wyn.wyn.core.link

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AppLinkTest {
    private val id = "0f8fad5b-d9cb-469f-a165-70867728950e"
    private fun parse(path: String, scheme: String = "https", host: String = "wynos.online") =
        AppLink.parse(scheme, host, path.split('/').filter { it.isNotEmpty() })

    @Test fun shareLinksOpenTheirScreen() {
        assertEquals(AppLink.Drop(id), parse("/drop/$id"))
        assertEquals(AppLink.Quote(id), parse("/quote/$id"))
        assertEquals(AppLink.Club(id), parse("/club/$id"))
        assertEquals(AppLink.ClubPost(id), parse("/club-post/$id"))
        assertEquals(AppLink.ClubInvite("a1b2c3d4e5"), parse("/club-invite/a1b2c3d4e5"))
        assertEquals("ids are kept lower case", AppLink.Drop(id), parse("/drop/${id.uppercase()}"))
        assertEquals(AppLink.Drop(id), parse("/drop/$id", host = "WYNOS.online"))
    }

    @Test fun anythingElseIsIgnored() {
        assertNull(parse("/drop/$id", scheme = "http"))
        assertNull(parse("/drop/$id", host = "evil.example"))
        assertNull(parse("/drop/$id", host = "wynos.online.evil.example"))
        assertNull(parse("/drop/not-an-id"))
        assertNull(parse("/drop/$id/extra"))
        assertNull(parse("/club/wynos-community"))
        assertNull(parse("/club-invite/../settings"))
        assertNull(parse("/club-invite/a:b"))
        assertNull(parse("/club-invite/" + "a".repeat(65)))
        assertNull(parse("/auth/callback"))
        assertNull(parse("/reset-password"))
        assertNull(AppLink.parse("https", null, listOf("drop", id)))
    }
}
