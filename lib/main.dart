import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart'; 

// Providers
import 'providers/progress_provider.dart';
import 'providers/clan_provider.dart'; 
import 'providers/elite_stats_provider.dart';
import 'providers/timer_provider.dart'; // 🔥 ADDED TIMER PROVIDER

// Screens
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/syllabus_screen.dart';
import 'screens/timer_screen.dart';
import 'screens/history_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/account_screen.dart'; 
import 'screens/routine_screen.dart'; 
import 'screens/live_room/live_room_screen.dart'; 
import 'screens/clan/clan_dashboard_screen.dart'; 
import 'screens/blocker/blocker_dashboard_screen.dart'; 

// Services
import 'services/background_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (Random().nextBool()) {
      final FlutterLocalNotificationsPlugin localNotif = FlutterLocalNotificationsPlugin();
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'reminder_task',
        'Study Reminders',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFF10A37F),
        showWhen: true,
      );
      const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
      await localNotif.show(999, 'Qaave', 'ভুলে গেলি আমাকে? আয় পড়তে বস, পড়তে হবে, নকল আর হবে না।', platformDetails);
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  await initializeService();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  
  await Workmanager().registerPeriodicTask(
    "random_reminder_task",
    "studyReminder",
    frequency: const Duration(hours: 3),
  );

  await Supabase.initialize(
    url: 'https://mllsdlbhxetctblonfec.supabase.co',
    anonKey: 'sb_publishable_G3pnWovIAJeeiegVifAY7Q_3Zl9PNwj',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProgressProvider()),
        ChangeNotifierProvider(create: (_) => ClanProvider()), 
        ChangeNotifierProvider(create: (_) => EliteStatsProvider()),
        ChangeNotifierProvider(create: (_) => TimerProvider()), // 🔥 CONNECTED
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
      title: 'Qaave', 
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
        return session != null ? const MainNavigation() : const LoginScreen();
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

  final List<Widget> _screens = [
    const DashboardScreen(),
    const SyllabusScreen(),
    const TimerScreen(),
    const HistoryScreen(),
    const LiveRoomScreen(myCurrentChapter: null), 
    const LeaderboardScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProgressProvider>(context, listen: false).fetchProfileData();
      Provider.of<ClanProvider>(context, listen: false).fetchMyClanData();
    });
  }

  Future<void> _handleRefresh() async {
    await Provider.of<ProgressProvider>(context, listen: false).fetchProfileData();
    await Provider.of<ClanProvider>(context, listen: false).fetchMyClanData(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset('assets/qaave_logo.png', width: 36, height: 36, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            const Text("Qaave", style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(LucideIcons.calendarDays, color: Color(0xFF10A37F)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutineScreen()))),
          IconButton(icon: const Icon(LucideIcons.shieldAlert, color: Color(0xFF10A37F)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockerDashboardScreen()))),
          IconButton(icon: const Icon(LucideIcons.users, color: Color(0xFF10A37F)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClanDashboardScreen()))),
          IconButton(icon: const Icon(LucideIcons.user, color: Color(0xFF64748B)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()))),
          const SizedBox(width: 8), 
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: const Color(0xFF10A37F),
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, LucideIcons.home, "Home"),
                _buildNavItem(1, LucideIcons.bookOpen, "Syllabus"),
                _buildNavItem(2, LucideIcons.clock, "Focus"),
                _buildNavItem(3, LucideIcons.history, "History"),
                _buildNavItem(4, LucideIcons.radio, "Live"), // 🔥 Live now GREEN
                _buildNavItem(5, LucideIcons.activity, "Rank"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF10A37F) : const Color(0xFF94A3B8);
    
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}