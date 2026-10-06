import java.io.FileInputStream
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing reads the gitignored android/key.properties
// (storeFile, storePassword, keyAlias, keyPassword). Falls back to debug signing when absent.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

android {
    namespace = "com.example.flutter_webrtc_dating_app_v3"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.example.flutter_webrtc_dating_app_v3"

        // Firebase plugins need API 23+.
        minSdk = maxOf(flutter.minSdkVersion, 23)

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("android/key.properties not found: release build is signed with the DEBUG key and cannot be published.")
                signingConfigs.getByName("debug")
            }
        }
    }
}

// kotlinOptions {} is an error in Kotlin 2.2 build scripts; use compilerOptions.
kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Native incoming-call notification (CallNotificationExtension.kt).
    // Keep OneSignal on the version onesignal_flutter pulls in (its android/build.gradle).
    implementation("com.onesignal:OneSignal:5.10.2")
    implementation("androidx.core:core-ktx:1.13.1")
    // Decline from the notification while the app is closed (CallActionReceiver.kt).
    // Same BoM as firebase_core (FirebaseSDKVersion in its android/gradle.properties).
    implementation(platform("com.google.firebase:firebase-bom:33.16.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-database")
    // org.webrtc types for BeautyFrameProcessor.kt. flutter_webrtc ships the
    // runtime copy but declares it `implementation`, so keep its version.
    compileOnly("io.github.webrtc-sdk:android:137.7151.04")
}

flutter {
    source = "../.."
}
