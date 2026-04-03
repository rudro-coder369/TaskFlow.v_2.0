import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/progress_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/syllabus_screen.dart';
import 'screens/timer_screen.dart';
import 'screens/history_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/account_screen.dart'; 
import 'screens/ioi_prep_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase Setup
  await Supabase.initialize(
    url: 'https://mllsdlbhxetctblonfec.supabase.co',
    anonKey: 'sb_publishable_G3pnWovIAJeeiegVifAY7Q_3Zl9PNwj',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProgressProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto', 
        primaryColor: const Color(0xFF10A37F),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0, 
          surfaceTintColor: Colors.transparent, 
          iconTheme: IconThemeData(color: Color(0xFF1E293B)),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF10A37F))));
        }
        final session = snapshot.data?.session;
        if (session != null) {
          Provider.of<ProgressProvider>(context, listen: false).fetchProfileData();
          return const MainNavigation();
        }
        return const LoginScreen();
      },
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
  bool _isIoiEnabled = false;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const SyllabusScreen(),
    const TimerScreen(),
    const HistoryScreen(),
    const LeaderboardScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkIoiStatus();
  }

  // IOI State check
  Future<void> _checkIoiStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isIoiEnabled = prefs.getBool('ioi_enabled') ?? false;
      });
    }
  }

  // Pull-to-Refresh logic
  Future<void> _handleRefresh() async {
    await Provider.of<ProgressProvider>(context, listen: false).fetchProfileData();
    await _checkIoiStatus();
    setState(() {}); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top Navbar (AppBar)
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(LucideIcons.checkCircle, color: Color(0xFF10A37F), size: 24),
            SizedBox(width: 8),
            Text("TaskFlow", style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        actions: [
          // IOI Prep Icon
          if (_isIoiEnabled)
            IconButton(
              icon: const Icon(LucideIcons.code, color: Color(0xFF10A37F)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const IoiPrepScreen()));
              },
            ),
          
          // Account/Profile Icon
          IconButton(
            icon: const Icon(LucideIcons.user, color: Color(0xFF64748B)),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
              _checkIoiStatus();
            },
          ),
          const SizedBox(width: 8), 
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: const Color(0xFF10A37F),
        backgroundColor: Colors.white,
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),

      // Premium Bottom Footer 
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          border: Border(top: BorderSide(color: Colors.lightBlue.shade50)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, LucideIcons.home, "Home"),
                _buildNavItem(1, LucideIcons.bookOpen, "Syllabus"),
                _buildNavItem(2, LucideIcons.clock, "Focus"),
                _buildNavItem(3, LucideIcons.history, "History"),
                _buildNavItem(4, LucideIcons.activity, "Rank"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10), 
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF10A37F).withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 22, 
              color: isSelected ? const Color(0xFF10A37F) : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? const Color(0xFF10A37F) : const Color(0xFF94A3B8),
            ),
          )
        ],
      ),
    );
  }
}