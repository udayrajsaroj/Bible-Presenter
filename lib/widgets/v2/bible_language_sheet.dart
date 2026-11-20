import 'package:flutter/material.dart';

import '../../state/bible_state.dart';
import '../../theme/app_theme.dart';

/// Modal bottom sheet for Bible language & Dual Language presentation settings.
/// Allows setting Primary language (large on TV), Secondary language (subtext on TV),
/// instant one-tap dual presets (Hindi + English, English + Hindi, etc.),
/// and importing new VerseVIEW XML translations.
Future<void> showBibleLanguageSheet({
  required BuildContext context,
  required BibleState bible,
  VoidCallback? onImportLanguage,
  VoidCallback? onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceSolid,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => AnimatedBuilder(
      animation: bible,
      builder: (sheetContext, _) => BibleLanguageSheet(
        bible: bible,
        onImportLanguage: onImportLanguage,
        onChanged: onChanged,
      ),
    ),
  );
}

class BibleLanguageSheet extends StatelessWidget {
  final BibleState bible;
  final VoidCallback? onImportLanguage;
  final VoidCallback? onChanged;

  const BibleLanguageSheet({
    super.key,
    required this.bible,
    this.onImportLanguage,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;
    final langs = bible.languages.entries.toList();

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ──
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ──
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cyan.withOpacity(0.35)),
                  ),
                  child: const Icon(Icons.translate_rounded,
                      size: 20, color: AppColors.cyan),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bible Languages & Dual Presenting',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Display two languages simultaneously on TV & phone',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 22, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
              const SizedBox(height: 14),

              // ── Dual Language Presentation Toggle Card ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bible.isDualLanguage
                      ? AppColors.purple.withOpacity(0.14)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: bible.isDualLanguage
                        ? AppColors.purple.withOpacity(0.55)
                        : AppColors.borderGlow,
                    width: 1.2,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (bible.isDualLanguage
                              ? AppColors.purple
                              : AppColors.textMuted)
                          .withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.layers_rounded,
                      color: bible.isDualLanguage
                          ? AppColors.purple
                          : AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dual Language Presenting',
                          style: TextStyle(
                            color: AppColors.textHigh,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bible.isDualLanguage
                              ? 'Active: ${bible.languages[bible.primaryLang]} + ${bible.languages[bible.secondaryLang]}'
                              : 'Single language presentation mode',
                          style: TextStyle(
                            color: bible.isDualLanguage
                                ? AppColors.purple
                                : AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: bible.isDualLanguage
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: bible.isDualLanguage,
                    activeThumbColor: AppColors.purple,
                    activeTrackColor: AppColors.purple.withOpacity(0.4),
                    onChanged: (val) {
                      bible.toggleDualLanguage(val);
                      onChanged?.call();
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Quick Presets ──
              const Text(
                'QUICK DUAL PRESETS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PresetChip(
                    label: 'Hindi + English',
                    badge: 'DUAL',
                    isSelected: bible.primaryLang == 'hi' &&
                        bible.secondaryLang == 'en',
                    onTap: () {
                      bible.setDualPreset(primary: 'hi', secondary: 'en');
                      onChanged?.call();
                    },
                  ),
                  _PresetChip(
                    label: 'English + Hindi',
                    badge: 'DUAL',
                    isSelected: bible.primaryLang == 'en' &&
                        bible.secondaryLang == 'hi',
                    onTap: () {
                      bible.setDualPreset(primary: 'en', secondary: 'hi');
                      onChanged?.call();
                    },
                  ),
                  _PresetChip(
                    label: 'Hindi only',
                    badge: null,
                    isSelected: bible.primaryLang == 'hi' &&
                        bible.secondaryLang.isEmpty,
                    onTap: () {
                      bible.setDualPreset(primary: 'hi', secondary: '');
                      onChanged?.call();
                    },
                  ),
                  _PresetChip(
                    label: 'English only',
                    badge: null,
                    isSelected: bible.primaryLang == 'en' &&
                        bible.secondaryLang.isEmpty,
                    onTap: () {
                      bible.setDualPreset(primary: 'en', secondary: '');
                      onChanged?.call();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Primary Language Section ──
              Row(children: [
                const Text(
                  'PRIMARY LANGUAGE',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Large on TV',
                      style: TextStyle(
                          color: AppColors.cyan,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 6),
              ...langs.map((e) => _LangOptionRow(
                    name: e.value,
                    subtitle: 'Primary verse text',
                    isSelected: bible.primaryLang == e.key,
                    accentColor: AppColors.cyan,
                    onTap: () {
                      bible.primaryLang = e.key;
                      onChanged?.call();
                    },
                  )),
              const SizedBox(height: 16),

              // ── Secondary Language Section ──
              Row(children: [
                const Text(
                  'SECONDARY LANGUAGE (DUAL)',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Subtext on TV & Phone',
                      style: TextStyle(
                          color: AppColors.purple,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 6),
              _LangOptionRow(
                name: 'None (Single Language)',
                subtitle: 'Do not show second language',
                isSelected: bible.secondaryLang.isEmpty,
                accentColor: AppColors.purple,
                onTap: () {
                  bible.secondaryLang = '';
                  onChanged?.call();
                },
              ),
              ...langs.map((e) {
                if (e.key == bible.primaryLang) return const SizedBox.shrink();
                return _LangOptionRow(
                  name: e.value,
                  subtitle: 'Second language under primary verse in italics',
                  isSelected: bible.secondaryLang == e.key,
                  accentColor: AppColors.purple,
                  onTap: () {
                    bible.secondaryLang = e.key;
                    onChanged?.call();
                  },
                );
              }),
              const SizedBox(height: 12),
              const Divider(color: AppColors.borderGlow),
              const SizedBox(height: 4),

              // ── Import Action ──
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.purple.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.purple.withOpacity(0.35)),
                  ),
                  child: const Icon(Icons.download_rounded,
                      color: AppColors.purple, size: 20),
                ),
                title: const Text(
                  'Import bible language…',
                  style: TextStyle(
                    color: AppColors.textHigh,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Support for VerseVIEW XML bible translations',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onImportLanguage?.call();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.purple.withOpacity(0.24)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.purple : AppColors.borderGlow,
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                const Icon(Icons.check_circle_rounded,
                    size: 14, color: AppColors.purple),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.textHigh : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: (isSelected ? AppColors.purple : AppColors.textMuted)
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color:
                          isSelected ? AppColors.purple : AppColors.textMuted,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LangOptionRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _LangOptionRow({
    required this.name,
    required this.subtitle,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? accentColor.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        leading: Icon(
          isSelected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_off_rounded,
          color: isSelected ? accentColor : AppColors.textMuted,
          size: 20,
        ),
        title: Text(
          name,
          style: TextStyle(
            color: isSelected ? AppColors.textHigh : AppColors.textMuted,
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isSelected
                ? accentColor.withOpacity(0.8)
                : AppColors.textMuted.withOpacity(0.65),
            fontSize: 10.5,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
