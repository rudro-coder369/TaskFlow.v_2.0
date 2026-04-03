import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _leaders = [];
  bool _loading = true;
  
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

      await _fetchLeaderboard(_currentDateStr);

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
            _fetchLeaderboard(_currentDateStr);
          });
        }
      },
    ).subscribe();
  }

  Future<void> _fetchLeaderboard(String dateString) async {
    if (!mounted) return;
    
    try {
      final todayRes = await _supabase
          .from('daily_logs')
          .select('user_id, study_seconds, self_study_seconds, class_seconds, profiles(username)')
          .eq('date_str', dateString)
          .order('study_seconds', ascending: false)
          .limit(50);

      final todayData = todayRes as List;

      if (todayData.isNotEmpty) {
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
        final lbData = await _supabase
            .from('daily_logs')
            .select('user_id, study_seconds')
            .gte('created_at', thirtyDaysAgo);

        Map<String, int> userTotals = {};
        for (var log in (lbData as List)) {
          final uid = log['user_id'].toString();
          final secs = int.tryParse(log['study_seconds'].toString()) ?? 0;
          userTotals[uid] = (userTotals[uid] ?? 0) + secs;
        }

        final finalLeaders = todayData.map<Map<String, dynamic>>((user) {
          final Map<String, dynamic> userMap = Map<String, dynamic>.from(user as Map);
          final uid = userMap['user_id'].toString();
          final total30d = userTotals[uid] ?? (int.tryParse(userMap['study_seconds'].toString()) ?? 0);
          return {
            ...userMap,
            'total_30d_seconds': total30d,
          };
        }).toList();

        if (mounted) setState(() => _leaders = finalLeaders);
      } else {
        if (mounted) setState(() => _leaders = []);
      }
    } catch (e) {
      debugPrint("Leaderboard Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 🚀 RANKING SYSTEM
  Map<String, dynamic> _calculateStats(int totalSeconds) {
    final hours = totalSeconds / 3600;
    final level = (hours / 2).floor() + 1;
    final rawXp = (hours * 99).floor();

    String rankName = 'Silver';
    Color color = Colors.grey.shade500;
    Color bg = Colors.grey.shade50;
    Color border = Colors.grey.shade200;

    if (rawXp >= 24750) { 
      rankName = 'Legend'; 
      color = Colors.purple.shade600; 
      bg = Colors.purple.shade50; 
      border = Colors.purple.shade200; 
    } else if (rawXp >= 14850) { 
      rankName = 'Emperor'; 
      color = Colors.red.shade600; 
      bg = Colors.red.shade50; 
      border = Colors.red.shade200; 
    } else if (rawXp >= 7920) { 
      rankName = 'Prime'; 
      color = Colors.indigo.shade600; 
      bg = Colors.indigo.shade50; 
      border = Colors.indigo.shade200; 
    } else if (rawXp >= 3960) { 
      rankName = 'Elite'; 
      color = Colors.orange.shade600; 
      bg = Colors.orange.shade50; 
      border = Colors.orange.shade200; 
    } else if (rawXp >= 1485) { 
      rankName = 'Platinum'; 
      color = Colors.lightBlue.shade600; 
      bg = Colors.lightBlue.shade50; 
      border = Colors.lightBlue.shade200; 
    }

    return {'level': level, 'name': rankName, 'color': color, 'bg': bg, 'border': border};
  }

  String _formatStudyTime(dynamic seconds) {
    final secs = int.tryParse(seconds.toString()) ?? 0;
    if (secs <= 0) return "0s";
    
    final h = (secs / 3600).floor();
    final m = ((secs % 3600) / 60).floor();
    final s = secs % 60;
    
    if (h > 0) return "${h}h ${m}m";
    if (m > 0) return "${m}m ${s}s";
    return "${s}s";
  }

  String _formatName(dynamic name) {
    if (name == null || name.toString().trim().isEmpty) return "Scholar";
    String n = name.toString().trim().split(' ')[0];
    return n[0].toUpperCase() + n.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMM yyyy').format(_now); 
    final formattedTime = DateFormat('hh:mm a').format(_now);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), 
      body: Column(
        children: [
          // 🔥 REDESIGNED VERTICAL HEADER SECTION (NO ICON, LESS TOP PADDING)
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 12),
            child: Column(
              children: [
                const Text(
                  "Daily Leaderboard", 
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5)
                ),
                const SizedBox(height: 12),
                
                // COMPACT DATE & TIME PILL
                Container(
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
                
                const SizedBox(height: 12),
                const Text("Resets daily at 12:00 AM.", style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          ),

          // 💎 PREMIUM FLOATING RANKBOARD
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16), 
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(24), 
                border: Border.all(color: Colors.lightBlue.shade100.withOpacity(0.8)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      border: const Border(bottom: BorderSide(color: Color(0xFFE0F2FE))),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 40, child: Center(child: Text("RANK", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)))),
                        Expanded(child: Text("SCHOLAR PROFILE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1))),
                        Text("TOTAL FOCUS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                      ],
                    ),
                  ),

                  Expanded(
                    child: (!_isTimeSynced || _loading)
                      ? const Center(
                          child: Text("FETCHING LIVE STANDINGS...", style: TextStyle(color: Color(0xFF10A37F), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        )
                      : _leaders.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                              Icon(LucideIcons.trophy, size: 40, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Center(child: Text("NO FOCUS SESSIONS YET", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1))),
                              const SizedBox(height: 4),
                              const Center(child: Text("Be the first to claim the top spot!", style: TextStyle(fontSize: 12, color: Colors.grey))),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            physics: const AlwaysScrollableScrollPhysics(), 
                            itemCount: _leaders.length,
                            itemBuilder: (context, index) {
                              final user = _leaders[index];
                              final stats = _calculateStats(user['total_30d_seconds'] as int? ?? 0);
                              final isTop3 = index < 3;
                              
                              final selfSecs = int.tryParse(user['self_study_seconds']?.toString() ?? '0') ?? 0;
                              final classSecs = int.tryParse(user['class_seconds']?.toString() ?? '0') ?? 0;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade100),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      child: Center(
                                        child: Text(
                                          index == 0 ? '🥇' : index == 1 ? '🥈' : index == 2 ? '🥉' : '${index + 1}',
                                          style: TextStyle(
                                            fontSize: isTop3 ? 24 : 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  _formatName(user['profiles']?['username']),
                                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                                child: Text("Lvl ${stats['level']}", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                                              ),
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: stats['bg'], border: Border.all(color: stats['border']), borderRadius: BorderRadius.circular(4)),
                                                child: Text(stats['name'], style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: stats['color'])),
                                              ),
                                            ],
                                          ),
                                          
                                          if (selfSecs > 0 || classSecs > 0) ...[
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (selfSecs > 0)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: const Color(0xFF10A37F).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                    child: Text("Self: ${_formatStudyTime(selfSecs)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10A37F))),
                                                  ),
                                                if (classSecs > 0)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(4)),
                                                    child: Text("Class: ${_formatStudyTime(classSecs)}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo.shade600)),
                                                  ),
                                              ],
                                            ),
                                          ]
                                        ],
                                      ),
                                    ),

                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10A37F).withOpacity(0.08),
                                        border: Border.all(color: const Color(0xFF10A37F).withOpacity(0.2)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _formatStudyTime(user['study_seconds']),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10A37F), fontFamily: 'monospace'),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}