import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'public_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _supabase = Supabase.instance.client;
  
  // Tabs: 0 = Daily, 1 = Clan (7d), 2 = Lifetime
  int _selectedTab = 0; 
  
  List<Map<String, dynamic>> _dailyLeaders = [];
  List<Map<String, dynamic>> _clanLeaders = [];
  List<Map<String, dynamic>> _lifetimeLeaders = [];
  
  bool _loading = true;
  String _searchQuery = "";
  
  // Swipeable Bottom Banner State
  bool _showMyRankBanner = false; 
  
  // User Rank Trackers
  int? _myDailyRank;
  int? _myClanRank;
  int? _myLifetimeRank;
  String? _myClanName;

  DateTime _now = DateTime.now();
  bool _isTimeSynced = false;
  Duration _timeOffset = Duration.zero;
  String _currentDateStr = "";
  
  Timer? _clockTimer;
  Timer? _debounceTimer;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _syncRealBangladeshTime();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _debounceTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _syncRealBangladeshTime() async {
    if (!mounted) return;
    setState(() => _loading = true);

    Duration offset = Duration.zero;
    try {
      final res1 = await http.get(Uri.parse('https://timeapi.io/api/Time/current/zone?timeZone=Asia/Dhaka')).timeout(const Duration(seconds: 5));
      if (res1.statusCode == 200) {
        final data = jsonDecode(res1.body);
        final realTime = DateTime.parse(data['dateTime'] + "+06:00");
        offset = realTime.difference(DateTime.now());
      } else {
        throw Exception("API 1 Failed");
      }
    } catch (e1) {
      try {
        final res2 = await http.get(Uri.parse('https://worldtimeapi.org/api/timezone/Asia/Dhaka')).timeout(const Duration(seconds: 5));
        if (res2.statusCode == 200) {
          final data = jsonDecode(res2.body);
          final realTime = DateTime.parse(data['datetime']);
          offset = realTime.difference(DateTime.now());
        }
      } catch (e2) {
        debugPrint("Time APIs blocked. Using local time fallback.");
      }
    }

    if (mounted) {
      setState(() {
        _timeOffset = offset;
        _isTimeSynced = true;
        _now = DateTime.now().add(_timeOffset);
        _currentDateStr = DateFormat('dd/MM/yyyy').format(_now); 
      });

      await _fetchAllLeaderboards();

      _clockTimer?.cancel();
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _now = DateTime.now().add(_timeOffset);
          });
        }
      });
    }
  }

  void _setupRealtimeSubscription() {
    _channel = _supabase.channel('public:daily_logs').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'daily_logs',
      callback: (payload) {
        if (_currentDateStr.isNotEmpty) {
          if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
          _debounceTimer = Timer(const Duration(seconds: 3), () {
            _fetchAllLeaderboards();
          });
        }
      },
    ).subscribe();
  }

  Future<void> _fetchAllLeaderboards() async {
    if (!mounted) return;
    final myId = _supabase.auth.currentUser!.id;
    
    try {
      final sevenDaysAgo = _now.subtract(const Duration(days: 7));

      final profRes = await _supabase.from('profiles').select('id, username, avatar_seed, clan_name');
      Map<String, Map<String, dynamic>> profiles = {};
      for (var p in (profRes as List)) {
        profiles[p['id'].toString()] = p;
        if (p['id'].toString() == myId) _myClanName = p['clan_name']?.toString();
      }

      // 🔥 Removed 30 days limit. Now fetches 100% Lifetime Data
      final logsRes = await _supabase
          .from('daily_logs')
          .select('user_id, study_seconds, self_study_seconds, class_seconds, date_str, created_at');
          
      final allLogs = logsRes as List;

      Map<String, Map<String, dynamic>> dailyUserSecs = {};
      Map<String, Map<String, dynamic>> lifetimeUserSecs = {};
      Map<String, int> clanWeeklySecs = {};

      for (var log in allLogs) {
        final uid = log['user_id']?.toString();
        if (uid == null) continue;

        final secs = int.tryParse(log['study_seconds']?.toString() ?? '0') ?? 0;
        final selfSecs = int.tryParse(log['self_study_seconds']?.toString() ?? '0') ?? 0;
        final classSecs = int.tryParse(log['class_seconds']?.toString() ?? '0') ?? 0;
        
        final dateStr = log['date_str']?.toString() ?? '';
        final createdAtStr = log['created_at']?.toString() ?? _now.toIso8601String();
        final createdAt = DateTime.tryParse(createdAtStr) ?? _now;
        
        final username = profiles[uid]?['username']?.toString() ?? 'Scholar';
        final avatar = profiles[uid]?['avatar_seed']?.toString() ?? 'Felix';
        final clanName = profiles[uid]?['clan_name']?.toString();

        // 1. Lifetime (No limits)
        if (!lifetimeUserSecs.containsKey(uid)) {
           lifetimeUserSecs[uid] = {'user_id': uid, 'totalSecs': 0, 'name': username, 'avatar_seed': avatar};
        }
        lifetimeUserSecs[uid]!['totalSecs'] = (lifetimeUserSecs[uid]!['totalSecs'] as int) + secs;

        // 2. Daily
        if (dateStr == _currentDateStr) {
          if (!dailyUserSecs.containsKey(uid)) {
             dailyUserSecs[uid] = {'user_id': uid, 'totalSecs': 0, 'self_secs': 0, 'class_secs': 0, 'name': username, 'avatar_seed': avatar};
          }
          dailyUserSecs[uid]!['totalSecs'] = (dailyUserSecs[uid]!['totalSecs'] as int) + secs;
          dailyUserSecs[uid]!['self_secs'] = (dailyUserSecs[uid]!['self_secs'] as int) + selfSecs;
          dailyUserSecs[uid]!['class_secs'] = (dailyUserSecs[uid]!['class_secs'] as int) + classSecs;
        }

        // 3. Clan (Strictly 7 Days)
        if (createdAt.isAfter(sevenDaysAgo) || dateStr == _currentDateStr) {
          if (clanName != null && clanName.trim().isNotEmpty) {
            clanWeeklySecs[clanName] = (clanWeeklySecs[clanName] ?? 0) + secs;
          }
        }
      }

      // Formatting and Sorting Daily
      List<Map<String, dynamic>> tempDaily = dailyUserSecs.values.toList();
      for (var u in tempDaily) {
        u['lifetime_secs'] = lifetimeUserSecs[u['user_id']]?['totalSecs'] ?? u['totalSecs'] ?? 0;
      }
      tempDaily.sort((a, b) => (b['totalSecs'] as int).compareTo(a['totalSecs'] as int));
      int? dRank;
      for (int i = 0; i < tempDaily.length; i++) {
        if (tempDaily[i]['user_id'] == myId) dRank = i + 1;
      }

      // Formatting and Sorting Lifetime
      List<Map<String, dynamic>> tempLifetime = lifetimeUserSecs.values.toList();
      for (var u in tempLifetime) {
        u['lifetime_secs'] = u['totalSecs'] ?? 0; 
      }
      tempLifetime.sort((a, b) => (b['totalSecs'] as int).compareTo(a['totalSecs'] as int));
      int? lRank;
      for (int i = 0; i < tempLifetime.length; i++) {
        if (tempLifetime[i]['user_id'] == myId) lRank = i + 1;
      }

      // Formatting and Sorting Clan
      List<Map<String, dynamic>> tempClan = clanWeeklySecs.entries.map((e) {
        return {'clan_name': e.key, 'name': e.key, 'totalSecs': e.value};
      }).toList();
      tempClan.sort((a, b) => (b['totalSecs'] as int).compareTo(a['totalSecs'] as int));
      int? cRank;
      if (_myClanName != null && _myClanName!.trim().isNotEmpty) {
        for (int i = 0; i < tempClan.length; i++) {
          if (tempClan[i]['clan_name'] == _myClanName) cRank = i + 1;
        }
      }

      if (mounted) {
        setState(() {
          _dailyLeaders = tempDaily;
          _lifetimeLeaders = tempLifetime;
          _clanLeaders = tempClan;
          _myDailyRank = dRank;
          _myLifetimeRank = lRank;
          _myClanRank = cRank;
          _loading = false;
          _showMyRankBanner = true; 
        });

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _showMyRankBanner = false);
          }
        });
      }
    } catch (e) {
      debugPrint("Leaderboard Fetch Error: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  // 🚀 XP & RANK CALCULATION
  Map<String, dynamic> _calculateEliteStats(int totalSeconds) {
    final hours = totalSeconds / 3600;
    final level = (hours / 2).floor() + 1;
    final finalXp = (hours * 99).floor();

    Map<String, dynamic> rank = {
      'name': 'Silver',
      'color': Colors.grey.shade600,
      'bg': Colors.grey.shade100,
      'border': Colors.grey.shade200,
    };
    if (finalXp >= 24750) { 
      rank = {'name': 'Legend', 'color': Colors.purple.shade600, 'bg': Colors.purple.shade50, 'border': Colors.purple.shade200}; 
    } else if (finalXp >= 14850) { 
      rank = {'name': 'Emperor', 'color': Colors.red.shade600, 'bg': Colors.red.shade50, 'border': Colors.red.shade200}; 
    } else if (finalXp >= 7920) { 
      rank = {'name': 'Prime', 'color': Colors.indigo.shade600, 'bg': Colors.indigo.shade50, 'border': Colors.indigo.shade200}; 
    } else if (finalXp >= 3960) { 
      rank = {'name': 'Elite', 'color': Colors.orange.shade600, 'bg': Colors.orange.shade50, 'border': Colors.orange.shade200}; 
    } else if (finalXp >= 1485) { 
      rank = {'name': 'Platinum', 'color': Colors.lightBlue.shade600, 'bg': Colors.lightBlue.shade50, 'border': Colors.lightBlue.shade200}; 
    }

    return {'level': level, 'finalXp': finalXp, 'rank': rank};
  }

  String _formatStudyTime(dynamic seconds) {
    final secs = int.tryParse(seconds?.toString() ?? '0') ?? 0;
    if (secs <= 0) return "0m";
    final h = (secs / 3600).floor();
    final m = ((secs % 3600) / 60).floor();
    if (h > 0) return "${h}h ${m}m";
    return "${m}m";
  }

  String _formatName(dynamic name) {
    if (name == null || name.toString().trim().isEmpty) return "Scholar";
    String n = name.toString().trim().split(' ')[0];
    return n[0].toUpperCase() + n.substring(1).toLowerCase();
  }

  String _getOrdinal(int num) {
    if (num >= 11 && num <= 13) return '${num}th';
    switch (num % 10) {
      case 1: return '${num}st';
      case 2: return '${num}nd';
      case 3: return '${num}rd';
      default: return '${num}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMM yyyy').format(_now); 
    final formattedTime = DateFormat('hh:mm a').format(_now);

    List<Map<String, dynamic>> displayList = [];
    int? currentRankHighlight;
    String highlightPrefix = "";

    if (_selectedTab == 0) {
      displayList = _dailyLeaders;
      currentRankHighlight = _myDailyRank;
      highlightPrefix = "Your rank is";
    } else if (_selectedTab == 1) {
      displayList = _clanLeaders;
      currentRankHighlight = _myClanRank;
      highlightPrefix = "Your clan rank is";
    } else if (_selectedTab == 2) {
      displayList = _lifetimeLeaders;
      if (_searchQuery.trim().isNotEmpty) {
        displayList = displayList.where((u) => (u['name']?.toString().toLowerCase() ?? '').contains(_searchQuery.toLowerCase())).toList();
      }
      currentRankHighlight = _myLifetimeRank;
      highlightPrefix = "Your rank is";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), 
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 1. TOP HEADER & TIME
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.lightBlue.shade50.withOpacity(0.6),
                      border: Border.all(color: Colors.lightBlue.shade100),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _isTimeSynced
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.calendarClock, size: 16, color: Color(0xFF10A37F)),
                              const SizedBox(width: 8),
                              Text("$formattedDate  •  $formattedTime", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            ],
                          )
                        : const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10A37F))),
                  ),
                ),

                // 2. THE THREE TABS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton(0, "Daily"),
                        _buildTabButton(1, "Clan (7d)"),
                        _buildTabButton(2, "Lifetime"),
                      ],
                    ),
                  ),
                ),

                // 3. SEARCH BAR (Only for Lifetime)
                if (_selectedTab == 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: "Search scholar by username...",
                        prefixIcon: const Icon(LucideIcons.search, size: 18, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF10A37F))),
                      ),
                    ),
                  ),

                // 4. MAIN LIST AREA
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 40, child: Center(child: Text("RANK", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)))),
                      Expanded(child: Text(_selectedTab == 1 ? "CLAN NAME" : "SCHOLAR PROFILE", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1))),
                      const Text("FOCUS TIME", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                    ],
                  ),
                ),

                Expanded(
                  child: (_loading)
                    ? const Center(child: Text("FETCHING STANDINGS...", style: TextStyle(color: Color(0xFF10A37F), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)))
                    : displayList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.trophy, size: 40, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Text("NO FOCUS SESSIONS YET", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                              const SizedBox(height: 4),
                              const Text("Be the first to claim the top spot!", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), 
                          physics: const BouncingScrollPhysics(),
                          itemCount: displayList.length,
                          itemBuilder: (context, index) {
                            return _buildUnifiedListTile(displayList[index], index + 1);
                          },
                        ),
                ),
              ],
            ),

            // 5. SWIPEABLE STICKY HIGHLIGHT BANNER
            if (!_loading && currentRankHighlight != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                bottom: _showMyRankBanner ? 0 : -60,
                left: 0, right: 0,
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    if (details.delta.dy > 5) {
                      setState(() => _showMyRankBanner = false); // Swipe Down
                    } else if (details.delta.dy < -5) {
                      setState(() => _showMyRankBanner = true); // Swipe Up
                    }
                  },
                  onTap: () {
                    setState(() => _showMyRankBanner = !_showMyRankBanner);
                  },
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10A37F),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag Handle Pill
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 4),
                            width: 36, height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10)
                            ),
                          ),
                        ),
                        // Main Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                                child: const Icon(LucideIcons.medal, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(highlightPrefix, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                  Text(_getOrdinal(currentRankHighlight), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  Widget _buildTabButton(int index, String label) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
            _searchQuery = "";
            _showMyRankBanner = true; 
          });
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _selectedTab == index) {
              setState(() => _showMyRankBanner = false);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10A37F) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 INDIVIDUAL USER CARDS
  Widget _buildUnifiedListTile(Map<String, dynamic> data, int pos) {
    final isClan = _selectedTab == 1;
    final isDaily = _selectedTab == 0;
    
    final int lifetimeSecs = int.tryParse(data['lifetime_secs']?.toString() ?? '0') ?? int.tryParse(data['totalSecs']?.toString() ?? '0') ?? 0;
    final stats = isClan ? null : _calculateEliteStats(lifetimeSecs);
    
    final isTop3 = pos <= 3;
    final isMe = !isClan && data['user_id'] == _supabase.auth.currentUser!.id;
    final avatarSeed = data['avatar_seed']?.toString() ?? 'Felix';

    final int selfSecs = isDaily ? (int.tryParse(data['self_secs']?.toString() ?? '0') ?? 0) : 0;
    final int classSecs = isDaily ? (int.tryParse(data['class_secs']?.toString() ?? '0') ?? 0) : 0;
    final int totalSecsToDisplay = int.tryParse(data['totalSecs']?.toString() ?? '0') ?? 0;

    return GestureDetector(
      onTap: () {
        if (!isClan && data['user_id'] != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfileScreen(targetUserId: data['user_id'].toString())));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF10A37F).withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isMe ? const Color(0xFF10A37F).withOpacity(0.3) : Colors.grey.shade200, width: isMe ? 1.5 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            // Rank Display 
            SizedBox(
              width: 36,
              child: Center(
                child: Text(
                  pos == 1 ? '🥇' : pos == 2 ? '🥈' : pos == 3 ? '🥉' : '$pos',
                  style: TextStyle(
                    fontSize: isTop3 ? 24 : 14, 
                    fontWeight: FontWeight.w900, 
                    color: isTop3 ? null : Colors.grey.shade400
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            
            // Avatar (Hidden for Clan)
            if (!isClan) ...[
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade100,
                backgroundImage: NetworkImage('https://api.dicebear.com/8.x/notionists/png?seed=$avatarSeed&backgroundColor=f8fafc'),
              ),
              const SizedBox(width: 12),
            ],

            // User/Clan Name & Badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isClan ? (data['clan_name']?.toString() ?? 'Clan') : _formatName(data['name']), 
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isMe ? const Color(0xFF10A37F) : const Color(0xFF1E293B)), 
                    overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 4),
                  
                  if (!isClan && stats != null)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), 
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)), 
                          child: Text("Lvl ${stats['level']}", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade600))
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), 
                          decoration: BoxDecoration(color: stats['rank']['bg'], border: Border.all(color: stats['rank']['border']), borderRadius: BorderRadius.circular(4)), 
                          child: Text(stats['rank']['name'], style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: stats['rank']['color']))
                        ),
                      ],
                    )
                  else if (isClan)
                    const Text("7 Days Focus", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  
                  // 🔥 Class vs Self Study Badges
                  if (isDaily && (selfSecs > 0 || classSecs > 0)) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (selfSecs > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF10A37F).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text("Self: ${_formatStudyTime(selfSecs)}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10A37F))),
                          ),
                        if (classSecs > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(4)),
                            child: Text("Class: ${_formatStudyTime(classSecs)}", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.indigo.shade600)),
                          ),
                      ],
                    )
                  ]
                ],
              ),
            ),
            
            // Time & XP Display
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatStudyTime(totalSecsToDisplay), 
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), letterSpacing: 0.3) 
                ),
                const SizedBox(height: 2),
                if (!isClan && stats != null)
                  Text(
                    "${NumberFormat('#,###').format(stats['finalXp'])} XP", 
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10A37F))
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}