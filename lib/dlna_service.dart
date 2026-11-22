import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_cast_dlna/media_cast_dlna.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Active media type loaded on the DLNA renderer.
enum DlnaMediaType {
  none,
  slide,
  video,
  image,
}

/// DLNA "TV Direct" service (Phase D2).
///
/// The only file in the app that talks to the media_cast_dlna package: it
/// initializes the jUPnP stack, runs bounded SSDP discovery windows, filters
/// MediaRenderer devices (TVs that can be *commanded*, unlike MediaServer
/// devices which only *share* content), and issues the two-call AVTransport
/// sequence (SetAVTransportURI + Play) that puts a slide or video on screen.
///
/// Android-only: on iOS the multicast entitlement Apple requires for SSDP is
/// a non-starter for App Store review, so every entry point no-ops elsewhere.
class DlnaService extends ChangeNotifier {
  DlnaService._();
  static final DlnaService instance = DlnaService._();

  final MediaCastDlnaApi _api = MediaCastDlnaApi();
  MediaCastDlnaDiscoveryEvents? _discoveryEvents;

  /// Discovered MediaRenderer devices from the most recent scan.
  final List<DlnaDevice> devices = [];

  /// The currently connected TV, null when idle.
  DlnaDevice? connectedDevice;

  /// Active media type on the connected renderer.
  DlnaMediaType currentMediaType = DlnaMediaType.none;

  /// Active media URI loaded on the connected renderer.
  String? currentMediaUri;

  /// True when the renderer is in an active playback session.
  bool isSessionActive = false;

  bool _initialized = false;
  bool _scanning = false;
  StreamSubscription? _foundSub;
  StreamSubscription? _lostSub;
  StreamSubscription? _offlineSub;

  /// Set when the connected TV goes offline (renderer-offline event) so the
  /// UI can show the disconnect banner.
  bool rendererOffline = false;

  /// Fired when the connected renderer stops answering (TV powered off,
  /// Wi-Fi drop). The remote screen listens and shows the banner.
  final StreamController<DlnaDevice?> _onDisconnected =
      StreamController<DlnaDevice?>.broadcast();
  Stream<DlnaDevice?> get onDisconnected => _onDisconnected.stream;

  bool get isAndroid => Platform.isAndroid;
  bool get isScanning => _scanning;
  bool get isConnected => connectedDevice != null;

  String? get connectedName => connectedDevice?.friendlyName;

  // ── Logging ──

