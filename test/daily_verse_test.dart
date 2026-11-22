import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biblepresenter/screens/v2/home_screen.dart';
import 'package:biblepresenter/state/bible_state.dart';
import 'package:biblepresenter/state/song_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, BibleState bible, SongState songs) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<BibleState>.value(value: bible),
      ChangeNotifierProvider<SongState>.value(value: songs),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Hero verse card renders center aligned text and reference pill',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;

    final bible = BibleState();
    final songs = SongState();

    bool openedBible = false;

    await tester.pumpWidget(_wrap(
      HomeScreen(
        tvState: ValueNotifier<Map<String, dynamic>>({'type': 'idle'}),
        onOpenSlides: () {},
        onOpenSongs: () {},
        onOpenBible: () => openedBible = true,
        onOpenFiles: () {},
        onOpenSettings: () {},
        onCastLogo: () {},
        onCastBlackout: () {},
        onCastToTV: () {},
      ),
      bible,
      songs,
    ));
    await tester.pumpAndSettle();

    // Verify verse text is center aligned
    final textFinder = find.byWidgetPredicate(
      (w) => w is Text && w.textAlign == TextAlign.center && (w.data?.startsWith('“') ?? false),
    );
    expect(textFinder, findsOneWidget);

    final Text verseWidget = tester.widget<Text>(textFinder);
    expect(verseWidget.textAlign, TextAlign.center);

    // Verify reference pill is center aligned
    final pillFinder = find.byWidgetPredicate(
      (w) => w is Text && w.textAlign == TextAlign.center && !(w.data?.startsWith('“') ?? false),
    );
    expect(pillFinder, findsOneWidget);

    final Text pillWidget = tester.widget<Text>(pillFinder);
    expect(pillWidget.textAlign, TextAlign.center);
    expect(pillWidget.data, isNotEmpty);
  });
}
