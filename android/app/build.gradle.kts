plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.cunzhi.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.cunzhi.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // 开启资源压缩 + R8 代码压缩混淆，减小体积。
            // 注意：ML Kit 内部用 Dagger 依赖注入，必须在
            // proguard-rules.pro 里对 ML Kit 相关类做完整 keep，
            // 否则启动时 MlKitInitProvider 报 "Unsatisfied dependency" 崩溃。
            isShrinkResources = true
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // 关闭 lint 的 release 检查，规避 lint 工具自身 bug（CommentDetector
    // 在旧 JDK 下调用 List.removeLast() 抛 NoSuchMethodError）导致构建失败。
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ML Kit 中文 OCR 模型（bundled，打包进 APK，离线可用）。
    // google_mlkit_text_recognition 插件默认只用 compileOnly 引入，
    // 必须在这里显式 implementation 才会真正打包进 APK，否则运行时
    // 会报 ClassNotFoundException: ChineseTextRecognizerOptions 并闪退。
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
}
