import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/initial_data.dart';
import '../providers/progress_provider.dart'; 

class SyllabusScreen extends StatefulWidget {
  const SyllabusScreen({super.key});

  @override
  State<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends State<SyllabusScreen> {
  String _activeGroup = 'science'; 
  String _activeClass = '9'; 
  bool _isLoading = true;
  Map<String, bool> expandedSubject = {};

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchUserAcademicDetails();
  }

  Future<void> _fetchUserAcademicDetails() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final profileData = await _supabase
            .from('profiles')
            .select('academic_class, academic_group')
            .eq('id', userId)
            .maybeSingle();

        if (profileData != null && mounted) {
          setState(() {
            _activeGroup = (profileData['academic_group']?.toString() ?? 'science').toLowerCase();
            _activeClass = profileData['academic_class']?.toString() ?? '9';
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching academic details: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void toggleSubject(String key) {
    setState(() {
      expandedSubject[key] = !(expandedSubject[key] ?? false);
    });
  }

  // 🧠 Core Actions
  List<String> getCoreActions(String subjectKey) {
    if (subjectKey.isEmpty) return ['basic', 'cq', 'mcq'];
    final keyLower = subjectKey.toLowerCase();
    
    if (keyLower.contains('english') || keyLower.contains('ict')) {
      return ['basic'];
    }
    if (keyLower.contains('bangla_2nd') || keyLower.contains('bangla2')) {
      return ['basic', 'mcq'];
    }
    return ['basic', 'cq', 'mcq'];
  }

  // 🔥 Progress Calculation
  int calculateSubjectProgress(String subjectKey, List chapters, Map<String, dynamic> syllabusProgress) {
    if (chapters.isEmpty) return 0;
    final progress = syllabusProgress[subjectKey] ?? {};
    int completed = 0;
    final coreActions = getCoreActions(subjectKey);

    for (int i = 0; i < chapters.length; i++) {
      bool isChapterDone = true;
      for (var action in coreActions) {
        if (progress[i.toString()]?[action] != true) {
          isChapterDone = false;
          break;
        }
      }
      if (isChapterDone) completed++;
    }
    return ((completed / chapters.length) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10A37F)),
        ),
      );
    }

    final progressProvider = Provider.of<ProgressProvider>(context);
    final syllabusProgress = progressProvider.syllabusProgress;

