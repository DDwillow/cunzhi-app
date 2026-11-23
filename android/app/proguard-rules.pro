# Flutter 相关 keep 规则
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }

# ===== ML Kit 关键：内部用 Dagger 依赖注入，R8 混淆会破坏注入关系 =====
# 必须完整保留 com.google.mlkit 下的所有类和成员，否则启动时
# MlKitInitProvider 报 "Unsatisfied dependency"（class ve / zzp 等）崩溃。
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Dagger 依赖注入框架（ML Kit 内部使用），保留其注解和生成的工厂类
-dontwarn dagger.**
-keep class dagger.** { *; }
-dontwarn javax.inject.**
-keep class javax.inject.** { *; }
-dontwarn javax.annotation.**

# 保留 google_mlkit_text_recognition 插件入口
-keep class com.google_mlkit_text_recognition.** { *; }

# ===== 忽略可选依赖（未打包，运行时不会用到）=====
# Flutter 引擎对 Play Core（deferred components 延迟加载）的可选引用
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
