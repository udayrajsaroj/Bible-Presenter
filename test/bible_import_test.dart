import 'package:flutter_test/flutter_test.dart';
import 'package:biblepresenter/services/bible_import.dart';

void main() {
  group('BibleImport.parseZefaniaXml', () {
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<XMLBIBLE biblename="TestLang">
  <BIBLEBOOK bnumber="1" bname="Genesis">
    <CHAPTER cnumber="1">
      <VERS vnumber="1">In the beginning God</VERS>
      <VERS vnumber="2">And the earth was <NOTE type="x-strongs">H7225</NOTE>without form</VERS>
    </CHAPTER>
    <CHAPTER cnumber="2">
      <VERS vnumber="3">Third verse</VERS>
    </CHAPTER>
  </BIBLEBOOK>
  <BIBLEBOOK bnumber="19">
    <!-- no bname: falls back to canonical table -->
    <CHAPTER cnumber="23">
      <VERS vnumber="1">The LORD is my shepherd</VERS>
    </CHAPTER>
  </BIBLEBOOK>
  <BIBLEBOOK bnumber="20" bname="Psalm">
    <CHAPTER cnumber="119">
      <VERS vnumber="105">Thy word is a lamp</VERS>
    </CHAPTER>
  </BIBLEBOOK>
</XMLBIBLE>
''';

    test('extracts books, chapters and verses', () {
      final b = BibleImport.parseZefaniaXml(xml);
      expect(b.name, 'TestLang');
      expect(b.code, 'testlang');
      // "Psalm" (bnumber 20) merges into canonical "Psalms" (bnumber 19).
      expect(b.data.keys.toList(), ['Genesis', 'Psalms']);
      expect(b.data['Genesis']['1']['1'], 'In the beginning God');
      expect(b.data['Genesis']['1']['2'], 'And the earth was without form');
      expect(b.data['Genesis']['2']['3'], 'Third verse');
      expect(b.data['Psalms']['23']['1'], 'The LORD is my shepherd');
      expect(b.verseCount, 5);
    });

    test('bnumber fallback resolves canonical book names', () {
      final b = BibleImport.parseZefaniaXml(xml);
      // bnumber 19 → canonical index 18 → Psalms
      expect(b.data.containsKey('Psalms'), isTrue);
    });

    test('book-name aliases normalize to asset names', () {
      final b = BibleImport.parseZefaniaXml(xml);
      // The alias merged "Psalm" into "Psalms": chapter 119 landed there.
      expect(b.data.containsKey('Psalm'), isFalse);
      expect(b.data['Psalms']!.containsKey('119'), isTrue);
      expect(b.data['Psalms']['119']['105'], 'Thy word is a lamp');
    });

    test('throws when no verses found', () {
      expect(
        () => BibleImport.parseZefaniaXml('<XMLBIBLE></XMLBIBLE>'),
        throwsFormatException,
      );
    });
  });

  group('BibleImport.validateAppJson', () {
    test('accepts the app bible format', () {
      const json =
          '{"Genesis": {"1": {"1": "In the beginning", "2": "The earth"}}}';
      final data = BibleImport.validateAppJson(json);
      expect(data, isNotNull);
      expect(data!['Genesis']['1']['2'], 'The earth');
    });

    test('rejects non-bible JSON', () {
      expect(BibleImport.validateAppJson('{"a": [1,2,3]}'), isNull);
      expect(BibleImport.validateAppJson('not json'), isNull);
      expect(BibleImport.validateAppJson('{}'), isNull);
    });
  });
}
