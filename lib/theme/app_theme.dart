import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// BiblePresenter design system — dark-neon glassmorphism (v7 redesign).
///
/// Single source of truth for the palette, gradients, radii and the shared
/// glass surfaces used across the six redesigned screens (Home, Slides,
/// Songs, Bible, Files, Settings) and the glowing bottom navigation.
/// ─────────────────────────────────────────────────────────────────────────

/// Palette — exact hex tokens from the design specification.
class AppColors {
  AppColors._();

  /// Deep Midnight Obsidian — app background base.
  static const Color bg = Color(0xFF060814);

  /// Navy Surface — card base (use via [glass] at 60% opacity).
  static const Color surface = Color(0xFF0D122B);

  /// Solid page-surface variant for stacked chrome.
  static const Color surfaceSolid = Color(0xFF0A0E20);

  /// Subtle electric glow borders.
  static const Color borderWhite = Color(0x14FFFFFF); // white @ 8%
  static const Color borderGlow = Color(0x3338BDF8); // cyan @ 20%

  // Accents
  static const Color cyan = Color(0xFF00D2FF);
  static const Color cyanSoft = Color(0xFF38BDF8);
  static const Color cyanDeep = Color(0xFF38BDF8);
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleSoft = Color(0xFF9333EA);
  static const Color emerald = Color(0xFF10B981);
  static const Color green = Color(0xFF22C55E);
  static const Color orange = Color(0xFFF97316);
  static const Color orangeSoft = Color(0xFFFB923C);
  static const Color gold = Color(0xFFFACC15);
  static const Color goldSoft = Color(0xFFC9A96E);
  static const Color red = Color(0xFFEF4444);
  static const Color pink = Color(0xFFEC4899);

  // Text
  static const Color textHigh = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color inactive = Color(0xFF64748B);
}

/// Gradients — exact stops from the design specification.
class AppGradients {
  AppGradients._();

  static const LinearGradient slides = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0284C7), Color(0xFF00D2FF)],
  );

  static const LinearGradient songs = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7E22CE), Color(0xFFA855F7)],
  );

  static const LinearGradient bible = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF10B981)],
  );

  static const LinearGradient files = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEA580C), Color(0xFFF97316)],
  );

  /// Cast-to-TV banner: slate glass with a cyan glow bloom on the right.
  static const LinearGradient castBanner = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
  );

  static const LinearGradient profile = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
  );

  static const LinearGradient logout = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFEC4899), Color(0xFFEF4444)],
  );

  /// Deep purple/blue pill used by "+ Add Custom Slide".
  static const LinearGradient addSlide = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
  );

  /// Glowing blue pill used by "+ Add to Queue".
  static const LinearGradient addToQueue = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF0284C7), Color(0xFF00D2FF)],
  );

  /// Sunset sky used behind the scripture hero card when no image is set.
  static const LinearGradient scriptureDawn = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF7C3AED)],
  );
}

/// Corner radii.
class AppRadii {
  AppRadii._();

  static const double card = 20;
  static const double cardLg = 24;
  static const double pill = 50;
  static const double button = 16;
  static const double buttonLg = 18;
  static const double thumb = 16;
}

/// Bundled background photography for the Slides hub and hero cards.
class AppAssets {
  AppAssets._();

  static const String heroVerse = 'assets/backgrounds/hero_verse.png';
  static const String slideChurch = 'assets/backgrounds/slide_church.png';
  static const String slideMountains =
      'assets/backgrounds/slide_mountains.png';
  static const String slideBirds = 'assets/backgrounds/slide_birds.png';
  static const String slideFlowers = 'assets/backgrounds/slide_flowers.png';
  static const String slideOcean = 'assets/backgrounds/slide_ocean.png';
  static const String slideNeon = 'assets/backgrounds/slide_neon.png';
  static const String slideBokeh = 'assets/backgrounds/slide_bokeh.png';
}

/// Slide-media catalog shown in the Slides hub grid, grouped by category.
class SlideLibraryItem {
  final String name;
  final String asset;
  final String category; // Church / Nature / Abstract
  const SlideLibraryItem(this.name, this.asset, this.category);
}

const List<SlideLibraryItem> kSlideLibrary = [
  SlideLibraryItem('Church Cross', AppAssets.slideChurch, 'Church'),
  SlideLibraryItem('Mountain Sunrise', AppAssets.slideMountains, 'Nature'),
  SlideLibraryItem('Flight at Dusk', AppAssets.slideBirds, 'Nature'),
  SlideLibraryItem('Meadow Blossoms', AppAssets.slideFlowers, 'Nature'),
  SlideLibraryItem('Living Waters', AppAssets.slideOcean, 'Nature'),
  SlideLibraryItem('Neon Glory', AppAssets.slideNeon, 'Abstract'),
  SlideLibraryItem('Golden Light', AppAssets.slideBokeh, 'Abstract'),
  SlideLibraryItem('Cross at Dawn', AppAssets.heroVerse, 'Church'),
];

/// Global dark theme for the redesigned shell.
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.cyan,
        secondary: AppColors.purple,
        surface: AppColors.surface,
        error: AppColors.red,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textHigh,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: AppColors.textHigh),
      ),
      dividerTheme:
          const DividerThemeData(color: AppColors.borderWhite, thickness: 1),
    );
  }
}

/// Glassmorphic surface decoration: navy @ 60% over the base, hairline white
/// border that catches an optional cyan glow.
BoxDecoration glass({
  double opacity = 0.60,
  double radius = AppRadii.card,
  Color borderColor = AppColors.borderWhite,
  double borderWidth = 1,
  List<BoxShadow>? shadow,
  Gradient? gradient,
}) {
  return BoxDecoration(
    color: gradient == null
        ? AppColors.surface.withOpacity(opacity)
        : null,
    gradient: gradient,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor, width: borderWidth),
    boxShadow: shadow ??
        [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
  );
}

/// Soft radial glow blob (used behind emblems, icons and active indicators).
Widget glowBlob({
  double size = 120,
  Color color = AppColors.cyan,
  double intensity = 0.45,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [color.withOpacity(intensity), color.withOpacity(0.0)],
      ),
    ),
  );
}
