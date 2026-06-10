import 'dart:async';
import 'package:flutter/foundation.dart';
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

  // ── Discovered devices ──
  final Map<String, CastDevice> _discoveredDevices = {};

  /// Unmodifiable list of currently discovered cast devices.
  List<CastDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices.values);

  // ── Connection state ──
  bool _isConnected = false;

  /// Whether we are currently connected to a cast device.
  bool get isConnected => _isConnected;

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
  Future<void> startDiscovery() async {
    try {
      await _hostApi.startDiscovery();
      _isDiscovering = true;
      _lastError = '';
      notifyListeners();
    } catch (e) {
      _lastError = 'startDiscovery failed: $e';
      notifyListeners();
    }
  }

  /// Stop ongoing device discovery.
  Future<void> stopDiscovery() async {
    try {
      await _hostApi.stopDiscovery();
      _isDiscovering = false;
      notifyListeners();
    } catch (e) {
      _lastError = 'stopDiscovery failed: $e';
      notifyListeners();
    }
  }

  /// Connect to a specific cast device by [deviceId].
  Future<void> connectToDevice(String deviceId) async {
    try {
      await _hostApi.connectToDevice(deviceId);
      // The actual connection confirmation comes via onConnected callback.
      _lastError = '';
    } catch (e) {
      _lastError = 'connectToDevice failed: $e';
      notifyListeners();
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
      notifyListeners();
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
      notifyListeners();
    }
  }

  /// Resume playback on the cast device.
  Future<void> play() async {
    try {
      await _hostApi.play();
    } catch (e) {
      _lastError = 'play failed: $e';
      notifyListeners();
    }
  }

  /// Pause playback on the cast device.
  Future<void> pause() async {
    try {
      await _hostApi.pause();
    } catch (e) {
      _lastError = 'pause failed: $e';
      notifyListeners();
    }
  }

  /// Seek to a specific position in the current media.
  Future<void> seekTo(double positionSeconds) async {
    try {
      await _hostApi.seekTo(positionSeconds);
    } catch (e) {
      _lastError = 'seekTo failed: $e';
      notifyListeners();
    }
  }

  /// Set the playback volume on the cast device (0.0 – 1.0).
  Future<void> setVolume(double volume) async {
    try {
      await _hostApi.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      _lastError = 'setVolume failed: $e';
      notifyListeners();
    }
  }

  /// On iOS: show the native AirPlay route picker.
  /// On Android: no-op (use discovery + connectToDevice instead).
  Future<void> showAirPlayPicker() async {
    try {
      await _hostApi.showAirPlayPicker();
    } catch (e) {
      _lastError = 'showAirPlayPicker failed: $e';
      notifyListeners();
    }
  }

  /// Check if a device is currently connected (returns device ID or '').
  Future<String> getConnectedDeviceId() async {
    try {
      return await _hostApi.getConnectedDeviceId();
    } catch (e) {
      _lastError = 'getConnectedDeviceId failed: $e';
      notifyListeners();
      return '';
    }
  }

  // ────────────────────────────────────────────────────────────
  // Flutter API implementation (Native → Flutter callbacks)
  // ────────────────────────────────────────────────────────────

  @override
  void onDeviceDiscovered(CastDevice device) {
    _discoveredDevices[device.deviceId] = device;
    notifyListeners();
  }

  @override
  void onDeviceLost(String deviceId) {
    _discoveredDevices.remove(deviceId);
    notifyListeners();
  }

  @override
  void onPlayerStateChanged(CastPlayerState state) {
    _playerState = state;
    notifyListeners();
  }

  @override
  void onConnected(String deviceId) {
    _isConnected = true;
    _connectedDeviceId = deviceId;
    // Look up the human-readable name from discovered devices.
    _connectedDeviceName =
        _discoveredDevices[deviceId]?.name ?? deviceId;
    _lastError = '';
    notifyListeners();
  }

  @override
  void onDisconnected() {
    _isConnected = false;
    _connectedDeviceId = '';
    _connectedDeviceName = '';
    _playerState = CastPlayerState(
      state: 'idle',
      position: 0,
      duration: 0,
      volume: 1.0,
      mediaTitle: '',
    );
    notifyListeners();
  }

  @override
  void onError(String errorMessage) {
    _lastError = errorMessage;
    notifyListeners();
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
    await disconnect();
    await stopDiscovery();
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
    notifyListeners();
  }
}
