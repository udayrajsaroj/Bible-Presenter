import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:biblepresenter/state/bible_state.dart';

void main() {
  const expected66Books = [
    // Old Testament (39 books)
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
    'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
    '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
    'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah',
    'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
    'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah',
    'Haggai', 'Zechariah', 'Malachi',
    // New Testament (27 books)
    'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
    '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians', 'Philippians',
    'Colossians', '1 Thessalonians', '2 Thessalonians', '1 Timothy',
    '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James', '1 Peter',
    '2 Peter', '1 John', '2 John', '3 John', 'Jude', 'Revelation',
  ];

  test('BibleState.canonicalBooks contains exactly 66 books in canonical order', () {
    expect(BibleState.canonicalBooks.length, 66);
    for (int i = 0; i < 66; i++) {
      expect(
        BibleState.canonicalBooks[i],
        equals(expected66Books[i]),
        reason: 'Book at position ${i + 1} must be ${expected66Books[i]}',
      );
    }
  });

  test('Old Testament has exactly 39 books (Genesis to Malachi)', () {
    final ot = BibleState.canonicalBooks.sublist(0, 39);
    expect(ot.length, 39);
    expect(ot.first, 'Genesis');
    expect(ot.last, 'Malachi');
    expect(ot.contains('Song of Solomon'), isTrue);
    expect(ot.indexOf('Song of Solomon'), 21); // 22nd book (index 21)
    expect(ot.indexOf('Ecclesiastes'), 20);    // 21st book (index 20)
    expect(ot.indexOf('Isaiah'), 22);          // 23rd book (index 22)
  });

  test('New Testament has exactly 27 books (Matthew to Revelation)', () {
    final nt = BibleState.canonicalBooks.sublist(39);
    expect(nt.length, 27);
    expect(nt.first, 'Matthew');
    expect(nt.last, 'Revelation');
    expect(nt.indexOf('Acts'), 4); // 44th book (index 4 in NT)
    expect(nt.indexOf('Romans'), 5);
  });

  test('assets/bible_en.json has all 66 books in exact canonical order', () {
    final file = File('assets/bible_en.json');
    expect(file.existsSync(), isTrue);
    final data = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    final keys = data.keys.toList();
    expect(keys.length, 66);
    expect(keys, equals(expected66Books));
  });

  test('assets/bible_hi.json has all 66 books in exact canonical order', () {
    final file = File('assets/bible_hi.json');
    expect(file.existsSync(), isTrue);
    final data = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    final keys = data.keys.toList();
    expect(keys.length, 66);
    expect(keys, equals(expected66Books));
  });

  test('BibleState.normalizeBookName maps aliases and case variations', () {
    expect(BibleState.normalizeBookName('psalm'), 'Psalms');
    expect(BibleState.normalizeBookName('Psalm'), 'Psalms');
    expect(BibleState.normalizeBookName('psalms of david'), 'Psalms');
    expect(BibleState.normalizeBookName('song of songs'), 'Song of Solomon');
    expect(BibleState.normalizeBookName('canticles'), 'Song of Solomon');
    expect(BibleState.normalizeBookName('GENESIS'), 'Genesis');
    expect(BibleState.normalizeBookName('revelation'), 'Revelation');
  });
}
