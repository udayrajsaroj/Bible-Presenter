import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../theme.dart';

/// Shows side-by-side thumbnails of the current PDF page and the next page.
class PdfPagePreview extends StatefulWidget {
  final String localPath;
  final int currentPage; // 1-indexed
  final int totalPages;
  final void Function(int totalPages)? onTotalPagesKnown;

  const PdfPagePreview({
    super.key,
    required this.localPath,
    required this.currentPage,
    required this.totalPages,
    this.onTotalPagesKnown,
  });

  @override
  State<PdfPagePreview> createState() => _PdfPagePreviewState();
}

class _PdfPagePreviewState extends State<PdfPagePreview> {
  PdfDocument? _doc;
  final Map<int, Uint8List> _cache = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _openDoc();
  }

  @override
  void didUpdateWidget(covariant PdfPagePreview old) {
    super.didUpdateWidget(old);
    if (old.localPath != widget.localPath) {
      _cache.clear();
      _openDoc();
    } else if (old.currentPage != widget.currentPage) {
      _renderNeeded();
    }
  }

  Future<void> _openDoc() async {
    setState(() {
      _error = null;
    });
    try {
      _doc?.close();
      _doc = await PdfDocument.openFile(widget.localPath);
      if (mounted && _doc != null && widget.onTotalPagesKnown != null) {
        widget.onTotalPagesKnown!(_doc!.pagesCount);
      }
      await _renderNeeded();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
        });
      }
    }
  }

  Future<void> _renderNeeded() async {
    if (_doc == null) return;
    final total = widget.totalPages > 0 ? widget.totalPages : (_doc?.pagesCount ?? 0);
    final pagesToRender = <int>{
      widget.currentPage,
      widget.currentPage + 1
    }.where((p) => p >= 1 && (total == 0 || p <= total) && !_cache.containsKey(p));
    for (final p in pagesToRender) {
      try {
        final page = await _doc!.getPage(p);
        final img = await page.render(
          width: page.width * 0.6,
          height: page.height * 0.6,
          format: PdfPageImageFormat.jpeg,
          quality: 70,
        );
        await page.close();
        if (img != null && mounted) {
          setState(() {
            _cache[p] = img.bytes;
          });
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _doc?.close();
    super.dispose();
  }

  Widget _thumb(String label, int? pageNum, {bool highlight = false}) {
    final bytes = pageNum != null ? _cache[pageNum] : null;
    return Expanded(
      child: Column(children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: highlight ? kAccent : kBorder, width: highlight ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: bytes != null
              ? Image.memory(bytes, fit: BoxFit.contain)
              : pageNum == null
                  ? const Center(
                      child: Icon(Icons.stop_circle_outlined,
                          color: kMuted, size: 22))
                  : const Center(
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: kAccent))),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: highlight ? kAccent : kMuted,
                letterSpacing: 0.5)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Preview error: $_error',
            style: const TextStyle(color: kMuted, fontSize: 10)),
      );
    }
    final total = widget.totalPages > 0 ? widget.totalPages : (_doc?.pagesCount ?? 0);
    final hasNext = total == 0 ? true : (widget.currentPage < total);
    return Row(children: [
      _thumb('PAGE ${widget.currentPage} (CURRENT)', widget.currentPage,
          highlight: true),
      const SizedBox(width: 10),
      _thumb(hasNext ? 'PAGE ${widget.currentPage + 1} (NEXT)' : 'LAST PAGE',
          hasNext ? widget.currentPage + 1 : null),
    ]);
  }
}
