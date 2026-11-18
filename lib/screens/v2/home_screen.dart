import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/bible_state.dart';
import '../../theme/app_theme.dart';

/// Screen 1 — Home dashboard: glowing emblem header, hero verse-of-the-day
/// card, the 2×2 feature grid and the Cast to TV banner.
class HomeScreen extends StatelessWidget {
  final VoidCallback onOpenSlides;
  final VoidCallback onOpenSongs;
  final VoidCallback onOpenBible;
  final VoidCallback onOpenFiles;
  final VoidCallback onOpenSettings;
  final VoidCallback onCastToTV;

  const HomeScreen({
    super.key,
    required this.onOpenSlides,
    required this.onOpenSongs,
    required this.onOpenBible,
    required this.onOpenFiles,
    required this.onOpenSettings,
    required this.onCastToTV,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Header(onSettings: onOpenSettings),
        const SizedBox(height: 18),
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
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onSettings;
  const _Header({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Column(children: [
        const SizedBox(height: 8),
        const _Emblem(),
        const SizedBox(height: 12),
        const Text('BiblePresenter',
            style: TextStyle(
                color: AppColors.textHigh,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3)),
        const SizedBox(height: 4),
        const Text('Present • Worship • Share',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
                letterSpacing: 1.1)),
        const SizedBox(height: 10),
      ]),
      // Settings gear — top-right action.
      Positioned(
        top: 0,
        right: 0,
        child: IconButton(
          tooltip: 'Settings',
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined,
              color: AppColors.textMuted, size: 24),
        ),
      ),
    ]);
  }
}

/// Centered glowing emblem: golden open Bible with a radiant cross above,
/// white/gold light rays behind (built from a radial bloom + drawn cross).
class _Emblem extends StatelessWidget {
  const _Emblem();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 120,
      child: Stack(alignment: Alignment.center, children: [
        // Radiant glow behind the emblem.
        Container(
          width: 150,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              Colors.amber.withOpacity(0.38),
              Colors.amber.withOpacity(0.10),
              Colors.transparent,
            ], stops: const [0.0, 0.55, 1.0]),
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          // The cross — two rounded golden bars with a soft glow.
          Container(
            width: 44,
            height: 52,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                    color: Colors.amberAccent.withOpacity(0.55),
                    blurRadius: 22,
                    spreadRadius: 2),
              ],
            ),
            child: CustomPaint(painter: _CrossPainter()),
          ),
          const SizedBox(height: 6),
          // Open golden Bible.
          const Icon(Icons.menu_book_rounded,
              size: 40, color: Color(0xFFF5C842)),
        ]),
      ]),
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF5C842)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.16;
    final cx = size.width / 2;
    // Vertical beam.
    canvas.drawLine(Offset(cx, size.height * 0.06),
        Offset(cx, size.height * 0.94), paint);
    // Horizontal beam (classic Latin cross proportions).
    canvas.drawLine(Offset(size.width * 0.14, size.height * 0.32),
        Offset(size.width * 0.86, size.height * 0.32), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
