import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import '../theme.dart';
import '../widgets/presenter_shell.dart';

/// Dedicated live-casting screen for PDF documents. Renders the active page
/// on the phone with pdfx (same engine the DLNA pipeline uses), syncs page
/// changes with the TV, and offers a thumbnail grid for fast jumping.
class PdfPresenterScreen extends StatefulWidget {
  final String fileName;
  final String? localPath;
  final int initialPage;
  final int reportedTotalPages;
  final ValueNotifier<Map<String, dynamic>> tvState;

  /// Navigates pages on the TV (emits pdf-page through the OutputRouter).
  final void Function(int page) onGoToPage;
  final VoidCallback onLogo;
  final VoidCallback onBlackout;

  const PdfPresenterScreen({
    super.key,
    required this.fileName,
    required this.localPath,
    required this.initialPage,
    required this.reportedTotalPages,
    required this.tvState,
    required this.onGoToPage,
    required this.onLogo,
    required this.onBlackout,
  });

  @override
  State<PdfPresenterScreen> createState() => _PdfPresenterScreenState();
}

class _PdfPresenterScreenState extends State<PdfPresenterScreen> {
  pdfx.PdfDocument? _doc;
  int _page = 1;
  int _totalPages = 0;
  String? _error;
  final Map<int, Uint8List> _pageCache = {};

