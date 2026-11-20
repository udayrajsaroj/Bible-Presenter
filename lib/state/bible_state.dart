import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/bible_import.dart';

final defaultAssetBundle = rootBundle;

/// Verse record inside the merged bible view. The app displays any two of
/// the installed languages at a time (primary big on TV, secondary below),
/// so records carry 'primary' / 'secondary' instead of hardcoded languages.
typedef VerseRecord = Map<String, String>;

/// Bible state model with multi-language support. Built-in English + Hindi
/// ship as assets; more languages are imported from VerseVIEW
/// bible-database files (Zefania XML / app JSON) via BibleImport.
class BibleState extends ChangeNotifier {
  /// Canonical Protestant 66-book order (39 OT, 27 NT).
  static const List<String> canonicalBooks = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
    'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
    '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
    'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah',
    'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
    'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah',
    'Haggai', 'Zechariah', 'Malachi', 'Matthew', 'Mark', 'Luke', 'John',
    'Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
    'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians',
    '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus', 'Philemon',
    'Hebrews', 'James', '1 Peter', '2 Peter', '1 John', '2 John',
    '3 John', 'Jude', 'Revelation',
  ];

  static String normalizeBookName(String name) {
    final lower = name.trim().toLowerCase();
    switch (lower) {
      case 'psalm':
      case 'psalms of david':
        return 'Psalms';
      case 'song of songs':
      case 'canticles':
      case 'canticle of canticles':
        return 'Song of Solomon';
      default:
        for (final cb in canonicalBooks) {
          if (cb.toLowerCase() == lower) return cb;
        }
        return name.trim();
    }
  }

  /// Per-language data: code → {book: {chapter: {verse: text}}}.
  final Map<String, Map<String, dynamic>> _langData = {};

  /// Installed languages: code → display name (built-ins + imported).
  Map<String, String> _languages = {'en': 'English', 'hi': 'Hindi'};

  String _primaryLang = 'hi';
  String _secondaryLang = 'en';

  /// Merged view for the UI: {book: {chapter: {verse: {'primary', 'secondary'}}}}.
  Map<String, Map<int, Map<int, Map<String, String>>>> _bible = {};
  bool _bibleLoaded = false;
  String _selectedBook = 'Psalms';
  int _selectedChapter = 23;
  int _selectedVerse = 1;
  int _fontSize = 44;

  BibleState() {
    _loadAll();
  }

  // Getters
  Map<String, Map<int, Map<int, Map<String, String>>>> get bible => _bible;
  bool get bibleLoaded => _bibleLoaded;
  String get selectedBook => _selectedBook;
  int get selectedChapter => _selectedChapter;
  int get selectedVerse => _selectedVerse;
  int get fontSize => _fontSize;
  Map<String, String> get languages => _languages;
  String get primaryLang => _primaryLang;
  String get secondaryLang => _secondaryLang;
  bool get isDualLanguage => _secondaryLang.isNotEmpty;

  // Bible data access
  Map<int, Map<int, Map<String, String>>>? get selectedBookChapters =>
      _bible[_selectedBook];
  Map<int, Map<String, String>>? get selectedChapterVerses =>
      _bible[_selectedBook]?[_selectedChapter];
  Map<String, String>? get selectedVerseData =>
      _bible[_selectedBook]?[_selectedChapter]?[_selectedVerse];

  // Setters
  set selectedBook(String book) {
    if (_bible.containsKey(book) && _selectedBook != book) {
      _selectedBook = book;
      _selectedChapter = _bible[book]!.keys.first;
      _selectedVerse = _bible[book]![_selectedChapter]!.keys.first;
      notifyListeners();
    }
  }

  set selectedChapter(int chapter) {
    final bookChapters = _bible[_selectedBook];
    if (bookChapters == null) return;
    if (bookChapters.containsKey(chapter) && _selectedChapter != chapter) {
      _selectedChapter = chapter;
      _selectedVerse = bookChapters[chapter]!.keys.first;
      notifyListeners();
    }
  }

  set selectedVerse(int verse) {
    final bookChapters = _bible[_selectedBook];
    final chapterVerses = bookChapters?[_selectedChapter];
    if (chapterVerses == null) return;
    if (chapterVerses.containsKey(verse) && _selectedVerse != verse) {
      _selectedVerse = verse;
      notifyListeners();
    }
  }

  set fontSize(int size) {
    if (_fontSize != size) {
      _fontSize = size.clamp(24, 120);
      notifyListeners();
    }
  }

  // ── Language selection ──

  set primaryLang(String code) {
    if (!_languages.containsKey(code) || code == _primaryLang) return;
    final oldPrimary = _primaryLang;
    _primaryLang = code;
    // If switching primary to the current secondary, swap so dual mode stays active!
    if (_secondaryLang == code) {
      _secondaryLang = oldPrimary;
    }
    _persistSelection();
    _rebuild();
    notifyListeners();
  }

  set secondaryLang(String code) {
    if (code.isNotEmpty && !_languages.containsKey(code)) return;
    if (code == _secondaryLang) return;
    if (code == _primaryLang) return; // can't use the same language twice
    _secondaryLang = code;
    _persistSelection();
    _rebuild();
    notifyListeners();
  }

  void toggleDualLanguage(bool enable) {
    if (enable) {
      if (_secondaryLang.isEmpty) {
        final other = _languages.keys.firstWhere(
          (k) => k != _primaryLang,
          orElse: () => '',
        );
        _secondaryLang = other;
      }
    } else {
      _secondaryLang = '';
    }
    _persistSelection();
    _rebuild();
    notifyListeners();
  }

  void setDualPreset({required String primary, required String secondary}) {
    if (_languages.containsKey(primary)) {
      _primaryLang = primary;
    }
    if (secondary.isNotEmpty &&
        _languages.containsKey(secondary) &&
        secondary != _primaryLang) {
      _secondaryLang = secondary;
    } else {
      _secondaryLang = '';
    }
    _persistSelection();
    _rebuild();
    notifyListeners();
  }

  Future<void> _persistSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bible_primary_lang', _primaryLang);
      await prefs.setString('bible_secondary_lang', _secondaryLang);
    } catch (_) {}
  }

  /// Registers an imported bible and makes it available for selection.
  Future<void> addImportedLanguage(ImportedBible imported) async {
    await BibleImport.saveLanguage(
        imported.code, imported.name, imported.data);
    _langData[imported.code] = imported.data;
    _languages = {..._languages, imported.code: imported.name};
    _persistSelection();
    _rebuild();
    notifyListeners();
  }

  Future<void> removeImportedLanguage(String code) async {
    if (code == 'en' || code == 'hi') return; // built-ins stay
    await BibleImport.deleteLanguage(code);
    _langData.remove(code);
    _languages = Map.of(_languages)..remove(code);
    if (_primaryLang == code) _primaryLang = 'hi';
    if (_secondaryLang == code) _secondaryLang = 'en';
    _persistSelection();
    _rebuild();
    notifyListeners();
  }

  // Provider pattern
  static BibleState of(BuildContext context) {
    return context.read<BibleState>();
  }

  // ── Loading ──

  Future<void> _loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Built-in languages ship as assets.
      final enData = jsonDecode(
              await defaultAssetBundle.loadString('assets/bible_en.json'))
          as Map<String, dynamic>;
      final hiData = jsonDecode(
              await defaultAssetBundle.loadString('assets/bible_hi.json'))
          as Map<String, dynamic>;
      _langData['en'] = enData;
      _langData['hi'] = hiData;

      // Imported languages from disk (registered in prefs).
      final imported = await BibleImport.loadImported();
      for (final entry in imported.entries) {
        final data = await BibleImport.loadLanguageFile(entry.key);
        if (data != null) _langData[entry.key] = data;
      }
      _languages = {
        'en': 'English',
        'hi': 'Hindi',
        ...imported,
      };

      // Restore selections; fall back to defaults when a language vanished.
      final p = prefs.getString('bible_primary_lang') ?? 'hi';
      final s = prefs.getString('bible_secondary_lang') ?? 'en';
      _primaryLang = _languages.containsKey(p) ? p : 'hi';
      _secondaryLang = (_languages.containsKey(s) && s != _primaryLang)
          ? s
          : (_primaryLang == 'en' ? 'hi' : 'en');

      _rebuild();

      if (_bible.isNotEmpty) {
        if (!_bible.containsKey(_selectedBook)) {
          _selectedBook = _bible.keys.first;
        }
        if (!_bible[_selectedBook]!.containsKey(_selectedChapter)) {
          _selectedChapter = _bible[_selectedBook]!.keys.first;
        }
        if (!_bible[_selectedBook]![_selectedChapter]!
            .containsKey(_selectedVerse)) {
          _selectedVerse =
              _bible[_selectedBook]![_selectedChapter]!.keys.first;
        }
      }
      _bibleLoaded = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading Bible: $e');
      }
      _bible = _fallbackBible();
      _bibleLoaded = true;
      if (_bible.isNotEmpty) {
        _selectedBook = _bible.keys.first;
        _selectedChapter = _bible[_selectedBook]!.keys.first;
        _selectedVerse = _bible[_selectedBook]![_selectedChapter]!.keys.first;
      }
      notifyListeners();
    }
  }

  /// Rebuilds the merged view from the selected primary + secondary
  /// languages. Book/chapter/verse numbering follows the primary language;
  /// secondary text is attached where the same reference exists.
  void _rebuild() {
    final primary = _langData[_primaryLang];
    final secondary = _secondaryLang.isEmpty ? null : _langData[_secondaryLang];
    final Map<String, Map<int, Map<int, Map<String, String>>>> bible = {};

    void merge(Map<String, dynamic>? data, String slot) {
      if (data == null) return;
      for (final bookEntry in data.entries) {
        final bookName = normalizeBookName(bookEntry.key);
        final chapters = bookEntry.value as Map<String, dynamic>;
        final bookMap =
            (bible[bookName] ??= <int, Map<int, Map<String, String>>>{});
        for (final chapterEntry in chapters.entries) {
          final chapterNum = int.tryParse(chapterEntry.key) ?? 0;
          final verses = chapterEntry.value as Map<String, dynamic>;
          final chapterMap =
              (bookMap[chapterNum] ??= <int, Map<String, String>>{});
          for (final verseEntry in verses.entries) {
            final verseNum = int.tryParse(verseEntry.key) ?? 0;
            final record =
                (chapterMap[verseNum] ??= <String, String>{'primary': '', 'secondary': ''});
            record[slot] = verseEntry.value.toString();
          }
        }
      }
    }

    merge(primary, 'primary');
    merge(secondary, 'secondary');

    final orderedBible = <String, Map<int, Map<int, Map<String, String>>>>{};
    for (final book in canonicalBooks) {
      if (bible.containsKey(book)) {
        orderedBible[book] = bible[book]!;
      }
    }
    for (final entry in bible.entries) {
      if (!orderedBible.containsKey(entry.key)) {
        orderedBible[entry.key] = entry.value;
      }
    }

    _bible = orderedBible;
    if (_bible.isNotEmpty) {
      if (!_bible.containsKey(_selectedBook)) {
        _selectedBook = _bible.keys.first;
      }
      final chapters = _bible[_selectedBook];
      if (chapters != null && !chapters.containsKey(_selectedChapter)) {
        _selectedChapter = chapters.keys.first;
      }
      final verses = _bible[_selectedBook]?[_selectedChapter];
      if (verses != null && !verses.containsKey(_selectedVerse)) {
        _selectedVerse = verses.keys.first;
      }
    }
  }

  Map<String, Map<int, Map<int, Map<String, String>>>> _fallbackBible() {
    return {
      'Psalms': {
        23: {
          1: {
            'primary': 'यहोवा मेरा चरवाहा है, मुझे कोई घटी न होगा।',
            'secondary': 'The Lord is my shepherd; I shall not want.'
          },
          2: {
            'primary': 'वह मुझे हरी हरी चराइयों में बैठाता है।',
            'secondary': 'He maketh me to lie down in green pastures.'
          },
          4: {
            'primary': 'चाहे मैं मृत्यु की छाया की तराई में भी चलूं, मैं किसी विपत्ति से न डरूंगा।',
            'secondary': 'Yea, though I walk through the valley of the shadow of death, I will fear no evil.'
          },
          6: {
            'primary': 'निश्चय भलाई और करुणा मेरे जीवन भर मेरे साथ रहेंगी।',
            'secondary': 'Surely goodness and mercy shall follow me all the days of my life.'
          },
        },
        119: {
          105: {
            'primary': 'तेरा वचन मेरे पांव के लिये दीपक, और मेरे मार्ग के लिये प्रकाश है।',
            'secondary': 'Thy word is a lamp unto my feet, and a light unto my path.'
          }
        },
      },
      'John': {
        3: {
          16: {
            'primary': 'क्योंकि परमेश्वर ने जगत से ऐसा प्रेम रखा कि उस ने अपना एकलौता पुत्र दे दिया।',
            'secondary': 'For God so loved the world, that he gave his only begotten Son.'
          }
        },
        14: {
          6: {
            'primary': 'मैं ही रास्ता, मैं ही सत्य, और मैं ही जीवन हूं।',
            'secondary': 'I am the way, the truth, and the life.'
          }
        },
      },
    };
  }
}
