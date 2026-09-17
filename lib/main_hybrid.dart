import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/supabase_config.dart';
import 'services/app_config.dart';
import 'services/offline_db_helper.dart';
import 'services/sync_service.dart';
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
  AppConfig.isHybridMode = true;

  await AppStrings.loadLanguagePreference();

  // Initialize SQLite FFI bindings immediately
  OfflineDbHelper.initializeFfi();

  // 1. Initialize Supabase for cloud synchronization
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (e) {
    debugPrint('Supabase init note: $e');
  }

  // 2. Initialize local SQLite database
  try {
    await OfflineDbHelper.instance.database;
    // 3. Start background sync manager
    SyncService.instance.start();
  } catch (e) {
    debugPrint('Hybrid DB / Sync init note: $e');
  }

  runApp(const SakhiBachatGatHybridApp());
}

class SakhiBachatGatHybridApp extends StatelessWidget {
  const SakhiBachatGatHybridApp({super.key});

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
        title: 'Sakhi Bachat Gat (Hybrid Auto-Sync)',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const HybridAuthGate(),
        builder: (context, child) => GlobalOfflineWrapper(child: child!),
      ),
    );
  }
}

class HybridAuthGate extends StatelessWidget {
  const HybridAuthGate({super.key});

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
                'सखी बचत गट (हायब्रिड) सुरू होत आहे...',
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
