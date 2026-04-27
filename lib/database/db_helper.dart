import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('microfinance_dashboard_v23.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    // Bumped to v23 to include the settings table
    return await openDatabase(path, version: 23, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute(
      '''CREATE TABLE admins (id $idType, username $textType, password $textType)''',
    );
    await db.insert('admins', {'username': 'roshan', 'password': '7249'});

    await db.execute(
      '''CREATE TABLE customers (id $idType, name $textType, phone $textType, address $textType)''',
    );

    await db.execute('''
      CREATE TABLE loans (
        id $idType, customer_id INTEGER NOT NULL,
        principal_amount $realType, total_payable $realType,
        daily_installment $realType, balance_remaining $realType,
        installment_start_date $textType, start_date $textType, 
        expected_end_date $textType, is_active INTEGER NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE collections (
        id $idType, loan_id INTEGER NOT NULL,
        amount_paid $realType, collection_date $textType,
        FOREIGN KEY (loan_id) REFERENCES loans (id)
      )
    ''');

    // NEW: Settings table to track base business capital
    await db.execute(
      '''CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)''',
    );
    await db.insert('settings', {
      'key': 'base_capital',
      'value': '100000',
    }); // Default 1 Lakh
  }

  Future<bool> login(String username, String password) async {
    final db = await instance.database;
    final result = await db.query(
      'admins',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    return result.isNotEmpty;
  }

  // --- NEW VAULT MANAGEMENT FUNCTION ---
  Future<void> updateBaseCapital(double amount) async {
    final db = await instance.database;
    await db.insert('settings', {
      'key': 'base_capital',
      'value': amount.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getPendingCollectionsForToday() async {
    final db = await instance.database;
    final loans = await db.rawQuery('''
      SELECT l.id AS loan_id, c.name AS customer_name, l.daily_installment, l.balance_remaining, l.total_payable, l.installment_start_date
      FROM loans l JOIN customers c ON l.customer_id = c.id
      WHERE l.is_active = 1
    ''');

    List<Map<String, dynamic>> pendingList = [];
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    for (var item in loans) {
      DateTime startDate = DateTime.parse(
        item['installment_start_date'] as String,
      );
      double totalPaid =
          (item['total_payable'] as num).toDouble() -
          (item['balance_remaining'] as num).toDouble();
      double installmentAmt = (item['daily_installment'] as num).toDouble();

      int installsCovered = (totalPaid / installmentAmt).floor();

      DateTime nextDueDate = startDate.add(Duration(days: installsCovered));
      DateTime strictNextDate = DateTime(
        nextDueDate.year,
        nextDueDate.month,
        nextDueDate.day,
      );
      int daysRemaining = strictNextDate.difference(today).inDays;

      var mutableItem = Map<String, dynamic>.from(item);
      mutableItem['days_remaining'] = daysRemaining;
      mutableItem['next_due_date'] = strictNextDate.toIso8601String();
      pendingList.add(mutableItem);
    }

    pendingList.sort(
      (a, b) =>
          (a['days_remaining'] as int).compareTo(b['days_remaining'] as int),
    );
    return pendingList;
  }

  Future<double> getTodayCollectionTotal() async {
    final db = await instance.database;
    String today = DateTime.now().toIso8601String().split('T')[0];
    var result = await db.rawQuery(
      "SELECT SUM(amount_paid) as total FROM collections WHERE collection_date LIKE '$today%'",
    );
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  // --- REBUILT SCOREBOARD TO REFLECT LIQUID VAULT MATH ---
  Future<Map<String, dynamic>> getDashboardScoreboard() async {
    final db = await instance.database;

    // 1. Get Base Capital (Initial Investment)
    final settingsRes = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['base_capital'],
    );
    double baseCapital = settingsRes.isNotEmpty
        ? double.parse(settingsRes.first['value'] as String)
        : 100000.0;

    // 2. All Time Deployed & Collected (to calculate liquid cash)
    final allLentRes = await db.rawQuery(
      'SELECT SUM(principal_amount) as total FROM loans',
    );
    double totalLentAllTime =
        (allLentRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final allCollectedRes = await db.rawQuery(
      'SELECT SUM(amount_paid) as total FROM collections',
    );
    double totalCollectedAllTime =
        (allCollectedRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // 3. Liquid Cash = Base - Lent + Collected
    double liquidCash = baseCapital - totalLentAllTime + totalCollectedAllTime;

    // 4. Active Stats (Money currently out on the street)
    final activeRes = await db.rawQuery('''
      SELECT SUM(principal_amount) as total_principal, SUM(balance_remaining) as total_outstanding 
      FROM loans WHERE is_active = 1
    ''');
    double activeDeployed =
        (activeRes.first['total_principal'] as num?)?.toDouble() ?? 0.0;
    double activeOutstanding =
        (activeRes.first['total_outstanding'] as num?)?.toDouble() ?? 0.0;

    // 5. Total Business Value (Net Worth = Cash on hand + Debt owed to you)
    double totalBusinessValue = liquidCash + activeOutstanding;

    // 6. 30-Day Projection
    final activeLoans = await db.query('loans', where: 'is_active = 1');
    double dailyInterestProjection = 0.0;
    for (var loan in activeLoans) {
      double payable = (loan['total_payable'] as num).toDouble();
      double principal = (loan['principal_amount'] as num).toDouble();
      double dailyInstallment = (loan['daily_installment'] as num).toDouble();

      if (payable > 0) {
        double interestPortion =
            ((payable - principal) / payable) * dailyInstallment;
        dailyInterestProjection += interestPortion;
      }
    }

    return {
      'base_capital': baseCapital,
      'liquid_cash': liquidCash,
      'active_deployed': activeDeployed,
      'total_business_value': totalBusinessValue,
      'monthly_projection': dailyInterestProjection * 30,
    };
  }

  Future<List<Map<String, dynamic>>> getAllActiveLoans() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT l.id AS loan_id, c.name AS customer_name, l.installment_start_date, l.expected_end_date, l.total_payable, l.balance_remaining
      FROM loans l JOIN customers c ON l.customer_id = c.id
      WHERE l.is_active = 1
      ORDER BY l.installment_start_date DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getLedgerMatrix() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT col.collection_date, c.name AS customer_name, col.amount_paid
      FROM collections col 
      JOIN loans l ON col.loan_id = l.id 
      JOIN customers c ON l.customer_id = c.id
      ORDER BY col.collection_date DESC
    ''');
  }

  Future<Map<String, dynamic>?> getCustomerProfile(int loanId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
      SELECT c.name, c.phone, c.address, l.principal_amount, l.total_payable, l.balance_remaining, l.daily_installment, l.installment_start_date, l.expected_end_date
      FROM loans l JOIN customers c ON l.customer_id = c.id
      WHERE l.id = ?
    ''',
      [loanId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getCustomerCollections(int loanId) async {
    final db = await instance.database;
    return await db.query(
      'collections',
      where: 'loan_id = ?',
      orderBy: 'collection_date DESC',
      whereArgs: [loanId],
    );
  }

  Future<List<Map<String, dynamic>>> getPaymentHeatmap(int loanId) async {
    final db = await instance.database;

    final loanRes = await db.query(
      'loans',
      columns: ['installment_start_date', 'expected_end_date'],
      where: 'id = ?',
      whereArgs: [loanId],
    );
    if (loanRes.isEmpty) return [];

    DateTime startDate = DateTime.parse(
      loanRes.first['installment_start_date'] as String,
    );
    DateTime endDate = DateTime.parse(
      loanRes.first['expected_end_date'] as String,
    );

    DateTime today = DateTime.now();
    DateTime strictToday = DateTime(today.year, today.month, today.day);
    DateTime strictStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    DateTime strictEnd = DateTime(endDate.year, endDate.month, endDate.day);

    DateTime finalDate = strictEnd.isAfter(strictToday)
        ? strictEnd
        : strictToday;

    final colRes = await db.query(
      'collections',
      columns: ['collection_date'],
      where: 'loan_id = ?',
      whereArgs: [loanId],
    );
    Set<String> paidDates = colRes.map((row) {
      return (row['collection_date'] as String).split('T')[0];
    }).toSet();

    List<Map<String, dynamic>> heatmap = [];
    DateTime current = strictStart;

    while (!current.isAfter(finalDate)) {
      String dateStr = current.toIso8601String().split('T')[0];
      bool isPaid = paidDates.contains(dateStr);
      String status;

      if (isPaid) {
        status = 'paid';
      } else if (current.isBefore(strictToday)) {
        status = 'missed';
      } else if (current.isAtSameMomentAs(strictToday)) {
        status = 'due';
      } else {
        status = 'future';
      }

      heatmap.add({'date': current, 'status': status});

      current = current.add(const Duration(days: 1));
    }

    return heatmap;
  }

  Future<void> recordDailyCollection(
    int loanId,
    double amount, {
    DateTime? collectionDate,
  }) async {
    final db = await instance.database;
    String dateStr = collectionDate != null
        ? collectionDate.toIso8601String()
        : DateTime.now().toIso8601String();

    await db.insert('collections', {
      'loan_id': loanId,
      'amount_paid': amount,
      'collection_date': dateStr,
    });
    await db.rawUpdate(
      'UPDATE loans SET balance_remaining = balance_remaining - ? WHERE id = ?',
      [amount, loanId],
    );

    final result = await db.query(
      'loans',
      columns: ['balance_remaining'],
      where: 'id = ?',
      whereArgs: [loanId],
    );
    if (result.isNotEmpty &&
        (result.first['balance_remaining'] as num).toDouble() <= 0) {
      await db.update(
        'loans',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [loanId],
      );
    }
  }

  Future<void> addCustomerAndLoan({
    required String name,
    required String phone,
    required String address,
    required DateTime startDate,
    required double principal,
    required double totalPayable,
    required double dailyInstallment,
    required int durationDays,
  }) async {
    final db = await instance.database;
    int customerId = await db.insert('customers', {
      'name': name,
      'phone': phone,
      'address': address,
    });

    String expectedEndDate = startDate
        .add(Duration(days: durationDays))
        .toIso8601String();

    await db.insert('loans', {
      'customer_id': customerId,
      'principal_amount': principal,
      'total_payable': totalPayable,
      'daily_installment': dailyInstallment,
      'balance_remaining': totalPayable,
      'installment_start_date': startDate.toIso8601String(),
      'start_date': DateTime.now().toIso8601String(),
      'expected_end_date': expectedEndDate,
      'is_active': 1,
    });
  }
}
