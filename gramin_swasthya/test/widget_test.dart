// Unit tests for the health-calculation utilities.
//
// These replace the default Flutter "counter" boilerplate test, which never
// matched this app and always failed. The calculators are pure logic, so they
// can be tested without Firebase / platform initialization.

import 'package:flutter_test/flutter_test.dart';

import 'package:gramin_swasthya/utils/bmi_calculator.dart';
import 'package:gramin_swasthya/utils/bp_calculator.dart';
import 'package:gramin_swasthya/utils/sugar_classification.dart';

void main() {
  group('BmiCalculator', () {
    test('returns 0 for non-positive inputs', () {
      expect(BmiCalculator.calculate(0, 170), 0.0);
      expect(BmiCalculator.calculate(70, 0), 0.0);
      expect(BmiCalculator.calculate(-5, 170), 0.0);
    });

    test('computes a correct BMI value', () {
      // 70kg at 175cm -> 22.86
      expect(BmiCalculator.calculate(70, 175), closeTo(22.86, 0.01));
    });

    test('classifies BMI into the right category', () {
      expect(BmiCalculator.classify(17.0), BmiCategory.underweight);
      expect(BmiCalculator.classify(18.5), BmiCategory.normal); // boundary
      expect(BmiCalculator.classify(22.0), BmiCategory.normal);
      expect(BmiCalculator.classify(25.0), BmiCategory.overweight); // boundary
      expect(BmiCalculator.classify(27.0), BmiCategory.overweight);
      expect(BmiCalculator.classify(30.0), BmiCategory.obese); // boundary
      expect(BmiCalculator.classify(35.0), BmiCategory.obese);
    });
  });

  group('BPCalculator', () {
    test('returns null for non-positive inputs', () {
      expect(BPCalculator.calculate(0, 80), isNull);
      expect(BPCalculator.calculate(120, 0), isNull);
    });

    test('classifies blood pressure categories', () {
      expect(BPCalculator.calculate(110, 70)!.category, 'Normal');
      expect(BPCalculator.calculate(125, 75)!.category, 'Elevated');
      expect(BPCalculator.calculate(135, 75)!.category, 'Hypertension Stage 1');
      expect(BPCalculator.calculate(120, 85)!.category, 'Hypertension Stage 1');
      expect(BPCalculator.calculate(150, 95)!.category, 'Hypertension Stage 2');
      expect(BPCalculator.calculate(185, 100)!.category, 'Hypertensive Crisis');
      expect(BPCalculator.calculate(120, 125)!.category, 'Hypertensive Crisis');
    });
  });

  group('SugarClassification', () {
    test('classifies fasting glucose', () {
      expect(SugarClassification.getLevel(SugarType.fasting, 90),
          SugarLevel.normal);
      expect(SugarClassification.getLevel(SugarType.fasting, 110),
          SugarLevel.prediabetic);
      expect(SugarClassification.getLevel(SugarType.fasting, 130),
          SugarLevel.diabetic);
    });

    test('classifies post-meal / random glucose', () {
      expect(SugarClassification.getLevel(SugarType.postMeal, 120),
          SugarLevel.normal);
      expect(SugarClassification.getLevel(SugarType.postMeal, 160),
          SugarLevel.prediabetic);
      expect(SugarClassification.getLevel(SugarType.random, 210),
          SugarLevel.diabetic);
    });
  });
}
