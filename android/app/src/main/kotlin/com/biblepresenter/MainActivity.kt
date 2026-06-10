package com.biblepresenter

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Main Activity for BiblePresenter.
 *
 * Sets up the Pigeon CastHostApi implementation which bridges
 * Flutter ↔ Native for Google Cast (Chromecast) functionality.
 */
class MainActivity : FlutterActivity() {

    private var castApiImpl: CastHostApiImpl? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize our Cast Host API implementation
        castApiImpl = CastHostApiImpl(this, flutterEngine.dartExecutor.binaryMessenger).also {
            it.initialize()
            // Register the Pigeon Host API handler
            CastHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, it)
        }

        // Also handle the legacy MethodChannel for screen mirroring
        MethodChannelHandler.setup(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        castApiImpl?.dispose()
        castApiImpl = null
        super.onDestroy()
    }
}
