// This file is deprecated. Use health_data_provider.dart instead.
// Kept for backward compatibility — any imports should be migrated.

import 'package:flutter_riverpod/flutter_riverpod.dart';

class BpReading {
  final String id;
  final int systolic;
  final int diastolic;
  final int? pulse;
  final String? notes;
  final DateTime recordedAt;

  BpReading({
    required this.id,
    required this.systolic,
    required this.diastolic,
    this.pulse,
    this.notes,
    required this.recordedAt,
  });
}

class SugarReading {
  final String id;
  final double value;
  final String type;
  final String? notes;
  final DateTime recordedAt;

  SugarReading({
    required this.id,
    required this.value,
    required this.type,
    this.notes,
    required this.recordedAt,
  });
}

class WeightEntry {
  final String id;
  final double weightKg;
  final String? notes;
  final DateTime recordedAt;

  WeightEntry({
    required this.id,
    required this.weightKg,
    this.notes,
    required this.recordedAt,
  });
}

class HealthDataState {
  final List<BpReading> bpReadings;
  final List<SugarReading> sugarReadings;
  final List<WeightEntry> weightEntries;

  HealthDataState({
    this.bpReadings = const [],
    this.sugarReadings = const [],
    this.weightEntries = const [],
  });

  HealthDataState copyWith({
    List<BpReading>? bpReadings,
    List<SugarReading>? sugarReadings,
    List<WeightEntry>? weightEntries,
  }) {
    return HealthDataState(
      bpReadings: bpReadings ?? this.bpReadings,
      sugarReadings: sugarReadings ?? this.sugarReadings,
      weightEntries: weightEntries ?? this.weightEntries,
    );
  }
}

final healthProvider =
    StateNotifierProvider<HealthNotifier, HealthDataState>((ref) {
  return HealthNotifier();
});

class HealthNotifier extends StateNotifier<HealthDataState> {
  HealthNotifier() : super(HealthDataState());

  void addBpReading(
      {required int systolic,
      required int diastolic,
      int? pulse,
      String? notes}) {
    // Deprecated — use healthRepoProvider from health_data_provider.dart
  }

  void addSugarReading(
      {required double value, required String type, String? notes}) {
    // Deprecated
  }

  void addWeightEntry({required double weightKg, String? notes}) {
    // Deprecated
  }
}
