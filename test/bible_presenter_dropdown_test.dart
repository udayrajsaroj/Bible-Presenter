import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:biblepresenter/screens/bible_presenter_screen.dart';
import 'package:biblepresenter/state/bible_state.dart';

/// Point 3 regression: the Bible presenter uses 3 inline scripture
/// dropdowns (Book / Chapter / Verse) in the top strip; picking any of
/// them updates BibleState and live-casts immediately — no bottom sheet.
///
/// Note: testWidgets runs in FakeAsync — never `await Future.delayed` in the
/// body; drive async state loading (asset bible + prefs) with pumpAndSettle.
void main() {
  BiblePresenterScreen screen(BibleState b, void Function() cast) {
    return BiblePresenterScreen(
      bibleState: b,
      tvState: ValueNotifier<Map<String, dynamic>>({'type': 'idle'}),
      onCastVerse: cast,
      onPrevVerse: () {},
      onNextVerse: () {},
      onLogo: () {},
      onBlackout: () {},
    );
  }

  /// Real-asset preload: BibleState must be constructed INSIDE runAsync so
  /// its _loadAll async chain runs on the real event loop (rootBundle file
  /// I/O can never complete in the FakeAsync zone).
  Future<BibleState> loadedState(WidgetTester tester) async {
    late BibleState b;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      b = BibleState();
      for (var i = 0; i < 150 && !b.bibleLoaded; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    return b;
  }

  testWidgets('header strip shows Book / Ch / Vs dropdowns and casts on pick',
      (tester) async {
    final bibleState = await loadedState(tester);
    var casts = 0;
    await tester.pumpWidget(MaterialApp(home: screen(bibleState, () => casts++)));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    // The three inline selectors exist; the old jump sheet is gone.
    expect(find.textContaining('Book: '), findsOneWidget);
    expect(find.textContaining('Ch: '), findsOneWidget);
    expect(find.textContaining('Vs: '), findsOneWidget);
    expect(find.text('JUMP TO SCRIPTURE'), findsNothing);

    // Open the Book dropdown and pick John — must cast immediately.
    await tester.tap(find.textContaining('Book: '));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.tap(find.text('John').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(bibleState.selectedBook, 'John');
    expect(casts, 1,
        reason: 'picking a book must live-cast without extra taps');
    expect(find.text('Book: John'), findsOneWidget);
  });

  testWidgets('chapter dropdown lists the book chapters and casts on pick',
      (tester) async {
    final bibleState = await loadedState(tester);
    var casts = 0;
    await tester.pumpWidget(MaterialApp(home: screen(bibleState, () => casts++)));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    await tester.tap(find.textContaining('Ch: '));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.tap(find.text('119').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(bibleState.selectedChapter, 119);
    expect(casts, 1);
  });
}
