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
    ..sort((a, b) => (int.tryParse(a.toString()) ?? 0)
        .compareTo(int.tryParse(b.toString()) ?? 0));

  void _onSwipe(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dx;
    if (v < -120) widget.onNextVerse();
    if (v > 120) widget.onPrevVerse();
  }

  void _openScripturePicker(int initialTab) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ScriptureGridPicker(
        bibleState: widget.bibleState,
        initialTab: initialTab,
        onVersePicked: () {
          Navigator.pop(ctx);
          widget.onCastVerse();
        },
        onStateChanged: () {
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

        final chList = (b.selectedBookChapters ?? {}).keys.toList()
          ..sort((a, b) => (int.tryParse(a.toString()) ?? 0)
              .compareTo(int.tryParse(b.toString()) ?? 0));
        final chIdx = chList.indexOf(b.selectedChapter);
        final books = b.bible.keys.toList();
        final bIdx = books.indexOf(b.selectedBook);
        final hasNext = (vIdx < verses.length - 1) ||
            (chIdx < chList.length - 1) ||
            (bIdx < books.length - 1);
        final hasPrev = (vIdx > 0) || (chIdx > 0) || (bIdx > 0);

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
              // Three inline scripture selectors opening the full-screen curved grid picker
              Expanded(
                flex: 4,
                child: _RefPillButton(
                  text: 'Book: ${b.selectedBook}',
                  onTap: () => _openScripturePicker(0),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 2,
                child: _RefPillButton(
                  text: 'Ch: ${b.selectedChapter}',
                  onTap: () => _openScripturePicker(1),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 2,
                child: _RefPillButton(
                  text: 'Vs: ${b.selectedVerse}',
                  onTap: () => _openScripturePicker(2),
                ),
              ),
              const SizedBox(width: 6),
              Text('Verse ${vIdx + 1} of ${verses.length}',
                  style: const TextStyle(color: kMuted, fontSize: 10.5)),
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
                        fontSize: 18,
                        height: 1.6,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                              color: Colors.black.withOpacity(0.6),
                              blurRadius: 18)
                        ],
                      ),
                    ),
                  if (primary.isNotEmpty && secondary.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('❖',
                        style: TextStyle(color: kGold, fontSize: 13)),
                    const SizedBox(height: 14),
                  ],
                  if (secondary.isNotEmpty)
                    Text(
                      '"$secondary"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.55,
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
            onTap: hasPrev ? widget.onPrevVerse : null,
          ),
          dockCenter: _BibleDockCounter(
              tvState: widget.tvState,
              position: 'Verse ${vIdx + 1} of ${verses.length}'),
          dockRight: DockNavButton(
            label: 'NEXT',
            icon: Icons.skip_next,
            onTap: hasNext ? widget.onNextVerse : null,
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

/// Tactile curved button in the header strip for [Book], [Ch], [Vs]
class _RefPillButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  static const Color accent = kGold;

  const _RefPillButton({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kBg2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: accent.withOpacity(0.2),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withOpacity(0.55), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.keyboard_arrow_down, size: 14, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fullscreen/modal curved button grid selector for Book, Chapter, and Verse.
/// Arranges options 3-4 in a row with tactile curved buttons and quick filtering.
class _ScriptureGridPicker extends StatefulWidget {
  final BibleState bibleState;
  final int initialTab; // 0: Book, 1: Chapter, 2: Verse
  final VoidCallback onVersePicked;
  final VoidCallback onStateChanged;

  const _ScriptureGridPicker({
    required this.bibleState,
    required this.initialTab,
    required this.onVersePicked,
    required this.onStateChanged,
  });

  @override
  State<_ScriptureGridPicker> createState() => _ScriptureGridPickerState();
}

class _ScriptureGridPickerState extends State<_ScriptureGridPicker> {
  late int _tab;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _division = 0; // 0: ALL, 1: OT, 2: NT

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bibleState;
    final allBooks = b.bible.keys.toList(); // canonical order
    final chList = (b.selectedBookChapters ?? {}).keys.toList()
      ..sort((a, b) => (int.tryParse(a.toString()) ?? 0)
          .compareTo(int.tryParse(b.toString()) ?? 0));
    final vList =
        (b.selectedBookChapters?[b.selectedChapter] ?? {}).keys.toList()
          ..sort((a, b) => (int.tryParse(a.toString()) ?? 0)
              .compareTo(int.tryParse(b.toString()) ?? 0));

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: kAccent.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: kMuted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Top bar: breadcrumb + close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.menu_book, size: 16, color: kGold),
                  const SizedBox(width: 8),
                  Text(
                    '${b.selectedBook} ${b.selectedChapter}:${b.selectedVerse}',
                    style: const TextStyle(
                      color: kGold,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ]),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: kMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: kBorder, height: 1),
          // 3-tab selector: BOOKS, CHAPTERS, VERSES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Expanded(
                child: _tabPill(
                  index: 0,
                  label: '1. BOOKS',
                  active: _tab == 0,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _tabPill(
                  index: 1,
                  label: '2. CHAPTER (${chList.length})',
                  active: _tab == 1,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _tabPill(
                  index: 2,
                  label: '3. VERSE (${vList.length})',
                  active: _tab == 2,
                ),
              ),
            ]),
          ),
          // Content for active tab
          Expanded(
            child: _tab == 0
                ? _buildBooksGrid(allBooks, b)
                : _tab == 1
                    ? _buildChaptersGrid(chList, b)
                    : _buildVersesGrid(vList, b),
          ),
        ]),
      ),
    );
  }

  Widget _tabPill({
    required int index,
    required String label,
    required bool active,
  }) {
    return Material(
      color: active ? kGold.withOpacity(0.18) : kBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? kGold : kBorder,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? kGold : kMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBooksGrid(List<String> allBooks, BibleState b) {
    // 39 OT books, 27 NT books
    final filtered = allBooks.where((book) {
      if (_searchQuery.isNotEmpty) {
        if (!book.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      final idx = allBooks.indexOf(book);
      if (_division == 1 && idx >= 39) return false; // OT only
      if (_division == 2 && idx < 39) return false;  // NT only
      return true;
    }).toList();

    return Column(children: [
      // Search and OT/NT filter chips
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(children: [
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                const Icon(Icons.search, size: 16, color: kMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: kText, fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Search 66 books...',
                      hintStyle: TextStyle(color: kMuted, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (q) => setState(() => _searchQuery = q),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(Icons.close, size: 14, color: kMuted),
                  ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          _divisionChip(0, 'ALL'),
          const SizedBox(width: 4),
          _divisionChip(1, 'OT'),
          const SizedBox(width: 4),
          _divisionChip(2, 'NT'),
        ]),
      ),
      const SizedBox(height: 6),
      // 3 in a row curved buttons
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.3,
          ),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) {
            final book = filtered[i];
            final selected = book == b.selectedBook;
            return _curvedButton(
              label: book,
              selected: selected,
              fontSize: 11.5,
              onTap: () {
                b.selectedBook = book;
                widget.onStateChanged();
                setState(() => _tab = 1); // automatically step to Chapter grid
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _divisionChip(int div, String label) {
    final active = _division == div;
    return GestureDetector(
      onTap: () => setState(() => _division = div),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? kAccent.withOpacity(0.2) : kBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? kAccent : kBorder,
            width: active ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? kAccent : kMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildChaptersGrid(List<int> chList, BibleState b) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          '${b.selectedBook} — Select Chapter',
          style: const TextStyle(
            color: kMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.5,
          ),
          itemCount: chList.length,
          itemBuilder: (ctx, i) {
            final ch = chList[i];
            final selected = ch == b.selectedChapter;
            return _curvedButton(
              label: '$ch',
              selected: selected,
              fontSize: 14,
              onTap: () {
                b.selectedChapter = ch;
                widget.onStateChanged();
                setState(() => _tab = 2); // automatically step to Verse grid
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildVersesGrid(List<int> vList, BibleState b) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          '${b.selectedBook} ${b.selectedChapter} — Select Verse',
          style: const TextStyle(
            color: kMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.5,
          ),
          itemCount: vList.length,
          itemBuilder: (ctx, i) {
            final vs = vList[i];
            final selected = vs == b.selectedVerse;
            return _curvedButton(
              label: '$vs',
              selected: selected,
              fontSize: 14,
              onTap: () {
                b.selectedVerse = vs;
                widget.onVersePicked(); // picks verse, casts, and closes modal
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _curvedButton({
    required String label,
    required bool selected,
    required double fontSize,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? kGold.withOpacity(0.22) : kBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        splashColor: kGold.withOpacity(0.25),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? kGold : kBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? kGold : kText,
              fontSize: fontSize,
              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
