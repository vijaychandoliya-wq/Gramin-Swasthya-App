import 'package:flutter/material.dart';

enum BmiCategory { underweight, normal, overweight, obese }

class BmiCalculator {
  static double calculate(double weightKg, double heightCm) {
    if (heightCm <= 0 || weightKg <= 0) return 0.0;
    final double heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  static BmiCategory classify(double bmi) {
    if (bmi < 18.5) return BmiCategory.underweight;
    if (bmi >= 18.5 && bmi < 25.0) return BmiCategory.normal;
    if (bmi >= 25.0 && bmi < 30.0) return BmiCategory.overweight;
    return BmiCategory.obese;
  }

  static Color getBgColor(BmiCategory category, ColorScheme colorScheme) {
    switch (category) {
      case BmiCategory.underweight:
        return Colors.blue.shade100;
      case BmiCategory.normal:
        return Colors.green.shade100;
      case BmiCategory.overweight:
        return Colors.amber.shade200;
      case BmiCategory.obese:
        return colorScheme.errorContainer;
    }
  }

  static Color getFgColor(BmiCategory category, ColorScheme colorScheme) {
    switch (category) {
      case BmiCategory.underweight:
        return Colors.blue.shade900;
      case BmiCategory.normal:
        return Colors.green.shade900;
      case BmiCategory.overweight:
        return Colors.brown.shade900;
      case BmiCategory.obese:
        return colorScheme.onErrorContainer;
    }
  }

  static String getLabelHindi(BmiCategory category) {
    switch (category) {
      case BmiCategory.underweight:
        return 'कम वजन';
      case BmiCategory.normal:
        return 'सामान्य';
      case BmiCategory.overweight:
        return 'अधिक वजन';
      case BmiCategory.obese:
        return 'मोटापा';
    }
  }
}
