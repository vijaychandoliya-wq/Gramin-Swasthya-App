import 'package:flutter/material.dart';

class BPResult {
  final int systolic;
  final int diastolic;
  final String category;
  final Color color;
  final Color textColor;
  final String advice;
  final String categoryHindi;
  final int severityRank;
  final bool isolatedSystolic;
  final bool highDemographicRisk;

  const BPResult({
    required this.systolic,
    required this.diastolic,
    required this.category,
    required this.color,
    required this.textColor,
    required this.advice,
    required this.categoryHindi,
    this.severityRank = 0,
    this.isolatedSystolic = false,
    this.highDemographicRisk = false,
  });
}

class BPCalculator {
  static BPResult? calculate(
    int systolic,
    int diastolic, {
    int age = 18,
    String biologicalSex = 'male',
  }) {
    if (systolic <= 0 || diastolic <= 0) return null;

    // A missing profile age is represented by 0 in the existing schema and
    // must use the adult rule branch, not pediatric thresholds.
    final effectiveAge = age > 0 ? age : 18;
    final ageGroup = effectiveAge >= 60
        ? 'geriatric'
        : effectiveAge >= 18
            ? 'adult'
            : effectiveAge >= 13
                ? 'adolescent'
                : 'pediatric';

    if (systolic < 90 || diastolic < 60) {
      return BPResult(
        systolic: systolic,
        diastolic: diastolic,
        category: 'Low (Hypotension)',
        categoryHindi: 'निम्न रक्तचाप',
        color: Colors.blue.shade100,
        textColor: Colors.blue.shade900,
        advice:
            'Low BP detected. Monitor dizziness or fainting and consult a doctor if persistent.',
        severityRank: -1,
      );
    }

    if (ageGroup == 'pediatric') {
      return BPResult(
        systolic: systolic,
        diastolic: diastolic,
        category: 'Percentile evaluation required',
        categoryHindi: 'प्रतिशतक जांच आवश्यक',
        color: Colors.blue.shade100,
        textColor: Colors.blue.shade900,
        advice:
            'For children under 13, compare age, sex, and height percentile with the IAP reference chart.',
      );
    }

    if (ageGroup == 'adolescent') {
      final sysRank = systolic >= 140
          ? 3
          : systolic >= 130
              ? 2
              : systolic >= 120
                  ? 1
                  : 0;
      final diaRank = diastolic >= 90
          ? 3
          : diastolic >= 80
              ? 2
              : 0;
      final rank = sysRank > diaRank ? sysRank : diaRank;
      const categories = [
        'Normal',
        'Elevated',
        'Stage 1 Hypertension',
        'Stage 2 Hypertension'
      ];
      return BPResult(
        systolic: systolic,
        diastolic: diastolic,
        category: categories[rank],
        categoryHindi: categories[rank],
        color: _colorForRank(rank),
        textColor: _textColorForRank(rank),
        advice: rank >= 2
            ? 'Persistent high readings should be reviewed by a clinician.'
            : 'Continue routine health tracking.',
        severityRank: rank,
      );
    }

    final sysRank = systolic >= 180
        ? 5
        : systolic >= 160
            ? 4
            : systolic >= 140
                ? 3
                : systolic >= 130
                    ? 2
                    : systolic >= 120
                        ? 1
                        : 0;
    final diaRank = diastolic >= 110
        ? 5
        : diastolic >= 100
            ? 4
            : diastolic >= 90
                ? 3
                : diastolic >= 85
                    ? 2
                    : diastolic >= 80
                        ? 1
                        : 0;
    final rank = sysRank > diaRank ? sysRank : diaRank;
    final isolated = systolic >= 140 && diastolic < 90;
    final hypertensive = rank >= 3 || isolated;
    final sex = biologicalSex.toLowerCase();
    final highRisk = hypertensive &&
        ((sex.contains('female') && effectiveAge > 65) ||
            (sex.contains('male') && effectiveAge > 55) ||
            effectiveAge >= 60);
    final category = isolated
        ? 'Isolated Systolic Hypertension (ISH)'
        : const [
            'Optimal',
            'Normal',
            'High-Normal',
            'Stage 1 Hypertension',
            'Stage 2 Hypertension',
            'Stage 3 Hypertension (Severe)'
          ][rank];
    final advice = rank >= 5
        ? 'Severe hypertension detected. Seek medical attention immediately.'
        : rank >= 4
            ? 'Arrange a medical evaluation within 48 hours and repeat the reading.'
            : rank >= 3 || isolated
                ? highRisk
                    ? 'High-risk profile. Consult a physician within 7 days.'
                    : 'Adopt lifestyle changes, repeat readings, and consult a doctor.'
                : 'Continue healthy habits and routine monitoring.';
    return BPResult(
      systolic: systolic,
      diastolic: diastolic,
      category: category,
      categoryHindi: category,
      color: _colorForRank(rank),
      textColor: _textColorForRank(rank),
      advice: advice,
      severityRank: rank,
      isolatedSystolic: isolated,
      highDemographicRisk: highRisk,
    );
  }

  static Color _colorForRank(int rank) {
    if (rank >= 5) return Colors.red.shade800;
    if (rank >= 3) return Colors.red.shade200;
    if (rank == 2) return Colors.orange.shade200;
    if (rank == 1) return Colors.amber.shade200;
    return Colors.green.shade100;
  }

  static Color _textColorForRank(int rank) {
    return rank >= 5 ? Colors.white : Colors.grey.shade900;
  }
}
