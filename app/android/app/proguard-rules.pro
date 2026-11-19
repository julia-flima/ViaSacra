# Via Sacra — regras R8
# audio_service / just_audio (Media3)
-keep class com.ryanheise.** { *; }
# flutter_local_notifications usa Gson para serializar notificações agendadas
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
# flutter_tts
-keep class com.eyedeadevelopment.fluttertts.** { *; }
