import 'package:flutter/material.dart';

import '../state/bible_state.dart';
import '../theme.dart';
import '../widgets/presenter_shell.dart';

/// Dedicated live-casting screen for scripture. The selection (book /
/// chapter / verse) lives in BibleState — this screen listens to it, so the
/// reference chip, stage and dock always match what is on the TV.
class BiblePresenterScreen extends StatefulWidget {
  final BibleState bibleState;
  final ValueNotifier<Map<String, dynamic>> tvState;

  final VoidCallback onCastVerse;
  final VoidCallback onPrevVerse;
  final VoidCallback onNextVerse;
  final VoidCallback onLogo;
  final VoidCallback onBlackout;

  const BiblePresenterScreen({
    super.key,
    required this.bibleState,
    required this.tvState,
    required this.onCastVerse,
    required this.onPrevVerse,
    required this.onNextVerse,
    required this.onLogo,
    required this.onBlackout,
  });

  @override
  State<BiblePresenterScreen> createState() => _BiblePresenterScreenState();
}

class _BiblePresenterScreenState extends State<BiblePresenterScreen> {
  final _stageScroll = ScrollController();

  @override
  void dispose() {
    _stageScroll.dispose();
    super.dispose();
  }

  List<int> _verseNumbers() => (widget.bibleState
              .selectedBookChapters?[widget.bibleState.selectedChapter] ??
          {})
      .keys
      .toList()
    ..sort();

  void _onSwipe(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dx;
    if (v < -120) widget.onNextVerse();
    if (v > 120) widget.onPrevVerse();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.bibleState,
      builder: (context, _) {
        final b = widget.bibleState;
        final verses = _verseNumbers();
        final vIdx = verses.indexOf(b.selectedVerse);
        final v = b.selectedVerseData ?? const {};
        final primary = v['primary'] ?? '';
        final secondary = v['secondary'] ?? '';
        final ref = '${b.selectedBook} ${b.selectedChapter}:${b.selectedVerse}';

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_stageScroll.hasClients && _stageScroll.offset != 0) {
            _stageScroll.jumpTo(0);
          }
        });

        return PresenterScaffold(
          leading: PresenterIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Back to Bible browser',
            onTap: () => Navigator.of(context).pop(),
          ),
          title: '${b.selectedBook} ${b.selectedChapter}',
          subtitle: '${verses.length} verses in chapter',
          tvState: widget.tvState,
          headerActions: [
            // Font size popover — re-casts so the TV follows immediately.
            PopupMenuButton<int>(
              tooltip: 'Font size',
              icon: const Icon(Icons.format_size, size: 20, color: kText),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: kBg2,
              onSelected: (size) {
                b.fontSize = size;
                widget.onCastVerse();
              },
              itemBuilder: (_) => [36, 44, 52, 60, 68, 80]
                  .map((s) => PopupMenuItem<int>(
                      value: s,
                      child: Text('$s sp',
                          style: TextStyle(
                              color: b.fontSize == s ? kGold : kText,
                              fontSize: 13,
                              fontWeight: b.fontSize == s
                                  ? FontWeight.bold
                                  : FontWeight.normal))))
                  .toList(),
            ),
            PresenterIconButton(
                icon: Icons.image_outlined,
                tooltip: 'Show church logo',
                onTap: widget.onLogo),
            PresenterIconButton(
                icon: Icons.dark_mode_outlined,
                tooltip: 'Blackout screen',
                onTap: widget.onBlackout),
          ],
          headerStrip: Container(
            height: 46,
            color: kBg,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(children: [
              // Three inline scripture selectors — any pick updates BibleState
              // and live-casts to the TV immediately, no extra confirmation.
              Expanded(
                child: _RefDropdown<String>(
                  label: 'Book',
                  value: b.selectedBook,
                  items: b.bible.keys.toList(), // already canonical order
                  display: (v) => v,
                  onChanged: (book) {
                    if (book == null || book == b.selectedBook) return;
                    b.selectedBook = book;
                    widget.onCastVerse();
                  },
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 72,
                child: _RefDropdown<int>(
                  label: 'Ch',
                  value: b.selectedChapter,
                  items: (b.bible[b.selectedBook] ?? {}).keys.toList()..sort(),
                  display: (v) => '$v',
                  onChanged: (ch) {
                    if (ch == null || ch == b.selectedChapter) return;
                    b.selectedChapter = ch;
                    widget.onCastVerse();
                  },
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 62,
                child: _RefDropdown<int>(
                  label: 'Vs',
                  value: b.selectedVerse,
                  items: verses,
                  display: (v) => '$v',
                  onChanged: (vs) {
                    if (vs == null || vs == b.selectedVerse) return;
                    b.selectedVerse = vs;
                    widget.onCastVerse();
                  },
                ),
              ),
              const SizedBox(width: 6),
              Text('Verse ${vIdx + 1} of ${verses.length}',
                  style:
                      const TextStyle(color: kMuted, fontSize: 10.5)),
            ]),
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: _onSwipe,
            child: SingleChildScrollView(
              controller: _stageScroll,
              physics: const BouncingScrollPhysics(),
              child: Container(
                constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 280),
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kAccent.withOpacity(0.4)),
                    ),
                    child: Text(ref,
                        style: const TextStyle(
                            color: kAccent,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 18),
                  if (primary.isNotEmpty)
                    Text(
                      primary,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kGold,
                        fontSize: (b.fontSize * 0.85).clamp(20, 52).toDouble(),
                        height: 1.75,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                              color: Colors.black.withOpacity(0.6),
                              blurRadius: 18)
                        ],
                      ),
                    ),
                  if (primary.isNotEmpty && secondary.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text('❖',
                        style: TextStyle(color: kGold, fontSize: 15)),
                    const SizedBox(height: 18),
                  ],
                  if (secondary.isNotEmpty)
                    Text(
                      '"$secondary"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: (b.fontSize * 0.6).clamp(14, 34).toDouble(),
                        height: 1.75,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ]),
              ),
            ),
          ),
          dockLeft: DockNavButton(
            label: 'PREV',
            icon: Icons.skip_previous,
            iconFirst: true,
            onTap: vIdx > 0 ? widget.onPrevVerse : null,
          ),
          dockCenter: _BibleDockCounter(
              tvState: widget.tvState,
              position: 'Verse ${vIdx + 1} of ${verses.length}'),
          dockRight: DockNavButton(
            label: 'NEXT',
            icon: Icons.skip_next,
            onTap: vIdx < verses.length - 1 ? widget.onNextVerse : null,
          ),
        );
      },
    );
  }
}

