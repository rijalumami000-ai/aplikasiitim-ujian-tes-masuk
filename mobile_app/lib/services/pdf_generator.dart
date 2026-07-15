import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfGenerator {
  static final _dateFormatter = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID');

  /// Warna-warna tema PDF
  static const _primaryColor = PdfColor.fromInt(0xFF0F766E);
  static const _headerBg = PdfColor.fromInt(0xFF1E293B);
  static const _headerText = PdfColors.white;
  static const _altRowBg = PdfColor.fromInt(0xFFF1F5F9);
  static const _borderColor = PdfColor.fromInt(0xFFCBD5E1);

  // ============================================================
  // 1. PDF Daftar Nama Santri per Kelompok
  // ============================================================
  static Future<void> generateAndPreviewGroupPdf({
    required String groupName,
    required String groupGender,
    required List<dynamic> examinees,
  }) async {
    final pdf = pw.Document();
    final now = _formatDate(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          title: 'Daftar Calon Santri',
          subtitle: '$groupName ($groupGender)',
          date: now,
        ),
        footer: (context) => _buildFooter(context),
        build: (context) {
          if (examinees.isEmpty) {
            return [
              pw.SizedBox(height: 40),
              pw.Center(
                child: pw.Text(
                  'Belum ada calon santri di kelompok ini.',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                ),
              ),
            ];
          }

          return [
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: _borderColor, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(35),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FixedColumnWidth(55),
                4: const pw.FixedColumnWidth(70),
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _headerBg),
                  children: [
                    _headerCell('No'),
                    _headerCell('Nama Lengkap'),
                    _headerCell('No. Daftar'),
                    _headerCell('Jenjang'),
                    _headerCell('Kelas'),
                  ],
                ),
                // Data Rows
                ...examinees.asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  final isAlt = i % 2 == 1;
                  return pw.TableRow(
                    decoration: isAlt ? const pw.BoxDecoration(color: _altRowBg) : null,
                    children: [
                      _dataCell('${i + 1}', center: true),
                      _dataCell(e['name'] ?? '-'),
                      _dataCell(e['registration_number'] ?? '-'),
                      _dataCell(e['school'] ?? '-', center: true),
                      _dataCell(e['placement'] ?? 'Belum', center: true),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Total: ${examinees.length} santri',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) => pdf.save(),
      name: 'Daftar_${groupName.replaceAll(' ', '_')}.pdf',
    );
  }

  // ============================================================
  // 2. PDF Info Login Penguji (Dipisah Putra & Putri)
  // ============================================================
  static Future<void> generateAndPreviewExaminersPdf({
    required List<dynamic> users,
    required List<dynamic> groups,
  }) async {
    final pdf = pw.Document();
    final now = _formatDate(DateTime.now());

    // Pisahkan penguji berdasarkan gender kelompok
    final putraExaminers = <dynamic>[];
    final putriExaminers = <dynamic>[];
    final superUsers = <dynamic>[];

    for (final user in users) {
      final role = user['role'] ?? '';
      if (role == 'SUPER_USER') {
        superUsers.add(user);
        continue;
      }

      final groupId = user['group_id'];
      if (groupId != null) {
        final group = groups.firstWhere(
          (g) => g['id'] == groupId,
          orElse: () => null,
        );
        if (group != null) {
          final gender = group['group_gender'] ?? 'PUTRA';
          if (gender == 'PUTRI') {
            putriExaminers.add(user);
          } else {
            putraExaminers.add(user);
          }
        } else {
          putraExaminers.add(user);
        }
      } else {
        putraExaminers.add(user);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          title: 'Informasi Login Penguji',
          subtitle: 'Aplikasi Ujian Tes Masuk - Al-Hamid',
          date: now,
        ),
        footer: (context) => _buildFooter(context),
        build: (context) {
          final widgets = <pw.Widget>[];

          // Super Users
          if (superUsers.isNotEmpty) {
            widgets.addAll([
              pw.SizedBox(height: 8),
              _sectionTitle('Super User'),
              _buildLoginTable(superUsers, groups),
              pw.SizedBox(height: 20),
            ]);
          }

          // Penguji Putra
          if (putraExaminers.isNotEmpty) {
            widgets.addAll([
              _sectionTitle('Penguji Putra'),
              _buildLoginTable(putraExaminers, groups),
              pw.SizedBox(height: 20),
            ]);
          }

          // Penguji Putri
          if (putriExaminers.isNotEmpty) {
            widgets.addAll([
              _sectionTitle('Penguji Putri'),
              _buildLoginTable(putriExaminers, groups),
            ]);
          }

          if (widgets.isEmpty) {
            widgets.add(
              pw.Center(
                child: pw.Text('Belum ada penguji terdaftar.',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
              ),
            );
          }

          return widgets;
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) => pdf.save(),
      name: 'Info_Login_Penguji.pdf',
    );
  }

  // ============================================================
  // 3. PDF Rekap Penempatan Kelas
  // ============================================================
  static Future<void> generateAndPreviewPlacementsPdf({
    required List<dynamic> groups,
    required List<dynamic> examinees,
  }) async {
    final pdf = pw.Document();
    final now = _formatDate(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          title: 'Rekap Penempatan Kelas',
          subtitle: 'Hasil Ujian Tes Masuk - Al-Hamid',
          date: now,
        ),
        footer: (context) => _buildFooter(context),
        build: (context) {
          final widgets = <pw.Widget>[];

          for (final group in groups) {
            final groupId = group['id'];
            final groupName = group['group_name'] ?? 'Kelompok';
            final groupGender = group['group_gender'] ?? 'PUTRA';

            final groupExaminees = examinees
                .where((e) => e['group_id'] == groupId)
                .toList();

            widgets.addAll([
              _sectionTitle('$groupName ($groupGender)'),
            ]);

            if (groupExaminees.isEmpty) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 16),
                  child: pw.Text(
                    'Tidak ada calon santri di kelompok ini.',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
                  ),
                ),
              );
              continue;
            }

            widgets.addAll([
              pw.Table(
                border: pw.TableBorder.all(color: _borderColor, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FixedColumnWidth(55),
                  4: const pw.FixedColumnWidth(70),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: _headerBg),
                    children: [
                      _headerCell('No'),
                      _headerCell('Nama Lengkap'),
                      _headerCell('No. Daftar'),
                      _headerCell('Jenjang'),
                      _headerCell('Kelas'),
                    ],
                  ),
                  ...groupExaminees.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    final isAlt = i % 2 == 1;
                    return pw.TableRow(
                      decoration: isAlt ? const pw.BoxDecoration(color: _altRowBg) : null,
                      children: [
                        _dataCell('${i + 1}', center: true),
                        _dataCell(e['name'] ?? '-'),
                        _dataCell(e['registration_number'] ?? '-'),
                        _dataCell(e['school'] ?? '-', center: true),
                        _dataCell(e['placement'] ?? 'Belum', center: true),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Total: ${groupExaminees.length} santri | '
                'Sudah dinilai: ${groupExaminees.where((e) => e['placement'] != null).length} | '
                'Belum dinilai: ${groupExaminees.where((e) => e['placement'] == null).length}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 20),
            ]);
          }

          if (widgets.isEmpty) {
            widgets.add(
              pw.Center(
                child: pw.Text('Belum ada data kelompok.',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
              ),
            );
          }

          return widgets;
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) => pdf.save(),
      name: 'Rekap_Penempatan_Kelas.pdf',
    );
  }

  // ============================================================
  // Helper: Build login table for examiners
  // ============================================================
  static pw.Widget _buildLoginTable(List<dynamic> users, List<dynamic> groups) {
    return pw.Table(
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerBg),
          children: [
            _headerCell('No'),
            _headerCell('Username'),
            _headerCell('Password'),
            _headerCell('Kelompok'),
          ],
        ),
        ...users.asMap().entries.map((entry) {
          final i = entry.key;
          final user = entry.value;
          final isAlt = i % 2 == 1;

          // Resolve group name
          String groupInfo = '-';
          final role = user['role'] ?? '';
          if (role == 'SUPER_USER') {
            groupInfo = 'Semua Kelompok';
          } else {
            final assigned = user['assigned_groups'];
            if (assigned is List && assigned.isNotEmpty) {
              groupInfo = assigned.map((g) => g['name'] ?? '').join(', ');
            }
          }

          final plainPassword = user['plain_password'] ?? '********';

          return pw.TableRow(
            decoration: isAlt ? const pw.BoxDecoration(color: _altRowBg) : null,
            children: [
              _dataCell('${i + 1}', center: true),
              _dataCell(user['username'] ?? '-'),
              _dataCell(plainPassword),
              _dataCell(groupInfo),
            ],
          );
        }),
      ],
    );
  }

  // ============================================================
  // Helper: Header, Footer, Cells
  // ============================================================

  static pw.Widget _buildHeader({
    required String title,
    required String subtitle,
    required String date,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  subtitle,
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Pondok Pesantren Al-Hamid',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Dicetak: $date',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: _primaryColor, thickness: 1.5),
        pw.SizedBox(height: 4),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Halaman ${context.pageNumber} dari ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: _primaryColor,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _headerCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: _headerText,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _dataCell(String text, {bool center = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    try {
      return _dateFormatter.format(dt);
    } catch (_) {
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    }
  }
}
