import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/pdf_generator.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../theme/premium_theme.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  int? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataProvider>(context, listen: false).fetchAllAdminData();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _refreshData() {
    Provider.of<DataProvider>(context, listen: false).fetchAllAdminData();
  }

  Future<void> _downloadGroupPdf(DataProvider dataProvider, int groupId) async {
    try {
      final group = dataProvider.groups.firstWhere((g) => g['id'] == groupId);
      final groupName = group['group_name'] ?? 'Kelompok';
      final groupGender = group['group_gender'] ?? 'PUTRA';
      final examinees = dataProvider.examinees
          .where((e) => e['group_id'] == groupId)
          .toList();

      await PdfGenerator.generateAndPreviewGroupPdf(
        groupName: groupName,
        groupGender: groupGender,
        examinees: examinees,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan saat membuat PDF: $e')),
        );
      }
    }
  }

  Future<void> _downloadExaminersPdf(DataProvider dataProvider) async {
    try {
      await PdfGenerator.generateAndPreviewExaminersPdf(
        users: dataProvider.users,
        groups: dataProvider.groups,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan saat membuat PDF: $e')),
        );
      }
    }
  }


  Widget _buildSelectedTab(DataProvider dataProvider, int index) {
    switch (index) {
      case 0:
        return _buildGroupsTab(dataProvider);
      case 1:
        return _buildUsersTab(dataProvider);
      case 2:
        return _buildExamineesTab(dataProvider);
      default:
        return _buildGroupsTab(dataProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final dataProvider = Provider.of<DataProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Panel Kontrol Super User',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: PremiumColors.textMain(context)),
            ),
            const Text(
              'Kelola Kelompok, Penguji & Calon Santri',
              style: TextStyle(fontSize: 12, color: PremiumColors.primaryLight),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              authProvider.themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: PremiumColors.primaryLight,
            ),
            tooltip: 'Ganti Tema',
            onPressed: () => authProvider.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart, color: PremiumColors.primaryLight, size: 28),
            tooltip: 'Rekap Global',
            onPressed: () => Navigator.pushNamed(context, '/recap'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Colors.redAccent),
            tooltip: 'Keluar',
            onPressed: () async {
              await authProvider.logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: PremiumBackground(
        child: dataProvider.isLoading
            ? const Center(child: CircularProgressIndicator(color: PremiumColors.primaryLight))
            : RefreshIndicator(
                onRefresh: () async {
                  await dataProvider.fetchAllAdminData();
                },
                color: PremiumColors.primaryLight,
                backgroundColor: PremiumColors.bgDarkSecondary,
                child: _buildSelectedTab(dataProvider, _selectedIndex),
              ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: PremiumColors.cardBorder.withOpacity(0.5), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          backgroundColor: PremiumColors.bgDarkSecondary,
          selectedItemColor: PremiumColors.accent,
          unselectedItemColor: PremiumColors.textMuted(context),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.group_work_outlined),
              activeIcon: Icon(Icons.group_work, color: PremiumColors.accent),
              label: 'Kelompok',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.supervisor_account_outlined),
              activeIcon: Icon(Icons.supervisor_account, color: PremiumColors.accent),
              label: 'Penguji',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people, color: PremiumColors.accent),
              label: 'Santri',
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: KELOMPOK (GROUPS) ---
  Widget _buildGroupsTab(DataProvider dataProvider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: PremiumButton(
            label: 'Tambah Kelompok Baru',
            icon: Icons.add,
            onPressed: () => _showGroupForm(context, dataProvider, null),
          ),
        ),
        Expanded(
          child: dataProvider.groups.isEmpty
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: 300,
                    child: Center(
                      child: Text('Belum ada kelompok.', style: TextStyle(color: PremiumColors.textMuted(context))),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: dataProvider.groups.length,
                  itemBuilder: (context, index) {
                    final group = dataProvider.groups[index];
                    return GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      group['group_name'],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: (group['group_gender'] ?? 'PUTRA') == 'PUTRA' ? Colors.blue.withOpacity(0.15) : Colors.pink.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        group['group_gender'] ?? 'PUTRA',
                                        style: TextStyle(
                                          fontSize: 9, 
                                          fontWeight: FontWeight.bold, 
                                          color: (group['group_gender'] ?? 'PUTRA') == 'PUTRA' ? Colors.blueAccent : Colors.pinkAccent
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  group['description'] ?? 'Tanpa deskripsi',
                                  style: TextStyle(color: PremiumColors.textMuted(context), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                                onPressed: () => _showGroupForm(context, dataProvider, group),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () => _confirmDeleteGroup(context, dataProvider, group['id'], group['group_name']),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- TAB 2: PENGUJI (USERS) ---
  Widget _buildUsersTab(DataProvider dataProvider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: PremiumButton(
                  label: 'Buat Akun Penguji Baru',
                  icon: Icons.person_add_alt,
                  onPressed: () => _showUserForm(context, dataProvider, null),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: PremiumButton(
                  label: 'Cetak Info Login',
                  icon: Icons.picture_as_pdf,
                  color: Colors.redAccent.withOpacity(0.85),
                  onPressed: () => _downloadExaminersPdf(dataProvider),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: dataProvider.users.isEmpty
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: 300,
                    child: Center(
                      child: Text('Belum ada pengguna.', style: TextStyle(color: PremiumColors.textMuted(context))),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: dataProvider.users.length,
                  itemBuilder: (context, index) {
                    final user = dataProvider.users[index];
                    final String username = user['username'];
                    final String role = user['role'];
                    final List<dynamic> assigned = user['assigned_groups'] ?? [];

                    return GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      borderColor: role == 'SUPER_USER' 
                          ? Colors.purple.withOpacity(0.3) 
                          : PremiumColors.cardBorder,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      username,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: role == 'SUPER_USER' ? Colors.purple.withOpacity(0.2) : Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        role,
                                        style: TextStyle(
                                          fontSize: 9, 
                                          fontWeight: FontWeight.bold, 
                                          color: role == 'SUPER_USER' ? Colors.purpleAccent : PremiumColors.accent
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (role == 'SUPER_USER')
                                  Text('Semua Kelompok (Super User)', style: TextStyle(color: PremiumColors.textMutedLight(context), fontSize: 12))
                                else
                                  Text(
                                    assigned.isEmpty
                                        ? 'Kelompok: Belum ditentukan'
                                        : 'Kelompok: ${assigned.map((g) => g['name']).join(', ')}',
                                    style: TextStyle(color: PremiumColors.textMuted(context), fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                                onPressed: () => _showUserForm(context, dataProvider, user),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () => _confirmDeleteUser(context, dataProvider, user['id'], username),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- TAB 3: SANTRI (EXAMINEES) ---
  Widget _buildExamineesTab(DataProvider dataProvider) {
    if (dataProvider.groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Harap tambahkan kelompok terlebih dahulu di tab Kelompok.',
            style: TextStyle(color: PremiumColors.textMuted(context), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_selectedGroupId == null && dataProvider.groups.isNotEmpty) {
      _selectedGroupId = dataProvider.groups[0]['id'];
    }

    // Cek apakah group yang terpilih masih ada (kalau-kalau didelete)
    final groupExists = dataProvider.groups.any((g) => g['id'] == _selectedGroupId);
    if (!groupExists && dataProvider.groups.isNotEmpty) {
      _selectedGroupId = dataProvider.groups[0]['id'];
    }

    final selectedGroup = dataProvider.groups.firstWhere((g) => g['id'] == _selectedGroupId);
    final String selectedGroupName = selectedGroup['group_name'];
    final String selectedGroupGender = selectedGroup['group_gender'] ?? 'PUTRA';

    final groupStudents = dataProvider.examinees.where((e) => e['group_id'] == _selectedGroupId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal Scroll untuk Pilihan Kelompok
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: dataProvider.groups.length,
            itemBuilder: (context, index) {
              final group = dataProvider.groups[index];
              final int groupId = group['id'];
              final String name = group['group_name'];
              final String gender = group['group_gender'] ?? 'PUTRA';
              final isSelected = _selectedGroupId == groupId;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        gender == 'PUTRA' ? Icons.male : Icons.female,
                        size: 14,
                        color: isSelected ? Colors.black : (gender == 'PUTRA' ? Colors.blueAccent : Colors.pinkAccent),
                      ),
                      const SizedBox(width: 4),
                      Text(name),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: PremiumColors.accent,
                  backgroundColor: PremiumColors.bgDarkSecondary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : PremiumColors.textMain(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedGroupId = groupId;
                      });
                    }
                  },
                ),
              );
            },
          ),
        ),

        const Divider(color: PremiumColors.cardBorder, height: 1),

        // Daftar Calon Santri Kelompok Terpilih
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Kelompok & Tombol Tambah
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_shared_outlined, color: PremiumColors.primaryLight, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        selectedGroupName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: PremiumColors.textMain(context)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: PremiumColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${groupStudents.length} Santri',
                          style: const TextStyle(fontSize: 10, color: PremiumColors.primaryLight),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: selectedGroupGender == 'PUTRA' ? Colors.blue.withOpacity(0.15) : Colors.pink.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          selectedGroupGender,
                          style: TextStyle(
                            fontSize: 9, 
                            fontWeight: FontWeight.bold, 
                            color: selectedGroupGender == 'PUTRA' ? Colors.blueAccent : Colors.pinkAccent
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.redAccent),
                        tooltip: 'Cetak PDF Kelompok',
                        onPressed: () => _downloadGroupPdf(dataProvider, _selectedGroupId!),
                      ),
                      TextButton.icon(
                        onPressed: () => _showExamineeForm(context, dataProvider, null, autoGroupId: _selectedGroupId!),
                        icon: const Icon(Icons.add, size: 16, color: PremiumColors.accent),
                        label: const Text('Tambah Santri', style: TextStyle(color: PremiumColors.accent, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (groupStudents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'Belum ada calon santri di kelompok ini.',
                      style: TextStyle(color: PremiumColors.textMuted(context), fontSize: 13),
                    ),
                  ),
                )
              else
                ...groupStudents.map((examinee) {
                  final String name = examinee['name'];
                  final String regNum = examinee['registration_number'];
                  final String gender = examinee['gender'] ?? 'PUTRA';
                  final String school = examinee['school'] ?? 'MTS';
                  final String? placement = examinee['placement'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: gender == 'PUTRA' ? Colors.blue.withOpacity(0.15) : Colors.pink.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        gender,
                                        style: TextStyle(
                                          fontSize: 9, 
                                          fontWeight: FontWeight.bold, 
                                          color: gender == 'PUTRA' ? Colors.blueAccent : Colors.pinkAccent
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        school,
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'No. Daftar: $regNum',
                                  style: TextStyle(color: PremiumColors.textMuted(context), fontSize: 11),
                                ),
                                if (placement != null) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Lulus Kelas: $placement',
                                      style: const TextStyle(fontSize: 10, color: PremiumColors.accent, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                ]
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 18),
                                onPressed: () => _showExamineeForm(context, dataProvider, examinee, autoGroupId: _selectedGroupId!),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                onPressed: () => _confirmDeleteExaminee(context, dataProvider, examinee['id'], name),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // --- DIALOGS & FORMS ---

  // Dialog Form Kelompok (Create / Update)
  void _showGroupForm(BuildContext context, DataProvider dataProvider, dynamic group) {
    final nameController = TextEditingController(text: group?['group_name']);
    final descController = TextEditingController(text: group?['description']);
    final isEdit = group != null;
    String selectedGender = group?['group_gender'] ?? 'PUTRA';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: PremiumColors.bgDarkSecondary,
              title: Text(isEdit ? 'Ubah Kelompok' : 'Tambah Kelompok Baru'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nama Kelompok', hintText: 'Kelompok 1'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Deskripsi', hintText: 'Keterangan kelompok'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedGender,
                    decoration: const InputDecoration(labelText: 'Kategori Gender Kelompok'),
                    dropdownColor: PremiumColors.bgDarkSecondary,
                    items: const [
                      DropdownMenuItem(value: 'PUTRA', child: Text('Putra (Laki-laki)')),
                      DropdownMenuItem(value: 'PUTRI', child: Text('Putri (Perempuan)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedGender = val;
                        });
                      }
                    },
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal', style: TextStyle(color: PremiumColors.textMuted(context))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: PremiumColors.primary),
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty) {
                      bool success;
                      if (isEdit) {
                        success = await dataProvider.updateGroup(group['id'], nameController.text.trim(), descController.text.trim(), selectedGender);
                      } else {
                        success = await dataProvider.createGroup(nameController.text.trim(), descController.text.trim(), selectedGender);
                      }
                      if (success && mounted) {
                        Navigator.pop(context);
                        _refreshData();
                      }
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // Konfirmasi Hapus Kelompok
  void _confirmDeleteGroup(BuildContext context, DataProvider dataProvider, int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PremiumColors.bgDarkSecondary,
        title: const Text('Hapus Kelompok'),
        content: Text('Apakah Anda yakin ingin menghapus "$name"? Semua calon santri di kelompok ini akan kehilangan penugasan kelompoknya.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: PremiumColors.textMuted(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final success = await dataProvider.deleteGroup(id);
              if (success && mounted) {
                Navigator.pop(context);
                _refreshData();
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // Dialog Form Registrasi & Edit Penguji (User)
  void _showUserForm(BuildContext context, DataProvider dataProvider, dynamic user) {
    final isEdit = user != null;
    final userController = TextEditingController(text: user?['username']);
    final passController = TextEditingController();
    String selectedRole = user?['role'] ?? 'EXAMINER';
    int? selectedGroupId = user?['group_id'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: PremiumColors.bgDarkSecondary,
              title: Text(isEdit ? 'Ubah Akun Penguji' : 'Akun Penguji Baru'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: userController,
                      decoration: const InputDecoration(labelText: 'Username', hintText: 'nama_penguji'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passController,
                      decoration: InputDecoration(
                        labelText: isEdit ? 'Password Baru (Kosongkan jika tetap)' : 'Password',
                        hintText: isEdit ? 'Biarkan kosong jika tidak diubah' : 'Ketik password'
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'Peran (Role)'),
                      dropdownColor: PremiumColors.bgDarkSecondary,
                      items: const [
                        DropdownMenuItem(value: 'EXAMINER', child: Text('Penguji Biasa (EXAMINER)')),
                        DropdownMenuItem(value: 'SUPER_USER', child: Text('Super User (SUPER_USER)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedRole = val;
                            if (selectedRole == 'SUPER_USER') {
                              selectedGroupId = null;
                            }
                          });
                        }
                      },
                    ),
                    if (selectedRole == 'EXAMINER') ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int?>(
                        value: selectedGroupId,
                        decoration: const InputDecoration(labelText: 'Pilih Kelompok Tugas'),
                        dropdownColor: PremiumColors.bgDarkSecondary,
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Tanpa Kelompok')),
                          ...dataProvider.groups.map((g) {
                            return DropdownMenuItem<int?>(value: g['id'], child: Text(g['group_name']));
                          }),
                        ],
                        onChanged: (val) {
                          setState(() => selectedGroupId = val);
                        },
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal', style: TextStyle(color: PremiumColors.textMuted(context))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: PremiumColors.primary),
                  onPressed: () async {
                    if (userController.text.trim().isNotEmpty) {
                      if (!isEdit && passController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password wajib diisi untuk pengguna baru!'), backgroundColor: Colors.redAccent)
                        );
                        return;
                      }

                      bool success;
                      if (isEdit) {
                        success = await dataProvider.updateUser(
                          user['id'], 
                          userController.text.trim(), 
                          passController.text.isNotEmpty ? passController.text : null, 
                          selectedRole, 
                          selectedGroupId
                        );
                      } else {
                        success = await dataProvider.registerUser(
                          userController.text.trim(), 
                          passController.text, 
                          selectedRole, 
                          selectedGroupId
                        );
                      }
                      
                      if (success && mounted) {
                        Navigator.pop(context);
                        _refreshData();
                      }
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Konfirmasi & Proses Hapus User (Penguji)
  void _confirmDeleteUser(BuildContext context, DataProvider dataProvider, int id, String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PremiumColors.bgDarkSecondary,
        title: const Text('Hapus Akun Penguji'),
        content: Text('Apakah Anda yakin ingin menghapus akun "$username"? Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: PremiumColors.textMuted(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final success = await dataProvider.deleteUser(id);
              if (success && mounted) {
                Navigator.pop(context);
                _refreshData();
              } else if (!success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(dataProvider.error ?? 'Gagal menghapus pengguna'),
                    backgroundColor: Colors.redAccent,
                  )
                );
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // Dialog Form Calon Santri (Dari PSB / Custom Edit)
  void _showExamineeForm(BuildContext context, DataProvider dataProvider, dynamic examinee, {required int autoGroupId}) {
    final isEdit = examinee != null;
    
    // Controller untuk edit
    final nameController = TextEditingController(text: examinee?['name']);
    String selectedGender = examinee?['gender'] ?? 'PUTRA';
    String selectedSchool = examinee?['school'] ?? 'MTS';

    // State untuk tambah baru
    Future<List<dynamic>>? candidatesFuture;
    dynamic selectedCandidate;

    // Dapatkan gender kelompok terpilih untuk memfilter calon santri
    final group = dataProvider.groups.firstWhere((g) => g['id'] == autoGroupId);
    final String groupGender = group['group_gender'] ?? 'PUTRA';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (!isEdit && candidatesFuture == null) {
              candidatesFuture = dataProvider.apiService.getAvailableCandidates(groupGender);
            }

            return AlertDialog(
              backgroundColor: PremiumColors.bgDarkSecondary,
              title: Text(isEdit ? 'Ubah Calon Santri' : 'Tambah Calon Santri (Dari PSB)'),
              content: SingleChildScrollView(
                child: isEdit
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(labelText: 'Nama Lengkap', hintText: 'Nama Santri'),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedGender,
                            decoration: const InputDecoration(labelText: 'Jenis Kelamin'),
                            dropdownColor: PremiumColors.bgDarkSecondary,
                            items: const [
                              DropdownMenuItem(value: 'PUTRA', child: Text('Putra (Laki-laki)')),
                              DropdownMenuItem(value: 'PUTRI', child: Text('Putri (Perempuan)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => selectedGender = val);
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedSchool,
                            decoration: const InputDecoration(labelText: 'Jenjang Sekolah Pendaftaran'),
                            dropdownColor: PremiumColors.bgDarkSecondary,
                            items: const [
                              DropdownMenuItem(value: 'MTS', child: Text('MTs (Tingkat Menengah)')),
                              DropdownMenuItem(value: 'ALIYAH', child: Text('Aliyah (Tingkat Atas)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => selectedSchool = val);
                            },
                          ),
                        ],
                      )
                    : FutureBuilder<List<dynamic>>(
                        future: candidatesFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 100,
                              child: Center(child: CircularProgressIndicator(color: PremiumColors.primaryLight)),
                            );
                          }
                          if (snapshot.hasError) {
                            return Text(
                              'Gagal memuat data PSB: ${snapshot.error}',
                              style: const TextStyle(color: Colors.redAccent),
                            );
                          }

                          final candidates = snapshot.data ?? [];
                          if (candidates.isEmpty) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline, color: PremiumColors.textMuted(context), size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  'Tidak ditemukan calon santri ${groupGender == 'PUTRA' ? "Putra" : "Putri"} yang belum ditugaskan kelompok.',
                                  style: TextStyle(color: PremiumColors.textMuted(context), fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<dynamic>(
                                value: selectedCandidate,
                                decoration: const InputDecoration(
                                  labelText: 'Pilih Calon Santri',
                                  hintText: 'Pilih nama santri...',
                                ),
                                dropdownColor: PremiumColors.bgDarkSecondary,
                                items: candidates.map((c) {
                                  return DropdownMenuItem<dynamic>(
                                    value: c,
                                    child: Text(
                                      "${c['name']} (${c['school']})",
                                      style: TextStyle(fontSize: 13, color: PremiumColors.textMain(context)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    selectedCandidate = val;
                                  });
                                },
                              ),
                              if (selectedCandidate != null) ...[
                                const SizedBox(height: 20),
                                const Text(
                                  'Detail Calon Santri:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: PremiumColors.primaryLight),
                                ),
                                const SizedBox(height: 8),
                                Text('Nama: ${selectedCandidate['name']}', style: const TextStyle(fontSize: 13)),
                                const SizedBox(height: 4),
                                Text('No. Daftar: ${selectedCandidate['registration_number']}', style: TextStyle(fontSize: 13, color: PremiumColors.textMuted(context))),
                                const SizedBox(height: 4),
                                Text('Jenis Kelamin: ${selectedCandidate['gender'] == 'PUTRA' ? "Laki-laki (Putra)" : "Perempuan (Putri)"}', style: const TextStyle(fontSize: 13)),
                                const SizedBox(height: 4),
                                Text('Jenjang: ${selectedCandidate['school']}', style: const TextStyle(fontSize: 13)),
                              ]
                            ],
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal', style: TextStyle(color: PremiumColors.textMuted(context))),
                ),
                if (isEdit || (selectedCandidate != null))
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: PremiumColors.primary),
                    onPressed: () async {
                      bool success;
                      if (isEdit) {
                        success = await dataProvider.updateExaminee(
                          examinee['id'],
                          nameController.text.trim(),
                          selectedGender,
                          selectedSchool,
                          autoGroupId,
                        );
                      } else {
                        success = await dataProvider.createExaminee(
                          selectedCandidate['registration_number'],
                          selectedCandidate['name'],
                          selectedCandidate['gender'],
                          selectedCandidate['school'],
                          autoGroupId,
                        );
                      }
                      if (success && mounted) {
                        Navigator.pop(context);
                        _refreshData();
                      }
                    },
                    child: const Text('Simpan'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // Konfirmasi Hapus Calon Santri
  void _confirmDeleteExaminee(BuildContext context, DataProvider dataProvider, int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PremiumColors.bgDarkSecondary,
        title: const Text('Hapus Calon Santri'),
        content: Text('Apakah Anda yakin ingin menghapus data calon santri "$name"? Data hasil ujian miliknya juga akan dihapus secara permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: PremiumColors.textMuted(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final success = await dataProvider.deleteExaminee(id);
              if (success && mounted) {
                Navigator.pop(context);
                _refreshData();
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
