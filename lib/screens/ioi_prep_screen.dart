import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/initial_data.dart';

class IoiPrepScreen extends StatefulWidget {
  const IoiPrepScreen({super.key});

  @override
  State<IoiPrepScreen> createState() => _IoiPrepScreenState();
}

class _IoiPrepScreenState extends State<IoiPrepScreen> {
  final Map<int, bool> _expandedCategories = {};
  
  // Progress Structure: { "0_1": {"theory": true, "practice": false, "apply": false, "isDone": false} }
  Map<String, dynamic> _ioiProgress = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('ioi_progress_data');
    if (savedData != null) {
      setState(() {
        _ioiProgress = jsonDecode(savedData);
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _toggleAction(int catIdx, int topicIdx, String action) async {
    final key = "${catIdx}_$topicIdx";
    
    if (!_ioiProgress.containsKey(key)) {
      _ioiProgress[key] = {'theory': false, 'practice': false, 'apply': false, 'isDone': false};
    }

    // Toggle the specific action
    _ioiProgress[key][action] = !(_ioiProgress[key][action] ?? false);

    // Check if all three are done to trigger DOPAMINE "DONE"
    if (_ioiProgress[key]['theory'] == true && 
        _ioiProgress[key]['practice'] == true && 
        _ioiProgress[key]['apply'] == true) {
      _ioiProgress[key]['isDone'] = true;
    } else {
      _ioiProgress[key]['isDone'] = false;
    }

    setState(() {});

    // Save to local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ioi_progress_data', jsonEncode(_ioiProgress));
  }

  // 📊 Calculate Overall Progress
  int _calculateOverallProgress() {
    final categories = InitialData.ioi['categories'] as List;
    int totalTopics = 0;
    int completedTopics = 0;

    for (int c = 0; c < categories.length; c++) {
      final topics = categories[c]['topics'] as List;
      totalTopics += topics.length;
      for (int t = 0; t < topics.length; t++) {
        if (_ioiProgress["${c}_$t"]?['isDone'] == true) completedTopics++;
      }
    }
    if (totalTopics == 0) return 0;
    return ((completedTopics / totalTopics) * 100).round();
  }

  // 📊 Calculate Category Progress
  int _calculateCategoryProgress(int catIdx, int totalTopics) {
    if (totalTopics == 0) return 0;
    int completed = 0;
    for (int t = 0; t < totalTopics; t++) {
      if (_ioiProgress["${catIdx}_$t"]?['isDone'] == true) completed++;
    }
    return ((completed / totalTopics) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: Color(0xFFF8FAFC), body: Center(child: CircularProgressIndicator(color: Color(0xFF10A37F))));

    final ioiCategories = InitialData.ioi['categories'] as List;
    final overallProgress = _calculateOverallProgress();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("IOI Preparation", style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16, bottom: 100, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🌟 OVERALL PROGRESS BAR
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.lightBlue.shade50),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Journey to IOI", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      Text("$overallProgress%", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF10A37F))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text("Master the algorithms, conquer the Olympiad.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: overallProgress / 100,
                      minHeight: 10,
                      backgroundColor: Colors.lightBlue.shade50,
                      color: const Color(0xFF10A37F),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              "Syllabus Modules", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))
            ),
            const SizedBox(height: 16),
            
            // 📝 DYNAMIC CATEGORIES
            ...ioiCategories.asMap().entries.map((entry) {
              final int catIdx = entry.key;
              final category = entry.value;
              final bool isExpanded = _expandedCategories[catIdx] ?? false;
              final List topics = category['topics'] as List;
              final catProgress = _calculateCategoryProgress(catIdx, topics.length);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.lightBlue.shade50),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                ),
                child: Column(
                  children: [
                    // Category Header
                    InkWell(
                      onTap: () => setState(() => _expandedCategories[catIdx] = !isExpanded),
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isExpanded ? const Color(0xFF10A37F).withOpacity(0.1) : Colors.white,
                                border: isExpanded ? null : Border.all(color: Colors.lightBlue.shade50),
                                borderRadius: BorderRadius.circular(12)
                              ),
                              child: Icon(
                                isExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight, 
                                size: 20, 
                                color: isExpanded ? const Color(0xFF10A37F) : const Color(0xFF94A3B8)
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category['name'], 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(value: catProgress / 100, minHeight: 6, backgroundColor: Colors.grey.shade100, color: const Color(0xFF10A37F)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text("$catProgress%", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10A37F))),
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    
                    // Expanded Topics List
                    if (isExpanded)
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.lightBlue.shade50))),
                        child: Column(
                          children: topics.asMap().entries.map((tEntry) {
                            final int topicIdx = tEntry.key;
                            final String topicName = tEntry.value;
                            final String key = "${catIdx}_$topicIdx";
                            
                            final progress = _ioiProgress[key] ?? {'theory': false, 'practice': false, 'apply': false, 'isDone': false};
                            final bool isDone = progress['isDone'] == true;

                            return Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(16),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDone ? const Color(0xFF10A37F).withOpacity(0.03) : Colors.white, 
                                borderRadius: BorderRadius.circular(16), 
                                border: Border.all(color: isDone ? const Color(0xFF10A37F).withOpacity(0.3) : Colors.lightBlue.shade50)
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${topicIdx + 1}. $topicName", 
                                    style: TextStyle(
                                      fontSize: 15, 
                                      color: isDone ? const Color(0xFF64748B) : const Color(0xFF1E293B), 
                                      fontWeight: isDone ? FontWeight.w500 : FontWeight.w600,
                                      decoration: isDone ? TextDecoration.lineThrough : null
                                    )
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // 🎁 DOPAMINE RELEASE: "DONE" BADGE OR ACTION BUTTONS
                                  isDone 
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(colors: [Color(0xFF10A37F), Colors.teal]),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [BoxShadow(color: const Color(0xFF10A37F).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(LucideIcons.checkCircle2, color: Colors.white, size: 16),
                                            SizedBox(width: 6),
                                            Text("MASTERED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                                          ],
                                        ),
                                      )
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _buildActionButton("Theory", LucideIcons.bookOpen, Colors.blue, progress['theory'] == true, () => _toggleAction(catIdx, topicIdx, 'theory')),
                                          _buildActionButton("Practice", LucideIcons.code2, Colors.orange, progress['practice'] == true, () => _toggleAction(catIdx, topicIdx, 'practice')),
                                          _buildActionButton("Applied", LucideIcons.swords, Colors.purple, progress['apply'] == true, () => _toggleAction(catIdx, topicIdx, 'apply')),
                                        ],
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
            }),
          ],
        ),
      ),
    );
  }

  // 🎛️ Custom Action Button Builder
  Widget _buildActionButton(String label, IconData icon, MaterialColor color, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.shade50 : Colors.white,
          border: Border.all(color: isSelected ? color.shade400 : Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? color.shade700 : Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(
              label, 
              style: TextStyle(
                fontSize: 11, 
                fontWeight: FontWeight.bold, 
                color: isSelected ? color.shade800 : Colors.grey.shade600
              )
            ),
          ],
        ),
      ),
    );
  }
}