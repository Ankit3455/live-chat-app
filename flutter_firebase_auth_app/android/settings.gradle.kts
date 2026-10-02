pluginManagement {
    repositories {
        google()
        mavenCentral()
        // Aliyun mirrors (backup) - keep them as uri() for Kotlin DSL
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        // Flutter engine/artifacts mirror
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    // Prefer repositories declared here (safer)
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}

rootProject.name = "flutter_firebase_auth_app"
include(":app")
