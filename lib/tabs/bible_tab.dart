import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';

class BibleTab extends StatelessWidget {
  final Map<String, Map<int, Map<int, Map<String, String>>>> bible;
  final bool bibleLoaded;
  final String selBook;
  final int selChapter;
  final int selVerse;
  final int fontSize;
  final Map<String, String> languages; // code → display name
  final String primaryLang;
  final String secondaryLang;
  final bool importingLanguage;
  final void Function(String book) onBookChanged;
  final void Function(int chapter) onChapterChanged;
  final void Function(int verse) onVerseChanged;
  final void Function(String code) onPrimaryLangChanged;
  final void Function(String code) onSecondaryLangChanged;
  final VoidCallback onImportLanguage;
  final VoidCallback onCastVerse;
  final VoidCallback onPrevVerse;
  final VoidCallback onNextVerse;
  final void Function(int size) onFontSizeChanged;
  final VoidCallback onOpenFullscreen;

  const BibleTab({
    super.key,
    required this.bible,
    required this.bibleLoaded,
    required this.selBook,
    required this.selChapter,
    required this.selVerse,
    required this.fontSize,
    required this.languages,
    required this.primaryLang,
    required this.secondaryLang,
    required this.importingLanguage,
    required this.onBookChanged,
    required this.onChapterChanged,
    required this.onVerseChanged,
    required this.onPrimaryLangChanged,
    required this.onSecondaryLangChanged,
    required this.onImportLanguage,
    required this.onCastVerse,
    required this.onPrevVerse,
    required this.onNextVerse,
    required this.onFontSizeChanged,
    required this.onOpenFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    if (!bibleLoaded) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: kAccent),
          SizedBox(height: 16),
          Text('Loading Bible data...', style: TextStyle(color: kMuted, fontSize: 13)),
        ],
      ));
    }

    final chapters = bible[selBook] ?? {};
    final verses = chapters[selChapter] ?? {};
    final v = verses[selVerse];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 84),
      child: appCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          label('LANGUAGES'),
          GestureDetector(
            onTap: importingLanguage ? null : onImportLanguage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kAccent.withOpacity(0.3)),
              ),
              child: importingLanguage
                  ? const SizedBox(width: 12, height: 12,
                      child: CircularProgressIndicator(color: kAccent, strokeWidth: 2))
                  : const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.upload_file, size: 12, color: kAccent),
                      SizedBox(width: 5),
                      Text('Add Language', style: TextStyle(color: kAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                    ]),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Import VerseVIEW bible-database files (.xml / .json)',
            style: const TextStyle(color: kMuted, fontSize: 8.5)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: dropdownField<String>(
            label: 'Primary (big on TV)', value: primaryLang,
            items: languages.keys.toList(),
            display: (c) => languages[c] ?? c,
            onChanged: onPrimaryLangChanged,
          )),
          const SizedBox(width: 8),
          Expanded(child: dropdownField<String>(
            label: 'Secondary', value: secondaryLang,
            items: ['', ...languages.keys],
            display: (c) => c.isEmpty ? 'None' : (languages[c] ?? c),
            onChanged: onSecondaryLangChanged,
          )),
        ]),
        const SizedBox(height: 14),
        label('SELECT SCRIPTURE'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: dropdownField<String>(
            label: 'Book', value: selBook,
            items: bible.keys.toList(),
            display: (v) => v,
            onChanged: onBookChanged,
          )),
          const SizedBox(width: 8),
          Expanded(child: dropdownField<int>(
            label: 'Ch', value: selChapter,
            items: (bible[selBook] ?? {}).keys.toList(),
            display: (v) => '$v',
            onChanged: onChapterChanged,
          )),
          const SizedBox(width: 8),
          Expanded(child: dropdownField<int>(
            label: 'Vs', value: selVerse,
            items: (bible[selBook]?[selChapter] ?? {}).keys.toList(),
            display: (v) => '$v',
            onChanged: onVerseChanged,
          )),
        ]),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$selBook $selChapter:$selVerse', style: const TextStyle(fontFamily: 'monospace', color: kAccent, fontSize: 11)),
            if (v?['primary'] != null && (v!['primary']!.isNotEmpty)) ...[
              const SizedBox(height: 8),
              Text(v['primary']!, style: const TextStyle(color: kGold, fontSize: 13, height: 1.5)),
            ],
            if (v?['secondary'] != null && (v!['secondary']!.isNotEmpty)) ...[
              const SizedBox(height: 6),
              Text('"${v['secondary']}"', style: const TextStyle(color: kMuted, fontSize: 11, fontStyle: FontStyle.italic, height: 1.5)),
            ],
            if (v == null) const Text('Verse not available', style: TextStyle(color: kMuted, fontSize: 11, fontStyle: FontStyle.italic)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: secondaryBtn('Prev', onPrevVerse)),
          const SizedBox(width: 8),
          Expanded(child: secondaryBtn('Next', onNextVerse)),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          label('FONT SIZE'),
          Text('$fontSize px', style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10)),
        ]),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: kGold, thumbColor: kGold,
            inactiveTrackColor: kBorder, overlayColor: kGold.withOpacity(0.1),
          ),
          child: Slider(min: 24, max: 80, divisions: 56, value: fontSize.toDouble(), onChanged: (v) => onFontSizeChanged(v.round())),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: primaryBtn('Cast Scripture to TV', onCastVerse)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onOpenFullscreen,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kAccent.withOpacity(0.4)),
              ),
              child: const Icon(Icons.fullscreen, color: kAccent, size: 20),
            ),
          ),
        ]),
      ])),
    );
  }
}
