# Gson uses reflection over the data model classes; keep their members.
-keep class com.cometchat.marketplace.data.model.** { *; }

# Retrofit / OkHttp defaults.
-dontwarn okhttp3.**
-dontwarn retrofit2.**
-keepattributes Signature
-keepattributes *Annotation*
