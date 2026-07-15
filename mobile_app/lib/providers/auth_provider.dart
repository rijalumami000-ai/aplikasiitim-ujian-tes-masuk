import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService apiService;

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _user;
  ThemeMode _themeMode = ThemeMode.dark; // Default tema gelap premium

  AuthProvider(this.apiService) {
    loadThemePreference();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isSuperUser => _user != null && _user!['role'] == 'SUPER_USER';
  ThemeMode get themeMode => _themeMode;

  // Memuat preferensi tema dari SharedPreferences
  Future<void> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLight = prefs.getBool('theme_is_light') ?? false;
      _themeMode = isLight ? ThemeMode.light : ThemeMode.dark;
      notifyListeners();
    } catch (e) {
      debugPrint('Gagal memuat preferensi tema: $e');
    }
  }

  // Mengubah/men-toggle tema aktif
  Future<void> toggleTheme() async {
    try {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('theme_is_light', _themeMode == ThemeMode.light);
    } catch (e) {
      debugPrint('Gagal menyimpan preferensi tema: $e');
    }
  }

  // Periksa apakah penguji memiliki izin ke kelompok tertentu
  bool hasGroupPermission(int groupId) {
    if (isSuperUser) return true;
    if (_user == null || _user!['assignedGroups'] == null) return false;
    final List<dynamic> groups = _user!['assignedGroups'];
    return groups.contains(groupId);
  }

  // Auto Login saat aplikasi dibuka
  Future<void> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();
    try {
      await apiService.init();
      if (apiService.token == null) {
        _user = null;
        _isLoading = false;
        notifyListeners();
        return;
      }
      final profile = await apiService.getProfile();
      _user = profile;
      _error = null;
    } catch (e) {
      // Token tidak valid atau server tidak aktif, abaikan dan minta login kembali
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Proses Login
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await apiService.login(username, password);
      _user = data['user'];
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Log Out
  Future<void> logout() async {
    _user = null;
    _error = null;
    await apiService.setToken(null);
    notifyListeners();
  }
}
