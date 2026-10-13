import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'dart:ui';
import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:app_links/app_links.dart';
import 'package:local_auth/local_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:home_widget/home_widget.dart';
import 'package:quick_actions/quick_actions.dart';
import 'screens/analytics_screen.dart';
import 'services/indian_banks.dart';
import 'services/sms_parser.dart';

int? smartAccountMatch(String text, List<Map<String, dynamic>> accountsData, {String? senderAddress}) {
  return IndianBankDirectory.matchAccountFromSms(
    senderAddress: senderAddress,
    messageBody: text,
    accounts: accountsData,
  );
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final actionId = notificationResponse.actionId;
  final payload = notificationResponse.payload;
  if (payload == null || actionId == null) return;
  
  final txId = int.tryParse(payload);
  if (txId == null) return;

  try {
    String dbPath = p.join(await getDatabasesPath(), 'money_os_v8.db');
    Database db = await openDatabase(dbPath);
    
    final txs = await db.query('transactions', where: 'id = ?', whereArgs: [txId]);
    if (txs.isEmpty) return;
    final tx = txs.first;
    double amt = (tx['amount'] as num).toDouble();
    String oldType = tx['type'] as String;
    int? accId = tx['account_id'] as int?;

    if (actionId == 'confirm_ok') {
      await db.update('transactions', {'needs_review': 0}, where: 'id = ?', whereArgs: [txId]);
    } else if (actionId == 'change_transfer') {
      if (accId != null && oldType == 'INCOME') {
        final accs = await db.query('accounts', where: 'id = ?', whereArgs: [accId]);
        if (accs.isNotEmpty) {
          double bal = (accs.first['balance'] as num).toDouble();
          await db.update('accounts', {'balance': bal - amt}, where: 'id = ?', whereArgs: [accId]);
        }
      }
      await db.update('transactions', {
        'type': 'TRANSFER_OUT',
        'category': 'Transfer Out',
        'needs_review': 0
      }, where: 'id = ?', whereArgs: [txId]);
    } else if (actionId == 'change_income') {
      if (accId != null && oldType == 'EXPENSE') {
        final accs = await db.query('accounts', where: 'id = ?', whereArgs: [accId]);
        if (accs.isNotEmpty) {
          double bal = (accs.first['balance'] as num).toDouble();
          await db.update('accounts', {'balance': bal + (2 * amt)}, where: 'id = ?', whereArgs: [accId]);
        }
      }
      await db.update('transactions', {
        'type': 'INCOME',
        'category': 'Salary',
        'needs_review': 0
      }, where: 'id = ?', whereArgs: [txId]);
    }
  } catch (e) {
    debugPrint("Background notification action error: $e");
  }
}

@pragma('vm:entry-point')
Future<Map<String, dynamic>?> processIncomingSmsString({
  required String rawBody,
  String? senderAddress,
  DateTime? date,
  bool showNotification = true,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final trimmedBody = rawBody.trim();
  if (trimmedBody.isEmpty) return null;

  // 1. High-precision Indian Financial SMS parsing
  final parsed = SmsTransactionParser.parse(
    senderAddress: senderAddress,
    body: trimmedBody,
  );

  if (!parsed.isValid) return null;

  double amount = parsed.amount;
  bool isIncome = parsed.type == 'INCOME';
  String typeStr = parsed.type;
  String merchant = parsed.merchant;
  String category = parsed.category;

  String dbPath = p.join(await getDatabasesPath(), 'money_os_v8.db');
  Database db = await openDatabase(dbPath);

  try {
    var autoSyncRes = await db.query('user_profile', where: 'key = ?', whereArgs: ['auto_sms']);
    if (autoSyncRes.isNotEmpty && autoSyncRes.first['value'] == 'false') {
      return null;
    }
  } catch (_) {}

  // 2. Smart Account Match with Indian Bank identification & number matching
  final accounts = await db.query('accounts');
  int? matchedAccountId = IndianBankDirectory.matchAccountFromSms(
    senderAddress: senderAddress,
    messageBody: trimmedBody,
    accounts: accounts,
  );
  if (matchedAccountId == null && accounts.isNotEmpty) {
    matchedAccountId = accounts.first['id'] as int;
  }

  DateTime txDate = date ?? DateTime.now();
  int msgDateId = txDate.millisecondsSinceEpoch;
  
  // Deduplicate against processed SMS hash or timestamp
  try {
    int smsHash = (trimmedBody + (senderAddress ?? '')).hashCode;
    var processed = await db.query('processed_sms', where: 'date_id = ?', whereArgs: [smsHash]);
    if (processed.isNotEmpty) return null;
    await db.insert('processed_sms', {'date_id': smsHash}, conflictAlgorithm: ConflictAlgorithm.ignore);
  } catch (_) {}

  int newTxId = await db.insert('transactions', {
    'merchant': merchant,
    'category': category,
    'amount': amount,
    'type': typeStr,
    'date': txDate.toIso8601String(),
    'goal_id': null,
    'account_id': matchedAccountId,
    'needs_review': 1,
  });
  
  // 3. Update account balance (using Ground-Truth balance from SMS if present)
  String accName = 'mone Account';
  if (matchedAccountId != null && accounts.isNotEmpty) {
    var accMatches = accounts.where((a) => a['id'] == matchedAccountId);
    if (accMatches.isNotEmpty) {
      var accRow = accMatches.first;
      String bName = accRow['bank_name']?.toString() ?? '';
      String aNum = accRow['account_number']?.toString() ?? '';
      if (bName.isNotEmpty) {
        accName = aNum.isNotEmpty ? '$bName •• $aNum' : bName;
      } else {
        accName = accRow['name']?.toString() ?? 'Account';
      }
      double currentBal = (accRow['balance'] as num?)?.toDouble() ?? 0.0;
      double newBal = parsed.availableBalance ?? (isIncome ? currentBal + amount : currentBal - amount);
      await db.update('accounts', {'balance': newBal}, where: 'id = ?', whereArgs: [matchedAccountId]);
    }
  }
  
  await db.insert('user_profile', {'key': 'last_synced_timestamp', 'value': msgDateId.toString()}, conflictAlgorithm: ConflictAlgorithm.replace);
  
  // 4. Fire Instant Push Notification with Actionable Heads-up (iOS & Android compatible)
  if (showNotification) {
    try {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );
      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'mone_sync_channel', 'Mone Auto Sync',
        description: 'Instant notification on SMS transactions',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'mone_sync_channel', 'Mone Auto Sync',
        channelDescription: 'Notifications for auto synced transactions',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'confirm_ok',
            '✓ Confirm',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          const AndroidNotificationAction(
            'change_transfer',
            '⇄ Transfer',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          const AndroidNotificationAction(
            'change_income',
            '+ Income',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );
      const DarwinNotificationDetails darwinPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: darwinPlatformChannelSpecifics,
      );
      
      String title = isIncome ? '⚡ ₹${amount.toStringAsFixed(0)} Received' : '⚡ ₹${amount.toStringAsFixed(0)} Spent';
      String body = isIncome 
          ? 'mone securely added +₹${amount.toStringAsFixed(0)} to $accName ($merchant)'
          : 'mone automatically logged -₹${amount.toStringAsFixed(0)} from $accName ($merchant)';
      if (parsed.availableBalance != null) {
        body += ' • Avl: ₹${parsed.availableBalance!.toStringAsFixed(0)}';
      }
      
      await flutterLocalNotificationsPlugin.show(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: title,
        body: body,
        payload: newTxId.toString(),
        notificationDetails: platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint("Notification dispatch error: $e");
    }
  }

  final createdRows = await db.query('transactions', where: 'id = ?', whereArgs: [newTxId]);
  return createdRows.isNotEmpty ? createdRows.first : null;
}

IconData getCategoryIcon(String category) {
  switch(category.toLowerCase()) {
    case 'food': return Icons.fastfood_rounded;
    case 'shopping': return Icons.shopping_bag_rounded;
    case 'transport': return Icons.directions_car_rounded;
    case 'entertainment': return Icons.movie_rounded;
    case 'utilities': return Icons.lightbulb_rounded;
    case 'groceries': return Icons.local_grocery_store_rounded;
    case 'salary': return Icons.account_balance_wallet_rounded;
    default: return Icons.category_rounded;
  }
}

Color getCategoryColor(String category) {
  switch(category.toLowerCase()) {
    case 'food': case 'food & dining': return const Color(0xFF10B981); // green
    case 'shopping': return const Color(0xFF8B5CF6); // purple
    case 'transport': return const Color(0xFF3B82F6);
    case 'entertainment': return const Color(0xFFEF4444); // red
    case 'utilities': case 'bills': return const Color(0xFF14B8A6);
    case 'groceries': return const Color(0xFFF59E0B);
    case 'salary': return const Color(0xFF6366F1);
    default: 
      int hash = category.hashCode;
      int r = (hash & 0xFF0000) >> 16;
      int g = (hash & 0x00FF00) >> 8;
      int b = (hash & 0x0000FF);
      return Color.fromRGBO(r, g, b, 1.0);
  }
}

List<String> getDateRange(String timePeriod) {
  DateTime now = DateTime.now();
  if (timePeriod == 'Weekly') return [DateTime(now.year, now.month, now.day - now.weekday + 1).toIso8601String(), DateTime(now.year, now.month, now.day - now.weekday + 8).toIso8601String()];
  if (timePeriod == 'Monthly') return [DateTime(now.year, now.month, 1).toIso8601String(), DateTime(now.year, now.month + 1, 1).toIso8601String()];
  return [DateTime(now.year, 1, 1).toIso8601String(), DateTime(now.year + 1, 1, 1).toIso8601String()];
}

String getPeriodKey(String timePeriod) {
  DateTime now = DateTime.now();
  if (timePeriod == 'Monthly') return 'M${now.year}-${now.month}';
  if (timePeriod == 'Weekly') return 'W${now.year}-${now.month}-${now.day - now.weekday + 1}';
  return 'Y${now.year}';
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PersonalMoneyOS());
}

