import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/progress_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _topScholars = [];
  bool _isExpanded = false;

  Map<String, dynamic> _userStats = {
    'xp': 0,
    'level': 1,
    'totalHours': 0,
    'currentRank': null,
    'progress': 0.0
  };
  Map<String, int> _timeLeft = {'days': 0, 'hours': 0, 'minutes': 0, 'seconds': 0};
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _calculateTimeLeft();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _calculateTimeLeft();
    });
  }

  void _calculateTimeLeft() {
    final target = DateTime(2026, 12, 1);
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return;
    setState(() {
      _timeLeft = {
        'days': diff.inDays,
        'hours': diff.inHours % 24,
        'minutes': diff.inMinutes % 60,
        'seconds': diff.inSeconds % 60
      };
    });
  }

  Map<String, dynamic> _calculateEliteStats(int totalSeconds) {
    final hours = totalSeconds / 3600;
    final level = (hours / 2).floor() + 1;
    final finalXp = (hours * 99).floor();

    Map<String, dynamic> rank = {
      'name': 'Silver',
      'next': 'Platinum',
      'color': Colors.grey.shade600,
      'bg': Colors.grey.shade100,
      'border': Colors.grey.shade200,
      'min': 0,
      'max': 1485
    };
    if (finalXp >= 24750) {
      rank = {'name': 'Legend', 'next': 'Max Level', 'color': Colors.purple.shade600, 'bg': Colors.purple.shade50, 'border': Colors.purple.shade200, 'min': 24750, 'max': 50000};
    } else if (finalXp >= 14850) {
      rank = {'name': 'Emperor', 'next': 'Legend', 'color': Colors.red.shade600, 'bg': Colors.red.shade50, 'border': Colors.red.shade200, 'min': 14850, 'max': 24750};
    } else if (finalXp >= 7920) {
      rank = {'name': 'Prime', 'next': 'Emperor', 'color': Colors.indigo.shade600, 'bg': Colors.indigo.shade50, 'border': Colors.indigo.shade200, 'min': 7920, 'max': 14850};
    } else if (finalXp >= 3960) {
      rank = {'name': 'Elite', 'next': 'Prime', 'color': Colors.orange.shade600, 'bg': Colors.orange.shade50, 'border': Colors.orange.shade200, 'min': 3960, 'max': 7920};
    } else if (finalXp >= 1485) {
      rank = {'name': 'Platinum', 'next': 'Elite', 'color': Colors.lightBlue.shade600, 'bg': Colors.lightBlue.shade50, 'border': Colors.lightBlue.shade200, 'min': 1485, 'max': 3960};
    }

    double progress = finalXp >= 24750 ? 100.0 : ((finalXp - rank['min']) / (rank['max'] - rank['min'])) * 100;
    if (progress < 0) progress = 0;
    if (progress > 100) progress = 100;

    return {'level': level, 'finalXp': finalXp, 'rank': rank, 'progress': progress, 'hours': hours};
  }

  Future<void> _fetchDashboardData() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final lbData = await _supabase.from('daily_logs').select('user_id, study_seconds, profiles(username)').gte('created_at', thirtyDaysAgo);

      Map<String, Map<String, dynamic>> userTotals = {};
      for (var log in (lbData as List)) {
        final uid = log['user_id'].toString();
        final name = log['profiles']?['username'] ?? 'Scholar';
        final secs = int.tryParse(log['study_seconds'].toString()) ?? 0;
        if (!userTotals.containsKey(uid)) userTotals[uid] = {'name': name, 'totalSecs': 0};
        userTotals[uid]!['totalSecs'] += secs;
      }

      final sorted = userTotals.values.toList()..sort((a, b) => b['totalSecs'].compareTo(a['totalSecs']));
      
      int myTotalSecs = 0;
      if (userTotals.containsKey(session.user.id)) {
        myTotalSecs = userTotals[session.user.id]!['totalSecs'];
      }
      
      final myStats = _calculateEliteStats(myTotalSecs);

      if (mounted) {
        setState(() {
          _userStats = {
            'xp': myStats['finalXp'],
            'level': myStats['level'],
            'totalHours': myStats['hours'],
            'currentRank': myStats['rank'],
            'progress': myStats['progress']
          };
          _topScholars = sorted;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatFirstName(dynamic name) {
    if (name == null || name.toString().trim().isEmpty) return "S";
    return name.toString().trim().split(' ')[0][0].toUpperCase() + name.toString().trim().split(' ')[0].substring(1).toLowerCase();
  }

  String _formatStudyTime(int seconds) {
    final h = (seconds / 3600).floor();
    final m = ((seconds % 3600) / 60).floor();
    return h > 0 ? "${h}h ${m}m" : "${m}m";
  }

  @override
  Widget build(BuildContext context) {
    final progressProvider = Provider.of<ProgressProvider>(context);
    
    if (_loading || _userStats['currentRank'] == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: Text(
            "SYNCING HUB...",
            style: TextStyle(color: Color(0xFF10A37F), fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12),
          ),
        ),
      );
    }
    
    final rank = _userStats['currentRank'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Elite Rank Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.lightBlue.shade50.withOpacity(0.4),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.lightBlue.shade100),
                boxShadow: [
                  BoxShadow(color: Colors.lightBlue.shade50, blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.lightBlue.shade100),
                        ),
                        child: Center(
                          child: Text(
                            _formatFirstName(progressProvider.userProfile['username'])[0],
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF10A37F)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatFirstName(progressProvider.userProfile['username']),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.lightBlue.shade100),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.zap, size: 12, color: Color(0xFF10A37F)),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Level ${_userStats['level']}",
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                      )
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: rank['bg'],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: rank['border']),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.medal, size: 12, color: rank['color']),
                                      const SizedBox(width: 4),
                                      Text(
                                        rank['name'],
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: rank['color']),
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.lightBlue.shade50),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "TOTAL XP EARNED",
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              NumberFormat('#,###').format(_userStats['xp']),
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF0F172A)),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6, left: 4),
                              child: Text(
                                "XP",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10A37F)),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.flame, size: 14, color: Color(0xFF10A37F)),
                          SizedBox(width: 6),
                          Text(
                            "JOURNEY TO NEXT RANK",
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          )
                        ],
                      ),
                      Text(
                        "${_userStats['progress'].round()}%",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10A37F)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _userStats['progress'] / 100,
                      minHeight: 8,
                      backgroundColor: Colors.lightBlue.shade100,
                      color: const Color(0xFF10A37F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${NumberFormat('#,###').format(rank['min'])} XP",
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                      ),
                      Text(
                        rank['name'] != 'Legend' ? "Next: ${rank['next']} (${NumberFormat('#,###').format(rank['max'])})" : "Peak Achieved!",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: rank['name'] != 'Legend' ? const Color(0xFF10A37F) : Colors.purple),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Countdown Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.lightBlue.shade50),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(color: Color(0xFFF0F9FF), shape: BoxShape.circle),
                        child: const Icon(LucideIcons.timer, color: Colors.lightBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("SSC 2027", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          Text("TIME LEFT TO PREPARE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1.5)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTimeBox(_timeLeft['days'] ?? 0, "DAY"),
                      const Text(":", style: TextStyle(fontSize: 24, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w300)),
                      _buildTimeBox(_timeLeft['hours'] ?? 0, "HR"),
                      const Text(":", style: TextStyle(fontSize: 24, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w300)),
                      _buildTimeBox(_timeLeft['minutes'] ?? 0, "MIN"),
                      const Text(":", style: TextStyle(fontSize: 24, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w300)),
                      _buildTimeBox(_timeLeft['seconds'] ?? 0, "SEC", isHighlight: true),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Leaderboard Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.lightBlue.shade50),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.trophy, color: Color(0xFF10A37F), size: 18),
                          SizedBox(width: 8),
                          Text("LIVE COMPETITION", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), letterSpacing: 0.5)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade100)),
                        child: const Text("LIVE STANDINGS", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 1)),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (_topScholars.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
                      child: const Text("No scores yet. Start focusing!", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1)),
                    )
                  else ...[
                    if (_topScholars.isNotEmpty) _buildLeaderCard(_topScholars[0], 1, true),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_topScholars.length > 1) Expanded(child: _buildLeaderCard(_topScholars[1], 2, false)),
                        if (_topScholars.length > 2) const SizedBox(width: 12),
                        if (_topScholars.length > 2) Expanded(child: _buildLeaderCard(_topScholars[2], 3, false)),
                      ],
                    ),
                    if (_isExpanded && _topScholars.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          children: _topScholars.skip(3).map((scholar) {
                            int idx = _topScholars.indexOf(scholar) + 1;
                            final stats = _calculateEliteStats(scholar['totalSecs']);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.lightBlue.shade50)),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28, height: 28,
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: Center(
                                      child: Text("$idx", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8))),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_formatFirstName(scholar['name']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                        Text("Lvl ${stats['level']} | ${stats['rank']['name']}", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: stats['rank']['color'])),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // 🔥 Time Highlighted
                                      Text(_formatStudyTime(scholar['totalSecs']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                      Text("${NumberFormat('#,###').format(stats['finalXp'])} XP", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10A37F))),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    if (_topScholars.length > 3)
                      GestureDetector(
                        onTap: () => setState(() => _isExpanded = !_isExpanded),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.lightBlue.shade100)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_isExpanded ? "SHOW LESS" : "VIEW FULL LEADERBOARD", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1)),
                              const SizedBox(width: 6),
                              Icon(_isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 14, color: const Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      )
                  ]
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBox(int value, String label, {bool isHighlight = false}) {
    return Container(
      width: 65, height: 75,
      decoration: BoxDecoration(
        color: isHighlight ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isHighlight ? const Color(0xFF10A37F).withOpacity(0.3) : Colors.transparent),
        boxShadow: isHighlight ? [BoxShadow(color: const Color(0xFF10A37F).withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))] : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value.toString().padLeft(2, '0'), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isHighlight ? const Color(0xFF10A37F) : const Color(0xFF334155), fontFamily: 'monospace')),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isHighlight ? const Color(0xFF10A37F).withOpacity(0.7) : const Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildLeaderCard(Map<String, dynamic> scholar, int pos, bool isFirst) {
    final stats = _calculateEliteStats(scholar['totalSecs']);
    return Container(
      padding: EdgeInsets.all(isFirst ? 20 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isFirst ? const Color(0xFF10A37F).withOpacity(0.2) : Colors.lightBlue.shade50),
        boxShadow: isFirst ? [BoxShadow(color: const Color(0xFF10A37F).withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))] : [],
      ),
      child: isFirst
        ? Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(color: Color(0xFF10A37F), shape: BoxShape.circle),
                child: const Center(child: Text("1", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formatFirstName(scholar['name']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(4)),
                          child: Text("Lvl ${stats['level']}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10A37F))),
                        ),
                        const SizedBox(width: 6),
                        Text(stats['rank']['name'], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: stats['rank']['color'])),
                      ],
                    )
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 🔥 Time Highlighted
                  Text(_formatStudyTime(scholar['totalSecs']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                  Text("${NumberFormat('#,###').format(stats['finalXp'])} XP", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10A37F))),
                ],
              )
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: pos == 2 ? Colors.lightBlue : Colors.grey.shade400, shape: BoxShape.circle),
                    child: Center(child: Text("$pos", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(_formatFirstName(scholar['name']), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text("Lvl ${stats['level']} | ${stats['rank']['name']}", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: stats['rank']['color'])),
              const SizedBox(height: 12),
              // 🔥 Time Highlighted
              Text(_formatStudyTime(scholar['totalSecs']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              Text("${NumberFormat('#,###').format(stats['finalXp'])} XP", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10A37F))),
            ],
          ),
    );
  }
}