import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStrings {
  static const String _prefKey = 'user_selected_language';

  // ValueNotifier for reactive updates across the entire app
  static final ValueNotifier<bool> languageNotifier = ValueNotifier<bool>(true);

  static bool get isMarathi => languageNotifier.value;
  static set isMarathi(bool val) {
    if (languageNotifier.value != val) {
      languageNotifier.value = val;
      _savePreference(val);
    }
  }

  static String tr(String mr, String en) => isMarathi ? mr : en;

  /// Loads saved language preference on application startup
  static Future<void> loadLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString(_prefKey);
      if (savedLang != null) {
        languageNotifier.value = (savedLang == 'mr');
        debugPrint('Loaded language preference: ${savedLang == "mr" ? "Marathi" : "English"}');
      } else {
        languageNotifier.value = true; // Default is Marathi
      }
    } catch (e) {
      debugPrint('Language preference load error: $e');
    }
  }

  /// Sets and persists language preference
  static Future<void> setLanguage({required bool marathi}) async {
    languageNotifier.value = marathi;
    await _savePreference(marathi);
  }

  /// Toggles and persists language preference
  static Future<void> toggleLanguage() async {
    await setLanguage(marathi: !isMarathi);
  }

  static Future<void> _savePreference(bool marathi) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, marathi ? 'mr' : 'en');
      debugPrint('Saved language preference: ${marathi ? "Marathi" : "English"}');
    } catch (e) {
      debugPrint('Language preference save error: $e');
    }
  }

  // Header & App Identity
  static String get appName => tr('सखी बचत गट', 'Sakhi Bachat Gat');
  static String get appSubtitle => tr('महिला बचत गट व्यवस्थापन ॲप', 'Mahila Bachat Gat Management Application');
  static String get tagline => tr('महिला सक्षमीकरण • समृद्ध भविष्य', 'Empowering Women • Building Better Tomorrows');

  // Navigation
  static String get navHome => tr('मुख्यपृष्ठ', 'Home');
  static String get navMembers => tr('सदस्य', 'Members');
  static String get navSavings => tr('बचत', 'Savings');
  static String get navLoans => tr('कर्ज', 'Loans');
  static String get navMore => tr('अधिक', 'More');

  // Dashboard KPIs
  static String get totalMembers => tr('एकूण सदस्य', 'Total Members');
  static String get totalSavings => tr('एकूण बचत', 'Total Savings');
  static String get activeLoans => tr('सक्रिय कर्ज', 'Active Loans');
  static String get pendingEmi => tr('प्रलंबित हप्ते', 'Pending EMI');
  static String get bankBalance => tr('बँक शिल्लक', 'Bank Balance');
  static String get cashInHand => tr('हातातील रोख', 'Cash in Hand');
  static String get totalIncome => tr('एकूण उत्पन्न', 'Total Income');
  static String get totalExpenses => tr('एकूण खर्च', 'Total Expenses');
  static String get totalProfit => tr('एकूण नफा', 'Total Profit');
  static String get upcomingMeeting => tr('पुढील बैठक', 'Upcoming Meeting');

  // Buttons & Actions
  static String get save => tr('जतन करा', 'Save');
  static String get cancel => tr('रद्द करा', 'Cancel');
  static String get apply => tr('अर्ज करा', 'Apply');
  static String get makePayment => tr('हप्ता भरा', 'Make Payment');
  static String get viewLedger => tr('खातेवही पहा', 'View Ledger');
  static String get exportPdf => tr('PDF डाऊनलोड करा', 'Export PDF');
  static String get searchMembers => tr('सदस्य शोधा...', 'Search members...');
  static String get addNewUser => tr('नवीन युझर जोडा', 'Add New User');
  static String get switchUser => tr('खाते बदला', 'Switch Account');

  // Multi-Tenant Group Management
  static String get selectGroup => tr('बचत गट निवडा', 'Select Bachat Gat');
  static String get switchGroup => tr('बचत गट बदला', 'Switch Bachat Gat');
  static String get registerGroup => tr('नवीन बचत गट नोंदणी', 'Register New Bachat Gat');
  static String get groupName => tr('बचत गटाचे नाव', 'Bachat Gat Name');
  static String get registrationNo => tr('नोंदणी क्रमांक', 'Registration Number');
  static String get village => tr('गाव', 'Village');
  static String get taluka => tr('तालुका', 'Taluka');
  static String get district => tr('जिल्हा', 'District');
  static String get monthlySavings => tr('मासिक बचत रक्कम', 'Monthly Savings Amount');
  static String get presidentName => tr('अध्यक्षांचे नाव', 'President Name');
  static String get secretaryName => tr('सचिवांचे नाव', 'Secretary Name');
  static String get treasurerName => tr('खजिनदारांचे नाव', 'Treasurer Name');
  static String get noMembersYet => tr('या बचत गटामध्ये अद्याप कोणतीही सदस्या नाही', 'No members in this Bachat Gat yet');
  static String get addFirstMember => tr('+ पहिली सदस्या जोडा', '+ Add First Member');
  static String get switchedGroupMsg => tr('सक्रिय बचत गट बदलला:', 'Switched active Bachat Gat:');
}

