import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_cast_dlna/media_cast_dlna.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool get isConnected => connectedDevice != null && !rendererOffline;

  String? get connectedName => connectedDevice?.friendlyName;

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
  Future<void> connect(DlnaDevice device) async {
    connectedDevice = device;
    rendererOffline = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dlna_last_udn', device.udn.value);
    await prefs.setString('dlna_last_name', device.friendlyName);
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
      if (fresh != null &&
          fresh.deviceType.contains('MediaRenderer')) {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dlna_last_udn');
    await prefs.remove('dlna_last_name');
    notifyListeners();
  }

  // ── Casting ──

  /// Sends a slide image to the TV: SetAVTransportURI with photo item
  /// metadata (object.item.imageItem.photo — best-supported media class
  /// across TV brands) followed by Play.
  Future<bool> castImage(String url, {String title = 'BiblePresenter'}) async {
    final device = connectedDevice;
    if (device == null || rendererOffline) return false;
    try {
      await _api.setMediaUri(
        device.udn,
        Url(value: url),
        ImageMetadata(title: title, upnpClass: 'object.item.imageItem.photo'),
      );
      await _api.play(device.udn);
      return true;
    } catch (e) {
      debugPrint('[Dlna] castImage failed: $e');
      _markOffline();
      return false;
    }
  }

  /// Sends a local video file; the TV's native player takes over playback,
  /// hardware decoding and its own remote's pause/seek.
  Future<bool> castVideo(String url, {String title = 'Video'}) async {
    final device = connectedDevice;
    if (device == null || rendererOffline) return false;
    try {
      await _api.setMediaUri(
        device.udn,
        Url(value: url),
        VideoMetadata(title: title, upnpClass: 'object.item.videoItem'),
      );
      await _api.play(device.udn);
      return true;
    } catch (e) {
      debugPrint('[Dlna] castVideo failed: $e');
      _markOffline();
      return false;
    }
  }

  Future<void> pause() async {
    if (!_canControl) return;
    try {
      await _api.pause(connectedDevice!.udn);
    } catch (e) {
      debugPrint('[Dlna] pause failed: $e');
    }
  }

  Future<void> resume() async {
    if (!_canControl) return;
    try {
      await _api.play(connectedDevice!.udn);
    } catch (e) {
      debugPrint('[Dlna] resume failed: $e');
    }
  }

  /// DLNA Stop: returns the TV to idle. Also maps onto clear-screen.
  Future<void> stop() async {
    if (!_canControl) return;
    try {
      await _api.stop(connectedDevice!.udn);
    } catch (e) {
      debugPrint('[Dlna] stop failed: $e');
    }
  }

  bool get _canControl =>
      isAndroid && connectedDevice != null && !rendererOffline;

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
