// =============================================================
// FICHIER : trialgo/android/app/build.gradle.kts
// ROLE    : Configuration de build Android de l'app JOUEUR
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
// Un APK/AAB distribue doit etre signe avec NOTRE cle, jamais avec
// la cle de debug generee automatiquement par Android : le Play
// Store refuse les binaires signes en debug, et la cle de debug
// n'est pas la meme d'une machine a l'autre.
//
// La cle est decrite dans android/key.properties, un fichier
// VOLONTAIREMENT absent du depot (il contient des mots de passe).
// Chaque poste de build en possede sa copie. Voir android/
// key.properties.example pour le gabarit et la commande keytool.
//
// Comportement si le fichier est absent : on retombe sur la
// signature de debug. C'est ce qui permet a `flutter run --release`
// de fonctionner sur un poste de developpement sans keystore. Le
// bloc buildTypes ci-dessous journalise alors un avertissement,
// pour qu'un build non signable ne passe pas inapercu.
// =============================================================
val proprietesDeSignature = Properties()
val fichierDeSignature = rootProject.file("key.properties")
val signatureDisponible = fichierDeSignature.exists()
if (signatureDisponible) {
    proprietesDeSignature.load(FileInputStream(fichierDeSignature))
}

android {
    // namespace : identifiant du package Kotlin/Java genere.
    // Il reste sur com.example.trialgo car le changer imposerait de
    // deplacer MainActivity.kt et tous les fichiers generes. Il est
    // interne a la compilation et n'est PAS ce que voit le Play
    // Store : c'est applicationId (ci-dessous) qui identifie l'app.
    namespace = "com.example.trialgo"
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
        // =====================================================
        // applicationId : L'IDENTITE DEFINITIVE DE L'APP
        // =====================================================
        // C'est la cle primaire de l'app sur le Play Store et sur
        // l'appareil. Elle est IMMUABLE une fois la premiere version
        // publiee : la changer ensuite cree une application
        // differente, sans mise a jour possible pour les utilisateurs
        // deja installes.
        //
        // L'ancienne valeur, "com.example.trialgo", venait du gabarit
        // Flutter. Le Play Store refuse tout identifiant sous
        // com.example.*, considere comme un espace de noms de test.
        //
        // Aligne avec l'app studio (com.trialgo.trialgo_admin).
        // =====================================================
        applicationId = "com.trialgo.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // La configuration n'est declaree que si key.properties existe.
        // La declarer avec des valeurs nulles ferait echouer la
        // configuration Gradle sur les postes sans keystore.
        if (signatureDisponible) {
            create("release") {
                keyAlias = proprietesDeSignature["keyAlias"] as String
                keyPassword = proprietesDeSignature["keyPassword"] as String
                // storeFile est un chemin relatif au dossier android/.
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
                // Repli : build local uniquement, NON distribuable.
                logger.warn(
                    "TRIALGO joueur : android/key.properties absent, build release " +
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
