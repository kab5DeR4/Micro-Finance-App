import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../theme/editorial_theme.dart';

class AddLoanScreen extends StatefulWidget {
  const AddLoanScreen({super.key});
  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  final _principalController = TextEditingController();
  final _interestController = TextEditingController();
  final _durationController = TextEditingController();

  DateTime _startDate = DateTime.now();

  double _calculatedTotal = 0;
  double _calculatedDaily = 0;

  @override
  void initState() {
    super.initState();
    _principalController.addListener(_calculateTotals);
    _interestController.addListener(_calculateTotals);
    _durationController.addListener(_calculateTotals);
  }

  void _calculateTotals() {
    double p = double.tryParse(_principalController.text) ?? 0;
    double i = double.tryParse(_interestController.text) ?? 0;
    int d = int.tryParse(_durationController.text) ?? 0;

    if (p > 0 && d > 0) {
      double totalInterest = p * (i / 100) * (d / 30.0);
      double total = p + totalInterest;
      double daily = total / d;

      setState(() {
        _calculatedTotal = total;
        _calculatedDaily = daily;
      });
    } else {
      setState(() {
        _calculatedTotal = 0;
        _calculatedDaily = 0;
      });
    }
  }

  Future<void> _saveData() async {
    if (_formKey.currentState!.validate() &&
        _calculatedTotal > 0 &&
        _calculatedDaily > 0) {
      await DatabaseHelper.instance.addCustomerAndLoan(
        name: _nameController.text,
        phone: _phoneController.text,
        address: '',
        startDate: _startDate,
        principal: double.parse(_principalController.text),
        totalPayable: _calculatedTotal,
        dailyInstallment: _calculatedDaily,
        durationDays: int.parse(_durationController.text),
      );
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isMobile = MediaQuery.of(context).size.width < 600; // Mobile detection

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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDark ? Colors.white : EditorialTheme.textMain,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 32,
              vertical: isMobile ? 16 : 24,
            ), // Dynamic padding
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CleanFadeIn(
                    index: 0,
                    child: Text(
                      "Initialize Portfolio",
                      style: TextStyle(
                        fontFamily: EditorialTheme.fontHeading,
                        fontSize: isMobile ? 28 : 36,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : EditorialTheme.textMain,
                        letterSpacing: -1,
                      ), // Dynamic font size
                    ),
                  ),
                  SizedBox(height: isMobile ? 24 : 40), // Dynamic spacing

                  Container(
                    padding: EdgeInsets.all(
                      isMobile ? 24 : 40,
                    ), // Dynamic container padding
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E1E)
                          : EditorialTheme.surface,
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
                        CleanFadeIn(
                          index: 1,
                          child: TextFormField(
                            controller: _nameController,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: dynamicInput('Client Name'),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                        SizedBox(height: isMobile ? 24 : 32),
                        CleanFadeIn(
                          index: 2,
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: dynamicInput('Contact Number'),
                          ),
                        ),

                        SizedBox(height: isMobile ? 32 : 48),

                        CleanFadeIn(
                          index: 3,
                          child: GestureDetector(
                            onTap: () async {
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
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
                                setState(() => _startDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: isDark
                                        ? Colors.white24
                                        : EditorialTheme.border,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Commencement Date",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white54
                                          : EditorialTheme.textDim,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(_startDate),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : EditorialTheme.textMain,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ), // Shortened date format for mobile
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isMobile ? 24 : 32),
                        CleanFadeIn(
                          index: 4,
                          child: TextFormField(
                            controller: _principalController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: dynamicInput('Principal Capital (₹)'),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                        SizedBox(height: isMobile ? 24 : 32),
                        CleanFadeIn(
                          index: 5,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _interestController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  decoration: dynamicInput(
                                    'Monthly Interest (%)',
                                  ),
                                  validator: (v) =>
                                      v!.isEmpty ? 'Required' : null,
                                ),
                              ),
                              SizedBox(
                                width: isMobile ? 16 : 32,
                              ), // Tighter spacing between fields
                              Expanded(
                                child: TextFormField(
                                  controller: _durationController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  decoration: dynamicInput('Duration (Days)'),
                                  validator: (v) =>
                                      v!.isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: isMobile ? 32 : 48),
                        CleanFadeIn(
                          index: 6,
                          child: Container(
                            padding: EdgeInsets.all(isMobile ? 24 : 32),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : EditorialTheme.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white12
                                    : EditorialTheme.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Projected Gross Liability',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : EditorialTheme.textDim,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // FittedBox prevents huge numbers from overflowing on small phones
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    fmt.format(_calculatedTotal),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : EditorialTheme.textMain,
                                      fontSize: isMobile ? 32 : 40,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  int.tryParse(_durationController.text) !=
                                              null &&
                                          (int.tryParse(
                                                    _durationController.text,
                                                  ) ??
                                                  0) >
                                              0
                                      ? 'Daily: ${fmt.format(_calculatedDaily)} for ${_durationController.text} days'
                                      : 'Awaiting parameters...',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : EditorialTheme.textDim,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: isMobile ? 32 : 48),
                        CleanFadeIn(
                          index: 7,
                          child: SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _saveData,
                              child: const Text(
                                "Generate Contract",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