class PersonalMoneyOS extends StatelessWidget {
  const PersonalMoneyOS({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mone',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF09090B),
        primaryColor: const Color(0xFF818CF8),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const MainAppScreen(),
    );
  }
}

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({Key? key}) : super(key: key);

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isDbReady = false;
  late Database _database;
  String _timePeriod = 'Monthly';
  String _userName = '';
  bool _needsOnboarding = false;
  
  bool _isBiometricEnabled = false;
  bool _isAutoSmsEnabled = true;
  bool _isClipboardSyncEnabled = true;
  String _lastProcessedClipboardText = '';
  bool _isAuthenticated = false;
  final LocalAuthentication auth = LocalAuthentication();
  
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  bool _ambientAnimations = true;
  late AnimationController _ambientController;
  bool _showIsland = false;
  Map<String, dynamic>? _lastIslandTx;
  String _cardText = 'MONEY OS PREMIUM';
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  DateTime _lastShakeTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ambientController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    _initDatabase();
    _setupDeepLinks();

    _accelerometerSubscription = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      if (!_isAuthenticated && _isBiometricEnabled) return;
      double acceleration = event.x * event.x + event.y * event.y + event.z * event.z;
      if (acceleration > 400) { 
        DateTime now = DateTime.now();
        if (now.difference(_lastShakeTime).inSeconds > 2) {
          _lastShakeTime = now;
          HapticFeedback.heavyImpact();
          _showAddTransactionModal();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForSms();
    }
  }

  void _setupDeepLinks() {
    _appLinks = AppLinks();
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleIncomingUri(uri);
    }).catchError((err) {
      debugPrint("AppLinks getInitialLink error: $err");
    });

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingUri(uri);
    }, onError: (err) {
      debugPrint("AppLinks stream error: $err");
    });
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    debugPrint("Handling incoming URI: $uri");
    if (uri.scheme == 'mone') {
      if (uri.host == 'import-sms' || uri.path.contains('import-sms') || uri.host == 'sms') {
        String? text = uri.queryParameters['text'] ?? uri.queryParameters['body'] ?? uri.queryParameters['sms'];
        String? sender = uri.queryParameters['sender'] ?? uri.queryParameters['address'];
        if (text != null && text.isNotEmpty) {
          final tx = await processIncomingSmsString(rawBody: text, senderAddress: sender);
          if (tx != null) {
            await _updateWidget();
            if (mounted) {
              setState(() {
                _lastIslandTx = tx;
                _showIsland = true;
              });
              HapticFeedback.heavyImpact();
              Future.delayed(const Duration(seconds: 4), () {
                if (mounted) setState(() => _showIsland = false);
              });
            }
          }
        }
      } else if (uri.queryParameters['action'] == 'add') {
        String? category = uri.queryParameters['category'];
        if (category != null) {
          _showAddTransactionModal(existingTx: {'category': category, 'type': 'EXPENSE'});
        }
      }
    }
  }

  Future<void> _checkClipboardForSms() async {
    if (!_isClipboardSyncEnabled) return;
    try {
      ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.length < 15 || text == _lastProcessedClipboardText) return;

      final parsed = SmsTransactionParser.parse(body: text);
      if (!parsed.isValid) return;

      _lastProcessedClipboardText = text;

      if (mounted) {
        _showClipboardDetectedSheet(text, parsed);
      }
    } catch (_) {}
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    _ambientController.dispose();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDatabase() async {
    try {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) async {
          if (details.actionId != null) {
            notificationTapBackground(details);
            setState(() {});
          }
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'mone_sync_channel', 'Mone Auto Sync',
        description: 'Instant notification on SMS transactions',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      final androidPlugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {}

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'money_os_v8.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, merchant TEXT, category TEXT, amount REAL, type TEXT, date TEXT, goal_id INTEGER, account_id INTEGER, needs_review INTEGER DEFAULT 0)''');
        await db.execute('''CREATE TABLE budgets(category TEXT PRIMARY KEY, limit_amount REAL)''');
        await db.execute('''CREATE TABLE goals(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, target REAL, saved REAL)''');
        await db.execute('''CREATE TABLE settings(key TEXT PRIMARY KEY, value REAL)''');
        await db.execute('''CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, type TEXT)''');
        await db.execute('''CREATE TABLE IF NOT EXISTS accounts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, account_number TEXT, balance REAL, type TEXT)''');
        await db.execute('''CREATE TABLE IF NOT EXISTS processed_sms(date_id INTEGER PRIMARY KEY)''');
        
        await db.insert('settings', {'key': 'total_budget', 'value': 0.0});
        
        final cats = ['Food & Dining', 'Shopping', 'Entertainment', 'Bills', 'Investment', 'Other'];
        for (var c in cats) { await db.insert('categories', {'name': c, 'type': 'EXPENSE'}); }
        await db.insert('categories', {'name': 'Salary', 'type': 'INCOME'});
        await db.insert('categories', {'name': 'Freelance', 'type': 'INCOME'});
      },
    );

    await _database.execute('''CREATE TABLE IF NOT EXISTS user_profile(key TEXT PRIMARY KEY, value TEXT)''');
    List<Map<String, dynamic>> res = await _database.query('user_profile', where: 'key = ?', whereArgs: ['name']);
    if (res.isNotEmpty) {
      _userName = res.first['value'];
    } else {
      _needsOnboarding = true;
    }

    try {
      await _database.execute('ALTER TABLE transactions ADD COLUMN account_id INTEGER');
    } catch (_) {}
    try {
      await _database.execute('ALTER TABLE transactions ADD COLUMN needs_review INTEGER DEFAULT 0');
    } catch (_) {}
    await _database.execute('''CREATE TABLE IF NOT EXISTS accounts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, account_number TEXT, balance REAL, type TEXT)''');
    await _database.execute('''CREATE TABLE IF NOT EXISTS processed_sms(date_id INTEGER PRIMARY KEY)''');
    try {
      await _database.execute('ALTER TABLE accounts ADD COLUMN include_in_total INTEGER DEFAULT 1');
    } catch (_) {}
    try {
      await _database.execute('ALTER TABLE accounts ADD COLUMN bank_name TEXT');
    } catch (_) {}
    try {
      await _database.execute('ALTER TABLE accounts ADD COLUMN bank_code TEXT');
    } catch (_) {}
    try {
      await _database.execute('ALTER TABLE accounts ADD COLUMN initial_balance REAL DEFAULT 0.0');
    } catch (_) {}
    
    var existingAccs = await _database.query('accounts');
    if (existingAccs.isEmpty) {
      await _database.insert('accounts', {'name': 'Cash', 'type': 'CASH', 'balance': 0.0, 'account_number': ''});
    }

    setState(() => _isDbReady = true);
    
    // Check if biometric is enabled
    var bioRes = await _database.query('settings', where: 'key = ?', whereArgs: ['biometric_enabled']);
    if (bioRes.isNotEmpty && bioRes.first['value'] == 1.0) {
      _isBiometricEnabled = true;
      _authenticate();
    } else {
      _isAuthenticated = true;
    }
    
    var textRes = await _database.query('settings', where: 'key = ?', whereArgs: ['card_text']);
    if (textRes.isNotEmpty && textRes.first['value'] != null) {
      // For string settings, we can reuse the table by storing it in a new profile table or hacking 'value'. Wait, settings table has `value REAL`.
    }
    // Wait, the settings table is CREATE TABLE settings(key TEXT PRIMARY KEY, value REAL)
    // I should save string in user_profile!
    var userProfileText = await _database.query('user_profile', where: 'key = ?', whereArgs: ['card_text']);
    if (userProfileText.isNotEmpty) {
      _cardText = userProfileText.first['value'].toString();
    }
    
    var autoSmsRes = await _database.query('user_profile', where: 'key = ?', whereArgs: ['auto_sms']);
    if (autoSmsRes.isNotEmpty && autoSmsRes.first['value'] == 'true') {
      _isAutoSmsEnabled = true;
    }
    
    _checkPendingResolutions();
    _updateWidget();
    _checkWidgetLaunch();
    _setupQuickActions();
    _silentCatchUpSync();
  }

  Future<void> _manualSyncSms() async {
    try {
      await _checkClipboardForSms();
      await _updateWidget();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Balances updated • Scanned clipboard for bank alerts'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1E1E24),
          ),
        );
      }
    } catch (e) {
      debugPrint("Manual sync error: $e");
    }
  }

  Future<void> _silentCatchUpSync() async {
    await Future.delayed(const Duration(seconds: 1));
    _checkClipboardForSms();
  }

  void _setupQuickActions() {
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      if (shortcutType == 'action_add_expense') {
        _showAddTransactionModal(existingTx: {'type': 'EXPENSE'});
      } else if (shortcutType == 'action_add_income') {
        _showAddTransactionModal(existingTx: {'type': 'INCOME'});
      }
    });

    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(type: 'action_add_expense', localizedTitle: 'Add Expense', icon: 'add_expense_icon'),
      const ShortcutItem(type: 'action_add_income', localizedTitle: 'Add Income', icon: 'add_income_icon'),
    ]);
  }

  void _checkWidgetLaunch() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
    HomeWidget.widgetClicked.listen(_handleWidgetUri);
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri != null && uri.scheme == 'mone' && uri.queryParameters['action'] == 'add') {
      String? category = uri.queryParameters['category'];
      if (category != null) {
        _showAddTransactionModal(existingTx: {'category': category, 'type': 'EXPENSE'});
      }
    }
  }

  Future<void> _updateWidget() async {
    if (!_isDbReady) return;
    final allTxs = await _database.query('transactions');
    double walletBalance = 0;
    for (var t in allTxs) {
      if (t['type'] == 'INCOME' || t['type'] == 'TRANSFER_IN') walletBalance += (t['amount'] as num).toDouble();
      else if (t['type'] == 'EXPENSE' || t['type'] == 'GOAL_TRANSFER' || t['type'] == 'TRANSFER_OUT') walletBalance -= (t['amount'] as num).toDouble();
    }
    String balanceStr = walletBalance < 0 ? '-₹ ${walletBalance.abs().toStringAsFixed(0)}' : '₹ ${walletBalance.toStringAsFixed(0)}';
    await HomeWidget.saveWidgetData<String>('balance', balanceStr);
    await HomeWidget.updateWidget(name: 'MoneyWidgetProvider');
  }

  Future<void> _authenticate() async {
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to unlock mone',
      );
      if (didAuthenticate && mounted) {
        setState(() => _isAuthenticated = true);
      }
    } catch (e) {
      // Fallback or error
    }
  }

  Future<void> _checkPendingResolutions() async {
    DateTime now = DateTime.now();
    DateTime lastMonth = DateTime(now.year, now.month - 1, 1);
    String lastMonthKey = 'M${lastMonth.year}-${lastMonth.month}';
    
    final settings = await _database.query('settings');
    bool isResolved = false;
    double baseBudget = 0;
    
    for (var s in settings) {
      if (s['key'] == 'total_budget') baseBudget = s['value'] as double;
      if (s['key'] == 'resolved_$lastMonthKey') isResolved = (s['value'] as double) > 0;
    }
    
    final countRes = await _database.rawQuery("SELECT COUNT(*) as c FROM transactions WHERE date < ?", [DateTime(now.year, now.month, 1).toIso8601String()]);
    int pastTxCount = countRes.first['c'] as int;
    
    if (!isResolved && pastTxCount > 0) {
      DateTime start = DateTime(lastMonth.year, lastMonth.month, 1);
      DateTime end = DateTime(now.year, now.month, 1);
      final txs = await _database.query('transactions', where: 'type = ? AND date >= ? AND date < ?', whereArgs: ['EXPENSE', start.toIso8601String(), end.toIso8601String()]);
      double spent = txs.fold(0.0, (sum, item) => sum + (item['amount'] as double));
      double unspent = baseBudget - spent;
      
      if (mounted) {
        _showMonthEndResolutionModal(unspent, unspent < 0, periodKeyOverride: lastMonthKey);
      }
    }
  }

  void _showAppleShortcutsGuideModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF14151C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF818CF8).withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.bolt_rounded, color: Color(0xFF818CF8), size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('iOS Apple Shortcuts Sync', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Automate SMS logging seamlessly on iPhone', style: TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
                child: const Text(
                  'Apple restricts iOS apps from directly reading the Messages inbox. '
                  'Using native Apple Shortcuts Personal Automation, you can automatically route incoming bank SMS alerts directly into mone!',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Setup Steps (Takes 1 Minute):', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildShortcutStep('1', 'Open the native Shortcuts app on your iPhone.'),
              _buildShortcutStep('2', 'Go to Automation tab -> tap + (New Automation).'),
              _buildShortcutStep('3', 'Select "Message" -> When I receive a message containing keywords: "debited", "credited", "UPI", "spent".'),
              _buildShortcutStep('4', 'Add Action: "Open URLs" -> paste URL scheme: mone://import-sms?text=[Shortcut Input]'),
              _buildShortcutStep('5', 'Turn off "Ask Before Running" and tap Done!'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: 'mone://import-sms?text='));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied URL Scheme: mone://import-sms?text= to clipboard!'), backgroundColor: Color(0xFF10B981)),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white),
                      label: const Text('Copy URL Scheme', style: TextStyle(color: Colors.white, fontSize: 13)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27272A), padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleIncomingUri(Uri.parse('mone://import-sms?text=HDFC%20Bank%3A%20Rs%20649.00%20debited%20from%20a%2Fc%20**4321%20at%20Swiggy%20UPI.%20Avl%20Bal%3A%20INR%2024500.00'));
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
                      label: const Text('Test Simulation', style: TextStyle(color: Colors.white, fontSize: 13)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: const Color(0xFF818CF8).withOpacity(0.2),
            child: Text(num, style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13))),
        ],
      ),
    );
  }

  void _showClipboardDetectedSheet(String text, ParsedSmsResult parsed) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF14151C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.content_paste_rounded, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bank SMS in Clipboard', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Detected transaction ready to import', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(parsed.merchant, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(parsed.category, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                  Text(
                    '${parsed.type == 'INCOME' ? '+' : '-'}₹${parsed.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: parsed.type == 'INCOME' ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final tx = await processIncomingSmsString(rawBody: text);
                      if (tx != null && mounted) {
                        await _updateWidget();
                        setState(() {
                          _lastIslandTx = tx;
                          _showIsland = true;
                        });
                        HapticFeedback.heavyImpact();
                        Future.delayed(const Duration(seconds: 4), () {
                          if (mounted) setState(() => _showIsland = false);
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Import Transaction', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showPasteSmsModal() {
    final TextEditingController controller = TextEditingController();
    ParsedSmsResult? previewParsed;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF14151C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Paste Bank SMS Text', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.paste_rounded, color: Color(0xFF818CF8)),
                        tooltip: 'Paste from Clipboard',
                        onPressed: () async {
                          ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            controller.text = data!.text!;
                            setModalState(() {
                              previewParsed = SmsTransactionParser.parse(body: data.text!);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. HDFC Bank: Rs 550.00 debited from a/c **1234 at Starbucks UPI. Avl bal: INR 12,000.00',
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        previewParsed = SmsTransactionParser.parse(body: val);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (previewParsed != null && previewParsed!.isValid)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Recognized: ₹${previewParsed!.amount.toStringAsFixed(0)} ${previewParsed!.type} at ${previewParsed!.merchant} (${previewParsed!.category})',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        Navigator.pop(ctx);
                        final tx = await processIncomingSmsString(rawBody: text);
                        if (tx != null && mounted) {
                          await _updateWidget();
                          setState(() {
                            _lastIslandTx = tx;
                            _showIsland = true;
                          });
                          HapticFeedback.heavyImpact();
                          Future.delayed(const Duration(seconds: 4), () {
                            if (mounted) setState(() => _showIsland = false);
                          });
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not detect transaction in pasted text'), backgroundColor: Colors.redAccent),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text('Parse & Save Transaction', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddTransactionModal({Map<String, dynamic>? existingTx}) async {
    final catsRaw = await _database.query('categories');
    final accountsRaw = await _database.query('accounts');
    List<String> expenseCats = catsRaw.where((c) => c['type'] == 'EXPENSE').map((c) => c['name'] as String).toList();
    List<String> incomeCats = catsRaw.where((c) => c['type'] == 'INCOME').map((c) => c['name'] as String).toList();
    
    final _merchantCtrl = TextEditingController(text: existingTx?['merchant'] ?? '');
    final _amountCtrl = TextEditingController(text: existingTx?['amount']?.toString() ?? '');
    String _selectedType = existingTx?['type'] ?? 'EXPENSE';
    DateTime _selectedDate = (existingTx != null && existingTx['date'] != null) ? DateTime.parse(existingTx['date']) : DateTime.now();
    
    String _selectedExpCat = expenseCats.contains(existingTx?['category']) ? existingTx!['category'] : (expenseCats.isNotEmpty ? expenseCats.first : 'Other');
    String _selectedIncCat = incomeCats.contains(existingTx?['category']) ? existingTx!['category'] : (incomeCats.isNotEmpty ? incomeCats.first : 'Salary');
    
    int? _selectedAccountId = existingTx?['account_id'];
    if (_selectedAccountId == null && accountsRaw.isNotEmpty) {
       _selectedAccountId = accountsRaw.first['id'] as int;
    }

    int? _toAccountId = accountsRaw.length > 1 ? accountsRaw.last['id'] as int : _selectedAccountId;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300), curve: Curves.easeOutExpo,
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32),
            decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: const BorderRadius.vertical(top: Radius.circular(40)), border: Border.all(color: Colors.white.withOpacity(0.1))),
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(existingTx == null ? 'Track Record' : 'Edit Record', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    if (existingTx == null)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showPasteSmsModal();
                        },
                        icon: const Icon(Icons.paste_rounded, size: 16, color: Color(0xFF818CF8)),
                        label: const Text('From SMS', style: TextStyle(color: Color(0xFF818CF8), fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: () => setModalState(() => _selectedType = 'EXPENSE'), child: AnimatedContainer(duration: const Duration(milliseconds: 250), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: _selectedType == 'EXPENSE' ? const Color(0xFFF43F5E).withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(30), border: Border.all(color: _selectedType == 'EXPENSE' ? const Color(0xFFF43F5E) : Colors.white.withOpacity(0.1))), alignment: Alignment.center, child: Text('Expense', style: TextStyle(color: _selectedType == 'EXPENSE' ? const Color(0xFFF43F5E) : Colors.white, fontWeight: FontWeight.bold))))),
                    const SizedBox(width: 8),
                    Expanded(child: GestureDetector(onTap: () => setModalState(() => _selectedType = 'INCOME'), child: AnimatedContainer(duration: const Duration(milliseconds: 250), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: _selectedType == 'INCOME' ? const Color(0xFF10B981).withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(30), border: Border.all(color: _selectedType == 'INCOME' ? const Color(0xFF10B981) : Colors.white.withOpacity(0.1))), alignment: Alignment.center, child: Text('Income', style: TextStyle(color: _selectedType == 'INCOME' ? const Color(0xFF10B981) : Colors.white, fontWeight: FontWeight.bold))))),
                    const SizedBox(width: 8),
                    Expanded(child: GestureDetector(onTap: () => setModalState(() => _selectedType = 'TRANSFER'), child: AnimatedContainer(duration: const Duration(milliseconds: 250), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: _selectedType == 'TRANSFER' ? const Color(0xFF3B82F6).withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(30), border: Border.all(color: _selectedType == 'TRANSFER' ? const Color(0xFF3B82F6) : Colors.white.withOpacity(0.1))), alignment: Alignment.center, child: Text('Move Funds', style: TextStyle(color: _selectedType == 'TRANSFER' ? const Color(0xFF3B82F6) : Colors.white, fontWeight: FontWeight.bold))))),
                  ],
                ),
                
                const SizedBox(height: 24),
                TextField(controller: _amountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), decoration: InputDecoration(prefixText: '₹ ', prefixStyle: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), labelText: 'Amount', labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)), filled: true, fillColor: Colors.white.withOpacity(0.03), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFF6366F1))))),
                const SizedBox(height: 16),
                TextField(controller: _merchantCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Title / Description', labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)), filled: true, fillColor: Colors.white.withOpacity(0.03), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFF6366F1))))),
                const SizedBox(height: 16),
                
                if (_selectedType != 'TRANSFER') ...[
                  DropdownButtonFormField<String>(
                    value: _selectedType == 'EXPENSE' ? _selectedExpCat : _selectedIncCat,
                    dropdownColor: const Color(0xFF18181B), style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)), filled: true, fillColor: Colors.white.withOpacity(0.03), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.white.withOpacity(0.1)))),
                    items: (_selectedType == 'EXPENSE' ? expenseCats : incomeCats).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) { setModalState(() { if (_selectedType == 'EXPENSE') _selectedExpCat = val!; else _selectedIncCat = val!; }); },
                  ),
                  const SizedBox(height: 16),
                ],
                
                DropdownButtonFormField<int>(
                  value: _selectedAccountId,
                  dropdownColor: const Color(0xFF18181B),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: _selectedType == 'TRANSFER' ? 'From Account' : 'Account',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.03),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  items: accountsRaw.map((a) {
                    final b = IndianBankDirectory.findBankByName((a['bank_code'] ?? a['bank_name'] ?? (a['type'] == 'CASH' ? 'cash' : '')).toString());
                    return DropdownMenuItem(
                      value: a['id'] as int,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          b.buildBadge(size: 20, showBorder: false),
                          const SizedBox(width: 8),
                          Text('${a['name']}${a['account_number'] != null && a['account_number'].toString().isNotEmpty ? " (•• ${a['account_number']})" : ""}'),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) { setModalState(() { _selectedAccountId = val; }); },
                ),
                if (_selectedType == 'TRANSFER') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _toAccountId,
                    dropdownColor: const Color(0xFF18181B),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'To Account',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.03),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                    items: accountsRaw.map((a) {
                      final b = IndianBankDirectory.findBankByName((a['bank_code'] ?? a['bank_name'] ?? (a['type'] == 'CASH' ? 'cash' : '')).toString());
                      return DropdownMenuItem(
                        value: a['id'] as int,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            b.buildBadge(size: 20, showBorder: false),
                            const SizedBox(width: 8),
                            Text('${a['name']}${a['account_number'] != null && a['account_number'].toString().isNotEmpty ? " (•• ${a['account_number']})" : ""}'),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) { setModalState(() { _toAccountId = val; }); },
                  ),
                ],
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100), builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF6366F1), onPrimary: Colors.white, surface: Color(0xFF18181B), onSurface: Colors.white)), child: child!));
                    if (picked != null) setModalState(() => _selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.1))),
                    child: Row(children: [const Icon(Icons.calendar_today, color: Colors.white54), const SizedBox(width: 16), Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}', style: const TextStyle(color: Colors.white, fontSize: 16))]),
                  ),
                ),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 60,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 15, spreadRadius: -5)]),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                      onPressed: () async {
                        if (_amountCtrl.text.isEmpty || _merchantCtrl.text.isEmpty || double.tryParse(_amountCtrl.text) == null || double.tryParse(_amountCtrl.text)! <= 0) {
                          showDialog(context: context, builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF18181B),
                            title: const Text('Missing Details', style: TextStyle(color: Colors.red)),
                            content: const Text('Please enter a valid amount and a title/description.', style: TextStyle(color: Colors.white)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: Colors.white)))
                            ]
                          ));
                          return;
                        }
                        double amt = double.parse(_amountCtrl.text);
                        String finalCat = _selectedType == 'EXPENSE' ? _selectedExpCat : _selectedIncCat;
                        
                        if (_selectedType == 'EXPENSE') {
                          final budgets = await _database.query('budgets', where: 'category = ?', whereArgs: [finalCat]);
                          if (budgets.isNotEmpty) {
                            double limit = budgets.first['limit_amount'] as double;
                            DateTime startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
                            final txs = await _database.query('transactions', where: 'type = ? AND category = ? AND date >= ?', whereArgs: ['EXPENSE', finalCat, startOfMonth.toIso8601String()]);
                            double spent = txs.fold(0.0, (sum, item) => sum + (item['amount'] as double));
                            if (existingTx != null) spent -= (existingTx['amount'] as double);
                            
                            if (spent + amt > limit) {
                              bool? proceed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF18181B),
                                title: const Text('Budget Warning', style: TextStyle(color: Colors.red)),
                                content: Text('Adding this will exceed your $finalCat limit of ₹$limit by ₹${(spent + amt - limit).toStringAsFixed(0)}.', style: const TextStyle(color: Colors.white)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Proceed', style: TextStyle(color: Colors.white))),
                                ]
                              ));
                              if (proceed != true) return;
                            }
                          }
                        }

                        
                        if (_selectedType == 'TRANSFER') {
if (existingTx == null) {
await _database.insert('transactions', { 'merchant': _merchantCtrl.text, 'category': 'Transfer Out', 'amount': amt, 'type': 'TRANSFER_OUT', 'date': _selectedDate.toIso8601String(), 'goal_id': null, 'account_id': _selectedAccountId });
if (_toAccountId != null && _toAccountId != _selectedAccountId) {
await _database.insert('transactions', { 'merchant': _merchantCtrl.text, 'category': 'Transfer In', 'amount': amt, 'type': 'TRANSFER_IN', 'date': _selectedDate.toIso8601String(), 'goal_id': null, 'account_id': _toAccountId });
}
}
                        } else {
                          final data = { 'merchant': _merchantCtrl.text, 'category': finalCat, 'amount': amt, 'type': _selectedType, 'date': _selectedDate.toIso8601String(), 'goal_id': null, 'account_id': _selectedAccountId };
                          if (existingTx == null) { 
                            await _database.insert('transactions', data); 
                            if (_selectedAccountId != null) {
                              var acc = accountsRaw.firstWhere((a) => a['id'] == _selectedAccountId, orElse: () => {'balance': 0.0});
                              double newBal = (acc['balance'] as double) + (_selectedType == 'INCOME' ? amt : -amt);
                              await _database.update('accounts', {'balance': newBal}, where: 'id = ?', whereArgs: [_selectedAccountId]);
                            }
                            setState(() { _lastIslandTx = data; _showIsland = true; }); 
                            Future.delayed(const Duration(seconds: 4), () { if (mounted) setState(() => _showIsland = false); });
                          }
                          else { 
                             await _database.update('transactions', data, where: 'id = ?', whereArgs: [existingTx['id']]);
                          }
                        }
                        Navigator.pop(context);
                        setState(() {}); 
                      },
                      child: Text(existingTx == null ? 'Save Record' : 'Update Record', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        });
      }
    );
  }

  void _showSetTotalBudgetModal() {
    final _amountCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF18181B), title: const Text('Overall Monthly Budget', style: TextStyle(color: Colors.white)),
      content: TextField(controller: _amountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Limit (₹)', labelStyle: TextStyle(color: Colors.grey))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (_amountCtrl.text.isNotEmpty) {
            await _database.insert('settings', {'key': 'total_budget', 'value': double.parse(_amountCtrl.text)}, conflictAlgorithm: ConflictAlgorithm.replace);
            Navigator.pop(ctx); setState(() {});
          }
        }, child: const Text('Save'))
      ]
    ));
  }

  void _showSetBudgetModal() async {
    final catsRaw = await _database.query('categories', where: 'type = ?', whereArgs: ['EXPENSE']);
    List<String> expenseCats = catsRaw.map((c) => c['name'] as String).toList();
    if(expenseCats.isEmpty) return;
    
    String _selectedCat = expenseCats.first;
    final _amountCtrl = TextEditingController();
    
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
      return AlertDialog(
        backgroundColor: const Color(0xFF18181B), title: const Text('Set Category Limit', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: _selectedCat, dropdownColor: const Color(0xFF18181B), style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: Colors.grey)),
            items: expenseCats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setDialogState(() => _selectedCat = val!),
          ),
          const SizedBox(height: 16),
          TextField(controller: _amountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Limit (₹)', labelStyle: TextStyle(color: Colors.grey))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () async {
            if (_amountCtrl.text.isNotEmpty) {
              await _database.insert('budgets', {'category': _selectedCat, 'limit_amount': double.parse(_amountCtrl.text)}, conflictAlgorithm: ConflictAlgorithm.replace);
              Navigator.pop(ctx); setState(() {});
            }
          }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)), child: const Text('Save', style: TextStyle(color: Colors.white)))
        ]
      );
    }));
  }

  void _showSetGoalModal({Map<String, dynamic>? existingGoal}) {
    final _titleCtrl = TextEditingController(text: existingGoal?['title'] ?? '');
    final _targetCtrl = TextEditingController(text: existingGoal?['target']?.toString() ?? '');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF18181B), title: Text(existingGoal == null ? 'Create New Goal' : 'Edit Goal', style: const TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _titleCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Goal Title', labelStyle: TextStyle(color: Colors.grey))),
        TextField(controller: _targetCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Target (₹)', labelStyle: TextStyle(color: Colors.grey))),
      ]),
      actions: [
        if (existingGoal != null)
          TextButton(onPressed: () async {
            await _database.delete('goals', where: 'id = ?', whereArgs: [existingGoal['id']]);
            Navigator.pop(ctx); setState(() {});
          }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (_titleCtrl.text.isNotEmpty && _targetCtrl.text.isNotEmpty) {
            if (existingGoal == null) {
              await _database.insert('goals', {'title': _titleCtrl.text, 'target': double.parse(_targetCtrl.text), 'saved': 0.0});
            } else {
              await _database.update('goals', {'title': _titleCtrl.text, 'target': double.parse(_targetCtrl.text)}, where: 'id = ?', whereArgs: [existingGoal['id']]);
            }
            Navigator.pop(ctx); setState(() {});
          }
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), child: const Text('Save', style: TextStyle(color: Colors.white)))
      ]
    ));
  }

  void _showManageCategoriesModal() async {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
        return FutureBuilder<List<dynamic>>(
          future: _database.query('categories'),
          builder: (context, snapshot) {
            final cats = snapshot.data ?? [];
            final _nameCtrl = TextEditingController();
            String _newType = 'EXPENSE';
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32),
              decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: const BorderRadius.vertical(top: Radius.circular(40))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Manage Categories', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(child: TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'New Category...', hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))))),
                    const SizedBox(width: 8),
                    DropdownButton<String>(value: _newType, dropdownColor: const Color(0xFF09090B), style: const TextStyle(color: Colors.white), items: ['EXPENSE', 'INCOME'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setModalState(() => _newType = v!)),
                    IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF6366F1), size: 36), onPressed: () async {
                      if (_nameCtrl.text.isNotEmpty) {
                        await _database.insert('categories', {'name': _nameCtrl.text, 'type': _newType});
                        setModalState(() {});
                      }
                    })
                  ]),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: cats.length,
                      itemBuilder: (context, index) {
                        final c = cats[index];
                        return ListTile(
                          title: Text(c['name'], style: const TextStyle(color: Colors.white)),
                          subtitle: Text(c['type'], style: TextStyle(color: c['type'] == 'INCOME' ? const Color(0xFF10B981) : const Color(0xFFF43F5E), fontSize: 12)),
                          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: () async {
                            await _database.delete('categories', where: 'id = ?', whereArgs: [c['id']]);
                            setModalState(() {});
                          }),
                        );
                      }
                    )
                  )
                ],
              ),
            );
          }
        );
      })
    );
  }


  void _showEditAccountDialog(Map<String, dynamic> acc, StateSetter parentSetModalState) {
    BankInfo currentBank = IndianBankDirectory.findBankByName(acc['bank_code'] ?? acc['bank_name'] ?? '');
    String editBankCode = acc['bank_code']?.toString() ?? currentBank.id;
    final editNameCtrl = TextEditingController(text: acc['name']?.toString() ?? '');
    final editBankCtrl = TextEditingController(text: currentBank.name);
    final editNumberCtrl = TextEditingController(text: acc['account_number']?.toString() ?? '');
    final editBalCtrl = TextEditingController(text: ((acc['initial_balance'] ?? acc['balance']) as num?)?.toString() ?? '0');
    String editType = (acc['type']?.toString().toUpperCase() == 'CASH') ? 'CASH' : 'BANK';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF14151B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_rounded, color: Color(0xFF818CF8), size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Edit Account', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bank / Institution', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final picked = await showIndianBankPicker(context, selectedBank: currentBank);
                      if (picked != null) {
                        setDialogState(() {
                          currentBank = picked;
                          editBankCtrl.text = picked.name;
                          editBankCode = picked.id;
                          if (picked.isCash) {
                            editType = 'CASH';
                          } else {
                            editType = 'BANK';
                          }
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          currentBank.buildBadge(size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SELECTED BANK',
                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentBank.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('CHANGE', style: TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold)),
                                SizedBox(width: 2),
                                Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF818CF8), size: 14),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Account Label', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: editNameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      hintText: 'e.g. Salary Account',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Account Number (or Last 4)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: editNumberCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      hintText: 'e.g. 4821',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Available Balance (₹)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: editBalCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      hintText: 'Enter available balance (₹)',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Account Type', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButton<String>(
                      value: editType,
                      dropdownColor: const Color(0xFF181920),
                      isExpanded: true,
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.white),
                      items: ['BANK', 'CASH'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setDialogState(() => editType = v!),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  if (editNameCtrl.text.trim().isNotEmpty) {
                    double newBal = double.tryParse(editBalCtrl.text.trim()) ?? 0.0;
                    await _database.update('accounts', {
                      'name': editNameCtrl.text.trim(),
                      'bank_name': currentBank.name,
                      'bank_code': editBankCode,
                      'account_number': editNumberCtrl.text.trim(),
                      'initial_balance': newBal,
                      'balance': newBal,
                      'type': editType,
                    }, where: 'id = ?', whereArgs: [acc['id']]);
                    parentSetModalState(() {});
                    setState(() {});
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showManageAccountsModal() async {
    final _nameCtrl = TextEditingController(text: 'SBI Account');
    final _numberCtrl = TextEditingController();
    BankInfo _selectedBank = IndianBankDirectory.allBanks.first;
    final _bankNameCtrl = TextEditingController(text: _selectedBank.name);
    String _selectedBankCode = _selectedBank.id;
    final _initBalCtrl = TextEditingController();
    String _newType = 'BANK';
    
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
        return FutureBuilder<List<dynamic>>(
          future: _database.query('accounts'),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Container(color: const Color(0xFF18181B), child: Center(child: Text(snapshot.error.toString(), style: const TextStyle(color: Colors.red))));
            final accs = snapshot.data ?? [];
            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 28),
              decoration: BoxDecoration(color: const Color(0xFF12141D), borderRadius: const BorderRadius.vertical(top: Radius.circular(36)), border: Border.all(color: Colors.white.withOpacity(0.08))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bank & Wallets', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                          SizedBox(height: 2),
                          Text('Connect & manage your accounts', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close_rounded, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ADD NEW INDIAN BANK OR WALLET', style: TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                        const SizedBox(height: 12),
                        // Bank Selection Choice Button
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final picked = await showIndianBankPicker(context, selectedBank: _selectedBank);
                            if (picked != null) {
                              setModalState(() {
                                _selectedBank = picked;
                                _selectedBankCode = picked.id;
                                _bankNameCtrl.text = picked.name;
                                if (_nameCtrl.text.isEmpty || _nameCtrl.text.endsWith('Account') || _nameCtrl.text.endsWith('Wallet')) {
                                  _nameCtrl.text = picked.isCash ? 'Cash Wallet' : '${picked.shortName} Account';
                                }
                                _newType = picked.isCash ? 'CASH' : 'BANK';
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                _selectedBank.buildBadge(size: 34),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'BANK / INSTITUTION',
                                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _selectedBank.name,
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('SELECT', style: TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.w800)),
                                      SizedBox(width: 2),
                                      Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF818CF8), size: 16),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _nameCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Account Label',
                                hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 12),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _numberCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'A/C No (Last 4)',
                                hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 12),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _initBalCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Enter available balance (₹)',
                                hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 12),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                            child: DropdownButton<String>(
                              value: _newType,
                              dropdownColor: const Color(0xFF181920),
                              underline: const SizedBox(),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: ['BANK', 'CASH'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (v) => setModalState(() => _newType = v!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                            label: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () async {
                              if (_nameCtrl.text.isNotEmpty) {
                                double initBal = double.tryParse(_initBalCtrl.text) ?? 0.0;
                                await _database.insert('accounts', {
                                  'name': _nameCtrl.text,
                                  'bank_name': _selectedBank.name,
                                  'bank_code': _selectedBankCode,
                                  'account_number': _numberCtrl.text,
                                  'type': _newType,
                                  'balance': initBal,
                                  'initial_balance': initBal,
                                  'include_in_total': 1,
                                });
                                _nameCtrl.text = '${_selectedBank.shortName} Account';
                                _numberCtrl.clear();
                                _initBalCtrl.clear();
                                setModalState(() {});
                                setState(() {});
                              }
                            },
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('EXISTING ACCOUNTS', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: accs.length,
                      itemBuilder: (context, index) {
                        final a = accs[index];
                        int include = (a['include_in_total'] as int?) ?? 1;
                        double bal = ((a['balance'] ?? a['initial_balance'] ?? 0.0) as num).toDouble();
                        BankInfo b = IndianBankDirectory.findBankByName(
                          a['bank_code'] ?? a['bank_name'] ?? (a['type'] == 'CASH' ? 'cash' : ''),
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              b.buildBadge(size: 38),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a['name'] ?? 'Account', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${b.shortName} • A/C: ${a['account_number'] != null && a['account_number'].toString().isNotEmpty ? a['account_number'] : 'N/A'} • ₹${bal.toStringAsFixed(0)}',
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              // Edit Account Button
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, color: Color(0xFF818CF8), size: 20),
                                tooltip: 'Edit Account Details',
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _showEditAccountDialog(a, setModalState);
                                },
                              ),
                              // Include in Total Switch
                              Switch(
                                value: include == 1,
                                activeColor: const Color(0xFF10B981),
                                onChanged: (val) async {
                                  await _database.update('accounts', {'include_in_total': val ? 1 : 0}, where: 'id = ?', whereArgs: [a['id']]);
                                  setModalState(() {});
                                  setState(() {});
                                },
                              ),
                              // Delete Button
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                                onPressed: () async {
                                  bool? confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      backgroundColor: const Color(0xFF18181B),
                                      title: const Text('Delete Account?', style: TextStyle(color: Colors.white)),
                                      content: Text('Are you sure you want to delete ${a['name']}? Associated transactions will remain.', style: const TextStyle(color: Colors.white70)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await _database.delete('accounts', where: 'id = ?', whereArgs: [a['id']]);
                                    setModalState(() {});
                                    setState(() {});
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  Future<void> _markResolved({String? keyOverride}) async {
    String key = keyOverride ?? getPeriodKey(_timePeriod);
    await _database.insert('settings', {'key': 'resolved_$key', 'value': 1.0}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  void _showSweepToGoalModal(double amount, {String? periodKeyOverride}) async {
    final goals = await _database.query('goals');
    if (goals.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active goals to sweep to!')));
      return;
    }
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF18181B), builder: (ctx) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Select Goal to Fund', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...goals.map((g) => ListTile(
          title: Text(g['title'].toString(), style: const TextStyle(color: Colors.white)),
          subtitle: Text('Target: ₹${g['target']}', style: const TextStyle(color: Colors.white54)),
          onTap: () async {
            await _database.update('goals', {'saved': (g['saved'] as double) + amount}, where: 'id = ?', whereArgs: [g['id']]);
            await _database.insert('transactions', {'merchant': 'Swept to Goal: ${g['title']}', 'category': 'Goal Funding', 'amount': amount, 'type': 'GOAL_TRANSFER', 'date': DateTime.now().toIso8601String(), 'goal_id': g['id']});
            await _markResolved(keyOverride: periodKeyOverride);
            Navigator.pop(ctx);
            setState(() {});
          }
        )).toList()
      ])
    ));
  }

  void _showMonthEndResolutionModal(double difference, bool overspent, {String? periodKeyOverride}) {
    showDialog(barrierDismissible: false, context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF18181B),
      title: Text(overspent ? 'Budget Exceeded!' : 'Budget Surplus!', style: TextStyle(color: overspent ? Colors.red : Colors.green)),
      content: Text(overspent ? 'You overspent your overall budget by ₹${difference.abs().toStringAsFixed(0)}. Please review your spending habits.' 
                              : 'You have ₹${difference.toStringAsFixed(0)} unspent budget left. What would you like to do?', style: const TextStyle(color: Colors.white)),
      actions: [
        if (periodKeyOverride == null) TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Dismiss', style: TextStyle(color: Colors.grey))),
        if (overspent)
          ElevatedButton(onPressed: () async {
            await _markResolved(keyOverride: periodKeyOverride);
            Navigator.pop(ctx);
            setState(() {});
          }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)), child: const Text('Acknowledge', style: TextStyle(color: Colors.white)))
        else ...[
          ElevatedButton(onPressed: () async {
            await _markResolved(keyOverride: periodKeyOverride);
            Navigator.pop(ctx);
            setState(() {});
          }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)), child: const Text('Keep in Wallet', style: TextStyle(color: Colors.white))),
          ElevatedButton(onPressed: () async {
            Navigator.pop(ctx);
            _showSweepToGoalModal(difference, periodKeyOverride: periodKeyOverride);
          }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), child: const Text('Sweep to a Goal', style: TextStyle(color: Colors.white)))
        ]
      ]
    ));
  }

  void _showEditProfileModal() {
    TextEditingController ctrl = TextEditingController(text: _userName);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF18181B),
      title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Your Name', labelStyle: const TextStyle(color: Colors.grey),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6366F1))),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
        ElevatedButton(onPressed: () async {
          if (ctrl.text.trim().isNotEmpty) {
            await _database.insert('user_profile', {'key': 'name', 'value': ctrl.text.trim()}, conflictAlgorithm: ConflictAlgorithm.replace);
            setState(() => _userName = ctrl.text.trim());
          }
          Navigator.pop(ctx);
        }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)), child: const Text('Save'))
      ]
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDbReady) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_needsOnboarding) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/mone_logo.png', width: 100, height: 100),
                const SizedBox(height: 32),
                const Text('Welcome to mone', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Your personal, offline-first financial OS.', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16)),
                const SizedBox(height: 48),
                TextField(
                  onChanged: (v) => _userName = v,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'What is your name?',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_userName.trim().isEmpty) return;
                      await _database.insert('user_profile', {'key': 'name', 'value': _userName.trim()});
                      setState(() { _needsOnboarding = false; });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    child: const Text('Get Started', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      );
    }

    if (!_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 80, color: Colors.white.withOpacity(0.5)),
              const SizedBox(height: 24),
              const Text('mone is locked', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint, color: Colors.white),
                label: const Text('Unlock with Biometrics', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
              )
            ],
          ),
        ),
      );
    }

    final List<Widget> _screens = [
      DashboardScreen(
        database: _database,
        onAddRequested: _showAddTransactionModal,
        onTransactionChanged: () => setState(() {}),
        timePeriod: _timePeriod,
        userName: _userName,
        onManageAccountsRequested: _showManageAccountsModal,
        onNavigateTab: (idx) => setState(() => _selectedIndex = idx),
        onRefreshRequested: _manualSyncSms,
      ),
      ModernAnalyticsScreen(database: _database, initialTimePeriod: _timePeriod, onAddRequested: _showAddTransactionModal),
      TrendsScreen(database: _database, onAddRequested: _showAddTransactionModal, onTransactionChanged: () => setState(() {})),
      ProfileScreen(
        database: _database, currentPeriod: _timePeriod, onPeriodChanged: (val) => setState(() => _timePeriod = val),
        onSetTotalBudget: _showSetTotalBudgetModal, onAddBudget: _showSetBudgetModal, onAddGoal: () => _showSetGoalModal(), onGoalEdit: (g) => _showSetGoalModal(existingGoal: g), onManageCategories: _showManageCategoriesModal, onManageAccounts: _showManageAccountsModal,
        userName: _userName, onEditProfile: _showEditProfileModal,
        isBiometricEnabled: _isBiometricEnabled,
        onToggleBiometric: (val) async {
          if (val) {
             bool canCheck = await auth.canCheckBiometrics;
             if (!canCheck) return;
             bool authd = await auth.authenticate(localizedReason: 'Authenticate to enable biometric lock');
             if (!authd) return;
          }
          await _database.insert('settings', {'key': 'biometric_enabled', 'value': val ? 1.0 : 0.0}, conflictAlgorithm: ConflictAlgorithm.replace);
          setState(() => _isBiometricEnabled = val);
        },
        isClipboardSyncEnabled: _isClipboardSyncEnabled,
        onToggleClipboardSync: (val) async {
          await _database.insert('user_profile', {'key': 'clipboard_sync', 'value': val ? 'true' : 'false'}, conflictAlgorithm: ConflictAlgorithm.replace);
          setState(() => _isClipboardSyncEnabled = val);
        },
        onOpenShortcutsGuide: _showAppleShortcutsGuideModal,
        onPasteSms: _showPasteSmsModal,
      ),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF090A0E),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF13151F), Color(0xFF090A0E), Color(0xFF07080B)],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(bottom: false, child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _screens[_selectedIndex])),
          
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            top: _showIsland ? 60 : -100,
            left: 20, right: 20,
            child: _lastIslandTx == null ? const SizedBox() : Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161822).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                  boxShadow: [BoxShadow(color: getCategoryColor(_lastIslandTx!['category']).withOpacity(0.25), blurRadius: 24)]
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: getCategoryColor(_lastIslandTx!['category']).withOpacity(0.2), shape: BoxShape.circle), child: Icon(getCategoryIcon(_lastIslandTx!['category']), color: getCategoryColor(_lastIslandTx!['category']), size: 16)),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Recorded ${_lastIslandTx!['merchant']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${_lastIslandTx!['type'] == 'INCOME' ? '+' : '-'}₹${_lastIslandTx!['amount']}', style: TextStyle(color: _lastIslandTx!['type'] == 'INCOME' ? const Color(0xFF10B981) : const Color(0xFFF43F5E), fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildFloatingBottomNav(),
    );
  }

  Widget _buildFloatingBottomNav() {
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF12141D).withOpacity(0.94),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))
              ]
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(Icons.account_balance_wallet_rounded, 0),
                _buildNavItem(Icons.pie_chart_rounded, 1),
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 4))
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showAddTransactionModal();
                    },
                  ),
                ),
                _buildNavItem(Icons.bar_chart_rounded, 2),
                _buildNavItem(Icons.settings_rounded, 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(duration: const Duration(milliseconds: 250), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent, shape: BoxShape.circle), child: Icon(icon, color: isSelected ? const Color(0xFF818CF8) : Colors.white.withOpacity(0.35), size: 26)),
    );
  }
}

