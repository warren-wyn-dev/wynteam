package io.wyn.wyn.core.diagnostics

import android.content.Context
import io.wyn.wyn.BuildConfig

/**
 * Device-only diagnostics for beta DEBUG builds. Never persist Throwable.message,
 * entire stack traces, tokens, URLs, user-entered data, or account details.
 * Google Play release builds do not install or surface this reporter.
 */
object QaCrashReport {
    private const val FILE = "wynos.qa.crash"
    private const val KEY = "last_crash"
    private const val MAX_REPORT_LENGTH = 160

    fun install(context: Context) {
        if (!BuildConfig.DEBUG) return
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            if (error !is VirtualMachineError && error !is ThreadDeath) {
                try {
                    store(context, summarize(error))
                } catch (_: RuntimeException) {
                    // Preserve Android's normal crash handler even if storage is unavailable.
                }
            }
            previous?.uncaughtException(thread, error)
        }
    }

    fun read(context: Context): String? {
        if (!BuildConfig.DEBUG) return null
        return context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getString(KEY, null)?.take(MAX_REPORT_LENGTH)
    }

    fun record(context: Context, error: Throwable): String {
        val report = summarize(error)
        if (BuildConfig.DEBUG) store(context, report)
        return report
    }

    fun clear(context: Context) {
        if (!BuildConfig.DEBUG) return
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().remove(KEY).apply()
    }

    private fun store(context: Context, report: String) {
        // A synchronous commit survives immediate process termination after a crash.
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit().putString(KEY, report).commit()
    }

    /** Only static exception and code-location metadata, never exception messages. */
    internal fun summarize(error: Throwable): String {
        var root = error
        repeat(5) { if (root.cause != null && root.cause !== root) root = root.cause!! }
        val type = root.javaClass.simpleName.ifBlank { "UnknownError" }
            .filter { it.isLetterOrDigit() || it == '_' }.take(48)
        // The previous code always preferred the WYNOS callsite, hiding the
        // SDK frame that actually threw. A static stack frame (not its message)
        // identifies the failing library/initialization method on a phone.
        val origin = root.stackTrace.firstOrNull()
        val appCaller = root.stackTrace.firstOrNull { it.className.startsWith("io.wyn.wyn.") }
        fun location(frame: StackTraceElement?): String = frame?.let {
            val cls = it.className.substringAfterLast('.')
                .filter { ch -> ch.isLetterOrDigit() || ch == '_' || ch == '
    }
}
 }.take(42)
            val method = it.methodName.filter { ch -> ch.isLetterOrDigit() || ch == '_' }.take(32)
            "${cls}.${method}:${it.lineNumber.coerceAtLeast(0)}"
        } ?: "unknown"
        val detail = if (appCaller != null && appCaller !== origin) {
            "${location(origin)} > ${location(appCaller)}"
        } else location(origin)
        return "QA-$type/$detail".take(MAX_REPORT_LENGTH)
    }
}
