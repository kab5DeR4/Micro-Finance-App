import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import '../database/db_helper.dart';
import '../theme/editorial_theme.dart';

class CollectionScheduleTab extends StatefulWidget {
  const CollectionScheduleTab({super.key});
  @override
  State<CollectionScheduleTab> createState() => _CollectionScheduleTabState();
}

class _CollectionScheduleTabState extends State<CollectionScheduleTab> {
  double _todayTotal = 0.0;
  double _baseCapital = 0.0;
  double _liquidCash = 0.0;
  double _activeDeployed = 0.0;
  double _totalBusinessValue = 0.0;
  double _monthlyInterestProjection = 0.0;

  String _selectedPartner = 'Krushna';
  final TextEditingController _withdrawCtrl = TextEditingController();
  List<Map<String, dynamic>> _recentWithdrawals = [];

  bool _isLoading = true;
  final NumberFormat fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final DateFormat dateFmt = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<Database> _getWithdrawalDb() async {
    return await openDatabase(
      path.join(await getDatabasesPath(), 'bhumi_withdrawals.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE withdrawals(id INTEGER PRIMARY KEY AUTOINCREMENT, partner TEXT, amount REAL, date TEXT)',
        );
      },
      version: 1,
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final todayTotal = await DatabaseHelper.instance.getTodayCollectionTotal();
    final Map<String, dynamic> stats = await DatabaseHelper.instance
        .getDashboardScoreboard();
    final wDb = await _getWithdrawalDb();
    final List<Map<String, dynamic>> wLogs = await wDb.query(
      'withdrawals',
      orderBy: 'date DESC',
    );
    double totalWithdrawals = wLogs.fold(
      0.0,
      (sum, item) => sum + (item['amount'] as num).toDouble(),
    );

    setState(() {
      _todayTotal = todayTotal;
      _recentWithdrawals = wLogs;
      _baseCapital = (stats['base_capital'] as num?)?.toDouble() ?? 0.0;
      _activeDeployed = (stats['active_deployed'] as num?)?.toDouble() ?? 0.0;
      _totalBusinessValue =
          (stats['total_business_value'] as num?)?.toDouble() ?? 0.0;
      _monthlyInterestProjection =
          (stats['monthly_projection'] as num?)?.toDouble() ?? 0.0;
      double rawLiquid = (stats['liquid_cash'] as num?)?.toDouble() ?? 0.0;
      _liquidCash = rawLiquid - totalWithdrawals;
      _isLoading = false;
    });
  }

