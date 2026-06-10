package com.biblepresenter

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Bundle
import android.util.Log
import com.google.android.gms.cast.CastStatusCodes
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.MediaStatus
import com.google.android.gms.cast.MediaTrack
import com.google.android.gms.cast.framework.CastButtonFactory
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastState
import com.google.android.gms.cast.framework.CastStateListener
import com.google.android.gms.cast.framework.IntroductoryOverlay
import com.google.android.gms.cast.framework.SessionManagerListener
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import com.google.android.gms.common.api.Status
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger

/**
 * CastHostApiImpl — Implements the Pigeon-generated [CastHostApi] interface.
 *
 * This class handles:
 * 1. **mDNS Discovery** — Uses Android's [NsdManager] to find Chromecast devices
 *    on the local network via the `_googlecast._tcp.` service type.
 * 2. **Google Cast Session** — Uses the Google Play Services Cast SDK
 *    ([CastContext], [RemoteMediaClient]) to connect and load media.
 * 3. **Media Playback** — Play, pause, seek, volume control via [RemoteMediaClient].
 *
 * Requirements:
 * - Google Play Services must be available on the device.
 * - `android.permission.ACCESS_WIFI_STATE` and `ACCESS_NETWORK_STATE` in Manifest.
 * - Cast options provider configured in AndroidManifest metadata.
 */