// ---------------------------------------------------------
// EXECUTIVE DASHBOARD SCREEN & CAROUSEL
// ---------------------------------------------------------
class CardInfo {
  final String title;
  final String amount;
  final String subtitle;
  final String network;
  final Color startColor;
  final Color endColor;
  final IconData icon;
  final String cardHolder;
  final Widget? bankBadge;
  final VoidCallback? onTap;

  CardInfo({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.network,
    required this.startColor,
    required this.endColor,
    required this.icon,
    required this.cardHolder,
    this.bankBadge,
    this.onTap,
  });
}

class HorizontalCardCarousel extends StatefulWidget {
  final List<CardInfo> cards;

  const HorizontalCardCarousel({Key? key, required this.cards}) : super(key: key);

  @override
  State<HorizontalCardCarousel> createState() => _HorizontalCardCarouselState();
}

class _HorizontalCardCarouselState extends State<HorizontalCardCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.cards.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              HapticFeedback.selectionClick();
            },
            itemBuilder: (context, index) {
              final info = widget.cards[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: GestureDetector(
                  onTap: info.onTap,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [info.startColor, info.endColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white.withOpacity(0.14), width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: info.startColor.withOpacity(0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Row: EMV Gold Chip, Contactless Waves & Network Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                // Realistic Metallic EMV Chip
                                Container(
                                  width: 36,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFE2C275), Color(0xFFC59F4E), Color(0xFFE8D390)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(color: const Color(0xFF997A2E), width: 0.8),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 1))
                                    ],
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: const Color(0xFF7D6018), width: 0.8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(Icons.contactless_rounded, color: Colors.white.withOpacity(0.65), size: 20),
                              ],
                            ),
                            Row(
                              children: [
                                if (info.bankBadge != null) ...[
                                  info.bankBadge!,
                                  const SizedBox(width: 8),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.8),
                                  ),
                                  child: Text(
                                    info.network,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Title & Balance
                        Text(
                          info.title.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          info.amount,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),

                        const Spacer(),

                        // Bottom Row: Account Number & Cardholder
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  info.subtitle,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  info.cardHolder,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  'MANAGE',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.4), size: 10),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.cards.length > 1) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.cards.length, (i) {
              bool isActive = i == _currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 22 : 6,
                height: 5,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF818CF8) : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

