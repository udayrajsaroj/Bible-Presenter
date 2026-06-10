import 'package:pigeon/pigeon.dart';

// ══════════════════════════════════════════════════════════════
// PIGEON API SCHEMA for Google Cast (Chromecast) & Apple AirPlay
// ══════════════════════════════════════════════════════════════
//
// Generate Dart output:
//   dart run pigeon --input pigeons/cast_api.dart \
//     --dart_out lib/services/cast_api.g.dart \
//     --kotlin_out android/app/src/main/kotlin/com/biblepresenter/CastApi.g.kt \
//     --kotlin_package com.biblepresenter \
//     --swift_out ios/Runner/CastApi.g.swift
//
// ══════════════════════════════════════════════════════════════

// ── Data Models ──

/// Represents a discovered cast device (Chromecast / AirPlay).
class CastDevice {
  /// Unique identifier for the device (session ID on Android, UID on iOS).
  String deviceId;

  /// Human-readable name shown in the picker (e.g. "Living Room TV").
  String name;

  /// Platform that discovered this device: "chromecast" or "airplay".
  String platform;

  CastDevice({
    required this.deviceId,
    required this.name,
    required this.platform,
  });
}

/// Represents the current player state on the cast device.
class CastPlayerState {
  /// "idle" | "playing" | "paused" | "buffering" | "error"
  String state;

  /// Current playback position in seconds.
  double position;

  /// Total duration in seconds (0 if unknown / live).
  double duration;

  /// Volume level 0.0 – 1.0.
  double volume;

  /// Display title of the currently loaded media.
  String mediaTitle;

  CastPlayerState({
    required this.state,
    required this.position,
    required this.duration,
    required this.volume,
    required this.mediaTitle,
  });
}

// ── Host API (Flutter → Native) ──
// Flutter calls these methods; native side implements them.

@HostApi()
abstract class CastHostApi {
  /// Begin mDNS / NSD discovery for Chromecast devices (Android).
  /// On iOS this is a no-op (AVRouteDetector starts automatically).
  void startDiscovery();

  /// Stop ongoing device discovery.
  void stopDiscovery();

  /// Connect to a specific cast device identified by [deviceId].
  void connectToDevice(String deviceId);

  /// Disconnect from the currently connected cast device.
  void disconnect();

  /// Load a media URL on the connected cast device.
  /// [mediaUrl] – the URL of the content to play.
  /// [title] – optional display title.
  /// [contentType] – MIME type, e.g. "video/mp4", "audio/mpeg", "application/pdf".
  void loadMedia({
    required String mediaUrl,
    required String title,
    required String contentType,
  });

  /// Playback controls.
  void play();
  void pause();
  void seekTo(double positionSeconds);

  /// Set volume on the cast device (0.0 – 1.0).
  void setVolume(double volume);

  /// On iOS: show the native AirPlay picker (AVRoutePickerView).
  /// On Android: no-op (use startDiscovery + connectToDevice instead).
  void showAirPlayPicker();

  /// Check if a cast device is currently connected.
  /// Returns the device ID if connected, empty string otherwise.
  String getConnectedDeviceId();
}

// ── Flutter API (Native → Flutter) ──
// Native side calls these methods; Flutter implements the handler.

@FlutterApi()
abstract class CastFlutterApi {
  /// Called when a new cast device is discovered.
  void onDeviceDiscovered(CastDevice device);

  /// Called when a device disappears from discovery results.
  void onDeviceLost(String deviceId);

  /// Called when the player state changes on the cast device.
  void onPlayerStateChanged(CastPlayerState state);

  /// Called when a connection is established to a cast device.
  void onConnected(String deviceId);

  /// Called when the connection to a cast device is lost / ended.
  void onDisconnected();

  /// Called when an error occurs in the native cast layer.
  void onError(String errorMessage);
}
