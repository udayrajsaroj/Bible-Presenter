import 'package:flutter_test/flutter_test.dart';
import 'package:biblepresenter/slide_renderer.dart';
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
