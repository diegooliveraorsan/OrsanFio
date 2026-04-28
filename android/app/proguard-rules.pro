-keep class com.regula.** { *; }
-keep class com.regula.face.** { *; }
-keep class com.regula.document.** { *; }
-keep class com.google.firebase.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-dontwarn okhttp3.**
-dontwarn okio.**