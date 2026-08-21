// =============================================================
// FICHIER : ok_trialgo_admin/android/app/build.gradle.kts
// ROLE    : Configuration de build Android du STUDIO ADMIN
// =============================================================

import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// =============================================================
// SIGNATURE DE RELEASE
// =============================================================
// Meme mecanisme que dans l'app joueur : la cle est decrite dans
// android/key.properties, hors depot, et on retombe sur la cle de
// debug (avec un avertissement) si le fichier est absent.
//
// L'app admin n'a pas forcement vocation a passer par le Play Store
// (distribution interne par APK). Elle doit tout de meme etre signee
// avec une cle stable : sinon, chaque nouveau build est considere par
// Android comme une application differente et refuse de s'installer
// par-dessus la precedente ("package conflicts with an existing
// package"), obligeant a desinstaller a chaque mise a jour.
// =============================================================
val proprietesDeSignature = Properties()
val fichierDeSignature = rootProject.file("key.properties")
val signatureDisponible = fichierDeSignature.exists()
if (signatureDisponible) {
    proprietesDeSignature.load(FileInputStream(fichierDeSignature))
}

android {
    namespace = "com.trialgo.trialgo_admin"
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
        // Deja hors de com.example.* : identifiant conserve tel quel.
        // Ne plus le modifier une fois l'app distribuee.
        applicationId = "com.trialgo.trialgo_admin"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signatureDisponible) {
            create("release") {
                keyAlias = proprietesDeSignature["keyAlias"] as String
                keyPassword = proprietesDeSignature["keyPassword"] as String
                storeFile = proprietesDeSignature["storeFile"]?.let {
                    rootProject.file(it as String)
                }
                storePassword = proprietesDeSignature["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (signatureDisponible) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "TRIALGO admin : android/key.properties absent, build release " +
                    "signe avec la cle de DEBUG. Ce binaire ne peut pas etre publie."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
