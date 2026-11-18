import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'cast_api.g.dart';

// ══════════════════════════════════════════════════════════════
// CastService — Central controller for Google Cast & AirPlay
// ══════════════════════════════════════════════════════════════
//
// This service bridges the Pigeon-generated [CastHostApi] and
// [CastFlutterApi] with the app's UI. It exposes reactive state
// via [ChangeNotifier] so any widget can listen and rebuild.
//
// Usage:
//   final castService = CastService();
//   CastFlutterApi.setup(castService);   // register native→Flutter handler
//   castService.startDiscovery();         // begin scanning
//   castService.connectToDevice(deviceId);
//   castService.loadMedia(url: '...', title: '...', contentType: 'video/mp4');
// ══════════════════════════════════════════════════════════════

class CastService extends ChangeNotifier implements CastFlutterApi {
  // ── Pigeon Host API instance ──
  final CastHostApi _hostApi = CastHostApi();

  // ── Disposal guard ──
  // Native callbacks can arrive after the host widget has been disposed
  // (e.g. user backs out while a Cast session is tearing down). Calling
  // notifyListeners() on a disposed ChangeNotifier throws a FlutterError.
  // All notifyListeners() calls are routed through _safeNotify which
  // bails out if _disposed is true.
  bool _disposed = false;
  bool get isDisposed => _disposed;

  /// Mark this service as disposed. Called from the host's dispose().
  /// After this point, native callbacks become no-ops.
  void markDisposed() {
    _disposed = true;
  }

