import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../public_profile_screen.dart';

class GlobalFlowZone extends StatefulWidget {
  final String? myCurrentChapter;
  final String? myCurrentSubject;
  final String? mySchool;

  const GlobalFlowZone({super.key, this.myCurrentChapter, this.myCurrentSubject, this.mySchool});

  @override
  State<GlobalFlowZone> createState() => _GlobalFlowZoneState();
}

class _GlobalFlowZoneState extends State<GlobalFlowZone> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _liveRoomChannel;
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _allActiveUsers = [];
  final Color _primaryGreen = const Color(0xFF10A37F);

  @override
  void initState() {
    super.initState();
    _fetchLiveUsers();
    _setupRealtimeSubscription();
  }

  // ==========================================
  // 🧠 CORE LOGIC: STRICT FILTERING & OPTIMIZATION
  // ==========================================
  Future<void> _fetchLiveUsers() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();

    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return;

      // 🔥 PERFORMANCE FIX: Added .limit(300) to prevent RAM overload with 10k users
      final res = await _supabase
          .from('profiles')
          .select('id, username, active_task, avatar_seed, active_subject') 
          .not('active_task', 'is', null)
          .gte('task_expires_at', nowIso)
          .order('task_expires_at', ascending: true) // যারা আগে থেকে পড়ছে তারা উপরে থাকবে
          .limit(300); 
          
      final liveData = List<Map<String, dynamic>>.from(res);

      List<Map<String, dynamic>> activeUsers = [];
      Map<String, dynamic>? myData;

      for (var user in liveData) {
        if (user['id'] == myId) {
          myData = user; 
          continue;
        }
        activeUsers.add(user);
      }

      // আমি যদি লাইভ থাকি, আমাকে ১ নম্বর সিটে বসাবে
      if (myData != null) {
        activeUsers.insert(0, myData);
      }

      if (mounted) {
        setState(() {
          _allActiveUsers = activeUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Live Room Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeSubscription() {
    _liveRoomChannel = _supabase.channel('public:profiles_live_room_global').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'profiles',
      callback: (payload) => _fetchLiveUsers(),
    ).subscribe();
  }

  @override
  void dispose() {
    _liveRoomChannel?.unsubscribe();
    super.dispose();
  }

  String _formatName(String? name) {
    if (name == null || name.trim().isEmpty) return "Scholar";
    return name.trim().split(' ')[0][0].toUpperCase() + name.trim().split(' ')[0].substring(1).toLowerCase();
  }

  // ==========================================
  // 📱 MAIN UI: OPTIMIZED WHITE & GREEN THEME
  // ==========================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _primaryGreen, strokeWidth: 2));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Clean White/Grey Background
      body: RefreshIndicator(
        onRefresh: _fetchLiveUsers,
        color: _primaryGreen,
        backgroundColor: Colors.white,
        child: Stack(
          children: [
            // 🔥 PERFORMANCE FIX: Removed heavy BackdropFilter blur, used smooth RadialGradient
            Positioned(
              top: -100, left: -50, 
              child: Container(
                width: 300, height: 300, 
                decoration: BoxDecoration(
                  shape: BoxShape.circle, 
                  gradient: RadialGradient(colors: [_primaryGreen.withOpacity(0.08), Colors.transparent])
                )
              )
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🟢 ACTIVE USERS COUNT HEADER
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: _primaryGreen.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(LucideIcons.radio, color: _primaryGreen, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("LIVE NOW", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
                          const SizedBox(height: 2),
                          Text("${_allActiveUsers.length} Students Focusing", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        ],
                      )
                    ],
                  ),
                ),

                // 📜 SCROLLABLE LIST
                Expanded(
                  child: _allActiveUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.moon, size: 40, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text("It's quiet. Start a session to lead the board.", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        // 🔥 PERFORMANCE FIX: AlwaysScrollableScrollPhysics for smooth 60fps scrolling
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _allActiveUsers.length,
                        itemBuilder: (context, index) {
                          final user = _allActiveUsers[index];
                          final isMe = user['id'] == _supabase.auth.currentUser?.id;
                          return _buildLiveUserCard(user, isMe: isMe);
                        },
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 🎨 USER CARD WIDGET (Minimal Solid Design)
  // ==========================================
  Widget _buildLiveUserCard(Map<String, dynamic> user, {bool isMe = false}) {
    final name = isMe ? "You" : _formatName(user['username']);
    final chapter = user['active_task'] ?? "Deep Work";
    final avatarSeed = user['avatar_seed'] ?? "Felix";
    final subject = user['active_subject'] ?? "Focus";

    return GestureDetector(
      onTap: () {
        if (!isMe) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(targetUserId: user['id'].toString())));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16), 
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: isMe ? _primaryGreen.withOpacity(0.4) : Colors.grey.shade200, width: isMe ? 1.5 : 1), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22, 
              backgroundColor: Colors.grey.shade100, 
              backgroundImage: NetworkImage('https://api.dicebear.com/8.x/notionists/png?seed=$avatarSeed&backgroundColor=f8fafc'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis), 
                  const SizedBox(height: 4),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(text: "${subject.toUpperCase()} • ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _primaryGreen)),
                        TextSpan(text: chapter, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isMe ? _primaryGreen.withOpacity(0.1) : Colors.orange.shade50, 
                shape: BoxShape.circle
              ),
              child: Icon(LucideIcons.flame, color: isMe ? _primaryGreen : Colors.orange.shade500, size: 18),
            )
          ],
        ),
      ),
    );
  }
}