import 'package:flutter/material.dart';

import '../theme.dart';

/// Shared shell for the three presenter screens (Songs / Bible / PDF).
///
/// Layout contract — the reason Prev/Next buttons never move:
///
///   ┌──────────────────────────┐
///   │ header (fixed height)    │
///   ├──────────────────────────┤
///   │ Expanded(               │
///   │   scrollable content)    │  ← all variable-height content lives here
///   ├──────────────────────────┤
///   │ dock (fixed 76dp)        │  ← never inside a scroll view
///   └──────────────────────────┘
///
/// The dock is NOT inside any scrollable and has a fixed height, so whether
/// the stage shows one line or fifteen, the buttons stay at the same pixel
/// coordinates under the user's thumb.
class PresenterScaffold extends StatelessWidget {
  /// Leading widget (usually a back button) — fixed 48dp slot.
  final Widget leading;

  /// Title shown in the header (marquee/truncated).
  final String title;

  /// Optional secondary line under the title.
  final String? subtitle;

  /// TV state notifier — drives the LIVE ON TV / OFF AIR pill.
  final ValueNotifier<Map<String, dynamic>> tvState;

  /// Emergency actions row in the header (logo / blackout / clear).
  final List<Widget> headerActions;

  /// Optional strip below the header (stanza chips, reference chip…).
  final Widget? headerStrip;

  /// Scrollable center stage. MUST be scrollable — it sits inside Expanded.
  final Widget body;

  /// Dock slots.
  final Widget? dockLeft;
  final Widget? dockCenter;
  final Widget? dockRight;

  final bool showLivePill;

  const PresenterScaffold({
    super.key,
    required this.leading,
    required this.title,
    required this.tvState,
    required this.body,
    this.subtitle,
    this.headerActions = const [],
    this.headerStrip,
    this.dockLeft,
    this.dockCenter,
    this.dockRight,
    this.showLivePill = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBg2, kBg],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(children: [
            _PresenterHeader(
              leading: leading,
              title: title,
              subtitle: subtitle,
              tvState: tvState,
              actions: headerActions,
              showLivePill: showLivePill,
            ),
            if (headerStrip != null) headerStrip!,
            Expanded(child: body),
            PresenterDock(
              left: dockLeft,
              center: dockCenter,
              right: dockRight,
            ),
          ]),
        ),
      ),
    );
  }
}

class _PresenterHeader extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final ValueNotifier<Map<String, dynamic>> tvState;
  final List<Widget> actions;
  final bool showLivePill;

  const _PresenterHeader({
    required this.leading,
    required this.title,
    required this.tvState,
    required this.actions,
    required this.showLivePill,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: kBg2,
        border: Border(
            bottom: BorderSide(color: kAccent.withOpacity(0.18), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(children: [
        leading,
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: kText,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3)),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: kMuted, fontSize: 10, height: 1.3)),
            ],
          ),
        ),
        if (showLivePill) ...[
          const SizedBox(width: 6),
          LivePill(tvState: tvState),
        ],
        ...actions,
      ]),
    );
  }
}

/// LIVE ON TV (green) / OFF AIR (muted) indicator pill, follows TV state.
class LivePill extends StatelessWidget {
  final ValueNotifier<Map<String, dynamic>> tvState;
  const LivePill({super.key, required this.tvState});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: tvState,
      builder: (context, state, _) {
        final live = state.isNotEmpty && state['type'] != 'idle';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (live ? Colors.green : kMuted).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: (live ? Colors.green : kMuted).withOpacity(0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: live ? Colors.green : kMuted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(live ? 'LIVE ON TV' : 'OFF AIR',
                style: TextStyle(
                    color: live ? Colors.green : kMuted,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8)),
          ]),
        );
      },
    );
  }
}

/// Fixed-height bottom dock: [left] [center] [right], 76 logical pixels,
/// wrapped in its own bottom SafeArea. Contains NO scrollables.
class PresenterDock extends StatelessWidget {
  final Widget? left;
  final Widget? center;
  final Widget? right;

  const PresenterDock({super.key, this.left, this.center, this.right});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBg2,
        border: Border(
            top: BorderSide(color: kAccent.withOpacity(0.25), width: 1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 12,
              offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              Expanded(child: Align(alignment: Alignment.centerLeft, child: left ?? const SizedBox())),
              SizedBox(width: 96, child: Center(child: center ?? const SizedBox())),
              Expanded(child: Align(alignment: Alignment.centerRight, child: right ?? const SizedBox())),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Large tactile navigation button for the dock (≥48dp tall, ink ripple,
/// clear disabled state).
class DockNavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool iconFirst;
  final VoidCallback? onTap;
  final Color color;

  const DockNavButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.iconFirst = false,
    this.color = kAccent,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = enabled ? color : kMuted;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled ? fg.withOpacity(0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: fg.withOpacity(0.25),
          highlightColor: fg.withOpacity(0.10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 96),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: enabled ? fg.withOpacity(0.55) : kBorder, width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (iconFirst) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
              if (!iconFirst) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 20, color: fg),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Center dock slot: primary counter line + secondary status line.
class DockCounter extends StatelessWidget {
  final String primary;
  final String? secondary;
  final Color accent;
  const DockCounter({super.key, required this.primary, this.secondary, this.accent = kGold});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(primary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: accent,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace')),
      if (secondary != null && secondary!.isNotEmpty)
        Text(secondary!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted, fontSize: 8.5, height: 1.4)),
    ]);
  }
}

/// 48x48 icon button used in presenter headers (logo, blackout, grid…).
class PresenterIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final String tooltip;
  const PresenterIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color = kText,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = enabled ? color : kMuted;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          splashColor: fg.withOpacity(0.25),
          child: SizedBox(
            width: 44,
            height: 48,
            child: Icon(icon, size: 20, color: fg),
          ),
        ),
      ),
    );
  }
}
