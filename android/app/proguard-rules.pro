## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

#-keep class com.google.firebase.** { *; }
#-keep class com.google.android.gms.** { *; }

## Prevent R8 from compressing the names of our classes
-keepnames class * { *; }

## Preserve all annotations and annotation members
-keepattributes *Annotation*

## Preserve all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

## Preserve enum types and their values
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

## Preserve the special static methods that are required in all enumeration classes
-keepclassmembers class * extends java.lang.Enum {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}