// Backward compatibility alias
class InteractiveCardStack extends StatelessWidget {
  final List<CardInfo> cards;
  const InteractiveCardStack({Key? key, required this.cards}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HorizontalCardCarousel(cards: cards);
  }
}

class DashboardScreen extends StatelessWidget {
  final Database database;
  final Function({Map<String, dynamic>? existingTx}) onAddRequested;
  final VoidCallback onTransactionChanged;
  final String timePeriod;
  final String userName;
  final VoidCallback onManageAccountsRequested;
  final Function(int) onNavigateTab;
  final Future<void> Function() onRefreshRequested;

  const DashboardScreen({
    Key? key,
    required this.database,
    required this.onAddRequested,
    required this.onTransactionChanged,
    required this.timePeriod,
    required this.userName,
    required this.onManageAccountsRequested,
    required this.onNavigateTab,
    required this.onRefreshRequested,
  }) : super(key: key);

  String _getGreeting() {
    int hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    if (hour < 21) return 'Good Evening,';
    return 'Good Night,';
  }

  void _showQuickReviewSheet(BuildContext context, Map<String, dynamic> tx, Map<dynamic, dynamic> accountMap) {
    HapticFeedback.mediumImpact();
    final amt = (tx['amount'] as num).toDouble();
    final txId = tx['id'] as int;
    final String type = tx['type'] as String;
    final int? accId = tx['account_id'] as int?;
    String accName = 'Account';
    if (accId != null && accountMap.containsKey(accId)) {
      final a = accountMap[accId]!;
      accName = a['name'] ?? 'Account';
      if (a['account_number'] != null && a['account_number'].toString().isNotEmpty) {
        accName += ' (•• ${a['account_number']})';
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
          decoration: BoxDecoration(
            color: const Color(0xFF13151F),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 14),
                        SizedBox(width: 4),
                        Text('SMS AUTO-SYNCED', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                      ],
                    ),
                  ),
                  Text(accName, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 14),
              Text(tx['merchant'] ?? 'Transaction', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('₹${amt.toStringAsFixed(2)} • ${tx['category']}', style: TextStyle(color: type == 'INCOME' ? const Color(0xFF10B981) : Colors.white70, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              const Text('Confirm or Reclassify with 1-Tap:', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              
              // 1. Confirm Option
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.08))),
                tileColor: Colors.white.withOpacity(0.04),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 20),
                ),
                title: Text(type == 'INCOME' ? 'Confirm as Income' : 'Confirm as Expense', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('Keep ₹${amt.toStringAsFixed(0)} logged to ${tx['category']}', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await database.update('transactions', {'needs_review': 0}, where: 'id = ?', whereArgs: [txId]);
                  Navigator.pop(ctx);
                  onTransactionChanged();
                },
              ),
              const SizedBox(height: 8),

