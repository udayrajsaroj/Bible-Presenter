import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// A generic full-screen overlay for any section (Slides, Bible, Songs, Files).
///
/// Content and controls are provided as BUILDERS (not static snapshots) so they
/// rebuild live whenever [refresh] is called — e.g. when the user taps Prev/Next.
/// The controls builder receives a `refresh` callback: call it after mutating
/// the parent state so the fullscreen view re-reads the latest values.
/// Controllers are ALWAYS visible — they never auto-hide.
class SectionFullscreen extends StatefulWidget {
  final String sectionTitle;           // e.g. "BIBLE", "SLIDES", "SONGS"
  final IconData sectionIcon;          // e.g. Icons.menu_book
  final Color sectionColor;            // e.g. kAccent, kGold, Colors.purple
  final Widget Function() contentBuilder;                       // main content (rebuilt each refresh)
  final List<Widget> Function(VoidCallback refresh) controlsBuilder; // bottom controls
  final VoidCallback onExit;           // Exit fullscreen
  final String? bgImageUrl;            // Optional background image URL
  final Map<String, dynamic> tvState;  // Current TV state for quick actions
  final VoidCallback? onBlackout;
  final VoidCallback? onWelcome;
  final VoidCallback? onLogo;

  const SectionFullscreen({
    super.key,
    required this.sectionTitle,
    required this.sectionIcon,
    required this.sectionColor,
    required this.contentBuilder,
    required this.controlsBuilder,
    required this.onExit,
    this.bgImageUrl,
    required this.tvState,
    this.onBlackout,
    this.onWelcome,
    this.onLogo,
  });

  @override
  State<SectionFullscreen> createState() => _SectionFullscreenState();
}

class _SectionFullscreenState extends State<SectionFullscreen> {
  @override
  void initState() {
    super.initState();
    // Enter immersive landscape mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Restore portrait mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  /// Re-read parent state and rebuild the fullscreen view (no flicker).
  void _refresh() {
    if (mounted) setState(() {});
  }

  Widget _quickAction(IconData icon, Color color, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // ── Background image (if set) ──
        if (widget.bgImageUrl != null)
          Positioned.fill(
            child: Image.network(
              widget.bgImageUrl!,
              fit: BoxFit.cover,
              color: Colors.black.withValues(alpha: 0.55),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

        // ── Gradient overlay ──
        Positioned.fill(child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)], radius: 1.2),
          ),
        )),

        // ── Main content area (center, live-rebuilt) ──
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 64, bottom: 88, left: 24, right: 24),
              child: Center(child: widget.contentBuilder()),
            ),
          ),
        ),

        // ── Top bar: section indicator + quick actions + exit ──
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(children: [
                // Section badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.sectionColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.sectionColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(widget.sectionIcon, size: 16, color: widget.sectionColor),
                    const SizedBox(width: 6),
                    Text(widget.sectionTitle,
                      style: TextStyle(color: widget.sectionColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ]),
                ),
                const Spacer(),

                // Quick actions (live TV controls)
                if (widget.onBlackout != null)
                  _quickAction(Icons.dark_mode, Colors.red, () { widget.onBlackout!(); _refresh(); }),
                if (widget.onWelcome != null)
                  _quickAction(Icons.waving_hand, Colors.green, () { widget.onWelcome!(); _refresh(); }),
                if (widget.onLogo != null)
                  _quickAction(Icons.church, kGold, () { widget.onLogo!(); _refresh(); }),

                // Exit button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onExit,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade700.withValues(alpha: 0.5)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.close, size: 16, color: Colors.red),
                        SizedBox(width: 6),
                        Text('Exit', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── Bottom controls: ALWAYS VISIBLE, live-rebuilt ──
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, const Color(0xFF060c18).withValues(alpha: 0.95)],
                ),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: widget.controlsBuilder(_refresh)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Shared fullscreen control buttons (consistent look across sections) ──

/// A large Prev/Next style nav button used inside fullscreen controls.
Widget fsNavBtn({required IconData icon, required String label, required bool iconFirst, VoidCallback? onTap}) => Material(
  color: Colors.transparent,
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Ink(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: onTap != null ? 0.08 : 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: onTap != null ? 0.12 : 0.05)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (iconFirst) ...[Icon(icon, color: onTap != null ? Colors.white70 : Colors.white24, size: 22), const SizedBox(width: 6)],
        Text(label, style: TextStyle(color: onTap != null ? Colors.white70 : Colors.white24, fontSize: 14, fontWeight: FontWeight.w600)),
        if (!iconFirst) ...[const SizedBox(width: 6), Icon(icon, color: onTap != null ? Colors.white70 : Colors.white24, size: 22)],
      ]),
    ),
  ),
);

/// The central Cast button used inside fullscreen controls.
Widget fsCastBtn({required String label, required List<Color> gradient, required VoidCallback onTap}) => Material(
  color: Colors.transparent,
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Ink(
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: gradient.first.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cast, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
    ),
  ),
);
