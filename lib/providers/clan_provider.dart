import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClanProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  Map<String, dynamic>? _myClan;
  String? _myRole;
  int _myContributionXp = 0;

  // Getters
  bool get isLoading => _isLoading;
  bool get hasClan => _myClan != null;
  Map<String, dynamic>? get myClan => _myClan;
  String? get myRole => _myRole;
  int get myContributionXp => _myContributionXp;

  // 🔥 Fetch current user's clan data (Called on App Start & Refreshes)
  Future<void> fetchMyClanData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _clearData();
      return;
    }

    _isLoading = true;
    notifyListeners(); // Notify UI that loading has started

    try {
      // ১. চেক করা ইউজার কোনো ক্ল্যানের মেম্বার কিনা
      final memberRes = await _supabase
          .from('clan_members')
          .select('clan_id, role, contribution_xp')
          .eq('user_id', user.id)
          .maybeSingle();

      if (memberRes != null) {
        // ২. মেম্বার হলে তার ক্ল্যানের বিস্তারিত ডাটা আনা
        final clanRes = await _supabase
            .from('clans')
            .select('*')
            .eq('id', memberRes['clan_id'])
            .single();

        _myClan = clanRes;
        _myRole = memberRes['role'];
        _myContributionXp = memberRes['contribution_xp'] ?? 0;
      } else {
        // ক্ল্যানে না থাকলে সব ডাটা নাল করে দেওয়া
        _clearData(notify: false); 
      }
    } catch (e) {
      debugPrint("ClanProvider Fetch Error: $e");
      _clearData(notify: false);
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify UI that data is ready
    }
  }

  // 🔥 Manual update helper (When creating or leaving a clan to avoid extra DB calls instantly)
  void setClanData(Map<String, dynamic> clan, String role, int xp) {
    _myClan = clan;
    _myRole = role;
    _myContributionXp = xp;
    notifyListeners();
  }

  // 🔥 Clear data (Used when kicked, left clan, or logged out)
  void clearClan() {
    _clearData();
  }

  void _clearData({bool notify = true}) {
    _myClan = null;
    _myRole = null;
    _myContributionXp = 0;
    _isLoading = false;
    if (notify) notifyListeners();
  }
}