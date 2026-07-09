import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../theme/premium_theme.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataProvider>(context, listen: false).fetchAllAdminData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshData() {
    Provider.of<DataProvider>(context, listen: false).fetchAllAdminData();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final dataProvider = Provider.of<DataProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Panel Kontrol Super User',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: PremiumColors.textMain),
            ),
            Text(
              'Kelola Kelompok, Penguji & Calon Santri',
              style: TextStyle(fontSize: 12, color: PremiumColors.primaryLight),
            ),
          ],
        ),
        actions: [
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: PremiumColors.primaryLight,
          labelColor: PremiumColors.primaryLight,
          unselectedLabelColor: PremiumColors.textMuted,
          tabs: const [
            Tab(icon: Icon(Icons.group_work_outlined), text: 'Kelompok'),
            Tab(icon: Icon(Icons.supervisor_account), text: 'Penguji'),
            Tab(icon: Icon(Icons.people_outline), text: 'Santri'),
          ],
        ),
      ),
      body: PremiumBackground(
        child: dataProvider.isLoading
            ? const Center(child: CircularProgressIndicator(color: PremiumColors.primaryLight))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildGroupsTab(dataProvider),
                  _buildUsersTab(dataProvider),
                  _buildExamineesTab(dataProvider),
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
              ? const Center(child: Text('Belum ada kelompok.', style: TextStyle(color: PremiumColors.textMuted)))
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
                                Text(
                                  group['group_name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  group['description'] ?? 'Tanpa deskripsi',
                                  style: const TextStyle(color: PremiumColors.textMuted, fontSize: 13),
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
          child: PremiumButton(
            label: 'Buat Akun Penguji Baru',
            icon: Icons.person_add_alt,
            onPressed: () => _showUserForm(context, dataProvider, null),
          ),
        ),
        Expanded(
          child: dataProvider.users.isEmpty
              ? const Center(child: Text('Belum ada pengguna.', style: TextStyle(color: PremiumColors.textMuted)))
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
                                  const Text('Semua Kelompok (Super User)', style: TextStyle(color: PremiumColors.textMutedLight, fontSize: 12))
                                else
                                  Text(
                                    assigned.isEmpty
                                        ? 'Kelompok: Belum ditentukan'
                                        : 'Kelompok: ${assigned.map((g) => g['name']).join(', ')}',
                                    style: const TextStyle(color: PremiumColors.textMuted, fontSize: 12),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Harap tambahkan kelompok terlebih dahulu di tab Kelompok.',
            style: TextStyle(color: PremiumColors.textMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Map students by group_id for faster lookup
    final Map<int?, List<dynamic>> groupedExaminees = {};
    for (var examinee in dataProvider.examinees) {
      final int? gId = examinee['group_id'];
      groupedExaminees.putIfAbsent(gId, () => []).add(examinee);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: dataProvider.groups.length,
      itemBuilder: (context, groupIndex) {
        final group = dataProvider.groups[groupIndex];
        final int groupId = group['id'];
        final String groupName = group['group_name'];
        final groupStudents = groupedExaminees[groupId] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      groupName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: PremiumColors.textMain),
                    ),
                    const SizedBox(width: 8),
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
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _showExamineeForm(context, dataProvider, null, autoGroupId: groupId),
                  icon: const Icon(Icons.add, size: 16, color: PremiumColors.accent),
                  label: const Text('Tambah Santri', style: TextStyle(color: PremiumColors.accent, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // List Santri di Kelompok ini
            if (groupStudents.isEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 28, bottom: 20, top: 4),
                child: Text('Belum ada calon santri di kelompok ini.', style: TextStyle(color: PremiumColors.textMuted, fontSize: 13)),
              )
            else ...[
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
                                style: const TextStyle(color: PremiumColors.textMuted, fontSize: 11),
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
                              onPressed: () => _showExamineeForm(context, dataProvider, examinee, autoGroupId: groupId),
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
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }


  // --- DIALOGS & FORMS ---

  // Dialog Form Kelompok (Create / Update)
  void _showGroupForm(BuildContext context, DataProvider dataProvider, dynamic group) {
    final nameController = TextEditingController(text: group?['group_name']);
    final descController = TextEditingController(text: group?['description']);
    final isEdit = group != null;

    showDialog(
      context: context,
      builder: (context) {
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: PremiumColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: PremiumColors.primary),
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  bool success;
                  if (isEdit) {
                    success = await dataProvider.updateGroup(group['id'], nameController.text.trim(), descController.text.trim());
                  } else {
                    success = await dataProvider.createGroup(nameController.text.trim(), descController.text.trim());
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
            child: const Text('Batal', style: TextStyle(color: PremiumColors.textMuted)),
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
                  child: const Text('Batal', style: TextStyle(color: PremiumColors.textMuted)),
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
            child: const Text('Batal', style: TextStyle(color: PremiumColors.textMuted)),
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

  // Dialog Form Calon Santri (Tanpa No Pendaftaran, ada Gender & School)
  void _showExamineeForm(BuildContext context, DataProvider dataProvider, dynamic examinee, {required int autoGroupId}) {
    final nameController = TextEditingController(text: examinee?['name']);
    String selectedGender = examinee?['gender'] ?? 'PUTRA';
    String selectedSchool = examinee?['school'] ?? 'MTS';
    final isEdit = examinee != null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: PremiumColors.bgDarkSecondary,
              title: Text(isEdit ? 'Ubah Calon Santri' : 'Tambah Calon Santri'),
              content: SingleChildScrollView(
                child: Column(
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
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal', style: TextStyle(color: PremiumColors.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: PremiumColors.primary),
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty) {
                      bool success;
                      if (isEdit) {
                        success = await dataProvider.updateExaminee(
                          examinee['id'], 
                          nameController.text.trim(), 
                          selectedGender,
                          selectedSchool,
                          autoGroupId
                        );
                      } else {
                        success = await dataProvider.createExaminee(
                          nameController.text.trim(), 
                          selectedGender,
                          selectedSchool,
                          autoGroupId
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
            child: const Text('Batal', style: TextStyle(color: PremiumColors.textMuted)),
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
