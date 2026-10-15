import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use(::load)
}
fun foodConfig(name: String): String =
    (localProperties.getProperty(name) ?: System.getenv(name) ?: "").trim()
fun javaString(value: String): String =
    "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r") + "\""

android {
    namespace = "online.wynos.food"
    compileSdk = 36

    defaultConfig {
        // Proposed ID until Google Play Console registration.
        applicationId = "online.wynos.food"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0-beta1"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // Public client values only; never put a service-role / sb_secret key here.
        buildConfigField("String", "SUPABASE_URL", javaString(foodConfig("WYNOS_FOOD_SUPABASE_URL")))
        buildConfigField("String", "SUPABASE_PUBLISHABLE_KEY", javaString(foodConfig("WYNOS_FOOD_SUPABASE_PUBLISHABLE_KEY")))
    }

    buildTypes {
        // Address mutations are disabled in ordinary APKs and ALL release builds.
        // Explicit staging-only opt-in must name the exact connected staging project.
        debug {
            // Explicitly enable the device-preview FCM service only in debug manifests.
            manifestPlaceholders["zokyFcmPreviewServiceEnabled"] = "true"
            val projectRef = foodConfig("WYNOS_FOOD_STAGING_PROJECT_REF")
            val targetUrl = foodConfig("WYNOS_FOOD_SUPABASE_URL")
            val verifiedStaging = projectRef.matches(Regex("[a-z0-9]{20}")) &&
                projectRef != "kqokpocajhfbidcxpvhh" &&
                targetUrl == "https://$projectRef.supabase.co"
            val stagingAddressWrites = verifiedStaging &&
                foodConfig("WYNOS_FOOD_ADDRESS_WRITE_STAGING") == "true"
            val stagingSignup = verifiedStaging &&
                foodConfig("WYNOS_FOOD_ACCOUNT_SIGNUP_STAGING") == "true"
            buildConfigField("boolean", "ADDRESS_WRITES_ALLOWED", stagingAddressWrites.toString())
            buildConfigField("boolean", "ACCOUNT_SIGNUP_ALLOWED", stagingSignup.toString())
            buildConfigField("boolean", "ACCOUNT_DELETION_ALLOWED", (
                verifiedStaging && foodConfig("WYNOS_FOOD_ACCOUNT_DELETION_STAGING") == "true"
            ).toString())
            // Idempotent order RPC is staging debug only, NEVER release.
            buildConfigField("boolean", "STAGING_ORDER_CREATION_ALLOWED", (
                verifiedStaging && foodConfig("WYNOS_FOOD_ORDER_CREATION_STAGING") == "true"
            ).toString())
            buildConfigField("boolean", "STAGING_MOBILE_PAYMENT_ALLOWED", (
                verifiedStaging && foodConfig("WYNOS_FOOD_MOBILE_PAYMENT_STAGING") == "true"
            ).toString())
            // Strict staging-only chat; requires the reviewed buyer/merchant RLS schema.
            buildConfigField("boolean", "CHAT_STAGING_ALLOWED", (
                verifiedStaging && foodConfig("WYNOS_FOOD_CHAT_STAGING") == "true"
            ).toString())
            // Explicit user-initiated, device-local Firebase test only. No production delivery.
            buildConfigField("boolean", "FCM_DEVICE_PREVIEW_ALLOWED", "true")
        }
        release {
            // Fail closed at Android service dispatch, not only inside onMessageReceived.
            manifestPlaceholders["zokyFcmPreviewServiceEnabled"] = "false"
            buildConfigField("boolean", "ADDRESS_WRITES_ALLOWED", "false")
            buildConfigField("boolean", "ACCOUNT_SIGNUP_ALLOWED", "false")
            buildConfigField("boolean", "ACCOUNT_DELETION_ALLOWED", "false")
            buildConfigField("boolean", "STAGING_ORDER_CREATION_ALLOWED", "false")
            buildConfigField("boolean", "STAGING_MOBILE_PAYMENT_ALLOWED", "false")
            buildConfigField("boolean", "CHAT_STAGING_ALLOWED", "false")
            buildConfigField("boolean", "FCM_DEVICE_PREVIEW_ALLOWED", "false")
            isMinifyEnabled = false // Enable and verify R8 before production.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2025.06.00"))
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.1")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.9.1")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("io.coil-kt:coil-compose:2.7.0")
    // Stripe PaymentSheet 22.6.x is compatible with the project's Compose
    // 1.8.x BOM. Feature itself is gated to isolated staging Debug only.
    implementation("com.stripe:paymentsheet:22.6.1")
    implementation(platform("com.google.firebase:firebase-bom:34.19.0"))
    implementation("com.google.firebase:firebase-messaging")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // Match the existing WYNOS Android Supabase/Ktor release family.
    implementation(platform("io.github.jan-tennert.supabase:bom:3.1.4"))
    implementation("io.github.jan-tennert.supabase:auth-kt")
    implementation("io.github.jan-tennert.supabase:postgrest-kt")
    implementation("io.ktor:ktor-client-okhttp:3.1.3")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.1")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
}
