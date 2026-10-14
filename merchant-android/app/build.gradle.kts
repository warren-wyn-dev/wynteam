plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val supabaseUrl = providers.gradleProperty("WYNOS_SUPABASE_URL").orElse("").get()
val supabasePublishableKey = providers.gradleProperty("WYNOS_SUPABASE_PUBLISHABLE_KEY").orElse("").get()
// Firebase client-side identifiers are public app configuration, never service credentials.
// Keep blank until the Android Firebase application has been registered.
val firebaseAppId = providers.gradleProperty("WYNOS_FIREBASE_APP_ID").orElse("").get()
val firebaseProjectId = providers.gradleProperty("WYNOS_FIREBASE_PROJECT_ID").orElse("").get()
val firebaseSenderId = providers.gradleProperty("WYNOS_FIREBASE_SENDER_ID").orElse("").get()
val firebaseApiKey = providers.gradleProperty("WYNOS_FIREBASE_API_KEY").orElse("").get()


android {
    namespace = "online.wynos.merchant"
    compileSdk = 36

    defaultConfig {
        applicationId = "online.wynos.merchant"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0-dev"
        buildConfigField("String", "SUPABASE_URL", "\"$supabaseUrl\"")
        buildConfigField("String", "SUPABASE_PUBLISHABLE_KEY", "\"$supabasePublishableKey\"")
        buildConfigField("String", "FIREBASE_APP_ID", "\"$firebaseAppId\"")
        buildConfigField("String", "FIREBASE_PROJECT_ID", "\"$firebaseProjectId\"")
        buildConfigField("String", "FIREBASE_SENDER_ID", "\"$firebaseSenderId\"")
        buildConfigField("String", "FIREBASE_API_KEY", "\"$firebaseApiKey\"")

    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions { jvmTarget = "17" }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2025.10.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.9.4")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.google.firebase:firebase-messaging:24.1.2")
    debugImplementation("androidx.compose.ui:ui-tooling")
    testImplementation("junit:junit:4.13.2")
}
