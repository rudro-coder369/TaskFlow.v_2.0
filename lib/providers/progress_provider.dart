import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgressProvider with ChangeNotifier {
  Map<String, dynamic> userProfile = {'username': 'Scholar', 'email': ''};
  Map<String, dynamic> syllabusProgress = {};
  
  // রুটিন ডেটা স্টোর করার Map
  Map<String, List<Map<String, dynamic>>> _weeklyRoutine = {};
  Map<String, List<Map<String, dynamic>>> get weeklyRoutine => _weeklyRoutine;

  final _supabase = Supabase.instance.client;

  // প্রোফাইল, সিলেবাস এবং রুটিন একসাথে ফেচ করা
  Future<void> fetchProfileData() async {
    final session = _supabase.auth.currentSession;
    if (session == null) return;
    
    try {
      final data = await _supabase.from('profiles').select().eq('id', session.user.id).maybeSingle();
      if (data != null) {
        userProfile = {
          'username': data['username'] ?? 'Scholar',
          'email': session.user.email ?? '',
        };
        syllabusProgress = Map<String, dynamic>.from(data['syllabus_progress'] ?? {});
        
        if (data['routine'] != null) {
          _weeklyRoutine = Map<String, List<Map<String, dynamic>>>.from(
            (data['routine'] as Map).map((key, value) => MapEntry(key, List<Map<String, dynamic>>.from(value)))
          );
        }
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Provider Fetch Error: $e");
    }
  }

  // উইকলি রুটিন আপডেট করা
  Future<void> updateRoutine(String day, List<Map<String, dynamic>> tasks) async {
    final session = _supabase.auth.currentSession;
    if (session == null) return;

    _weeklyRoutine[day] = tasks;
    notifyListeners();
    
    try {
      await _supabase.from('profiles').update({
        'routine': _weeklyRoutine
      }).eq('id', session.user.id);
    } catch (e) {
      debugPrint("Routine Update Error: $e");
    }
  }

  // 🔥 সিলেবাস আপডেট করা (basic, cq, mcq, mastered, revise সহ)
  Future<void> manuallyUpdateSyllabus(String subjectKey, int chapterIndex, String action) async {
    final session = _supabase.auth.currentSession;
    if (session == null) return;

    if (!syllabusProgress.containsKey(subjectKey)) {
      syllabusProgress[subjectKey] = {};
    }
    
    String chapKey = chapterIndex.toString();
    if (!syllabusProgress[subjectKey].containsKey(chapKey)) {
      syllabusProgress[subjectKey][chapKey] = {
        'basic': false, 
        'cq': false, 
        'mcq': false, 
        'mastered': false, 
        'revise': 0, // রেভাইস কাউন্টার
        'isDone': false
      };
    }

    final currentProgress = syllabusProgress[subjectKey][chapKey];
    
    // যদি অ্যাকশন 'revise' হয় তবে আলাদা লজিক, অন্যথায় Bool ফ্ল্যাগ আপডেট
    if (action == 'revise') {
      int currentReviseCount = currentProgress['revise'] ?? 0;
      currentProgress['revise'] = currentReviseCount + 1;
    } else {
      currentProgress[action] = true;
    }

    // লজিক চেক করে চ্যাপ্টার কমপ্লিট (isDone) মার্ক করা
    if (currentProgress['isDone'] != true) {
      if (subjectKey.toLowerCase().contains('english') || subjectKey.toLowerCase().contains('ict')) {
        if (currentProgress['basic'] == true) currentProgress['isDone'] = true;
      } else if (subjectKey.toLowerCase().contains('bangla_2nd') || subjectKey.toLowerCase().contains('bangla2')) {
        if (currentProgress['basic'] == true && currentProgress['mcq'] == true) currentProgress['isDone'] = true;
      } else {
        if (currentProgress['basic'] == true && currentProgress['cq'] == true && currentProgress['mcq'] == true) {
          currentProgress['isDone'] = true;
        }
      }
    }

    syllabusProgress[subjectKey][chapKey] = currentProgress;
    notifyListeners();

    try {
      await _supabase.from('profiles').update({
        'syllabus_progress': syllabusProgress,
      }).eq('id', session.user.id);
    } catch (e) {
      debugPrint("Syllabus Update Error: $e");
    }
  }

  // আলাদাভাবে রিভাইজ কাউন্টার বাড়ানোর ফাংশন (দরকার হলে ইউজ করবি)
  Future<void> incrementRevise(String subjectKey, int chapterIndex) async {
    await manuallyUpdateSyllabus(subjectKey, chapterIndex, 'revise');
  }
}