              // 2. Transfer / Move Option
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.08))),
                tileColor: Colors.white.withOpacity(0.04),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF3B82F6), size: 20),
                ),
                title: const Text('Move / Transfer Between Accounts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Reclassify as transfer without affecting spending budget', style: TextStyle(color: Colors.white38, fontSize: 11)),
                onTap: () async {
                  HapticFeedback.lightImpact();
                  if (accId != null && type == 'INCOME') {
                    final accs = await database.query('accounts', where: 'id = ?', whereArgs: [accId]);
                    if (accs.isNotEmpty) {
                      double bal = (accs.first['balance'] as num).toDouble();
                      await database.update('accounts', {'balance': bal - amt}, where: 'id = ?', whereArgs: [accId]);
                    }
                  }
                  await database.update('transactions', {
                    'type': 'TRANSFER_OUT',
                    'category': 'Transfer Out',
                    'needs_review': 0,
                  }, where: 'id = ?', whereArgs: [txId]);
                  Navigator.pop(ctx);
                  onTransactionChanged();
                },
              ),
              const SizedBox(height: 8),

              // 3. Switch Direction (Expense <-> Income)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.08))),
                tileColor: Colors.white.withOpacity(0.04),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(type == 'INCOME' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: const Color(0xFF8B5CF6), size: 20),
                ),
                title: Text(type == 'INCOME' ? 'Switch to Expense' : 'Switch to Income', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Correct transaction flow and account balance', style: TextStyle(color: Colors.white38, fontSize: 11)),
                onTap: () async {
                  HapticFeedback.lightImpact();
                  String newType = type == 'INCOME' ? 'EXPENSE' : 'INCOME';
                  String newCat = newType == 'INCOME' ? 'Salary' : 'Other';
                  if (accId != null) {
                    final accs = await database.query('accounts', where: 'id = ?', whereArgs: [accId]);
                    if (accs.isNotEmpty) {
                      double bal = (accs.first['balance'] as num).toDouble();
                      double newBal = newType == 'INCOME' ? bal + (2 * amt) : bal - (2 * amt);
                      await database.update('accounts', {'balance': newBal}, where: 'id = ?', whereArgs: [accId]);
                    }
                  }
                  await database.update('transactions', {
                    'type': newType,
                    'category': newCat,
                    'needs_review': 0,
                  }, where: 'id = ?', whereArgs: [txId]);
                  Navigator.pop(ctx);
                  onTransactionChanged();
                },
              ),
              const SizedBox(height: 8),

              // 4. Edit full details
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.08))),
                tileColor: Colors.white.withOpacity(0.04),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, color: Colors.white70, size: 20),
                ),
                title: const Text('Edit Full Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Change merchant, custom category, or account', style: TextStyle(color: Colors.white38, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  onAddRequested(existingTx: tx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> range = getDateRange(timePeriod);
    DateTime now = DateTime.now();
    int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    int daysRemaining = (daysInMonth - now.day + 1).clamp(1, 31);

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        database.query('transactions', orderBy: 'id DESC'), 
        database.query('transactions', where: 'type = ? AND date >= ? AND date < ?', whereArgs: ['EXPENSE', range[0], range[1]]), 
        database.query('settings'),
        database.query('accounts'),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final allTxs = snapshot.data![0];
        final periodExpenses = snapshot.data![1];
        final settings = snapshot.data![2];
        final accounts = snapshot.data![3];

        double periodSpent = 0;
        for (var e in periodExpenses) periodSpent += (e['amount'] as num).toDouble();
        
        double baseBudget = 0;
        for (var s in settings) {
          if (s['key'] == 'total_budget') baseBudget = (s['value'] as num).toDouble();
        }
        
        double unspentBudget = baseBudget - periodSpent;
        double safeDailyAllowance = (unspentBudget > 0 ? (unspentBudget / daysRemaining) : 0.0);

        List<CardInfo> stackCards = [];
        double totalBalance = 0.0;
        
        Map<int, double> computedBalances = {};
        for (var acc in accounts) {
           int id = acc['id'] as int;
           computedBalances[id] = (acc['initial_balance'] as num?)?.toDouble() ?? (acc['balance'] as num?)?.toDouble() ?? 0.0;
        }
        for (var t in allTxs) {
           int? accId = t['account_id'] as int?;
           if (accId != null && computedBalances.containsKey(accId)) {
               double amt = (t['amount'] as num).toDouble();
               if (t['type'] == 'INCOME' || t['type'] == 'TRANSFER_IN') computedBalances[accId] = computedBalances[accId]! + amt;
               else if (t['type'] == 'EXPENSE' || t['type'] == 'TRANSFER_OUT') computedBalances[accId] = computedBalances[accId]! - amt;
           }
        }
        
        for (var acc in accounts) {
          int include = (acc['include_in_total'] as int?) ?? 1;
          double bal = computedBalances[acc['id'] as int] ?? 0.0;
          if (include == 1) {
            totalBalance += bal;
          }
        }
        
        String formattedTotal = totalBalance < 0 ? '-₹ ${totalBalance.abs().toStringAsFixed(0)}' : '₹ ${totalBalance.toStringAsFixed(0)}';
        
        // Map accounts for instant lookup
        Map<int, Map<String, dynamic>> accountMap = {};
        for (var acc in accounts) {
          accountMap[acc['id'] as int] = acc;
        }

        // Card 1: Executive Titanium Net Worth Card
        stackCards.add(CardInfo(
          title: 'Total Liquid Assets',
          amount: formattedTotal,
          subtitle: 'MONE • 8820',
          network: 'PLATINUM OS',
          startColor: const Color(0xFF1E212B),
          endColor: const Color(0xFF0F1117),
          icon: Icons.shield_rounded,
          cardHolder: userName.isNotEmpty ? userName.toUpperCase() : 'USER',
          bankBadge: const Icon(Icons.all_inclusive_rounded, color: Colors.white70, size: 20),
          onTap: onManageAccountsRequested,
        ));
        
        // Card 2+: Authentic Indian Bank Cards
        for (var acc in accounts) {
          double bal = computedBalances[acc['id'] as int] ?? 0.0;
          bool isCash = acc['type'] == 'CASH';
          String bankName = acc['bank_name']?.toString() ?? '';
          String bankCode = acc['bank_code']?.toString() ?? '';
          BankInfo bank = isCash
              ? IndianBankDirectory.getBankById('cash')
              : IndianBankDirectory.findBankByName(bankCode.isNotEmpty ? bankCode : bankName);
          String accNum = acc['account_number']?.toString() ?? '';
          String cleanAccNum = accNum.isNotEmpty ? '•••• $accNum' : (isCash ? 'WALLET CASH' : '•••• 0000');
          String title = isCash ? '${acc['name']} Wallet' : '${acc['name']} (${bank.shortName})';
          
          stackCards.add(CardInfo(
            title: title,
            amount: '₹ ${bal.toStringAsFixed(0)}',
            subtitle: cleanAccNum,
            network: isCash ? 'CASH LEDGER' : bank.defaultCardNetwork,
            startColor: bank.gradientColors.first,
            endColor: bank.gradientColors.last,
            icon: isCash ? Icons.payments_rounded : Icons.account_balance_rounded,
            cardHolder: userName.isNotEmpty ? userName.toUpperCase() : 'USER',
            bankBadge: bank.buildBadge(size: 26, showBorder: false),
            onTap: onManageAccountsRequested,
          ));
        }

        return RefreshIndicator(
          onRefresh: onRefreshRequested,
          color: const Color(0xFF6366F1),
          backgroundColor: const Color(0xFF13151F),
          displacement: 40,
          strokeWidth: 2.5,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Formal Executive Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getGreeting(), style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text('$userName 👋', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    ]
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Color(0xFF10B981), size: 7),
                            SizedBox(width: 6),
                            Text('LIVE SYNC', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Image.asset('assets/mone_logo.png', width: 40, height: 40),
                    ],
                  ),
                ]
              ),
              const SizedBox(height: 18),

              // Executive Card Carousel
              HorizontalCardCarousel(cards: stackCards),
              const SizedBox(height: 20),

              // Formal 4-Action Fintech Dock
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF12141D),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickAction(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Record',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onAddRequested();
                      },
                    ),
                    _buildQuickAction(
                      icon: Icons.sync_alt_rounded,
                      label: 'Transfer',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onAddRequested(existingTx: {'type': 'TRANSFER'});
                      },
                    ),
                    _buildQuickAction(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Accounts',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onManageAccountsRequested();
                      },
                    ),
                    _buildQuickAction(
                      icon: Icons.insights_rounded,
                      label: 'Analytics',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onNavigateTab(1);
                      },
                    ),
                  ],
                ),
              ),

              // Feature Showcase Strip: Indian Bank SMS & Active Protection
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF131A29), Color(0xFF0F1420)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sensors_rounded, color: Color(0xFF10B981), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text(
                                'AUTO-READING BANK SMS',
                                style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 12),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Active for SBI, HDFC, ICICI, Axis & 25+ Indian Banks',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: onManageAccountsRequested,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('BANKS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Formal Adaptive Daily Pacer & Budget Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF12141D),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.speed_rounded, color: Color(0xFF818CF8), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DAILY SAFE SPENDING PACER',
                                  style: TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹ ${safeDailyAllowance.toStringAsFixed(0)} / day',
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$daysRemaining d left',
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (periodSpent / (baseBudget == 0 ? 1 : baseBudget)).clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withOpacity(0.06),
                        color: unspentBudget < 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          unspentBudget < 0 ? 'Exceeded by ₹${unspentBudget.abs().toStringAsFixed(0)}' : '₹${unspentBudget.toStringAsFixed(0)} unspent',
                          style: TextStyle(
                            color: unspentBudget < 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Limit: ₹${baseBudget.toStringAsFixed(0)} ($timePeriod)',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              // Recent Transactions Feed
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Activity', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('${allTxs.length} items', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                ],
              ),
              const SizedBox(height: 14),
              if (allTxs.isEmpty) Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text("No records yet.", style: TextStyle(color: Colors.white.withOpacity(0.4))),
                ),
              ),
              ...allTxs.take(15).toList().map((tx) {
                DateTime d = DateTime.parse(tx['date']);
                String dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
                return Dismissible(
                  key: Key(tx['id'].toString()),
                  background: Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.5), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.delete, color: Colors.white)),
                  secondaryBackground: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.green.withOpacity(0.5), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.edit, color: Colors.white)),
                  confirmDismiss: (dir) async {
                    if (dir == DismissDirection.startToEnd) {
                      HapticFeedback.heavyImpact();
                      await database.delete('transactions', where: 'id = ?', whereArgs: [tx['id']]);
                      onTransactionChanged();
                      return true;
                    } else {
                      HapticFeedback.lightImpact();
                      onAddRequested(existingTx: tx);
                      return false;
                    }
                  },
                  child: GestureDetector(
                    onTap: () {
                      if (tx['needs_review'] == 1) {
                        _showQuickReviewSheet(context, tx, accountMap);
                      } else {
                        onAddRequested(existingTx: tx);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF12141D),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: tx['needs_review'] == 1 ? const Color(0xFFF59E0B).withOpacity(0.35) : Colors.white.withOpacity(0.04),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: getCategoryColor(tx['category']).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(getCategoryIcon(tx['category']), color: getCategoryColor(tx['category']), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        tx['merchant'],
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (tx['needs_review'] == 1) ...[
                                      GestureDetector(
                                        onTap: () => _showQuickReviewSheet(context, tx, accountMap),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B).withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5), width: 0.8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B), size: 10),
                                              SizedBox(width: 3),
                                              Text(
                                                'REVIEW',
                                                style: TextStyle(
                                                  color: Color(0xFFFBBF24),
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    if (accountMap.containsKey(tx['account_id'])) ...[
                                      Builder(builder: (context) {
                                        final txAcc = accountMap[tx['account_id']]!;
                                        BankInfo b = IndianBankDirectory.findBankByName(
                                          txAcc['bank_code'] ?? txAcc['bank_name'] ?? (txAcc['type'] == 'CASH' ? 'cash' : ''),
                                        );
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: b.accentColor.withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            b.shortName,
                                            style: TextStyle(color: b.accentColor, fontSize: 9, fontWeight: FontWeight.w900),
                                          ),
                                        );
                                      }),
                                    ],
                                    Text('${tx['category']} • $dateStr', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${tx['type'] == 'INCOME' ? '+' : '-'}₹${tx['amount']}',
                            style: TextStyle(
                              color: tx['type'] == 'INCOME' ? const Color(0xFF10B981) : Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      );
    },
  );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// ANALYTICS & BUDGETS
