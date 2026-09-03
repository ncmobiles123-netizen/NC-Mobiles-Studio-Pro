import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// --- Release signing -------------------------------------------------
// CI (see .github/workflows/build-release.yml) decodes a base64 keystore
// secret to android/app/upload-keystore.jks and writes this properties
// file before the build step runs. For a local build, copy
// key.properties.example to key.properties and fill in your own
// keystore details — never commit the real key.properties or the .jks
// file (both are already covered by .gitignore below).
val keystorePropertiesFile = rootProject.file("app/key.properties")
val keystoreProperties = Properties()
val hasKeystoreProperties = keystorePropertiesFile.exists()
if (hasKeystoreProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.ncmobiles.studiopro"
    compileSdk = 34

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.ncmobiles.studiopro"
        // tflite_flutter + on-device inference require API 24+.
        minSdk = 24
        targetSdk = 34
        versionCode = (System.getenv("BUILD_NUMBER") ?: "1").toInt()
        versionName = System.getenv("BUILD_VERSION") ?: "1.0.0"
    }

    signingConfigs {
        create("release") {
            if (hasKeystoreProperties) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key only if no keystore is present,
            // so `flutter build apk` still works for quick local testing
            // before you've generated a release keystore.
            signingConfig = if (hasKeystoreProperties) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        // Avoids duplicate native lib conflicts pulled in by tflite_flutter.
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Flutter plugin dependencies are resolved automatically; nothing
    // manual needed here for tflite_flutter, image_picker, etc.
}
