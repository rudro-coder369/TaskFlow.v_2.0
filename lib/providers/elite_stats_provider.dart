import 'package:flutter/material.dart';

class EliteStatsProvider extends ChangeNotifier {
  int _lifetimeSeconds = 0;

  int get lifetimeSeconds => _lifetimeSeconds;

  void updateLifetimeSeconds(int seconds) {
    _lifetimeSeconds = seconds;
    notifyListeners();
  }

  // যেকোনো স্ক্রিন থেকে লেভেল, র‍্যাংক, XP পেতে এটা কল করবি
  Map<String, dynamic> get stats {
    final hours = _lifetimeSeconds / 3600;
    final level = (hours / 2).floor() + 1;
    final finalXp = (hours * 99).floor();

    Map<String, dynamic> rank = {
      'name': 'Silver',
      'color': Colors.grey.shade600,
      'bg': Colors.grey.shade100,
      'border': Colors.grey.shade200,
    };
    if (finalXp >= 24750) { 
      rank = {'name': 'Legend', 'color': Colors.purple.shade600, 'bg': Colors.purple.shade50, 'border': Colors.purple.shade200}; 
    } else if (finalXp >= 14850) { 
      rank = {'name': 'Emperor', 'color': Colors.red.shade600, 'bg': Colors.red.shade50, 'border': Colors.red.shade200}; 
    } else if (finalXp >= 7920) { 
      rank = {'name': 'Prime', 'color': Colors.indigo.shade600, 'bg': Colors.indigo.shade50, 'border': Colors.indigo.shade200}; 
    } else if (finalXp >= 3960) { 
      rank = {'name': 'Elite', 'color': Colors.orange.shade600, 'bg': Colors.orange.shade50, 'border': Colors.orange.shade200}; 
    } else if (finalXp >= 1485) { 
      rank = {'name': 'Platinum', 'color': Colors.lightBlue.shade600, 'bg': Colors.lightBlue.shade50, 'border': Colors.lightBlue.shade200}; 
    }

    return {'level': level, 'finalXp': finalXp, 'rank': rank};
  }
}