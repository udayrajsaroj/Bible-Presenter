package com.biblepresenter

import android.app.Activity
import android.os.Bundle

/**
 * Transparent activity used to request runtime permissions
 * (specifically ACCESS_FINE_LOCATION for NSD/mDNS discovery).
 *
 * Uses Activity instead of AppCompatActivity to avoid
 * requiring the appcompat dependency.
 */
class PermissionActivity : Activity() {

    companion object {
        const val PERMISSION_REQUEST_CODE = 7321

        // Static reference so MethodChannelHandler can access the Activity
        var activityInstance: PermissionActivity? = null
            private set
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        activityInstance = this
    }

    override fun onDestroy() {
        activityInstance = null
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            // Result is handled by MethodChannelHandler's check on next scan.
            finish()
        }
    }
}