// ---------------------------------------------------------
class AnalyticsScreen extends StatefulWidget {
  final Database database;
  final String timePeriod;
  final Function(double, bool) onResolveRollover;
  final Function({Map<String, dynamic>? existingTx}) onAddRequested;
  final VoidCallback onTransactionChanged;
  final String? overrideMonth;

  const AnalyticsScreen({Key? key, required this.database, required this.timePeriod, required this.onResolveRollover, required this.onAddRequested, required this.onTransactionChanged, this.overrideMonth}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _showLastMonth = false;

  @override
  Widget build(BuildContext context) {
    List<String> range = getDateRange(widget.timePeriod);
    if (widget.overrideMonth != null) {
      List<String> parts = widget.overrideMonth!.split('-');
      int y = int.parse(parts[0]);
      int m = int.parse(parts[1]);
      DateTime start = DateTime(y, m, 1);
      DateTime end = DateTime(y, m + 1, 1);
      range = [start.toIso8601String(), end.toIso8601String()];
    } else if (widget.timePeriod == 'Monthly' && _showLastMonth) {
      DateTime now = DateTime.now();
      DateTime lastMonthStart = DateTime(now.year, now.month - 1, 1);
      DateTime lastMonthEnd = DateTime(now.year, now.month, 1);
      range = [lastMonthStart.toIso8601String(), lastMonthEnd.toIso8601String()];
    }
    
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        widget.database.query('transactions', where: 'type = ? AND date >= ? AND date < ?', whereArgs: ['EXPENSE', range[0], range[1]]),
        widget.database.query('settings'),
        widget.database.query('budgets'),
        widget.database.query('transactions', where: 'date >= ? AND date < ?', whereArgs: [range[0], range[1]], orderBy: 'date DESC')
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final expenses = snapshot.data![0];
        final settings = snapshot.data![1];
        final budgets = snapshot.data![2];
        final ledger = snapshot.data![3];
        
        double totalExpense = 0;
        Map<String, double> catSpent = {};
        for (var t in expenses) { 
          totalExpense += t['amount']; 
          catSpent[t['category']] = (catSpent[t['category']] ?? 0) + (t['amount'] as double); 
        }
        
        Map<String, double> limits = {};
        for (var b in budgets) { limits[b['category']] = b['limit_amount']; }
        
        Set<String> allCats = {...catSpent.keys, ...limits.keys};
        var sortedCats = allCats.toList()..sort((a, b) => (catSpent[b] ?? 0).compareTo(catSpent[a] ?? 0));
        
        double baseBudget = 0; bool isResolved = false;
        for (var s in settings) { 
          if (s['key'] == 'total_budget') baseBudget = s['value'] as double; 
          if (s['key'] == 'resolved_') isResolved = (s['value'] as double) > 0;
        }
        double unspent = baseBudget - totalExpense;
        
        List<PieChartSectionData> pieSections = [];
        for (var cat in sortedCats) {
          if ((catSpent[cat] ?? 0) > 0) {
            int pct = ((catSpent[cat]! / totalExpense) * 100).toInt();
            pieSections.add(PieChartSectionData(
              color: getCategoryColor(cat),
              value: catSpent[cat]!,
              title: '$pct%',
              showTitle: pct >= 5,
              radius: 50,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ));
          }
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.overrideMonth != null ? ' ${widget.overrideMonth}' : (_showLastMonth && widget.timePeriod == 'Monthly' ? ' Last Month' : ' Analytics'), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  if (widget.timePeriod == 'Monthly' && widget.overrideMonth == null)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(24)),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _showLastMonth = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                              decoration: BoxDecoration(color: !_showLastMonth ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(20)), 
                              child: Text('Current', style: TextStyle(color: !_showLastMonth ? Colors.black : Colors.white54, fontWeight: FontWeight.bold))
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _showLastMonth = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                              decoration: BoxDecoration(color: _showLastMonth ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(20)), 
                              child: Text('Last', style: TextStyle(color: _showLastMonth ? Colors.black : Colors.white54, fontWeight: FontWeight.bold))
                            ),
                          ),
                        ]
                      )
                    )
                ]
              ),
              const SizedBox(height: 32),


              Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(32)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Total Spent', style: TextStyle(color: Colors.white70)), const SizedBox(height: 8), Text('₹ ${totalExpense.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900))])),
              const SizedBox(height: 32),
              
              if (pieSections.isNotEmpty) ...[
                const Text('Spending Breakdown', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                SizedBox(
                  height: 220,
                  child: Stack(
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 60,
                          sections: pieSections,
                          pieTouchData: PieTouchData(enabled: false),
                        ),
                      ),
                      Center(child: Text('₹${totalExpense.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
              
              const Text('Category Limits', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (sortedCats.isEmpty) Text('No category data yet.', style: TextStyle(color: Colors.white.withOpacity(0.5))),
              ...sortedCats.map((cat) {
                double spent = catSpent[cat] ?? 0;
                double? limit = limits[cat];
                double pct = 0;
                Color barColor = getCategoryColor(cat);
                String limitText = '';
                
                if (limit != null && limit > 0) {
                  pct = (spent / limit).clamp(0.0, 1.0);
                  limitText = 'Spent: ₹$spent / Limit: ₹$limit';
                } else {
                  pct = totalExpense == 0 ? 0 : (spent / totalExpense).clamp(0.0, 1.0);
                  limitText = 'Unbudgeted (Spent: ₹$spent)';
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                        children: [
                          Text(cat, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), 
                          Text(limit != null ? '${(pct * 100).toInt()}%' : '₹$spent', style: TextStyle(color: barColor, fontWeight: FontWeight.bold))
                        ]
                      ), 
                      const SizedBox(height: 8), 
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: pct, backgroundColor: Colors.white.withOpacity(0.05), color: barColor, minHeight: 12)),
                      const SizedBox(height: 8),
                      Text(limitText, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12))
                    ]
                  )
                );
              }).toList(),
              
              const SizedBox(height: 32),
              const Text('Detailed Ledger', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (ledger.isEmpty) Text('No transactions yet.', style: TextStyle(color: Colors.white.withOpacity(0.5))),
              ...ledger.map((tx) {
                DateTime d = DateTime.parse(tx['date']);
                String dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
                bool isIncome = tx['type'] == 'INCOME';
                return Dismissible(
                  key: Key(tx['id'].toString()),
                  background: Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.red.withOpacity(0.5), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.delete, color: Colors.white)),
                  secondaryBackground: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.green.withOpacity(0.5), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.edit, color: Colors.white)),
                  confirmDismiss: (dir) async { if (dir == DismissDirection.startToEnd) { HapticFeedback.heavyImpact(); await widget.database.delete('transactions', where: 'id = ?', whereArgs: [tx['id']]); widget.onTransactionChanged(); return true; } else { HapticFeedback.lightImpact(); widget.onAddRequested(existingTx: tx); return false; } },
                  child: Container(
                  margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (isIncome ? const Color(0xFF10B981) : const Color(0xFFF43F5E)).withOpacity(0.15), shape: BoxShape.circle), child: Icon(isIncome ? Icons.download : Icons.upload, color: isIncome ? const Color(0xFF10B981) : const Color(0xFFF43F5E), size: 20)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tx['merchant'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), Text('${tx['category']} • $dateStr', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12))])),
                    Text('${isIncome ? '+' : '-'}₹${tx['amount']}', style: TextStyle(color: isIncome ? const Color(0xFF10B981) : const Color(0xFFF43F5E), fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                )
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}


