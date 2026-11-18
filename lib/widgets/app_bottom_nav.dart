import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Glowing bottom navigation — 4 tabs with the active item in cyan
/// (icon + label) over a soft radial glow and a short underline bar.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    (label: 'Home', icon: Icons.home_rounded),
    (label: 'Preview', icon: Icons.tv_rounded),
    (label: 'Library', icon: Icons.grid_view_rounded),
    (label: 'More', icon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSolid.withOpacity(0.92),
        border: const Border(
          top: BorderSide(color: AppColors.borderWhite, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    data: _items[i],
                    active: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final ({String label, IconData icon}) data;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.data,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.cyan : AppColors.inactive;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
          if (active)
            Positioned(
              child: Container(
                width: 44,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.cyan.withOpacity(0.28),
                    AppColors.cyan.withOpacity(0.0),
                  ]),
                ),
              ),
            ),
          Icon(data.icon, size: 24, color: color),
        ]),
        const SizedBox(height: 3),
        Text(
          data.label,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        // Glowing underline indicator under the active tab.
        Container(
          width: 26,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: active ? AppColors.cyan : Colors.transparent,
            boxShadow: active
                ? [
                    BoxShadow(
                        color: AppColors.cyan.withOpacity(0.7),
                        blurRadius: 8,
                        spreadRadius: 0.5)
                  ]
                : null,
          ),
        ),
      ]),
    );
  }
}
