import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'services/app_config.dart';
import 'services/offline_db_helper.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/member_provider.dart';
import 'providers/savings_provider.dart';
import 'providers/loan_provider.dart';
import 'providers/monthly_savings_provider.dart';
import 'providers/bank_provider.dart';
import 'providers/bonus_provider.dart';
import 'providers/monthly_collection_provider.dart';
import 'core/constants/app_colors.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/sub_login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'core/localization/app_strings.dart';
import 'widgets/offline_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.isOfflineMode = true;
  AppConfig.isHybridMode = false;

  await AppStrings.loadLanguagePreference();

  // Initialize SQLite FFI bindings immediately
  OfflineDbHelper.initializeFfi();

  // Launch UI immediately so the OS window appears without delay
  runApp(const SakhiBachatGatOfflineApp());

  // Warmup database in background
  _preloadOfflineDb();
}

void _preloadOfflineDb() async {
  try {
    await OfflineDbHelper.instance.database;
  } catch (e) {
    debugPrint('Database initialization warning: $e');
  }
}

class SakhiBachatGatOfflineApp extends StatelessWidget {
  const SakhiBachatGatOfflineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => MemberProvider()),
        ChangeNotifierProvider(create: (_) => SavingsProvider()),
        ChangeNotifierProvider(create: (_) => LoanProvider()),
        ChangeNotifierProvider(create: (_) => MonthlySavingsProvider()),
        ChangeNotifierProvider(create: (_) => BankProvider()),
        ChangeNotifierProvider(create: (_) => BonusProvider()),
        ChangeNotifierProvider(create: (_) => MonthlyCollectionProvider()),
      ],
      child: MaterialApp(
        title: 'Sakhi Bachat Gat (Offline Edition)',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const OfflineAuthGate(),
        builder: (context, child) => GlobalOfflineWrapper(child: child!),
      ),
    );
  }
}

class OfflineAuthGate extends StatelessWidget {
  const OfflineAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (auth.isInitializing) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'सखी बचत गट (ऑफलाइन) सुरू होत आहे...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Stage 1: If application not yet initialized / no previous login, show Main Login
    if (!auth.isApplicationInitialized) {
      return const LoginScreen();
    }

    // Member Flow: Direct access to application in View-Only mode without Sub-Login lock
    if (auth.isMember) {
      return const MainNavigationScreen();
    }

    // Stage 2: Sub Login required on every application launch for Admin
    if (!auth.isSubLoginUnlocked) {
      return const SubLoginScreen();
    }

    return const MainNavigationScreen();
  }
}
