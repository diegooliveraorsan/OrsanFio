import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ✅ CONFIGURACIÓN DE FIRMA
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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

    // ✅ CONFIGURACIÓN DE FIRMA
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
        //versionCode = flutter.versionCode
        //versionName = flutter.versionName
        versionCode = 4
        versionName = "1.0.1"
    }

    buildTypes {
        release {
            // ✅ FIRMA DE PRODUCCIÓN
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}