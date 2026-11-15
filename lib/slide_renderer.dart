import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Off-screen slide renderer for DLNA "TV Direct" casting (Phase D1).
///
/// DLNA MediaRenderers cannot display HTML, so every content state is painted
/// as a 1920×1080 PNG that mirrors the tv.html presentation layout: the same
/// background themes (preset images + static stand-ins for the animated
/// gradients), the user's font-size setting, bilingual (Hindi/English) verse
/// text, song stanzas and the church logo.
///
/// The widget is inserted into the root [Overlay] as an offstage child, laid
/// out at exactly 1920×1080 logical pixels and captured via
/// [RenderRepaintBoundary.toImage] at pixel ratio 1.0.
///
/// [publish] writes the PNG into a `dlna/` subfolder of the upload directory
/// (shared with the server Isolate, which serves it at GET /dlna/<file> with
/// Cache-Control: no-store) and returns the phone-side URL that is handed to
/// the TV's SetAVTransportURI call.
class SlideRenderer {
  SlideRenderer._();

  static const Size slideSize = Size(1920, 1080);

  /// Upload directory shared with the server isolate; set once at boot.
  static String uploadDirPath = '';

  /// LAN IP of the phone, used to build the media URL for the TV.
  static String deviceIp = '';

  /// Actual server port (3000, or 3001 fallback) reported after boot.
  static int serverPort = 3000;

  static int _slideCounter = 0;
  static OverlayEntry? _entry;
  static final GlobalKey _boundaryKey = GlobalKey();

  // ── tv.html palette ──
  static const Color _ink = Color(0xFF0a0a0f);
  static const Color _gold = Color(0xFFc9a96e);

  /// Renders [tvState] to a full-HD PNG, or null when no overlay context is
  /// available yet (e.g. captures requested before the first frame).
  static Future<Uint8List?> capture(Map<String, dynamic> tvState,
      {required BuildContext context}) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return null;

    // Drop any previous capture widget before installing the new one.
    _removeEntry();

