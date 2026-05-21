plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

private val WRISTLINK_CONNECT_IQ_APP_UUID = "WRISTLINK_CONNECT_IQ_APP_UUID"
private val WRISTLINK_DEV_CONNECT_IQ_APP_UUID = "WRISTLINK_DEV_CONNECT_IQ_APP_UUID"
private val WRISTLINK_PROD_CONNECT_IQ_APP_UUID = "WRISTLINK_PROD_CONNECT_IQ_APP_UUID"
private val WRISTLINK_FLAVOR_CONFIG_PATH = "../config/wristlink-flavors.xcconfig"

private val wristLinkFlavorConfig: Map<String, String> =
    rootProject.file(WRISTLINK_FLAVOR_CONFIG_PATH).readLines().mapNotNull { rawLine ->
        val line = rawLine.substringBefore("//").trim()
        if (line.isBlank() || line.startsWith("#")) {
            null
        } else {
            val separator = line.indexOf('=')
            require(separator >= 0) { "Invalid WristLink flavor config line: $rawLine" }
            line.substring(0, separator).trim() to line.substring(separator + 1).trim()
        }
    }.toMap()

private fun wristLinkFlavorConfigValue(key: String): String =
    wristLinkFlavorConfig[key]
        ?: error("Missing $key in $WRISTLINK_FLAVOR_CONFIG_PATH")

android {
    namespace = "com.wristlink.wristlink_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.wristlink.wristlink_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            manifestPlaceholders[WRISTLINK_CONNECT_IQ_APP_UUID] =
                wristLinkFlavorConfigValue(WRISTLINK_DEV_CONNECT_IQ_APP_UUID)
        }
        create("prod") {
            dimension = "environment"
            manifestPlaceholders[WRISTLINK_CONNECT_IQ_APP_UUID] =
                wristLinkFlavorConfigValue(WRISTLINK_PROD_CONNECT_IQ_APP_UUID)
        }
    }

    buildTypes {
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
    implementation("com.garmin.connectiq:ciq-companion-app-sdk:2.4.0@aar")
    testImplementation("junit:junit:4.13.2")
}
