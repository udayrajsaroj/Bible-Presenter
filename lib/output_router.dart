import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import 'dlna_service.dart';
import 'slide_renderer.dart';

/// OutputRouter (plan 4.2, phase D4) — the fan-out at the existing choke
/// point. Every cast action calls _emit(); the router rides along:
///
///   Browser Connect TV attached → _emit pushes the socket event (unchanged)
///   DLNA TV attached           → additionally render the state to a
///                                full-HD PNG and push the media URI to the
///                                renderer (SetAVTransportURI + Play)
///
/// Both channels may run simultaneously — they are independent consumers of
/// one content state. Verse and song changes pass through a 500 ms debounce
/// so fast tapping does not flood the TV with image downloads (risk R1); the
/// likely next state is pre-rendered in the background so the cached PNG can
/// be published without a capture round-trip.
class OutputRouter {
  OutputRouter._();
  static final OutputRouter instance = OutputRouter._();

  static const _debounceDuration = Duration(milliseconds: 500);

  Timer? _debounce;
  Map<String, dynamic>? _pending;
  BuildContext? _pendingContext;

  // Pre-render cache: state key → PNG bytes (small LRU).
  static const _cacheMax = 4;
  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  final List<String> _cacheOrder = <String>[];

  /// Called from the controller's _emit() for every cast action. Media
  /// events that never travel over DLNA (YouTube) and TV→phone reports are
  /// ignored here.
  Future<void> route({
    required String event,
    required Map<String, dynamic> data,
    required BuildContext context,
    Map<String, dynamic>? currentState,
  }) async {
    final dlna = DlnaService.instance;
    if (!dlna.isConnected) return;

    switch (event) {
      case 'cast-verse':
      case 'cast-slide':
      case 'cast-song':
      case 'update-background':
        _debounceRender(_stateFor(event, data, currentState), context);
        break;

      case 'cast-logo':
        await _renderAndPush(
            _stateFor(event, data, currentState), context);
        break;

      case 'cast-blackout':
        await _renderBlackout(context);
        break;

      case 'cast-welcome':
        await _renderAndPush(
            _stateFor(event, data, currentState), context);
        break;

      case 'cast-pdf':
        await _renderPdfPage(
            localPath: data['_localPdfPath'] as String?,
            page: (data['currentPage'] as int? ?? 1),
            context: context);
        break;

      case 'pdf-page':
        await _renderPdfPage(
            localPath: data['_localPdfPath'] as String?,
            page: (data['page'] as int? ?? 1),
            context: context);
        break;

      case 'cast-pptx':
        // No phone-side PPTX renderer exists; PDF pages render on the phone,
        // PPTX must go through Browser Connect (plan D4 scope).
        break;

      case 'cast-video':
        // DLNA video is the TV's home turf: native player, hardware decode,
        // and the TV remote can pause/seek (plan 6.4).
        final url = _absoluteUrl(data['url'] as String? ?? '');
        if (url.isNotEmpty) {
          await dlna.castVideo(url, title: data['title'] as String? ?? 'Video');
        }
        break;

      case 'video-control':
        if (data['action'] == 'pause') {
          await dlna.pause();
        } else if (data['action'] == 'play') {
          await dlna.resume();
        }
        break;

      case 'video-seek':
        final s = data['seconds'];
        if (s is num) await dlna.seek(s.round());
        break;

      case 'video-stop':
      case 'clear-screen':
        _cancelPending();
        await dlna.stop();
        break;

      // YouTube (Feature 3) never touches DLNA — no direct stream URL
      // exists to hand a renderer (plan 7.1).
      case 'cast-youtube':
      case 'yt-play':
      case 'yt-pause':
      case 'yt-seek':
      case 'yt-volume':
      case 'yt-unmute':
      case 'video-ended':
      case 'video-progress':
        break;
    }
  }

  // ── State construction ──

  /// Builds the slide-renderer state for a cast event. Verse/slide/song
  /// events carry the full content; background updates re-render the current
  /// state with the new background.
  Map<String, dynamic> _stateFor(String event, Map<String, dynamic> data,
      Map<String, dynamic>? currentState) {
    switch (event) {
      case 'update-background':
        final base =
            Map<String, dynamic>.from(currentState ?? {'type': 'idle'});
        base['background'] = data.isEmpty ? null : data;
        return base;
      case 'cast-verse':
        return {'type': 'verse', 'content': data};
      case 'cast-slide':
        return {'type': 'slide', 'content': data};
      case 'cast-song':
        return {'type': 'song', 'content': data};
      case 'cast-logo':
        return {'type': 'logo', 'content': data};
      case 'cast-welcome':
        return {'type': 'welcome', 'content': data};
    }
    return {'type': 'idle'};
  }

  // ── Debounced rendering ──

