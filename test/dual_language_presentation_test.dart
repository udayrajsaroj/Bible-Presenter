import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:biblepresenter/state/bible_state.dart';
import 'package:biblepresenter/widgets/v2/bible_language_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dual Language Presentation in BibleState', () {
    test('isDualLanguage, toggleDualLanguage, and setDualPreset behave correctly',
        () async {
      SharedPreferences.setMockInitialValues({});
      final bible = BibleState();

      // Wait briefly for default language load
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Preset dual mode: Hindi primary + English secondary
      bible.setDualPreset(primary: 'hi', secondary: 'en');
      expect(bible.primaryLang, 'hi');
      expect(bible.secondaryLang, 'en');
      expect(bible.isDualLanguage, isTrue);

      // Swapping primary to 'en' should swap secondary to 'hi', keeping dual mode active!
      bible.primaryLang = 'en';
      expect(bible.primaryLang, 'en');
      expect(bible.secondaryLang, 'hi');
      expect(bible.isDualLanguage, isTrue);

      // Toggling dual language OFF
      bible.toggleDualLanguage(false);
      expect(bible.secondaryLang, '');
      expect(bible.isDualLanguage, isFalse);

      // Toggling dual language ON
      bible.toggleDualLanguage(true);
      expect(bible.isDualLanguage, isTrue);
      expect(bible.secondaryLang, isNotEmpty);
      expect(bible.secondaryLang, isNot(equals(bible.primaryLang)));
    });

    testWidgets('BibleLanguageSheet renders dual toggle, presets, and options',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final bible = BibleState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showBibleLanguageSheet(
                  context: ctx,
                  bible: bible,
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Tap to open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify sheet title and Dual Language Presenting toggle
      expect(find.text('Bible Languages & Dual Presenting'), findsOneWidget);
      expect(find.text('Dual Language Presenting'), findsOneWidget);

      // Verify quick presets
      expect(find.text('Hindi + English'), findsOneWidget);
      expect(find.text('English + Hindi'), findsOneWidget);
      expect(find.text('Hindi only'), findsOneWidget);
      expect(find.text('English only'), findsOneWidget);

      // Tap 'English + Hindi' dual preset
      await tester.tap(find.text('English + Hindi'));
      await tester.pumpAndSettle();

      expect(bible.primaryLang, 'en');
      expect(bible.secondaryLang, 'hi');
      expect(bible.isDualLanguage, isTrue);
    });
  });
}
