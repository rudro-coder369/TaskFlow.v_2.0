import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  bool _isFirstLoad = true; 
  
  List<Map<String, dynamic>> _graphData = [];
  Map<String, dynamic>? _selectedDay;
  Map<String, dynamic> _stats = {'total': '0m', 'avg': '0m', 'max': '0m', 'gridMax': 3.0};
  
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _historyChannel; 
  Timer? _debounceTimer; 

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _setupRealtimeSubscription(); 
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounceTimer?.cancel();
    _historyChannel?.unsubscribe(); 
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    final session = _supabase.auth.currentSession;
    if (session == null) return;

    _historyChannel = _supabase.channel('history_updates').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'daily_logs',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: session.user.id,
      ),
      callback: (payload) {
        if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
          _fetchHistory();
        });
      },
    ).subscribe();
  }

  Future<void> _fetchHistory() async {
    final session = _supabase.auth.currentSession;
    if (session == null) return;

    try {
      final res = await _supabase
          .from('daily_logs')
          .select('date_str, study_seconds, self_study_seconds, class_seconds, created_at')
          .eq('user_id', session.user.id)
          .order('created_at', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(res);
          _calculateGraphAndStats();
          _loading = false;
        });

        if (_isFirstLoad) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
            }
          });
          _isFirstLoad = false;
        }
      }
    } catch (e) {
      debugPrint('History Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _calculateGraphAndStats() {
    Map<String, Map<String, int>> dataMap = {};
    int totalSecs = 0;
    int maxSecs = 0;

    for (var log in _logs) {
      int t = int.tryParse(log['study_seconds']?.toString() ?? '0') ?? 0;
      int s = int.tryParse(log['self_study_seconds']?.toString() ?? '0') ?? 0;
      int c = int.tryParse(log['class_seconds']?.toString() ?? '0') ?? 0;
      dataMap[log['date_str']] = {'total': t, 'self': s, 'cls': c};
      
      totalSecs += t;
      if (t > maxSecs) maxSecs = t;
    }

    int avgSecs = _logs.isNotEmpty ? (totalSecs / _logs.length).round() : 0;
    double maxHoursGrid = maxSecs / 3600;
    double maxGridLimit = (maxHoursGrid / 3).ceil() * 3.0;
    if (maxGridLimit < 3) maxGridLimit = 3.0;

    _stats = {
      'total': _formatSimpleTime(totalSecs),
      'avg': _formatSimpleTime(avgSecs),
      'max': _formatSimpleTime(maxSecs),
      'gridMax': maxGridLimit,
    };

    List<Map<String, dynamic>> result = [];
    final now = DateTime.now();

    for (int i = 29; i >= 0; i--) {
      DateTime d = now.subtract(Duration(days: i));
      String dStr = DateFormat('dd/MM/yyyy').format(d); 
      
      var dayData = dataMap[dStr] ?? {'total': 0, 'self': 0, 'cls': 0};
      
      result.add({
        'fullDate': dStr,
        'dayName': DateFormat('E').format(d),
        'label': i == 0 ? 'Today' : DateFormat('E, MMM d').format(d),
        'hoursForGrid': dayData['total']! / 3600,
        'seconds': dayData['total'],
        'selfSeconds': dayData['self'],
        'classSeconds': dayData['cls'],
        'isToday': i == 0,
      });
    }

    _graphData = result;
    if (_selectedDay != null) {
      final updatedSelectedDay = _graphData.firstWhere(
        (day) => day['fullDate'] == _selectedDay!['fullDate'], 
        orElse: () => _graphData.last
      );
      _selectedDay = updatedSelectedDay;
    } else if (_graphData.isNotEmpty) {
      _selectedDay = _graphData.last;
    }
  }

  String _formatSimpleTime(int secs) {
    if (secs <= 0) return "0m";
    int h = (secs / 3600).floor();
    int m = ((secs % 3600) / 60).floor();
    int s = secs % 60;
    if (h > 0) return "${h}h ${m}m";
    if (m > 0) return "${m}m ${s}s";
    return "${s}s";
  }

  String _formatBigTime(int secs) {
    if (secs <= 0) return "0 min";
    int h = (secs / 3600).floor();
    int m = ((secs % 3600) / 60).floor();
    int s = secs % 60;
    List<String> parts = [];
    if (h > 0) parts.add("$h hr");
    if (m > 0) parts.add("$m min");
    if (h == 0 && s > 0) parts.add("$s sec");
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Color(0xFFF8FAFC), body: Center(child: Text("ANALYZING ARCHIVES...", style: TextStyle(color: Color(0xFF10A37F), fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12))));
    }

    const double graphHeight = 160.0;
    const double textSpace = 28.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        // 🔥 FIX: Top padding reduced and descriptive text removed
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatCard(LucideIcons.trendingUp, const Color(0xFF10A37F), "Total Focus", _stats['total']),
                const SizedBox(width: 12),
                _buildStatCard(LucideIcons.target, Colors.lightBlue, "Daily Avg", _stats['avg']),
                const SizedBox(width: 12),
                _buildStatCard(LucideIcons.barChart3, Colors.indigo, "Best Session", _stats['max']),
              ],
            ),
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.lightBlue.shade50)),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(_selectedDay != null ? _formatBigTime(_selectedDay!['seconds']) : "0 min", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w300, color: Color(0xFF1E293B))),
                  Text(_selectedDay?['label'] ?? "Select a day", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8))),
                  
                  if (_selectedDay != null && _selectedDay!['seconds'] > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.lightBlue.shade50.withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.lightBlue.shade100)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.bookOpen, size: 14, color: Color(0xFF10A37F)),
                          const SizedBox(width: 6),
                          Text("Self: ${_formatSimpleTime(_selectedDay!['selfSeconds'])}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("|", style: TextStyle(color: Colors.lightBlue))),
                          Icon(LucideIcons.graduationCap, size: 14, color: Colors.indigo.shade500),
                          const SizedBox(width: 6),
                          Text("Class: ${_formatSimpleTime(_selectedDay!['classSeconds'])}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    height: graphHeight + textSpace,
                    child: Stack(
                      children: [
                        _buildExactGrid(1.0, _stats['gridMax'], graphHeight, textSpace),
                        _buildExactGrid(0.666, _stats['gridMax'] * 0.666, graphHeight, textSpace),
                        _buildExactGrid(0.333, _stats['gridMax'] * 0.333, graphHeight, textSpace),
                        _buildExactGrid(0.0, 0, graphHeight, textSpace),

                        Positioned(
                          top: 0, 
                          bottom: 0, 
                          left: 0, 
                          right: 34, 
                          child: ListView.builder(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            itemCount: _graphData.length,
                            itemBuilder: (context, index) {
                              final day = _graphData[index];
                              double hPercent = (day['hoursForGrid'] / _stats['gridMax']);
                              if (hPercent > 1.0) hPercent = 1.0;
                              
                              bool isSelected = _selectedDay?['fullDate'] == day['fullDate'];

                              return GestureDetector(
                                onTap: () => setState(() => _selectedDay = day),
                                child: Container(
                                  width: 45,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      SizedBox(
                                        height: graphHeight,
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Container(
                                            width: 30,
                                            height: day['seconds'] > 0 ? max(2.0, graphHeight * hPercent) : 2.0,
                                            decoration: BoxDecoration(
                                              color: isSelected ? const Color(0xFF10A37F) : (day['seconds'] > 0 ? Colors.lightBlue.shade200 : Colors.transparent),
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: textSpace,
                                        child: Center(
                                          child: Text(
                                            day['dayName'], 
                                            style: TextStyle(
                                              fontSize: 10, 
                                              fontWeight: FontWeight.bold, 
                                              color: isSelected ? const Color(0xFF10A37F) : const Color(0xFF94A3B8)
                                            )
                                          )
                                        )
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Row(
              children: [
                Icon(LucideIcons.history, size: 18, color: Colors.lightBlue),
                SizedBox(width: 8),
                Text("DETAILED ARCHIVE", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 16),

            _logs.isEmpty 
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(color: Colors.lightBlue.shade50.withOpacity(0.4), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.lightBlue.shade100, style: BorderStyle.solid)),
                  child: const Column(
                    children: [
                      Icon(LucideIcons.clock, size: 24, color: Colors.grey),
                      SizedBox(height: 12),
                      Text("NO STUDY SESSIONS LOGGED YET.", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.lightBlue.shade50), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 2))]),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.lightBlue.shade50, borderRadius: BorderRadius.circular(12)),
                                child: const Icon(LucideIcons.calendarDays, size: 16, color: Colors.lightBlue),
                              ),
                              const SizedBox(width: 12),
                              Text(log['date_str'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF1F5F9))),
                                child: Text(_formatSimpleTime(log['study_seconds'] ?? 0), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569), fontFamily: 'monospace')),
                              ),
                              if ((log['self_study_seconds'] ?? 0) > 0 || (log['class_seconds'] ?? 0) > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    children: [
                                      if ((log['self_study_seconds'] ?? 0) > 0)
                                        Row(children: [const Icon(LucideIcons.bookOpen, size: 10, color: Color(0xFF10A37F)), const SizedBox(width: 4), Text(_formatSimpleTime(log['self_study_seconds']), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))]),
                                      if ((log['self_study_seconds'] ?? 0) > 0 && (log['class_seconds'] ?? 0) > 0) const SizedBox(width: 8),
                                      if ((log['class_seconds'] ?? 0) > 0)
                                        Row(children: [Icon(LucideIcons.graduationCap, size: 10, color: Colors.indigo.shade500), const SizedBox(width: 4), Text(_formatSimpleTime(log['class_seconds']), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))]),
                                    ],
                                  ),
                                )
                            ],
                          )
                        ],
                      ),
                    );
                  },
                )
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, Color color, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.lightBlue.shade50), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 2))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 18, color: color)),
            const SizedBox(height: 12),
            Text(title.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          ],
        ),
      ),
    );
  }

  Widget _buildExactGrid(double percent, double val, double gHeight, double bottomSpace) {
    return Positioned(
      bottom: bottomSpace + (gHeight * percent) - 7, 
      left: 0,
      right: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Container(height: 1, color: Colors.blueGrey.withOpacity(0.12))),
          const SizedBox(width: 8),
          SizedBox(
            width: 26, 
            child: Text(
              "${val.toStringAsFixed(val == val.roundToDouble() ? 0 : 1)}h", 
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)
            )
          ),
        ]
      )
    );
  }
}