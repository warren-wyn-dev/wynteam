package io.wyn.wyn

import android.app.Application
import io.wyn.wyn.core.push.FirebasePush
import io.wyn.wyn.core.push.ensurePushChannel

class WynosApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Push is optional: a build without Firebase values runs without it.
        runCatching { FirebasePush.start(this) }
        ensurePushChannel(this)
    }
}
