import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../theme/editorial_theme.dart';
import 'customer_detail_screen.dart';

class RegistryTab extends StatefulWidget {
  const RegistryTab({super.key});
  @override
  State<RegistryTab> createState() => _RegistryTabState();
}

class _RegistryTabState extends State<RegistryTab> {
  List<Map<String, dynamic>> _data = [];
  final NumberFormat fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await DatabaseHelper.instance.getAllActiveLoans();
    setState(() => _data = data);
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;
    bool isDark =
        Theme.of(context).brightness == Brightness.dark; // Theme check

    return Scaffold(
      backgroundColor: Theme.of(
        context,
      ).scaffoldBackgroundColor, // Syncs with theme
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(
                'Portfolio',
                style: TextStyle(
                  fontFamily: EditorialTheme.fontHeading,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : EditorialTheme.textMain,
                ),
              ),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop)
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
                  child: Text(
                    'Active Portfolios',
                    style: TextStyle(
                      fontFamily: EditorialTheme.fontHeading,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : EditorialTheme.textMain,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  itemCount: _data.length,
                  itemBuilder: (context, index) {
                    final item = _data[index];

                    return CleanFadeIn(
                      index: index,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : EditorialTheme.surface, // Dynamic card color
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white12
                                : EditorialTheme.border,
                          ), // Dynamic border
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CustomerDetailScreen(loanId: item['loan_id']),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['customer_name'],
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : EditorialTheme.textMain,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons
                                                .account_balance_wallet_outlined,
                                            size: 14,
                                            color: isDark
                                                ? Colors.white54
                                                : EditorialTheme.textDim,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Liability: ${fmt.format(item['balance_remaining'])}',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white70
                                                  : EditorialTheme.textDim,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward,
                                  size: 20,
                                  color: isDark
                                      ? Colors.white54
                                      : EditorialTheme.textDim,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
