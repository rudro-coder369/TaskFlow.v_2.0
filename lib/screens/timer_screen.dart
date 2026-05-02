import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../data/initial_data.dart';
import '../providers/progress_provider.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;
  
  Map<String, int> _habits = {'water': 0, 'meal': 0, 'prayer': 0};
  bool _sleepChecked = false;
  bool _exerciseChecked = false;
  
  List<Map<String, dynamic>> _todos = [];
  
  int _studySeconds = 0;
  int _selfStudySeconds = 0;
  int _classSeconds = 0;
  int _baseStudy = 0, _baseSelf = 0, _baseClass = 0, _baseTask = 0;

  bool _loadingData = true;
  String _taskMode = 'academic';
  String _activeGroup = 'science';
  String? _selectedSubject;
  String? _selectedChapter;
  List<String> _selectedActions = ['basic'];
  final _customTaskController = TextEditingController();
  String _newTaskStudyType = 'self';

  int? _activeTaskId;
  Timer? _timer;
  Timer? _midnightTimer;
  int? _sessionStartMs;
  bool _isProcessing = false;

  Map<String, dynamic>? _syncPopupTask;
  int? _milestonePopup;
  Map<String, dynamic> _dailyMilestones = {'targets': <int>[], 'reached': <int>[]};

  List<Map<String, dynamic>> _onlineUsers = [];
  String _trueDateStr = "";
  RealtimeChannel? _liveRoomChannel;

  StreamSubscription? _pauseSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initWorkspace();
    _fetchLiveUsers();
    _setupLiveRoomSubscription();
    _generateLuckyMilestones();
    _startMidnightChecker();

    // 🔥 Background থেকে `pause_ui` সিগন্যাল পেলে কাজ করবে
    final service = FlutterBackgroundService();
    _pauseSub = service.on('pause_ui').listen((event) {
      if (mounted && _activeTaskId != null) {
        _handlePause(_activeTaskId!); 
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _midnightTimer?.cancel();
    _customTaskController.dispose();
    _liveRoomChannel?.unsubscribe();
    _pauseSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resyncTimerFromAbsolute();
    } else if (state == AppLifecycleState.paused) {
      _syncWorkspaceToSupabase();
    }
  }

  // 🔥 উন্নত Midnight Checker
  void _startMidnightChecker() {
    _midnightTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final currentBDDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
      if (_trueDateStr.isNotEmpty && currentBDDate != _trueDateStr) {
        await _handleMidnightSplit(currentBDDate);
      }
    });
  }

  // 🔥 বুলেটপ্রুফ Midnight Split Logic
  Future<void> _handleMidnightSplit(String newDateStr) async {
    if (_activeTaskId != null) {
      _resyncTimerFromAbsolute(autoPauseCheck: false); 
    }
    // আগের দিনের ডাটা সেভ করা হলো
    await _syncWorkspaceToSupabase(); 

    setState(() {
      _trueDateStr = newDateStr; // নতুন দিন শুরু
      _habits = {'water': 0, 'meal': 0, 'prayer': 0};
      _sleepChecked = false;
      _exerciseChecked = false;
      _studySeconds = 0;
      _selfStudySeconds = 0;
      _classSeconds = 0;

      _todos = _todos.map((t) {
        t['trackedSeconds'] = 0;
        t['isDone'] = false;
        return t;
      }).toList();

      if (_activeTaskId != null) {
        // যদি টাইমার চলতে থাকে, তাহলে নতুন দিনের জন্য 0 থেকে শুরু হবে
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        _sessionStartMs = nowMs;
        _baseStudy = 0;
        _baseSelf = 0;
        _baseClass = 0;
        _baseTask = 0;
        SharedPreferences.getInstance().then((prefs) => prefs.setInt('active_task_start', nowMs));
      }
    });
    
    // নতুন দিনের একদম ফ্রেশ ডাটাবেস এন্ট্রি
    await _syncWorkspaceToSupabase();
    _generateLuckyMilestones();
  }

  Future<void> _fetchLiveUsers() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    try {
      final res = await _supabase.from('profiles').select('username, active_task').not('active_task', 'is', null).gte('task_expires_at', nowIso);
      if (mounted) setState(() => _onlineUsers = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint("Live Room Error: $e");
    }
  }

  void _setupLiveRoomSubscription() {
    _liveRoomChannel = _supabase.channel('live_room_db').onPostgresChanges(
      event: PostgresChangeEvent.all, schema: 'public', table: 'profiles',
      callback: (payload) => _fetchLiveUsers(),
    ).subscribe();
  }

  Future<void> _generateLuckyMilestones() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final savedData = prefs.getString('lucky_milestones');
    
    Map<String, dynamic> currentMilestones = {};
    if (savedData != null) currentMilestones = jsonDecode(savedData);

    if (currentMilestones['date'] != today) {
      final rnd = Random();
      final t1 = rnd.nextInt(3600) + 3600; 
      final t2 = rnd.nextInt(3600) + 10800; 
      final t3 = rnd.nextInt(7200) + 18000; 
      currentMilestones = {'date': today, 'targets': [t1, t2, t3], 'reached': []};
      prefs.setString('lucky_milestones', jsonEncode(currentMilestones));
    }
    setState(() => _dailyMilestones = currentMilestones);
  }

  Future<void> _initWorkspace() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _activeGroup = prefs.getString('academic_group') ?? 'science');

    _trueDateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final session = _supabase.auth.currentSession;
    if (session == null) return;

    try {
      final data = await _supabase.from('daily_logs').select().eq('user_id', session.user.id).eq('date_str', _trueDateStr).maybeSingle();
      
      if (data != null) {
        _habits = {'water': data['water'] ?? 0, 'meal': data['meal'] ?? 0, 'prayer': data['prayer'] ?? 0};
        _sleepChecked = data['sleep'] ?? false;
        _exerciseChecked = data['workout'] ?? false;
        _todos = List<Map<String, dynamic>>.from(data['todos'] ?? []);
        _studySeconds = int.tryParse(data['study_seconds']?.toString() ?? '0') ?? 0;
        _selfStudySeconds = int.tryParse(data['self_study_seconds']?.toString() ?? '0') ?? 0;
        _classSeconds = int.tryParse(data['class_seconds']?.toString() ?? '0') ?? 0;
      }

      final savedTaskId = prefs.getInt('active_task_id');
      final savedStartMs = prefs.getInt('active_task_start');

      if (savedTaskId != null && savedStartMs != null) {
        final elapsed = ((DateTime.now().millisecondsSinceEpoch - savedStartMs) / 1000).floor();
        
        if (elapsed < 7200) { 
          final taskIndex = _todos.indexWhere((t) => t['id'] == savedTaskId);
          if (taskIndex != -1) {
            _activeTaskId = savedTaskId;
            _sessionStartMs = savedStartMs;
            _baseStudy = _studySeconds;
            _baseSelf = _selfStudySeconds;
            _baseClass = _classSeconds;
            _baseTask = _todos[taskIndex]['trackedSeconds'] ?? 0;
            _startTimerInterval();
          }
        } else {
          // অ্যাপ বন্ধ অবস্থায় ২ ঘণ্টা পার হয়ে গেলে ক্লিনআপ
          _clearActiveTaskData();
          try {
            await _supabase.from('profiles').update({'active_task': null, 'task_expires_at': null}).eq('id', session.user.id);
          } catch(e) {}
        }
      }
    } catch (e) {
      debugPrint("Init Error: $e");
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  void _startTimerInterval() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _resyncTimerFromAbsolute();
    });
  }

  // 🔥 বুলেটপ্রুফ Resync & Auto-Pause Logic
  void _resyncTimerFromAbsolute({bool autoPauseCheck = true}) {
    if (_sessionStartMs == null || _activeTaskId == null) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    int elapsed = ((nowMs - _sessionStartMs!) / 1000).floor();
    if (elapsed <= 0) return;

    bool shouldAutoPause = false;
    // ২ ঘণ্টা পূর্ণ হলে এক্সট্রা টাইম কাউন্ট বন্ধ করে অটো পজ সিগন্যাল দিবে
    if (autoPauseCheck && elapsed >= 7200) {
      elapsed = 7200; 
      shouldAutoPause = true;
    }

    final taskIndex = _todos.indexWhere((t) => t['id'] == _activeTaskId);
    if (taskIndex == -1) return;
    
    final sType = _todos[taskIndex]['studyType'] ?? 'self';

    setState(() {
      _studySeconds = _baseStudy + elapsed;
      _selfStudySeconds = _baseSelf + (sType == 'self' ? elapsed : 0);
      _classSeconds = _baseClass + (sType == 'class' ? elapsed : 0);
      _todos[taskIndex]['trackedSeconds'] = _baseTask + elapsed;
    });

    final service = FlutterBackgroundService();
    service.invoke('updateTimer', {
      'seconds': _todos[taskIndex]['trackedSeconds'],
      'taskName': _todos[taskIndex]['title'],
      'subjectName': _todos[taskIndex]['subjectName'],
    });

    List<dynamic> targets = _dailyMilestones['targets'] ?? [];
    List<dynamic> reached = _dailyMilestones['reached'] ?? [];
    
    for (int target in targets) {
      if (_studySeconds >= target && !reached.contains(target)) {
        reached.add(target);
        _dailyMilestones['reached'] = reached;
        SharedPreferences.getInstance().then((prefs) => prefs.setString('lucky_milestones', jsonEncode(_dailyMilestones)));
        setState(() => _milestonePopup = target);
      }
    }

    if (elapsed > 0 && elapsed % 60 == 0) _syncWorkspaceToSupabase();

    // ইনফিনিট লুপ ছাড়া ২ ঘণ্টায় পজ
    if (shouldAutoPause) {
      _handlePause(_activeTaskId!); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("2 Hours reached. Timer auto-paused. Take a break."), backgroundColor: Colors.orange));
    }
  }

  Future<void> _syncWorkspaceToSupabase() async {
    final session = _supabase.auth.currentSession;
    if (session == null) return;

    final payload = {
      'user_id': session.user.id, 'date_str': _trueDateStr,
      'water': _habits['water'], 'meal': _habits['meal'], 'prayer': _habits['prayer'],
      'sleep': _sleepChecked, 'workout': _exerciseChecked,
      'tasks_completed': _todos.where((t) => t['isDone'] == true).length, 'todos': _todos,
      'study_seconds': _studySeconds, 'self_study_seconds': _selfStudySeconds, 'class_seconds': _classSeconds
    };

    try { await _supabase.from('daily_logs').upsert(payload, onConflict: 'user_id, date_str'); } catch (e) {}
  }

  Future<void> _handlePlay(int taskId) async {
    if (_isProcessing) return;
    _isProcessing = true;

    if (_activeTaskId != null) await _handlePause(_activeTaskId!);

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final taskIndex = _todos.indexWhere((t) => t['id'] == taskId);
    if (taskIndex == -1) { _isProcessing = false; return; }

    final task = _todos[taskIndex];
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _activeTaskId = taskId;
      _sessionStartMs = nowMs;
      _baseStudy = _studySeconds;
      _baseSelf = _selfStudySeconds;
      _baseClass = _classSeconds;
      _baseTask = task['trackedSeconds'] ?? 0;
    });

    await prefs.setInt('active_task_id', taskId);
    await prefs.setInt('active_task_start', nowMs);

    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }

    _startTimerInterval();

    final session = _supabase.auth.currentSession;
    if (session != null) {
      final expiresAt = DateTime.now().add(const Duration(hours: 2)).toUtc().toIso8601String();
      await _supabase.from('profiles').update({'active_task': task['title'], 'task_expires_at': expiresAt}).eq('id', session.user.id);
      _fetchLiveUsers();
    }
    _isProcessing = false;
  }

  // 🔥 সিকিউর Pause Logic (Data Loss হবে না)
  Future<void> _handlePause(int taskId) async {
    if (_activeTaskId != taskId) return;
    
    final service = FlutterBackgroundService();
    service.invoke('stopService');

    _timer?.cancel();
    _timer = null;
    
    // autoPauseCheck false দিয়েছি যাতে লুপ না হয়
    _resyncTimerFromAbsolute(autoPauseCheck: false);

    setState(() {
      _activeTaskId = null;
      _sessionStartMs = null;
    });

    await _clearActiveTaskData();
    await _syncWorkspaceToSupabase();

    final session = _supabase.auth.currentSession;
    if (session != null) {
      try {
        await _supabase.from('profiles').update({'active_task': null, 'task_expires_at': null}).eq('id', session.user.id);
        _fetchLiveUsers();
      } catch(e) {}
    }
  }

  Future<void> _clearActiveTaskData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_task_id');
    await prefs.remove('active_task_start');
  }

  List<String> _getAvailableActions(String? subjectKey) {
    if (subjectKey == null || subjectKey.isEmpty) return ['basic', 'cq', 'mcq', 'mastered'];
    final keyLower = subjectKey.toLowerCase();
    if (keyLower.contains('english') || keyLower.contains('ict')) return ['basic', 'mastered'];
    if (keyLower.contains('bangla2') || keyLower.contains('bangla_2nd')) return ['basic', 'mcq', 'mastered'];
    return ['basic', 'cq', 'mcq', 'mastered'];
  }

  void _addTodo() {
    if (_taskMode == 'academic' && (_selectedSubject == null || _selectedChapter == null || _selectedActions.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select subject, chapter and at least one action."), backgroundColor: Colors.redAccent));
      return;
    }
    if (_taskMode == 'custom' && _customTaskController.text.trim().isEmpty) return;

    final subjectData = _taskMode == 'academic' ? InitialData.academics[_selectedSubject] : null;

    final newTask = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'type': _taskMode,
      'studyType': _newTaskStudyType,
      'isDone': false,
      'trackedSeconds': 0,
      'title': _taskMode == 'academic' ? subjectData['chapters'][int.parse(_selectedChapter!)] : _customTaskController.text.trim(),
      'subjectKey': _selectedSubject,
      'subjectName': subjectData?['name'],
      'chapterIndex': _taskMode == 'academic' ? int.parse(_selectedChapter!) : null,
      'actions': _taskMode == 'academic' ? List<String>.from(_selectedActions) : ['task'],
    };

    setState(() {
      _todos.add(newTask);
      if (_taskMode == 'academic') { _selectedChapter = null; _selectedActions = ['basic']; }
      else { _customTaskController.clear(); }
    });
    _syncWorkspaceToSupabase();
  }

  Future<void> _toggleTodoDone(Map<String, dynamic> todo) async {
    if (!todo['isDone'] && todo['type'] == 'academic') {
      setState(() => _syncPopupTask = todo);
    } else {
      _processTodoStatus(todo['id'], false, !todo['isDone']);
    }
  }

  Future<void> _processTodoStatus(int id, bool syncSyllabus, bool status) async {
    if (_activeTaskId == id) await _handlePause(id);
    
    setState(() {
      final index = _todos.indexWhere((t) => t['id'] == id);
      if (index != -1) {
        _todos[index]['isDone'] = status;
        if (syncSyllabus && _todos[index]['type'] == 'academic') {
          Provider.of<ProgressProvider>(context, listen: false).manuallyUpdateSyllabus(
            _todos[index]['subjectKey'], _todos[index]['chapterIndex'], _todos[index]['actions'].first
          );
        }
      }
      _syncPopupTask = null;
    });
    await _syncWorkspaceToSupabase();
  }

  Future<void> _deleteTodo(int id) async {
    if (_activeTaskId == id) await _handlePause(id);
    setState(() => _todos.removeWhere((t) => t['id'] == id));
    await _syncWorkspaceToSupabase();
  }

  String _formatTime(int s) {
    int h = (s / 3600).floor(); int m = ((s % 3600) / 60).floor(); int sec = s % 60;
    if (h > 0) return "${h}h ${m}m ${sec}s";
    return "${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  void _updateHabit(String type, dynamic val) {
    setState(() {
      if (type == 'sleep') _sleepChecked = val;
      else if (type == 'workout') _exerciseChecked = val;
      else _habits[type] = val;
    });
    _syncWorkspaceToSupabase();
  }

  String _formatName(String? name) {
    if (name == null || name.trim().isEmpty) return "Scholar";
    return name.trim().split(' ')[0][0].toUpperCase() + name.trim().split(' ')[0].substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) return const Scaffold(backgroundColor: Color(0xFFF8FAFC), body: Center(child: Text("SYNCING WORKSPACE...", style: TextStyle(color: Color(0xFF10A37F), fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12))));

    int totalExpected = _todos.length;
    int completedTasks = _todos.where((t) => t['isDone'] == true).length;
    int progressPercent = totalExpected == 0 ? 0 : ((completedTasks / totalExpected) * 100).round();

    final filteredSubjects = InitialData.academics.entries.where((e) => (e.value['groups'] as List).contains(_activeGroup)).toList();
    final availableActions = _getAvailableActions(_selectedSubject);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              children: [
                const Center(child: Column(children: [Text("Your Study Workspace", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))), SizedBox(height: 8), Text("Plan, focus deeply, and track habits.", style: TextStyle(color: Color(0xFF64748B), fontSize: 14))])),
                const SizedBox(height: 24),

                // LIVE ROOM CARD
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 12,
                        children: [
                          const Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.users, color: Colors.lightBlue, size: 20), SizedBox(width: 8), Text("Live Study Room", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))]),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade200)), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)), const SizedBox(width: 6), Text("${_onlineUsers.length} ACTIVE", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 1))]))
                        ],
                      ),
                      const SizedBox(height: 16),
                      _onlineUsers.isEmpty 
                        ? Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid)), child: const Center(child: Text("It's quiet here. Start a task to join.", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500))))
                        : Wrap(
                            spacing: 10, runSpacing: 10,
                            children: _onlineUsers.map((u) => Container(
                              width: (MediaQuery.of(context).size.width - 80) / 2, 
                              padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.lightBlue.shade50), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
                              child: Row(children: [
                                CircleAvatar(radius: 16, backgroundColor: const Color(0xFF10A37F), child: Text(_formatName(u['username'])[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                                const SizedBox(width: 8),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_formatName(u['username']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis), Text(u['active_task'] ?? "Focusing", style: const TextStyle(fontSize: 9, color: Color(0xFF10A37F), fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)])),
                              ]),
                            )).toList(),
                          )
                    ],
                  )
                ),

                // PROGRESS CARD
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Daily Progress", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))), Text("$progressPercent%", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF10A37F)))]),
                      const SizedBox(height: 8),
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progressPercent / 100, minHeight: 8, backgroundColor: Colors.lightBlue.shade100, color: const Color(0xFF10A37F))),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        runSpacing: 8,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [const Icon(LucideIcons.bookOpen, size: 12, color: Color(0xFF10A37F)), const SizedBox(width: 4), Text("Self: ${_formatTime(_selfStudySeconds)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))]),
                          Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.graduationCap, size: 12, color: Colors.indigo.shade500), const SizedBox(width: 4), Text("Class: ${_formatTime(_classSeconds)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))]),
                        ],
                      )
                    ],
                  )
                ),

                // TASKS CARD
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 12,
                        children: [
                          const Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.activity, color: Colors.grey, size: 20), SizedBox(width: 8), Text("Academic Tasks", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))]),
                          Container(
                            padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              GestureDetector(onTap: () => setState(() => _taskMode = 'academic'), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _taskMode == 'academic' ? const Color(0xFF10A37F) : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Text("Academic", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _taskMode == 'academic' ? Colors.white : Colors.grey)))),
                              GestureDetector(onTap: () => setState(() => _taskMode = 'custom'), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _taskMode == 'custom' ? const Color(0xFF10A37F) : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Text("Custom", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _taskMode == 'custom' ? Colors.white : Colors.grey)))),
                            ]),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.lightBlue.shade50)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => _newTaskStudyType = 'self'), 
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                                    decoration: BoxDecoration(color: _newTaskStudyType == 'self' ? const Color(0xFF10A37F).withOpacity(0.1) : Colors.white, border: Border.all(color: _newTaskStudyType == 'self' ? const Color(0xFF10A37F).withOpacity(0.3) : Colors.grey.shade200), borderRadius: BorderRadius.circular(8)), 
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min, 
                                      children: [
                                        const Icon(LucideIcons.bookOpen, size: 12, color: Color(0xFF10A37F)), 
                                        const SizedBox(width: 4), 
                                        Text("Self", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _newTaskStudyType == 'self' ? const Color(0xFF10A37F) : Colors.grey))
                                      ]
                                    )
                                  )
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _newTaskStudyType = 'class'), 
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                                    decoration: BoxDecoration(color: _newTaskStudyType == 'class' ? Colors.indigo.shade50 : Colors.white, border: Border.all(color: _newTaskStudyType == 'class' ? Colors.indigo.shade200 : Colors.grey.shade200), borderRadius: BorderRadius.circular(8)), 
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min, 
                                      children: [
                                        Icon(LucideIcons.graduationCap, size: 12, color: Colors.indigo.shade500), 
                                        const SizedBox(width: 4), 
                                        Text("Class", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _newTaskStudyType == 'class' ? Colors.indigo.shade700 : Colors.grey))
                                      ]
                                    )
                                  )
                                ),
                              ]
                            ),
                            const SizedBox(height: 12),
                            
                            if (_taskMode == 'academic') ...[
                              Container(
                                padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                                child: Row(children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () async { 
                                        final p=await SharedPreferences.getInstance(); 
                                        p.setString('academic_group','science'); 
                                        setState((){_activeGroup='science';_selectedSubject=null;_selectedChapter=null;}); 
                                      }, 
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8), 
                                        decoration: BoxDecoration(color: _activeGroup == 'science' ? const Color(0xFF10A37F) : Colors.transparent, borderRadius: BorderRadius.circular(8)), 
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center, 
                                          children: [
                                            Icon(LucideIcons.graduationCap, size: 14, color: _activeGroup == 'science' ? Colors.white : Colors.grey), 
                                            const SizedBox(width: 4), 
                                            Text("Science", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _activeGroup == 'science' ? Colors.white : Colors.grey))
                                          ]
                                        )
                                      )
                                    )
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () async { 
                                        final p=await SharedPreferences.getInstance(); 
                                        p.setString('academic_group','arts'); 
                                        setState((){_activeGroup='arts';_selectedSubject=null;_selectedChapter=null;}); 
                                      }, 
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8), 
                                        decoration: BoxDecoration(color: _activeGroup == 'arts' ? Colors.lightBlue : Colors.transparent, borderRadius: BorderRadius.circular(8)), 
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center, 
                                          children: [
                                            Icon(LucideIcons.palette, size: 14, color: _activeGroup == 'arts' ? Colors.white : Colors.grey), 
                                            const SizedBox(width: 4), 
                                            Text("Arts", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _activeGroup == 'arts' ? Colors.white : Colors.grey))
                                          ]
                                        )
                                      )
                                    )
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 12),

                              DropdownButtonFormField<String>(
                                dropdownColor: Colors.white,
                                isExpanded: true,
                                value: _selectedSubject,
                                decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10A37F)))),
                                hint: const Text("Select Subject", style: TextStyle(fontSize: 13)),
                                items: filteredSubjects.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value['name'], style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (val) => setState(() { _selectedSubject = val; _selectedChapter = null; _selectedActions = ['basic']; }),
                              ),
                              const SizedBox(height: 8),

                              DropdownButtonFormField<String>(
                                dropdownColor: Colors.white,
                                isExpanded: true,
                                value: _selectedChapter,
                                decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10A37F)))),
                                hint: const Text("Select Chapter", style: TextStyle(fontSize: 13)),
                                items: _selectedSubject == null ? [] : (InitialData.academics[_selectedSubject]['chapters'] as List).asMap().entries.map((e) => DropdownMenuItem(value: e.key.toString(), child: Text(e.value, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: _selectedSubject == null ? null : (val) => setState(() => _selectedChapter = val),
                              ),
                              const SizedBox(height: 12),

                              Wrap(
                                spacing: 8, runSpacing: 8,
                                children: availableActions.map((act) {
                                  bool isSelected = _selectedActions.contains(act);
                                  return GestureDetector(
                                    onTap: () => setState(() => isSelected ? _selectedActions.remove(act) : _selectedActions.add(act)),
                                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: isSelected ? Colors.indigo.shade50 : Colors.white, border: Border.all(color: isSelected ? Colors.indigo.shade200 : Colors.grey.shade200), borderRadius: BorderRadius.circular(8)), child: Text(act.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade600))),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              
                              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _addTodo, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10A37F), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Add to Plan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),

                            ] else ...[
                              Row(children: [
                                Expanded(child: TextFormField(controller: _customTaskController, decoration: InputDecoration(hintText: "Personal task...", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)))),
                                const SizedBox(width: 12),
                                InkWell(onTap: _addTodo, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF10A37F), borderRadius: BorderRadius.circular(12)), child: const Icon(LucideIcons.plus, color: Colors.white, size: 20))),
                              ])
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      ..._todos.map((t) {
                        bool isRunning = _activeTaskId == t['id'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12), 
                          padding: const EdgeInsets.all(16), 
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isRunning ? const Color(0xFF10A37F).withOpacity(0.4) : Colors.lightBlue.shade50), boxShadow: isRunning ? [BoxShadow(color: const Color(0xFF10A37F).withOpacity(0.1), blurRadius: 10)] : []),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () => _toggleTodoDone(t),
                                    child: Container(width: 24, height: 24, margin: const EdgeInsets.only(top: 2), decoration: BoxDecoration(color: t['isDone'] ? const Color(0xFF1E293B) : Colors.transparent, border: Border.all(color: t['isDone'] ? const Color(0xFF1E293B) : Colors.grey.shade300), borderRadius: BorderRadius.circular(6)), child: t['isDone'] ? const Icon(Icons.check, color: Colors.white, size: 16) : null),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t['title'], style: TextStyle(fontSize: 15, fontWeight: isRunning ? FontWeight.bold : FontWeight.w600, color: t['isDone'] ? Colors.grey : const Color(0xFF1E293B), decoration: t['isDone'] ? TextDecoration.lineThrough : null), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6, runSpacing: 6,
                                          children: [
                                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: t['studyType'] == 'class' ? Colors.indigo.shade50 : const Color(0xFF10A37F).withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(t['studyType'] == 'class' ? "CLASS" : "SELF", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: t['studyType'] == 'class' ? Colors.indigo : const Color(0xFF10A37F)))),
                                            if (t['type'] == 'academic' && t['subjectName'] != null)
                                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)), child: Text(t['subjectName'], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))),
                                            if (t['type'] == 'academic' && t['actions'] != null)
                                              ...(t['actions'] as List).map((act) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)), child: Text(act.toString().toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue.shade700)))),
                                          ],
                                        )
                                      ],
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: isRunning ? const Color(0xFF10A37F).withOpacity(0.1) : Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: isRunning ? const Color(0xFF10A37F).withOpacity(0.2) : Colors.grey.shade200)), child: Text(_formatTime(t['trackedSeconds'] ?? 0), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isRunning ? const Color(0xFF10A37F) : Colors.grey.shade600, fontFamily: 'monospace'))),
                                  const SizedBox(width: 8),
                                  if (!t['isDone'])
                                    GestureDetector(
                                      onTap: () => isRunning ? _handlePause(t['id']) : _handlePlay(t['id']),
                                      child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isRunning ? Colors.grey.shade200 : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Icon(isRunning ? LucideIcons.pause : LucideIcons.play, size: 18, color: const Color(0xFF1E293B))),
                                    ),
                                  const SizedBox(width: 6),
                                  GestureDetector(onTap: () => _deleteTodo(t['id']), child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(LucideIcons.trash2, size: 18, color: Colors.grey.shade400))),
                                ],
                              )
                            ],
                          ),
                        );
                      }).toList()
                    ],
                  )
                ),

                // HABITS
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Daily Health & Habits", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildHabitTracker("Water", _habits['water']!, 12, LucideIcons.droplets, Colors.lightBlue, (v) => _updateHabit('water', v))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildHabitTracker("Meals", _habits['meal']!, 4, LucideIcons.utensils, Colors.orange, (v) => _updateHabit('meal', v))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildHabitTracker("Prayers", _habits['prayer']!, 5, LucideIcons.moon, Colors.indigo, (v) => _updateHabit('prayer', v)),
                      const SizedBox(height: 16),
                      
                      Container(
                        padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.lightBlue.shade50)),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => _updateHabit('sleep', !_sleepChecked),
                              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [const Icon(LucideIcons.moon, size: 16, color: Colors.purple), const SizedBox(width: 8), Text("Get 7+ Hours Sleep", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _sleepChecked ? Colors.grey : Colors.black87, decoration: _sleepChecked ? TextDecoration.lineThrough : null))]), Container(width: 24, height: 24, decoration: BoxDecoration(color: _sleepChecked ? Colors.green : Colors.transparent, border: Border.all(color: _sleepChecked ? Colors.green : Colors.grey.shade300), borderRadius: BorderRadius.circular(6)), child: _sleepChecked ? const Icon(Icons.check, color: Colors.white, size: 16) : null)]),
                            ),
                            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                            GestureDetector(
                              onTap: () => _updateHabit('workout', !_exerciseChecked),
                              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [const Icon(LucideIcons.activity, size: 16, color: Colors.red), const SizedBox(width: 8), Text("Exercise (30 Mins)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _exerciseChecked ? Colors.grey : Colors.black87, decoration: _exerciseChecked ? TextDecoration.lineThrough : null))]), Container(width: 24, height: 24, decoration: BoxDecoration(color: _exerciseChecked ? Colors.green : Colors.transparent, border: Border.all(color: _exerciseChecked ? Colors.green : Colors.grey.shade300), borderRadius: BorderRadius.circular(6)), child: _exerciseChecked ? const Icon(Icons.check, color: Colors.white, size: 16) : null)]),
                            ),
                          ],
                        ),
                      )
                    ],
                  )
                )
              ],
            ),
          ),
          
          // SYNC POPUP
          if (_syncPopupTask != null)
             Positioned.fill(
               child: Container(
                 color: Colors.transparent,
                 child: Center(
                   child: Container(
                     padding: const EdgeInsets.all(24),
                     margin: const EdgeInsets.symmetric(horizontal: 24),
                     decoration: BoxDecoration(
                       color: Colors.lightBlue.shade400,
                       borderRadius: BorderRadius.circular(24),
                     ),
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         const Icon(LucideIcons.bookOpen, size: 40, color: Colors.white),
                         const SizedBox(height: 16),
                         const Text("Save to syllabus?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                         const SizedBox(height: 8),
                         Text(_syncPopupTask!['title'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                         const SizedBox(height: 16),
                         Wrap(
                           spacing: 8, 
                           children: (_syncPopupTask!['actions'] as List).map((a) => Container(
                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                             decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), 
                             child: Text(a.toString().toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.lightBlue, fontWeight: FontWeight.bold))
                           )).toList()
                         ),
                         const SizedBox(height: 24),
                         Row(
                           children: [
                             Expanded(
                               child: ElevatedButton(
                                 onPressed: () => _processTodoStatus(_syncPopupTask!['id'], false, true), 
                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.lightBlue), 
                                 child: const Text("No", style: TextStyle(fontWeight: FontWeight.bold))
                               )
                             ),
                             const SizedBox(width: 12),
                             Expanded(
                               child: ElevatedButton(
                                 onPressed: () => _processTodoStatus(_syncPopupTask!['id'], true, true), 
                                 style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white), 
                                 child: const Text("Yes", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
                               )
                             )
                           ]
                         )
                       ]
                     )
                   )
                 )
               )
             ),

          // RANDOM REWARD MILESTONE POPUP
          if (_milestonePopup != null)
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10A37F),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16), 
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), 
                          child: const Icon(LucideIcons.trophy, size: 48, color: Colors.white)
                        ),
                        const SizedBox(height: 24),
                        const Text("Milestone Unlocked", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 8),
                        Text(
                          "You've hit ${_formatTime(_milestonePopup!)} of deep focus. Great job staying consistent.", 
                          textAlign: TextAlign.center, 
                          style: const TextStyle(color: Colors.white70, fontSize: 14)
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity, 
                          child: ElevatedButton(
                            onPressed: () => setState(() => _milestonePopup = null), 
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white, 
                              foregroundColor: const Color(0xFF10A37F), 
                              padding: const EdgeInsets.symmetric(vertical: 16), 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                            ), 
                            child: const Text("Awesome, let's go", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                          )
                        )
                      ],
                    ),
                  ),
                ),
              )
            )
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.lightBlue.shade50.withOpacity(0.4), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.lightBlue.shade100.withOpacity(0.6)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))]),
      child: child,
    );
  }

  Widget _buildHabitTracker(String label, int current, int max, IconData icon, Color color, Function(int) onUpdate) {
    return Container(
      padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.lightBlue.shade50)),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]), Text("$current/$max", style: const TextStyle(fontSize: 10, color: Colors.grey))]),
          const SizedBox(height: 12),
          Wrap(spacing: 4, runSpacing: 4, children: List.generate(max, (i) => GestureDetector(onTap: () => onUpdate(current + 1), child: Container(width: max > 5 ? 20 : 32, height: max > 5 ? 20 : 32, decoration: BoxDecoration(color: i < current ? color : Colors.grey.shade50, shape: BoxShape.circle, border: Border.all(color: i < current ? color : Colors.grey.shade200)), child: i < current ? Icon(Icons.check, size: max > 5 ? 10 : 16, color: Colors.white) : null))))
        ],
      ),
    );
  }
}