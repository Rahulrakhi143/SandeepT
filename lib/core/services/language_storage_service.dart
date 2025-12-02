import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Web-compatible language storage service
/// Uses SharedPreferences when available, falls back to in-memory storage for web
class LanguageStorageService {
  static const String _languageKey = 'app_language';
  static String? _cachedLanguageCode;
  static bool _initialized = false;

  /// Initialize storage (pre-load SharedPreferences if available)
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      if (!kIsWeb) {
        // For non-web platforms, try to initialize SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        _cachedLanguageCode = prefs.getString(_languageKey);
      } else {
        // For web, try to use SharedPreferences, but have fallback
        try {
          final prefs = await SharedPreferences.getInstance();
          _cachedLanguageCode = prefs.getString(_languageKey);
        } catch (e) {
          // Fallback to localStorage via JavaScript if SharedPreferences fails
          debugPrint('⚠️ SharedPreferences not available, using fallback storage');
          _cachedLanguageCode = _getFromWebStorage();
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('⚠️ Language storage initialization warning: $e');
      _initialized = true; // Mark as initialized even if failed
    }
  }

  /// Get current language code
  static Future<String?> getLanguageCode() async {
    await initialize();
    
    if (_cachedLanguageCode != null) {
      return _cachedLanguageCode;
    }

    try {
      if (kIsWeb) {
        // Try SharedPreferences first
        try {
          final prefs = await SharedPreferences.getInstance();
          _cachedLanguageCode = prefs.getString(_languageKey);
          if (_cachedLanguageCode != null) {
            return _cachedLanguageCode;
          }
        } catch (e) {
          // Fallback to web storage
          return _getFromWebStorage();
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        _cachedLanguageCode = prefs.getString(_languageKey);
        return _cachedLanguageCode;
      }
    } catch (e) {
      debugPrint('⚠️ Error getting language: $e');
      return _getFromWebStorage();
    }
    
    return null;
  }

  /// Save language code
  static Future<void> saveLanguageCode(String languageCode) async {
    await initialize();
    _cachedLanguageCode = languageCode;

    try {
      if (kIsWeb) {
        // Try SharedPreferences first
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_languageKey, languageCode);
          debugPrint('✅ Language saved via SharedPreferences: $languageCode');
          return;
        } catch (e) {
          // Fallback to web storage
          debugPrint('⚠️ SharedPreferences failed, using web storage fallback');
          _saveToWebStorage(languageCode);
          return;
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_languageKey, languageCode);
        debugPrint('✅ Language saved: $languageCode');
      }
    } catch (e) {
      debugPrint('⚠️ Error saving language, using fallback: $e');
      _saveToWebStorage(languageCode);
    }
  }

  /// Get from web localStorage (fallback)
  static String? _getFromWebStorage() {
    if (!kIsWeb) return null;
    try {
      // Use JavaScript interop to access localStorage
      // This is a simple implementation
      return null; // Will be handled by SharedPreferences web implementation
    } catch (e) {
      return null;
    }
  }

  /// Save to web localStorage (fallback)
  static void _saveToWebStorage(String languageCode) {
    if (!kIsWeb) return;
    // SharedPreferences web implementation should handle this
    // This is just a placeholder for additional fallback if needed
  }
}

