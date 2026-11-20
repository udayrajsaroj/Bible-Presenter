import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/bible_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/v2/bible_language_sheet.dart';

/// Screen 4 — Bible / Scripture presenter hub (bottom-nav "Preview" tab):
/// language + book selector pills, the interactive scripture hero card with
/// instant verse navigation, the font size slider and the cast action.
class BibleHubScreen extends StatelessWidget {
  final VoidCallback onPrevVerse;
  final VoidCallback onNextVerse;
  final VoidCallback onCastVerse;
  final VoidCallback onImportLanguage;

  const BibleHubScreen({
    super.key,
    required this.onPrevVerse,
    required this.onNextVerse,
    required this.onCastVerse,
    required this.onImportLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<BibleState>(builder: (context, bible, _) {
      final verseData = bible.selectedVerseData ?? const {};
      final ref =
          '${bible.selectedBook} ${bible.selectedChapter}:${bible.selectedVerse}';

      return SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Top bar ──
            Row(children: [
              const Icon(Icons.menu_book_rounded,
                  size: 24, color: AppColors.cyan),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Bible',
                    style: TextStyle(
                        color: AppColors.textHigh,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ),
              IconButton(
                tooltip: 'Jump to book',
                onPressed: () => _pickBook(context, bible),
                icon: const Icon(Icons.search, color: AppColors.textMuted),
              ),
              IconButton(
                tooltip: 'Language & Dual Presenting',
                onPressed: () => _pickLanguage(context, bible),
                icon: const Icon(Icons.tune, color: AppColors.textMuted),
              ),
            ]),

            // ── Dual selector pills ──
            Row(children: [
              Expanded(
                child: _SelectorPill(
                  label: _langName(bible),
                  onTap: () => _pickLanguage(context, bible),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SelectorPill(
                  label: bible.bibleLoaded
                      ? bible.selectedBook
                      : 'Loading…',
                  onTap: () => _pickBook(context, bible),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Interactive scripture hero card ──
            _ScriptureCard(
              ref: ref,
              primary: verseData['primary'] ?? '',
              secondary: verseData['secondary'] ?? '',
              loaded: bible.bibleLoaded,
              onPrev: onPrevVerse,
              onNext: onNextVerse,
            ),
            const SizedBox(height: 14),

            // ── Font size & brightness slider ──
            _FontSlider(fontSize: bible.fontSize),
            const SizedBox(height: 16),

            // ── Cast action ──
            _CastButton(onTap: onCastVerse),
          ]),
        ),
      );
    });
  }

  String _langName(BibleState bible) {
    final p = bible.languages[bible.primaryLang] ?? 'Language';
    if (bible.secondaryLang.isNotEmpty) {
      final s = bible.languages[bible.secondaryLang] ?? bible.secondaryLang;
      return '$p + $s (Dual)';
    }
    return p;
  }

  // ── Pickers ────────────────────────────────────────────────────────────

  void _pickLanguage(BuildContext ctx, BibleState bible) {
    showBibleLanguageSheet(
      context: ctx,
      bible: bible,
      onImportLanguage: onImportLanguage,
    );
  }

  void _pickBook(BuildContext ctx, BibleState bible) {
    if (!bible.bibleLoaded) return;
    final books = bible.bible.keys.toList(); // canonical order
    const otEnd = 'Malachi';
    final otIdx = books.indexOf(otEnd);
    final ot = otIdx >= 0 ? books.sublist(0, otIdx + 1) : books;
    final nt = otIdx >= 0 ? books.sublist(otIdx + 1) : <String>[];

    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AppColors.surfaceSolid,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final otFiltered = filter.isEmpty
                ? ot
                : ot.where((b) => b.toLowerCase().contains(filter)).toList();
            final ntFiltered = filter.isEmpty
                ? nt
                : nt.where((b) => b.toLowerCase().contains(filter)).toList();

            return SafeArea(
              child: SizedBox(
                height: 520,
                child: Column(children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      autofocus: false,
                      onChanged: (q) =>
                          setModalState(() => filter = q.trim().toLowerCase()),
                      style: const TextStyle(
                          color: AppColors.textHigh, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Search 66 books…',
                        hintStyle: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppColors.textMuted, size: 20),
                        suffixIcon: filter.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: AppColors.textMuted, size: 18),
                                onPressed: () =>
                                    setModalState(() => filter = ''),
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surface.withOpacity(0.6),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadii.button),
                          borderSide:
                              const BorderSide(color: AppColors.borderWhite),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadii.button),
                          borderSide:
                              const BorderSide(color: AppColors.borderWhite),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: otFiltered.isEmpty && ntFiltered.isEmpty
                        ? const Center(
                            child: Text('No books matching query',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 13)),
                          )
                        : ListView(children: [
                            if (otFiltered.isNotEmpty) ...[
                              _groupLabel('OLD TESTAMENT'),
                              for (final b in otFiltered)
                                _bookTile(ctx, bible, b, books),
                            ],
                            if (ntFiltered.isNotEmpty) ...[
                              _groupLabel('NEW TESTAMENT'),
                              for (final b in ntFiltered)
                                _bookTile(ctx, bible, b, books),
                            ],
                          ]),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _groupLabel(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
        child: Text(t,
            style: const TextStyle(
                color: AppColors.gold,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4)),
      );

  Widget _bookTile(
      BuildContext ctx, BibleState bible, String book, List<String> books) {
    final active = book == bible.selectedBook;
    return ListTile(
      dense: true,
      leading: Icon(
          active
              ? Icons.radio_button_checked
              : Icons.radio_button_off_rounded,
          color: AppColors.cyan,
          size: 18),
      title: Text(book,
          style: TextStyle(
              color: active ? AppColors.cyan : AppColors.textHigh,
              fontSize: 13.5,
              fontWeight: active ? FontWeight.bold : FontWeight.w500)),
      onTap: () {
        Navigator.pop(ctx);
        bible.selectedBook = book;
      },
    );
  }
}

// ── Selector pill ───────────────────────────────────────────────────────────

class _SelectorPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SelectorPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: glass(
            radius: AppRadii.pill,
            opacity: 0.65,
            borderColor: AppColors.borderGlow,
          ),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textHigh,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppColors.textMuted),
          ]),
        ),
      ),
    );
  }
}

