import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Assinatura de release (opcional). Fontes, em ordem:
//   1. android/key.properties (local, ignorado pelo git)
//   2. variáveis de ambiente (GitHub Actions): ANDROID_KEYSTORE_PATH,
//      ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD
// Sem nenhuma delas, o release é assinado com a chave de debug (o F-Droid
// compila e assina com a própria chave a partir do código-fonte).
// ---------------------------------------------------------------------------
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}
fun signingValue(prop: String, env: String): String? =
    keystoreProperties.getProperty(prop) ?: System.getenv(env)

val releaseStoreFile = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")

android {
    namespace = "io.github.juliaflima.via_sacra"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Necessário para flutter_local_notifications (java.time em APIs antigas)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.juliaflima.via_sacra"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // versionCode vem do pubspec.yaml; nos APKs por ABI o Flutter soma 1000*ABI.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseStoreFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    // F-Droid / builds reproduzíveis: não embutir o bloco de metadados de
    // dependências assinado pelo Google (é opaco e quebra a reprodutibilidade).
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    packaging {
        jniLibs {
            // Bibliotecas nativas descompactadas e alinhadas: APK determinístico.
            useLegacyPackaging = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
