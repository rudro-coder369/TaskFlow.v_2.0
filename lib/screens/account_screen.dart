import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/progress_provider.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _supabase = Supabase.instance.client;
  final _usernameController = TextEditingController();
  
  bool _isSpecialUnlocked = false; // 🔥 দুইটা ফিচারের জন্য একটা ভেরিয়েবল
  bool _loading = true;
  bool _isEditing = false;
  
  String _userEmail = "";
  String _userName = "";
  String? _userId;

  final List<Map<String, dynamic>> _rankTiers = [
    { 'name': 'Legend', 'hours': '250h+', 'xp': '24,750+ XP', 'color': Colors.purple.shade600, 'bg': Colors.purple.shade50, 'border': Colors.purple.shade200 },
    { 'name': 'Emperor', 'hours': '150 - 250h', 'xp': '14,850 XP', 'color': Colors.red.shade600, 'bg': Colors.red.shade50, 'border': Colors.red.shade200 },
    { 'name': 'Prime', 'hours': '80 - 150h', 'xp': '7,920 XP', 'color': Colors.indigo.shade600, 'bg': Colors.indigo.shade50, 'border': Colors.indigo.shade200 },
    { 'name': 'Elite', 'hours': '40 - 80h', 'xp': '3,960 XP', 'color': Colors.orange.shade600, 'bg': Colors.orange.shade50, 'border': Colors.orange.shade200 },
    { 'name': 'Platinum', 'hours': '15 - 40h', 'xp': '1,485 XP', 'color': Colors.lightBlue.shade600, 'bg': Colors.lightBlue.shade50, 'border': Colors.lightBlue.shade200 },
    { 'name': 'Silver', 'hours': '0 - 15h', 'xp': '0 XP', 'color': Colors.grey.shade500, 'bg': Colors.grey.shade50, 'border': Colors.grey.shade200 }
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final prefs = await SharedPreferences.getInstance();
    // যেকোনো একটা চেক করলেই হবে, কারণ দুইটা একসাথেই আনলক হয়
    _isSpecialUnlocked = prefs.getBool('ioi_enabled') ?? false;

    final session = _supabase.auth.currentSession;
    if (session != null) {
      _userEmail = session.user.email ?? "";
      _userId = session.user.id;

      try {
        final data = await _supabase.from('profiles').select('username').eq('id', session.user.id).single();
        
        setState(() {
          _userName = data['username'] ?? "Scholar";
          _usernameController.text = _userName;
        });
      } catch (e) {
        debugPrint("Fetch User Error: $e");
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _handleSaveUsername() async {
    final newName = _usernameController.text.trim();
    if (newName.isEmpty || newName == _userName) {
      setState(() => _isEditing = false);
      return;
    }

    try {
      await _supabase.from('profiles').upsert({'id': _userId, 'username': newName});
      setState(() {
        _userName = newName;
        _isEditing = false;
      });
      if (mounted) {
         Provider.of<ProgressProvider>(context, listen: false).userProfile['username'] = newName;
         Provider.of<ProgressProvider>(context, listen: false).notifyListeners();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error updating username. It might be taken!")));
    }
  }

  // 🔥 নতুন মাস্টার আনলক মেথড
  Future<void> _toggleSpecialFeatures() async {
    if (!_isSpecialUnlocked) {
      String code = "";
      bool success = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Enter VIP Code"),
          content: TextField(
            onChanged: (val) => code = val,
            obscureText: true,
            decoration: const InputDecoration(hintText: "Enter secret code"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(onPressed: () => Navigator.pop(context, code == "369369"), child: const Text("Unlock")),
          ],
        ),
      ) ?? false;

      if (!success) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Incorrect code. Access Denied."), backgroundColor: Colors.red));
        return;
      }
    }

    final newStatus = !_isSpecialUnlocked;
    final prefs = await SharedPreferences.getInstance();
    
    // 🔥 একসাথে দুইটা মডিউল ডাটাবেসে অন/অফ হবে
    await prefs.setBool('ioi_enabled', newStatus);
    await prefs.setBool('level_up_enabled', newStatus);
    
    setState(() => _isSpecialUnlocked = newStatus);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newStatus ? "Titan Vault & IOI Prep Unlocked! 🎉" : "Special Features Disabled.")));
  }

  Future<void> _handleHardReset() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("⚠️ WARNING"),
        content: const Text("This will PERMANENTLY wipe your entire History, Leaderboard ranks, and Syllabus progress from the Database!"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Reset", style: TextStyle(color: Colors.white))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _loading = true);
    try {
      if (_userId != null) {
        await _supabase.from('daily_logs').delete().eq('user_id', _userId!);
        await _supabase.from('profiles').update({'syllabus_progress': {}}).eq('id', _userId!);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('active_task_id');
        await prefs.remove('active_task_start');

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hard Reset Complete! 🚀"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not complete Hard Reset."), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleLogout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pop(); // Back to main screen which will redirect to login
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: Color(0xFFF8FAFC), body: Center(child: Text("LOADING WORKSPACE...", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12))));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("Settings", style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          children: [
            // 🌟 COMPACT & COLORED PROFILE SECTION
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10A37F), Colors.teal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF10A37F).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(LucideIcons.user, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_isEditing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: _usernameController,
                            textAlign: TextAlign.center,
                            autofocus: true,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            decoration: const InputDecoration(
                              isDense: true, 
                              contentPadding: EdgeInsets.only(bottom: 4), 
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white, width: 2)), 
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white70))
                            ),
                            onSubmitted: (_) => _handleSaveUsername(),
                          ),
                        ),
                        IconButton(onPressed: _handleSaveUsername, icon: const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 24)),
                      ],
                    )
                  else
                    GestureDetector(
                      onTap: () => setState(() => _isEditing = true),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(width: 8),
                          const Icon(LucideIcons.edit2, size: 16, color: Colors.white70),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text(_userEmail, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ⚙️ SETTINGS ACTIONS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(24), 
                border: Border.all(color: Colors.grey.shade200), 
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Column(
                children: [
                  ListTile(
                    // 🔥 UI Update: ডাইনামিক আইকন এবং টেক্সট
                    leading: Icon(_isSpecialUnlocked ? LucideIcons.unlock : LucideIcons.lock, color: _isSpecialUnlocked ? const Color(0xFF10A37F) : Colors.grey),
                    title: const Text("Nutrition & Dev Modes", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    subtitle: const Text("Nutrition & IOI Prep Modules", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: ElevatedButton(
                      onPressed: _toggleSpecialFeatures,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSpecialUnlocked ? Colors.grey.shade100 : const Color(0xFF10A37F), 
                        foregroundColor: _isSpecialUnlocked ? Colors.grey.shade700 : Colors.white, 
                        elevation: 0, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                      ),
                      child: Text(_isSpecialUnlocked ? "Disable" : "Unlock", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Divider(color: Colors.grey.shade100, height: 1),
                  ListTile(
                    onTap: _handleHardReset,
                    leading: const Icon(LucideIcons.refreshCw, color: Colors.redAccent),
                    title: const Text("Erase Workspace", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    subtitle: const Text("Permanently delete all progress", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: const Text("Reset", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ),
                  Divider(color: Colors.grey.shade100, height: 1),
                  ListTile(
                    onTap: _handleLogout,
                    leading: const Icon(LucideIcons.logOut, color: Colors.grey),
                    title: const Text("Sign out", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 🏆 RANK TIERS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(24), 
                border: Border.all(color: Colors.grey.shade200), 
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.trophy, size: 20, color: Color(0xFF10A37F)), 
                      SizedBox(width: 8), 
                      Text("Rank Tiers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))
                    ]
                  ),
                  const SizedBox(height: 16),
                  ..._rankTiers.map((rank) => Container(
                    margin: const EdgeInsets.only(bottom: 12), 
                    padding: const EdgeInsets.all(12), 
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40, height: 40, 
                              decoration: BoxDecoration(color: rank['bg'], shape: BoxShape.circle, border: Border.all(color: rank['border'])), 
                              child: Icon(LucideIcons.medal, size: 18, color: rank['color'])
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start, 
                              children: [
                                Text(rank['name'], style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: rank['color'])), 
                                Row(
                                  children: [
                                    const Icon(LucideIcons.zap, size: 10, color: Colors.grey), 
                                    const SizedBox(width: 4), 
                                    Text("${rank['hours']} Focus", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey))
                                  ]
                                )
                              ]
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)), 
                          child: Text(rank['xp'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700))
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            const Text("TaskFlow App v2.0", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            const Text("© 2026 Rudro Sarkar", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}