  static void _log(String message) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    debugPrint('[DLNA $timeStr] $message');
  }

  static void _logCmd(String cmd, String details) {
    _log('>>> COMMAND: $cmd | $details');
  }

  static void _logResult(String cmd, bool success,
      {int? durationMs, Object? error}) {
    if (success) {
      _log('<<< SUCCESS: $cmd${durationMs != null ? " (${durationMs}ms)" : ""}');
    } else {
      _log('<<< FAILED: $cmd${durationMs != null ? " (${durationMs}ms)" : ""}${error != null ? " | Error: $error" : ""}');
    }
  }

  // ── Lifecycle ──

  /// Boots the UPnP stack once. Safe to call repeatedly; no-ops off Android.
  Future<void> start() async {
    if (!isAndroid || _initialized) return;
    try {
      await _api.initializeUpnpService();
      _initialized = true;

      final events = MediaCastDlnaDiscoveryEvents();
      _discoveryEvents = events;
      _foundSub = events.onDeviceFound.listen(_handleDeviceFound);
      _lostSub = events.onDeviceLost.listen(_handleDeviceLost);
      _offlineSub = events.onRendererOffline.listen(_handleRendererOffline);
    } catch (e) {
      debugPrint('[Dlna] init failed: $e');
    }
  }

  /// Runs one bounded (~10 s) SSDP discovery window. Called at app boot (to
  /// warm the cache for the reconnect ping) and when the cast dialog opens.
  /// Battery-safe per R8: scanning only happens inside these windows.
  Future<void> scan({Duration timeout = const Duration(seconds: 10)}) async {
    if (!isAndroid || !_initialized || _scanning) return;
    _scanning = true;
    devices.clear();
    notifyListeners();
    try {
      await _api.startDiscovery(
        DiscoveryOptions(
          timeout: DiscoveryTimeout(seconds: timeout.inSeconds),
          searchTarget: SearchTarget(target: 'upnp:rootdevice'),
        ),
      );
    } catch (e) {
      debugPrint('[Dlna] discovery failed: $e');
    }
    // Keep the flag on until stopDiscovery — onDeviceFound answers arrive
    // asynchronously during the window; stop() flips _scanning off.
  }

  /// Ends the current discovery window early (e.g. sheet closed).
  Future<void> stopScan() async {
    if (!_scanning) return;
    _scanning = false;
    try {
      await _api.stopDiscovery();
    } catch (_) {}
    notifyListeners();
  }

  void _handleDeviceFound(DlnaDevice device) {
    if (!isMediaRenderer(device)) return;
    final i = devices.indexWhere((d) => d.udn.value == device.udn.value);
    if (i >= 0) {
      devices[i] = device;
    } else {
      devices.add(device);
    }
    // Auto-clear offline status if our connected TV was rediscovered
    if (connectedDevice?.udn.value == device.udn.value && rendererOffline) {
      connectedDevice = device;
      rendererOffline = false;
    }
    notifyListeners();
  }

  /// Only MediaRenderer devices can be *commanded* to play content.
  /// MediaServer devices (e.g. BubbleUPnP Server, NAS boxes) only *share*
  /// content and must be filtered out of the picker.
  static bool isMediaRenderer(DlnaDevice device) =>
      device.deviceType.contains('MediaRenderer');

  void _handleDeviceLost(DeviceUdn udn) {
    // DeviceUdn is a plain Pigeon data class without ==, compare by value.
    devices.removeWhere((d) => d.udn.value == udn.value);
    if (connectedDevice?.udn.value == udn.value) {
      _markOffline();
    }
    notifyListeners();
  }

  void _handleRendererOffline(DeviceUdn udn) {
    if (connectedDevice?.udn.value == udn.value) {
      _markOffline();
      notifyListeners();
    }
    devices.removeWhere((d) => d.udn.value == udn.value);
    notifyListeners();
  }

  void _markOffline() {
    if (rendererOffline) return;
    rendererOffline = true;
    _onDisconnected.add(connectedDevice);
    notifyListeners();
  }

  // ── Connection ──

  /// Selects a TV, remembers it in SharedPreferences for the one-tap
  /// reconnect banner, and clears the offline flag.
  /// Connection is established ONCE and maintained throughout the session.
  Future<void> connect(DlnaDevice device) async {
    connectedDevice = device;
    rendererOffline = false;
    isSessionActive = false;
    currentMediaUri = null;
    currentMediaType = DlnaMediaType.none;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dlna_last_udn', device.udn.value);
    await prefs.setString('dlna_last_name', device.friendlyName);

    _log('[SESSION] Connected to TV: "${device.friendlyName}" (${device.udn.value}). Connection established once.');
    notifyListeners();
  }

  /// Returns the remembered TV (UDN + friendly name), or null. Used by the
  /// reconnect banner; the caller decides whether to ping before offering.
  static Future<({String udn, String name})?> lastTv() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final udn = prefs.getString('dlna_last_udn');
      final name = prefs.getString('dlna_last_name');
      if (udn == null || udn.isEmpty) return null;
      return (udn: udn, name: name ?? 'TV');
    } catch (_) {
      return null;
    }
  }

  /// True when the stored TV answers — cheap warm-up ping used by the
  /// reconnect banner instead of a full 10 s scan.
  Future<DlnaDevice?> pingStored(String udn) async {
    if (!isAndroid || !_initialized) return null;
    try {
      if (!await _api.isDeviceOnline(DeviceUdn(value: udn))) return null;
      final fresh = await _api.refreshDevice(DeviceUdn(value: udn));
      if (fresh != null && fresh.deviceType.contains('MediaRenderer')) {
        return fresh;
      }
    } catch (e) {
      debugPrint('[Dlna] ping $udn failed: $e');
    }
    return null;
  }

  Future<void> disconnect() async {
    if (connectedDevice != null && !rendererOffline) {
      await stop().catchError((_) {});
    }
    connectedDevice = null;
    rendererOffline = false;
    isSessionActive = false;
    currentMediaUri = null;
    currentMediaType = DlnaMediaType.none;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dlna_last_udn');
    await prefs.remove('dlna_last_name');

    _log('[SESSION] Disconnected from TV. DLNA session cleared.');
    notifyListeners();
  }

  // ── Casting ──

  int _castImageGeneration = 0;

  /// Sends a presentation slide to the TV.
  ///
  /// Reuses existing connection & session:
  /// When a slide session is already established on the TV with the same media
  /// resource URI, this avoids repeatedly sending SetAVTransportURI and Play.
  /// Repeated SetAVTransportURI calls cause Google TV / Toshiba TV to reset its
  /// media session and display "A device is connected to your TV" on every slide
  /// change.
  ///
  /// For in-session slide changes, the HTTP server updates the slide bytes at the
  /// existing URI in memory, and this method updates content using the existing connection.
  Future<bool> castSlide(
    String url, {
    String title = 'BiblePresenter',
    bool forceNewSession = false,
  }) async {
    var device = connectedDevice;
    if (device == null) {
      _log('castSlide skipped: No TV connected');
      return false;
    }

    final int generation = ++_castImageGeneration;
    final bool isSameResource = isConnected &&
        isSessionActive &&
        currentMediaType == DlnaMediaType.slide &&
        currentMediaUri == url;

    _log('[SESSION] Device: "${device.friendlyName}" | Active: $isSessionActive | Media: $currentMediaType | URI: $url | SameResource: $isSameResource');

    if (!isSameResource || forceNewSession) {
      // ── Establish New Media Session ──
      // Genuinely requires SetAVTransportURI + Play because the media resource or
      // media type has changed (e.g. initial slide, or coming from video).
      _log('Establishing NEW slide session with URI: $url (previous URI: $currentMediaUri)');

      final sw = Stopwatch()..start();
      try {
        _logCmd('SetAVTransportURI',
            'Device: "${device.friendlyName}", URI: "$url", Title: "$title", Class: "object.item.imageItem.photo"');
        await _api.setMediaUri(
          device.udn,
          Url(value: url),
          ImageMetadata(title: title, upnpClass: 'object.item.imageItem.photo'),
        );
        sw.stop();
        _logResult('SetAVTransportURI', true,
            durationMs: sw.elapsedMilliseconds);

        if (generation != _castImageGeneration) {
          _log('Session establishment superseded by generation $generation');
          return false;
        }

        sw.reset();
        sw.start();
        _logCmd('Play', 'Device: "${device.friendlyName}"');
        await _api.play(device.udn);
        sw.stop();
        _logResult('Play', true, durationMs: sw.elapsedMilliseconds);

        if (generation != _castImageGeneration) {
          return false;
        }

        currentMediaUri = url;
        currentMediaType = DlnaMediaType.slide;
        isSessionActive = true;
        if (rendererOffline) {
          rendererOffline = false;
          notifyListeners();
        }
        return true;
      } catch (e) {
        sw.stop();
        _logResult('SetAVTransportURI / Play', false,
            durationMs: sw.elapsedMilliseconds, error: e);
        _log('Failed to establish slide session: $e');
        return false;
      }
    } else {
      // ── In-Session Slide Change: Reuse Existing Connection ──
      // The slide image at $url has already been updated in the server's RAM cache and on disk.
      // Do NOT send SetAVTransportURI again — that is what triggers the Toshiba Google TV
      // "A device is connected to your TV" notification on every slide change!
      _log('In-session slide change. Reusing existing connection ($url). Skipping SetAVTransportURI.');

      // Issue a lightweight Play to prompt the renderer to reload the current URI,
      // but gracefully handle renderers that return "Transition not available" (already playing).
      final sw = Stopwatch()..start();
      try {
        _logCmd('Play (in-session refresh)', 'Device: "${device.friendlyName}"');
        await _api.play(device.udn);
        sw.stop();
        _logResult('Play (in-session refresh)', true,
            durationMs: sw.elapsedMilliseconds);
      } catch (e) {
        sw.stop();
        // UPnP 701 (Transition not available) or 501 is common when already in PLAYING state.
        _log('Play (in-session refresh) non-fatal response: $e (renderer may already be playing)');
      }

      if (rendererOffline) {
        rendererOffline = false;
        notifyListeners();
      }
      return true;
    }
  }

  /// Sends a standalone image to the TV: SetAVTransportURI with photo item
  /// metadata (object.item.imageItem.photo) followed by Play.
  Future<bool> castImage(String url, {String title = 'BiblePresenter'}) async {
    var device = connectedDevice;
    if (device == null) {
      _log('castImage skipped: No TV connected');
      return false;
    }

    final int generation = ++_castImageGeneration;
    final sw = Stopwatch()..start();
    try {
      _logCmd('SetAVTransportURI (Image)',
          'Device: "${device.friendlyName}", URI: "$url", Title: "$title"');
      await _api.setMediaUri(
        device.udn,
        Url(value: url),
        ImageMetadata(title: title, upnpClass: 'object.item.imageItem.photo'),
      );
      sw.stop();
      _logResult('SetAVTransportURI (Image)', true,
          durationMs: sw.elapsedMilliseconds);

      if (generation != _castImageGeneration) return false;

      sw.reset();
      sw.start();
      _logCmd('Play (Image)', 'Device: "${device.friendlyName}"');
      await _api.play(device.udn);
      sw.stop();
      _logResult('Play (Image)', true, durationMs: sw.elapsedMilliseconds);

      if (generation != _castImageGeneration) return false;

      currentMediaUri = url;
      currentMediaType = DlnaMediaType.image;
      isSessionActive = true;
      if (rendererOffline) {
        rendererOffline = false;
        notifyListeners();
      }
      return true;
    } catch (e) {
      sw.stop();
      _logResult('castImage', false,
          durationMs: sw.elapsedMilliseconds, error: e);
      return false;
    }
  }

  /// Sends a local video file; the TV's native player takes over playback,
  /// hardware decoding and its own remote's pause/seek.
  /// Uses 'object.item.videoItem.movie' UPnP class so renderers (such as Kodi
  /// and Smart TVs) route playback to their video rendering pipeline instead
  /// of falling back to audio-only.
  Future<bool> castVideo(String url, {String title = 'Video'}) async {
    var device = connectedDevice;
    if (device == null) {
      _log('castVideo skipped: No TV connected');
      return false;
    }

    final sw = Stopwatch()..start();
    try {
      _logCmd('SetAVTransportURI (Video)',
          'Device: "${device.friendlyName}", URI: "$url", Title: "$title", Class: "object.item.videoItem.movie"');
      await _api.setMediaUri(
        device.udn,
        Url(value: url),
        VideoMetadata(title: title, upnpClass: 'object.item.videoItem.movie'),
      );
      sw.stop();
      _logResult('SetAVTransportURI (Video)', true,
          durationMs: sw.elapsedMilliseconds);

      sw.reset();
      sw.start();
      _logCmd('Play (Video)', 'Device: "${device.friendlyName}"');
      await _api.play(device.udn);
      sw.stop();
      _logResult('Play (Video)', true, durationMs: sw.elapsedMilliseconds);

      currentMediaUri = url;
      currentMediaType = DlnaMediaType.video;
      isSessionActive = true;
      if (rendererOffline) {
        rendererOffline = false;
        notifyListeners();
      }
      return true;
    } catch (e) {
      sw.stop();
      _logResult('castVideo', false,
          durationMs: sw.elapsedMilliseconds, error: e);
      return false;
    }
  }

  /// Sends a YouTube link formatted for Kodi's official YouTube add-on
  /// (plugin.video.youtube) over DLNA/UPnP.
  Future<bool> castKodiYouTube(String videoId,
      {String title = 'YouTube'}) async {
    return castVideo(
      'plugin://plugin.video.youtube/play/?video_id=$videoId',
      title: title,
    );
  }

  Future<void> pause() async {
    if (!_canControl) return;
    final sw = Stopwatch()..start();
    try {
      _logCmd('Pause', 'Device: "${connectedDevice!.friendlyName}"');
      await _api.pause(connectedDevice!.udn);
      sw.stop();
      _logResult('Pause', true, durationMs: sw.elapsedMilliseconds);
    } catch (e) {
      sw.stop();
      _logResult('Pause', false,
          durationMs: sw.elapsedMilliseconds, error: e);
    }
  }

  Future<void> resume() async {
    if (!_canControl) return;
    final sw = Stopwatch()..start();
    try {
      _logCmd('Play (Resume)', 'Device: "${connectedDevice!.friendlyName}"');
      await _api.play(connectedDevice!.udn);
      sw.stop();
      _logResult('Play (Resume)', true, durationMs: sw.elapsedMilliseconds);
    } catch (e) {
      sw.stop();
      _logResult('Play (Resume)', false,
          durationMs: sw.elapsedMilliseconds, error: e);
    }
  }

  /// AVTransport Seek — used by the video remote in TV Direct mode (the
  /// TV's native player honors it; see plan 6.4).
  Future<void> seek(int seconds) async {
    if (!_canControl) return;
    final sw = Stopwatch()..start();
    try {
      _logCmd('Seek',
          'Device: "${connectedDevice!.friendlyName}", Position: ${seconds}s');
      await _api.seek(connectedDevice!.udn, TimePosition(seconds: seconds));
      sw.stop();
      _logResult('Seek', true, durationMs: sw.elapsedMilliseconds);
    } catch (e) {
      sw.stop();
      _logResult('Seek', false,
          durationMs: sw.elapsedMilliseconds, error: e);
    }
  }

  /// DLNA Stop: returns the TV to idle. Also maps onto clear-screen.
  Future<void> stop() async {
    if (!_canControl) return;
    final sw = Stopwatch()..start();
    try {
      _logCmd('Stop', 'Device: "${connectedDevice!.friendlyName}"');
      await _api.stop(connectedDevice!.udn);
      sw.stop();
      _logResult('Stop', true, durationMs: sw.elapsedMilliseconds);
    } catch (e) {
      sw.stop();
      _logResult('Stop', false,
          durationMs: sw.elapsedMilliseconds, error: e);
    } finally {
      isSessionActive = false;
      currentMediaUri = null;
      currentMediaType = DlnaMediaType.none;
    }
  }

  bool get _canControl => isAndroid && connectedDevice != null;

  @override
  void dispose() {
    _foundSub?.cancel();
    _lostSub?.cancel();
    _offlineSub?.cancel();
    _discoveryEvents?.dispose();
    _onDisconnected.close();
    super.dispose();
  }
}
