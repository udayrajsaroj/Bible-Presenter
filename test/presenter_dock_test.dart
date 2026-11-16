import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:biblepresenter/screens/song_presenter_screen.dart';
import 'package:biblepresenter/state/song_state.dart';
import 'package:biblepresenter/widgets/presenter_shell.dart';

Widget _host(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('dock buttons never move when content height changes',
      (tester) async {
    final tv = ValueNotifier<Map<String, dynamic>>({'type': 'idle'});

    Future<Rect> prevRectOf(Widget body) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(_host(PresenterScaffold(
        leading: const SizedBox(),
        title: 'Test',
        tvState: tv,
        body: body,
        dockLeft: DockNavButton(
            label: 'PREV', icon: Icons.skip_previous, onTap: () {}),
        dockRight: DockNavButton(
            label: 'NEXT', icon: Icons.skip_next, onTap: () {}),
      )));
      await tester.pumpAndSettle();
      return tester.getRect(find.text('PREV'));
    }

    // Long content (15-line verse) vs short content (1 line).
    final tall = SingleChildScrollView(
        child: Column(children: List.generate(
            15, (i) => Text('Verse line $i', style: const TextStyle(fontSize: 24)))));
    final short = SingleChildScrollView(child: Text('one line'));

    final rectTall = await prevRectOf(tall);
    final rectShort = await prevRectOf(short);

    expect(rectShort.top, rectTall.top,
        reason: 'PREV must stay at the same Y position');
    expect(rectShort.left, rectTall.left,
        reason: 'PREV must stay at the same X position');
    expect(rectShort.bottom, rectTall.bottom);
  });

  testWidgets('pill counter never collides with PREV/NEXT borders',
      (tester) async {
    final tv = ValueNotifier<Map<String, dynamic>>({'type': 'idle'});
    tester.view.physicalSize = const Size(360, 700); // narrow phone
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(_host(PresenterScaffold(
      leading: const SizedBox(),
      title: 'Test',
      tvState: tv,
      body: const SizedBox(),
      dockLeft: DockNavButton(
          label: 'PREV', icon: Icons.skip_previous, onTap: () {}),
      dockCenter: const DockCounterPill(
          primary: 'Page 100 / 200', secondary: 'tap to jump'),
      dockRight: DockNavButton(
          label: 'NEXT', icon: Icons.skip_next, onTap: () {}),
    )));
    await tester.pumpAndSettle();

    final prev = tester.getRect(find.text('PREV'));
    final pill = tester.getRect(find.text('Page 100 / 200'));
    expect(pill.left, greaterThanOrEqualTo(prev.right + 4),
        reason: 'counter pill must stay clear of the PREV button');
    final next = tester.getRect(find.text('NEXT'));
    expect(pill.right, lessThanOrEqualTo(next.left - 4),
        reason: 'counter pill must stay clear of the NEXT button');
  });

  testWidgets('LivePill follows TV state', (tester) async {
    final tv = ValueNotifier<Map<String, dynamic>>({'type': 'idle'});
    await tester.pumpWidget(_host(LivePill(tvState: tv)));
    expect(find.text('OFF AIR'), findsOneWidget);

    tv.value = {'type': 'song', 'content': {}};
    await tester.pumpAndSettle();
    expect(find.text('LIVE ON TV'), findsOneWidget);
  });

  testWidgets('DockNavButton disabled state ignores taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(Material(
        child: DockNavButton(
      label: 'NEXT',
      icon: Icons.skip_next,
      onTap: null,
    ))));
    await tester.tap(find.text('NEXT'), warnIfMissed: false);
    expect(taps, 0);

    await tester.pumpWidget(_host(Material(
        child: DockNavButton(
      label: 'NEXT',
      icon: Icons.skip_next,
      onTap: () => taps++,
    ))));
    await tester.tap(find.text('NEXT'));
    expect(taps, 1);
  });

  group('SongPresenterScreen', () {
    late SongState songState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      songState = SongState();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    Widget screen() => _host(SongPresenterScreen(
          songState: songState,
          tvState: ValueNotifier<Map<String, dynamic>>({'type': 'idle'}),
          onSelectStanza: (i) {
            songState.selectedStanzaIndex = i;
          },
          onPrevStanza: () => songState.selectedStanzaIndex =
              songState.selectedStanzaIndex - 1,
          onNextStanza: () => songState.selectedStanzaIndex =
              songState.selectedStanzaIndex + 1,
          onLogo: () {},
          onBlackout: () {},
          onClear: () {},
        ));

    testWidgets('chip labels: [Chorus] named, plain stanzas numbered',
        (tester) async {
      expect(
        SongPresenterScreen.stanzaLabels(
            ['[Chorus]\na', 'plain', '[Chorus]\nb', '[Bridge]\nc']),
        ['Chorus', 'Stanza 2', 'Chorus 2', 'Bridge'],
      );
    });

    testWidgets('shows stanzas, dock counters and live pill', (tester) async {
      await songState.importSong(title: 'Test Song', stanzas: [
        '[Chorus]\nBless the Lord',
        'The sun comes up',
      ]);
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();

      expect(find.text('Test Song'), findsWidgets);
      expect(find.text('Chorus'), findsOneWidget);
      expect(find.text('Stanza 2'), findsOneWidget);
      expect(find.text('Bless the Lord'), findsOneWidget); // label stripped
      expect(find.text('Stanza 1 / 2'), findsOneWidget);
      expect(find.text('OFF AIR'), findsOneWidget);
    });

    testWidgets('NEXT advances stanza and updates counters', (tester) async {
      await songState.importSong(title: 'Test Song', stanzas: [
        'slide one',
        'slide two',
      ]);
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      expect(songState.selectedStanzaIndex, 1);
      expect(find.text('Stanza 2 / 2'), findsOneWidget);
    });

    testWidgets('tapping a chip selects and shows that stanza',
        (tester) async {
      await songState.importSong(title: 'Test Song', stanzas: [
        'slide one',
        'slide two',
        'slide three',
      ]);
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stanza 3'));
      await tester.pumpAndSettle();

      expect(songState.selectedStanzaIndex, 2);
      expect(find.text('slide three'), findsOneWidget);
      expect(find.text('Stanza 3 / 3'), findsOneWidget);
    });
  });
}
