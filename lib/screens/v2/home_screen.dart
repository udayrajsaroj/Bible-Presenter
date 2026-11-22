import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/bible_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/presenter_shell.dart';

/// Screen 1 — Home dashboard: compact presenter-style header (title + LIVE
/// pill + Logo / Blackout / Settings quick actions, mirroring the header used
/// for logo and blackout presentation), hero verse-of-the-day card, the 2×2
/// feature grid and the Cast to TV banner.
class HomeScreen extends StatelessWidget {
  final ValueNotifier<Map<String, dynamic>> tvState;
  final VoidCallback onOpenSlides;
  final VoidCallback onOpenSongs;
  final VoidCallback onOpenBible;
  final VoidCallback onOpenFiles;
  final VoidCallback onOpenSettings;
  final VoidCallback onCastLogo;
  final VoidCallback onCastBlackout;
  final VoidCallback onCastToTV;

  const HomeScreen({
    super.key,
    required this.tvState,
    required this.onOpenSlides,
    required this.onOpenSongs,
    required this.onOpenBible,
    required this.onOpenFiles,
    required this.onOpenSettings,
    required this.onCastLogo,
    required this.onCastBlackout,
    required this.onCastToTV,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Header(
            tvState: tvState,
            onSettings: onOpenSettings,
            onCastLogo: onCastLogo,
            onCastBlackout: onCastBlackout,
          ),
          const SizedBox(height: 14),
          _HeroVerseCard(onTap: onOpenBible),
          const SizedBox(height: 18),
          _FeatureGrid(
            onSlides: onOpenSlides,
            onSongs: onOpenSongs,
            onBible: onOpenBible,
            onFiles: onOpenFiles,
          ),
          const SizedBox(height: 18),
          _CastBanner(onTap: onCastToTV),
        ]),
      ),
    );
  }
}

// ── Header (presenter-style compact bar) ────────────────────────────────────

/// Same design as the presenter screens' header (`PresenterScaffold`): small
/// brand mark + bold title/subtitle on the left, LIVE ON TV / OFF AIR pill,
/// and the Logo / Blackout / Settings quick-action icon buttons on the right.
class _Header extends StatelessWidget {
  final ValueNotifier<Map<String, dynamic>> tvState;
  final VoidCallback onSettings;
  final VoidCallback onCastLogo;
  final VoidCallback onCastBlackout;

  const _Header({
    required this.tvState,
    required this.onSettings,
    required this.onCastLogo,
    required this.onCastBlackout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderGlow, width: 1),
        ),
      ),
      child: Row(children: [
        const _BrandMark(),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BiblePresenter',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppColors.textHigh,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2)),
              SizedBox(height: 1),
              Text('Present • Worship • Share',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9.5,
                      height: 1.2,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
        const SizedBox(width: 4),
        LivePill(tvState: tvState),
        const SizedBox(width: 2),
        _HeaderAction(
          icon: Icons.church,
          color: AppColors.gold,
          tooltip: 'Cast Logo',
          onTap: onCastLogo,
        ),
        _HeaderAction(
          icon: Icons.dark_mode,
          color: Colors.red.shade400,
          tooltip: 'Blackout',
          onTap: onCastBlackout,
        ),
        _HeaderAction(
          icon: Icons.settings_outlined,
          color: AppColors.textMuted,
          tooltip: 'Settings',
          onTap: onSettings,
        ),
      ]),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 32,
            height: 38,
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

/// Small brand mark for the leading slot — a compact glass chip holding the
/// golden open Bible with a soft amber glow (the emblem, miniaturized).
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.amber.withOpacity(0.22),
              blurRadius: 10,
              spreadRadius: 1),
        ],
      ),
      child: const Icon(Icons.menu_book_rounded,
          size: 19, color: Color(0xFFF5C842)),
    );
  }
}

// ── Hero verse card ─────────────────────────────────────────────────────────

