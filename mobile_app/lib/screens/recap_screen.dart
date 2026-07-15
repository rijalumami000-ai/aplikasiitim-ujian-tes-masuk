import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../services/pdf_generator.dart';
import '../theme/premium_theme.dart';

class RecapScreen extends StatefulWidget {
  const RecapScreen({super.key});

  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends State<RecapScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterGrade = 'ALL'; // ALL, SIFIR, SATU, SP, UNGRADED

  Future<void> _downloadPlacementsPdf(DataProvider dataProvider) async {
    try {
      await PdfGenerator.generateAndPreviewPlacementsPdf(
        groups: dataProvider.groups,
        examinees: dataProvider.examinees,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan saat membuat PDF: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dp = Provider.of<DataProvider>(context, listen: false);
      dp.fetchRecap();
      dp.fetchExaminees();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final dp = Provider.of<DataProvider>(context, listen: false);
    await dp.fetchRecap();
    await dp.fetchExaminees();
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
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
    final dataProvider = Provider.of<DataProvider>(context);
    final recap = dataProvider.recap;
    final summary = recap?['summary'];
    final groupsBreakdown = recap?['groups'] as List<dynamic>? ?? [];

    // Filter data calon santri untuk pencarian & filter kelulusan
    final filteredExaminees = dataProvider.examinees.where((e) {
      final String name = e['name'].toString().toLowerCase();
      final String regNum = e['registration_number'].toString().toLowerCase();
      final String? placement = e['placement'];
      
      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || regNum.contains(_searchQuery.toLowerCase());
      
      bool matchesGrade = true;
      if (_filterGrade == 'SIFIR') {
        matchesGrade = placement == 'SIFIR';
      } else if (_filterGrade == 'SATU') {
        matchesGrade = placement == 'SATU';
      } else if (_filterGrade == 'SP') {
        matchesGrade = placement == 'SP';
      } else if (_filterGrade == 'UNGRADED') {
        matchesGrade = placement == null;
      }

      return matchesSearch && matchesGrade;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rekapitulasi Penempatan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: PremiumColors.textMain(context)),
            ),
            const Text(
              'Statistik Hasil Ujian Santri',
              style: TextStyle(fontSize: 12, color: PremiumColors.primaryLight),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_for_offline, color: PremiumColors.accent, size: 28),
            tooltip: 'Cetak PDF Rekap Penempatan',
            onPressed: () => _downloadPlacementsPdf(dataProvider),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: PremiumBackground(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: PremiumColors.primaryLight,
          backgroundColor: PremiumColors.bgDarkSecondary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                
                if (summary != null) ...[
                  // 1. KPI Cards Row
                  Row(
                    children: [
                      _buildKPICard('Total Pendaftar', summary['total'].toString(), Icons.people, Colors.blueAccent),
                      const SizedBox(width: 12),
                      _buildKPICard('Telah Dinilai', summary['graded'].toString(), Icons.check_circle, PremiumColors.accent),
                      const SizedBox(width: 12),
                      _buildKPICard('Belum Dinilai', summary['ungraded'].toString(), Icons.pending, Colors.amber),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. Bar Penempatan Kelas (Visual Distribution)
                  Text(
                    'Distribusi Kelulusan Kelas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PremiumColors.textMain(context)),
                  ),
                  const SizedBox(height: 16),
                  _buildDistributionBar(summary['grades']),
                  const SizedBox(height: 28),
                ],

                // 3. Progres Kelompok
                if (groupsBreakdown.isNotEmpty) ...[
                  Text(
                    'Progres Pengujian per Kelompok',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PremiumColors.textMain(context)),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groupsBreakdown.length,
                    itemBuilder: (context, index) {
                      final g = groupsBreakdown[index];
                      final String groupName = g['groupName'];
                      final int total = g['totalStudents'];
                      final int graded = g['gradedStudents'];
                      final int progress = g['progressPercent'];

                      return GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  groupName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  '$graded/$total Santri ($progress%)',
                                  style: TextStyle(fontSize: 12, color: PremiumColors.textMuted(context)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: total > 0 ? (graded / total) : 0.0,
                                minHeight: 8,
                                backgroundColor: Colors.white10,
                                valueColor: const AlwaysStoppedAnimation<Color>(PremiumColors.primaryLight),
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                ],

                // 4. Detail Santri & Filter Pencarian
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daftar Hasil Santri',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PremiumColors.textMain(context)),
                    ),
                    _buildGradeFilterDropdown(),
                  ],
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Cari nama santri...',
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                ),
                const SizedBox(height: 16),

                // List Santri hasil filter
                filteredExaminees.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Text('Tidak ada data santri yang cocok.', style: TextStyle(color: PremiumColors.textMuted(context))),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredExaminees.length,
                        itemBuilder: (context, index) {
                          final e = filteredExaminees[index];
                          final String? placement = e['placement'];
                          return GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            borderColor: placement != null
                                ? _getGradeColor(placement).withOpacity(0.2)
                                : PremiumColors.cardBorder,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e['name'],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'No: ${e['registration_number']} | Kelompok: ${e['group_name'] ?? "-"}',
                                        style: TextStyle(color: PremiumColors.textMuted(context), fontSize: 11),
                                      ),
                                      if (placement != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Diuji oleh: ${e['examiner_name'] ?? "-"}',
                                          style: TextStyle(color: PremiumColors.textMuted(context), fontSize: 10),
                                        )
                                      ]
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: placement != null 
                                        ? _getGradeColor(placement).withOpacity(0.15)
                                        : Colors.white10,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: placement != null ? _getGradeColor(placement).withOpacity(0.4) : Colors.transparent
                                    )
                                  ),
                                  child: Text(
                                    placement ?? 'BELUM',
                                    style: TextStyle(
                                      fontSize: 11, 
                                      fontWeight: FontWeight.bold,
                                      color: placement != null ? _getGradeColor(placement) : PremiumColors.textMuted(context)
                                    ),
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget KPI Card
  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: PremiumColors.textMain(context)),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 10, color: PremiumColors.textMuted(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Widget Visual Bar Penempatan Kelas (Distribution Bar)
  Widget _buildDistributionBar(dynamic grades) {
    final int sifir = grades['SIFIR'] ?? 0;
    final int satu = grades['SATU'] ?? 0;
    final int sp = grades['SP'] ?? 0;
    final int total = sifir + satu + sp;

    final double pctSifir = total > 0 ? (sifir / total) : 0.0;
    final double pctSatu = total > 0 ? (satu / total) : 0.0;
    final double pctSp = total > 0 ? (sp / total) : 0.0;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem('SIFIR', sifir, pctSifir, PremiumColors.sifirColor),
              _buildLegendItem('SATU', satu, pctSatu, PremiumColors.satuColor),
              _buildLegendItem('SP', sp, pctSp, PremiumColors.spColor),
            ],
          ),
          const SizedBox(height: 20),
          
          // Gabungan Bar Horizontal
          if (total == 0)
            Container(
              height: 16,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text('Belum ada data nilai', style: TextStyle(fontSize: 10, color: PremiumColors.textMuted(context))),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 16,
                child: Row(
                  children: [
                    if (sifir > 0)
                      Expanded(
                        flex: (pctSifir * 100).round(),
                        child: Container(
                          color: PremiumColors.sifirColor,
                        ),
                      ),
                    if (satu > 0)
                      Expanded(
                        flex: (pctSatu * 100).round(),
                        child: Container(
                          color: PremiumColors.satuColor,
                        ),
                      ),
                    if (sp > 0)
                      Expanded(
                        flex: (pctSp * 100).round(),
                        child: Container(
                          color: PremiumColors.spColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Widget Legend Item untuk Bar Penempatan
  Widget _buildLegendItem(String label, int count, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PremiumColors.textMain(context))),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$count Santri (${(percentage * 100).toStringAsFixed(0)}%)',
          style: TextStyle(fontSize: 11, color: PremiumColors.textMuted(context)),
        )
      ],
    );
  }

  // Widget Dropdown Filter Kelulusan Kelas
  Widget _buildGradeFilterDropdown() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : PremiumColors.bgDarkSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isLight ? const Color(0xFFE2E8F0) : PremiumColors.cardBorder),
      ),
      child: DropdownButton<String>(
        value: _filterGrade,
        underline: const SizedBox(),
        dropdownColor: isLight ? Colors.white : PremiumColors.bgDarkSecondary,
        style: TextStyle(fontSize: 12, color: PremiumColors.textMain(context), fontWeight: FontWeight.bold),
        items: const [
          DropdownMenuItem(value: 'ALL', child: Text('Semua')),
          DropdownMenuItem(value: 'SIFIR', child: Text('SIFIR')),
          DropdownMenuItem(value: 'SATU', child: Text('SATU')),
          DropdownMenuItem(value: 'SP', child: Text('SP')),
          DropdownMenuItem(value: 'UNGRADED', child: Text('Belum Dinilai')),
        ],
        onChanged: (val) {
          if (val != null) setState(() => _filterGrade = val);
        },
      ),
    );
  }
}
