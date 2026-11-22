import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biblepresenter/screens/song_presenter_screen.dart';
import 'package:biblepresenter/state/song_state.dart';
import 'package:biblepresenter/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: kBg,
    ),
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SongState Font Size', () {
    test('default font size is 44 and clamps between 24 and 120', () {
      final state = SongState();
      expect(state.fontSize, 44);

      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.fontSize = 68;
      expect(state.fontSize, 68);
      expect(notifyCount, 1);

      // Clamp max 120
      state.fontSize = 150;
      expect(state.fontSize, 120);

      // Clamp min 24
      state.fontSize = 10;
      expect(state.fontSize, 24);
    });
  });

  group('SongPresenterScreen "Tt" Text Controller', () {
    late SongState songState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      songState = SongState();
      await songState.importSong(
        title: 'Amazing Grace',
        stanzas: [
          '[Verse 1]\nAmazing grace how sweet the sound',
          "[Verse 2]\n'Twas grace that taught my heart to fear",
        ],
      );
    });

    testWidgets('shows format_size "Tt" icon in header actions',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(_wrap(SongPresenterScreen(
        songState: songState,
        tvState: ValueNotifier<Map<String, dynamic>>({'type': 'idle'}),
        onSelectStanza: (_) {},
        onPrevStanza: () {},
        onNextStanza: () {},
        onLogo: () {},
        onBlackout: () {},
        onClear: () {},
      )));
      await tester.pumpAndSettle();

      // Find format_size icon ("Tt")
      expect(find.byIcon(Icons.format_size), findsOneWidget);
    });

    testWidgets('shows on-screen text controller bar with A-, slider, A+, and sp badge',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(_wrap(SongPresenterScreen(
        songState: songState,
        tvState: ValueNotifier<Map<String, dynamic>>({'type': 'idle'}),
        onSelectStanza: (_) {},
        onPrevStanza: () {},
        onNextStanza: () {},
        onLogo: () {},
        onBlackout: () {},
        onClear: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('A-'), findsOneWidget);
      expect(find.text('A+'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('44 sp'), findsOneWidget);
    });

    testWidgets('tapping A+ increases font size and triggers recast',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      bool recastCalled = false;
      await tester.pumpWidget(_wrap(SongPresenterScreen(
        songState: songState,
        tvState: ValueNotifier<Map<String, dynamic>>({'type': 'idle'}),
        onSelectStanza: (_) {},
        onPrevStanza: () {},
        onNextStanza: () {},
        onLogo: () {},
        onBlackout: () {},
        onClear: () {},
        onCastSong: () => recastCalled = true,
      )));
      await tester.pumpAndSettle();

      expect(songState.fontSize, 44);
      await tester.tap(find.text('A+'));
      await tester.pumpAndSettle();

      expect(songState.fontSize, 48);
      expect(recastCalled, isTrue);
      expect(find.text('48 sp'), findsOneWidget);
    });

    testWidgets('tapping A- decreases font size and triggers recast',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      bool recastCalled = false;
      songState.fontSize = 50;

      await tester.pumpWidget(_wrap(SongPresenterScreen(
        songState: songState,
        tvState: ValueNotifier<Map<String, dynamic>>({'type': 'idle'}),
        onSelectStanza: (_) {},
        onPrevStanza: () {},
        onNextStanza: () {},
        onLogo: () {},
        onBlackout: () {},
        onClear: () {},
        onCastSong: () => recastCalled = true,
      )));
      await tester.pumpAndSettle();

      expect(songState.fontSize, 50);
      await tester.tap(find.text('A-'));
      await tester.pumpAndSettle();

      expect(songState.fontSize, 46);
      expect(recastCalled, isTrue);
      expect(find.text('46 sp'), findsOneWidget);
    });

    testWidgets('tapping Tt format_size popover opens menu and updates size',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      bool recastCalled = false;
      await tester.pumpWidget(_wrap(SongPresenterScreen(
        songState: songState,
        tvState: ValueNotifier<Map<String, dynamic>>({'type': 'idle'}),
        onSelectStanza: (_) {},
        onPrevStanza: () {},
        onNextStanza: () {},
        onLogo: () {},
        onBlackout: () {},
        onClear: () {},
        onCastSong: () => recastCalled = true,
      )));
      await tester.pumpAndSettle();

      // Tap the format_size Tt icon to open the popup menu
      await tester.tap(find.byIcon(Icons.format_size));
      await tester.pumpAndSettle();

      // Check popup menu items
      expect(find.text('68 sp'), findsOneWidget);
      await tester.tap(find.text('68 sp'));
      await tester.pumpAndSettle();

      expect(songState.fontSize, 68);
      expect(recastCalled, isTrue);
      expect(find.text('68 sp'), findsOneWidget);
    });
  });
}
