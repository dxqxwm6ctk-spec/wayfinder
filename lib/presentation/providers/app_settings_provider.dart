import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, arabic }

class AppSettingsProvider extends ChangeNotifier {
  AppSettingsProvider() {
    _loadPreferences();
  }

  static const String _themeKey = 'app.theme_mode';
  static const String _languageKey = 'app.language';

  SharedPreferences? _preferences;
  ThemeMode _themeMode = ThemeMode.dark;
  AppLanguage _language = AppLanguage.english;

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;
  Locale get locale => _language == AppLanguage.arabic
      ? const Locale('ar')
      : const Locale('en');
  bool get isArabic => _language == AppLanguage.arabic;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _saveTheme();
    notifyListeners();
  }

  void setLanguage(AppLanguage language) {
    if (_language == language) {
      return;
    }
    _language = language;
    _saveLanguage();
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    _preferences = await SharedPreferences.getInstance();

    final String? savedTheme = _preferences?.getString(_themeKey);
    final String? savedLanguage = _preferences?.getString(_languageKey);

    if (savedTheme == ThemeMode.light.name) {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }

    if (savedLanguage == AppLanguage.arabic.name) {
      _language = AppLanguage.arabic;
    } else {
      _language = AppLanguage.english;
    }

    notifyListeners();
  }

  Future<void> _saveTheme() async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences?.setString(_themeKey, _themeMode.name);
  }

  Future<void> _saveLanguage() async {
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences?.setString(_languageKey, _language.name);
  }
}
