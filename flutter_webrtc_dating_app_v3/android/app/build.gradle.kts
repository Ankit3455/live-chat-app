plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_webrtc_dating_app_v3"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // BEST PRACTICE: Change back to Java 1.8 for better compatibility
        sourceCompatibility = JavaVersion.VERSION_1_8 // <-- CHANGED
        targetCompatibility = JavaVersion.VERSION_1_8 // <-- CHANGED
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // Match the Java version
        jvmTarget = "1.8" // <-- CHANGED
    }

    defaultConfig {
        applicationId = "com.example.flutter_webrtc_dating_app_v3"

        // CRITICAL FIX: Set minSdk directly to 21 or higher
        minSdk = flutter.minSdkVersion // <-- CHANGED

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true // Good to have this
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // This line is correct and should remain
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
