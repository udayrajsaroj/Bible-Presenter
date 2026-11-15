/// Bible language import (VerseVIEW bible-database support).
///
/// VerseVIEW (verseview.com/bible-database) distributes 60+ translations in
/// 40+ languages as Zefania XML files:
///   <XMLBIBLE biblename="Hindi">
///     <BIBLEBOOK bnumber="1" bname="Genesis">
///       <CHAPTER cnumber="1">
///         <VERS vnumber="1">…text…</VERS>
///
/// This service converts those files — or an app-format JSON — into the
/// app's per-language bible map `{book: {chapter: {verse: text}}}`, stores
/// them under `<docs>/bible_languages/<code>.json` and registers them in
/// SharedPreferences so BibleState can offer them as display languages.
///
/// NOTE on licensing: the VerseVIEW database mixes public-domain and
/// copyright-restricted translations. Nothing is bundled with the app; the
/// user imports files they legitimately downloaded for their own ministry
/// use. Copyrighted versions (NIV, ESV, …) remain subject to their own terms.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml_events.dart';

const String _kImportedPrefs = 'bible_imported_langs';

/// Canonical book names by ordinal (1-66) for files whose BIBLEBOOK lacks
/// the bname attribute.
const List<String> _kCanonicalBooks = [
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

/// VerseVIEW files use slightly different book names than the built-in
/// assets (e.g. "Psalm" vs "Psalms"). Normalizing to the asset names keeps
/// primary/secondary verse pairing aligned across languages.
const Map<String, String> _kBookAliases = {
  'psalm': 'Psalms',
  'psalms of david': 'Psalms',
  'canticles': 'Song of Solomon',
  'song of songs': 'Song of Solomon',
};

String _canonicalBook(String name) =>
    _kBookAliases[name.toLowerCase()] ?? name;

class ImportedBible {
  /// ASCII slug used as the storage key (e.g. `malayalam`).
  final String code;

  /// Display name (e.g. `Malayalam`).
  final String name;

  /// App-format bible map: {book: {chapter: {verse: text}}}.
  final Map<String, dynamic> data;

  final int verseCount;

  const ImportedBible({
    required this.code,
    required this.name,
    required this.data,
    required this.verseCount,
  });
}

class BibleImport {
  /// Parses a .xml (Zefania) or .json (app-format) bible file.
  static Future<ImportedBible> parseFile(String path) async {
    final fileName = path.split(Platform.pathSeparator).last;
    final lower = fileName.toLowerCase();
    final content = await File(path).readAsString();
    if (lower.endsWith('.xml')) {
      return parseZefaniaXml(content, fallbackName: _stem(fileName));
    }
    if (lower.endsWith('.json')) {
      final data = validateAppJson(content);
      if (data == null) {
        throw const FormatException('Not a valid bible JSON file');
      }
      final stem = _stem(fileName);
      return ImportedBible(
        code: _slug(stem),
        name: stem,
        data: data,
        verseCount: _countVerses(data),
      );
    }
    throw const FormatException('Unsupported file type (use .xml or .json)');
  }

  /// Streaming Zefania XML → app map. Uses the event parser so multi-MB
  /// files never build a full DOM in memory.
  static ImportedBible parseZefaniaXml(String xml, {String? fallbackName}) {
    if (xml.startsWith('\uFEFF')) xml = xml.substring(1);

    String? bibleName;
    String? book;
    int? chapter;
    final Map<String, dynamic> data = {};
    int verseCount = 0;

    // Verse capture state.
    bool inVerse = false;
    int vnumber = 0;
    final StringBuffer verseText = StringBuffer();
    int ignoreDepth = 0; // inside <NOTE>/<STYLE> within a VERS

    void storeVerse() {
      final text = verseText.toString().trim();
      if (book != null && chapter != null && text.isNotEmpty) {
        final chapters =
            (data[book] ??= <String, dynamic>{}) as Map<String, dynamic>;
        final verses =
            (chapters['$chapter'] ??= <String, dynamic>{}) as Map<String, dynamic>;
        verses['$vnumber'] = text;
        verseCount++;
      }
      inVerse = false;
      verseText.clear();
    }

    for (final event in parseEvents(xml)) {
      if (event is XmlStartElementEvent) {
        switch (event.name) {
          case 'XMLBIBLE':
            bibleName = event.attributes
                .firstWhereOrNull((a) => a.name == 'biblename')
                ?.value;
            break;
          case 'BIBLEBOOK':
            final bname = event.attributes
                .firstWhereOrNull((a) => a.name == 'bname')
                ?.value;
            final bnumber = int.tryParse(event.attributes
                .firstWhereOrNull((a) => a.name == 'bnumber')
                ?.value ?? '');
            if (bname != null && bname.trim().isNotEmpty) {
              book = _canonicalBook(bname.trim());
            } else if (bnumber != null &&
                bnumber >= 1 &&
                bnumber <= _kCanonicalBooks.length) {
              book = _kCanonicalBooks[bnumber - 1];
            } else {
              book = null; // unidentifiable book — skip its content
            }
            break;
          case 'CHAPTER':
            chapter = int.tryParse(event.attributes
                .firstWhereOrNull((a) => a.name == 'cnumber')
                ?.value ?? '');
            break;
          case 'VERS':
            inVerse = true;
            ignoreDepth = 0;
            vnumber = int.tryParse(event.attributes
                .firstWhereOrNull((a) => a.name == 'vnumber')
                ?.value ?? '') ?? 0;
            verseText.clear();
            break;
          case 'NOTE':
          case 'STYLE':
            if (inVerse && !event.isSelfClosing) ignoreDepth++;
            break;
        }
      } else if (event is XmlTextEvent) {
        if (inVerse && ignoreDepth == 0) verseText.write(event.text);
      } else if (event is XmlCDATAEvent) {
        if (inVerse && ignoreDepth == 0) verseText.write(event.text);
      } else if (event is XmlEndElementEvent) {
        switch (event.name) {
          case 'VERS':
            storeVerse();
            break;
          case 'NOTE':
          case 'STYLE':
            if (ignoreDepth > 0) ignoreDepth--;
            break;
        }
      }
    }

    if (data.isEmpty) {
      throw const FormatException('No verses found — not a Zefania bible XML');
    }

    final name = (bibleName?.trim().isNotEmpty ?? false)
        ? bibleName!.trim()
        : (fallbackName ?? 'Imported Bible');
    return ImportedBible(
      code: _slug(name),
      name: name,
      data: data,
      verseCount: verseCount,
    );
  }

  /// Validates an app-format bible JSON ({book: {chapter: {verse: text}}}).
  /// Returns the decoded map, or null when the shape is wrong.
  static Map<String, dynamic>? validateAppJson(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) return null;
      int checked = 0;
      for (final book in decoded.values) {
        if (book is! Map<String, dynamic>) return null;
        for (final chapter in book.values) {
          if (chapter is! Map<String, dynamic>) return null;
          for (final verse in chapter.values) {
            if (verse is! String) return null;
            if (++checked > 20) return decoded; // shape verified
          }
        }
      }
      return checked > 0 ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Writes the bible map to <docs>/bible_languages/<code>.json and records
  /// code → display name in prefs.
  static Future<void> saveLanguage(
      String code, String name, Map<String, dynamic> data) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}'
        '/bible_languages');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    await File('${dir.path}/$code.json')
        .writeAsString(jsonEncode(data), flush: true);
    final prefs = await SharedPreferences.getInstance();
    final registered = loadRegistered(prefs);
    registered[code] = name;
    await prefs.setString(_kImportedPrefs, jsonEncode(registered));
  }

  /// Deletes an imported language file + registration.
  static Future<void> deleteLanguage(String code) async {
    final file = File('${(await getApplicationDocumentsDirectory()).path}'
        '/bible_languages/$code.json');
    if (file.existsSync()) await file.delete();
    final prefs = await SharedPreferences.getInstance();
    final registered = loadRegistered(prefs);
    registered.remove(code);
    await prefs.setString(_kImportedPrefs, jsonEncode(registered));
  }

  /// Registered imported languages (code → display name) from prefs.
  static Map<String, String> loadRegistered(SharedPreferences prefs) {
    final raw = prefs.getString(_kImportedPrefs);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
    return {};
  }

  /// Imported languages that actually exist on disk (code → display name).
  static Future<Map<String, String>> loadImported() async {
    final prefs = await SharedPreferences.getInstance();
    final registered = loadRegistered(prefs);
    final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/bible_languages');
    if (!dir.existsSync()) return {};
    final result = <String, String>{};
    for (final entry in registered.entries) {
      final f = File('${dir.path}/${entry.key}.json');
      if (f.existsSync()) result[entry.key] = entry.value;
    }
    return result;
  }

  /// Loads one imported language file from disk.
  static Future<Map<String, dynamic>?> loadLanguageFile(String code) async {
    final f = File(
        '${(await getApplicationDocumentsDirectory()).path}/bible_languages/$code.json');
    if (!f.existsSync()) return null;
    try {
      final decoded = jsonDecode(await f.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  // ── helpers ──

  static String _stem(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return (dot > 0 ? fileName.substring(0, dot) : fileName).trim();
  }

  static String _slug(String name) {
    final s = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final trimmed = s.replaceAll(RegExp(r'^_+|_+$'), '');
    return trimmed.isEmpty ? 'imported' : trimmed.substring(0, trimmed.length.clamp(0, 32));
  }

  static int _countVerses(Map<String, dynamic> data) {
    var n = 0;
    for (final book in data.values) {
      if (book is! Map) continue;
      for (final chapter in book.values) {
        if (chapter is! Map) continue;
        n += chapter.length;
      }
    }
    return n;
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
