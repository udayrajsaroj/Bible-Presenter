/// Word (.docx) song import/export for the Songs tab.
///
/// A .docx file is a zip containing word/document.xml. This service:
///  - EXPORT: builds a minimal, Word-compatible docx — the song title as a
///    heading, then one paragraph per slide line with a blank paragraph
///    between slides. Slide labels like "[Chorus]" stay bold on their line.
///  - IMPORT: unzips the docx, reads word/document.xml, extracts paragraph
///    text (w:p → w:r → w:t), treats the first non-empty paragraph as the
///    song title and groups the rest into slides at blank lines — the same
///    structure churches type in Word naturally.
///
/// Only plain paragraphs are handled (headers/footers, tables and text
/// boxes are ignored), which keeps round-trips lossless for song lyrics.
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class ParsedSongDoc {
  final String title;
  final List<String> stanzas;
  const ParsedSongDoc({required this.title, required this.stanzas});
}

class SongDocx {
  // ── Export ──

  /// Builds a .docx file for the song. Each stanza becomes a slide section:
  /// one paragraph per line, blank paragraph between slides, [Label] lines bold.
  static List<int> exportSongDocx(String title, List<String> stanzas) {
    final esc = _escapeXml;
    final buf = StringBuffer();

    // Title heading.
    buf.write('<w:p><w:pPr><w:spacing w:after="240"/></w:pPr>'
        '<w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr>'
        '<w:t xml:space="preserve">${esc(title)}</w:t></w:r></w:p>');

    for (var s = 0; s < stanzas.length; s++) {
      final lines = stanzas[s].split('\n');
      for (final line in lines) {
        final isLabel = RegExp(r'^\s*\[[^\]]*\]\s*$').hasMatch(line);
        final rpr = isLabel ? '<w:rPr><w:b/><w:color w:val="8B6914"/></w:rPr>' : '';
        buf.write('<w:p><w:r>$rpr<w:t xml:space="preserve">'
            '${esc(line.isEmpty ? ' ' : line)}</w:t></w:r></w:p>');
      }
      if (s < stanzas.length - 1) {
        buf.write('<w:p/>'); // blank line between slides
      }
    }

    final documentXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>${buf.toString()}'
        '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/></w:sectPr>'
        '</w:body></w:document>';

    final contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>';

    final rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';

    final docRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>';

    final archive = Archive();
    archive.addFile(ArchiveFile.bytes(
        '[Content_Types].xml', utf8.encode(contentTypes)));
    archive.addFile(ArchiveFile.bytes('_rels/.rels', utf8.encode(rels)));
    archive.addFile(ArchiveFile.bytes(
        'word/_rels/document.xml.rels', utf8.encode(docRels)));
    archive.addFile(
        ArchiveFile.bytes('word/document.xml', utf8.encode(documentXml)));
    return ZipEncoder().encode(archive);
  }

  // ── Import ──

  /// Parses a .docx byte stream into a song. Throws [FormatException] when
  /// the file is not a readable docx or contains no lyrics.
  static ParsedSongDoc parseSongDocx(List<int> bytes) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('Not a valid .docx file (zip open failed)');
    }

    ArchiveFile? docFile;
    for (final f in archive.files) {
      if (f.name == 'word/document.xml') {
        docFile = f;
        break;
      }
    }
    if (docFile == null) {
      throw const FormatException('Not a Word document (no word/document.xml)');
    }

    XmlDocument doc;
    try {
      doc = XmlDocument.parse(utf8.decode(docFile.content as List<int>,
          allowMalformed: true));
    } catch (_) {
      throw const FormatException('Corrupt Word document (xml parse failed)');
    }

    // Collect paragraph texts in document order.
    final paragraphs = <String>[];
    for (final p in doc.descendantElements.where((e) => e.name.local == 'p')) {
      // Only top-level paragraphs: skip paragraphs nested in others (rare).
      final parent = p.parent;
      if (parent is XmlElement && parent.name.local == 'p') continue;
      final text = _paragraphText(p);
      paragraphs.add(text);
    }

    final parsed = _paragraphsToSong(paragraphs);
    if (parsed.stanzas.isEmpty) {
      throw const FormatException('No song lyrics found in the document');
    }
    return parsed;
  }

  /// Converts raw paragraph texts into {title, stanzas}. First non-empty
  /// paragraph = title ("SONG:" / "Title:" prefixes stripped); blank lines
  /// separate slides; a repeated title line inside the body is ignored.
  static ParsedSongDoc paragraphsToSong(List<String> paragraphs) =>
      _paragraphsToSong(paragraphs);

  static ParsedSongDoc _paragraphsToSong(List<String> paragraphs) {
    String title = '';
    final stanzas = <String>[];
    final current = <String>[];

    void flush() {
      if (current.isEmpty) return;
      final text = current.join('\n').trim();
      if (text.isNotEmpty) stanzas.add(text);
      current.clear();
    }

    for (final raw in paragraphs) {
      final line = raw.trim();
      if (line.isEmpty) {
        flush();
        continue;
      }
      if (title.isEmpty) {
        title = line.replaceFirst(
            RegExp(r'^(song|title|naam|name)\s*[:\-–]\s*', caseSensitive: false),
            '')
            .trim();
        continue;
      }
      if (line == title) continue; // repeated title line
      current.add(line);
    }
    flush();

    return ParsedSongDoc(title: title, stanzas: stanzas);
  }

  /// Concatenates the text of one paragraph: w:t joins, w:tab → space,
  /// w:br → newline.
  static String _paragraphText(XmlElement p) {
    final buf = StringBuffer();
    void walk(XmlElement el) {
      for (final node in el.children) {
        if (node is XmlText) {
          buf.write(node.value);
        } else if (node is XmlElement) {
          switch (node.name.local) {
            case 'tab':
              buf.write(' ');
              break;
            case 'br':
            case 'cr':
              buf.write('\n');
              break;
            case 't':
              buf.write(node.innerText);
              break;
            default:
              walk(node);
          }
        }
      }
    }

    walk(p);
    return buf.toString().replaceAll(RegExp(r'\s+$'), '');
  }

  static String _escapeXml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
