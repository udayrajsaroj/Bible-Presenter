import 'package:flutter/material.dart';
import '../theme.dart';

// ══════════════════ AUTO-FIT TEXT ══════════════════

/// Largest font size (in points) at which [text] laid out with [style] fits
/// inside maxWidth × maxHeight. Binary search between [minSize] and the size
/// in [style]; guarantees the measured block height stays within maxHeight.
double fitFontSize({
  required String text,
  required TextStyle style,
  required double maxWidth,
  required double maxHeight,
  double minSize = 12,
  int maxLines = 1000,
}) {
  double probe(double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    final h = tp.height;
    tp.dispose();
    return h;
  }

  var hi = (style.fontSize ?? 16).toDouble();
  if (probe(hi) <= maxHeight) return hi;
  var lo = minSize;
  for (var i = 0; i < 14 && hi - lo > 0.5; i++) {
    final mid = (lo + hi) / 2;
    if (probe(mid) <= maxHeight) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// Verse/stanza text that never overflows: starts at [maxFontSize] and
/// shrinks to the largest size that still fits the available box. Pass
/// [maxHeightOverride] when the parent gives unbounded height (scroll views).
class AutoFitText extends StatelessWidget {
  final String text;
  final double maxFontSize;
  final double minFontSize;
  final TextStyle style;
  final TextAlign textAlign;
  final double? maxHeightOverride;

  const AutoFitText(
    this.text, {
    super.key,
    required this.maxFontSize,
    required this.style,
    this.minFontSize = 12,
    this.textAlign = TextAlign.center,
    this.maxHeightOverride,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final maxH = maxHeightOverride ?? box.maxHeight;
      final maxW = box.maxWidth.isFinite ? box.maxWidth : 400.0;
      final base = style.copyWith(fontSize: maxFontSize);
      final size = fitFontSize(
        text: text,
        style: base,
        maxWidth: maxW,
        maxHeight: maxH.isFinite ? maxH : 400.0,
        minSize: minFontSize,
      );
      return Text(text,
          textAlign: textAlign,
          style: base.copyWith(fontSize: size));
    });
  }
}

// ══════════════════ REUSABLE WIDGETS ══════════════════

Widget appCard(Widget child) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: kBg3,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: kBorder),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
  ),
  child: child,
);

Widget label(String text) => Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kMuted, letterSpacing: 1.5));

Widget pill(String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: kAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: kAccent.withValues(alpha: 0.3))),
  child: Text(text, style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: kAccent)),
);

Widget primaryBtn(String label, VoidCallback? onTap) => Material(
  color: Colors.transparent,
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Ink(
      height: 50,
      width: double.infinity,
      decoration: BoxDecoration(
        color: onTap != null ? kAccent : kBorder,
        borderRadius: BorderRadius.circular(14),
        boxShadow: onTap != null ? [BoxShadow(color: kAccent.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 5))] : [],
      ),
      child: Center(
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: onTap != null ? Colors.white : kMuted, letterSpacing: 0.5)),
      ),
    ),
  ),
);

Widget secondaryBtn(String label, VoidCallback? onTap) => Material(
  color: Colors.transparent,
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Ink(
      height: 46,
      decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: onTap != null ? kBorder : kBorder.withValues(alpha: 0.3))),
      child: Center(
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: onTap != null ? kText : kMuted)),
      ),
    ),
  ),
);

Widget inputField(TextEditingController ctrl, String label, String hint, {int maxLines = 1}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kMuted, letterSpacing: 1.5)),
    const SizedBox(height: 6),
    TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: kText, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: kMuted, fontSize: 12),
        filled: true, fillColor: kBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kAccent)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
  ],
);

Widget dropdownField<T>({
  required String label, required T value,
  required List<T> items, required String Function(T) display,
  required void Function(T) onChanged,
}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Text(label, style: const TextStyle(fontSize: 8, color: kMuted, fontWeight: FontWeight.bold, letterSpacing: 1)),
  const SizedBox(height: 4),
  Container(
    decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
        isExpanded: true,
        dropdownColor: kBg3,
        style: const TextStyle(color: kText, fontSize: 11),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(display(i), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    ),
  ),
]);

Widget sectionHeader(IconData icon, String title, Color color) => Row(children: [
  Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
    child: Icon(icon, size: 14, color: color),
  ),
  const SizedBox(width: 8),
  Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 1.5)),
]);

Widget infoRow(String label, String value, Color valueColor) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Row(children: [
    SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 10, color: kMuted))),
    Expanded(child: Text(value, style: TextStyle(fontSize: 11, color: valueColor, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
  ]),
);

Widget castStep(String num, String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kAccent.withValues(alpha: 0.4)),
      ),
      child: Center(child: Text(num, style: const TextStyle(fontSize: 10, color: kAccent, fontWeight: FontWeight.bold))),
    ),
    const SizedBox(width: 10),
    Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), height: 1.4))),
  ]),
);

Widget castFileBtn(String label, VoidCallback onTap) => Material(
  color: Colors.transparent,
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Ink(
      height: 44,
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cast, size: 14, color: kAccent),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kAccent, letterSpacing: 0.3)),
        ],
      ),
    ),
  ),
);

IconData fileIcon(String type) {
  switch (type) {
    case 'pdf': return Icons.picture_as_pdf;
    case 'pptx': return Icons.slideshow;
    default: return Icons.insert_drive_file;
  }
}

Color fileColor(String type) {
  switch (type) {
    case 'pdf': return Colors.red.shade400;
    case 'pptx': return Colors.orange.shade400;
    case 'video': return kAccent;
    default: return kMuted;
  }
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
}
