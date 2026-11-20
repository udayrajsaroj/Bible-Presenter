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
          const _HeroVerseCard(),
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
  const _HeroVerseCard();

  @override
  Widget build(BuildContext context) {
    // Real verse of the day when the bible is loaded, else the default quote.
    const fallback = 'For where two or three gather in my name, '
        'there am I with them.';
    String verse = fallback;
    final bible = context.watch<BibleState>();
    final matthew = bible.bible['Matthew'];
    final data = matthew?[18]?[20];
    if (data != null) {
      final primary = data['primary'] ?? '';
      if (primary.isNotEmpty) verse = primary;
    }

    return Container(
      height: 172,
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
          // Readability scrim over the left half.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withOpacity(0.62),
                  Colors.black.withOpacity(0.12),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 0.85],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 120, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text('“$verse”',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textHigh,
                        fontSize: 16.5,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 10)
                        ],
                      )),
                ),
              ],
            ),
          ),
          // Reference pill — bottom-left, gold.
          Positioned(
            left: 16,
            bottom: 14,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: AppColors.gold.withOpacity(0.5)),
              ),
              child: const Text('Matthew 18:20',
                  style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
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