  void _debounceRender(Map<String, dynamic> state, BuildContext context) {
    _pending = state;
    _pendingContext = context;
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () async {
      final s = _pending;
      final ctx = _pendingContext;
      _pending = null;
      _pendingContext = null;
      if (s != null && ctx != null && ctx.mounted) {
        await _renderAndPush(s, ctx);
      }
    });
  }

  void _cancelPending() {
    _debounce?.cancel();
    _pending = null;
    _pendingContext = null;
  }

  // ── Render + publish + push ──

  Future<void> _renderAndPush(
      Map<String, dynamic> state, BuildContext context) async {
    if (!context.mounted) return;
    final key = stateKey(state);
    Uint8List? png = _cache[key];
    if (png != null) {
      _touch(key);
    } else {
      try {
        png = await SlideRenderer.capture(state, context: context);
      } catch (_) {
        return;
      }
      if (png == null) return;
      _store(key, png);
    }
    final url = await SlideRenderer.publish(png);
    if (url == null) return;
    await DlnaService.instance.castImage(url);
  }

  /// Blackout on a DLNA TV: render a solid full-HD black PNG and publish it
  /// as a still image — the renderer shows black until the next cast or stop.
  Future<void> _renderBlackout(BuildContext context) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawPaint(ui.Paint()..color = const ui.Color(0xFF000000));
      final picture = recorder.endRecording();
      final img = await picture.toImage(1920, 1080);
      final byteData =
          await img.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      img.dispose();
      final png = byteData?.buffer.asUint8List();
      if (png == null) return;
      final url = await SlideRenderer.publish(png);
      if (url == null) return;
      await DlnaService.instance.castImage(url, title: 'Blackout');
    } catch (_) {
      // Blackout is best-effort; the phone UI still shows OFF AIR state.
    }
  }

  /// Pre-renders the likely next state (next verse, next slide, next stanza,
  /// next PDF page) so the DLNA switch is a publish-and-play instead of a
  /// full capture (plan 4.3 latency lever).
  Future<void> preRender(
      Map<String, dynamic> nextState, BuildContext context) async {
    final dlna = DlnaService.instance;
    if (!dlna.isConnected) return;
    final key = stateKey(nextState);
    if (_cache.containsKey(key)) return;
    try {
      final png = await SlideRenderer.capture(nextState, context: context);
      if (png != null) _store(key, png);
    } catch (_) {
      // Pre-rendering is best-effort; failures fall back to live capture.
    }
  }

  // ── PDF pages on the phone (pdfx, Appendix A) ──

  Future<void> _renderPdfPage({
    required String? localPath,
    required int page,
    required BuildContext context,
  }) async {
    final png = await _pdfPng(localPath, page);
    if (png == null) return;
    final url = await SlideRenderer.publish(png);
    if (url == null) return;
    await DlnaService.instance.castImage(url, title: 'Page $page');
  }

  /// Pre-renders the next PDF page into the cache (plan D4).
  Future<void> preRenderPdfPage(
      String? localPath, int page, BuildContext context) async {
    if (localPath == null || localPath.isEmpty) return;
    if (!DlnaService.instance.isConnected) return;
    if (_cache.containsKey('pdf:$localPath:$page')) return;
    final png = await _pdfPng(localPath, page);
    if (png != null) _store('pdf:$localPath:$page', png);
  }

  Future<Uint8List?> _pdfPng(String? localPath, int page) async {
    if (localPath == null || localPath.isEmpty) {
      // No local copy (files uploaded in an earlier session): Browser
      // Connect is the document path in that case.
      return null;
    }
    final key = 'pdf:$localPath:$page';
    Uint8List? png = _cache[key];
    if (png != null) {
      _touch(key);
      return png;
    }
    try {
      final doc = await pdfx.PdfDocument.openFile(localPath);
      if (page < 1 || page > doc.pagesCount) {
        await doc.close();
        return null;
      }
      final pdfPage = await doc.getPage(page);
      final image = await pdfPage.render(
        width: pdfPage.width,
        height: pdfPage.height,
        format: pdfx.PdfPageImageFormat.png,
        backgroundColor: '#000000',
      );
      await doc.close();
      png = image?.bytes;
    } catch (_) {
      return null;
    }
    return png;
  }

  // ── Cache helpers ──

  String stateKey(Map<String, dynamic> state) => jsonEncode(state);

  void _store(String key, Uint8List png) {
    if (_cache.containsKey(key)) return;
    _cache[key] = png;
    _cacheOrder.add(key);
    while (_cacheOrder.length > _cacheMax) {
      final evict = _cacheOrder.removeAt(0);
      _cache.remove(evict);
    }
  }

  void _touch(String key) {
    _cacheOrder.remove(key);
    _cacheOrder.add(key);
  }

  String _absoluteUrl(String url) {
    if (url.startsWith('http')) return url;
    final ip = (SlideRenderer.deviceIp.isEmpty || SlideRenderer.deviceIp == '...')
        ? '127.0.0.1'
        : SlideRenderer.deviceIp;
    return 'http://$ip:${SlideRenderer.serverPort}$url';
  }
}
