import java.util.Base64

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The --dart-define values of this build: Flutter passes them base64-encoded, comma-separated.
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String? ?: "")
    .split(",")
    .filter { it.isNotBlank() }
    .map { String(Base64.getDecoder().decode(it)) }
    .filter { it.contains("=") }
    .associate { it.substringBefore("=") to it.substringAfter("=") }

android {
    namespace = "com.collarbell.collarbell"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications (notifications shown while the app is open) needs newer Java APIs on old
        // Android versions.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // The Kotlin namespace/package stays com.collarbell.collarbell; the store id is com.collarbell.app.
        applicationId = "com.collarbell.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase Auth needs API 23+, the document scanner
        // (cunning_document_scanner) 24+; Flutter 3.38 defaults to 24.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Plain HTTP only for a build whose API is http://: the phone at home talks to the API on the Mac
        // (tool/install_phone.sh). Other release builds stay HTTPS only.
        manifestPlaceholders["usesCleartextTraffic"] =
            (dartDefines["CB_API_BASE_URL"]?.startsWith("http://") ?: false).toString()
    }

    buildTypes {
        debug {
            // The local API over plain HTTP: http://10.0.2.2:5080 on the emulator, the Mac's LAN IP on a phone.
            manifestPlaceholders["usesCleartextTraffic"] = "true"
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