    final completer = Completer<Uint8List?>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Offstage(
        offstage: true,
        child: UnconstrainedBox(
          constrainedAxis: null,
          child: SizedBox(
            width: slideSize.width,
            height: slideSize.height,
            child: RepaintBoundary(
              key: _boundaryKey,
              child: MediaQuery(
                // Fixed 1:1 device pixels so text scales like a real TV.
                data: MediaQueryData(size: slideSize),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: buildSlideWidget(tvState),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);

    // Let the widget build, layout and paint before capturing. Two frames:
    // one for the widget tree, one for async image/typography resolution.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        try {
          final boundary = _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
          if (boundary == null || !boundary.attached) {
            completer.complete(null);
            return;
          }
          final image = await boundary.toImage(pixelRatio: 1.0);
          final data =
              await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          completer.complete(data?.buffer.asUint8List());
        } catch (_) {
          completer.complete(null);
        }
      });
    });

    final result = await completer.future;
    _removeEntry();
    return result;
  }

  static void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  /// Writes a captured PNG to `<uploadDir>/dlna/slide_<n>.png` and returns the
  /// URL the TV should download, e.g.
  /// `http://192.168.1.20:3000/dlna/slide_7.png`. Returns null when the
  /// upload directory has not been configured yet.
  static Future<String?> publish(Uint8List png) async {
    if (uploadDirPath.isEmpty) return null;
    _slideCounter++;
    final dir = Directory('$uploadDirPath/dlna');
    if (!await dir.exists()) await dir.create(recursive: true);
    final name = 'slide_$_slideCounter.png';
    await File('${dir.path}/$name').writeAsBytes(png, flush: true);
    final ip = (deviceIp.isEmpty || deviceIp == '...') ? '127.0.0.1' : deviceIp;
    return 'http://$ip:$serverPort/dlna/$name';
  }

  /// Convenience: capture + publish in one call.
  static Future<String?> captureAndPublish(Map<String, dynamic> tvState,
      {required BuildContext context}) async {
    final png = await capture(tvState, context: context);
    if (png == null) return null;
    return publish(png);
  }

  // ══════════════════ Slide widget tree (mirrors tv.html) ══════════════════

  static Widget buildSlideWidget(Map<String, dynamic> tvState) {
    final type = tvState['type'] as String? ?? 'idle';
    final content =
        Map<String, dynamic>.from(tvState['content'] as Map? ?? {});
    final background = tvState['background'] as Map<String, dynamic>?;

    return SizedBox(
      width: slideSize.width,
      height: slideSize.height,
      child: ColoredBox(
        color: _ink,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _backgroundLayer(background),
            // Vignette overlay, like #bg-overlay in tv.html.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.2,
                  colors: [Colors.transparent, Color(0x870a0a0f)],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 58, vertical: 32),
                // Guaranteed fit: content lays out at its natural size inside
                // the content width and scales down uniformly when it would
                // overflow the slide — the largest readable size wins.
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: slideSize.width - 116,
                      child: _contentFor(type, content),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Background: preset image, animated-gradient stand-in, or plain ink ──
  static Widget _backgroundLayer(Map<String, dynamic>? background) {
    final url = background?['url'] as String? ?? '';
    if (url.startsWith('animated:')) {
      return _animatedGradientStandIn(url);
    }
    if (url.isEmpty) return const SizedBox.shrink();
    return Opacity(
      opacity: 0.45,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  /// The TV's animated CSS gradients are approximated with static gradients
  /// in the PNG (renderers show a single still frame anyway).
  static Widget _animatedGradientStandIn(String id) {
    final List<List<Color>> palettes = const [
      [Color(0xFF0a0a2e), Color(0xFF1a0a3e), Color(0xFF0a2a4e), Color(0xFF0a0a2e)],
      [Color(0xFF1a1a0a), Color(0xFF0a0a0f)],
      [Color(0xFF1a0a0a), Color(0xFF2a1a0a), Color(0xFF1a0a1a), Color(0xFF0a0a2a)],
      [Color(0xFF0a1a2a), Color(0xFF0a2a3a), Color(0xFF0a1a3a), Color(0xFF0a0a2a)],
      [Color(0xFF0a0a0a), Color(0xFF2a1208)],
    ];
    final key = id.replaceFirst('animated:', '');
    final idx = switch (key) {
      'aurora' => 0,
      'divine' => 1,
      'sunset' => 2,
      'ocean' => 3,
      'fire' => 4,
      _ => 0,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palettes[idx],
        ),
      ),
    );
  }

  // ── Per-type content ──
  static Widget _contentFor(String type, Map<String, dynamic> c) {
    switch (type) {
      case 'verse':
        return _verseContent(c);
      case 'slide':
        return _slideContent(c);
      case 'song':
        return _songContent(c);
      case 'logo':
        return _logoContent(c);
      case 'welcome':
        return _welcomeContent(c);
      case 'idle':
      default:
        return _idleContent();
    }
  }

  /// Port of tv.html fontSize(): shrink stepwise as text grows.
  static double _autoFontSize(String text, num base) {
    final scale = text.length > 350
        ? 0.5
        : text.length > 250
            ? 0.64
            : text.length > 160
                ? 0.78
                : text.length > 90
                    ? 0.92
                    : 1.0;
    return (base * scale).clamp(16.0, 200.0).toDouble();
  }

  /// Port of tv.html songFontSize().
  static double _songAutoFontSize(String text, num base) {
    final scale = text.length > 300
        ? 0.55
        : text.length > 200
            ? 0.68
            : text.length > 120
                ? 0.82
                : text.length > 60
                    ? 0.95
                    : 1.1;
    return (base * scale).clamp(14.0, 220.0).toDouble();
  }

  static const Shadow _tvShadow =
      Shadow(color: Color(0xE6000000), blurRadius: 30, offset: Offset(0, 2));

  static Widget _verseContent(Map<String, dynamic> c) {
    final hi = c['textHi'] as String? ?? '';
    final en = c['textEn'] as String? ?? '';
    final fallback = c['text'] as String? ?? '';
    final base = (c['fontSize'] as num? ?? 44).toDouble();
    final totalLen = hi.length + en.length + fallback.length;
    final fs = _autoFontSize(totalLen > 0 ? 'x' * totalLen : 'x', base);

    Widget text(String s, {bool italic = false}) => Text(
          s,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: italic ? Colors.white70 : Colors.white,
            fontSize: fs,
            height: 1.55,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            fontWeight: italic ? FontWeight.w300 : FontWeight.w400,
            fontFamilyFallback: const ['serif'],
            shadows: const [_tvShadow],
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hi.isNotEmpty) text(hi),
        if (hi.isNotEmpty && en.isNotEmpty)
          const _Ornament(),
        if (en.isNotEmpty) text('"$en"', italic: true),
        if (hi.isEmpty && en.isEmpty && fallback.isNotEmpty)
          text('"$fallback"'),
        const SizedBox(height: 24),
        Text(
          '${c['book'] ?? ''} ${c['chapter'] ?? ''}:${c['verse'] ?? ''}'
              .toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _gold,
            fontSize: 22,
            letterSpacing: 6,
            fontWeight: FontWeight.w700,
            fontFamilyFallback: ['serif'],
            shadows: [Shadow(color: Color(0x66c9a96e), blurRadius: 30)],
          ),
        ),
      ],
    );
  }

  static Widget _slideContent(Map<String, dynamic> c) {
    final base = (c['fontSize'] as num? ?? 44).toDouble();
    final title = c['title'] as String? ?? '';
    final body = c['text'] as String? ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if ((c['subtitle'] as String? ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text(
              (c['subtitle'] as String).toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _gold, fontSize: 15, letterSpacing: 7),
            ),
          ),
        Text(
          title.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: (base * 1.15).clamp(24.0, 220.0),
            fontWeight: FontWeight.w900,
            height: 1.15,
            letterSpacing: 2,
            fontFamilyFallback: const ['serif'],
            shadows: const [_tvShadow],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: _Ornament(),
        ),
        if (body.isNotEmpty)
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFccc4b0),
              fontSize: (base * 0.78).clamp(18.0, 160.0),
              height: 1.7,
              fontFamilyFallback: const ['serif'],
              shadows: const [_tvShadow],
            ),
          ),
      ],
    );
  }

  static Widget _songContent(Map<String, dynamic> c) {
    final stanzas = (c['stanzas'] as List? ?? []).cast<String>();
    final idx = (c['currentStanza'] as int? ?? 0);
    final total = (c['totalStanzas'] as int? ?? stanzas.length);
    final stanza = idx < stanzas.length ? stanzas[idx] : '';
    final base = (c['fontSize'] as num? ?? 44).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stanza,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: _songAutoFontSize(stanza, base),
            height: 1.8,
            fontFamilyFallback: const ['serif'],
            shadows: const [_tvShadow],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${idx + 1} / $total',
          style: TextStyle(
            color: Colors.white.withOpacity(0.25),
            fontSize: 14,
            letterSpacing: 5,
          ),
        ),
      ],
    );
  }

  static Widget _logoContent(Map<String, dynamic> c) {
    final image = c['image'] as String? ?? '';
    return _fullBleedImage(image);
  }

  static Widget _welcomeContent(Map<String, dynamic> c) {
    final message = c['message'] as String? ?? '';
    final logo = c['logo'] as String? ?? '';
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 90),
        child: Column(
          mainAxisAlignment: message.isNotEmpty
              ? MainAxisAlignment.end
              : MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Flexible(child: _decodedImage(logo, fit: BoxFit.contain)),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 48),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF2a2a2a),
                  fontSize: 40,
                  letterSpacing: 3,
                  fontFamilyFallback: ['serif'],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _idleContent() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: 0.25,
            child: SizedBox(
              width: 64,
              height: 64,
              child: CustomPaint(painter: _CrossPainter()),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'BIBLEPRESENTER',
            style: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 14,
              letterSpacing: 8,
              fontFamilyFallback: const ['serif'],
            ),
          ),
        ],
      );

  // ── Image decoding helpers ──
  static Widget _fullBleedImage(String src) {
    if (src.startsWith('data:image')) {
      return _decodedImage(src, fit: BoxFit.cover);
    }
    return Image.network(src,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink());
  }

  /// Decodes a `data:image/...;base64,<payload>` URI (the app stores the
  /// custom logo and welcome logo as base64 data URIs).
  static Widget _decodedImage(String dataUri, {BoxFit fit = BoxFit.contain}) {
    final payload =
        dataUri.contains(',') ? dataUri.split(',')[1] : dataUri;
    try {
      final bytes = base64Decode(payload);
      return Image.memory(bytes, fit: fit);
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

/// Thin gold flourish line, the PNG twin of tv.html's .ornament.
class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) {
    const line = Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            Color(0x99c9a96e),
            Colors.transparent,
          ]),
        ),
        child: SizedBox(height: 1),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 90),
      child: Row(
        children: [
          line,
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text('✢',
                style: TextStyle(color: Color(0x99c9a96e), fontSize: 18)),
          ),
          line,
        ],
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFc9a96e);
    const barW = 7.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width / 2 - barW / 2, 0, barW, size.height),
          const Radius.circular(2)),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, size.height * 0.28, size.width, barW),
          const Radius.circular(2)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
