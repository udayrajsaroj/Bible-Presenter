import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

final defaultAssetBundle = rootBundle;

/// Bible state model
class BibleState extends ChangeNotifier {
  Map<String, Map<int, Map<int, Map<String, String>>>> _bible = {};
  bool _bibleLoaded = false;
  String _selectedBook = 'Psalms';
  int _selectedChapter = 23;
  int _selectedVerse = 1;
  int _fontSize = 44;

  BibleState() {
    _loadBible();
  }

  // Getters
  Map<String, Map<int, Map<int, Map<String, String>>>> get bible => _bible;
  bool get bibleLoaded => _bibleLoaded;
  String get selectedBook => _selectedBook;
  int get selectedChapter => _selectedChapter;
  int get selectedVerse => _selectedVerse;
  int get fontSize => _fontSize;

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
    if (_bible[_selectedBook]!.containsKey(chapter) &&
        _selectedChapter != chapter) {
      _selectedChapter = chapter;
      _selectedVerse = _bible[_selectedBook]![chapter]!.keys.first;
      notifyListeners();
    }
  }

  set selectedVerse(int verse) {
    if (_bible[_selectedBook]![_selectedChapter]!.containsKey(verse) &&
        _selectedVerse != verse) {
      _selectedVerse = verse;
      notifyListeners();
    }
  }

  set fontSize(int size) {
    if (_fontSize != size) {
      _fontSize = size.clamp(24, 80);
      notifyListeners();
    }
  }

  // Provider pattern
  static BibleState of(BuildContext context) {
    return context.read<BibleState>();
  }

  // Private methods
  Future<void> _loadBible() async {
    try {
      // Load with the same logic as in main.dart for consistency
      final enJsonStr =
          await defaultAssetBundle.loadString('assets/bible_en.json');
      final enData = jsonDecode(enJsonStr) as Map<String, dynamic>;
      final hiJsonStr =
          await defaultAssetBundle.loadString('assets/bible_hi.json');
      final hiData = jsonDecode(hiJsonStr) as Map<String, dynamic>;
      final Map<String, Map<int, Map<int, Map<String, String>>>> bible = {};

      for (final bookEntry in enData.entries) {
        final bookName = bookEntry.key;
        final chapters = bookEntry.value as Map<String, dynamic>;
        bible[bookName] = {};
        for (final chapterEntry in chapters.entries) {
          final chapterNum = int.tryParse(chapterEntry.key) ?? 0;
          final verses = chapterEntry.value as Map<String, dynamic>;
          bible[bookName]![chapterNum] = {};
          for (final verseEntry in verses.entries) {
            final verseNum = int.tryParse(verseEntry.key) ?? 0;
            bible[bookName]![chapterNum]![verseNum] = {
              'en': verseEntry.value.toString(),
              'hi': ''
            };
          }
        }
      }

      for (final bookEntry in hiData.entries) {
        final bookName = bookEntry.key;
        final chapters = bookEntry.value as Map<String, dynamic>;
        if (!bible.containsKey(bookName)) bible[bookName] = {};
        for (final chapterEntry in chapters.entries) {
          final chapterNum = int.tryParse(chapterEntry.key) ?? 0;
          final verses = chapterEntry.value as Map<String, dynamic>;
          if (!bible[bookName]!.containsKey(chapterNum))
            bible[bookName]![chapterNum] = {};
          for (final verseEntry in verses.entries) {
            final verseNum = int.tryParse(verseEntry.key) ?? 0;
            if (bible[bookName]![chapterNum]!.containsKey(verseNum)) {
              bible[bookName]![chapterNum]![verseNum]!['hi'] =
                  verseEntry.value.toString();
            } else {
              bible[bookName]![chapterNum]![verseNum] = {
                'en': '',
                'hi': verseEntry.value.toString()
              };
            }
          }
        }
      }

      _bible = bible;
      _bibleLoaded = true;
      if (_bible.isNotEmpty) {
        _selectedBook = _bible.keys.first;
        _selectedChapter = _bible[_selectedBook]!.keys.first;
        _selectedVerse = _bible[_selectedBook]![_selectedChapter]!.keys.first;
      }
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

  Map<String, Map<int, Map<int, Map<String, String>>>> _fallbackBible() {
    return {
      'Psalms': {
        23: {
          1: {
            'en': 'The Lord is my shepherd; I shall not want.',
            'hi': 'यहोवा मेरा चरवाहा है, मुझे कोई घटी न होगी।'
          },
          2: {
            'en': 'He maketh me to lie down in green pastures.',
            'hi': 'वह मुझे हरी हरी चराइयों में बैठाता है।'
          },
          4: {
            'en':
                'Yea, though I walk through the valley of the shadow of death, I will fear no evil.',
            'hi':
                'चाहे मैं मृत्यु की छाया की तराई में भी चलूं, मैं किसी विपत्ति से न डरूंगा।'
          },
          6: {
            'en':
                'Surely goodness and mercy shall follow me all the days of my life.',
            'hi': 'निश्चय भलाई और करुणा मेरे जीवन भर मेरे साथ रहेंगी।'
          },
        },
        119: {
          105: {
            'en': 'Thy word is a lamp unto my feet, and a light unto my path.',
            'hi':
                'तेरा वचन मेरे पांव के लिये दीपक, और मेरे मार्ग के लिये प्रकाश है।'
          }
        },
      },
      'John': {
        3: {
          16: {
            'en':
                'For God so loved the world, that he gave his only begotten Son.',
            'hi':
                'क्योंकि परमेश्वर ने जगत से ऐसा प्रेम रखा कि उस ने अपना एकलौता पुत्र दे दिया।'
          }
        },
        14: {
          6: {
            'en': 'I am the way, the truth, and the life.',
            'hi': 'मार्ग और सत्य और जीवन मैं ही हूं।'
          }
        },
      },
      'Romans': {
        8: {
          28: {
            'en': 'All things work together for good to them that love God.',
            'hi':
                'जो लोग परमेश्वर से प्रेम रखते हैं उनके लिये सब बातें मिलकर भलाई ही को उत्पन्न करती हैं।'
          }
        },
      },
      'Philippians': {
        4: {
          13: {
            'en': 'I can do all things through Christ which strengtheneth me.',
            'hi':
                'मैं मसीह के द्वारा जो मुझे सामर्थ देता है सब कुछ कर सकता हूं।'
          }
        },
      },
    };
  }
}

// Provider accessors
BibleState bibleStateOf(BuildContext context, {bool listen = true}) =>
    Provider.of<BibleState>(context, listen: listen);

BibleState? bibleStateMaybeOf(BuildContext context) =>
    context.read<BibleState?>();
