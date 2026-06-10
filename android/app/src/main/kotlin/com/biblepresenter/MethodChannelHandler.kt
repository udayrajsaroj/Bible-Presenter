package com.biblepresenter

import android.content.Intent
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles the legacy MethodChannel `biblepresenter/screencast` for
 * opening the phone's screen mirroring / screencast settings.
 */
class MethodChannelHandler(private val context: android.content.Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "MethodChannelHandler"
        private const val CHANNEL = "biblepresenter/screencast"

        fun setup(context: android.content.Context, messenger: BinaryMessenger) {
            val channel = MethodChannel(messenger, CHANNEL)
            channel.setMethodCallHandler(MethodChannelHandler(context))
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
            else -> result.notImplemented()
        }
    }
}
