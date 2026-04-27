import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import '../database/db_helper.dart';
import '../theme/editorial_theme.dart';

class PendingCollectionsTab extends StatefulWidget {
  const PendingCollectionsTab({super.key});
  @override
  State<PendingCollectionsTab> createState() => _PendingCollectionsTabState();
}

class _PendingCollectionsTabState extends State<PendingCollectionsTab> {
  List<Map<String, dynamic>> _data = [];
  List<Map<String, dynamic>> _withdrawalLogs = [];
  bool _isLoading = true;

  final NumberFormat fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final DateFormat dateFmt = DateFormat('MMM dd, yyyy • hh:mm a');

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

    final data = await DatabaseHelper.instance.getPendingCollectionsForToday();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    List<Map<String, dynamic>> augmentedData = [];

    for (var item in data) {
      final history = await DatabaseHelper.instance.getCustomerCollections(
        item['loan_id'],
      );
      bool alreadyPaidToday = history.any(
        (h) => h['collection_date'].toString().startsWith(todayStr),
      );

      var mutableItem = Map<String, dynamic>.from(item);
      mutableItem['paid_today'] = alreadyPaidToday;
      augmentedData.add(mutableItem);
    }

    List<Map<String, dynamic>> wLogs = [];
    try {
      final wDb = await _getWithdrawalDb();
      wLogs = await wDb.query('withdrawals', orderBy: 'date DESC');
    } catch (e) {
      debugPrint("No withdrawal database found yet.");
    }

