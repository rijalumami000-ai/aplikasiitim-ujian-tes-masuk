import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../theme/premium_theme.dart';

class ExamineeChecklistScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  final bool isReadOnly;

  const ExamineeChecklistScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.isReadOnly,
  });

  @override
  State<ExamineeChecklistScreen> createState() => _ExamineeChecklistScreenState();
}

class _ExamineeChecklistScreenState extends State<ExamineeChecklistScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Tarik daftar santri saat halaman dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataProvider>(context, listen: false).fetchExaminees();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper untuk mendapatkan warna chip penempatan
  Color _getPlacementColor(String? placement) {
    switch (placement) {
      case 'SIFIR':
        return PremiumColors.sifirColor;
      case 'SATU':
        return PremiumColors.satuColor;
      case 'SP':
        return PremiumColors.spColor;
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final dataProvider = Provider.of<DataProvider>(context);

    // Filter santri berdasarkan kelompok saat ini dan query pencarian
    final filteredExaminees = dataProvider.examinees.where((e) {
      final matchesGroup = e['group_id'] == widget.groupId;
      final matchesSearch = _searchQuery.isEmpty ||
          e['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e['registration_number'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesGroup && matchesSearch;
    }).toList();

    final examinerName = authProvider.user?['username'] ?? 'Penguji';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: PremiumColors.textMain(context)),
            ),
            Text(
              widget.isReadOnly ? 'Mode Lihat Saja' : 'Ceklis Penempatan Kelas',
              style: TextStyle(
                fontSize: 12, 
                color: widget.isReadOnly ? Colors.orangeAccent : PremiumColors.primaryLight
              ),
            ),
          ],
        ),
      ),
      body: PremiumBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Bar Pencarian
              TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Cari nama atau nomor daftar...',
                  prefixIcon: const Icon(Icons.search, color: PremiumColors.primaryLight),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: PremiumColors.textMuted(context)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // Daftar Calon Santri
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await dataProvider.fetchExaminees();
                  },
                  color: PremiumColors.primaryLight,
                  backgroundColor: PremiumColors.bgDarkSecondary,
                  child: dataProvider.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: PremiumColors.primaryLight),
                        )
                      : filteredExaminees.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: 350,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_outline, size: 64, color: PremiumColors.textMuted(context).withOpacity(0.5)),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty 
                                          ? 'Tidak ditemukan santri "${_searchQuery}"' 
                                          : 'Kelompok ini belum memiliki daftar santri.',
                                      style: TextStyle(color: PremiumColors.textMuted(context)),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                            itemCount: filteredExaminees.length,
                            itemBuilder: (context, index) {
                              final examinee = filteredExaminees[index];
                              final int id = examinee['id'];
                              final String regNum = examinee['registration_number'];
                              final String name = examinee['name'];
                              final String? placement = examinee['placement'];
                              final String? checkedBy = examinee['examiner_name'];

                              final isSyncing = dataProvider.isSyncing(id);

                              return GlassCard(
                                padding: const EdgeInsets.all(16),
                                borderColor: placement != null 
                                    ? _getPlacementColor(placement).withOpacity(0.3)
                                    : PremiumColors.cardBorder,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Baris Atas: Nama dan Status Sinkronisasi
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: TextStyle(
                                                  fontSize: 16, 
                                                  fontWeight: FontWeight.bold, 
                                                  color: PremiumColors.textMain(context)
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text(
                                                    'No. Daftar: $regNum',
                                                    style: TextStyle(fontSize: 12, color: PremiumColors.textMuted(context)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: (examinee['gender'] ?? 'PUTRA') == 'PUTRA' ? Colors.blue.withOpacity(0.15) : Colors.pink.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      examinee['gender'] ?? 'PUTRA',
                                                      style: TextStyle(
                                                        fontSize: 9, 
                                                        fontWeight: FontWeight.bold, 
                                                        color: (examinee['gender'] ?? 'PUTRA') == 'PUTRA' ? Colors.blueAccent : Colors.pinkAccent
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
                                                      examinee['school'] ?? 'MTS',
                                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        // Status Simpan / Sinkronisasi
                                        if (isSyncing)
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(PremiumColors.primaryLight),
                                            ),
                                          )
                                        else if (placement != null)
                                          Row(
                                            children: [
                                              Icon(Icons.check_circle_outline, color: PremiumColors.accent.withOpacity(0.7), size: 16),
                                              const SizedBox(width: 4),
                                              Text(
                                                checkedBy ?? 'Sistem',
                                                style: TextStyle(fontSize: 10, color: PremiumColors.accent.withOpacity(0.7)),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Baris Bawah: Tombol Ceklis Kelulusan
                                    if (widget.isReadOnly)
                                      // Tampilan Mode View Only (Locked)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Status Penempatan:',
                                            style: TextStyle(fontSize: 12, color: PremiumColors.textMuted(context)),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _getPlacementColor(placement).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: _getPlacementColor(placement).withOpacity(0.4),
                                              ),
                                            ),
                                            child: Text(
                                              placement ?? 'Belum Dinilai',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: placement != null ? _getPlacementColor(placement) : PremiumColors.textMuted(context),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      // Tampilan Mode Edit (Ceklis Interaktif)
                                      Row(
                                        children: [
                                          _buildGradeToggleButton('SIFIR', placement, id, name, examinerName, dataProvider),
                                          const SizedBox(width: 10),
                                          _buildGradeToggleButton('SATU', placement, id, name, examinerName, dataProvider),
                                          const SizedBox(width: 10),
                                          _buildGradeToggleButton('SP', placement, id, name, examinerName, dataProvider),
                                        ],
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget custom untuk tombol toggle grade
  Widget _buildGradeToggleButton(
    String targetGrade,
    String? currentGrade,
    int examineeId,
    String examineeName,
    String examinerName,
    DataProvider dataProvider,
  ) {
    final isSelected = currentGrade == targetGrade;
    Color activeColor;
    switch (targetGrade) {
      case 'SIFIR':
        activeColor = PremiumColors.sifirColor;
        break;
      case 'SATU':
        activeColor = PremiumColors.satuColor;
        break;
      case 'SP':
      default:
        activeColor = PremiumColors.spColor;
        break;
    }

    return Expanded(
      child: InkWell(
        onTap: () async {
          // Jika diklik kelas yang sama, hapus penempatan (null)
          final newGrade = isSelected ? null : targetGrade;
          await dataProvider.submitPlacement(examineeId, newGrade, examinerName);

          if (mounted) {
            final message = newGrade != null
                ? 'Berhasil menempatkan $examineeName ke kelas $newGrade'
                : 'Berhasil menghapus penempatan kelas untuk $examineeName';
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                backgroundColor: PremiumColors.accent,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeColor : (Theme.of(context).brightness == Brightness.light ? const Color(0xFFE2E8F0) : PremiumColors.cardBorder),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            targetGrade,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? activeColor : PremiumColors.textMuted(context),
            ),
          ),
        ),
      ),
    );
  }
}
