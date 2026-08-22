# Flutter's own engine/embedding and Dart AOT-compiled app code aren't
# touched by R8 (Dart isn't JVM bytecode) - these rules only cover the
# Android-side plugin bridges. Most plugins (file_picker, share_plus,
# flutter_secure_storage, url_launcher) ship their own consumer-rules.pro
# bundled in their AAR, so this file is intentionally minimal.

# Keep Play Core split-install classes some Flutter deferred-component
# tooling references reflectively, even though this app doesn't use
# deferred components today.
-dontwarn com.google.android.play.core.**