// ---------------------------------------------------------
// PROFILE / SETTINGS SCREEN
// ---------------------------------------------------------
class ProfileScreen extends StatelessWidget {
  final Database database;
  final String currentPeriod;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onSetTotalBudget;
  final VoidCallback onAddBudget;
  final VoidCallback onAddGoal;
  final Function(Map<String, dynamic>) onGoalEdit;
  final VoidCallback onManageCategories;
  final VoidCallback onManageAccounts;
  final String userName;
  final VoidCallback onEditProfile;
  final bool isBiometricEnabled;
  final Function(bool) onToggleBiometric;
  final bool isClipboardSyncEnabled;
  final Function(bool) onToggleClipboardSync;
  final VoidCallback onOpenShortcutsGuide;
  final VoidCallback onPasteSms;

  const ProfileScreen({
    Key? key,
    required this.database,
    required this.currentPeriod,
    required this.onPeriodChanged,
    required this.onSetTotalBudget,
    required this.onAddBudget,
    required this.onAddGoal,
    required this.onGoalEdit,
    required this.onManageCategories,
    required this.onManageAccounts,
    required this.userName,
    required this.onEditProfile,
    required this.isBiometricEnabled,
    required this.onToggleBiometric,
    required this.isClipboardSyncEnabled,
    required this.onToggleClipboardSync,
    required this.onOpenShortcutsGuide,
    required this.onPasteSms,
  }) : super(key: key);