// ── Scripture hero card ─────────────────────────────────────────────────────

class _ScriptureCard extends StatelessWidget {
  final String ref;
  final String primary;
  final String secondary;
  final bool loaded;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _ScriptureCard({
    required this.ref,
    required this.primary,
    required this.secondary,
    required this.loaded,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.cardLg),
        border: Border.all(color: AppColors.borderGlow, width: 1.2),
        boxShadow: [
          BoxShadow(
              color: AppColors.purple.withOpacity(0.20),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.cardLg),
        child: Stack(fit: StackFit.expand, children: [
          Image.asset(AppAssets.heroVerse, fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.45),
                  Colors.black.withOpacity(0.28),
                  Colors.black.withOpacity(0.62),
                ],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ref,
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                  color: Colors.black54, blurRadius: 10)
                            ])),
                    const SizedBox(height: 10),
                    if (primary.isNotEmpty)
                      Text(primary,
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                    color: Colors.black54, blurRadius: 10)
                              ])),
                    if (secondary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('"$secondary"',
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                              shadows: const [
                                Shadow(
                                    color: Colors.black54, blurRadius: 10)
                              ])),
                    ],
                    if (!loaded) ...[
                      const SizedBox(height: 10),
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.cyan)),
                    ],
                  ]),
            ),
          ),
          // Floating circular verse navigation buttons.
          _NavBubble(icon: Icons.arrow_back_ios_new_rounded, onTap: onPrev),
          Positioned(
            right: 10,
            top: 0,
            bottom: 0,
            child: Center(
              child: _bubble(Icons.arrow_forward_ios_rounded, onNext),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _NavBubble({required IconData icon, required VoidCallback onTap}) =>
      Positioned(
        left: 10,
        top: 0,
        bottom: 0,
        child: Center(child: _bubble(icon, onTap)),
      );

  Widget _bubble(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.55),
            border: Border.all(
                color: Colors.white.withOpacity(0.5), width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.4), blurRadius: 10)
            ],
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      );
}

// ── Font size slider ────────────────────────────────────────────────────────

class _FontSlider extends StatelessWidget {
  final int fontSize;
  const _FontSlider({required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: glass(
          radius: AppRadii.pill,
          opacity: 0.55,
          shadow: const []),
      child: Row(children: [
        const Text('A-',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: fontSize.toDouble(),
              min: 24,
              max: 120,
              activeColor: AppColors.cyan,
              inactiveColor: AppColors.borderWhite,
              onChanged: (v) =>
                  context.read<BibleState>().fontSize = v.round(),
            ),
          ),
        ),
        const Icon(Icons.brightness_5_rounded,
            size: 16, color: AppColors.gold),
        const SizedBox(width: 6),
        const Text('A+',
            style: TextStyle(
                color: AppColors.textHigh,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ── Cast button ─────────────────────────────────────────────────────────────

class _CastButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CastButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: AppGradients.addToQueue,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            boxShadow: [
              BoxShadow(
                  color: AppColors.cyan.withOpacity(0.45), blurRadius: 20),
            ],
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text('Add to Queue  •  Cast to TV',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold)),
              ]),
        ),
      ),
    );
  }
}