class _HeroVerseCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _HeroVerseCard({this.onTap});

  static const List<(String, int, int)> _dailyVerses = [
    ('Matthew', 18, 20),
    ('Jeremiah', 29, 11),
    ('Philippians', 4, 13),
    ('Proverbs', 3, 5),
    ('Romans', 8, 28),
    ('Isaiah', 40, 31),
    ('Joshua', 1, 9),
    ('Psalms', 23, 1),
    ('Matthew', 11, 28),
    ('John', 3, 16),
    ('Romans', 12, 2),
    ('Psalms', 46, 1),
    ('2 Timothy', 1, 7),
    ('Galatians', 5, 22),
    ('Ephesians', 2, 8),
    ('Matthew', 6, 33),
    ('Psalms', 119, 105),
    ('1 Corinthians', 13, 13),
    ('Isaiah', 41, 10),
    ('Hebrews', 11, 1),
    ('Matthew', 28, 20),
    ('Psalms', 118, 24),
    ('Philippians', 4, 6),
    ('Romans', 15, 13),
    ('Psalms', 91, 1),
    ('1 Peter', 5, 7),
    ('Lamentations', 3, 22),
    ('Psalms', 121, 2),
    ('Colossians', 3, 23),
    ('1 Thessalonians', 5, 16),
    ('Psalms', 37, 4),
    ('Zephaniah', 3, 17),
    ('Proverbs', 16, 3),
    ('Isaiah', 26, 3),
    ('Psalms', 103, 1),
    ('Micah', 6, 8),
    ('Psalms', 27, 1),
    ('Romans', 8, 31),
    ('2 Corinthians', 5, 17),
    ('Psalms', 34, 8),
    ('James', 1, 5),
    ('Psalms', 19, 14),
    ('Proverbs', 4, 23),
    ('John', 14, 6),
    ('Psalms', 62, 1),
    ('Isaiah', 43, 2),
    ('2 Corinthians', 12, 9),
    ('Psalms', 139, 14),
    ('Deuteronomy', 31, 6),
    ('1 John', 4, 19),
    ('Psalms', 16, 11),
    ('Romans', 8, 38),
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayIndex = DateTime(now.year, now.month, now.day)
            .difference(DateTime(2026, 1, 1))
            .inDays
            .abs();
    final item = _dailyVerses[dayIndex % _dailyVerses.length];
    final book = item.$1;
    final ch = item.$2;
    final vs = item.$3;
    final refLabel = '$book $ch:$vs';

    final bible = context.watch<BibleState>();
    final bookData = bible.bible[book];
    final verseData = bookData?[ch]?[vs];
    final primary = verseData?['primary'] ?? verseData?['secondary'] ?? '';
    final verse = primary.isNotEmpty ? primary : '...';

    return GestureDetector(
      onTap: () {
        if (onTap != null && bible.bibleLoaded) {
          bible.selectedBook = book;
          bible.selectedChapter = ch;
          bible.selectedVerse = vs;
          onTap!();
        }
      },
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.cardLg),
          border: Border.all(color: AppColors.borderGlow, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withOpacity(0.18),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.cardLg),
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(AppAssets.heroVerse, fit: BoxFit.cover),
            // High contrast readability overlay across entire card
            Container(
              color: Colors.black.withOpacity(0.55),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        '“$verse”',
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textHigh,
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 10)
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Centered Reference pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(
                          color: AppColors.gold.withOpacity(0.6), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      refLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── 2×2 feature grid ────────────────────────────────────────────────────────

class _FeatureGrid extends StatelessWidget {
  final VoidCallback onSlides, onSongs, onBible, onFiles;
  const _FeatureGrid({
    required this.onSlides,
    required this.onSongs,
    required this.onBible,
    required this.onFiles,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(
          child: _FeatureTile(
            gradient: AppGradients.slides,
            icon: Icons.present_to_all_rounded,
            title: 'Slides',
            onTap: onSlides,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _FeatureTile(
            gradient: AppGradients.songs,
            icon: Icons.music_note_rounded,
            title: 'Songs',
            onTap: onSongs,
          ),
        ),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: _FeatureTile(
            gradient: AppGradients.bible,
            icon: Icons.menu_book_rounded,
            title: 'Bible',
            onTap: onBible,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _FeatureTile(
            gradient: AppGradients.files,
            icon: Icons.folder_rounded,
            title: 'Files',
            onTap: onFiles,
          ),
        ),
      ]),
    ]);
  }
}

class _FeatureTile extends StatelessWidget {
  final Gradient gradient;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          height: 112,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppRadii.card),
            boxShadow: [
              BoxShadow(
                color: (gradient.colors.last).withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: Colors.white),
              ),
              const SizedBox(height: 7),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(title,
                    maxLines: 1,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Cast to TV banner ───────────────────────────────────────────────────────

class _CastBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _CastBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: glass(
            radius: AppRadii.card,
            borderColor: AppColors.borderGlow,
            gradient: AppGradients.castBanner,
            shadow: [
              BoxShadow(
                color: AppColors.cyan.withOpacity(0.16),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.cyan.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cyan.withOpacity(0.5)),
              ),
              child: const Icon(Icons.cast, size: 22, color: AppColors.cyan),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cast to TV',
                      style: TextStyle(
                          color: AppColors.textHigh,
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Share your presentation',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 24),
          ]),
        ),
      ),
    );
  }
}