  Future<void> _exportToCsv(BuildContext context) async {
    String? selectedPeriod = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Export Data', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose a time period to export:', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ListTile(title: const Text('Last 1 Month', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(ctx, '1M')),
            ListTile(title: const Text('Last 3 Months', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(ctx, '3M')),
            ListTile(title: const Text('Last 6 Months', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(ctx, '6M')),
            ListTile(title: const Text('All Time', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(ctx, 'ALL')),
          ]
        )
      )
    );

    if (selectedPeriod == null) return;

    DateTime now = DateTime.now();
    DateTime cutoff;
    if (selectedPeriod == '1M') cutoff = DateTime(now.year, now.month - 1, now.day);
    else if (selectedPeriod == '3M') cutoff = DateTime(now.year, now.month - 3, now.day);
    else if (selectedPeriod == '6M') cutoff = DateTime(now.year, now.month - 6, now.day);
    else cutoff = DateTime(2000); 

    try {
      final List<Map<String, dynamic>> data = await database.query('transactions', where: 'date >= ?', whereArgs: [cutoff.toIso8601String()]);
      
      if (data.isEmpty) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No transactions found in this period.')));
        return;
      }
      
      String csv = 'ID,Date,Amount,Type,Category,Merchant,Account ID\n';
      for (var row in data) {
        String merchant = (row['merchant'] ?? '').toString().replaceAll('"', '""');
        csv += '${row['id']},${row['date']},${row['amount']},${row['type']},${row['category']},"${merchant}",${row['account_id'] ?? ''}\n';
      }
      
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/mone_export.csv';
      final file = File(path);
      await file.writeAsString(csv);
      
      await Share.shareXFiles([XFile(path)], text: 'My mone Transactions Export');
      
      if (!context.mounted) return;
      bool? doDelete = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          title: const Text('Purge Exported Data?', style: TextStyle(color: Colors.white)),
          content: const Text('Would you like to delete these exported transactions from the app to save space?\\n\\nYour Account Balances will NOT be affected and will remain perfectly accurate!', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Data', style: TextStyle(color: Colors.grey))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete Data', style: TextStyle(color: Colors.redAccent))),
          ]
        )
      );

      if (doDelete == true) {
         List<int> ids = data.map((e) => e['id'] as int).toList();
         String idString = ids.join(',');
         await database.delete('transactions', where: 'id IN ($idString)');
         if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transactions deleted. Balances remain intact.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      }
      
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: database.query('goals'),
      builder: (context, snapshot) {
        final goals = snapshot.data ?? [];

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(), padding: const EdgeInsets.only(left: 20, right: 20, top: 40, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF6366F1).withOpacity(0.2), border: Border.all(color: const Color(0xFF6366F1), width: 2)),
                    child: Center(child: Text(userName.isNotEmpty ? userName.substring(0, 1).toUpperCase() : 'U', style: const TextStyle(color: Color(0xFF818CF8), fontSize: 28, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(userName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const Text('Money OS User', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  ])),
                  IconButton(icon: const Icon(Icons.edit, color: Colors.grey), onPressed: onEditProfile),
                ],
              ),
              const SizedBox(height: 32),
              const Text('System Setup', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Material(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: [
                    ListTile(leading: const Icon(Icons.calendar_month, color: Color(0xFF8B5CF6)), title: const Text('View Analytics As', style: TextStyle(color: Colors.white)), trailing: DropdownButton<String>(dropdownColor: const Color(0xFF18181B), value: currentPeriod, style: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold), underline: const SizedBox(), items: ['Weekly', 'Monthly', 'Yearly'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => onPeriodChanged(val!))),
                    Divider(color: Colors.white.withOpacity(0.1), height: 1),
                    ListTile(onTap: onSetTotalBudget, leading: const Icon(Icons.account_balance, color: Color(0xFF10B981)), title: const Text('Overall Monthly Budget', style: TextStyle(color: Colors.white)), trailing: const Icon(Icons.edit, color: Colors.grey)),
                    Divider(color: Colors.white.withOpacity(0.1), height: 1),
                    ListTile(onTap: onAddBudget, leading: const Icon(Icons.track_changes, color: Color(0xFF6366F1)), title: const Text('Set Category Limits', style: TextStyle(color: Colors.white)), trailing: const Icon(Icons.add, color: Color(0xFF6366F1))),
                    Divider(color: Colors.white.withOpacity(0.1), height: 1),
                    ListTile(onTap: onManageCategories, leading: const Icon(Icons.category, color: Color(0xFFF59E0B)), title: const Text('Manage Categories', style: TextStyle(color: Colors.white)), trailing: const Icon(Icons.chevron_right, color: Colors.grey)),
                    Divider(color: Colors.white.withOpacity(0.1), height: 1),
                    ListTile(onTap: onManageAccounts, leading: const Icon(Icons.account_balance_wallet, color: Color(0xFF10B981)), title: const Text('Manage Accounts', style: TextStyle(color: Colors.white)), trailing: const Icon(Icons.chevron_right, color: Colors.grey)),
            const SizedBox(height: 12),
            const Text('Tools & Automation', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
                    ListTile(
                      onTap: onOpenShortcutsGuide,
                      leading: const Icon(Icons.bolt_rounded, color: Color(0xFF818CF8)),
                      title: const Text('Apple Shortcuts SMS Sync', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Setup instant background SMS capture via iOS Shortcuts', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    ),
                    Divider(color: Colors.white.withOpacity(0.1), height: 1),
                    SwitchListTile(
                      value: isClipboardSyncEnabled,
                      onChanged: onToggleClipboardSync,
                      secondary: const Icon(Icons.content_paste_rounded, color: Colors.greenAccent),
                      title: const Text('Clipboard Auto-Detection', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Scans copied bank SMS transaction alerts on app launch', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      activeColor: Colors.greenAccent,
                    ),
                    Divider(color: Colors.white.withOpacity(0.1), height: 1),
                    ListTile(
                      onTap: onPasteSms,
                      leading: const Icon(Icons.mark_email_read_rounded, color: Color(0xFFF59E0B)),
                      title: const Text('Paste Bank SMS Text', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Quick paste & parse any financial SMS message', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    ),
                    Divider(color: Colors.white.withOpacity(0.1), height: 1),
                    SwitchListTile(
                      value: isBiometricEnabled,
                      onChanged: onToggleBiometric,
                      secondary: const Icon(Icons.fingerprint, color: Colors.cyanAccent),
                      title: const Text('Biometric App Lock (Face ID)', style: TextStyle(color: Colors.white)),
                      activeColor: Colors.cyanAccent,
                    ),
                    Divider(color: Colors.white.withOpacity(0.1), height: 1),
                  ListTile(onTap: () => _exportToCsv(context), leading: const Icon(Icons.file_download, color: Colors.purpleAccent), title: const Text('Export Data to CSV', style: TextStyle(color: Colors.white)), subtitle: const Text('Share your transactions as a spreadsheet', style: TextStyle(color: Colors.grey, fontSize: 12)), trailing: const Icon(Icons.chevron_right, color: Colors.grey)),
                  Divider(color: Colors.white.withOpacity(0.1), height: 1),
                  ListTile(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HowToUseScreen())), leading: const Icon(Icons.help_outline, color: Colors.blueAccent), title: const Text('How to Use?', style: TextStyle(color: Colors.white)), trailing: const Icon(Icons.chevron_right, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('My Goals', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF6366F1), size: 30), onPressed: onAddGoal)]),
              const SizedBox(height: 16),
              ...goals.map((g) {
                double target = g['target']; double saved = g['saved']; double pct = (saved / target).clamp(0.0, 1.0);
                return GestureDetector(
                  onTap: () => onGoalEdit(g),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(32)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(g['title'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text('${(pct * 100).toInt()}%', style: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 16),
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: pct, backgroundColor: Colors.white.withOpacity(0.05), color: const Color(0xFF818CF8), minHeight: 12)),
                      const SizedBox(height: 12), Text('Saved: ₹${saved.toStringAsFixed(0)} / Target: ₹${target.toStringAsFixed(0)}', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                    ]),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      }
    );
  }
}

// ---------------------------------------------------------
// TRENDS SCREEN
// ---------------------------------------------------------
class TrendsScreen extends StatelessWidget {
  final Database database;
  final Function({Map<String, dynamic>? existingTx}) onAddRequested;
  final VoidCallback onTransactionChanged;

  const TrendsScreen({Key? key, required this.database, required this.onAddRequested, required this.onTransactionChanged}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: database.rawQuery('''
        SELECT strftime('%Y-%m', date) as month, SUM(amount) as total
        FROM transactions
        WHERE type = 'EXPENSE'
        GROUP BY month
        ORDER BY month DESC
      '''),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        
        double maxTotal = 0;
        for (var row in data) {
          double total = (row['total'] as num).toDouble();
          if (total > maxTotal) maxTotal = total;
        }
        
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(' Historical Trends', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              if (data.isEmpty) const Text('No data yet.', style: TextStyle(color: Colors.white54)),
              ...data.map((row) {
                String raw = row['month'] as String;
                double total = (row['total'] as num).toDouble();
                List<String> parts = raw.split('-');
                if (parts.length != 2) return const SizedBox();
                int m = int.parse(parts[1]);
                const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                String name = '${monthNames[m - 1]} ${parts[0]}';
                
                double pct = maxTotal > 0 ? (total / maxTotal) : 0;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (ctx) => Scaffold(
                        backgroundColor: const Color(0xFF09090B),
                        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text(''), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(ctx))),
                        body: AnalyticsScreen(database: database, timePeriod: 'Monthly', onResolveRollover: (a,b){}, onAddRequested: onAddRequested, onTransactionChanged: onTransactionChanged, overrideMonth: raw)
                      )));
                    },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10), 
                        child: LinearProgressIndicator(
                          value: pct, 
                          backgroundColor: Colors.white.withOpacity(0.05), 
                          color: const Color(0xFF8B5CF6), 
                          minHeight: 12
                        )
                      ),
                    ]
                  )
                ));
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}


class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        title: const Text('How to Use mone?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
             _buildFeatureCard(Icons.account_balance, 'Indian Banks Directory & Cards', 'Select from 25+ verified Indian banks (SBI, HDFC, ICICI, Axis, PNB, Kotak, etc.) with authentic corporate branding, official gradients, and individual card stacks.'),
             _buildFeatureCard(Icons.mark_email_unread_rounded, 'Real-Time SMS Auto-Sync', 'Intelligent background SMS reader automatically captures incoming debit & credit alerts via TRAI sender IDs, maps them to your accounts, and delivers instant notification feedback.'),
             _buildFeatureCard(Icons.account_balance_wallet_rounded, 'Available Balance & Accounts', 'Easily configure your exact available balance in Manage Accounts. Toggle accounts in your overall net worth or edit account credentials at any time.'),
             _buildFeatureCard(Icons.speed_rounded, 'Safe Spending Pacer', 'The intelligent pacer computes real-time daily safe spend allowances based on your active budget and days remaining in the billing cycle.'),
             _buildFeatureCard(Icons.vibration_rounded, 'Shake to Log Rapid Entry', 'Need to record an expense quickly? Shake your phone anywhere across the app to immediately open the rapid transaction logger.'),
             _buildFeatureCard(Icons.insights_rounded, 'Financial Intelligence & Diagnostics', 'Comprehensive cash flow analytics, category distributions, recurring cost anomaly detection, and automated micro-savings goal funding.'),
             _buildFeatureCard(Icons.compare_arrows_rounded, 'Transfers & ATM Cash Flow', 'Transfer funds between accounts or record ATM cash withdrawals without skewing your primary expense metrics or double-counting.'),
             _buildFeatureCard(Icons.fingerprint_rounded, 'Biometric Security & Export', 'Secure your financial ledger with biometric authentication (Fingerprint / Face ID) and export your complete transaction history to CSV at any time.'),
          ]
        )
      )
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(color: const Color(0xFF818CF8).withOpacity(0.2), shape: BoxShape.circle),
             child: Icon(icon, color: const Color(0xFF818CF8), size: 28)
           ),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 8),
                 Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
               ]
             )
           )
        ]
      )
    );
  }
}
