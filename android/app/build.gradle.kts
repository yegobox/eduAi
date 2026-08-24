import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // START: FlutterFire Configuration
    // Declared but not applied here: google-services fails the build when its
    // config file is missing, and that file is git-ignored (CI injects it).
    id("com.google.gms.google-services") apply false
    // END: FlutterFire Configuration
}

// Firebase phone auth needs the generated resources from google-services.json.
// Devs without the file still get a working build, just no Firebase.
val hasGoogleServices = file("google-services.json").exists()
if (hasGoogleServices) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle("google-services.json not found in :app - Firebase will be inactive.")
}

// Upload-key material. Written by CI (or created locally from the shared
// keystore) and never committed — see android/.gitignore.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

android {
    namespace = "rw.akili.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "rw.akili.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // CI drives these so every Play upload gets a fresh, monotonic code.
        versionCode = System.getenv("VERSION_CODE")?.toInt() ?: flutter.versionCode
        versionName = System.getenv("VERSION_NAME") ?: flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Falls back to debug keys locally so `flutter run --release` still
            // works without the keystore; CI always has key.properties.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
