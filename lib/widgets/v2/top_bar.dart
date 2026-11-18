import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Shared hub top bar: leading widget, small accent icon + bold title on the
/// left, and trailing actions (search / filter / view toggles).
class TopBarV2 extends StatelessWidget {
  final Widget? leading;
  final IconData icon;
  final String title;
  final List<Widget> actions;

  const TopBarV2({
    super.key,
    this.leading,
    required this.icon,
    required this.title,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(children: [
        leading ?? const SizedBox(width: 8),
        const SizedBox(width: 8),
        Icon(icon, size: 22, color: AppColors.cyan),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  color: AppColors.textHigh,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ),
        ...actions,
      ]),
    );
  }
}

/// Horizontal capsule filter pills row (All / English / Hindi / …).
class FilterPills extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;
  final Color activeColor;

  const FilterPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.activeColor = AppColors.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final opt = options[i];
          final sel = opt == selected;
          return GestureDetector(
            onTap: () => onSelect(opt),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                color: sel ? null : const Color(0xFF0F172A),
                gradient: sel
                    ? LinearGradient(colors: [
                        activeColor.withOpacity(0.85),
                        activeColor.withOpacity(0.65)
                      ])
                    : null,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                  color: sel
                      ? activeColor.withOpacity(0.8)
                      : AppColors.borderWhite,
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                            color: activeColor.withOpacity(0.35),
                            blurRadius: 12)
                      ]
                    : null,
              ),
              child: Text(opt,
                  style: TextStyle(
                      color: sel ? Colors.white : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }
}
