package io.wyn.wyn

import android.app.Application
import io.wyn.wyn.core.data.SupabaseProvider
import io.wyn.wyn.core.diagnostics.QaCrashReport
import io.wyn.wyn.core.push.FirebasePush
import io.wyn.wyn.core.push.ensurePushChannel

class WynosApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Keep only a small, sanitized error fingerprint when a DEBUG APK exits.
        QaCrashReport.install(this)
        // Supplies application-private session storage to the Android Auth client.
        // Client construction remains lazy until the app actually needs it.
        SupabaseProvider.initialize(this)
        // Push is optional: a build without Firebase values runs without it.
        runCatching { FirebasePush.start(this) }
        try {
            ensurePushChannel(this)
        } catch (error: Exception) {
            if (!BuildConfig.DEBUG) throw error
            QaCrashReport.record(this, error)
        }
    }
}
