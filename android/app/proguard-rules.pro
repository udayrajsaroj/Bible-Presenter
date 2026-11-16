# Suppress missing optional OSGi annotations referenced by jUPnP (used by media_cast_dlna)
-dontwarn org.osgi.**
-dontwarn org.jupnp.**

# Keep jUPnP classes, interfaces, and Android services
-keep class org.jupnp.** { *; }
-keep interface org.jupnp.** { *; }
-keep class org.jupnp.android.AndroidUpnpServiceImpl { *; }
-keep class br.com.felnanuke2.media_cast_dlna.** { *; }

# Keep Google Cast framework
-keep class com.google.android.gms.cast.** { *; }
-keep class androidx.mediarouter.** { *; }