  /// Ensures the "sync TV to Page 1" emit happens exactly once per entry.
  bool _initialSyncDone = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage < 1 ? 1 : widget.initialPage;
    _totalPages =
        widget.reportedTotalPages > 0 ? widget.reportedTotalPages : 0;
    _open();
  }

  Future<void> _open() async {
    final path = widget.localPath;
    if (path == null || path.isEmpty) return; // Browser Connect path only
    try {
      final doc = await pdfx.PdfDocument.openFile(path);
      if (!mounted) {
        await doc.close();
        return;
      }
      setState(() {
        _doc = doc;
        _totalPages = doc.pagesCount;
        if (_page > doc.pagesCount) _page = doc.pagesCount;
      });
      // Guarantee Kodi/DLNA shows the entry page immediately: the TV push
      // competes with this open for the same file descriptor on Android, so
      // re-emit explicitly once the document is initialized (fixes the
      // "Page 1 skipped until Next+Prev" race).
      if (!_initialSyncDone) {
        _initialSyncDone = true;
        widget.onGoToPage(_page);
      }
      _render(_page);
      _render(_page + 1); // pre-render the up-next card
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not open document preview');
      }
    }
  }

  Future<void> _render(int page) async {
    final doc = _doc;
    if (doc == null || _pageCache.containsKey(page)) return;
    if (page < 1 || page > doc.pagesCount) return;
    try {
      final pdfPage = await doc.getPage(page);
      final img = await pdfPage.render(
        width: pdfPage.width,
        height: pdfPage.height,
        format: pdfx.PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      if (img != null && mounted) {
        setState(() => _pageCache[page] = img.bytes);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not render page $page');
    }
  }

  @override
  void dispose() {
    try {
      _doc?.close();
    } catch (_) {}
    super.dispose();
  }

  void _go(int page) {
    if (page < 1 || (_totalPages > 0 && page > _totalPages)) return;
    if (page == _page) return;
    setState(() => _page = page);
    _render(page);
    _render(page + 1); // pre-render the up-next preview in the background
    widget.onGoToPage(page);
  }

  void _onSwipe(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dx;
    if (v < -120) _go(_page + 1);
    if (v > 120) _go(_page - 1);
  }

  void _openGrid() {
    if (_totalPages <= 0) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kBg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => _PageGrid(
        totalPages: _totalPages,
        currentPage: _page,
        doc: _doc,
        onPick: (p) {
          Navigator.pop(ctx);
          _go(p);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PresenterScaffold(
      leading: PresenterIconButton(
        icon: Icons.arrow_back,
        tooltip: 'Back to files',
        onTap: () => Navigator.of(context).pop(),
      ),
      title: widget.fileName,
      subtitle: _totalPages > 0 ? '$_totalPages pages' : null,
      tvState: widget.tvState,
      headerActions: [
        if (_totalPages > 0)
          PresenterIconButton(
              icon: Icons.grid_view,
              tooltip: 'Page thumbnails',
              onTap: _openGrid),
        PresenterIconButton(
            icon: Icons.image_outlined,
            tooltip: 'Show church logo',
            onTap: widget.onLogo),
        PresenterIconButton(
            icon: Icons.dark_mode_outlined,
            tooltip: 'Blackout screen',
            onTap: widget.onBlackout),
      ],
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: _onSwipe,
        child: Container(
          color: kBg,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: widget.localPath == null || widget.localPath!.isEmpty
              ? Center(child: _noLocalPreview())
              : _totalPages <= 0
                  ? Center(child: _activeCard())
                  : Column(children: [
                      // Active live page — the card that mirrors the TV.
                      Expanded(flex: 5, child: _activeCard()),
                      const SizedBox(height: 10),
                      // Upcoming page preview (~60% of the active card) so
                      // the operator sees the next slide before advancing.
                      Expanded(
                        flex: 3,
                        child: _page < _totalPages
                            ? GestureDetector(
                                onTap: () => _go(_page + 1),
                                child: _previewCard(),
                              )
                            : _endCard(),
                      ),
                    ]),
        ),
      ),
      dockLeft: DockNavButton(
        label: 'PREV',
        icon: Icons.navigate_before,
        iconFirst: true,
        onTap: _page > 1 ? () => _go(_page - 1) : null,
      ),
      dockCenter: DockCounterPill(
        primary: 'Page $_page${_totalPages > 0 ? ' / $_totalPages' : ''}',
        secondary: 'tap to jump',
        accent: kAccent,
      ),
      dockRight: DockNavButton(
        label: 'NEXT',
        icon: Icons.navigate_next,
        onTap: (_totalPages > 0 && _page >= _totalPages)
            ? null
            : () => _go(_page + 1),
      ),
    );
  }

  /// Top card: the live page with glowing LIVE ON TV badge + accent border.
  Widget _activeCard() {
    final bytes = _pageCache[_page];
    return _stageCard(
      page: _page,
      bytes: bytes,
      loadingLabel: _error ?? 'Rendering page $_page…',
      badge: _badge(
          icon: Icons.circle,
          iconSize: 7,
          label: 'LIVE ON TV',
          fg: Colors.greenAccent,
          bg: Colors.green.withOpacity(0.30)),
      borderColor: kAccent,
      borderWidth: 1.6,
      interactive: true,
      showPageChip: true,
    );
  }

  /// Bottom card: preview of page N+1 (rendered in the background).
  Widget _previewCard() {
    final next = _page + 1;
    final bytes = _pageCache[next];
    return _stageCard(
      page: next,
      bytes: bytes,
      loadingLabel: 'Pre-rendering page $next…',
      badge: _badge(
          icon: Icons.skip_next,
          iconSize: 11,
          label: 'UP NEXT (Page $next)',
          fg: kGold,
          bg: kGold.withOpacity(0.16)),
      borderColor: kBorder,
      borderWidth: 1,
      dimmed: true,
    );
  }

  /// Final page: clean end-of-document card instead of an empty preview.
  Widget _endCard() {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kBg2.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder, width: 1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_outline,
            size: 30, color: Colors.greenAccent),
        const SizedBox(height: 8),
        const Text('End of Document',
            style: TextStyle(
                color: kText, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text('All $_totalPages pages presented',
            style: const TextStyle(color: kMuted, fontSize: 10)),
      ]),
    );
  }

  Widget _badge({
    required IconData icon,
    required double iconSize,
    required String label,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.55), width: 1),
        boxShadow: [
          BoxShadow(
              color: fg.withOpacity(0.35), blurRadius: 8, spreadRadius: 0.5),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: iconSize, color: fg),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: fg,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.7)),
      ]),
    );
  }

  Widget _stageCard({
    required int page,
    required Uint8List? bytes,
    required String loadingLabel,
    required Widget badge,
    required Color borderColor,
    required double borderWidth,
    bool interactive = false,
    bool dimmed = false,
    bool showPageChip = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
              color: borderColor.withOpacity(interactive ? 0.28 : 0.10),
              blurRadius: interactive ? 14 : 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.5),
        child: Stack(fit: StackFit.expand, children: [
          if (bytes != null)
            Opacity(
              opacity: dimmed ? 0.82 : 1,
              child: interactive
                  ? InteractiveViewer(
                      maxScale: 4,
                      child: Center(
                          child: Image.memory(bytes,
                              fit: BoxFit.contain,
                              alignment: Alignment.center)))
                  : Center(
                      child: Image.memory(bytes,
                          fit: BoxFit.contain, alignment: Alignment.center)),
            )
          else
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: kAccent)),
                const SizedBox(height: 10),
                Text(loadingLabel,
                    style: const TextStyle(color: kMuted, fontSize: 11),
                    textAlign: TextAlign.center),
              ]),
            ),
          Positioned(top: 8, left: 8, child: badge),
          if (showPageChip)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Page $page',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600)),
              ),
            ),
        ]),
      ),
    );
  }

  /// Old sessions have no local copy on the phone — the document still casts
  /// through Browser Connect, only the phone-side preview is unavailable.
  Widget _noLocalPreview() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.picture_as_pdf, size: 56, color: Colors.red.shade400),
          const SizedBox(height: 14),
          Text(widget.fileName,
              style: const TextStyle(color: kText, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
              'Page preview needs the file on this phone.\nThe TV (Browser Connect) still shows the document.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kMuted, fontSize: 11, height: 1.5)),
        ],
      );
}