    setState(() {
      _data = augmentedData;
      _withdrawalLogs = wLogs;
      _isLoading = false;
    });
  }

  Future<bool> _confirmExtraction(String name, double amount) async {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDark
                ? const Color(0xFF1E1E1E)
                : EditorialTheme.surface,
            title: Text(
              "Confirm Extraction",
              style: TextStyle(
                fontFamily: EditorialTheme.fontHeading,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : EditorialTheme.textMain,
              ),
            ),
            content: Text(
              "Are you sure you want to record ${fmt.format(amount)} from $name?",
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
                  'Confirm Extraction',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 32,
              vertical: isMobile ? 24 : 48,
            ), // Mobile padding fix
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending Collections',
                  style: TextStyle(
                    fontFamily: EditorialTheme.fontHeading,
                    fontSize: isMobile ? 28 : 36,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : EditorialTheme.textMain,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Action required for today\'s scheduled payments.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : EditorialTheme.textDim,
                  ),
                ),
                const SizedBox(height: 24),

                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4CAF50),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_data.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 40,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 64,
                                          color: isDark
                                              ? const Color(0xFF81C784)
                                              : Colors.green.shade300,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          "You're all caught up for today.",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                        Text(
                                          "No actions required.",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white54
                                                : EditorialTheme.textDim,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _data.length,
                                  itemBuilder: (context, index) {
                                    final item = _data[index];
                                    int daysRemaining = item['days_remaining'];
                                    bool paidToday =
                                        item['paid_today'] ?? false;

                                    String statusText;
                                    Color accentColor;

                                    if (paidToday) {
                                      statusText = "Recorded today";
                                      accentColor = isDark
                                          ? const Color(0xFF81C784)
                                          : const Color(0xFF2E7D32);
                                    } else {
                                      statusText = daysRemaining < 0
                                          ? "${daysRemaining.abs()} days overdue"
                                          : daysRemaining == 0
                                          ? "Due today"
                                          : "Due in $daysRemaining days";
                                      accentColor = daysRemaining < 0
                                          ? (isDark
                                                ? Colors.redAccent
                                                : EditorialTheme.danger)
                                          : (isDark
                                                ? Colors.white54
                                                : EditorialTheme.textDim);
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: EdgeInsets.all(
                                        isMobile ? 16 : 24,
                                      ), // Dynamic padding
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1E1E1E)
                                            : EditorialTheme.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: paidToday
                                              ? const Color(
                                                  0xFF4CAF50,
                                                ).withOpacity(0.3)
                                              : (isDark
                                                    ? Colors.white12
                                                    : EditorialTheme.border),
                                          width: paidToday ? 1.5 : 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              isDark ? 0.3 : 0.02,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['customer_name'],
                                                  style: TextStyle(
                                                    fontSize:
                                                        16, // Slightly smaller on mobile to prevent wrapping
                                                    fontWeight: FontWeight.w600,
                                                    color: paidToday
                                                        ? (isDark
                                                              ? Colors.white38
                                                              : EditorialTheme
                                                                    .textDim)
                                                        : (isDark
                                                              ? Colors.white
                                                              : EditorialTheme
                                                                    .textMain),
                                                    decoration: paidToday
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  statusText,
                                                  style: TextStyle(
                                                    color: accentColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                fmt.format(
                                                  item['daily_installment'],
                                                ),
                                                style: TextStyle(
                                                  fontSize: isMobile ? 16 : 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: paidToday
                                                      ? (isDark
                                                            ? Colors.white38
                                                            : EditorialTheme
                                                                  .textDim)
                                                      : (isDark
                                                            ? Colors.white
                                                            : EditorialTheme
                                                                  .textMain),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                height: 32,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                        ),
                                                    backgroundColor: paidToday
                                                        ? (isDark
                                                              ? const Color(
                                                                  0xFF2A2A2A,
                                                                )
                                                              : Colors
                                                                    .grey
                                                                    .shade200)
                                                        : const Color(
                                                            0xFF2E7D32,
                                                          ),
                                                    foregroundColor: paidToday
                                                        ? (isDark
                                                              ? Colors.white38
                                                              : Colors
                                                                    .grey
                                                                    .shade600)
                                                        : Colors.white,
                                                    elevation: paidToday
                                                        ? 0
                                                        : 2,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                  ),
                                                  onPressed: paidToday
                                                      ? () {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                "Already recorded today! Check Contract Timeline for overdue.",
                                                              ),
                                                              backgroundColor:
                                                                  Colors.orange,
                                                              duration:
                                                                  Duration(
                                                                    seconds: 4,
                                                                  ),
                                                            ),
                                                          );
                                                        }
                                                      : () async {
                                                          bool
                                                          confirm = await _confirmExtraction(
                                                            item['customer_name'],
                                                            (item['daily_installment']
                                                                    as num)
                                                                .toDouble(),
                                                          );
                                                          if (confirm) {
                                                            await DatabaseHelper
                                                                .instance
                                                                .recordDailyCollection(
                                                                  item['loan_id'],
                                                                  (item['daily_installment']
                                                                          as num)
                                                                      .toDouble(),
                                                                );
                                                            _loadData();
                                                          }
                                                        },
                                                  child: Text(
                                                    paidToday
                                                        ? 'Paid'
                                                        : 'Extract',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                              const SizedBox(height: 48),

                              Text(
                                'Partner Withdrawals Log',
                                style: TextStyle(
                                  fontFamily: EditorialTheme.fontHeading,
                                  fontSize: isMobile ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : EditorialTheme.textMain,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'History of business expenses and withdrawals.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white70
                                      : EditorialTheme.textDim,
                                ),
                              ),
                              const SizedBox(height: 16),

                              if (_withdrawalLogs.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white12
                                          : EditorialTheme.border,
                                    ),
                                  ),
                                  child: Text(
                                    "No internal withdrawals recorded yet.",
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: isDark
                                          ? Colors.white54
                                          : EditorialTheme.textDim,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _withdrawalLogs.length,
                                  itemBuilder: (context, index) {
                                    final w = _withdrawalLogs[index];
                                    final date = DateTime.parse(w['date']);

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1E1E1E)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white12
                                              : EditorialTheme.border,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor: isDark
                                                    ? const Color(
                                                        0xFF4CAF50,
                                                      ).withOpacity(0.1)
                                                    : const Color(0xFFE8F5E9),
                                                child: Icon(
                                                  Icons.person,
                                                  size: 18,
                                                  color: isDark
                                                      ? const Color(0xFF81C784)
                                                      : const Color(0xFF2E7D32),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    w['partner'],
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: isDark
                                                          ? Colors.white
                                                          : Colors.black,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    dateFmt.format(date),
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? Colors.white54
                                                          : EditorialTheme
                                                                .textDim,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Text(
                                            "- ${fmt.format(w['amount'])}",
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.redAccent
                                                  : EditorialTheme.danger,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                              const SizedBox(height: 80),
                            ],
                          ),
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
