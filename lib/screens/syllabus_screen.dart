import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/initial_data.dart';
import '../providers/progress_provider.dart'; 

class SyllabusScreen extends StatefulWidget {
  const SyllabusScreen({super.key});

  @override
  State<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends State<SyllabusScreen> {
  String activeGroup = 'science';
  Map<String, bool> expandedSubject = {};

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      activeGroup = prefs.getString('academic_group') ?? 'science';
    });
  }

  Future<void> _setGroup(String group) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('academic_group', group);
    setState(() {
      activeGroup = group;
      expandedSubject.clear(); // গ্রুপ চেঞ্জ করলে সব কলাপ্স হয়ে যাবে
    });
  }

  void toggleSubject(String key) {
    setState(() {
      expandedSubject[key] = !(expandedSubject[key] ?? false);
    });
  }

  int calculateSubjectProgress(String subjectKey, List chapters, Map<String, dynamic> syllabusProgress) {
    if (chapters.isEmpty) return 0;
    final progress = syllabusProgress[subjectKey] ?? {};
    int completed = 0;
    for (int i = 0; i < chapters.length; i++) {
      if (progress[i.toString()]?['isDone'] == true) {
        completed++;
      }
    }
    return ((completed / chapters.length) * 100).round();
  }

  // 🧠 DYNAMIC ACTIONS LOGIC based on subject
  List<String> getAvailableActions(String subjectKey) {
    if (subjectKey.isEmpty) return ['basic', 'cq', 'mcq', 'mastered'];
    final keyLower = subjectKey.toLowerCase();
    
    if (keyLower.contains('english') || keyLower.contains('ict')) {
      return ['basic', 'mastered'];
    }
    if (keyLower.contains('bangla_2nd') || keyLower.contains('bangla2')) {
      return ['basic', 'mcq', 'mastered'];
    }
    return ['basic', 'cq', 'mcq', 'mastered'];
  }

  @override
  Widget build(BuildContext context) {
    final progressProvider = Provider.of<ProgressProvider>(context);
    final syllabusProgress = progressProvider.syllabusProgress;

    // Filter Subjects
    final filteredSubjects = InitialData.academics.entries.where((entry) {
      final groups = entry.value['groups'] as List<String>;
      return groups.contains(activeGroup);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 24, bottom: 100, left: 16, right: 16),
        child: Column(
          children: [
            // Header
            const Center(
              child: Column(
                children: [
                  Text("Academic Syllabus", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                  SizedBox(height: 8),
                  Text("Track your progress and conquer your curriculum.", style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Group Toggle
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.lightBlue.shade50)),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _setGroup('science'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: activeGroup == 'science' ? const Color(0xFF10A37F) : Colors.transparent, borderRadius: BorderRadius.circular(12), boxShadow: activeGroup == 'science' ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : []),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.graduationCap, size: 18, color: activeGroup == 'science' ? Colors.white : const Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text("Science", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: activeGroup == 'science' ? Colors.white : const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _setGroup('arts'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: activeGroup == 'arts' ? Colors.lightBlue : Colors.transparent, borderRadius: BorderRadius.circular(12), boxShadow: activeGroup == 'arts' ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : []),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.palette, size: 18, color: activeGroup == 'arts' ? Colors.white : const Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text("Arts", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: activeGroup == 'arts' ? Colors.white : const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Subject List
            ...filteredSubjects.map((entry) {
              final key = entry.key;
              final subject = entry.value;
              final chapters = subject['chapters'] as List<String>;
              final int progressPercentage = calculateSubjectProgress(key, chapters, syllabusProgress);
              final bool isExpanded = expandedSubject[key] ?? false;
              final subjectActions = getAvailableActions(key);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.lightBlue.shade50), boxShadow: [BoxShadow(color: Colors.lightBlue.shade50.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  children: [
                    // 🔥 FIX: Subject Header with Expanded and Overflow handling for Premium Uniform Vibe
                    InkWell(
                      onTap: () => toggleSubject(key),
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            // 1. Icon / Collapse Button
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: isExpanded ? const Color(0xFF10A37F).withOpacity(0.1) : Colors.white, border: isExpanded ? null : Border.all(color: Colors.lightBlue.shade50), borderRadius: BorderRadius.circular(12)),
                              child: Icon(isExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight, size: 20, color: isExpanded ? const Color(0xFF10A37F) : const Color(0xFF94A3B8)),
                            ),
                            const SizedBox(width: 16),
                            
                            // 2. Subject Name (Wrapped in Expanded so it never overflows)
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(LucideIcons.bookOpen, size: 18, color: Colors.blueGrey.shade300),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      subject['name'], 
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                      maxLines: 1, // 🔥 Ensures all boxes have the exact same height
                                      overflow: TextOverflow.ellipsis, // 🔥 Adds "..." if name is too long
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // 3. Progress Bar (Fixed Width so it always aligns perfectly)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 60, // Fixed width for progress bar
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(value: progressPercentage / 100, backgroundColor: Colors.lightBlue.shade50, color: const Color(0xFF10A37F), minHeight: 6),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: progressPercentage == 100 ? const Color(0xFF10A37F).withOpacity(0.1) : Colors.white, border: Border.all(color: const Color(0xFF10A37F).withOpacity(0.2)), borderRadius: BorderRadius.circular(8)),
                                  child: Text("$progressPercentage%", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10A37F))),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),

                    // Chapters List
                    if (isExpanded)
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.lightBlue.shade50))),
                        child: Column(
                          children: chapters.asMap().entries.map((chapEntry) {
                            int idx = chapEntry.key;
                            String chapterName = chapEntry.value;
                            
                            final chapProgress = syllabusProgress[key]?[idx.toString()] ?? {'basic': false, 'cq': false, 'mcq': false, 'mastered': false, 'isDone': false};
                            final bool isDone = chapProgress['isDone'] == true;

                            return Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(16),
                              width: double.infinity, // Ensures full width for uniformity
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.lightBlue.shade50)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${idx + 1}. $chapterName",
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDone ? const Color(0xFF94A3B8) : const Color(0xFF334155), decoration: isDone ? TextDecoration.lineThrough : null),
                                  ),
                                  const SizedBox(height: 12),
                                  isDone
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(color: const Color(0xFF10A37F).withOpacity(0.1), border: Border.all(color: const Color(0xFF10A37F).withOpacity(0.2)), borderRadius: BorderRadius.circular(8)),
                                          child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.check, size: 14, color: Color(0xFF10A37F)), SizedBox(width: 4), Text("DONE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10A37F)))]),
                                        )
                                      : Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: subjectActions.map((action) {
                                            bool actionDone = chapProgress[action] == true;
                                            return InkWell(
                                              onTap: () => progressProvider.manuallyUpdateSyllabus(key, idx, action),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: actionDone ? const Color(0xFF10A37F).withOpacity(0.1) : Colors.transparent,
                                                  border: Border.all(color: actionDone ? const Color(0xFF10A37F).withOpacity(0.2) : Colors.grey.shade300),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(action.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: actionDone ? const Color(0xFF10A37F) : const Color(0xFF64748B))),
                                              ),
                                            );
                                          }).toList(),
                                        )
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      )
                  ],
                ),
              );
            })
          ],
        ),
      ),
    );
  }
}