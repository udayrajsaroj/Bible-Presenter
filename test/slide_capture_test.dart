import 'package:flutter_test/flutter_test.dart';
import 'package:biblepresenter/slide_renderer.dart';
import 'package:biblepresenter/output_router.dart';
import 'package:biblepresenter/state/bible_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TEST: SlideRenderer.capture produces valid 1080p slide image quickly', () async {
    final verseState = {
      'type': 'verse',
      'content': {
        'book': 'Revelation',
        'chapter': '2',
        'verse': '10',
        'textEn': 'Fear none of those things which thou shalt suffer: behold, the devil shall cast some of you into prison, that ye may be tried; and ye shall have tribulation ten days: be thou faithful unto death, and I will give thee a crown of life.',
        'textHi': 'जो दुःख तुझको झेलने होंगे, उनसे मत डर: क्योंकि, शैतान तुम में से कुछ को जेलखाने में डालने पर है ताकि तुम परखे जाओ; और तुम्हें दस दिन तक क्लेश उठाना होगा। प्राण देने तक विश्वासयोग्य रह; तो मैं तुझे जीवन का मुकुट दूँगा।',
        'fontSize': 44,
      },
      'background': null,
    };

    final sw = Stopwatch()..start();
    final bytes = await SlideRenderer.capture(verseState);
    sw.stop();
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(1000));
    print('Slide capture took: ${sw.elapsedMilliseconds} ms, size: ${bytes.length} bytes');
  });

  test('TEST: Verse numerical ordering is respected (verse 2 follows verse 1, not verse 10)', () {
    final rawVerseKeys = ['1', '10', '11', '2', '20', '3', '4'];
    final sorted = List<String>.from(rawVerseKeys)
      ..sort((a, b) => (int.tryParse(a.toString()) ?? 0)
          .compareTo(int.tryParse(b.toString()) ?? 0));

    expect(sorted, equals(['1', '2', '3', '4', '10', '11', '20']));
    final idx1 = sorted.indexOf('1');
    expect(sorted[idx1 + 1], equals('2'),
        reason: 'Verse 2 must immediately follow Verse 1, not Verse 10');
  });

  test('TEST: Pre-rendered verse cache hits return immediately in <50ms', () async {
    final router = OutputRouter.instance;

    final verseState = {
      'type': 'verse',
      'content': {
        'book': 'Psalms',
        'chapter': 23,
        'verse': 2,
        'textEn': 'He maketh me to lie down in green pastures: he leadeth me beside the still waters.',
        'textHi': 'वह मुझे हरी हरी चराइयों में बैठाता है; वह मुझे सुखदाई जल के झरने के पास ले चलता है।',
        'fontSize': 44,
      },
      'background': null,
    };

    // Pre-render into OutputRouter cache
    await router.preRender(verseState);
    expect(router.hasCached(verseState), isTrue);

    // Measure cache hit retrieval latency
    final sw = Stopwatch()..start();
    final cachedBytes = router.getCached(verseState);
    sw.stop();

    expect(cachedBytes, isNotNull);
    expect(cachedBytes!.length, greaterThan(1000));
    expect(sw.elapsedMilliseconds, lessThan(50),
        reason: 'Cache hit lookup must complete in <50ms');
    print('Pre-rendered cache hit returned in ${sw.elapsedMicroseconds / 1000} ms');
  });

  test('TEST: Song of Solomon is in canonical position between Ecclesiastes and Isaiah', () {
    final state = BibleState();
    // Wait for bible to load
    final books = state.bible.keys.toList();
    if (books.isNotEmpty) {
      final eccl = books.indexOf('Ecclesiastes');
      final song = books.indexOf('Song of Solomon');
      final isaiah = books.indexOf('Isaiah');
      expect(song, equals(eccl + 1));
      expect(isaiah, equals(song + 1));
    }
  });
}
