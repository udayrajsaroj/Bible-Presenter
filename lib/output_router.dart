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

  static const _debounceDuration = Duration(milliseconds: 200);

  Timer? _debounce;
  Map<String, dynamic>? _pending;
  BuildContext? _pendingContext;

  // Pre-render cache: state key → PNG/JPG bytes (small LRU).
  static const _cacheMax = 20;
  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  final List<String> _cacheOrder = <String>[];

  /// Public check for testing and diagnostics: whether a state has been pre-rendered.
  bool hasCached(Map<String, dynamic> state) => _cache.containsKey(stateKey(state));

  /// Public retriever for cached slide bytes.
  Uint8List? getCached(Map<String, dynamic> state) => _cache[stateKey(state)];

  /// Number of pre-rendered slides currently cached.
  int get cacheCount => _cache.length;

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
        return {
          'type': 'verse',
          'content': data,
          'background': data['background'] ?? currentState?['background'],
        };
      case 'cast-slide':
        return {
          'type': 'slide',
          'content': data,
          'background': data['background'] ?? currentState?['background'],
        };
      case 'cast-song':
        return {
          'type': 'song',
          'content': data,
          'background': data['background'] ?? currentState?['background'],
        };
      case 'cast-logo':
        return {
          'type': 'logo',
          'content': data,
          'background': data['background'] ?? currentState?['background'],
        };
      case 'cast-welcome':
        return {
          'type': 'welcome',
          'content': data,
          'background': data['background'] ?? currentState?['background'],
        };
    }
    return {'type': 'idle'};
  }

  // ── Debounced rendering ──

  void _debounceRender(Map<String, dynamic> state, BuildContext context) {
    final key = stateKey(state);
    // Instant response: if slide was pre-rendered, serve immediately!
    if (_cache.containsKey(key)) {
      _cancelPending();
      _renderAndPush(state, context);
      return;
    }
    // Live render: kick off immediately without artificial delay
    _cancelPending();
    _renderAndPush(state, context);
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
  /// full capture (plan 4.3 latency lever). Runs in the background without
  /// blocking the active frame or UI interactions.
  Future<void> preRender(
      Map<String, dynamic> nextState, [BuildContext? context]) async {
    final key = stateKey(nextState);
    if (_cache.containsKey(key)) return;
    // Microtask yield so optimistic UI and active gestures finish and render first
    await Future.microtask(() {});
    if (context != null && !context.mounted) return;
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
    Uint8List? png = await _pdfPng(localPath, page);
    if (png == null && localPath != null && localPath.isNotEmpty) {
      // The entry-page push used to fail silently when PdfPresenterScreen
      // held the file descriptor at the same time (Kodi showed nothing until
      // Next + Prev). One settle + retry makes the first push reliable.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      png = await _pdfPng(localPath, page);
    }
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

  /// Serializes phone-side pdfx renders. Android's PdfRenderer can fail when
  /// two renders of the same path race (OutputRouter vs PdfPresenterScreen),
  /// so every render waits for the previous one to finish.
  Future<void> _pdfGate = Future.value();

  Future<Uint8List?> _pdfPng(String? localPath, int page) {
    final gate = _pdfGate;
    final done = Completer<void>();
    _pdfGate = done.future;
    return gate.then((_) => _pdfPngLocked(localPath, page)).whenComplete(() {
      done.complete();
    });
  }

  Future<Uint8List?> _pdfPngLocked(String? localPath, int page) async {
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

  String stateKey(Map<String, dynamic> state) {
    final type = state['type'] as String? ?? 'idle';
    final content =
        Map<String, dynamic>.from(state['content'] as Map? ?? {});
    final bg = (state['background'] as Map?)?['url'] as String? ??
        (content['background'] as Map?)?['url'] as String? ??
        '';

    if (type == 'verse') {
      final book = content['book'] ?? '';
      final ch = content['chapter'] ?? '';
      final vs = content['verse'] ?? '';
      final fs = content['fontSize'] ?? 44;
      return 'verse:$book:$ch:$vs:$fs:$bg';
    } else if (type == 'song') {
      final title = content['title'] ?? '';
      final stanza = content['currentStanza'] ?? 0;
      final fs = content['fontSize'] ?? 44;
      return 'song:$title:$stanza:$fs:$bg';
    } else if (type == 'slide') {
      final title = content['title'] ?? '';
      final text = content['text'] ?? '';
      final fs = content['fontSize'] ?? 44;
      return 'slide:$title:$text:$fs:$bg';
    } else if (type == 'logo') {
      return 'logo:$bg';
    } else if (type == 'welcome') {
      final msg = content['message'] ?? '';
      return 'welcome:$msg:$bg';
    }
    return jsonEncode(state);
  }

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
