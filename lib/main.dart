import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:trivora_provider/core/router/app_router.dart';
import 'package:trivora_provider/core/services/notification_service.dart';
import 'package:trivora_provider/core/providers/auth_provider.dart';
import 'package:trivora_provider/core/services/language_service.dart';
import 'package:trivora_provider/core/services/language_storage_service.dart';
import 'package:trivora_provider/firebase_options.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Main entry point for Trivora Provider App
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize language storage service early
  try {
    await LanguageStorageService.initialize();
    debugPrint('✅ Language storage initialized');
  } catch (e) {
    debugPrint('⚠️ Language storage initialization warning: $e');
  }
  
  // Set preferred orientations for mobile
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('⚠️ Firebase initialization failed: $e');
    debugPrint('Stack trace: $stackTrace');
  }
  
  runApp(
    const ProviderScope(
      child: TrivoraProviderApp(),
    ),
  );
}

class TrivoraProviderApp extends ConsumerWidget {
  const TrivoraProviderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final currentLanguage = ref.watch(currentLanguageProvider);
    final languageService = ref.read(languageServiceProvider);
    
    // Initialize notifications when user is logged in
    if (authUser != null && !kIsWeb) {
      final notificationService = ref.read(notificationServiceProvider);
      notificationService.initialize(authUser.uid);
    }

    // Get locale from current language
    final locale = languageService.getLocale(currentLanguage);
    debugPrint('🌐 Current locale: ${locale.languageCode}');

    return MaterialApp.router(
      key: ValueKey(locale.languageCode), // Force rebuild on language change
      title: 'Trivora Provider',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        brightness: Brightness.light, // Force light theme only
        fontFamily: 'Roboto', // Default Material font
        fontFamilyFallback: const [
          'Noto Sans Devanagari', // Hindi support
          'Noto Sans', // General support
          'Arial Unicode MS', // Fallback
          'sans-serif', // System fallback
        ],
      ),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('hi', ''), // Hindi
      ],
      routerConfig: router,
    );
  }
}

