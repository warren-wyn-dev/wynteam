package io.wyn.wyn.core.diagnostics

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class QaCrashReportTest {
    @Test
    fun reportIncludesOnlyExceptionTypeAndStaticCodeLocation() {
        val error = IllegalArgumentException(
            "Should never include https://some-project.supabase.co or sb_publishable_fake or password=abc"
        )
        error.stackTrace = arrayOf(
            StackTraceElement("io.wyn.wyn.MainActivity", "onCreate", "MainActivity.kt", 78),
        )

        val code = QaCrashReport.summarize(error)

        assertEquals("QA-IllegalArgumentException/MainActivity.onCreate:78", code)
        assertFalse(code.contains("supabase"))
        assertFalse(code.contains("password"))
        assertFalse(code.contains("sb_publishable"))
    }

    @Test
    fun reportsSafeSdkOriginBeforeOurOwnCallSiteWithoutMessages() {
        val error = IllegalStateException("URL=https://private-project.supabase.co; password=TOPSECRET")
        error.stackTrace = arrayOf(
            StackTraceElement("io.github.jan.supabase.internal.KtorSupabaseHttpClient", "initialize", "Client.kt", 117),
            StackTraceElement("io.wyn.wyn.core.data.SupabaseProvider", "getClient", "SupabaseProvider.kt", 34),
        )
        val report = QaCrashReport.summarize(error)
        assertEquals("QA-IllegalStateException/KtorSupabaseHttpClient.initialize:117 > SupabaseProvider.getClient:34", report)
        assertFalse(report.contains("TOPSECRET"))
        assertFalse(report.contains("private-project"))
    }

    @Test
    fun wrappedErrorUsesRootTypeButNeverRootMessage() {
        val root = IllegalStateException("secret account address@example.com")
        root.stackTrace = arrayOf(
            StackTraceElement("io.wyn.wyn.core.data.SupabaseProvider", "getClient", "SupabaseProvider.kt", 22),
        )
        val outer = RuntimeException("private message", root)
        val code = QaCrashReport.summarize(outer)
        assertEquals("QA-IllegalStateException/SupabaseProvider.getClient:22", code)
        assertTrue(code.length <= 160)
        assertFalse(code.contains("@example.com"))
    }
}
