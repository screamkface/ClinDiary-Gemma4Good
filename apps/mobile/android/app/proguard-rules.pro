# Preserve Flutter embedding and plugin classes accessed via reflection.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep LiteRT entry points used by on-device AI initialization.
-keep class com.google.ai.edge.litertlm.** { *; }

-dontwarn com.google.android.play.core.**
