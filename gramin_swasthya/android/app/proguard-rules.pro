# Flutter plugins can be reached through reflection or Android manifest entries.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class net.sqlcipher.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class dev.fluttercommunity.plus.androidalarmmanager.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep <methods>;
    @androidx.annotation.Keep <fields>;
}

# Keep Firebase/Google service model metadata used by reflection.
-keepattributes *Annotation*
-keepattributes Signature
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.**

# Flutter references Play Store deferred-component APIs even when the app does
# not declare deferred components. The Play Core dependency is intentionally
# not packaged for this APK, so suppress those optional references.
-dontwarn com.google.android.play.core.**
