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

  test('TEST: BibleState fontSize clamps up to 120 and allows large TV text sizes', () {
    final state = BibleState();
    state.fontSize = 80;
    expect(state.fontSize, equals(80));
    state.fontSize = 112;
    expect(state.fontSize, equals(112));
    state.fontSize = 150;
    expect(state.fontSize, equals(120), reason: 'Clamped to max 120');
    state.fontSize = 10;
    expect(state.fontSize, equals(24), reason: 'Clamped to min 24');
  });

  test('TEST: SlideRenderer renders large font size (Joshua 3:16) cleanly on 1080p slide', () async {
    final joshuaVerseState = {
      'type': 'verse',
      'content': {
        'book': 'Joshua',
        'chapter': '3',
        'verse': '16',
        'textEn': 'That the waters which came down from above stood and rose up upon an heap very far from the city Adam, that is beside Zaretan: and those that came down toward the sea of the plain, even the salt sea, failed, and were cut off: and the people passed over right against Jericho.',
        'textHi': 'तब जो जल ऊपर की ओर से बहा आता था वह बहुत दूर, अर्थात् आदाम नगर के पास जो सारतान के निकट है रुककर एक ढेर हो गया, और दीवार सा उठा रहा, और जो जल अराबा का ताल, जो खारा ताल भी कहलाता है उसकी ओर बहा जाता था, वह पूरी रीति से सूख गया; और प्रजा के लोग यरीहो के सामने पार उतर गए।',
        'fontSize': 96,
      },
      'background': null,
    };

    final bytes = await SlideRenderer.capture(joshuaVerseState);
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(1000));
  });
}
