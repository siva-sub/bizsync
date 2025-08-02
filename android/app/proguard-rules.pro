# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Dart VM and Flutter optimizations
-dontwarn io.flutter.**
-dontwarn androidx.**

# Keep SQLCipher/SQLite classes
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# Keep QR code generation classes
-keep class com.google.zxing.** { *; }

# Keep encryption/crypto classes
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }

# Keep Bluetooth classes for P2P sync
-keep class android.bluetooth.** { *; }

# Keep notification classes
-keep class androidx.core.app.NotificationCompat** { *; }

# Generic rules for reflection-based serialization
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Gson/JSON serialization
-keepattributes Signature
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.stream.** { *; }

# Keep model classes for JSON serialization
-keep class com.bizsync.app.** { *; }

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Optimize and obfuscate
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-dontpreverify
-verbose

# Keep line numbers for debugging stack traces
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile