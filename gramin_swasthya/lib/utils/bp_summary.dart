import 'dart:math';

import '../providers/health_data_provider.dart';
import 'bp_calculator.dart';

class BPSummary {
  final List<BpRecord> readings;

  BPSummary(this.readings);

  // --- Systolic Stats ---
  double get avgSystolic =>
      readings.map((r) => r.systolic).reduce((a, b) => a + b) /
      readings.length;

  int get minSystolic => readings.map((r) => r.systolic).reduce(min);

  int get maxSystolic => readings.map((r) => r.systolic).reduce(max);

  // --- Diastolic Stats ---
  double get avgDiastolic =>
      readings.map((r) => r.diastolic).reduce((a, b) => a + b) /
      readings.length;

  int get minDiastolic => readings.map((r) => r.diastolic).reduce(min);

  int get maxDiastolic => readings.map((r) => r.diastolic).reduce(max);

  // --- Pulse Pressure (Systolic - Diastolic) ---
  double get avgPulsePressure => avgSystolic - avgDiastolic;

  // --- Mean Arterial Pressure: MAP = DBP + 1/3(SBP - DBP) ---
  double get avgMAP => avgDiastolic + (avgSystolic - avgDiastolic) / 3;

  // --- Category Distribution ---
  /// Returns a map of all BP categories with their count from the readings.
  /// Categories use the same strings as BPCalculator.
  Map<String, int> get categoryDistribution {
    final map = <String, int>{
      'Severe Hypotension': 0,
      'Hypotension': 0,
      'Normal': 0,
      'Elevated': 0,
      'Hypertension Stage 1': 0,
      'Hypertension Stage 2': 0,
      'Hypertensive Crisis': 0,
    };

    for (final r in readings) {
      final result = BPCalculator.calculate(r.systolic, r.diastolic);
      if (result != null) {
        map[result.category] = (map[result.category] ?? 0) + 1;
      }
    }

    return map;
  }

  /// Returns only non-zero categories for display.
  Map<String, int> get nonZeroCategoryDistribution {
    return Map.fromEntries(
      categoryDistribution.entries.where((e) => e.value > 0),
    );
  }

  /// The most frequent category across all readings.
  String get dominantCategory {
    final dist = categoryDistribution;
    return dist.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Percentage of readings that are abnormal (not Normal).
  double get abnormalPercentage {
    final dist = categoryDistribution;
    final normal = dist['Normal'] ?? 0;
    return ((readings.length - normal) / readings.length) * 100;
  }
}
