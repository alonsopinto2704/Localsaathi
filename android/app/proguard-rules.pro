# Flutter and its plugins are covered by the Flutter team's consumer rules.
# These additions keep R8 from stripping plugin registration and the Flutter
# embedding, and they are written narrowly rather than disabling shrinking.

-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# shared_preferences uses reflection-free platform channels, but keep the plugin
# entry point so plugin registration survives shrinking.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
