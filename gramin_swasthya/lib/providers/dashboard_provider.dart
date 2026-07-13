import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'family_provider.dart';
import 'health_data_provider.dart';
import 'medicines_provider.dart';

class HealthSummary {
  final String latestBp;
  final String latestSugar;
  final String latestWeight;
  final String? bpCategory;
  final Color? bpColor;

  const HealthSummary({
    required this.latestBp,
    required this.latestSugar,
    required this.latestWeight,
    this.bpCategory,
    this.bpColor,
  });
}

class MedicineReminder {
  final String id;
  final String name;
  final String dosage;
  final String time;
  final bool isTaken;

  const MedicineReminder({
    required this.id,
    required this.name,
    required this.dosage,
    required this.time,
    required this.isTaken,
  });
}

// --- BP Calculator Logic ---
Map<String, dynamic> _classifyBp(int systolic, int diastolic) {
  if (systolic < 120 && diastolic < 80) {
    return {'category': 'Normal', 'color': Colors.green};
  } else if (systolic >= 120 && systolic <= 129 && diastolic < 80) {
    return {'category': 'Elevated', 'color': Colors.amber};
  } else if ((systolic >= 130 && systolic <= 139) ||
      (diastolic >= 80 && diastolic <= 89)) {
    return {'category': 'Stage 1', 'color': Colors.orange};
  } else if ((systolic >= 140 && systolic <= 179) ||
      (diastolic >= 90 && diastolic <= 119)) {
    return {'category': 'Stage 2', 'color': Colors.redAccent};
  } else if (systolic >= 180 || diastolic >= 120) {
    return {'category': 'Crisis', 'color': Colors.red.shade900};
  }
  return {'category': '', 'color': Colors.grey};
}

// Read latest values from the actual HealthRepo streams with BP classification
final healthSummaryProvider = Provider<HealthSummary>((ref) {
  final bpAsync = ref.watch(bpStreamProvider);
  final sugarAsync = ref.watch(sugarStreamProvider);
  final weightAsync = ref.watch(weightStreamProvider);

  String latestBp = '--';
  String? bpCategory;
  Color? bpColor;

  bpAsync.whenOrNull(data: (list) {
    if (list.isNotEmpty) {
      final r = list.first;
      latestBp = '${r.systolic}/${r.diastolic}';
      final bp = _classifyBp(r.systolic, r.diastolic);
      bpCategory = bp['category'] as String;
      bpColor = bp['color'] as Color;
    }
  });

  final latestSugar = sugarAsync.whenOrNull(data: (list) {
        if (list.isEmpty) return '--';
        return '${list.first.glucose} mg/dL';
      }) ??
      '--';

  final latestWeight = weightAsync.whenOrNull(data: (list) {
        if (list.isEmpty) return '--';
        return '${list.first.weight} kg';
      }) ??
      '--';

  return HealthSummary(
    latestBp: latestBp,
    latestSugar: latestSugar,
    latestWeight: latestWeight,
    bpCategory: bpCategory,
    bpColor: bpColor,
  );
});

// Real medicines from the database — today's active reminders
final todayMedicinesProvider = Provider<List<MedicineReminder>>((ref) {
  final medicinesAsync = ref.watch(medicinesStreamProvider);
  final now = DateTime.now();

  return medicinesAsync.maybeWhen(
    data: (medicines) {
      final List<MedicineReminder> reminders = [];

      for (final med in medicines) {
        if (!med.isActive) continue;

        for (final time in med.times) {
          final timeStr = DateFormat('h:mm a').format(
            DateTime(now.year, now.month, now.day, time.hour, time.minute),
          );

          // Check if this specific time slot was taken today
          final isTaken = med.takenHistory.any((dt) =>
              dt.year == now.year &&
              dt.month == now.month &&
              dt.day == now.day);

          reminders.add(MedicineReminder(
            id: med.id,
            name: med.name,
            dosage: '${med.dosage} ${med.unit}',
            time: timeStr,
            isTaken: isTaken,
          ));
        }
      }

      // Sort: untaken first, then by time
      reminders.sort((a, b) {
        if (a.isTaken != b.isTaken) return a.isTaken ? 1 : -1;
        return a.time.compareTo(b.time);
      });

      return reminders;
    },
    orElse: () => [],
  );
});

// Family branding: "[Last Name] Family" / "[Last Name] परिवार"
final familyBrandingProvider = Provider<String>((ref) {
  final members = ref.watch(familyProvider);
  if (members.isEmpty) return 'My Family';

  final primary =
      members.firstWhere((m) => m.isPrimary, orElse: () => members.first);
  final parts = primary.name.trim().split(' ');
  final lastName = parts.length > 1 ? parts.last : parts.first;
  return '$lastName परिवार / $lastName Family';
});
