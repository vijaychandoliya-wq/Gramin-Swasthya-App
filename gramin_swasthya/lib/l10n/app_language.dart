import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'generated_translations.dart';

class AppLocaleInfo {
  const AppLocaleInfo({
    required this.code,
    required this.englishName,
    required this.nativeName,
    this.available = true,
  });

  final String code;
  final String englishName;
  final String nativeName;
  final bool available;
}

class AppLanguage {
  AppLanguage._();

  static const languages = <AppLocaleInfo>[
    AppLocaleInfo(code: 'en', englishName: 'English', nativeName: 'English'),
    AppLocaleInfo(code: 'as', englishName: 'Assamese', nativeName: 'অসমীয়া'),
    AppLocaleInfo(code: 'awa', englishName: 'Awadhi', nativeName: 'अवधी'),
    AppLocaleInfo(code: 'bn', englishName: 'Bengali', nativeName: 'বাংলা'),
    AppLocaleInfo(code: 'bho', englishName: 'Bhojpuri', nativeName: 'भोजपुरी'),
    AppLocaleInfo(
        code: 'brx', englishName: 'Bodo', nativeName: 'बड़ो', available: false),
    AppLocaleInfo(code: 'doi', englishName: 'Dogri', nativeName: 'डोगरी'),
    AppLocaleInfo(code: 'gu', englishName: 'Gujarati', nativeName: 'ગુજરાતી'),
    AppLocaleInfo(code: 'hi', englishName: 'Hindi', nativeName: 'हिंदी'),
    AppLocaleInfo(code: 'kn', englishName: 'Kannada', nativeName: 'ಕನ್ನಡ'),
    AppLocaleInfo(code: 'kha', englishName: 'Khasi', nativeName: 'Khasi'),
    AppLocaleInfo(code: 'trp', englishName: 'Kokborok', nativeName: 'Kokborok'),
    AppLocaleInfo(code: 'gom', englishName: 'Konkani', nativeName: 'कोंकणी'),
    AppLocaleInfo(code: 'mai', englishName: 'Maithili', nativeName: 'मैथिली'),
    AppLocaleInfo(code: 'ml', englishName: 'Malayalam', nativeName: 'മലയാളം'),
    AppLocaleInfo(
        code: 'mni-Mtei',
        englishName: 'Manipuri (Meiteilon)',
        nativeName: 'ꯃꯤꯇꯩ ꯂꯣꯟ'),
    AppLocaleInfo(code: 'mr', englishName: 'Marathi', nativeName: 'मराठी'),
    AppLocaleInfo(code: 'mwr', englishName: 'Marwadi', nativeName: 'मारवाड़ी'),
    AppLocaleInfo(code: 'lus', englishName: 'Mizo', nativeName: 'Mizo ṭawng'),
    AppLocaleInfo(code: 'or', englishName: 'Odia', nativeName: 'ଓଡ଼ିଆ'),
    AppLocaleInfo(
        code: 'pa', englishName: 'Punjabi (Gurmukhi)', nativeName: 'ਪੰਜਾਬੀ'),
    AppLocaleInfo(
        code: 'pa-Arab',
        englishName: 'Punjabi (Shahmukhi)',
        nativeName: 'پنجابی'),
    AppLocaleInfo(code: 'sa', englishName: 'Sanskrit', nativeName: 'संस्कृतम्'),
    AppLocaleInfo(code: 'sat', englishName: 'Santali', nativeName: 'ᱥᱟᱱᱛᱟᱲᱤ'),
    AppLocaleInfo(code: 'ta', englishName: 'Tamil', nativeName: 'தமிழ்'),
    AppLocaleInfo(code: 'te', englishName: 'Telugu', nativeName: 'తెలుగు'),
    AppLocaleInfo(code: 'tcy', englishName: 'Tulu', nativeName: 'ತುಳು'),
    AppLocaleInfo(code: 'ur', englishName: 'Urdu', nativeName: 'اردو'),
  ];

  static final Set<String> supportedCodes = {
    for (final language in languages)
      if (language.available) language.code,
  };

