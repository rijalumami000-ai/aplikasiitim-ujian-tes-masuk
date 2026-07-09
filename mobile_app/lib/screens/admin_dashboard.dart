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
            onPressed: () => _showUserForm(context, dataProvider),
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
                                // Menampilkan daftar kelompok yang ditugaskan
                                if (role == 'SUPER_USER')
                                  const Text('Semua Kelompok (Super User)', style: TextStyle(color: PremiumColors.textMutedLight, fontSize: 12))
                                else
                                  Text(
                                    assigned.isEmpty
                                        ? 'Kelompok ditugaskan: Belum ada'
                                        : 'Kelompok ditugaskan: ${assigned.map((g) => g['name']).join(', ')}',
                                    style: const TextStyle(color: PremiumColors.textMuted, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          if (role != 'SUPER_USER')
                            ElevatedButton.icon(
                              onPressed: () => _showAssignGroupsDialog(context, dataProvider, user['id'], username, assigned),
                              icon: const Icon(Icons.link_outlined, size: 16),
                              label: const Text('Tugaskan', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PremiumColors.primary.withOpacity(0.6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: PremiumButton(
            label: 'Tambah Calon Santri',
            icon: Icons.person_add_outlined,
            onPressed: () => _showExamineeForm(context, dataProvider, null),
          ),
        ),
        Expanded(
          child: dataProvider.examinees.isEmpty
              ? const Center(child: Text('Belum ada calon santri.', style: TextStyle(color: PremiumColors.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: dataProvider.examinees.length,
                  itemBuilder: (context, index) {
                    final examinee = dataProvider.examinees[index];
                    final String name = examinee['name'];
                    final String regNum = examinee['registration_number'];
                    final String? groupName = examinee['group_name'];
                    final String? placement = examinee['placement'];

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
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'No. Daftar: $regNum | Kelompok: ${groupName ?? "Belum Masuk"}',
                                  style: const TextStyle(color: PremiumColors.textMuted, fontSize: 12),
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
                                icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                                onPressed: () => _showExamineeForm(context, dataProvider, examinee),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () => _confirmDeleteExaminee(context, dataProvider, examinee['id'], name),
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

  // Dialog Form Registrasi User (Penguji)
  void _showUserForm(BuildContext context, DataProvider dataProvider) {
    final userController = TextEditingController();
    final passController = TextEditingController();
    String selectedRole = 'EXAMINER';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: PremiumColors.bgDarkSecondary,
              title: const Text('Akun Penguji Baru'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: userController,
                    decoration: const InputDecoration(labelText: 'Username', hintText: 'nama_penguji'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passController,
                    decoration: const InputDecoration(labelText: 'Password', hintText: 'Ketik password'),
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
                      if (val != null) setState(() => selectedRole = val);
                    },
                  )
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
                    if (userController.text.trim().isNotEmpty && passController.text.isNotEmpty) {
                      final success = await dataProvider.registerUser(userController.text.trim(), passController.text, selectedRole);
                      if (success && mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Daftarkan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog Penugasan Kelompok ke Penguji
  void _showAssignGroupsDialog(
    BuildContext context, 
    DataProvider dataProvider, 
    int userId, 
    String username, 
    List<dynamic> assignedGroups
  ) {
    // List ID kelompok yang saat ini ditugaskan
    final List<int> selectedIds = assignedGroups.map((g) => g['id'] as int).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: PremiumColors.bgDarkSecondary,
              title: Text('Tugaskan Kelompok: $username'),
              content: SizedBox(
                width: double.maxFinite,
                child: dataProvider.groups.isEmpty
                    ? const Text('Belum ada kelompok yang terdaftar.', style: TextStyle(color: PremiumColors.textMuted))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: dataProvider.groups.length,
                        itemBuilder: (context, index) {
                          final g = dataProvider.groups[index];
                          final int gId = g['id'];
                          final bool isChecked = selectedIds.contains(gId);

                          return CheckboxListTile(
                            title: Text(g['group_name']),
                            value: isChecked,
                            activeColor: PremiumColors.accent,
                            onChanged: (bool? val) {
                              setState(() {
                                if (val == true) {
                                  selectedIds.add(gId);
                                } else {
                                  selectedIds.remove(gId);
                                }
                              });
                            },
                          );
                        },
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
                    final success = await dataProvider.assignGroupsToUser(userId, selectedIds);
                    if (success && mounted) Navigator.pop(context);
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

  // Dialog Form Calon Santri (Create / Update)
  void _showExamineeForm(BuildContext context, DataProvider dataProvider, dynamic examinee) {
    final regController = TextEditingController(text: examinee?['registration_number']);
    final nameController = TextEditingController(text: examinee?['name']);
    int? selectedGroupId = examinee?['group_id'];
    final isEdit = examinee != null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: PremiumColors.bgDarkSecondary,
              title: Text(isEdit ? 'Ubah Calon Santri' : 'Tambah Calon Santri'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: regController,
                    decoration: const InputDecoration(labelText: 'Nomor Pendaftaran', hintText: 'REG2026xxxx'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nama Lengkap', hintText: 'Nama Santri'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    value: selectedGroupId,
                    decoration: const InputDecoration(labelText: 'Pilih Kelompok'),
                    dropdownColor: PremiumColors.bgDarkSecondary,
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Belum Masuk Kelompok')),
                      ...dataProvider.groups.map((g) {
                        return DropdownMenuItem<int?>(value: g['id'], child: Text(g['group_name']));
                      }),
                    ],
                    onChanged: (val) {
                      setState(() => selectedGroupId = val);
                    },
                  )
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
                    if (regController.text.trim().isNotEmpty && nameController.text.trim().isNotEmpty) {
                      bool success;
                      if (isEdit) {
                        success = await dataProvider.updateExaminee(
                          examinee['id'], 
                          regController.text.trim(), 
                          nameController.text.trim(), 
                          selectedGroupId
                        );
                      } else {
                        success = await dataProvider.createExaminee(
                          regController.text.trim(), 
                          nameController.text.trim(), 
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