class _BibleDockCounter extends StatelessWidget {
  final ValueNotifier<Map<String, dynamic>> tvState;
  final String position;
  const _BibleDockCounter({required this.tvState, required this.position});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: tvState,
      builder: (context, state, _) {
        final live = state.isNotEmpty && state['type'] == 'verse';
        return DockCounterPill(
          primary: position,
          secondary: live ? '● Live on TV' : 'Off air',
          accent: live ? Colors.green : kAccent,
        );
      },
    );
  }
}

/// Compact inline scripture selector for the header strip: a bordered
/// capsule with [label: value ▼] and a full list of options. Books follow
/// canonical order (BibleState already sorts its map); chapters and verses
/// sort numerically.
class _RefDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) display;
  final void Function(T?) onChanged;
  final Color accent;

  const _RefDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.display,
    required this.onChanged,
    this.accent = kGold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.5), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          dropdownColor: kBg2,
          borderRadius: BorderRadius.circular(12),
          elevation: 8,
          icon: Icon(Icons.keyboard_arrow_down, size: 15, color: accent),
          style: TextStyle(
              color: accent, fontSize: 11.5, fontWeight: FontWeight.bold),
          selectedItemBuilder: (ctx) => items.map((_) => Text(
                '$label: ${display(value)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold),
              )).toList(),
          items: items
              .map((it) => DropdownMenuItem<T>(
                    value: it,
                    child: Text(display(it),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: kText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