  static final List<Locale> supportedLocales =
      supportedCodes.map(localeFor).toList();
  static const Set<String> _flutterMaterialCodes = {
    'en',
    'as',
    'bn',
    'gu',
    'hi',
    'kn',
    'ml',
    'mr',
    'or',
    'pa',
    'ta',
    'te',
    'ur',
  };
  static const List<Locale> materialSupportedLocales = [
    Locale('en'),
    Locale('as'),
    Locale('bn'),
    Locale('gu'),
    Locale('hi'),
    Locale('kn'),
    Locale('ml'),
    Locale('mr'),
    Locale('or'),
    Locale('pa'),
    Locale('ta'),
    Locale('te'),
    Locale('ur'),
  ];
  static final ValueNotifier<String> current = ValueNotifier<String>('en');

  static bool get isHindi => current.value == 'hi';

  static AppLocaleInfo get currentInfo => languages.firstWhere(
        (language) => language.code == current.value,
        orElse: () => languages.first,
      );

  static Locale localeFor(String code) {
    final parts = code.split('-');
    return parts.length == 1
        ? Locale(parts.first)
        : Locale.fromSubtags(languageCode: parts.first, scriptCode: parts[1]);
  }

  /// Flutter does not yet ship Material widget translations for every Google
  /// Translate locale. App-owned text still uses [current]; framework-owned
  /// controls use the closest safe locale so selecting a dialect never crashes.
  static Locale materialLocaleFor(String code) {
    if (code == 'pa-Arab') return const Locale('ur');
    final base = code.split('-').first;
    return _flutterMaterialCodes.contains(base)
        ? Locale(base)
        : const Locale('en');
  }

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('language');
    current.value = supportedCodes.contains(saved) ? saved! : 'en';
  }

  static Future<void> setLanguage(String code) async {
    if (!supportedCodes.contains(code)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', code);
    current.value = code;
  }

  static String text(String source, {String? languageCode}) {
    final code = languageCode ?? current.value;
    if (code == 'en') return _toEnglish(source);
    if (code == 'hi') return _toHindi(source);
    return _toGeneratedLanguage(source, code);
  }

  static String _toGeneratedLanguage(String source, String code) {
    final translations = generatedTranslations[code];
    if (translations == null) return _toEnglish(source);
    var value = _toEnglish(source);
    final canonical = _generatedAliases[value.trim()] ?? value.trim();
    String? exact = translations[canonical];
    if (exact == null) {
      for (final entry in translations.entries) {
        if (entry.key.trim() == canonical) {
          exact = entry.value.trim();
          break;
        }
      }
    }
    if (exact != null) return _restoreOuterWhitespace(value, exact);

    final replacements = translations.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in replacements) {
      value = value.replaceAll(entry.key, entry.value);
    }
    return value;
  }

  static const _generatedAliases = {
    'Let the doctor scan this code': 'Show this code to your doctor',
  };

  static String _toEnglish(String source) {
    var value = _selectBilingualPart(source, wantHindi: false);
    final exact = _hindiToEnglish[value.trim()];
    if (exact != null) return _restoreOuterWhitespace(value, exact);

    final replacements = _hindiToEnglish.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in replacements) {
      value = value.replaceAll(entry.key, entry.value);
    }
    return value;
  }

  static String _toHindi(String source) {
    var value = _selectBilingualPart(source, wantHindi: true);
    final exact = _englishToHindi[value.trim()];
    if (exact != null) return _restoreOuterWhitespace(value, exact);

    final replacements = _englishToHindi.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in replacements) {
      value = value.replaceAll(entry.key, entry.value);
    }
    return value;
  }

  static String _selectBilingualPart(
    String source, {
    required bool wantHindi,
  }) {
    var value = source;

    if (value.contains(' / ')) {
      final parts = value.split(' / ');
      final hindiParts = parts.where(_containsDevanagari).toList();
      final englishParts =
          parts.where((part) => RegExp(r'[A-Za-z]').hasMatch(part)).toList();
      if (wantHindi && hindiParts.isNotEmpty) {
        value = hindiParts.first.trim();
      } else if (!wantHindi && englishParts.isNotEmpty) {
        value = englishParts.last.trim();
      }
    }

    final lines = value.split('\n');
    if (lines.length > 1) {
      final matching = lines.where(
        (line) => wantHindi
            ? _containsDevanagari(line)
            : line.trim().isNotEmpty && !_containsDevanagari(line),
      );
      if (matching.isNotEmpty) value = matching.join('\n').trim();
    }

    final parenthetical =
        RegExp(r'^(.*?)\s*\(([^()]*)\)(.*)$').firstMatch(value);
    if (parenthetical != null) {
      final outside =
          '${parenthetical.group(1)}${parenthetical.group(3)}'.trim();
      final inside = parenthetical.group(2)!.trim();
      final outsideHindi = _containsDevanagari(outside);
      final insideHindi = _containsDevanagari(inside);
      if (outsideHindi != insideHindi) {
        value = wantHindi
            ? (outsideHindi ? outside : inside)
            : (outsideHindi ? inside : outside);
      }
    }

    return value;
  }

  static bool _containsDevanagari(String value) =>
      RegExp(r'[\u0900-\u097F]').hasMatch(value);

  static String _restoreOuterWhitespace(String original, String translated) {
    final leading = RegExp(r'^\s*').firstMatch(original)?.group(0) ?? '';
    final trailing = RegExp(r'\s*$').firstMatch(original)?.group(0) ?? '';
    return '$leading$translated$trailing';
  }

  static const Map<String, String> _englishToHindi = {
    'Home': 'होम',
    'Health': 'स्वास्थ्य',
    'Reports': 'रिपोर्ट',
    'Meds': 'दवाइयाँ',
    'Settings': 'सेटिंग्स',
    'English': 'अंग्रेज़ी',
    'Hindi': 'हिंदी',
    'Choose Your Language': 'अपनी भाषा चुनें',
    'Continue': 'जारी रखें',
    'Skip': 'छोड़ें',
    'Next': 'आगे',
    'Get Started': 'शुरू करें',
    'Search': 'खोजें',
    'Search...': 'खोजें...',
    'Search members, medicines, or reports...':
        'सदस्य, दवाई या रिपोर्ट खोजें...',
    'Recent Searches': 'हालिया खोजें',
    'Members': 'सदस्य',
    'Medicines': 'दवाइयाँ',
    'Family member': 'परिवार सदस्य',
    'No results found': 'कोई परिणाम नहीं मिला',
    'No member': 'कोई सदस्य नहीं',
    'Start searching...': 'खोजना शुरू करें...',
    'Data Synced': 'डेटा सिंक हुआ',
    'Offline': 'ऑफलाइन — डेटा सुरक्षित है',
    'Quick Add': 'त्वरित जोड़ें',
    'Cancel': 'रद्द करें',
    'Save': 'सहेजें',
    'Saving...': 'सहेजा जा रहा है...',
    'Add': 'जोड़ें',
    'Update': 'अपडेट करें',
    'Delete': 'हटाएँ',
    'Edit': 'संपादित करें',
    'Back': 'वापस',
    'Undo': 'पहले जैसा करें',
    'Optional': 'वैकल्पिक',
    'Name': 'नाम',
    'Age': 'उम्र',
    'years': 'वर्ष',
    'Gender': 'लिंग',
    'Male': 'पुरुष',
    'Female': 'महिला',
    'Other': 'अन्य',
    'Unknown': 'अज्ञात',
    'Blood Group': 'रक्त समूह',
    'Basic Info': 'बुनियादी जानकारी',
    'Health Info': 'स्वास्थ्य जानकारी',
    'Conditions': 'मौजूदा बीमारियाँ',
    'Emergency': 'आपातकालीन संपर्क',
    'Contact Name': 'संपर्क नाम',
    'Phone': 'फोन नंबर',
    'Add Member': 'सदस्य जोड़ें',
    'Edit Member': 'सदस्य संपादित करें',
    'Save Changes': 'बदलाव सहेजें',
    'Delete Member': 'सदस्य हटाएँ',
    'Primary': 'मुख्य',
    'Family': 'परिवार',
    'Self': 'स्वयं',
    'Diabetes': 'मधुमेह',
    'Hypertension': 'उच्च रक्तचाप',
    'Heart Disease': 'हृदय रोग',
    'Thyroid': 'थायराइड',
    'Asthma': 'अस्थमा',
    'Kidney Disease': 'गुर्दे की बीमारी',
    'Health Data': 'स्वास्थ्य डेटा',
    'History': 'इतिहास',
    'No Data': 'कोई डेटा नहीं',
    'No data in range': 'इस अवधि में कोई डेटा नहीं',
    'Blood Pressure': 'रक्तचाप',
    'Blood Sugar': 'ब्लड शुगर',
    'Sugar': 'शुगर',
    'Weight': 'वजन',
    'Height': 'लंबाई',
    'Pulse': 'नाड़ी',
    'Notes': 'नोट्स',
    'Fasting': 'खाली पेट',
    'After meal': 'खाने के बाद',
    'Random': 'कभी भी',
    'Normal': 'सामान्य',
    'Elevated': 'सीमारेखा',
    'Underweight': 'कम वजन',
    'Overweight': 'अधिक वजन',
    'Obese': 'मोटापा',
    'Add BP': 'BP जोड़ें',
    'Save BP': 'BP सहेजें',
    'Add Sugar': 'शुगर जोड़ें',
    'Save Sugar': 'शुगर सहेजें',
    'Add Weight': 'वजन जोड़ें',
    'Save Weight': 'वजन सहेजें',
    'Report': 'रिपोर्ट',
    'Add Report': 'रिपोर्ट जोड़ें',
    'Save Report': 'रिपोर्ट सहेजें',
    'Report Type': 'रिपोर्ट का प्रकार',
    'Doctor Name': 'डॉक्टर का नाम',
    'Camera': 'कैमरा',
    'Gallery': 'गैलरी',
    'Prescription': 'नुस्खा',
    'Lab Report': 'लैब रिपोर्ट',
    'No Reports': 'कोई रिपोर्ट नहीं',
    'Delete Report?': 'रिपोर्ट हटाएँ?',
    'Share': 'शेयर करें',
    'Download': 'डाउनलोड करें',
    'Medicine': 'दवाई',
    'Tablet': 'गोली',
    'Capsule': 'कैप्सूल',
    'Drops': 'बूँदें',
    'Units': 'इकाइयाँ',
    'Add Medicine': 'दवाई जोड़ें',
    'Edit Medicine': 'दवाई संपादित करें',
    'Medicine name': 'दवाई का नाम',
    'Dosage': 'खुराक',
    'Unit': 'इकाई',
    'Reminders': 'रिमाइंडर',
    'Duration': 'अवधि',
    'Always': 'हमेशा',
    'Start Date': 'प्रारंभ तिथि',
    'Enable reminders': 'दवाई रिमाइंडर चालू करें',
    'Save Medicine': 'दवाई सहेजें',
    'No Medicines': 'कोई दवाई नहीं',
    "Today's Meds": 'आज की दवाइयाँ',
    'remaining': 'बाकी हैं',
    'Taken': 'ली गई',
    'Take': 'लें',
    'Emergency Card': 'आपातकालीन कार्ड',
    'Emergency Contact': 'आपातकालीन संपर्क',
    'Share on WhatsApp': 'WhatsApp पर शेयर करें',
    'Save image': 'छवि सहेजें',
    'Share with Doctor': 'डॉक्टर को शेयर करें',
    'What to Share': 'क्या शेयर करें',
    'Link Validity': 'लिंक की वैधता',
    'Expired': 'समाप्त',
    'Create new': 'नया बनाएँ',
    'Share Link': 'लिंक शेयर करें',
    'Send on WhatsApp': 'WhatsApp पर भेजें',
    'Preferences': 'प्राथमिकताएँ',
    'Language': 'भाषा',
    'Cloud Backup': 'क्लाउड बैकअप',
    'Google Drive Link': 'गूगल ड्राइव लिंक',
    'Linked': 'संबद्ध',
    'Link': 'लिंक करें',
    'Unlink': 'हटाएँ',
    'Google Drive Backup': 'गूगल ड्राइव बैकअप',
    'Import Profile': 'प्रोफ़ाइल आयात करें',
    'About App': 'ऐप के बारे में',
    'Version': 'वर्शन',
    'Privacy': 'गोपनीयता नीति',
    'Help': 'मदद',
    'Erase All Data': 'सब कुछ मिटाएँ',
    'OK': 'ठीक है',
    'No Backups': 'कोई बैकअप नहीं',
    'Error saving': 'सहेजने में त्रुटि',
    'Loading...': 'लोड हो रहा है...',
    'Unable to load': 'लोड करने में असमर्थ',
    'Error:': 'त्रुटि:',
    'Placeholder for': 'अस्थायी स्क्रीन:',
    'Select what you want to share': 'चुनें कि आप क्या शेयर करना चाहते हैं',
    'Generate QR Code': 'QR कोड बनाएँ',
    'Show this code to your doctor': 'यह कोड अपने डॉक्टर को दिखाएँ',
    'They can scan it to view your selected health records securely.':
        'वे इसे स्कैन करके आपके चुने हुए स्वास्थ्य रिकॉर्ड सुरक्षित रूप से देख सकते हैं।',
    'This link will expire in 24 hours.':
        'यह लिंक 24 घंटे में समाप्त हो जाएगा।',
    'Blood:': 'रक्त समूह:',
    'Your health records, one secure account':
        'आपके स्वास्थ्य रिकॉर्ड, एक सुरक्षित खाता',
    'Sign in only once. This phone remembers your account for future app launches.':
        'केवल एक बार साइन इन करें। आगे से यह फ़ोन आपका खाता याद रखेगा।',
    'No password, PIN, or OTP required.':
        'पासवर्ड, पिन या OTP की आवश्यकता नहीं है।',
    'Systolic': 'ऊपरी रक्तचाप',
    'Diastolic': 'निचला रक्तचाप',
    'Post-meal': 'खाने के बाद',
    'e.g.': 'उदाहरण:',
    'Hello': 'नमस्ते',
    'All': 'सभी',
    'day': 'दिन',
    'days': 'दिन',
    'Last backup:': 'पिछला बैकअप:',
    'View all →': 'सभी देखें →',
    'Gramin Swasthya': 'ग्रामीण स्वास्थ्य',
    'Expires:': 'समाप्ति:',
    'Unable to open WhatsApp': 'WhatsApp शुरू करने में असमर्थ',
    'QR code': 'QR कोड',
    'Sign in with Google. Your first health profile will be created automatically using your name, email, and linked mobile number.':
        'Google से साइन इन करें। आपकी पहली स्वास्थ्य प्रोफ़ाइल आपके नाम, ईमेल और लिंक किए गए मोबाइल नंबर से अपने आप बन जाएगी।',
    'When was the sugar measured?': 'किस समय की शुगर है?',
    'Delete profile?': 'प्रोफ़ाइल हटाएँ?',
    'Are you sure you want to delete this profile?':
        'क्या आप वाकई इस प्रोफाइल को हटाना चाहते हैं?',
    'Add from camera or gallery': 'फोटो या गैलरी से जोड़ें',
  };

  static final Map<String, String> _hindiToEnglish = {
    for (final entry in _englishToHindi.entries) entry.value: entry.key,
    'अपनी भाषा चुनें': 'Choose Your Language',
    'परिवार का स्वास्थ्य रिकॉर्ड': 'Family health records',
    'एक ही जगह सभी मेडिकल जानकारी': 'All medical information in one place',
    'रोज़ाना BP और शुगर ट्रैक करें': 'Track BP and sugar every day',
    'ग्राफ देखें, ट्रेंड समझें': 'View graphs and understand trends',
    'Google से एक बार साइन इन करें': 'Sign in with Google once',
    'आपकी पहली प्रोफ़ाइल अपने आप बनेगी और यह फ़ोन आपका खाता याद रखेगा':
        'Your first profile is created automatically and this phone remembers your account',
    'परिवार का सदस्य जोड़ें': 'Add a family member',
    'शुरू करने के लिए अपना पहला सदस्य जोड़ें':
        'Add your first family member to get started',
    'रिकॉर्ड जोड़ें': 'Add record',
    'आज का स्वास्थ्य': 'Health today',
    'सभी देखें': 'View all',
    'दवाई जोड़ें': 'Add medicine',
    'रिकॉर्ड सफलतापूर्वक जोड़ा गया': 'Record added successfully',
    'सही BP दर्ज करें': 'Enter valid BP',
    'सही शुगर दर्ज करें': 'Enter valid sugar',
    'सही वजन दर्ज करें': 'Enter valid weight',
    'कम से कम एक समय चुनें': 'Select at least one time',
    'चुने हुए समय पर नाम लेकर आवाज़ में याद दिलाएँ':
        'Speak the person and medicine names at the selected times',
    'दवाइयों के लिए सूचनाएं प्राप्त करें': 'Receive medicine notifications',
    'बैकअप के लिए साइन इन करें': 'Sign in to back up',
    'गूगल ड्राइव से प्रोफ़ाइल बहाल करें': 'Restore a profile from Google Drive',
    'कोई सदस्य नहीं मिला': 'No member found',
    'डॉक्टर को दिखाएं': 'Show this to the doctor',
    'यह कोड scan करने दें': 'Let the doctor scan this code',
    'नया बनाएं': 'Create new',
    'नाम आवश्यक है': 'Name is required',
    '10 अंकों का नंबर आवश्यक है': 'A 10-digit number is required',
    'मौजूदा बीमारियाँ': 'Existing conditions',
    'कोई इतिहास नहीं': 'No history',
    'इस सीमा में कोई डेटा नहीं': 'No data in this range',
    'जैसे: मिठाई खाने के बाद...': 'For example: after eating sweets...',
    'जैसे: दवाई लेने के 2 घंटे बाद...':
        'For example: two hours after taking medicine...',
    'वैकल्पिक': 'Optional',
    'वर्ष': 'years',
    'मुख्य': 'Primary',
    'अधिक': 'more',
    'शेयर': 'Share',
    'सहेजें': 'Save',
    'हटाएं': 'Delete',
    'रद्द': 'Cancel',
    'वापस': 'Back',
    'लें': 'Take',
    'ली गई': 'Taken',
    'शाबाश! सभी ली गईं ': 'Well done! All doses taken ',
    'आज, 10:30 AM': 'Today, 10:30 AM',
    'अभी-अभी': 'Just now',
    'भाषा बदल दी गई': 'Language changed',
    'सभी डेटा मिटा दिया गया है': 'All data has been erased',
    'सदस्य, दवाई या रिपोर्ट खोजें...':
        'Search members, medicines, or reports...',
    'पिछला बैकअप:': 'Last backup:',
    'सभी देखें →': 'View all →',
    'ग्रामीण स्वास्थ्य': 'Gramin Swasthya',
    'लिंक': 'Link',
    'समाप्ति:': 'Expires:',
    'WhatsApp शुरू करने में असमर्थ': 'Unable to open WhatsApp',
    'QR कोड': 'QR code',
    'Google से साइन इन करें। आपकी पहली स्वास्थ्य प्रोफ़ाइल आपके नाम, ईमेल और लिंक किए गए मोबाइल नंबर से अपने आप बन जाएगी।':
        'Sign in with Google. Your first health profile will be created automatically using your name, email, and linked mobile number.',
    'ब्लड प्रेशर': 'Blood pressure',
    'किस समय की शुगर है?': 'When was the sugar measured?',
    'को हटाएं?': 'Delete?',
    'को हटा दिया गया': 'deleted',
    'क्या आप वाकई इस प्रोफाइल को हटाना चाहते हैं?':
        'Are you sure you want to delete this profile?',
    'फोटो या गैलरी से जोड़ें': 'Add from camera or gallery',
    'के लिए कोई परिणाम नहीं मिला': 'No results found for',
  };
}
