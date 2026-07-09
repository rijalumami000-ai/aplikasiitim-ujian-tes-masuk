import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _defaultUrl = 'https://alhamidcintamulya.my.id/ujian-api';
  static const String _tokenKey = 'auth_token';
  static const String _urlKey = 'backend_base_url';

  String _baseUrl = _defaultUrl;
  String? _token;

  String? get token => _token;

  // Inisialisasi API Service (Selalu gunakan IP VPS)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = _defaultUrl;
    _token = prefs.getString(_tokenKey);
  }

  // Mendapatkan Base URL saat ini
  String get baseUrl => _baseUrl;

  // Mengubah Base URL
  Future<void> setBaseUrl(String url) async {
    // Hilangkan slash di akhir jika ada
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, url);
  }

  // Menyimpan token otentikasi
  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  // Mendapatkan header HTTP (ditambahkan token JWT)
  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // Menangani respons HTTP
  dynamic _handleResponse(http.Response response) {
    final int statusCode = response.statusCode;
    final body = jsonDecode(response.body);

    if (statusCode >= 200 && statusCode < 300) {
      return body;
    } else {
      final String message = body['message'] ?? 'Terjadi kesalahan sistem';
      throw Exception(message);
    }
  }

  // --- API CALLS ---

  // Auth: Login
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: _getHeaders(),
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 10));
      final data = _handleResponse(response);
      await setToken(data['token']);
      return data;
    } catch (e) {
      rethrow;
    }
  }

  // Auth: Mendapatkan Data Profil
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/auth/me'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 7));
      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // Super User: Register User Baru
  Future<Map<String, dynamic>> registerUser(String username, String password, String role, int? groupId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/register'),
        headers: _getHeaders(),
        body: jsonEncode({
          'username': username,
          'password': password,
          'role': role,
          'group_id': groupId
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // Super User: Dapatkan Semua Pengguna
  Future<List<dynamic>> getUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/users'),
        headers: _getHeaders(),
      );
      return _handleResponse(response) as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // Super User: Update Pengguna
  Future<Map<String, dynamic>> updateUser(int id, String username, String? password, String role, int? groupId) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/users/$id'),
        headers: _getHeaders(),
        body: jsonEncode({
          'username': username,
          'password': password,
          'role': role,
          'group_id': groupId
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // Super User: Hapus Pengguna
  Future<void> deleteUser(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/users/$id'),
        headers: _getHeaders(),
      );
      _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // Super User: Tugaskan Penguji ke Kelompok
  Future<void> assignGroups(int userId, List<int> groupIds) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/users/assign-groups'),
        headers: _getHeaders(),
        body: jsonEncode({'user_id': userId, 'group_ids': groupIds}),
      );
      _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // --- GROUPS API ---

  // Ambil Semua Kelompok
  Future<List<dynamic>> getGroups() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/groups'),
        headers: _getHeaders(),
      );
      return _handleResponse(response) as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // Super User: Tambah Kelompok
  Future<Map<String, dynamic>> createGroup(String groupName, String description) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/groups'),
        headers: _getHeaders(),
        body: jsonEncode({'group_name': groupName, 'description': description}),
      );
      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // Super User: Edit Kelompok
  Future<Map<String, dynamic>> updateGroup(int id, String groupName, String description) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/groups/$id'),
        headers: _getHeaders(),
        body: jsonEncode({'group_name': groupName, 'description': description}),
      );
      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // Super User: Hapus Kelompok
  Future<void> deleteGroup(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/groups/$id'),
        headers: _getHeaders(),
      );
      _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // --- EXAMINEES API ---

  // Ambil Daftar Calon Santri
  Future<List<dynamic>> getExaminees() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/examinees'),
        headers: _getHeaders(),
      );
      return _handleResponse(response) as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // Super User: Tambah Calon Santri
  Future<Map<String, dynamic>> createExaminee(String name, String gender, String school, int? groupId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/examinees'),
        headers: _getHeaders(),
        body: jsonEncode({
          'name': name,
          'gender': gender,
          'school': school,
          'group_id': groupId,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // Super User: Edit Calon Santri
  Future<Map<String, dynamic>> updateExaminee(int id, String name, String gender, String school, int? groupId) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/examinees/$id'),
        headers: _getHeaders(),
        body: jsonEncode({
          'name': name,
          'gender': gender,
          'school': school,
          'group_id': groupId,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // Super User: Hapus Calon Santri
  Future<void> deleteExaminee(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/examinees/$id'),
        headers: _getHeaders(),
      );
      _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // --- EXAMS PLACEMENT API ---

  // Ceklis Penempatan Kelas (Sifir, Satu, SP, atau null)
  Future<Map<String, dynamic>> submitPlacement(int examineeId, String? grade) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/exams/placement'),
        headers: _getHeaders(),
        body: jsonEncode({
          'examinee_id': examineeId,
          'grade': grade,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // --- RECAP API ---

  // Dapatkan Data Rekapitulasi Penempatan Kelas
  Future<Map<String, dynamic>> getRecap() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/exams/recap'),
        headers: _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }
}
