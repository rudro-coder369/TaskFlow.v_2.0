import 'package:flutter/material.dart';

class TimerProvider with ChangeNotifier {
  int _currentTaskSeconds = 0;
  bool _isRunning = false;

  int get currentTaskSeconds => _currentTaskSeconds;
  bool get isRunning => _isRunning;

  // মেইন টাইমার থেকে প্রতি সেকেন্ডে টাইম সিঙ্ক হবে
  void syncTime(int seconds, bool running) {
    if (_currentTaskSeconds != seconds || _isRunning != running) {
      _currentTaskSeconds = seconds;
      _isRunning = running;
      notifyListeners();
    }
  }

  // Deep Focus স্ক্রিন থেকে পজ বাটনে চাপ দিলে এটা কল করবি
  void stopTimer() {
    _isRunning = false;
    notifyListeners();
  }
}