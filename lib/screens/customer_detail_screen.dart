import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database/db_helper.dart';
import '../theme/editorial_theme.dart';

class CustomerDetailScreen extends StatefulWidget {
  final int loanId;
  const CustomerDetailScreen({super.key, required this.loanId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _heatmap = [];

  final NumberFormat fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final DateFormat dateFmt = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await DatabaseHelper.instance.getCustomerProfile(
      widget.loanId,
    );
    final history = await DatabaseHelper.instance.getCustomerCollections(
      widget.loanId,
    );
    final heatmap = await DatabaseHelper.instance.getPaymentHeatmap(
      widget.loanId,
    );
    setState(() {
      _profile = profile;
      _history = history;
      _heatmap = heatmap;
    });
  }

  List<Map<String, dynamic>> _getCombinedLog(double dailyAmt) {
    List<Map<String, dynamic>> combined = [];
    for (var h in _history) {
      double amt = (h['amount_paid'] as num).toDouble();
      combined.add({
        'date': DateTime.parse(h['collection_date']),
        'type': 'PAID',
        'amount': amt,
        'hasFine': amt > dailyAmt,
      });
    }
    for (var day in _heatmap) {
      if (day['status'] == 'missed') {
        combined.add({
          'date': day['date'],
          'type': 'MISSED',
          'amount': 0.0,
          'hasFine': false,
        });
      }
    }
    combined.sort((a, b) => b['date'].compareTo(a['date']));
    return combined;
  }

  Future<bool> _confirmPayment(
    double amount,
    DateTime date,
    bool isDark,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDark
                ? const Color(0xFF1E1E1E)
                : EditorialTheme.surface,
            title: Text(
              "Confirm Settlement",
              style: TextStyle(
                fontFamily: EditorialTheme.fontHeading,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : EditorialTheme.textMain,
              ),
            ),
            content: Text(
              "Process payment of ${fmt.format(amount)} for ${dateFmt.format(date)}?",
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : EditorialTheme.textDim,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Confirm Settlement',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _exportCustomerStatement() async {
    if (_profile == null) return;
    pw.Font? ttf;
    NumberFormat pdfFmt = fmt;
    try {
      final fontData = await rootBundle.load("assets/fonts/font.ttf");
      ttf = pw.Font.ttf(fontData);
    } catch (e) {
      pdfFmt = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
    }

    final double dailyAmt = (_profile!['daily_installment'] as num).toDouble();
    final double remBalance = (_profile!['balance_remaining'] as num)
        .toDouble();
    final double totalPayable = (_profile!['total_payable'] as num).toDouble();
    final double totalPaid = totalPayable - remBalance;
    final String customerName = _profile!['name'];
    final List<Map<String, dynamic>> combinedLog = _getCombinedLog(dailyAmt);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        theme: ttf != null ? pw.ThemeData.withFont(base: ttf, bold: ttf) : null,
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BHUMI FINANCE',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'STATEMENT OF ACCOUNT',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'GENERATED ON',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      DateFormat('dd MMM yyyy').format(DateTime.now()),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 32),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CLIENT NAME',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        customerName,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _profile!['phone'] ?? 'N/A',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'MATURITY DATE',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        dateFmt.format(
                          DateTime.parse(_profile!['expected_end_date']),
                        ),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 32),
            pw.Text(
              'FINANCIAL SUMMARY',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPdfStat('Total Payable', pdfFmt.format(totalPayable)),
                _buildPdfStat('Total Collected', pdfFmt.format(totalPaid)),
                _buildPdfStat(
                  'Balance Due',
                  pdfFmt.format(remBalance),
                  isHighlight: true,
                ),
              ],
            ),
            pw.SizedBox(height: 40),
            pw.Text(
              'TRANSACTION LOG',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            if (combinedLog.isEmpty)
              pw.Text(
                'No payments or missed days recorded yet.',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey600,
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'DATE',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'DESCRIPTION',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'AMOUNT',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  for (var log in combinedLog)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            dateFmt.format(log['date']),
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            log['type'] == 'MISSED'
                                ? 'Payment Missed'
                                : (log['hasFine']
                                      ? 'Overdue Settled (+Fine)'
                                      : 'Payment Received'),
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: log['type'] == 'MISSED'
                                  ? PdfColors.red800
                                  : (log['hasFine']
                                        ? PdfColors.orange800
                                        : PdfColors.black),
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            log['type'] == 'MISSED'
                                ? '--'
                                : pdfFmt.format(log['amount']),
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: log['type'] == 'MISSED'
                                  ? PdfColors.red800
                                  : (log['hasFine']
                                        ? PdfColors.orange800
                                        : PdfColors.black),
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
          ];
        },
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Statement_${customerName.replaceAll(' ', '_')}.pdf',
    );
  }

  pw.Widget _buildPdfStat(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: isHighlight ? PdfColors.red800 : PdfColors.black,
          ),
        ),
      ],
    );
  }

  void _showPaymentSheet(bool isDark, {DateTime? initialDate}) {
    DateTime selectedDate = initialDate ?? DateTime.now();
    final amtCtrl = TextEditingController(
      text: _profile!['daily_installment'].toString(),
    );
    final fineCtrl = TextEditingController(text: '0');

    InputDecoration dynamicInput(String label) {
      return EditorialTheme.inputTheme(label).copyWith(
        fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.transparent,
        labelStyle: TextStyle(
          color: isDark ? Colors.white54 : EditorialTheme.textDim,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : EditorialTheme.border,
            width: 1.5,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF81C784) : EditorialTheme.textMain,
            width: 2,
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark
          ? const Color(0xFF1E1E1E)
          : EditorialTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          double baseAmt = double.tryParse(amtCtrl.text) ?? 0.0;
          double fineAmt = double.tryParse(fineCtrl.text) ?? 0.0;
          double totalSettlement = baseAmt + fineAmt;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Record Extraction',
                  style: TextStyle(
                    fontFamily: EditorialTheme.fontHeading,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : EditorialTheme.textMain,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: dynamicInput('Base Installment Amount (₹)'),
                  onChanged: (val) => setSheetState(() {}),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: fineCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: dynamicInput('Late Fine / Penalty (₹)'),
                  onChanged: (val) => setSheetState(() {}),
                ),
                const SizedBox(height: 24),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: isDark
                                ? const ColorScheme.dark(
                                    primary: Color(0xFF4CAF50),
                                    onPrimary: Colors.white,
                                    surface: Color(0xFF1E1E1E),
                                    onSurface: Colors.white,
                                  )
                                : const ColorScheme.light(
                                    primary: Color(0xFF2E7D32),
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setSheetState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.white24
                              : EditorialTheme.border,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Extraction Date",
                          style: TextStyle(
                            color: isDark
                                ? Colors.white54
                                : EditorialTheme.textDim,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          dateFmt.format(selectedDate),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1B5E20).withOpacity(0.3)
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total Settlement:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                      Text(
                        fmt.format(totalSettlement),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                  onPressed: () async {
                    if (totalSettlement > 0) {
                      bool confirm = await _confirmPayment(
                        totalSettlement,
                        selectedDate,
                        isDark,
                      );
                      if (confirm) {
                        Navigator.pop(ctx);
                        await DatabaseHelper.instance.recordDailyCollection(
                          widget.loanId,
                          totalSettlement,
                          collectionDate: selectedDate,
                        );
                        _loadData();
                      }
                    }
                  },
                  child: const Text(
                    'Confirm Settle',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _legendItem(
    String label,
    Color color,
    bool isDark, {
    Color? borderColor,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: borderColor != null ? Border.all(color: borderColor) : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : EditorialTheme.textMain,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
        ),
      );
    }

    bool isMobile = MediaQuery.of(context).size.width < 600;
    bool isDesktop = MediaQuery.of(context).size.width > 900;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    final double dailyAmt = (_profile!['daily_installment'] as num).toDouble();
    final double remBalance = (_profile!['balance_remaining'] as num)
        .toDouble();
    final DateTime startDate = DateTime.parse(
      _profile!['installment_start_date'],
    );
    final double totalPayable = (_profile!['total_payable'] as num).toDouble();

    final DateTime nextDueDate = startDate.add(
      Duration(days: ((totalPayable - remBalance) / dailyAmt).floor()),
    );
    final int totalDays = _heatmap.length;
    final int paidDays = _heatmap
        .where((day) => day['status'] == 'paid')
        .length;
    final int missedDays = _heatmap
        .where((day) => day['status'] == 'missed')
        .length;
    final List<Map<String, dynamic>> combinedLog = _getCombinedLog(dailyAmt);

    List<Widget> futurePaymentsList = [];
    double tempBal = remBalance;
    int projectionCount = (remBalance / dailyAmt).ceil() > 3
        ? 3
        : (remBalance / dailyAmt).ceil();
    for (int i = 0; i < projectionCount; i++) {
      double amt = (tempBal >= dailyAmt) ? dailyAmt : tempBal;
      DateTime date = nextDueDate.add(Duration(days: i));
      futurePaymentsList.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateFmt.format(date),
                style: TextStyle(
                  color: isDark ? Colors.white54 : EditorialTheme.textDim,
                  fontSize: 14,
                ),
              ),
              Text(
                fmt.format(amt),
                style: TextStyle(
                  color: isDark ? Colors.white : EditorialTheme.textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
      tempBal -= amt;
    }

    Widget liabilityCard = Container(
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : EditorialTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : EditorialTheme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.02),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OUTSTANDING LIABILITY',
            style: TextStyle(
              color: isDark ? Colors.white54 : EditorialTheme.textDim,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fmt.format(remBalance),
            style: TextStyle(
              fontSize: isMobile ? 36 : 44,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : EditorialTheme.textMain,
              letterSpacing: -1,
            ),
          ),
          Divider(
            height: 48,
            color: isDark ? Colors.white12 : EditorialTheme.border,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Principal',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : EditorialTheme.textDim,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fmt.format(_profile!['principal_amount']),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Maturity',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : EditorialTheme.textDim,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFmt.format(
                      DateTime.parse(_profile!['expected_end_date']),
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
              ),
              onPressed: () => _showPaymentSheet(isDark),
              child: const Text(
                'Process Payment',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );

    Widget timelineCard = Container(
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : EditorialTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : EditorialTheme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.02),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTRACT TIMELINE & LEDGER',
            style: TextStyle(
              color: isDark ? Colors.white54 : EditorialTheme.textDim,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                "$totalDays Days",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              const Text(
                "Paid: ",
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                "$paidDays",
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Missed: ",
                style: TextStyle(
                  color: isDark ? Colors.redAccent : EditorialTheme.danger,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                "$missedDays",
                style: TextStyle(
                  color: isDark ? Colors.redAccent : EditorialTheme.danger,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: isMobile ? 6 : 8,
            runSpacing: isMobile ? 6 : 8,
            children: [
              for (var day in _heatmap)
                Tooltip(
                  message:
                      "${dateFmt.format(day['date'])}\nStatus: ${day['status']}",
                  child: InkWell(
                    onTap: (day['status'] == 'missed' || day['status'] == 'due')
                        ? () => _showPaymentSheet(
                            isDark,
                            initialDate: day['date'],
                          )
                        : null,
                    child: Container(
                      width: isMobile ? 18 : 22,
                      height: isMobile ? 18 : 22,
                      decoration: BoxDecoration(
                        color: day['status'] == 'paid'
                            ? const Color(0xFF4CAF50)
                            : (day['status'] == 'missed'
                                  ? (isDark
                                        ? Colors.redAccent.withOpacity(0.2)
                                        : EditorialTheme.danger.withOpacity(
                                            0.15,
                                          ))
                                  : (day['status'] == 'due'
                                        ? (isDark
                                              ? Colors.orange.withOpacity(0.2)
                                              : Colors.orange.shade100)
                                        : Colors.transparent)),
                        border: Border.all(
                          color: day['status'] == 'future'
                              ? (isDark
                                    ? Colors.white24
                                    : EditorialTheme.border)
                              : (day['status'] == 'paid'
                                    ? const Color(0xFF4CAF50)
                                    : (day['status'] == 'missed'
                                          ? (isDark
                                                ? Colors.redAccent
                                                : EditorialTheme.danger
                                                      .withOpacity(0.6))
                                          : Colors.orange.shade700)),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(
            height: 1,
            color: isDark ? Colors.white12 : EditorialTheme.border,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _legendItem("Paid", const Color(0xFF4CAF50), isDark),
              _legendItem(
                "Missed",
                isDark
                    ? Colors.redAccent.withOpacity(0.2)
                    : EditorialTheme.danger.withOpacity(0.15),
                isDark,
                borderColor: isDark
                    ? Colors.redAccent
                    : EditorialTheme.danger.withOpacity(0.6),
              ),
              _legendItem(
                "Due",
                isDark
                    ? Colors.orange.withOpacity(0.2)
                    : Colors.orange.shade100,
                isDark,
                borderColor: Colors.orange.shade700,
              ),
            ],
          ),
        ],
      ),
    );

    Widget transactionCard = Container(
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : EditorialTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : EditorialTheme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.02),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRANSACTION LOG',
            style: TextStyle(
              color: isDark ? Colors.white54 : EditorialTheme.textDim,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          if (combinedLog.isEmpty)
            Text(
              "No records found.",
              style: TextStyle(
                color: isDark ? Colors.white54 : EditorialTheme.textDim,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            for (var log in combinedLog)
              Builder(
                builder: (context) {
                  String desc = log['type'] == 'MISSED'
                      ? 'Missed'
                      : (log['hasFine'] ? 'Settled(+Fine)' : 'Received');
                  Color descColor = log['type'] == 'MISSED'
                      ? (isDark ? Colors.redAccent : EditorialTheme.danger)
                      : (log['hasFine']
                            ? Colors.orange
                            : (isDark
                                  ? Colors.white
                                  : EditorialTheme.textMain));
                  Color amtColor = log['type'] == 'MISSED'
                      ? (isDark ? Colors.redAccent : EditorialTheme.danger)
                      : (log['hasFine']
                            ? Colors.orange
                            : const Color(0xFF4CAF50));

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            DateFormat('MMM dd').format(log['date']),
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white54
                                  : EditorialTheme.textDim,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  desc,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: descColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (log['hasFine'])
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    size: 14,
                                    color: Colors.orange,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            log['type'] == 'MISSED'
                                ? '--'
                                : '+${fmt.format(log['amount'])}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: amtColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ],
      ),
    );

    Widget projectionCard = Container(
      padding: EdgeInsets.all(isMobile ? 24 : 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : EditorialTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : EditorialTheme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.02),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UPCOMING PROJECTION',
            style: TextStyle(
              color: isDark ? Colors.white54 : EditorialTheme.textDim,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          for (var w in futurePaymentsList) w,
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : EditorialTheme.textMain,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              icon: Icon(
                Icons.description_outlined,
                size: 16,
                color: isDark ? Colors.white : EditorialTheme.textMain,
              ),
              label: Text(
                "Export",
                style: TextStyle(
                  color: isDark ? Colors.white : EditorialTheme.textMain,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isDark ? Colors.white24 : EditorialTheme.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: _exportCustomerStatement,
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 32,
              vertical: isMobile ? 16 : 32,
            ),
            children: [
              Text(
                _profile!['name'],
                style: TextStyle(
                  fontSize: isMobile ? 32 : 40,
                  fontWeight: FontWeight.bold,
                  fontFamily: EditorialTheme.fontHeading,
                  color: isDark ? Colors.white : EditorialTheme.textMain,
                ),
              ),
              const SizedBox(height: 32),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: liabilityCard),
                    const SizedBox(width: 32),
                    Expanded(flex: 6, child: timelineCard),
                  ],
                )
              else
                Column(
                  children: [
                    liabilityCard,
                    const SizedBox(height: 16),
                    timelineCard,
                  ],
                ),
              const SizedBox(height: 16),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: transactionCard),
                    const SizedBox(width: 32),
                    Expanded(flex: 4, child: projectionCard),
                  ],
                )
              else
                Column(
                  children: [
                    transactionCard,
                    const SizedBox(height: 16),
                    projectionCard,
                  ],
                ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
