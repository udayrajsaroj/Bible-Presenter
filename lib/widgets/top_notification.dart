import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Top in-app notification banner that slides down from the top of the screen.
/// Replaces bottom SnackBars so messages never collide with bottom navigation bars,
/// bottom sheets, or URL bars, and guarantees 100% white, high-contrast readable text.
class TopNotification {
  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  /// Shows a top in-app notification banner.
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    // Dismiss any existing notification immediately
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _activeEntry?.remove();
    _activeEntry = null;

    final overlayState = Overlay.maybeOf(context, rootOverlay: true) ??
        Overlay.of(context);

    late final OverlayEntry entry;
    final topPadding = MediaQuery.of(context).padding.top;

    entry = OverlayEntry(
      builder: (ctx) => _TopNotificationWidget(
        message: message,
        isError: isError,
        icon: icon,
        topPadding: topPadding,
        onDismiss: () {
          _dismissTimer?.cancel();
          _dismissTimer = null;
          if (_activeEntry == entry) {
            _activeEntry?.remove();
            _activeEntry = null;
          }
        },
      ),
    );

    _activeEntry = entry;
    overlayState.insert(entry);

    _dismissTimer = Timer(duration, () {
      if (_activeEntry == entry) {
        _activeEntry?.remove();
        _activeEntry = null;
      }
    });
  }
}

class _TopNotificationWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final IconData? icon;
  final double topPadding;
  final VoidCallback onDismiss;

  const _TopNotificationWidget({
    required this.message,
    required this.isError,
    required this.icon,
    required this.topPadding,
    required this.onDismiss,
  });

  @override
  State<_TopNotificationWidget> createState() => _TopNotificationWidgetState();
}

class _TopNotificationWidgetState extends State<_TopNotificationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
    );

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    try {
      await _animCtrl.reverse();
    } catch (_) {}
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final isError = widget.isError;
    final defaultIcon = isError
        ? Icons.error_outline_rounded
        : (widget.message.toLowerCase().contains('copied')
            ? Icons.copy_rounded
            : Icons.check_circle_rounded);

    final iconData = widget.icon ?? defaultIcon;
    final iconColor = isError ? Colors.redAccent : kAccent;

    return Positioned(
      top: widget.topPadding + 10,
      left: 14,
      right: 14,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _handleDismiss,
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta != null && details.primaryDelta! < -4) {
              _handleDismiss();
            }
          },
          child: SlideTransition(
            position: _slideAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isError
                      ? const Color(0xFF230E14)
                      : const Color(0xFF0B1B2F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isError
                        ? Colors.redAccent.withOpacity(0.6)
                        : kAccent.withOpacity(0.5),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                    if (!isError)
                      BoxShadow(
                        color: kAccent.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconData, size: 18, color: iconColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _handleDismiss,
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