    final filteredSubjects = InitialData.academics.entries.where((entry) {
      final groups = entry.value['groups'] as List<String>;
      return groups.map((g) => g.toLowerCase()).contains(_activeGroup);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: filteredSubjects.isEmpty 
        ? const Center(
            child: Text(
              "No syllabus found for your group.",
              style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
            ),
          )
        : SingleChildScrollView(
        padding: const EdgeInsets.only(top: 24, bottom: 100, left: 16, right: 16),
        child: Column(
          children: [
            ...filteredSubjects.map((entry) {
              final key = entry.key;
              final subject = entry.value;
              final chapters = subject['chapters'] as List<String>;
              final int progressPercentage = calculateSubjectProgress(key, chapters, syllabusProgress);
              final bool isExpanded = expandedSubject[key] ?? false;
              final coreActions = getCoreActions(key);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.lightBlue.shade50), boxShadow: [BoxShadow(color: Colors.lightBlue.shade50.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => toggleSubject(key),
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: isExpanded ? const Color(0xFF10A37F).withOpacity(0.1) : Colors.white, border: isExpanded ? null : Border.all(color: Colors.lightBlue.shade50), borderRadius: BorderRadius.circular(12)),
                              child: Icon(isExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight, size: 20, color: isExpanded ? const Color(0xFF10A37F) : const Color(0xFF94A3B8)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(LucideIcons.bookOpen, size: 18, color: Colors.blueGrey.shade300),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      subject['name'], 
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                      maxLines: 1, 
                                      overflow: TextOverflow.ellipsis, 
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 60, 
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

                    if (isExpanded)
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.lightBlue.shade50))),
                        child: Column(
                          children: chapters.asMap().entries.map((chapEntry) {
                            int idx = chapEntry.key;
                            String chapterName = chapEntry.value;
                            
                            final chapProgress = syllabusProgress[key]?[idx.toString()] ?? {};
                            
                            bool isDone = true;
                            for (var action in coreActions) {
                              if (chapProgress[action] != true) {
                                isDone = false;
                                break;
                              }
                            }

                            final bool isMastered = chapProgress['mastered'] == true;
                            final int reviseCount = chapProgress['revise'] ?? 0;

                            return Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(16),
                              width: double.infinity, 
                              decoration: BoxDecoration(
                                color: isMastered ? const Color(0xFFF0FDF4) : Colors.white, 
                                borderRadius: BorderRadius.circular(16), 
                                border: Border.all(color: isMastered ? const Color(0xFF10A37F).withOpacity(0.4) : Colors.lightBlue.shade50)
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 🔥 FIXED: Strikethrough bug solved & colors made aesthetic
                                  Text(
                                    "${idx + 1}. $chapterName",
                                    style: TextStyle(
                                      fontSize: 14, 
                                      fontWeight: FontWeight.w600, 
                                      color: isMastered ? const Color(0xFF166534) : (isDone ? const Color(0xFF94A3B8) : const Color(0xFF334155)), 
                                      decoration: (isDone && !isMastered) ? TextDecoration.lineThrough : TextDecoration.none,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  isDone 
                                    ? Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          // DONE Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(color: const Color(0xFF10A37F), borderRadius: BorderRadius.circular(20)),
                                            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.checkCheck, size: 12, color: Colors.white), SizedBox(width: 4), Text("DONE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))]),
                                          ),
                                          
                                          // MASTERED Toggle
                                          InkWell(
                                            onTap: () => progressProvider.manuallyUpdateSyllabus(key, idx, 'mastered'),
                                            borderRadius: BorderRadius.circular(20),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isMastered ? const Color(0xFF16A34A) : Colors.transparent,
                                                border: Border.all(color: isMastered ? const Color(0xFF16A34A) : Colors.grey.shade300),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min, 
                                                children: [
                                                  Icon(LucideIcons.flame, size: 12, color: isMastered ? Colors.white : const Color(0xFF64748B)), 
                                                  const SizedBox(width: 4), 
                                                  Text("MASTERED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isMastered ? Colors.white : const Color(0xFF64748B)))
                                                ]
                                              ),
                                            ),
                                          ),

                                          // 🔥 NEW: REVISE with [+] icon for clear UX
                                          InkWell(
                                            onTap: () => progressProvider.incrementRevise(key, idx),
                                            borderRadius: BorderRadius.circular(20),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: reviseCount > 0 ? Colors.purple.shade50 : Colors.transparent,
                                                border: Border.all(color: reviseCount > 0 ? Colors.purple.shade200 : Colors.grey.shade300),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min, 
                                                children: [
                                                  Icon(LucideIcons.refreshCw, size: 12, color: reviseCount > 0 ? Colors.purple.shade600 : const Color(0xFF64748B)), 
                                                  const SizedBox(width: 4), 
                                                  Text(reviseCount > 0 ? "${reviseCount}X REVISED" : "REVISE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: reviseCount > 0 ? Colors.purple.shade700 : const Color(0xFF64748B))),
                                                  const SizedBox(width: 4),
                                                  Icon(LucideIcons.plus, size: 12, color: reviseCount > 0 ? Colors.purple.shade600 : const Color(0xFF64748B)), 
                                                ]
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: coreActions.map((action) {
                                          bool actionDone = chapProgress[action] == true;
                                          return InkWell(
                                            onTap: () => progressProvider.manuallyUpdateSyllabus(key, idx, action),
                                            borderRadius: BorderRadius.circular(20),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: actionDone ? const Color(0xFF10A37F).withOpacity(0.1) : Colors.transparent,
                                                border: Border.all(color: actionDone ? const Color(0xFF10A37F).withOpacity(0.3) : Colors.grey.shade300),
                                                borderRadius: BorderRadius.circular(20),
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