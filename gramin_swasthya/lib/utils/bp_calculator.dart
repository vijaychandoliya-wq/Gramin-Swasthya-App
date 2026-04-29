import 'package:flutter/material.dart';

class BPResult {
  final int systolic;
  final int diastolic;
  final String category;
  final Color color;
  final Color textColor;
  final String advice;
  final String categoryHindi;

  const BPResult({
    required this.systolic,
    required this.diastolic,
    required this.category,
    required this.color,
    required this.textColor,
    required this.advice,
    required this.categoryHindi,
  });
}

class BPCalculator {
  static BPResult? calculate(int systolic, int diastolic) {
    if (systolic <= 0 || diastolic <= 0) return null;

    String category;
    String categoryHindi;
    Color color;
    Color textColor;
    String advice;

    // --- HIGH BP (NICE 2019 Clinic BP) — check from highest first ---
    if (systolic >= 180 || diastolic >= 120) {
      category = 'Hypertensive Crisis';
      categoryHindi = 'गंभीर स्थिति';
      color = Colors.red.shade800;
      textColor = Colors.white;
      advice =
          'Seek emergency care immediately / तुरंत आपातकालीन चिकित्सा लें';
    } else if ((systolic >= 140 && systolic <= 179) ||
        (diastolic >= 90 && diastolic <= 119)) {
      category = 'Hypertension Stage 2';
      categoryHindi = 'उच्च रक्तचाप - चरण 2';
      color = Colors.red.shade200;
      textColor = Colors.red.shade900;
      advice = 'Medical attention required / चिकित्सा ध्यान आवश्यक';
    } else if ((systolic >= 130 && systolic <= 139) ||
        (diastolic >= 80 && diastolic <= 89)) {
      category = 'Hypertension Stage 1';
      categoryHindi = 'उच्च रक्तचाप - चरण 1';
      color = Colors.orange.shade200;
      textColor = Colors.orange.shade900;
      advice =
          'Consult doctor & lifestyle changes / डॉक्टर से मिलें और जीवनशैली बदलें';
    } else if (systolic >= 120 && systolic <= 129 && diastolic < 80) {
      category = 'Elevated';
      categoryHindi = 'सीमारेखा';
      color = Colors.amber.shade200;
      textColor = Colors.brown.shade800;
      advice =
          'Monitor regularly & reduce salt / नियमित जांच करें और नमक कम करें';
    // --- LOW BP (NHLBI / Clinical Practice) ---
    } else if (systolic < 70 || diastolic < 40) {
      category = 'Severe Hypotension';
      categoryHindi = 'गंभीर निम्न रक्तचाप';
      color = const Color(0xFF1A5276);
      textColor = Colors.white;
      advice =
          'Seek emergency care immediately / तुरंत आपातकालीन चिकित्सा लें';
    } else if (systolic < 90 || diastolic < 60) {
      category = 'Hypotension';
      categoryHindi = 'निम्न रक्तचाप';
      color = const Color(0xFFD6EAF8);
      textColor = const Color(0xFF1A5276);
      advice =
          'Drink fluids, consult doctor if dizzy / तरल पदार्थ लें, चक्कर आए तो डॉक्टर से मिलें';
    // --- NORMAL ---
    } else {
      category = 'Normal';
      categoryHindi = 'सामान्य';
      color = Colors.green.shade100;
      textColor = Colors.green.shade800;
      advice = 'Maintain healthy lifestyle / स्वस्थ जीवनशैली बनाए रखें';
    }

    return BPResult(
      systolic: systolic,
      diastolic: diastolic,
      category: category,
      categoryHindi: categoryHindi,
      color: color,
      textColor: textColor,
      advice: advice,
    );
  }
}
