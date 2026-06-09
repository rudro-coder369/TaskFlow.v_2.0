import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/initial_data.dart';
import '../providers/progress_provider.dart';
import '../providers/timer_provider.dart'; 
import 'deep_focus_screen.dart'; 
import '../widgets/timer/health_card.dart';

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
  final List<int> _completedGoals = []; 
  
  int _studySeconds = 0;
  int _selfStudySeconds = 0;
  int _classSeconds = 0;
  int _baseStudy = 0, _baseSelf = 0, _baseClass = 0, _baseTask = 0;

  bool _loadingData = true;
  String _activeGroup = 'science'; 
  
  String? _selectedSubject;
  String? _selectedChapter;
  List<String> _selectedActions = ['basic'];
  String _newTaskStudyType = 'self';

  int? _activeTaskId;
  Timer? _timer;
  Timer? _midnightTimer;
  int? _sessionStartMs;
  bool _isProcessing = false;

  Map<String, dynamic>? _syncPopupTask;
  int? _milestonePopup;
  Map<String, dynamic> _dailyMilestones = {'targets': <int>[], 'reached': <int>[]};

  String _trueDateStr = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initWorkspace();
    _generateLuckyMilestones();
    _startMidnightChecker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resyncTimerFromAbsolute();
    } else if (state == AppLifecycleState.paused) {
      if (_activeTaskId != null) {
        _syncWorkspaceToSupabase();
      }
    }
  }

  void _startMidnightChecker() {
    _midnightTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final currentBDDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
      if (_trueDateStr.isNotEmpty && currentBDDate != _trueDateStr) {
        await _handleMidnightSplit(currentBDDate);
      }
    });
  }

  Future<void> _handleMidnightSplit(String newDateStr) async {
    if (_activeTaskId != null && _sessionStartMs != null) {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day); 
      final sessionStart = DateTime.fromMillisecondsSinceEpoch(_sessionStartMs!);
      
      final secondsBeforeMidnight = midnight.difference(sessionStart).inSeconds;
      
      if (secondsBeforeMidnight > 0) {
        _studySeconds = _baseStudy + secondsBeforeMidnight;
        final taskIndex = _todos.indexWhere((t) => t['id'] == _activeTaskId);
        if (taskIndex != -1) {
          final sType = _todos[taskIndex]['studyType'] ?? 'self';
          _selfStudySeconds = _baseSelf + (sType == 'self' ? secondsBeforeMidnight : 0);
          _classSeconds = _baseClass + (sType == 'class' ? secondsBeforeMidnight : 0);
          _todos[taskIndex]['trackedSeconds'] = _baseTask + secondsBeforeMidnight;
        }
        await _syncWorkspaceToSupabase(); 
      }
    } else {
      await _syncWorkspaceToSupabase(); 
    }

    setState(() {
      _trueDateStr = newDateStr; 
      _habits = {'water': 0, 'meal': 0, 'prayer': 0};
      _sleepChecked = false;
      _exerciseChecked = false;
      _completedGoals.clear();

      _studySeconds = 0; _selfStudySeconds = 0; _classSeconds = 0;
      _baseStudy = 0; _baseSelf = 0; _baseClass = 0; _baseTask = 0;

      _todos = _todos.map((t) {
        t['trackedSeconds'] = 0; 
        t['isDone'] = false;
        return t;
      }).toList();

      if (_activeTaskId != null) {
        final midnightMs = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).millisecondsSinceEpoch;
        _sessionStartMs = midnightMs;
        SharedPreferences.getInstance().then((prefs) => prefs.setInt('active_task_start', midnightMs));
      }
    });
    
    await _syncWorkspaceToSupabase();
    _generateLuckyMilestones();
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
        final startTime = DateTime.fromMillisecondsSinceEpoch(savedStartMs);
        final now = DateTime.now();
        final elapsedTotal = (now.difference(startTime).inSeconds);
        
        if (elapsedTotal < 7200) { 
          final taskIndex = _todos.indexWhere((t) => t['id'] == savedTaskId);
          if (taskIndex != -1) {
            final sType = _todos[taskIndex]['studyType'] ?? 'self';

            if (startTime.day != now.day) {
              final midnight = DateTime(now.year, now.month, now.day);
              final secondsBeforeMidnight = midnight.difference(startTime).inSeconds;
              
              String yesterdayStr = DateFormat('dd/MM/yyyy').format(startTime);
              final yData = await _supabase.from('daily_logs').select().eq('user_id', session.user.id).eq('date_str', yesterdayStr).maybeSingle();
              
              if (yData != null) {
                int yStudy = (yData['study_seconds'] ?? 0) + secondsBeforeMidnight;
                int ySelf = (yData['self_study_seconds'] ?? 0) + (sType == 'self' ? secondsBeforeMidnight : 0);
                int yClass = (yData['class_seconds'] ?? 0) + (sType == 'class' ? secondsBeforeMidnight : 0);
                
                List<dynamic> yTodos = yData['todos'] ?? [];
                final yTaskIdx = yTodos.indexWhere((t) => t['id'] == savedTaskId);
                if (yTaskIdx != -1) yTodos[yTaskIdx]['trackedSeconds'] = (yTodos[yTaskIdx]['trackedSeconds'] ?? 0) + secondsBeforeMidnight;
                
                await _supabase.from('daily_logs').update({
                  'study_seconds': yStudy, 'self_study_seconds': ySelf, 'class_seconds': yClass, 'todos': yTodos
                }).eq('user_id', session.user.id).eq('date_str', yesterdayStr);
              }
              
              _sessionStartMs = midnight.millisecondsSinceEpoch;
              await prefs.setInt('active_task_start', _sessionStartMs!);
              
              _baseStudy = _studySeconds; _baseSelf = _selfStudySeconds; _baseClass = _classSeconds; _baseTask = 0; 
            } else {
              _sessionStartMs = savedStartMs;
              _baseStudy = _studySeconds; _baseSelf = _selfStudySeconds; _baseClass = _classSeconds;
              _baseTask = _todos[taskIndex]['trackedSeconds'] ?? 0;
            }

            _activeTaskId = savedTaskId;
            
            // Sync Provider on Boot
            Provider.of<TimerProvider>(context, listen: false).syncTime(_baseTask, true);
            _startTimerInterval();
          }
        } else {
          _clearActiveTaskData();
          try { await _supabase.from('profiles').update({'active_task': null, 'active_subject': null, 'task_expires_at': null}).eq('id', session.user.id); } catch(e) {}
        }
      }
    } catch (e) {
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  void _startTimerInterval() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      
      final timerProv = Provider.of<TimerProvider>(context, listen: false);
      if (!timerProv.isRunning && _activeTaskId != null) {
        _handlePause(_activeTaskId!);
        return;
      }

      _resyncTimerFromAbsolute();
    });
  }

  void _resyncTimerFromAbsolute({bool autoPauseCheck = true}) {
    if (_sessionStartMs == null || _activeTaskId == null || !mounted) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    int elapsed = ((nowMs - _sessionStartMs!) / 1000).floor();
    if (elapsed <= 0) return;

    bool shouldAutoPause = false;
    if (autoPauseCheck && elapsed >= 7200) {
      elapsed = 7200; 
      shouldAutoPause = true;
    }

    final taskIndex = _todos.indexWhere((t) => t['id'] == _activeTaskId);
    if (taskIndex == -1) return;
    
    final sType = _todos[taskIndex]['studyType'] ?? 'self';
    final int currentTaskTime = _baseTask + elapsed;

    setState(() {
      _studySeconds = _baseStudy + elapsed;
      _selfStudySeconds = _baseSelf + (sType == 'self' ? elapsed : 0);
      _classSeconds = _baseClass + (sType == 'class' ? elapsed : 0);
      _todos[taskIndex]['trackedSeconds'] = currentTaskTime;
    });

    Provider.of<TimerProvider>(context, listen: false).syncTime(currentTaskTime, true);

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

    if (_activeTaskId != null && _activeTaskId != taskId) {
      await _handlePause(_activeTaskId!);
    }

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

    // FIXED BUG: Sync provider to true immediately so the loop knows it started
    Provider.of<TimerProvider>(context, listen: false).syncTime(_baseTask, true);

    _startTimerInterval();

    final session = _supabase.auth.currentSession;
    if (session != null) {
      final expiresAt = DateTime.now().add(const Duration(hours: 2)).toUtc().toIso8601String();
      await _supabase.from('profiles').update({
        'active_task': task['title'], 
        'active_subject': task['subjectName'] ?? 'Task',
        'task_expires_at': expiresAt
      }).eq('id', session.user.id);
    }
    
    _isProcessing = false;

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _activeTaskId == taskId) {
        _navigateToDeepFocus(task, nowMs);
      }
    });
  }

  void _navigateToDeepFocus(Map<String, dynamic> task, int startTimeMs) {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DeepFocusScreen(
            subjectName: task['subjectName'] ?? (task['studyType'] == 'class' ? 'Class Task' : 'Academic Task'),
            chapterName: task['title'] ?? 'Focus Session',
            startTime: DateTime.fromMillisecondsSinceEpoch(startTimeMs),
          ),
        ),
      );
    }
  }

  Future<void> _handlePause(int taskId) async {
    if (_activeTaskId != taskId) return;

    _timer?.cancel();
    _timer = null;
    
    _resyncTimerFromAbsolute(autoPauseCheck: false);
    
    Provider.of<TimerProvider>(context, listen: false).stopTimer();

    setState(() {
      _activeTaskId = null;
      _sessionStartMs = null;
    });

    await _clearActiveTaskData();
    await _syncWorkspaceToSupabase(); 

    final session = _supabase.auth.currentSession;
    if (session != null) {
      try {
        await _supabase.from('profiles').update({
          'active_task': null, 
          'active_subject': null,
          'task_expires_at': null
        }).eq('id', session.user.id);
      } catch(e) {}
    }
  }

  Future<void> _clearActiveTaskData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_task_id');
    await prefs.remove('active_task_start');
  }

  List<String> _getAvailableActions(String? subjectKey) {
    if (subjectKey == null || subjectKey.isEmpty) return ['basic', 'cq', 'mcq', 'mastered', 'revise'];
    final keyLower = subjectKey.toLowerCase();
    if (keyLower.contains('english') || keyLower.contains('ict')) return ['basic', 'mastered', 'revise'];
    if (keyLower.contains('bangla2') || keyLower.contains('bangla_2nd')) return ['basic', 'mcq', 'mastered', 'revise'];
    return ['basic', 'cq', 'mcq', 'mastered', 'revise'];
  }

  void _addTodo() {
    if (_selectedSubject != null && _selectedChapter != null && _selectedActions.isNotEmpty) {
      final subjectData = InitialData.academics[_selectedSubject];
      final newTask = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'type': 'academic',
        'studyType': _newTaskStudyType,
        'isDone': false,
        'trackedSeconds': 0,
        'title': subjectData!['chapters'][int.parse(_selectedChapter!)],
        'subjectKey': _selectedSubject,
        'subjectName': subjectData['name'],
        'chapterIndex': int.parse(_selectedChapter!),
        'actions': List<String>.from(_selectedActions),
      };
      setState(() {
        _todos.add(newTask);
        _selectedChapter = null; 
        _selectedActions = ['basic'];
      });
      _syncWorkspaceToSupabase();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a subject, chapter, and action."), backgroundColor: Colors.redAccent));
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
      if (type == 'sleep') {
        if (!_sleepChecked) _sleepChecked = true;
      } else if (type == 'workout') {
        if (!_exerciseChecked) _exerciseChecked = true;
      } else {
        _habits[type] = val;
      }
    });
    _syncWorkspaceToSupabase();
  }

  void _toggleGoalDopamine(int index) {
    setState(() {
      if (_completedGoals.contains(index)) {
        _completedGoals.remove(index);
      } else {
        _completedGoals.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) return const Scaffold(backgroundColor: Color(0xFFF8FAFC), body: Center(child: Text("SYNCING WORKSPACE...", style: TextStyle(color: Color(0xFF10A37F), fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12))));

    final filteredSubjects = InitialData.academics.entries.where((e) => (e.value['groups'] as List).contains(_activeGroup)).toList();
    final availableActions = _getAvailableActions(_selectedSubject);

    final progressProvider = Provider.of<ProgressProvider>(context);
    String todayDateKey = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final todayGoals = progressProvider.weeklyRoutine[todayDateKey] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // ==========================================
                // 1. TODAY'S TARGETS
                // ==========================================
                if (todayGoals.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 12),
                    child: Row(
                      children: [
                        Icon(LucideIcons.calendarCheck, color: Color(0xFF10A37F), size: 18),
                        SizedBox(width: 8),
                        Text("Today's Targets", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                      ],
                    ),
                  ),
                  
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 32),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(24), 
                      border: Border.all(color: Colors.grey.shade200), 
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: todayGoals.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final goal = entry.value;
                        
                        final subjectName = goal is Map ? (goal['subjectName'] ?? goal['subject'] ?? 'Subject') : 'Subject';
                        final chapterName = goal is Map ? (goal['chapterName'] ?? goal['chapter'] ?? 'Chapter') : goal.toString();
                        final bool isDone = _completedGoals.contains(index);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => _toggleGoalDopamine(index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    color: isDone ? const Color(0xFF10A37F) : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isDone ? const Color(0xFF10A37F) : Colors.grey.shade300, width: 1.5)
                                  ),
                                  child: isDone ? const Icon(LucideIcons.check, size: 14, color: Colors.white) : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(subjectName.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isDone ? Colors.grey.shade400 : const Color(0xFF10A37F), letterSpacing: 1.0, decoration: isDone ? TextDecoration.lineThrough : null)),
                                    const SizedBox(height: 2),
                                    Text(chapterName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDone ? Colors.grey.shade400 : const Color(0xFF334155), decoration: isDone ? TextDecoration.lineThrough : null)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                // ==========================================
                // 2. STUDY TABLE
                // ==========================================
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Row(
                    children: [
                      Icon(LucideIcons.bookOpen, color: Color(0xFF10A37F), size: 18),
                      SizedBox(width: 8),
                      Text("Study Table", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                    ],
                  ),
                ),
                
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 32),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.lightBlue.shade50.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.lightBlue.shade100.withOpacity(0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.lightBlue.shade50),
                        ),
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
                                    decoration: BoxDecoration(
                                      color: _newTaskStudyType == 'self' ? const Color(0xFF10A37F).withOpacity(0.1) : Colors.white,
                                      border: Border.all(color: _newTaskStudyType == 'self' ? const Color(0xFF10A37F).withOpacity(0.3) : Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(LucideIcons.bookOpen, size: 12, color: Color(0xFF10A37F)),
                                        const SizedBox(width: 4),
                                        Text("Self", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _newTaskStudyType == 'self' ? const Color(0xFF10A37F) : Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _newTaskStudyType = 'class'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _newTaskStudyType == 'class' ? Colors.indigo.shade50 : Colors.white,
                                      border: Border.all(color: _newTaskStudyType == 'class' ? Colors.indigo.shade200 : Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(LucideIcons.graduationCap, size: 12, color: Colors.indigo.shade500),
                                        const SizedBox(width: 4),
                                        Text("Class", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _newTaskStudyType == 'class' ? Colors.indigo.shade700 : Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            DropdownButtonFormField<String>(
                              dropdownColor: Colors.white, isExpanded: true, value: _selectedSubject,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                filled: true, fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10A37F))),
                              ),
                              hint: const Text("Select Subject", style: TextStyle(fontSize: 13)),
                              items: filteredSubjects.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value['name'], style: const TextStyle(fontSize: 13)))).toList(),
                              onChanged: (val) => setState(() { _selectedSubject = val; _selectedChapter = null; _selectedActions = ['basic']; }),
                            ),
                            const SizedBox(height: 8),

                            DropdownButtonFormField<String>(
                              dropdownColor: Colors.white, isExpanded: true, value: _selectedChapter,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                filled: true, fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10A37F))),
                              ),
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
                                  onTap: () => setState(() { _selectedActions.contains(act) ? _selectedActions.remove(act) : _selectedActions.add(act); }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.indigo.shade50 : Colors.white,
                                      border: Border.all(color: isSelected ? Colors.indigo.shade200 : Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(act.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.indigo.shade700 : Colors.grey.shade600)),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _addTodo,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10A37F),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Text("Add to Plan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_todos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text("No active tasks. Add one to start.", style: TextStyle(color: Colors.grey, fontSize: 12))),
                        )
                      else
                        ..._todos.map((t) {
                          bool isRunning = _activeTaskId == t['id'];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isRunning ? const Color(0xFF10A37F).withOpacity(0.4) : Colors.lightBlue.shade50, width: isRunning ? 2 : 1),
                              boxShadow: isRunning ? [BoxShadow(color: const Color(0xFF10A37F).withOpacity(0.1), blurRadius: 10)] : [],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t['title']?.toString() ?? 'Task',
                                            style: TextStyle(fontSize: 15, fontWeight: isRunning ? FontWeight.bold : FontWeight.w600, color: const Color(0xFF1E293B)),
                                            maxLines: 2, overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6, runSpacing: 6,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: t['studyType'] == 'class' ? Colors.indigo.shade50 : const Color(0xFF10A37F).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                child: Text(t['studyType'] == 'class' ? "CLASS" : "SELF", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: t['studyType'] == 'class' ? Colors.indigo : const Color(0xFF10A37F))),
                                              ),
                                              if (t['subjectName'] != null)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                                  child: Text(t['subjectName'], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                                                ),
                                              if (t['actions'] != null)
                                                ...(t['actions'] as List).map((act) => Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                                      child: Text(act.toString().toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                                    )),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                    
                                    if (isRunning && _sessionStartMs != null)
                                      GestureDetector(
                                        onTap: () => _navigateToDeepFocus(t, _sessionStartMs!),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: const Color(0xFF10A37F).withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF10A37F).withOpacity(0.3))),
                                          child: const Icon(LucideIcons.arrowUpRight, size: 18, color: Color(0xFF10A37F)),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(color: isRunning ? const Color(0xFF10A37F).withOpacity(0.1) : Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: isRunning ? const Color(0xFF10A37F).withOpacity(0.2) : Colors.grey.shade200)),
                                      child: Text(
                                        _formatTime(t['trackedSeconds'] ?? 0),
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isRunning ? const Color(0xFF10A37F) : Colors.grey.shade600, fontFamily: 'monospace'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => isRunning ? _handlePause(t['id']) : _handlePlay(t['id']),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: isRunning ? Colors.grey.shade200 : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                        child: Icon(isRunning ? LucideIcons.pause : LucideIcons.play, size: 18, color: const Color(0xFF1E293B)),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (!isRunning)
                                      GestureDetector(
                                        onTap: () => _deleteTodo(t['id']),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Icon(LucideIcons.trash2, size: 18, color: Colors.grey.shade400),
                                        ),
                                      ),
                                  ],
                                )
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),

                // ==========================================
                // 3. HEALTH & HABITS
                // ==========================================
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Row(
                    children: [
                      Icon(LucideIcons.heartHandshake, color: Color(0xFF0284C7), size: 18),
                      SizedBox(width: 8),
                      Text("Health & Habit", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                    ],
                  ),
                ),
                HealthHabitsWidget(
                  habits: _habits, sleepChecked: _sleepChecked, exerciseChecked: _exerciseChecked, onUpdateHabit: _updateHabit,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          
          if (_syncPopupTask != null) _buildSyncPopup(),
          if (_milestonePopup != null) _buildMilestonePopup(),
        ],
      ),
    );
  }

  Widget _buildSyncPopup() {
    return Positioned.fill(
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24), margin: const EdgeInsets.symmetric(horizontal: 24), decoration: BoxDecoration(color: Colors.lightBlue.shade400, borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.bookOpen, size: 40, color: Colors.white),
                const SizedBox(height: 16),
                const Text("Save to syllabus?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(_syncPopupTask!['title']?.toString() ?? 'Task', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 16),
                Wrap(spacing: 8, children: (_syncPopupTask!['actions'] as List).map((a) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Text(a.toString().toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.lightBlue, fontWeight: FontWeight.bold)))).toList()),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: ElevatedButton(onPressed: () => _processTodoStatus(_syncPopupTask!['id'], false, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.lightBlue), child: const Text("No", style: TextStyle(fontWeight: FontWeight.bold)))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(onPressed: () => _processTodoStatus(_syncPopupTask!['id'], true, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white), child: const Text("Yes", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))))
                  ]
                )
              ]
            )
          )
        )
      )
    );
  }

  Widget _buildMilestonePopup() {
    return Positioned.fill(
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32), margin: const EdgeInsets.symmetric(horizontal: 24), decoration: BoxDecoration(color: const Color(0xFF10A37F), borderRadius: BorderRadius.circular(32)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(LucideIcons.trophy, size: 48, color: Colors.white)),
                const SizedBox(height: 24),
                const Text("Milestone Unlocked", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text("You've hit ${_formatTime(_milestonePopup!)} of deep focus. Great job staying consistent.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 32),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => setState(() => _milestonePopup = null), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF10A37F), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("Awesome, let's go", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))))
              ],
            ),
          ),
        ),
      )
    );
  }
}