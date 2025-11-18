import java.util.Properties
import java.io.FileInputStream

// --- START: Property loading logic (Kotlin DSL) ---
// Load local.properties (usually for flutter.sdk path)
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    FileInputStream(localPropertiesFile).use { localProperties.load(it) }
}

// Load key.properties (for signing config)
val storeProperties = Properties()
val storeFile = rootProject.file("key.properties")
if (storeFile.exists()) {
    FileInputStream(storeFile).use { storeProperties.load(it) }
}
// --- END: Property loading logic ---


plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.prepskul.prepskul"
    compileSdk =  36
    ndkVersion = flutter.ndkVersion

    dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true 
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.prepskul.prepskul"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // --- START: Signing Configs (Kotlin DSL syntax) ---
    signingConfigs {
        create("release") {
            storeFile = file(storeProperties["storeFile"] as String)
            storePassword = storeProperties["storePassword"] as String
            keyAlias = storeProperties["keyAlias"] as String
            keyPassword = storeProperties["keyPassword"] as String
        }
    }
    // --- END: Signing Configs ---


       buildTypes {
        release {
            // Assign the new 'release' signing config created above
            signingConfig = signingConfigs.getByName("release")
            // Optional but recommended for production builds:
            // Enables code shrinking, obfuscation, and optimization
            isMinifyEnabled = true
            // Includes only the necessary resources for each target device (Corrected syntax)
            isShrinkResources = true 
        }
    }

}

flutter {
    source = "../.."
}
