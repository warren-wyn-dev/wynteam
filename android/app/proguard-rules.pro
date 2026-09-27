# kotlinx.serialization models used by supabase-kt
-keepattributes *Annotation*, InnerClasses
-keepclassmembers class **$$serializer { *; }
-keepclasseswithmembers class io.wyn.wyn.** { kotlinx.serialization.KSerializer serializer(...); }
