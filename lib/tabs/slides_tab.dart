import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';

class SlidesTab extends StatelessWidget {
  final List<Map<String, String>> slides;
  final int activeSlide;
  final void Function(int idx) onCastSlide;
  final void Function(int idx) onDeleteSlide;
  final VoidCallback onShowAddSlideModal;
  final VoidCallback onOpenFullscreen;

  const SlidesTab({
    super.key,
    required this.slides,
    required this.activeSlide,
    required this.onCastSlide,
    required this.onDeleteSlide,
    required this.onShowAddSlideModal,
    required this.onOpenFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        // Active slide card
        appCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            label('ACTIVE SLIDE'),
            pill('${activeSlide + 1} / ${slides.length}'),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(slides[activeSlide]['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: kText, fontSize: 14, letterSpacing: 0.5)),
              if ((slides[activeSlide]['text'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('"${slides[activeSlide]['text']}"', style: const TextStyle(color: kMuted, fontSize: 11, fontStyle: FontStyle.italic)),
              ],
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: secondaryBtn('Prev', activeSlide > 0 ? () => onCastSlide(activeSlide - 1) : null)),
            const SizedBox(width: 8),
            Expanded(child: secondaryBtn('Next', activeSlide < slides.length - 1 ? () => onCastSlide(activeSlide + 1) : null)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: primaryBtn('Cast to TV', () => onCastSlide(activeSlide))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onOpenFullscreen,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kAccent.withOpacity(0.4)),
                ),
                child: const Icon(Icons.fullscreen, color: kAccent, size: 20),
              ),
            ),
          ]),
        ])),

        const SizedBox(height: 12),

        // Queue card
        appCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            label('QUEUE'),
            GestureDetector(
              onTap: onShowAddSlideModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade800.withOpacity(0.5)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add, size: 12, color: Colors.green),
                  SizedBox(width: 4),
                  Text('Add', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          ...slides.asMap().entries.map((e) {
            final active = e.key == activeSlide;
            return GestureDetector(
              onTap: () => onCastSlide(e.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF0c1f3a) : kBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: active ? kAccent.withOpacity(0.7) : kBorder),
                ),
                child: Row(children: [
                  Text('${e.key + 1}', style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: active ? kAccent : kMuted)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.value['title'] ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? kText : kMuted))),
                  if (active) const Icon(Icons.cast, size: 13, color: kAccent),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () { if (slides.length > 1) onDeleteSlide(e.key); },
                    child: Icon(Icons.delete_outline, size: 14, color: slides.length > 1 ? Colors.red.shade400 : Colors.white12),
                  ),
                ]),
              ),
            );
          }),
        ])),
      ]),
    );
  }
}