  Future<void> _processWithdrawal(bool isDark, bool isMobile) async {
    double? amt = double.tryParse(_withdrawCtrl.text);
    if (amt == null || amt <= 0) return;
    if (amt > _liquidCash) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Insufficient Liquid Capital!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String pin = '';
    bool success =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDark || isMobile
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            title: Text(
              "Security Authorization",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: EditorialTheme.fontHeading,
                color: isDark || isMobile
                    ? Colors.white
                    : EditorialTheme.textMain,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Enter PIN for $_selectedPartner to authorize withdrawal of ${fmt.format(amt)}",
                  style: TextStyle(
                    color: isDark || isMobile
                        ? Colors.white70
                        : EditorialTheme.textMain,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => pin = v,
                  style: TextStyle(
                    color: isDark || isMobile ? Colors.white : Colors.black,
                  ),
                  decoration: EditorialTheme.inputTheme('Enter 4-Digit PIN')
                      .copyWith(
                        fillColor: isDark || isMobile
                            ? const Color(0xFF2A2A2A)
                            : Colors.white,
                        filled: true,
                      ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    color: isDark || isMobile
                        ? Colors.white54
                        : EditorialTheme.textDim,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMobile
                      ? const Color(0xFF00E676)
                      : const Color(0xFF4CAF50),
                  foregroundColor: isMobile ? Colors.black : Colors.white,
                ),
                onPressed: () {
                  if (_selectedPartner == 'Krushna' && pin == '1996') {
                    Navigator.pop(ctx, true);
                  } else if (_selectedPartner == 'Sudarshan' && pin == '1995')
                    Navigator.pop(ctx, true);
                  else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Incorrect PIN!",
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    Navigator.pop(ctx, false);
                  }
                },
                child: const Text(
                  "Verify & Withdraw",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (success) {
      final wDb = await _getWithdrawalDb();
      await wDb.insert('withdrawals', {
        'partner': _selectedPartner,
        'amount': amt,
        'date': DateTime.now().toIso8601String(),
      });
      _withdrawCtrl.clear();
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Withdrawal authorized & recorded!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showEditCapitalDialog(bool isDark, bool isMobile) {
    TextEditingController ctrl = TextEditingController(
      text: _baseCapital.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark || isMobile
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        title: Text(
          'Set Initial Capital',
          style: TextStyle(
            fontFamily: EditorialTheme.fontHeading,
            fontWeight: FontWeight.bold,
            color: isDark || isMobile ? Colors.white : EditorialTheme.textMain,
          ),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: TextStyle(
            color: isDark || isMobile ? Colors.white : Colors.black,
          ),
          decoration: EditorialTheme.inputTheme('Amount Injected (₹)').copyWith(
            fillColor: isDark || isMobile
                ? const Color(0xFF2A2A2A)
                : Colors.white,
            filled: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark || isMobile
                    ? Colors.white54
                    : EditorialTheme.textDim,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isMobile
                  ? const Color(0xFF00E676)
                  : const Color(0xFF4CAF50),
              foregroundColor: isMobile ? Colors.black : Colors.white,
            ),
            onPressed: () async {
              double? val = double.tryParse(ctrl.text);
              if (val != null) {
                await DatabaseHelper.instance.updateBaseCapital(val);
                if (mounted) Navigator.pop(ctx);
                _loadData();
              }
            },
            child: const Text(
              'Save Vault',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdfReport() async {
    pw.Font? ttf;
    NumberFormat pdfFmt = fmt;
    try {
      final fontData = await rootBundle.load("assets/fonts/font.ttf");
      ttf = pw.Font.ttf(fontData);
    } catch (e) {
      pdfFmt = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
    }
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        theme: ttf != null ? pw.ThemeData.withFont(base: ttf, bold: ttf) : null,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'BHUMI FINANCE - DAILY REPORT',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 2,
                  color: PdfColors.green900,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Generated on: ${DateFormat('MMMM d, yyyy - hh:mm a').format(DateTime.now())}',
                style: const pw.TextStyle(
                  color: PdfColors.grey700,
                  fontSize: 12,
                ),
              ),
              pw.SizedBox(height: 32),
              pw.Text(
                'VAULT STATUS',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              _buildPdfRow(
                'Liquid Capital Available',
                pdfFmt.format(_liquidCash),
              ),
              _buildPdfRow('Base Capital', pdfFmt.format(_baseCapital)),
              pw.SizedBox(height: 24),
              pw.Text(
                'BUSINESS OVERVIEW',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              _buildPdfRow(
                'Total Business Value',
                pdfFmt.format(_totalBusinessValue),
              ),
              _buildPdfRow(
                'Active Deployed Capital',
                pdfFmt.format(_activeDeployed),
              ),
              _buildPdfRow(
                'Today\'s Secured Yield',
                pdfFmt.format(_todayTotal),
              ),
              _buildPdfRow(
                '30-Day Yield Projection',
                pdfFmt.format(_monthlyInterestProjection),
              ),
              pw.SizedBox(height: 32),
              if (_recentWithdrawals.isNotEmpty) ...[
                pw.Text(
                  'WITHDRAWAL & EXPENSE LOG',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                for (var w in _recentWithdrawals)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          "${w['partner']} (Withdrawal)",
                          style: pw.TextStyle(color: PdfColors.red800),
                        ),
                        pw.Text(
                          "- ${pdfFmt.format(w['amount'])}",
                          style: pw.TextStyle(
                            color: PdfColors.red800,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name:
          'Bhumi_Report_${DateFormat('yyyy_MM_dd').format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 14)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MOBILE SPECIFIC UI WIDGETS
  // ==========================================
  Widget _buildMobileDashboard() {
    return ListView(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 40,
        bottom: 120,
      ), // Padding for the floating pill nav
      children: [
        // Top Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(DateTime.now()),
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF00E676)),
              onPressed: _exportPdfReport,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Beautiful Gradient Wallet Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF203A43)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E676).withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF00E676).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "LIQUID BALANCE",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showEditCapitalDialog(true, true),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  fmt.format(_liquidCash),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "BASE CAPITAL",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fmt.format(_baseCapital),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${(_liquidCash / 10000).floor()} Units Ready",
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Neo-Bank 2x2 Grid Stats
        const Text(
          'Business Overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _mobileStatCard(
                Icons.trending_up_rounded,
                "Secured Yield",
                _todayTotal,
                true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _mobileStatCard(
                Icons.star_rounded,
                "30-Day Proj.",
                _monthlyInterestProjection,
                false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _mobileStatCard(
                Icons.pie_chart_rounded,
                "Total Value",
                _totalBusinessValue,
                false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _mobileStatCard(
                Icons.rocket_launch_rounded,
                "Active Deployed",
                _activeDeployed,
                false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Modern Mobile Withdrawal Form
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Color(0xFF00E676),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Partner Withdrawal",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: _selectedPartner,
                dropdownColor: const Color(0xFF2A2A2A),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black45,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                items: ['Krushna', 'Sudarshan']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPartner = v!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _withdrawCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '₹0.00',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black45,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _processWithdrawal(true, true),
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text(
                    "Authorize",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mobileStatCard(
    IconData icon,
    String title,
    double amount,
    bool highlight,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF00E676).withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? const Color(0xFF00E676).withOpacity(0.3)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: highlight ? const Color(0xFF00E676) : Colors.white54,
            size: 24,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              fmt.format(amount),
              style: TextStyle(
                color: highlight ? const Color(0xFF00E676) : Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DESKTOP SPECIFIC UI WIDGETS (Untouched)
  // ==========================================
  Widget _buildDesktopDashboard(bool isDark) {
    int fullCards = (_liquidCash / 10000).floor();
    double cardProgress = (_liquidCash % 10000) / 10000.0;

    Widget heroCard = Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : EditorialTheme.accentDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.6 : 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    "LIQUID CAPITAL AVAILABLE",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_note,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () => _showEditCapitalDialog(isDark, false),
              ),
            ],
          ),
          Text(
            fmt.format(_liquidCash),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -2,
            ),
          ),
          Text(
            "Derived from base capital of ${fmt.format(_baseCapital)}",
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "DEPLOYMENT UNITS AVAILABLE",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "1 Unit = ₹10K",
                      style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (
                          int i = 0;
                          i < (fullCards > 10 ? 10 : fullCards);
                          i++
                        )
                          Container(
                            width: 44,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF81C784), Color(0xFF388E3C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.eco,
                                color: Colors.white70,
                                size: 24,
                              ),
                            ),
                          ),
                        if (fullCards > 10)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              "...",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (cardProgress > 0 || fullCards == 0)
                          Container(
                            width: 44,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white24,
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: cardProgress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4CAF50,
                                  ).withOpacity(0.7),
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      fullCards > 0
                          ? "$fullCards unit(s) of liquid capital are fully funded."
                          : "Collect ₹${fmt.format(10000 - (_liquidCash % 10000))} more to unlock your first unit.",
                      style: const TextStyle(
                        color: Colors.white60,
                        height: 1.5,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget scoreBoardDesktop = Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _pcScoreCard(
                "TOTAL BUSINESS VALUE",
                _totalBusinessValue,
                isDark,
                false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _pcScoreCard(
                "ACTIVE DEPLOYED CAPITAL",
                _activeDeployed,
                isDark,
                false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _pcScoreCard(
                "TODAY'S SECURED YIELD",
                _todayTotal,
                isDark,
                false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _pcScoreCard(
                "30-DAY YIELD PROJECTION",
                _monthlyInterestProjection,
                isDark,
                false,
                isHighlight: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : EditorialTheme.border,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "PARTNER WITHDRAWALS & EXPENSES",
                style: TextStyle(
                  color: isDark ? Colors.white54 : EditorialTheme.textDim,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedPartner,
                      dropdownColor: isDark
                          ? const Color(0xFF2A2A2A)
                          : Colors.white,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 16,
                      ),
                      decoration: EditorialTheme.inputTheme('Select Partner')
                          .copyWith(
                            fillColor: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                          ),
                      items: ['Krushna', 'Sudarshan']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedPartner = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _withdrawCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: EditorialTheme.inputTheme('Amount (₹)')
                          .copyWith(
                            fillColor: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                  onPressed: () => _processWithdrawal(isDark, false),
                  child: const Text(
                    "Authorize & Withdraw",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning.',
                  style: TextStyle(
                    fontFamily: EditorialTheme.fontHeading,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : EditorialTheme.textMain,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : EditorialTheme.textDim,
                  ),
                ),
              ],
            ),
            OutlinedButton.icon(
              icon: Icon(
                Icons.download,
                size: 18,
                color: isDark ? Colors.white : EditorialTheme.textMain,
              ),
              label: Text(
                "Export PDF",
                style: TextStyle(
                  color: isDark ? Colors.white : EditorialTheme.textMain,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isDark ? Colors.white30 : EditorialTheme.border,
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _exportPdfReport,
            ),
          ],
        ),
        const SizedBox(height: 48),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: heroCard),
            const SizedBox(width: 32),
            Expanded(flex: 5, child: scoreBoardDesktop),
          ],
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _pcScoreCard(
    String title,
    double amount,
    bool isDark,
    bool isMobile, {
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isHighlight
            ? (isDark
                  ? const Color(0xFF1B5E20).withOpacity(0.3)
                  : const Color(0xFFE8F5E9))
            : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlight
              ? const Color(0xFF4CAF50).withOpacity(0.5)
              : (isDark ? Colors.white12 : EditorialTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white54 : EditorialTheme.textDim,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fmt.format(amount),
            style: TextStyle(
              color: isHighlight
                  ? const Color(0xFF4CAF50)
                  : (isDark ? Colors.white : EditorialTheme.textMain),
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile =
        MediaQuery.of(context).size.width <
        800; // The threshold for switching UIs
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // On mobile, the background is forced Dark to match the neo-bank look, on PC it respects the theme.
      backgroundColor: isMobile
          ? const Color(0xFF121212)
          : Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                )
              : (isMobile
                    ? _buildMobileDashboard()
                    : _buildDesktopDashboard(isDark)), // Dynamic Injection!
        ),
      ),
    );
  }
}
