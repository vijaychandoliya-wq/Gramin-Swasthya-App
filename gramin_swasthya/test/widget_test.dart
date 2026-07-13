import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gramin_swasthya/db/database_helper.dart';
import 'package:gramin_swasthya/l10n/app_language.dart';
import 'package:gramin_swasthya/l10n/localized_text.dart';
import 'package:gramin_swasthya/services/notification_service.dart';
import 'package:flutter/material.dart';

void main() {
  test('web database keeps health records isolated by family member', () async {
    final db = MockDatabase();
    await db.insert('bp_readings', {
      'member_id': 1,
      'systolic': 120,
      'diastolic': 80,
    });
    await db.insert('bp_readings', {
      'member_id': 2,
      'systolic': 140,
      'diastolic': 90,
    });

    final firstMemberReadings = await db.query(
      'bp_readings',
      where: 'member_id = ?',
      whereArgs: [1],
    );

    expect(firstMemberReadings, hasLength(1));
    expect(firstMemberReadings.single['systolic'], 120);
  });

  test('medicine reminder includes person and medicine names', () {
    expect(
      englishMedicineReminder('Vijay', 'Metformin'),
      'Vijay, your Metformin medicine time is now. Please take Metformin.',
    );
    expect(
      hindiMedicineReminder('Vijay', 'Metformin'),
      'Vijay जी, आपकी Metformin लेने का समय हो गया है। कृपया Metformin लें।',
    );
  });

  test('bilingual labels render only the selected language', () {
    expect(
      AppLanguage.text('दवाई सहेजें / Save Medicine', languageCode: 'en'),
      'Save Medicine',
    );
    expect(
      AppLanguage.text('दवाई सहेजें / Save Medicine', languageCode: 'hi'),
      'दवाई सहेजें',
    );
    expect(
      AppLanguage.text('Choose Your Language', languageCode: 'hi'),
      'अपनी भाषा चुनें',
    );
  });

  testWidgets('localized text updates immediately with language selection',
      (tester) async {
    AppLanguage.current.value = 'en';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LocalizedText('दवाई सहेजें / Save Medicine'),
        ),
      ),
    );
    expect(find.text('Save Medicine'), findsOneWidget);
    expect(find.text('दवाई सहेजें'), findsNothing);

    AppLanguage.current.value = 'hi';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LocalizedText('दवाई सहेजें / Save Medicine'),
        ),
      ),
    );
    expect(find.text('दवाई सहेजें'), findsOneWidget);
    expect(find.text('Save Medicine'), findsNothing);
    AppLanguage.current.value = 'en';
  });

  test('every static Hindi UI label has an English rendering', () {
    final untranslated = <String>[];
    final missingHindi = <String>[];
    final mixed = <String>[];
    final literalPattern = RegExp(
      r'''(?:LocalizedText|AppLanguage\.text)\(\s*(?:'([^']*)'|"([^"]*)")''',
      multiLine: true,
    );

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in literalPattern.allMatches(source)) {
        final literal =
            (match.group(1) ?? match.group(2)!).replaceAll(r'\n', '\n');
        final english = AppLanguage.text(literal, languageCode: 'en');
        final hindi = AppLanguage.text(literal, languageCode: 'hi');
        if (RegExp(r'[\u0900-\u097F]').hasMatch(english)) {
          untranslated.add('${entity.path}: $literal');
        }
        final visibleLiteral = literal.replaceAll(RegExp(r'\$\{[^}]*\}'), '');
        final technicalOnly = RegExp(
              r'^(?:BP|ECG|X-Ray|QR|Google|WhatsApp|mg|ml|kg|cm|mmHg|bpm|IU|AM|PM|[\d\s.:+%/_-]+)$',
              caseSensitive: false,
            ).hasMatch(visibleLiteral.trim()) ||
            const {'G', 'BMI', 'mg/dL', 'v1.0.0'}
                .contains(visibleLiteral.trim()) ||
            !RegExp(r'[A-Za-z]').hasMatch(visibleLiteral);
        if (!RegExp(r'[\u0900-\u097F]').hasMatch(literal) &&
            RegExp(r'[A-Za-z]').hasMatch(literal) &&
            hindi == literal &&
            !technicalOnly) {
          missingHindi.add('${entity.path}: $literal');
        }
        if (english.contains(' / ') || hindi.contains(' / ')) {
          mixed.add('${entity.path}: $literal');
        }
      }
    }

    expect(untranslated, isEmpty, reason: untranslated.join('\n'));
    expect(missingHindi, isEmpty, reason: missingHindi.join('\n'));
    expect(mixed, isEmpty, reason: mixed.join('\n'));
  });
}
