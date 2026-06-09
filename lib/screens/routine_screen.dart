import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/initial_data.dart';
import '../providers/progress_provider.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  late List<DateTime> _rollingDays;
  late String _selectedDateKey;
  String _activeGroup = 'science';
  
  String? _selectedSubjectKey;
  String? _selectedChapterIndex;

  @override
  void initState() {
    super.initState();
    _rollingDays = List.generate(7, (index) => DateTime.now().add(Duration(days: index)));
    _selectedDateKey = DateFormat('dd/MM/yyyy').format(_rollingDays.first);
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _activeGroup = prefs.getString('academic_group') ?? 'science';
    });
  }

  Future<void> _setGroup(String group) async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('academic_group', group);
    setState(() {
      _activeGroup = group;
      _selectedSubjectKey = null;
      _selectedChapterIndex = null;
    });
  }

  void _addRoutineTask() {
    if (_selectedSubjectKey == null || _selectedChapterIndex == null) return;

    HapticFeedback.lightImpact();
    final pp = Provider.of<ProgressProvider>(context, listen: false);
    final subjectData = InitialData.academics[_selectedSubjectKey];
    if (subjectData == null) return;

    final chapterName = subjectData['chapters'][int.parse(_selectedChapterIndex!)];

    final newTask = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'subjectName': subjectData['name'],
      'subjectKey': _selectedSubjectKey,
      'chapterName': chapterName,
      'chapterIndex': int.parse(_selectedChapterIndex!),
    };

    final currentDayTasks = List<Map<String, dynamic>>.from(pp.weeklyRoutine[_selectedDateKey] ?? []);
    currentDayTasks.add(newTask);

    pp.updateRoutine(_selectedDateKey, currentDayTasks);

    setState(() {
      _selectedChapterIndex = null; 
    });
  }

  void _deleteRoutineTask(int index) {
    HapticFeedback.mediumImpact();
    final pp = Provider.of<ProgressProvider>(context, listen: false);
    final currentDayTasks = List<Map<String, dynamic>>.from(pp.weeklyRoutine[_selectedDateKey] ?? []);
    
    if (index >= 0 && index < currentDayTasks.length) {
      currentDayTasks.removeAt(index);
      pp.updateRoutine(_selectedDateKey, currentDayTasks);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pp = Provider.of<ProgressProvider>(context);
    final currentRoutine = pp.weeklyRoutine[_selectedDateKey] ?? [];

    final filteredSubjects = InitialData.academics.entries.where((entry) {
      final groups = entry.value['groups'] as List<String>;
      return groups.contains(_activeGroup);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E293B), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Study Routine",
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade50, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- গ্রুপ টগল ---
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.lightBlue.shade50)),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _setGroup('science'),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _activeGroup == 'science' ? const Color(0xFF10A37F) : Colors.transparent, 
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _activeGroup == 'science' ? [BoxShadow(color: const Color(0xFF10A37F).withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))] : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.graduationCap, size: 16, color: _activeGroup == 'science' ? Colors.white : const Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text("Science", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _activeGroup == 'science' ? Colors.white : const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _setGroup('arts'),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _activeGroup == 'arts' ? const Color(0xFF10A37F) : Colors.transparent, 
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _activeGroup == 'arts' ? [BoxShadow(color: const Color(0xFF10A37F).withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))] : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.palette, size: 16, color: _activeGroup == 'arts' ? Colors.white : const Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text("Arts", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _activeGroup == 'arts' ? Colors.white : const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 🔥 FIX: ডেট বক্সগুলো এখন কম রাউন্ডেড (borderRadius: 12) এবং স্লিক
            SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _rollingDays.length,
                itemBuilder: (context, index) {
                  final targetDate = _rollingDays[index];
                  final dateKey = DateFormat('dd/MM/yyyy').format(targetDate);
                  final isSelected = _selectedDateKey == dateKey;
                  final dayLabel = index == 0 ? "TODAY" : DateFormat('EEE').format(targetDate).toUpperCase();
                  final dateLabel = DateFormat('dd MMM').format(targetDate);
                  final dayTasksCount = (pp.weeklyRoutine[dateKey] ?? []).length;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedDateKey = dateKey);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF10A37F) : Colors.white,
                        borderRadius: BorderRadius.circular(12), // 🔥 Less Rounded
                        border: Border.all(color: isSelected ? const Color(0xFF10A37F) : Colors.grey.shade200),
                        boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF10A37F).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))] : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                dayLabel,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : const Color(0xFF1E293B)),
                              ),
                              if (dayTasksCount > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : const Color(0xFF10A37F).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "$dayTasksCount",
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF10A37F) : const Color(0xFF10A37F)),
                                  ),
                                ),
                              ]
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateLabel,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white70 : const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            // --- গোল অ্যাড কার্ড ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.lightBlue.shade50), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.target, size: 18, color: Color(0xFF10A37F)),
                      SizedBox(width: 8),
                      Text("ASSIGN STUDY GOAL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.0)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    dropdownColor: Colors.white,
                    isExpanded: true,
                    icon: const Icon(LucideIcons.chevronDown, size: 18, color: Color(0xFF94A3B8)),
                    value: _selectedSubjectKey,
                    decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade100)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade100)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10A37F)))),
                    hint: const Text("Select Subject", style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                    items: filteredSubjects.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) => setState(() { _selectedSubjectKey = val; _selectedChapterIndex = null; }),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    dropdownColor: Colors.white,
                    isExpanded: true,
                    icon: const Icon(LucideIcons.chevronDown, size: 18, color: Color(0xFF94A3B8)),
                    value: _selectedChapterIndex,
                    decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade100)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade100)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10A37F)))),
                    hint: const Text("Select Chapter", style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                    items: _selectedSubjectKey == null ? [] : (InitialData.academics[_selectedSubjectKey]['chapters'] as List).asMap().entries.map((e) => DropdownMenuItem(value: e.key.toString(), child: Text("${e.key + 1}. ${e.value}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: _selectedSubjectKey == null ? null : (val) => setState(() => _selectedChapterIndex = val),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addRoutineTask,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10A37F), padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.plus, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text("Add Chapter", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 28),

            // --- টাস্ক লিস্ট কার্ড ---
            Row(
              children: [
                const Icon(LucideIcons.listTodo, size: 18, color: Color(0xFF10A37F)),
                const SizedBox(width: 8),
                Text("SCHEDULE TARGETS", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.0)),
              ],
            ),
            const SizedBox(height: 14),

            currentRoutine.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.lightBlue.shade50)),
                  child: const Column(
                    children: [
                      Icon(LucideIcons.inbox, size: 28, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 10),
                      Text("No study goals assigned.", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: currentRoutine.length,
                  itemBuilder: (context, index) {
                    final task = currentRoutine[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white, 
                        borderRadius: BorderRadius.circular(18), 
                        border: Border.all(color: const Color(0xFF10A37F).withOpacity(0.15)), 
                        boxShadow: [BoxShadow(color: const Color(0xFF10A37F).withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))]
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task['chapterName'] ?? '',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFF10A37F).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    task['subjectName'] ?? '',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF10A37F)),
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () => _deleteRoutineTask(index),
                            icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF94A3B8)),
                            splashColor: Colors.red.shade50,
                            highlightColor: Colors.transparent,
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          )
                        ],
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }
}