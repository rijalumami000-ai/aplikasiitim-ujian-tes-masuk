import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../theme/premium_theme.dart';
import 'examinee_checklist_screen.dart';

class ExaminerDashboard extends StatefulWidget {
  const ExaminerDashboard({super.key});

  @override
  State<ExaminerDashboard> createState() => _ExaminerDashboardState();
}

class _ExaminerDashboardState extends State<ExaminerDashboard> {
  @override
  void initState() {
    super.initState();
    // Tarik data kelompok saat halaman dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataProvider>(context, listen: false).fetchGroups();
    });
  }

  // Melakukan refresh data kelompok
  Future<void> _onRefresh() async {
    await Provider.of<DataProvider>(context, listen: false).fetchGroups();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final dataProvider = Provider.of<DataProvider>(context);
    
    final username = authProvider.user?['username'] ?? 'Penguji';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: PremiumColors.primary.withOpacity(0.3),
              child: Text(
                username[0].toUpperCase(),
                style: const TextStyle(color: PremiumColors.primaryLight, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PremiumColors.textMain),
                ),
                const Text(
                  'Tim Penguji Ujian',
                  style: TextStyle(fontSize: 12, color: PremiumColors.textMuted),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Navigasi ke Rekap Hasil Penempatan Kelas
          IconButton(
            icon: const Icon(Icons.bar_chart, color: PremiumColors.primaryLight, size: 28),
            tooltip: 'Rekap Hasil Penempatan',
            onPressed: () {
              Navigator.pushNamed(context, '/recap');
            },
          ),
          // Tombol Logout
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Colors.redAccent),
            tooltip: 'Keluar',
            onPressed: () async {
              await authProvider.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: PremiumBackground(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: PremiumColors.primaryLight,
          backgroundColor: PremiumColors.bgDarkSecondary,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Banner Informasi
                GlassCard(
                  borderColor: PremiumColors.primary.withOpacity(0.3),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: PremiumColors.primaryLight, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kelompok Pengujian',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: PremiumColors.textMain),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Anda dapat menceklis santri pada kelompok bertanda "Aktif". Kelompok lain bersifat "Lihat Saja".',
                              style: TextStyle(fontSize: 12, color: PremiumColors.textMuted.withOpacity(0.85)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Daftar Kelompok',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: PremiumColors.textMain),
                ),
                const SizedBox(height: 16),
                
                // Konten Grid Kelompok
                Expanded(
                  child: dataProvider.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: PremiumColors.primaryLight,
                          ),
                        )
                      : dataProvider.error != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                                  const SizedBox(height: 16),
                                  Text(
                                    dataProvider.error!,
                                    style: const TextStyle(color: Colors.redAccent),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _onRefresh,
                                    child: const Text('Coba Lagi'),
                                  )
                                ],
                              ),
                            )
                          : dataProvider.groups.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Belum ada kelompok yang terdaftar.',
                                    style: TextStyle(color: PremiumColors.textMuted),
                                  ),
                                )
                              : GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 1.1,
                                  ),
                                  itemCount: dataProvider.groups.length,
                                  itemBuilder: (context, index) {
                                    final group = dataProvider.groups[index];
                                    final int groupId = group['id'];
                                    final String groupName = group['group_name'];
                                    final String? description = group['description'];

                                    // Cek apakah penguji ditugaskan ke kelompok ini
                                    final isAssigned = authProvider.hasGroupPermission(groupId);

                                    return GlassCard(
                                      padding: EdgeInsets.zero,
                                      borderColor: isAssigned 
                                          ? PremiumColors.primaryLight.withOpacity(0.4) 
                                          : PremiumColors.cardBorder,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ExamineeChecklistScreen(
                                              groupId: groupId,
                                              groupName: groupName,
                                              isReadOnly: !isAssigned,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Stack(
                                        children: [
                                          // Background Gradient halus untuk kelompok aktif
                                          if (isAssigned)
                                            Positioned.fill(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(24),
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      PremiumColors.primary.withOpacity(0.1),
                                                      PremiumColors.accent.withOpacity(0.05)
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          
                                          // Konten Teks
                                          Padding(
                                            padding: const EdgeInsets.all(18.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                // Icon status
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Icon(
                                                      isAssigned ? Icons.assignment : Icons.lock_outline,
                                                      color: isAssigned 
                                                          ? PremiumColors.primaryLight 
                                                          : PremiumColors.textMutedLight,
                                                      size: 24,
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: isAssigned 
                                                            ? PremiumColors.accent.withOpacity(0.15) 
                                                            : Colors.white10,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        isAssigned ? 'Aktif' : 'Lihat',
                                                        style: TextStyle(
                                                          fontSize: 10, 
                                                          fontWeight: FontWeight.bold,
                                                          color: isAssigned ? PremiumColors.accent : PremiumColors.textMuted
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                
                                                // Informasi Kelompok
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      groupName,
                                                      style: const TextStyle(
                                                        fontSize: 16, 
                                                        fontWeight: FontWeight.bold, 
                                                        color: PremiumColors.textMain
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      description ?? 'Tanpa deskripsi',
                                                      style: const TextStyle(
                                                        fontSize: 12, 
                                                        color: PremiumColors.textMuted
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                )
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
