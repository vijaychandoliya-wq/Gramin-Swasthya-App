import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gramin_swasthya/db/database_helper.dart';
import 'package:gramin_swasthya/l10n/app_language.dart';
import 'package:gramin_swasthya/l10n/localized_text.dart';
import 'package:gramin_swasthya/l10n/generated_translations.dart';
import 'package:gramin_swasthya/services/notification_service.dart';
import 'package:gramin_swasthya/utils/bp_calculator.dart';
import 'package:flutter/material.dart';

void main() {
  test('BP rules use profile age and adult fallback', () {
    expect(BPCalculator.calculate(135, 82, age: 16)?.category,
        'Stage 1 Hypertension');
    expect(BPCalculator.calculate(135, 82, age: 0)?.category, 'High-Normal');
    expect(BPCalculator.calculate(150, 76, age: 68)?.isolatedSystolic, isTrue);
    expect(BPCalculator.calculate(150, 115, age: 40)?.severityRank, 5);
  });

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

  test('every selectable regional language has a complete offline pack', () {
    final regionalCodes = AppLanguage.supportedCodes.difference({'en', 'hi'});
    expect(generatedTranslations.keys.toSet(), regionalCodes);
    for (final code in regionalCodes) {
      final pack = generatedTranslations[code]!;
      expect(pack.length, greaterThanOrEqualTo(260), reason: code);
      expect(pack.values.where((value) => value.trim().isEmpty), isEmpty,
          reason: code);
      expect(AppLanguage.text('Save Report', languageCode: code),
          isNot('Save Report'),
          reason: code);
      expect(AppLanguage.text('Save Report', languageCode: code),
          isNot(contains(' / ')),
          reason: code);
    }

    final bodo =
        AppLanguage.languages.singleWhere((item) => item.code == 'brx');
    expect(bodo.available, isFalse);
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
    final missingRegional = <String>[];
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
        if (!literal.contains(r'$') &&
            !literal.contains(r'\') &&
            !technicalOnly &&
            RegExp(r'[A-Za-z]').hasMatch(english)) {
          for (final code
              in AppLanguage.supportedCodes.difference({'en', 'hi'})) {
            final lookup = english.trim() == 'Let the doctor scan this code'
                ? 'Show this code to your doctor'
                : english.trim();
            final covered = generatedTranslations[code]!
                .keys
                .any((key) => key.trim() == lookup);
            if (!covered) {
              missingRegional.add('$code ${entity.path}: $english');
            }
          }
        }
      }
    }

    expect(untranslated, isEmpty, reason: untranslated.join('\n'));
    expect(missingHindi, isEmpty, reason: missingHindi.join('\n'));
    expect(mixed, isEmpty, reason: mixed.join('\n'));
    expect(missingRegional, isEmpty, reason: missingRegional.join('\n'));
  });
}
