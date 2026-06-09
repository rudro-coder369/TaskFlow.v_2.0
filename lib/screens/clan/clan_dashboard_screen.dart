import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==========================================
// 📂 IMPORT ALL OUR MODULAR FILES
// ==========================================
// 1. Service Layer (The Brain)
import 'services/clan_database_service.dart';

// 2. Main Views (The Tabs)
import 'views/clan_home_view.dart';
import 'views/clan_arena_view.dart';
import 'views/clan_leader_board_view.dart';
import 'views/clan_squad_view.dart';

// 3. Widgets (Reusable UI)
import 'widgets/clan_bottom_nav.dart';

// 4. Actions (Popups & Screens)
import 'actions/search_clan_screen.dart';
import 'actions/notification_screen.dart';

class ClanDashboardScreen extends StatefulWidget {
  const ClanDashboardScreen({super.key});

  @override
  State<ClanDashboardScreen> createState() => _ClanDashboardScreenState();
}

class _ClanDashboardScreenState extends State<ClanDashboardScreen> {
  // 🔥 Service Injection
  final ClanDatabaseService _dbService = ClanDatabaseService();
  
  bool _isLoading = true;
  int _currentIndex = 0; // App-in-App Navigation State
  
  // Data Variables
  Map<String, dynamic>? _myClan;
  Map<String, dynamic>? _myRoleInfo;
  String _userRegisteredSchool = "Loading...";

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // ==========================================
  // 🧠 DATA FETCHING (Cleaned up using Service Layer)
  // ==========================================
  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // 1. Get School Identity
      _userRegisteredSchool = await _dbService.getUserSchool(userId) ?? "Unknown School";

      // 2. Get Clan Details
      final details = await _dbService.getUserClanDetails(userId);

      if (details != null) {
        _myRoleInfo = details['roleInfo'];
        _myClan = details['clanData'];
      } else {
        _myClan = null;
        _myRoleInfo = null;
      }
    } catch (e) {
      debugPrint("Dashboard Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // 🎮 MAIN BUILD: THE APP-IN-APP WRAPPER
  // ==========================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0F19), // Dark E-sports Theme
        body: Center(child: CircularProgressIndicator(color: Color(0xFF10A37F))),
      );
    }

    // ⛔ VIEW 1: STRICT ONBOARDING (No Clan)
    if (_myClan == null) {
      return _buildNoClanView();
    }

    // 👑 VIEW 2: HAS CLAN (The Main Game Interface)
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: _buildGameAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _getInnerView(_currentIndex),
      ),
      // 🔥 Our Custom Modular Bottom Nav
      bottomNavigationBar: ClanBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }

  // ==========================================
  // ⛔ NO CLAN VIEW (Strict Identity Screen)
  // ==========================================
  Widget _buildNoClanView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context), // Exit Warzone
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.bell, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => NotificationScreen(hasClan: false, userRole: null)
              ));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFF10A37F).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(LucideIcons.shield, size: 64, color: Color(0xFF10A37F)),
            ),
            const SizedBox(height: 32),
            const Text("ENTER THE WARZONE", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            const Text(
              "You can only represent the institution registered in your profile. Mercenaries are strictly prohibited.", 
              textAlign: TextAlign.center, 
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5)
            ),
            const SizedBox(height: 32),
            
            // 🏫 Strict Identity Lock Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12)
              ),
              child: Column(
                children: [
                  const Text("YOUR VERIFIED INSTITUTION", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text(_userRegisteredSchool.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // 🚀 Action Buttons
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // Route to Search Screen with strict parameter
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => SearchClanScreen(userSchool: _userRegisteredSchool)
                  ));
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10A37F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text("Join Existing Squad", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () {
                  // TODO: Show Create Clan Logic (Will use _dbService.createClan)
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Create Clan feature coming next!")));
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade800, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Found a New Clan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 🛡️ APP BAR COMPONENTS
  // ==========================================
  PreferredSizeWidget _buildGameAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0B0F19),
      elevation: 0,
      centerTitle: true,
      title: const Text("WARZONE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 2)),
      leading: IconButton(
        icon: const Icon(LucideIcons.logOut, color: Colors.redAccent, size: 20),
        tooltip: "Exit Warzone",
        onPressed: () => Navigator.pop(context), // Back to main app
      ),
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(LucideIcons.bell, color: Colors.white),
              onPressed: () {
                // Route to Command Inbox
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => NotificationScreen(
                    hasClan: true, 
                    userRole: _myRoleInfo?['role']
                  )
                ));
              },
            ),
            // Dummy Notification Badge
            Positioned(
              right: 12, top: 12,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Text("2", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            )
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ==========================================
  // 📂 MODULAR VIEWS ROUTER
  // ==========================================
  Widget _getInnerView(int index) {
    // We are injecting data into the isolated view files
    switch (index) {
      case 0: 
        return ClanHomeView(clanData: _myClan!, roleInfo: _myRoleInfo!);
      case 1: 
        return ClanArenaView(clanData: _myClan!);
      case 2: 
        return ClanLeaderboardView(clanData: _myClan!);
      case 3: 
        return ClanSquadView(clanData: _myClan!, roleInfo: _myRoleInfo!);
      default: 
        return const SizedBox();
    }
  }
}