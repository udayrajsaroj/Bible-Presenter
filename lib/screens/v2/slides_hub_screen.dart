import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/v2/top_bar.dart';

/// Screen 2 — Slides hub: category filter pills, 2-column media grid with
/// floating select buttons, and the "+ Add Custom Slide" gradient pill.
class SlidesHubScreen extends StatefulWidget {
  /// Applied background asset name (empty when none of the presets is live).
  final String activeBackgroundAsset;
  final ValueChanged<SlideLibraryItem> onPickBackground;
  final VoidCallback onAddCustomSlide;
  final VoidCallback onOpenCustomSlides;

  const SlidesHubScreen({
    super.key,
    required this.activeBackgroundAsset,
    required this.onPickBackground,
    required this.onAddCustomSlide,
    required this.onOpenCustomSlides,
  });

  @override
  State<SlidesHubScreen> createState() => _SlidesHubScreenState();
}

class _SlidesHubScreenState extends State<SlidesHubScreen> {
  String _category = 'All';
  static const _categories = ['All', 'Church', 'Nature', 'Abstract'];

  @override
  Widget build(BuildContext context) {
    final items = kSlideLibrary
        .where((it) => _category == 'All' || it.category == _category)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          TopBarV2(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            icon: Icons.slideshow_rounded,
            title: 'Slides',
            actions: [
              IconButton(
                tooltip: 'Search slides',
                onPressed: () => widget.onOpenCustomSlides(),
                icon: const Icon(Icons.search, color: AppColors.textMuted),
              ),
              IconButton(
                tooltip: 'Filter',
                onPressed: () {},
                icon: const Icon(Icons.tune, color: AppColors.textMuted),
              ),
            ],
          ),
          // Category pills.
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                final selected = cat == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected ? null : const Color(0xFF0F172A),
                      gradient: selected
                          ? LinearGradient(colors: [
                              AppColors.cyanDeep.withOpacity(0.9),
                              AppColors.cyan.withOpacity(0.9)
                            ])
                          : null,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(
                        color: selected
                            ? AppColors.cyan.withOpacity(0.8)
                            : AppColors.borderWhite,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                  color: AppColors.cyan.withOpacity(0.4),
                                  blurRadius: 12)
                            ]
                          : null,
                    ),
                    child: Text(cat,
                        style: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 16 / 10.4,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                final active =
                    widget.activeBackgroundAsset == item.asset;
                return _MediaTile(
                  item: item,
                  active: active,
                  onTap: () => widget.onPickBackground(item),
                );
              },
            ),
          ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _AddCustomSlideButton(
            onAdd: widget.onAddCustomSlide,
            onOpenCustom: widget.onOpenCustomSlides,
          ),
        ),
      ),
    );
  }
}

/// 16:9 media tile with a floating circular select/download button.
class _MediaTile extends StatelessWidget {
  final SlideLibraryItem item;
  final bool active;
  final VoidCallback onTap;

  const _MediaTile({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.thumb),
          border: Border.all(
            color: active ? AppColors.cyan : AppColors.borderWhite,
            width: active ? 1.6 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: AppColors.cyan.withOpacity(0.35), blurRadius: 14)
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.thumb),
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(item.asset, fit: BoxFit.cover),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? AppColors.cyan
                      : Colors.black.withOpacity(0.55),
                  border: Border.all(
                      color: active
                          ? Colors.white
                          : Colors.white.withOpacity(0.6),
                      width: 1.2),
                  boxShadow: active
                      ? [
                          BoxShadow(
                              color: AppColors.cyan.withOpacity(0.6),
                              blurRadius: 10)
                        ]
                      : null,
                ),
                child: Icon(
                  active ? Icons.check_rounded : Icons.download_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AddCustomSlideButton extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onOpenCustom;
  const _AddCustomSlideButton({required this.onAdd, required this.onOpenCustom});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: AppGradients.addSlide,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.purple.withOpacity(0.4), blurRadius: 18),
                ],
              ),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text('Add Custom Slide',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold)),
                  ]),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      // My slides (custom text slides queue).
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpenCustom,
          borderRadius: BorderRadius.circular(AppRadii.button),
          child: Container(
            height: 52,
            width: 52,
            decoration: glass(
              radius: AppRadii.button,
              borderColor: AppColors.borderGlow,
            ),
            child: const Icon(Icons.format_list_bulleted_rounded,
                color: AppColors.cyan, size: 22),
          ),
        ),
      ),
    ]);
  }
}
