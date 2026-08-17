// WYN NOTICE: patched for AGP 9 / Gradle 9 compatibility.
// See ../NOTICE.md in this vendored package for the full explanation.
// Only this file was changed vs. upstream pub.dev video_thumbnail 0.5.6
// (which shipped android/build.gradle, a Groovy file) -- converted to the
// Kotlin DSL, removed the jcenter() repository (the method no longer
// exists on Gradle 9's RepositoryHandler), and switched from the legacy
// `apply plugin: 'com.android.library'` to the modern `plugins {}` block.
// This mirrors the pattern already used by other Flutter plugins this
// project depends on (e.g. video_player_android 2.12.0, image_picker_android
// 0.8.13+19 in pubspec.lock) -- including the `allprojects {}` block
// ordering before `plugins {}`, which Gradle 9.3.1 only accepts in the
// Kotlin DSL, not in a plain .gradle (Groovy) file.
group = "xyz.justsoft.video_thumbnail"
version = "1.0-SNAPSHOT"

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.13.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "xyz.justsoft.video_thumbnail"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        minSdk = 16
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    lint {
        disable.add("InvalidPackage")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
