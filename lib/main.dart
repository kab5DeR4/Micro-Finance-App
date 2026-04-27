import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

// Import your files
import 'theme/editorial_theme.dart';
import 'database/db_helper.dart';
import 'screens/brief_tab.dart';
import 'screens/portfolio_tab.dart';
import 'screens/pending_collections_tab.dart';
import 'screens/add_loan_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MicrofinanceApp());
}

class MicrofinanceApp extends StatelessWidget {
  const MicrofinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return MaterialApp(
          title: 'Bhumi Finance',
          themeMode: currentMode,

          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: EditorialTheme.bg,
            primaryColor: EditorialTheme.accent,
            fontFamily: EditorialTheme.fontBody,
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: EditorialTheme.textMain),
              bodyMedium: TextStyle(color: EditorialTheme.textMain),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: EditorialTheme.textMain,
              elevation: 0,
              centerTitle: false,
            ),
          ),

          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            primaryColor: const Color(0xFF00E676), // Vibrant mobile neo-green
            fontFamily: EditorialTheme.fontBody,
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white70),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
            ),
          ),

          home: const LoginScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;

  void _attemptLogin() async {
    setState(() => _isLoading = true);
    bool isValid = await DatabaseHelper.instance.login(
      _userController.text,
      _passController.text,
    );
    setState(() => _isLoading = false);

    if (isValid && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sign in failed.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    // --- MOBILE SPECIFIC LOGIN ---
    if (isMobile) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0F2027),
                Color(0xFF203A43),
                Color(0xFF2C5364),
              ], // Deep modern slate gradient
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00E676).withOpacity(0.2),
                        border: Border.all(
                          color: const Color(0xFF00E676).withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.eco,
                        color: Color(0xFF00E676),
                        size: 48,
                      ), // Vibrant Neon Green
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'bhumi finance',
                      style: TextStyle(
                        fontFamily: EditorialTheme.fontHeading,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Secure Executive Access',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 48),

                    // Glassmorphism effect inputs
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _userController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Username',
                          hintStyle: TextStyle(color: Colors.white38),
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: Colors.white54,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _passController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'PIN / Password',
                          hintStyle: TextStyle(color: Colors.white38),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: Colors.white54,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 10,
                          shadowColor: const Color(0xFF00E676).withOpacity(0.5),
                        ),
                        onPressed: _isLoading ? null : _attemptLogin,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.black,
                              )
                            : const Text(
                                "Authenticate",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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

    // --- PC SPECIFIC LOGIN (Untouched) ---
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xFF4CAF50),
                        child: Icon(Icons.eco, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'bhumi finance.',
                            style: TextStyle(
                              fontFamily: EditorialTheme.fontHeading,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : EditorialTheme.textMain,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to access your dashboard.',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white54 : EditorialTheme.textDim,
                    ),
                  ),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _userController,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: EditorialTheme.inputTheme('Username').copyWith(
                      fillColor: isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _passController,
                    obscureText: true,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: EditorialTheme.inputTheme('Password').copyWith(
                      fillColor: isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isLoading ? null : _attemptLogin,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Continue",
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
          ),
        ),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const CollectionScheduleTab(),
    const RegistryTab(),
    const PendingCollectionsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildThemeToggleButton() {
      return FloatingActionButton(
        heroTag: 'theme_toggle',
        mini: !isDesktop,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.amber : const Color(0xFF2E7D32),
        elevation: 4,
        tooltip: 'Toggle Theme',
        onPressed: () =>
            themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark,
        child: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
      );
    }

    if (isDesktop) {
      // --- PC NAVIGATION (Untouched) ---
      return Scaffold(
        floatingActionButton: buildThemeToggleButton(),
        body: Row(
          children: [
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1E1E)
                    : EditorialTheme.surface,
                border: Border(
                  right: BorderSide(
                    color: isDark ? Colors.white12 : EditorialTheme.border,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(0xFF4CAF50),
                          child: Icon(Icons.eco, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "bhumi finance.",
                              style: TextStyle(
                                fontFamily: EditorialTheme.fontHeading,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: isDark
                                    ? Colors.white
                                    : EditorialTheme.textMain,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _pcSideNavItem(
                    Icons.article_outlined,
                    Icons.article,
                    'The Daily Brief',
                    0,
                    isDark,
                  ),
                  _pcSideNavItem(
                    Icons.folder_outlined,
                    Icons.folder,
                    'Portfolio & Assets',
                    1,
                    isDark,
                  ),
                  _pcSideNavItem(
                    Icons.pending_actions_outlined,
                    Icons.pending_actions,
                    'Pending Collections',
                    2,
                    isDark,
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("New Portfolio"),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddLoanScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _screens[_currentIndex]),
          ],
        ),
      );
    } else {
      // --- MOBILE NAVIGATION (Redesigned Floating Pill) ---
      return Scaffold(
        extendBody: true, // Allows body to go behind the floating nav
        body: _screens[_currentIndex],

        // Floating Action Buttons stacked (Theme + Add)
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(
            bottom: 80,
          ), // Lift above the floating nav bar
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              buildThemeToggleButton(),
              const SizedBox(height: 16),
              FloatingActionButton(
                heroTag: 'add_portfolio',
                backgroundColor: const Color(0xFF00E676), // Vibrant Neon Green
                foregroundColor: Colors.black,
                elevation: 8,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddLoanScreen()),
                ),
                child: const Icon(Icons.add_rounded, size: 32),
              ),
            ],
          ),
        ),

        // Custom Floating Pill Bottom Nav
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E1E).withOpacity(0.9)
                  : Colors.black87,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _mobileNavItem(
                  Icons.dashboard_outlined,
                  Icons.dashboard_rounded,
                  'Brief',
                  0,
                ),
                _mobileNavItem(
                  Icons.folder_outlined,
                  Icons.folder_rounded,
                  'Vault',
                  1,
                ),
                _mobileNavItem(
                  Icons.notifications_none_rounded,
                  Icons.notifications_rounded,
                  'Tasks',
                  2,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _pcSideNavItem(
    IconData unselectedIcon,
    IconData selectedIcon,
    String label,
    int index,
    bool isDark,
  ) {
    bool isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? const Color(0xFF4CAF50).withOpacity(0.1)
                    : const Color(0xFFE8F5E9))
              : Colors.transparent,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
          border: isSelected
              ? const Border(
                  left: BorderSide(color: Color(0xFF4CAF50), width: 4),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected
                  ? (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
                  : (isDark ? Colors.white54 : EditorialTheme.textDim),
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (isDark
                          ? const Color(0xFF81C784)
                          : const Color(0xFF2E7D32))
                    : (isDark ? Colors.white54 : EditorialTheme.textDim),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileNavItem(
    IconData unselectedIcon,
    IconData selectedIcon,
    String label,
    int index,
  ) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 12,
          vertical: 8,  
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E676).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected ? const Color(0xFF00E676) : Colors.white54,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF00E676),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
