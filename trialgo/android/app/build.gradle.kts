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
    // Il valait com.example.trialgo, le defaut du gabarit Flutter
    // jamais renomme. Le deplacement de MainActivity.kt qu'imposait
    // son changement a ete fait en meme temps que le passage a
    // com.mixalgo.app : autant tout aligner d'un seul coup plutot
    // que laisser un "com.example" dans une application publiee.
    namespace = "com.mixalgo.app"
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
        // Histoire de cette valeur :
        //   com.example.trialgo  gabarit Flutter, refuse par le Play
        //                        Store qui traite com.example.* comme
        //                        un espace de noms de test
        //   com.trialgo.app      ancien nom du produit
        //   com.mixalgo.app      le nom reel, arrete AVANT toute
        //                        publication -- seul moment ou ce
        //                        changement est encore possible
        //
        // Le studio admin garde com.trialgo.trialgo_admin : c'est un
        // outil interne qui ne passe pas par le Play Store, et le
        // renommer n'apporterait rien.
        // =====================================================
        applicationId = "com.mixalgo.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // =====================================================
        // LES ARCHITECTURES EMBARQUEES
        // =====================================================
        // Mesure sur l'APK de 71,8 Mo : 63,6 Mo de bibliotheques
        // natives, reparties ainsi.
        //
        //   arm64-v8a     21,6 Mo   telephones modernes
        //   armeabi-v7a   17,9 Mo   telephones 32 bits
        //   x86_64        24,1 Mo   EMULATEURS uniquement
        //
        // Aucun telephone du commerce n'execute x86_64 : cette
        // architecture ne sert qu'aux emulateurs de developpement.
        // L'APK etant distribue par telechargement direct depuis
        // mixalgo.com, et non par un magasin qui saurait servir la
        // bonne variante, chaque joueur telechargeait ces 24 Mo
        // pour rien -- soit un tiers de l'attente, sur une
        // connexion mobile ou le fichier met deja plusieurs
        // minutes.
        //
        // Le developpement n'est pas gene : `flutter run` produit
        // un build de debug, qui n'est pas soumis a ce filtre.
        //
        // DEUX MECANISMES SONT NECESSAIRES, et c'est le piege :
        //
        //   1. Les bibliotheques de FLUTTER (libflutter.so,
        //      libapp.so) sont placees par son greffon Gradle
        //      selon --target-platform, pas selon abiFilters. Le
        //      filtre seul laissait donc l'APK a 71,8 Mo.
        //      -> voir la commande de build dans CLAUDE.md
        //
        //   2. Les bibliotheques des GREFFONS (ML Kit, CameraX)
        //      arrivent en dependances Android classiques. Elles
        //      ne repondent ni a --target-platform ni, en
        //      pratique, a abiFilters une fois le greffon Flutter
        //      passe. Elles sont donc exclues a l'empaquetage,
        //      ci-dessous.
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    // Le filet qui attrape ce que les deux mecanismes precedents
    // laissent passer. Sans lui, libbarhopper_v3.so -- le lecteur
    // de codes-barres de ML Kit -- pesait a lui seul 5,5 Mo en
    // x86_64, pour une architecture qu'aucun telephone n'execute.
    packaging {
        jniLibs {
            excludes += setOf("lib/x86/**", "lib/x86_64/**")
        }
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
