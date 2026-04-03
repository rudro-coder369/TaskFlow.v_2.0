import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgressProvider with ChangeNotifier {
  Map<String, dynamic> userProfile = {'username': 'Scholar', 'email': ''};
  Map<String, dynamic> syllabusProgress = {};
  
  final _supabase = Supabase.instance.client;

  // 📥 প্রোফাইল এবং সিলেবাস ফেচ করা
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
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Provider Fetch Error: $e");
    }
  }

  // 📝 সিলেবাস আপডেট করা (Syllabus Screen থেকে কল হবে)
  Future<void> manuallyUpdateSyllabus(String subjectKey, int chapterIndex, String action) async {
    final session = _supabase.auth.currentSession;
    if (session == null) return;

    if (!syllabusProgress.containsKey(subjectKey)) {
      syllabusProgress[subjectKey] = {};
    }
    
    String chapKey = chapterIndex.toString();
    if (!syllabusProgress[subjectKey].containsKey(chapKey)) {
      syllabusProgress[subjectKey][chapKey] = {
        'basic': false, 'cq': false, 'mcq': false, 'mastered': false, 'isDone': false
      };
    }

    final currentProgress = syllabusProgress[subjectKey][chapKey];
    if (currentProgress['isDone'] == true) return;

    // অ্যাকশন ট্রু করা (যেমন: basic = true)
    currentProgress[action] = true;

    // ৪টা ডান হলে চ্যাপ্টার কমপ্লিট
    if (currentProgress['basic'] == true && currentProgress['mastered'] == true) {
      // English/ICT logic bypass (can be enhanced based on your needs)
      if (currentProgress['cq'] == true && currentProgress['mcq'] == true) {
         currentProgress['isDone'] = true;
      } else if (subjectKey.toLowerCase().contains('english') || subjectKey.toLowerCase().contains('ict')) {
         currentProgress['isDone'] = true;
      } else if ((subjectKey.toLowerCase().contains('bangla_2nd') || subjectKey.toLowerCase().contains('bangla2')) && currentProgress['mcq'] == true) {
         currentProgress['isDone'] = true;
      }
    }

    syllabusProgress[subjectKey][chapKey] = currentProgress;
    notifyListeners();

    // Supabase এ সেভ করা
    try {
      await _supabase.from('profiles').update({
        'syllabus_progress': syllabusProgress,
      }).eq('id', session.user.id);
    } catch (e) {
      debugPrint("Syllabus Update Error: $e");
    }
  }
}