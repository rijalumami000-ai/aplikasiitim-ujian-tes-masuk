import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DataProvider extends ChangeNotifier with WidgetsBindingObserver {
  final ApiService apiService;

  List<dynamic> _groups = [];
  List<dynamic> _users = [];
  List<dynamic> _examinees = [];
  Map<String, dynamic>? _recap;

  bool _isLoading = false;
  String? _error;
  bool _isSuperUser = false;
  Timer? _syncTimer;

  // Menyimpan status sinkronisasi per-santri
  final Map<int, bool> _syncingExaminees = {};

  DataProvider(this.apiService) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('Aplikasi dilanjutkan (resumed): menyegarkan data otomatis...');
      if (_syncTimer != null) {
        pollAllData(_isSuperUser);
      }
    }
  }

  // Mulai timer sinkronisasi otomatis
  void startSyncTimer(bool isSuperUser) {
    _isSuperUser = isSuperUser;
    if (_syncTimer == null) {
      debugPrint('Memulai timer sinkronisasi otomatis (setiap 20 detik)...');
      pollAllData(isSuperUser); // Polling instan saat pertama kali aktif
      _syncTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
        pollAllData(isSuperUser);
      });
    }
  }

  // Hentikan timer sinkronisasi
  void stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // Polling data di background secara senyap (tanpa menampilkan full screen loading spinner)
  Future<void> pollAllData(bool isSuperUser) async {
    try {
      if (isSuperUser) {
        final grps = await apiService.getGroups();
        final usrs = await apiService.getUsers();
        final exms = await apiService.getExaminees();
        final rcp = await apiService.getRecap();
        _groups = grps;
        _users = usrs;
        _examinees = exms;
        _recap = rcp;
      } else {
        final grps = await apiService.getGroups();
        final exms = await apiService.getExaminees();
        _groups = grps;
        _examinees = exms;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Kesalahan sinkronisasi senyap: $e');
    }
  }

  List<dynamic> get groups => _groups;
  List<dynamic> get users => _users;
  List<dynamic> get examinees => _examinees;
  Map<String, dynamic>? get recap => _recap;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool isSyncing(int examineeId) => _syncingExaminees[examineeId] ?? false;

  // Clear caches on logout
  void clear() {
    stopSyncTimer();
    _groups = [];
    _users = [];
    _examinees = [];
    _recap = null;
    _syncingExaminees.clear();
    _error = null;
  }

  // --- GET DATA ---

  Future<void> fetchGroups() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _groups = await apiService.getGroups();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _users = await apiService.getUsers();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchExaminees() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _examinees = await apiService.getExaminees();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRecap() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _recap = await apiService.getRecap();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllAdminData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _groups = await apiService.getGroups();
      _users = await apiService.getUsers();
      _examinees = await apiService.getExaminees();
      _recap = await apiService.getRecap();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- CRUD GROUPS ---

  Future<bool> createGroup(String name, String description, String gender) async {
    try {
      final newGroup = await apiService.createGroup(name, description, gender);
      _groups.add(newGroup);
      _groups.sort((a, b) => (a['group_name'] as String).compareTo(b['group_name'] as String));
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateGroup(int id, String name, String description, String gender) async {
    try {
      final updated = await apiService.updateGroup(id, name, description, gender);
      final index = _groups.indexWhere((g) => g['id'] == id);
      if (index != -1) {
        _groups[index] = updated;
        _groups.sort((a, b) => (a['group_name'] as String).compareTo(b['group_name'] as String));
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteGroup(int id) async {
    try {
      await apiService.deleteGroup(id);
      _groups.removeWhere((g) => g['id'] == id);
      // Refresh examinees karena backend menghapus santri di kelompok ini
      // sehingga nama-nama tersebut bisa muncul kembali di daftar calon santri PSB
      await fetchExaminees();
      await fetchRecap();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // --- CRUD EXAMINEES ---

  Future<bool> createExaminee(String regNum, String name, String gender, String school, int groupId) async {
    try {
      await apiService.createExaminee(regNum, name, gender, school, groupId);
      await fetchExaminees();
      await fetchRecap();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateExaminee(int id, String name, String gender, String school, int? groupId) async {
    try {
      await apiService.updateExaminee(id, name, gender, school, groupId);
      await fetchExaminees();
      await fetchRecap();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteExaminee(int id) async {
    try {
      await apiService.deleteExaminee(id);
      _examinees.removeWhere((e) => e['id'] == id);
      await fetchRecap();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // --- MANAGE USERS & ASSIGNMENTS ---

  Future<bool> registerUser(String username, String password, String role, int? groupId) async {
    try {
      await apiService.registerUser(username, password, role, groupId);
      await fetchUsers();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUser(int id, String username, String? password, String role, int? groupId) async {
    try {
      await apiService.updateUser(id, username, password, role, groupId);
      await fetchUsers();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      await apiService.deleteUser(id);
      _users.removeWhere((u) => u['id'] == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> assignGroupsToUser(int userId, List<int> groupIds) async {
    try {
      await apiService.assignGroups(userId, groupIds);
      await fetchUsers();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // --- SUBMIT PLACEMENT (CEKLIS KELAS) ---

  Future<void> submitPlacement(int examineeId, String? grade, String examinerName) async {
    _syncingExaminees[examineeId] = true;
    notifyListeners();

    // Simpan data lama untuk fallback jika API gagal (Optimistic UI)
    final index = _examinees.indexWhere((e) => e['id'] == examineeId);
    dynamic originalData;
    if (index != -1) {
      originalData = Map<String, dynamic>.from(_examinees[index]);
      // Update lokal secara optimis
      _examinees[index]['placement'] = grade;
      _examinees[index]['examiner_name'] = grade != null ? examinerName : null;
      _examinees[index]['checked_at'] = grade != null ? DateTime.now().toIso8601String() : null;
    }

    try {
      await apiService.submitPlacement(examineeId, grade);
      // Sinkronisasi berhasil, perbarui rekapitulasi di background
      apiService.getRecap().then((newRecap) {
        _recap = newRecap;
        notifyListeners();
      }).catchError((_) {});
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      // Rollback data lokal jika gagal
      if (index != -1 && originalData != null) {
        _examinees[index] = originalData;
      }
    } finally {
      _syncingExaminees[examineeId] = false;
      notifyListeners();
    }
  }
}