/// Thumbnail grid for instant page jumping. Pages render lazily at a small
/// size so a 200-page document does not decode everything up front.
class _PageGrid extends StatelessWidget {
  final int totalPages;
  final int currentPage;
  final pdfx.PdfDocument? doc;
  final void Function(int) onPick;

  const _PageGrid({
    required this.totalPages,
    required this.currentPage,
    required this.doc,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.72),
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Text('JUMP TO PAGE',
                style: const TextStyle(
                    color: kAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            const Spacer(),
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 18, color: kMuted)),
          ]),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.78,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8),
              itemCount: totalPages,
              itemBuilder: (ctx, i) {
                final page = i + 1;
                return _Thumb(
                  page: page,
                  active: page == currentPage,
                  doc: doc,
                  onTap: () => onPick(page),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final int page;
  final bool active;
  final pdfx.PdfDocument? doc;
  final VoidCallback onTap;
  const _Thumb({
    required this.page,
    required this.active,
    required this.doc,
    required this.onTap,
  });

  Future<Widget> _load() async {
    if (doc == null) {
      return const Icon(Icons.broken_image, color: kMuted);
    }
    try {
      final pdfPage = await doc!.getPage(page);
      const w = 200.0;
      final h = (w * pdfPage.height / pdfPage.width).clamp(50, 1200);
      final img = await pdfPage.render(
          width: w,
          height: h.toDouble(),
          format: pdfx.PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF');
      if (img == null) return const Icon(Icons.broken_image, color: kMuted);
      return Image.memory(img.bytes, fit: BoxFit.contain);
    } catch (_) {
      return const Icon(Icons.broken_image, color: kMuted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? kAccent : kBorder, width: active ? 2 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(children: [
            Center(
              child: FutureBuilder<Widget>(
                future: _load(),
                builder: (ctx, snap) =>
                    snap.data ?? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: kMuted),
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: active ? kAccent : Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$page',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