  void _safeNotify() {
    if (_disposed) return;
    // Ensure notifyListeners is called on the UI thread to avoid issues
    // when called from platform channel isolates.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        try {
          notifyListeners();
        } catch (_) {
          // Defensive: never let a stray listener throw propagate up to the
          // platform channel handler (would crash the isolate).
        }
      }
    });
  }

  // ── Discovered devices ──
  final Map<String, CastDevice> _discoveredDevices = {};

  /// Unmodifiable list of currently discovered cast devices.
  List<CastDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices.values);

  // ── Connection state ──
  bool _isConnected = false;

  /// Whether we are currently connected to a cast device.
  bool get isConnected => _isConnected;

  bool _isConnecting = false;

  /// Whether we are currently in the process of connecting to a device.
  bool get isConnecting => _isConnecting;

  String _connectedDeviceId = '';

  /// Device ID of the currently connected device, or empty string.
  String get connectedDeviceId => _connectedDeviceId;

  String _connectedDeviceName = '';

  /// Human-readable name of the connected device.
  String get connectedDeviceName => _connectedDeviceName;

  // ── Player state ──
  CastPlayerState _playerState = CastPlayerState(
    state: 'idle',
    position: 0,
    duration: 0,
    volume: 1.0,
    mediaTitle: '',
  );

  /// Current playback state on the cast device.
  CastPlayerState get playerState => _playerState;

  /// Convenience: is media currently playing?
  bool get isPlaying => _playerState.state == 'playing';

  /// Convenience: is media currently paused?
  bool get isPaused => _playerState.state == 'paused';

  // ── Discovery state ──
  bool _isDiscovering = false;

  /// Whether device discovery is currently active.
  bool get isDiscovering => _isDiscovering;

  // ── Error state ──
  String _lastError = '';

  /// Last error message from the native layer (empty if no error).
  String get lastError => _lastError;

  // ────────────────────────────────────────────────────────────
  // Host API wrappers (Flutter → Native)
  // ────────────────────────────────────────────────────────────

  /// Start mDNS / NSD discovery for Chromecast devices.
  /// On iOS, this is a no-op since AVRouteDetector auto-discovers.
  ///
  /// On Android 6+ (API 23+), ACCESS_FINE_LOCATION must be granted at
  /// runtime before NSD discovery will work. If it isn't, we ask the
  /// host page to request it via [requestAndroidLocationPermission].
  /// If the host never wired that up, the request silently fails and
  /// the user will see "No devices found" — but the app won't crash.
  Future<void> startDiscovery() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final granted = await _ensureAndroidLocationPermission();
        if (!granted) {
          _lastError =
              'Location permission required to find cast devices. Please enable in Settings.';
          _isDiscovering = false;
          _safeNotify();
          return;
        }
      }
      await _hostApi.startDiscovery();
      _isDiscovering = true;
      _lastError = '';
      _safeNotify();
    } catch (e) {
      _lastError = 'startDiscovery failed: $e';
      _safeNotify();
    }
  }

  /// Returns true if location permission is granted (or not needed).
  /// The host widget should call [setLocationPermissionChannel] to wire
  /// up the platform-side permission requester.
  static const _locationPermissionChannel =
      MethodChannel('biblepresenter/cast_permissions');

  Future<bool> _ensureAndroidLocationPermission() async {
    try {
      final status = await _locationPermissionChannel
          .invokeMethod<String>('checkLocationPermission');
      if (status == 'granted') return true;
      final result = await _locationPermissionChannel
          .invokeMethod<String>('requestLocationPermission');
      return result == 'granted';
    } on PlatformException {
      // If the native side hasn't been implemented yet, fall through
      // and let the discovery attempt run anyway. Worst case, the user
      // gets an empty device list rather than a hard error.
      return true;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Stop ongoing device discovery.
  Future<void> stopDiscovery() async {
    try {
      await _hostApi.stopDiscovery();
      _isDiscovering = false;
      _safeNotify();
    } catch (e) {
      _lastError = 'stopDiscovery failed: $e';
      _safeNotify();
    }
  }

  /// Connect to a specific cast device by [deviceId].
  Future<void> connectToDevice(String deviceId) async {
    try {
      _isConnecting = true;
      _connectedDeviceName = 'Connecting...';
      _lastError = '';
      _safeNotify();

      await _hostApi.connectToDevice(deviceId);
      // The actual connection confirmation comes via onConnected callback.
    } catch (e) {
      _isConnecting = false;
      _lastError = 'connectToDevice failed: $e';
      _safeNotify();
    }
  }

  /// Disconnect from the currently connected cast device.
  Future<void> disconnect() async {
    try {
      await _hostApi.disconnect();
      // Confirmation comes via onDisconnected callback.
      _lastError = '';
    } catch (e) {
      _lastError = 'disconnect failed: $e';
      _safeNotify();
    }
  }

  /// Load a media URL on the connected cast device.
  ///
  /// [mediaUrl] – the URL of the content to play.
  /// [title] – optional display title for the Now Playing view.
  /// [contentType] – MIME type, e.g. "video/mp4", "audio/mpeg".
  Future<void> loadMedia({
    required String mediaUrl,
    required String title,
    String contentType = 'video/mp4',
  }) async {
    try {
      await _hostApi.loadMedia(
        mediaUrl: mediaUrl,
        title: title,
        contentType: contentType,
      );
      _lastError = '';
    } catch (e) {
      _lastError = 'loadMedia failed: $e';
      _safeNotify();
    }
  }

  /// Resume playback on the cast device.
  Future<void> play() async {
    try {
      await _hostApi.play();
    } catch (e) {
      _lastError = 'play failed: $e';
      _safeNotify();
    }
  }

  /// Pause playback on the cast device.
  Future<void> pause() async {
    try {
      await _hostApi.pause();
    } catch (e) {
      _lastError = 'pause failed: $e';
      _safeNotify();
    }
  }

  /// Seek to a specific position in the current media.
  Future<void> seekTo(double positionSeconds) async {
    try {
      await _hostApi.seekTo(positionSeconds);
    } catch (e) {
      _lastError = 'seekTo failed: $e';
      _safeNotify();
    }
  }

  /// Set the playback volume on the cast device (0.0 – 1.0).
  Future<void> setVolume(double volume) async {
    try {
      await _hostApi.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      _lastError = 'setVolume failed: $e';
      _safeNotify();
    }
  }

  /// On iOS: show the native AirPlay route picker.
  /// On Android: no-op (use discovery + connectToDevice instead).
  Future<void> showAirPlayPicker() async {
    try {
      await _hostApi.showAirPlayPicker();
    } catch (e) {
      _lastError = 'showAirPlayPicker failed: $e';
      _safeNotify();
    }
  }

  /// Check if a device is currently connected (returns device ID or '').
  Future<String> getConnectedDeviceId() async {
    try {
      return await _hostApi.getConnectedDeviceId();
    } catch (e) {
      _lastError = 'getConnectedDeviceId failed: $e';
      _safeNotify();
      return '';
    }
  }

  // ────────────────────────────────────────────────────────────
  // Flutter API implementation (Native → Flutter callbacks)
  // ────────────────────────────────────────────────────────────

  @override
  void onDeviceDiscovered(CastDevice device) {
    // Guard against null/empty fields that occasionally arrive from native
    // resolve failures (e.g. service resolved with no TXT records).
    final safeId = device.deviceId.isNotEmpty ? device.deviceId : 'unknown_${DateTime.now().microsecondsSinceEpoch}';
    final safeName = device.name.isNotEmpty ? device.name : 'Unknown Device';
    final safePlatform = device.platform.isNotEmpty ? device.platform : 'chromecast';
    _discoveredDevices[safeId] = CastDevice(
      deviceId: safeId,
      name: safeName,
      platform: safePlatform,
    );
    _safeNotify();
  }

  @override
  void onDeviceLost(String deviceId) {
    _discoveredDevices.remove(deviceId);
    _safeNotify();
  }

  @override
  void onPlayerStateChanged(CastPlayerState state) {
    // Sanitize NaN/Inf values that can come from native during buffering.
    final safePosition = state.position.isFinite ? state.position : 0.0;
    final safeDuration = state.duration.isFinite ? state.duration : 0.0;
    final safeVolume = state.volume.isFinite ? state.volume.clamp(0.0, 1.0) : 1.0;
    _playerState = CastPlayerState(
      state: state.state.isNotEmpty ? state.state : 'idle',
      position: safePosition,
      duration: safeDuration,
      volume: safeVolume,
      mediaTitle: state.mediaTitle,
    );
    _safeNotify();
  }

  @override
  void onConnected(String deviceId) {
    _isConnected = true;
    _isConnecting = false;
    _connectedDeviceId = deviceId;
    // Look up the human-readable name from discovered devices.
    // Fall back to a placeholder if discovery raced with connection.
    final discovered = _discoveredDevices[deviceId];
    _connectedDeviceName = (discovered != null && discovered.name.isNotEmpty)
        ? discovered.name
        : 'Connected TV';
    _lastError = '';
    _safeNotify();
  }

  @override
  void onDisconnected() {
    _isConnected = false;
    _isConnecting = false;
    _connectedDeviceId = '';
    _connectedDeviceName = '';
    _playerState = CastPlayerState(
      state: 'idle',
      position: 0,
      duration: 0,
      volume: 1.0,
      mediaTitle: '',
    );
    _safeNotify();
  }

  @override
  void onError(String errorMessage) {
    _isConnecting = false;
    _lastError = errorMessage;
    _safeNotify();
  }

  // ────────────────────────────────────────────────────────────
  // Convenience helpers
  // ────────────────────────────────────────────────────────────

  /// Toggle play / pause.
  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Convenience: cast the TV URL (the local server URL) to a Chromecast.
  /// This opens the BiblePresenter TV page on the big screen via
  /// the Cast RemoteMediaPlayer, loading it as a web page.
  Future<void> castTvUrl(String tvUrl) async {
    if (!_isConnected) return;
    await loadMedia(
      mediaUrl: tvUrl,
      title: 'BiblePresenter',
      contentType: 'text/html',
    );
  }

  /// Full teardown: disconnect, stop discovery, clear state.
  Future<void> disposeAll() async {
    // Mark disposed FIRST so any in-flight native callbacks become no-ops.
    _disposed = true;
    try {
      await disconnect();
    } catch (_) {}
    try {
      await stopDiscovery();
    } catch (_) {}
    _discoveredDevices.clear();
    _isConnected = false;
    _connectedDeviceId = '';
    _connectedDeviceName = '';
    _isDiscovering = false;
    _lastError = '';
    _playerState = CastPlayerState(
      state: 'idle',
      position: 0,
      duration: 0,
      volume: 1.0,
      mediaTitle: '',
    );
    // _safeNotify is now a no-op since _disposed is true, but call it
    // for symmetry with the rest of the API.
    _safeNotify();
  }
}
