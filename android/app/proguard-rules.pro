# Flutter uses R8, which ignores this file unless minifyEnabled is true.
# Keep Flutter and plugin entry points.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Preserve model classes that rely on reflection for JSON (if any are added later).
-keep class uk.co.rodderscode.drugs_taken.** { *; }

# Avoid stripping generic type information used by sqflite and other plugins.
-keepattributes *Annotation*, Signature

