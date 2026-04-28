import java.io.FileInputStream
import java.util.Properties
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

tasks.register("createProguardRules") {
    doLast {
        val proguardFile = file("proguard-rules.pro")
        proguardFile.writeText(
            """
            -keep class com.regula.** { *; }
            -keep class com.regula.face.** { *; }
            -keep class com.regula.document.** { *; }
            -keep class com.google.firebase.** { *; }
            -keepclassmembers class * {
                @android.webkit.JavascriptInterface <methods>;
            }
            -dontwarn okhttp3.**
            -dontwarn okio.**
            """.trimIndent()
        )
        println("✅ Archivo proguard-rules.pro generado automáticamente")
    }
}

tasks.preBuild {
    dependsOn("createProguardRules")
}

android {
    namespace = "com.orsanfio.orsanfio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.14033849"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    defaultConfig {
        applicationId = "com.orsanfio.orsanfio"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 14
        versionName = "1.1.0"
    }
    aaptOptions {
        noCompress("Regula/faceSdkResource.dat")
    }
    buildTypes {
        debug {}
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            isDebuggable = false
            manifestPlaceholders["usesCleartextTraffic"] = "true"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.regula.face:api:+@aar") {
        isTransitive = true
    }
    implementation("com.regula.face.core:basic:+@aar")
}