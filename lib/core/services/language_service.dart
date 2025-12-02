import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trivora_provider/core/services/language_storage_service.dart';

/// Supported languages
enum AppLanguage {
  english('en', 'English'),
  hindi('hi', 'Hindi');

  final String code;
  final String name;

  const AppLanguage(this.code, this.name);
}

/// Language Service to manage app language
class LanguageService {
  static const AppLanguage _defaultLanguage = AppLanguage.english;

  /// Get current language from storage
  Future<AppLanguage> getCurrentLanguage() async {
    try {
      // Initialize storage service
      await LanguageStorageService.initialize();
      
      // Get language code from storage
      final languageCode = await LanguageStorageService.getLanguageCode();
      
      if (languageCode == null) {
        return _defaultLanguage;
      }

      return AppLanguage.values.firstWhere(
        (lang) => lang.code == languageCode,
        orElse: () => _defaultLanguage,
      );
    } catch (e) {
      debugPrint('⚠️ Error getting language: $e');
      return _defaultLanguage;
    }
  }

  /// Set language and save to storage
  Future<void> setLanguage(AppLanguage language) async {
    try {
      // Initialize storage service
      await LanguageStorageService.initialize();
      
      // Save language code
      await LanguageStorageService.saveLanguageCode(language.code);
      debugPrint('✅ Language saved: ${language.code}');
    } catch (e) {
      debugPrint('❌ Error saving language: $e');
      // Try to save anyway using the storage service (which has fallback)
      try {
        await LanguageStorageService.saveLanguageCode(language.code);
      } catch (e2) {
        throw Exception('Failed to save language preference. The language will be applied for this session only.');
      }
    }
  }

  /// Get Locale from AppLanguage
  Locale getLocale(AppLanguage language) {
    return Locale(language.code);
  }

  /// Get all available languages
  List<AppLanguage> getAvailableLanguages() {
    return AppLanguage.values;
  }
}

/// Provider for LanguageService
final languageServiceProvider = Provider<LanguageService>((ref) {
  return LanguageService();
});

/// Provider for current language
final currentLanguageProvider = StateNotifierProvider<LanguageNotifier, AppLanguage>((ref) {
  return LanguageNotifier(ref.read(languageServiceProvider));
});

/// Notifier for language state
class LanguageNotifier extends StateNotifier<AppLanguage> {
  final LanguageService _languageService;

  LanguageNotifier(this._languageService) : super(AppLanguage.english) {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final language = await _languageService.getCurrentLanguage();
      state = language;
    } catch (e) {
      debugPrint('Error loading language: $e');
      state = AppLanguage.english;
    }
  }

  Future<void> changeLanguage(AppLanguage language) async {
    try {
      await _languageService.setLanguage(language);
      state = language;
      debugPrint('✅ Language changed to: ${language.name} (${language.code})');
    } catch (e) {
      debugPrint('❌ Error changing language: $e');
      throw Exception('Failed to change language: $e');
    }
  }
}

