import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'providers/lawsuit_provider.dart';
import 'providers/lawyer_provider.dart';
import 'providers/ai_chat_provider.dart';
import 'providers/inheritance_provider.dart';
import 'providers/court_provider.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'providers/settings_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/session_provider.dart';
import 'screens/register_screen.dart';
import 'screens/legal_library_screen.dart';
import 'screens/smart_assistant_screen.dart';
import 'screens/training_screen.dart';
import 'screens/inquiries_screen.dart';
import 'screens/contact_us_screen.dart';
import 'screens/about_us_screen.dart';
import 'screens/blog_screen.dart';
import 'screens/laws_screen.dart';
import 'screens/services_screen.dart';
import 'screens/complaint_screen.dart';
import 'screens/daily_sessions_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/electronic_lawsuit_screen.dart';
import 'screens/faq_screen.dart';
import 'screens/subscribe_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/payment_order_screen.dart';
import 'screens/appeal_screen.dart';
import 'screens/legal_database_screen.dart';
import 'screens/ai_case_analysis_screen.dart';
import 'screens/case_management_screen.dart';
import 'screens/case_accounting_screen.dart';
import 'screens/legal_forms_screen.dart';
import 'screens/remote_consultations_screen.dart';
import 'screens/procedures_guide_screen.dart';
import 'screens/inheritance_calculation_screen.dart';
import 'screens/area_calculation_screen.dart';
import 'screens/notary_accounting_screen.dart';
import 'screens/contracts_agencies_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/electronic_services_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/case_detail_screen.dart';
import 'screens/messages_list_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/create_sub_account_screen.dart';
import 'screens/archive_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/courts_search_screen.dart';
import 'screens/lawyers_search_screen.dart';
import 'screens/session_detail_screen.dart';
import 'models/hearing_model.dart';
import 'web_url_strategy.dart';
import 'theme/app_theme.dart';
import 'config/api_config.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // إعداد URL strategy لـ Flutter Web
    configureWebUrlStrategy();

    await ApiConfig.initialize();
    await initializeDateFormatting('ar', null);
    
    final prefs = await SharedPreferences.getInstance();
    final bool showOnboarding = prefs.getBool('onboarding_completed') != true;

    runApp(MyApp(showOnboarding: showOnboarding));
  }, (error, stack) {
    if (kDebugMode) debugPrint('❌ [Zone Error] $error');
  });
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  const MyApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => apiService),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService: apiService)..initialize()),
        ChangeNotifierProvider(create: (_) => LawsuitProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..initialize()),
        ChangeNotifierProxyProvider<AuthProvider, AIChatProvider>(
          create: (_) => AIChatProvider(),
          update: (_, auth, prev) {
            prev!.setAccessToken(auth.apiService.accessToken);
            return prev;
          },
        ),
        ChangeNotifierProvider(create: (_) => LawyerProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => InheritanceProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => SessionProvider(apiService)),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(apiService),
          update: (_, auth, prev) => NotificationProvider(apiService),
        ),
        ChangeNotifierProvider(create: (_) => CourtProvider(apiService: apiService)),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'SmartJudi',
            debugShowCheckedModeBanner: false,
            initialRoute: '/',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
            locale: const Locale('ar'),
            supportedLocales: const [
              Locale('ar'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routes: {
              '/': (context) => AuthWrapper(showOnboarding: showOnboarding),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/library': (context) => const LegalLibraryScreen(),
              '/legal-library': (context) => const LegalLibraryScreen(),
              '/chat': (context) => const SmartAssistantScreen(),
              '/training': (context) => const TrainingScreen(),
              '/courts': (context) =>  CourtsSearchScreen(),
              '/lawyers': (context) =>  LawyersSearchScreen(),
              '/inquiries': (context) => const InquiriesScreen(),
              '/contact': (context) => const ContactUsScreen(),
              '/about': (context) => const AboutUsScreen(),
              '/blog': (context) => const BlogScreen(),
              '/laws': (context) => const LawsScreen(),
              '/services': (context) => const ServicesScreen(),
              '/complaints': (context) => const ComplaintScreen(),
              '/sessions': (context) => const DailySessionsScreen(),
              '/calendar': (context) => const CalendarScreen(),
              '/electronic-lawsuit': (context) => const ElectronicLawsuitScreen(),
              '/faq': (context) => const FAQScreen(),
              '/subscribe': (context) => const SubscribeScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/payment': (context) => const PaymentOrderScreen(),
              '/appeal': (context) => const AppealScreen(),
              '/database': (context) => const LegalDatabaseScreen(),
              '/case-analysis': (context) => const AICaseAnalysisScreen(),
              '/case-management': (context) => const CaseManagementScreen(),
              '/accounting': (context) => const CaseAccountingScreen(),
              '/forms': (context) => const LegalFormsScreen(),
              '/consultations': (context) => const RemoteConsultationsScreen(),
              '/procedures': (context) => const ProceduresGuideScreen(),
              '/inheritance': (context) => const InheritanceCalculationScreen(),
              '/area': (context) => const AreaCalculationScreen(),
              '/notary-accounting': (context) => const NotaryAccountingScreen(),
              '/agencies': (context) => const ContractsAgenciesScreen(),
              '/notifications': (context) => const NotificationsScreen(),
              '/electronic-services': (context) => const ElectronicServicesScreen(),
              '/edit-profile': (context) => const EditProfileScreen(),
              '/change-password': (context) => const ChangePasswordScreen(),
              '/lawsuits': (context) => ArchiveScreen(),
              '/messages': (context) => MessagesListScreen(),
              '/create-sub-account': (context) => CreateSubAccountScreen(),
              '/profile': (context) => EditProfileScreen(),
              '/case-detail': (context) {
                final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
                return CaseDetailScreen(caseId: args['id'] as int);
              },
              '/messages': (context) => const MessagesListScreen(),
              '/create-sub-account': (context) => const CreateSubAccountScreen(),
              '/verify-otp': (context) {
                final phone = ModalRoute.of(context)!.settings.arguments as String? ?? '';
                return OtpVerificationScreen(phoneNumber: phone, purpose: 'verify_email');
              },
              '/session-detail': (context) {
                final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
                if (args['hearing'] is HearingModel) {
                  return SessionDetailScreen(session: args['hearing'] as HearingModel);
                }
                // Fallback for ID-only navigation (like from DailySessionsScreen)
                // The screen will need a full HearingModel to start, but it will reload data anyway.
                return SessionDetailScreen(
                  session: HearingModel(
                    id: args['id'] as int,
                    lawsuitId: 0,
                    hearingDate: DateTime.now(),
                    hearingType: 'unknown',
                    sessionType: 'unknown',
                    requirements: '',
                    notes: '',
                  ),
                );
              },
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final bool showOnboarding;
  const AuthWrapper({super.key, required this.showOnboarding});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late bool _showingOnboarding;
  bool _unauthorizedHandlerAttached = false;

  @override
  void initState() {
    super.initState();
    _showingOnboarding = widget.showOnboarding;
  }

  void _onOnboardingComplete() {
    setState(() {
      _showingOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showingOnboarding) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }

    final authProvider = Provider.of<AuthProvider>(context);

    if (!_unauthorizedHandlerAttached) {
      _unauthorizedHandlerAttached = true;
      authProvider.apiService.setUnauthorizedHandler(() {
        if (!mounted) return;
        final currentRoute = ModalRoute.of(context)?.settings.name;
        if (currentRoute == '/login') return;
        Navigator.of(context).pushNamed(
          '/login',
          arguments: {
            if (currentRoute != null) 'redirect': currentRoute,
          },
        );
      });
    }

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!authProvider.isAuthenticated) {
      authProvider.setGuestMode(true);
    }

    // In guest mode we still allow app entry. Specific screens/APIs will prompt login on 401.
    return const HomeScreen();
  }
}
