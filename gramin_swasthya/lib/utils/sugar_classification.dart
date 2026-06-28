import 'package:flutter/material.dart';

enum SugarType { fasting, postMeal, random }

enum SugarLevel { normal, prediabetic, diabetic }

class SugarClassification {
  static SugarLevel getLevel(SugarType type, double value) {
    if (type == SugarType.fasting) {
      if (value < 100) return SugarLevel.normal;
      if (value >= 100 && value <= 125) return SugarLevel.prediabetic;
      return SugarLevel.diabetic;
    } else {
      // postMeal & random
      if (value < 140) return SugarLevel.normal;
      if (value >= 140 && value <= 199) return SugarLevel.prediabetic;
      return SugarLevel.diabetic;
    }
  }

  static Color getBgColor(SugarLevel level, ColorScheme colorScheme) {
    switch (level) {
      case SugarLevel.normal:
        return Colors.green.shade100;
      case SugarLevel.prediabetic:
        return Colors.amber.shade200;
      case SugarLevel.diabetic:
        return colorScheme.errorContainer;
    }
  }

  static Color getFgColor(SugarLevel level, ColorScheme colorScheme) {
    switch (level) {
      case SugarLevel.normal:
        return Colors.green.shade800;
      case SugarLevel.prediabetic:
        return Colors.brown.shade800;
      case SugarLevel.diabetic:
        return colorScheme.onErrorContainer;
    }
  }

  static String getLabel(SugarLevel level) {
    switch (level) {
      case SugarLevel.normal:
        return 'सामान्य (Normal)';
      case SugarLevel.prediabetic:
        return 'प्रीडायबिटिक (Prediabetic)';
      case SugarLevel.diabetic:
        return 'उच्च (Diabetic)';
    }
  }
}