class CastHostApiImpl(
    private val context: Context,
    binaryMessenger: BinaryMessenger
) : CastHostApi {

    companion object {
        private const val TAG = "CastHostApiImpl"
        private const val CHROMECAST_SERVICE_TYPE = "_googlecast._tcp."
    }

    // ── Pigeon Flutter API (Native → Flutter) ──
    private val flutterApi = CastFlutterApi(binaryMessenger)

    // ── mDNS Discovery ──
    private var nsdManager: NsdManager? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private val resolveQueue = mutableListOf<NsdServiceInfo>()
    private var isResolving = false

    // ── Google Cast SDK ──
    private var castContext: CastContext? = null
    private var remoteMediaClient: RemoteMediaClient? = null
    private var connectedDeviceId: String = ""

    // ── Cast state listener ──
    private val castStateListener = object : CastStateListener {
        override fun onCastStateChanged(state: Int) {
            when (state) {
                CastState.CONNECTED -> {
                    val session = castContext?.sessionManager?.currentCastSession
                    val device = session?.castDevice
                    if (device != null) {
                        connectedDeviceId = device.deviceId ?: device.friendlyName ?: "unknown"
                        remoteMediaClient = session.remoteMediaClient
                        setupRemoteMediaClientCallbacks()
                        flutterApi.onConnected(connectedDeviceId) {}
                    }
                }
                CastState.NOT_CONNECTED -> {
                    if (connectedDeviceId.isNotEmpty()) {
                        connectedDeviceId = ""
                        remoteMediaClient = null
                        flutterApi.onDisconnected() {}
                    }
                }
            }
        }
    }

    // ── Session listener ──
    private val sessionListener = object : SessionManagerListener<com.google.android.gms.cast.framework.CastSession> {
        override fun onSessionStarted(session: com.google.android.gms.cast.framework.CastSession, sessionId: String) {
            connectedDeviceId = session.castDevice?.deviceId ?: sessionId
            remoteMediaClient = session.remoteMediaClient
            setupRemoteMediaClientCallbacks()
            flutterApi.onConnected(connectedDeviceId) {}
        }

        override fun onSessionEnded(session: com.google.android.gms.cast.framework.CastSession, error: Int) {
            connectedDeviceId = ""
            remoteMediaClient = null
            flutterApi.onDisconnected() {}
        }

        override fun onSessionResumed(session: com.google.android.gms.cast.framework.CastSession, wasSuspended: Boolean) {
            connectedDeviceId = session.castDevice?.deviceId ?: "resumed"
            remoteMediaClient = session.remoteMediaClient
            setupRemoteMediaClientCallbacks()
            flutterApi.onConnected(connectedDeviceId) {}
        }

        override fun onSessionResumeFailed(session: com.google.android.gms.cast.framework.CastSession, error: Int) {}
        override fun onSessionResuming(session: com.google.android.gms.cast.framework.CastSession, sessionId: String) {}
        override fun onSessionStarting(session: com.google.android.gms.cast.framework.CastSession) {}
        override fun onSessionEnding(session: com.google.android.gms.cast.framework.CastSession) {}
        override fun onSessionSuspended(session: com.google.android.gms.cast.framework.CastSession, reason: Int) {}
        override fun onSessionStartFailed(session: com.google.android.gms.cast.framework.CastSession, error: Int) {
            flutterApi.onError("Session start failed: error code $error") {}
        }
    }

    /** Call this from the Activity's onCreate / configureFlutterEngine. */
    fun initialize() {
        try {
            castContext = CastContext.getSharedInstance(context)
            castContext?.addCastStateListener(castStateListener)
            castContext?.sessionManager?.addSessionManagerListener(
                sessionListener, com.google.android.gms.cast.framework.CastSession::class.java)

            // If already connected, notify Flutter
            val session = castContext?.sessionManager?.currentCastSession
            if (session != null && session.isConnected) {
                connectedDeviceId = session.castDevice?.deviceId ?: "existing"
                remoteMediaClient = session.remoteMediaClient
                setupRemoteMediaClientCallbacks()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Cast SDK not available: ${e.message}")
        }

        nsdManager = context.getSystemService(Context.NSD_SERVICE) as? NsdManager
    }

    /** Call this from the Activity's onDestroy to clean up. */
    fun dispose() {
        castContext?.removeCastStateListener(castStateListener)
        castContext?.sessionManager?.removeSessionManagerListener(
            sessionListener, com.google.android.gms.cast.framework.CastSession::class.java)
        stopDiscovery()
    }

    // ══════════════════ Host API Implementation ══════════════════

    override fun startDiscovery() {
        if (nsdManager == null) {
            flutterApi.onError("NSD Manager not available") {}
            return
        }

        stopDiscovery() // Stop any existing discovery first

        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {
                Log.d(TAG, "mDNS discovery started for $serviceType")
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Found service: ${serviceInfo.serviceName}")
                resolveService(serviceInfo)
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Service lost: ${serviceInfo.serviceName}")
                val id = serviceInfo.serviceName
                flutterApi.onDeviceLost(id) {}
            }

            override fun onDiscoveryStopped(serviceType: String) {
                Log.d(TAG, "mDNS discovery stopped")
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "Discovery start failed: $errorCode")
                flutterApi.onError("Discovery start failed: error $errorCode") {}
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "Discovery stop failed: $errorCode")
            }
        }

        discoveryListener = listener
        try {
            nsdManager?.discoverServices(CHROMECAST_SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start discovery: ${e.message}")
            flutterApi.onError("Failed to start discovery: ${e.message}") {}
        }
    }

    override fun stopDiscovery() {
        try {
            discoveryListener?.let { nsdManager?.stopServiceDiscovery(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping discovery: ${e.message}")
        }
        discoveryListener = null
        resolveQueue.clear()
        isResolving = false
    }

    override fun connectToDevice(deviceId: String) {
        // With Google Cast SDK, we use the CastContext to initiate connection.
        // The deviceId here should match the friendlyName or deviceId from discovery.
        // Since Cast SDK has its own device discovery & selection flow,
        // we use the discovered mDNS device name to find a matching Cast device.
        try {
            val sessionManager = castContext?.sessionManager
            if (sessionManager == null) {
                flutterApi.onError("CastContext not initialized") {}
                return
            }

            // Attempt to start a cast session with the matching device.
            // The Cast SDK handles the actual connection via its internal route.
            val castState = castContext?.castState ?: CastState.NO_DEVICES_AVAILABLE
            if (castState == CastState.NO_DEVICES_AVAILABLE) {
                flutterApi.onError("No cast devices available. Ensure devices are on the same network.") {}
                return
            }

            // The Cast SDK uses its own internal discovery; our mDNS discovery
            // is supplementary for the Flutter UI device list. When the user
            // taps "Connect", we need to match our discovered device to the
            // SDK's known devices. The easiest way is to let the user use the
            // Cast dialog, but we can also try to programmatically start a session.
            flutterApi.onError("Use the system Cast button to connect to $deviceId, or the session will auto-start when a Cast device is selected.") {}
        } catch (e: Exception) {
            flutterApi.onError("connectToDevice failed: ${e.message}") {}
        }
    }

    override fun disconnect() {
        try {
            castContext?.sessionManager?.endCurrentSession(true)
            connectedDeviceId = ""
            remoteMediaClient = null
        } catch (e: Exception) {
            flutterApi.onError("disconnect failed: ${e.message}") {}
        }
    }

    override fun loadMedia(mediaUrl: String, title: String, contentType: String) {
        val client = remoteMediaClient
        if (client == null) {
            flutterApi.onError("Not connected to a cast device") {}
            return
        }

        val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_GENERIC)
        metadata.putString(MediaMetadata.KEY_TITLE, title)

        val mediaInfo = MediaInfo.Builder(mediaUrl)
            .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType(contentType)
            .setMetadata(metadata)
            .build()

        val requestData = MediaLoadRequestData.Builder()
            .setMediaInfo(mediaInfo)
            .build()

        client.load(requestData)
            .setResultCallback { result ->
                if (result.status.isSuccess) {
                    Log.d(TAG, "Media loaded successfully: $title")
                } else {
                    val statusCode = result.status.statusCode
                    val errorMsg = "Load failed: status code $statusCode"
                    flutterApi.onError(errorMsg) {}
                }
            }
    }

    override fun play() {
        remoteMediaClient?.play()
    }

    override fun pause() {
        remoteMediaClient?.pause()
    }

    override fun seekTo(positionSeconds: Double) {
        remoteMediaClient?.seek(positionSeconds.toLong() * 1000) // ms
    }

    override fun setVolume(volume: Double) {
        // RemoteMediaClient volume is 0.0 – 1.0
        remoteMediaClient?.setStreamVolume(volume.coerceIn(0.0, 1.0))
    }

    override fun showAirPlayPicker() {
        // No-op on Android — AirPlay is an Apple-only feature.
        Log.d(TAG, "showAirPlayPicker is a no-op on Android")
    }

    override fun getConnectedDeviceId(): String {
        return connectedDeviceId
    }

    // ══════════════════ Private Helpers ══════════════════

    private fun resolveService(serviceInfo: NsdServiceInfo) {
        synchronized(resolveQueue) {
            resolveQueue.add(serviceInfo)
            if (!isResolving) {
                resolveNext()
            }
        }
    }

    private fun resolveNext() {
        synchronized(resolveQueue) {
            if (resolveQueue.isEmpty()) {
                isResolving = false
                return
            }
            isResolving = true
            val info = resolveQueue.removeAt(0)

            nsdManager?.resolveService(info, object : NsdManager.ResolveListener {
                override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                    Log.e(TAG, "Resolve failed for ${serviceInfo.serviceName}: $errorCode")
                    synchronized(resolveQueue) {
                        resolveNext()
                    }
                }

                override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                    val deviceName = serviceInfo.serviceName ?: "Unknown Chromecast"
                    val deviceId = serviceInfo.serviceName ?: ""

                    // Try to extract friendly name from TXT records
                    val attributes = serviceInfo.attributes
                    var friendlyName = deviceName
                    val fn = attributes["fn"]
                    if (fn != null && fn.isNotEmpty()) {
                        friendlyName = String(fn)
                    }

                    Log.d(TAG, "Resolved device: $friendlyName ($deviceId) at ${serviceInfo.host?.hostAddress}")

                    val device = CastDevice(
                        deviceId = deviceId,
                        name = friendlyName,
                        platform = "chromecast"
                    )
                    flutterApi.onDeviceDiscovered(device) {}

                    synchronized(resolveQueue) {
                        resolveNext()
                    }
                }
            })
        }
    }

    private fun setupRemoteMediaClientCallbacks() {
        remoteMediaClient?.registerCallback(object : RemoteMediaClient.Callback() {
            override fun onStatusUpdated() {
                val mediaStatus = remoteMediaClient?.mediaStatus ?: return
                val playerState = when (mediaStatus.playerState) {
                    MediaStatus.PLAYER_STATE_PLAYING -> "playing"
                    MediaStatus.PLAYER_STATE_PAUSED -> "paused"
                    MediaStatus.PLAYER_STATE_BUFFERING -> "buffering"
                    MediaStatus.PLAYER_STATE_IDLE -> "idle"
                    else -> "idle"
                }

                val mediaInfo = mediaStatus.mediaInfo
                val title = mediaInfo?.metadata?.getString(MediaMetadata.KEY_TITLE) ?: ""
                val duration = (mediaInfo?.streamDuration?.toDouble() ?: 0.0) / 1000.0
                val position = (remoteMediaClient?.approximateStreamPosition?.toDouble() ?: 0.0) / 1000.0

                val state = CastPlayerState(
                    state = playerState,
                    position = position,
                    duration = duration,
                    volume = mediaStatus.streamVolume.toDouble(),
                    mediaTitle = title
                )
                flutterApi.onPlayerStateChanged(state) {}
            }

            override fun onMetadataUpdated() {
                // Trigger status update which will send the new title
                onStatusUpdated()
            }
        })
    }
}
