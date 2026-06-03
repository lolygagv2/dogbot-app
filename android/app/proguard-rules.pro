# WIM-Z Android release keep rules.
#
# NOTE: R8/minification is currently DISABLED in build.gradle.kts (Flutter
# default), so these rules are not yet active. They are wired into the release
# buildType ahead of time so that if/when we enable `isMinifyEnabled = true`
# (smaller AAB), the native plugins that reach code via JNI/reflection don't get
# stripped or obfuscated. The classic symptom of a missing rule is: debug APK
# works, release AAB crashes on launch or on the video/audio screen.

# ---- flutter_webrtc (org.webrtc native bridge, reached via JNI) ----
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# ---- Flutter embedding / plugin registrant (reflection) ----
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ---- flutter_local_notifications (GSON + receivers via reflection) ----
-keep class com.dexterous.** { *; }
-keepattributes *Annotation*
# Keep generic signatures GSON relies on for scheduled-notification payloads.
-keepattributes Signature

# ---- record / audioplayers (MediaRecorder/MediaPlayer callbacks) ----
-keep class com.llfbandit.record.** { *; }
-keep class xyz.luan.audioplayers.** { *; }

# ---- Keep native methods generally (JNI entry points) ----
-keepclasseswithmembernames class * {
    native <methods>;
}
