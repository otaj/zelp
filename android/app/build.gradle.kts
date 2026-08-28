import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    // Kotlin is applied by the Flutter plugin (matches the Flutter 3.44 app template).
    id("dev.flutter.flutter-gradle-plugin")
    id("io.gitlab.arturbosch.detekt")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "org.zelp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "org.zelp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // `prod` keeps the store id; `screenshots` installs beside it for capture runs.
    flavorDimensions += "install"
    productFlavors {
        create("prod") {
            dimension = "install"
            resValue("string", "app_name", "Zelp")
        }
        create("screenshots") {
            dimension = "install"
            applicationIdSuffix = ".screenshots"
            resValue("string", "app_name", "Zelp Screenshots")
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the release keystore when android/key.properties exists; otherwise
            // fall back to debug so CI / F-Droid source builds still work.
            signingConfig =
                if (hasReleaseKeystore) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }

    lint {
        abortOnError = true
        warningsAsErrors = true
        checkReleaseBuilds = false
    }

    // Keep Google Play's proprietary SDK-dependency metadata out of the APK
    // signing block (F-Droid rejects the extra "Dependency metadata" block).
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }
}

// ART baseline profiles are often non-deterministic across machines (F-Droid
// reproducible-build diffs in assets/dexopt/baseline.prof).
tasks.whenTaskAdded {
    if (name.contains("ArtProfile")) {
        enabled = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

detekt {
    buildUponDefaultConfig = true
    allRules = false
    parallel = true
    config.setFrom(rootProject.file("config/detekt/detekt.yml"))
    source.setFrom(
        files(
            "src/main/kotlin",
            "src/main/java",
        ),
    )
}

// Public alias so CI/pre-commit can run `./gradlew :app:analyze`
// (mirrors `flutter analyze`; avoids colliding with AGP's `lint` task).
tasks.register("analyze") {
    group = "verification"
    description = "Run Kotlin static analysis (detekt)"
    dependsOn("detekt")
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.documentfile:documentfile:1.0.1")
    implementation("androidx.activity:activity-ktx:1.9.3")
    detektPlugins("io.gitlab.arturbosch.detekt:detekt-formatting:1.23.8")
}
