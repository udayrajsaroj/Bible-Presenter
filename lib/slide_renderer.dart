import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:image/image.dart' as img;
import 'widgets/shared_widgets.dart';

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

  // ── tv.html palette ──
  static const Color _ink = Color(0xFF0a0a0f);
  static const Color _gold = Color(0xFFc9a96e);

  /// Renders [tvState] to a full-HD JPEG/PNG using a headless off-screen pipeline.
  /// Does not depend on Overlay or frame ticks, preventing assertion errors
  /// and returning immediately.
  static Future<Uint8List?> capture(Map<String, dynamic> tvState,
      {BuildContext? context}) async {
    try {
      final repaintBoundary = RenderRepaintBoundary();
      final pipelineOwner = PipelineOwner();
      final buildOwner = BuildOwner(focusManager: FocusManager());

      final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
        container: repaintBoundary,
        child: MediaQuery(
          data: const MediaQueryData(size: slideSize),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: buildSlideWidget(tvState),
          ),
        ),
      ).attachToRenderTree(buildOwner);

      buildOwner.buildScope(rootElement);
      buildOwner.finalizeTree();

      pipelineOwner.rootNode = repaintBoundary;
      repaintBoundary.layout(BoxConstraints.tight(slideSize));

      final rootLayer = OffsetLayer();
      rootLayer.attach(pipelineOwner);
      repaintBoundary.scheduleInitialPaint(rootLayer);

      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      final image = await repaintBoundary.toImage(pixelRatio: 1.0);
      try {
        rootLayer.detach();
        rootElement.unmount();
      } catch (_) {}

      // Use Skia native C++ PNG encoding (instantaneous ~30-50ms, zero main-thread stall)
      final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
      final outputBytes = pngData?.buffer.asUint8List();
      image.dispose();
      return outputBytes;
    } catch (_) {
      return null;
    }
  }


  /// Writes a captured slide to `<uploadDir>/dlna/slide_<n>.(jpg|png)` and returns the
  /// URL the TV should download. Automatically cleans up older slide files to prevent disk bloat.
  static Future<String?> publish(Uint8List bytes) async {
    if (uploadDirPath.isEmpty) return null;
    _slideCounter++;
    final dir = Directory('$uploadDirPath/dlna');
    if (!await dir.exists()) await dir.create(recursive: true);
    
    final isJpg = bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
    final ext = isJpg ? 'jpg' : 'png';
    final name = 'slide_$_slideCounter.$ext';
    await File('${dir.path}/$name').writeAsBytes(bytes, flush: true);

    // Keep only the last 5 slide files to prevent disk bloat
    try {
      final oldFiles = dir.listSync().whereType<File>().toList();
      if (oldFiles.length > 5) {
        oldFiles.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
        for (var i = 0; i < oldFiles.length - 5; i++) {
          try { oldFiles[i].deleteSync(); } catch (_) {}
        }
      }
    } catch (_) {}

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

    Widget imageWidget;
    File? localFile;
    if (url.startsWith('file://')) {
      localFile = File(url.replaceFirst('file://', ''));
    } else if (url.contains('/uploads/')) {
      final fileName = Uri.tryParse(url)?.pathSegments.last;
      if (fileName != null && uploadDirPath != null) {
        final f = File('$uploadDirPath/$fileName');
        if (f.existsSync()) localFile = f;
      }
    } else if (!url.startsWith('http://') && !url.startsWith('https://')) {
      final f = File(url);
      if (f.existsSync()) localFile = f;
    }

    if (localFile != null && localFile.existsSync()) {
      imageWidget = Image.file(
        localFile,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else {
      imageWidget = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    return Opacity(
      opacity: 0.45,
      child: imageWidget,
    );
  }

  /// The TV's animated CSS gradients are mirrored with rich multi-layer dark
  /// ambient gradients for DLNA still-frame rendering (Kodi/Smart TVs).
  static Widget _animatedGradientStandIn(String id) {
    final key = id.replaceFirst('animated:', '');
    switch (key) {
      case 'aurora': // Celestial Nebula
        return const Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF03030c), Color(0xFF080d24), Color(0xFF150d30), Color(0xFF04201c), Color(0xFF03030c)],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.3, -0.2),
                  radius: 0.95,
                  colors: [Color(0x330ea5e9), Color(0x228b5cf6), Colors.transparent],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.4, 0.5),
                  radius: 0.8,
                  colors: [Color(0x2010b981), Colors.transparent],
                ),
              ),
            ),
          ],
        );
      case 'divine': // Divine Glory
        return const Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [Color(0xFF18150d), Color(0xFF090805), Color(0xFF030302)],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.6,
                  colors: [Color(0x3ec9a96e), Color(0x18f59e0b), Colors.transparent],
                ),
              ),
            ),
          ],
        );
      case 'ocean': // Living Waters
        return const Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF020914), Color(0xFF031a2e), Color(0xFF02101c), Color(0xFF010408)],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.4, 0.2),
                  radius: 0.85,
                  colors: [Color(0x2b06b6d4), Color(0x160284c7), Colors.transparent],
                ),
              ),
            ),
          ],
        );
      case 'fire': // Altar Flame
        return const Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF060202), Color(0xFF0e0404), Color(0xFF160604)],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, 1.0),
                  radius: 0.95,
                  colors: [Color(0x3fef4444), Color(0x2af59e0b), Color(0x12b45309), Colors.transparent],
                ),
              ),
            ),
          ],
        );
      case 'sunset': // Midnight Sanctuary
      default:
        return const Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF06020c), Color(0xFF1c0533), Color(0xFF28041a), Color(0xFF070b24), Color(0xFF020106)],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, 0.1),
                  radius: 0.8,
                  colors: [Color(0x2ea855f7), Color(0x1aec4899), Colors.transparent],
                ),
              ),
            ),
          ],
        );
    }
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

    // Accurately combine text without duplicating fallback
    final String combinedText;
    if (hi.isNotEmpty && en.isNotEmpty) {
      combinedText = '$hi\n\n$en';
    } else if (hi.isNotEmpty) {
      combinedText = hi;
    } else if (en.isNotEmpty) {
      combinedText = en;
    } else {
      combinedText = fallback;
    }

    final double maxWidth = slideSize.width - 240; // 1680px — leaves 120px safe padding from borders
    const double maxHeight = 800; // leaves 140px safe margin top and bottom

    double probe(double size) {
      final tp = TextPainter(
        text: TextSpan(
          text: combinedText,
          style: TextStyle(
            fontSize: size,
            height: 1.38,
            fontFamilyFallback: const ['serif'],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      final h = tp.height;
      tp.dispose();
      return h;
    }

    // Binary search for largest font size that fills available space without touching borders
    double lo = 28.0;
    double hiSize = (base * 1.5).clamp(58.0, 72.0);
    for (int i = 0; i < 16; i++) {
      final mid = (lo + hiSize) / 2;
      if (probe(mid) <= maxHeight) {
        lo = mid;
      } else {
        hiSize = mid;
      }
    }
    final fs = lo.clamp(28.0, 72.0);
    final isDevanagari = RegExp(r'[\u0900-\u097F]').hasMatch(en);

    Widget text(String s, {bool italic = false}) => Text(
          s,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: italic ? Colors.white70 : Colors.white,
            fontSize: fs,
            height: 1.38,
            fontStyle: (italic && !isDevanagari) ? FontStyle.italic : FontStyle.normal,
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
