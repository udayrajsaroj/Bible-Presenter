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

  void _openJumpSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kBg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => _JumpSheet(
        bibleState: widget.bibleState,
        onVersePicked: () {
          Navigator.pop(ctx);
          widget.onCastVerse();
        },
      ),
    );
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(children: [
              // Reference chip → fast jump sheet.
              Material(
                color: kBg2,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: _openJumpSheet,
                  borderRadius: BorderRadius.circular(20),
                  splashColor: kGold.withOpacity(0.3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kGold.withOpacity(0.6)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(ref,
                          style: const TextStyle(
                              color: kGold,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 5),
                      const Icon(Icons.keyboard_arrow_down,
                          size: 15, color: kGold),
                    ]),
                  ),
                ),
              ),
              const Spacer(),
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
                  const SizedBox(height: 34),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kAccent.withOpacity(0.4)),
                    ),
                    child: Text(ref,
                        style: const TextStyle(
                            color: kAccent,
                            fontSize: 13,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
            ),
          ),
          dockLeft: DockNavButton(
            label: 'PREV VERSE',
            icon: Icons.skip_previous,
            iconFirst: true,
            onTap: vIdx > 0 ? widget.onPrevVerse : null,
          ),
          dockCenter: _BibleDockCounter(
              tvState: widget.tvState,
              position: 'Verse ${vIdx + 1} of ${verses.length}'),
          dockRight: DockNavButton(
            label: 'NEXT VERSE',
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
        return DockCounter(
          primary: position,
          secondary: live ? '● Live on TV' : 'Off air',
          accent: live ? Colors.green : kAccent,
        );
      },
    );
  }
}

/// Fast jump: books → chapters → verses in one scrollable bottom sheet.
/// Picking a verse selects it in BibleState and casts it.
class _JumpSheet extends StatelessWidget {
  final BibleState bibleState;
  final VoidCallback onVersePicked;
  const _JumpSheet({required this.bibleState, required this.onVersePicked});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.72),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        // Rebuild as book/chapter picks change the lists below.
        child: ListenableBuilder(
          listenable: bibleState,
          builder: (context, _) {
            final books = bibleState.bible.keys.toList()..sort();
            final chapters =
                (bibleState.bible[bibleState.selectedBook] ?? {}).keys.toList()
                  ..sort();
            final verses = (bibleState.bible[bibleState.selectedBook]
                        ?[bibleState.selectedChapter] ??
                    {})
                .keys
                .toList()
              ..sort();

            return SingleChildScrollView(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('JUMP TO SCRIPTURE',
                      style: TextStyle(
                          color: kGold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          const Icon(Icons.close, size: 18, color: kMuted)),
                ]),
                const SizedBox(height: 8),
                // Books
                const _SheetSectionLabel('BOOK'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: books.map((book) {
                    final active = book == bibleState.selectedBook;
                    return _SheetChip(
                      label: book,
                      active: active,
                      onTap: () => bibleState.selectedBook = book,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                // Chapters
                const _SheetSectionLabel('CHAPTER'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: chapters.map((ch) {
                    final active = ch == bibleState.selectedChapter;
                    return _SheetChip(
                      label: '$ch',
                      active: active,
                      width: 40,
                      onTap: () => bibleState.selectedChapter = ch,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                // Verses
                const _SheetSectionLabel('VERSE'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: verses.map((vs) {
                    final active = vs == bibleState.selectedVerse;
                    return _SheetChip(
                      label: '$vs',
                      active: active,
                      width: 40,
                      onTap: () {
                        bibleState.selectedVerse = vs;
                        onVersePicked();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),
              ]),
            );
          },
        ),
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  final String text;
  const _SheetSectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: kMuted,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.3)),
      );
}

class _SheetChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final double? width;
  const _SheetChip(
      {required this.label,
      required this.active,
      required this.onTap,
      this.width});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? kGold.withOpacity(0.22) : kBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: kGold.withOpacity(0.3),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: active ? kGold : kBorder, width: active ? 1.5 : 1),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: active ? kGold : kText,
                  fontSize: 11.5,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500)),
        ),
      ),
    );
  }
}
