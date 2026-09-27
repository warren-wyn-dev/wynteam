import java.util.Properties

plugins {
    id("com.android.application")
}

// Release signing comes from android/keystore.properties (local, git-ignored)
// or WYNOS_ANDROID_* environment variables (CI secrets). Without either, a
// release build is produced unsigned; nothing secret lives in this file.
val keystoreProps = Properties().apply {
    val file = rootProject.file("keystore.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
fun signingValue(prop: String, env: String): String? =
    keystoreProps.getProperty(prop) ?: System.getenv(env)

val releaseStoreFile = signingValue("storeFile", "WYNOS_ANDROID_KEYSTORE_PATH")

android {
    namespace = "online.wynos.app"
    compileSdk = 36

    defaultConfig {
        // The Play Store identity of the app. It can never change once the
        // app is published, and must match web/lib/android-asset-links.ts.
        applicationId = "online.wynos.app"
        minSdk = 23
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0-beta1"

        // The only origin the app opens full-screen. Must serve a matching
        // /.well-known/assetlinks.json, or Chrome shows its URL bar.
        val host = "wynos.online"
        manifestPlaceholders["hostName"] = host
        resValue("string", "appName", "WYNOS")
        resValue("string", "launchUrl", "https://$host/")
        resValue("string", "providerAuthority", "online.wynos.app.fileprovider")
        resValue(
            "string",
            "assetStatements",
            "[{\\\"relation\\\": [\\\"delegate_permission/common.handle_all_urls\\\"], " +
                "\\\"target\\\": {\\\"namespace\\\": \\\"web\\\", \\\"site\\\": \\\"https://$host\\\"}}]",
        )
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = signingValue("storePassword", "WYNOS_ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "WYNOS_ANDROID_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "WYNOS_ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.findByName("release")
        }
    }

    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation("com.google.androidbrowserhelper:androidbrowserhelper:2.7.3")
}
