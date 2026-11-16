package com.biblepresenter

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles MethodChannel calls from Flutter:
 *  - `biblepresenter/screencast`  → opens the system cast / screencast settings
 *  - `biblepresenter/cast_permissions` → checks & requests the runtime
 *    `ACCESS_FINE_LOCATION` permission that Android 6+ requires for
 *    NSD / mDNS service discovery (otherwise NSD silently returns
 *    zero results and `onServiceFound` is never fired).
 */
class MethodChannelHandler(private val context: android.content.Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "MethodChannelHandler"
        private const val CHANNEL = "biblepresenter/screencast"
        private const val PERMISSIONS_CHANNEL = "biblepresenter/cast_permissions"
        private const val PERMISSION_REQUEST_CODE = 7321

        fun setup(context: android.content.Context, messenger: BinaryMessenger) {
            val channel = MethodChannel(messenger, CHANNEL)
            channel.setMethodCallHandler(MethodChannelHandler(context))

            val permissionsChannel = MethodChannel(messenger, PERMISSIONS_CHANNEL)
            permissionsChannel.setMethodCallHandler(MethodChannelHandler(context))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openScreenMirror" -> {
                try {
                    // Try to open the cast/screencast settings directly
                    val intent = Intent(Settings.ACTION_CAST_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(null)
                } catch (e: Exception) {
                    Log.e(TAG, "Could not open cast settings: ${e.message}")
                    result.error("UNAVAILABLE", "Could not open screen mirror settings", null)
                }
            }
            "checkLocationPermission" -> {
                val granted = ContextCompat.checkSelfPermission(
                    context, Manifest.permission.ACCESS_FINE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
                result.success(if (granted) "granted" else "denied")
            }
            "requestLocationPermission" -> requestLocationPermission(result)
            "openAppSettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    intent.data = Uri.fromParts("package", context.packageName, null)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "Could not open app settings", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun requestLocationPermission(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success("granted")
            return
        }
        val activity: Activity? = (context as? Activity) ?: PermissionActivity.activityInstance
        if (activity == null) {
            result.error(
                "NO_ACTIVITY",
                "No foreground Activity available to request permission. " +
                    "Open the cast sheet from the main screen first.",
                null
            )
            return
        }
        if (ActivityCompat.shouldShowRequestPermissionRationale(
                activity, Manifest.permission.ACCESS_FINE_LOCATION
            )
        ) {
            // User has previously denied. Don't loop on the dialog; tell Flutter
            // to surface a "Open Settings" prompt instead.
            result.success("denied_permanently")
            return
        }
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
            PERMISSION_REQUEST_CODE
        )
        // The result is delivered asynchronously via PermissionActivity's
        // onRequestPermissionsResult; for simplicity, return the current
        // state synchronously. Flutter will re-check on next scan attempt.
        result.success(
            if (ContextCompat.checkSelfPermission(
                    context, Manifest.permission.ACCESS_FINE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
            ) "granted" else "pending"
        )
    }
}
