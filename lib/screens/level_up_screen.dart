import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class LevelUpScreen extends StatefulWidget {
  const LevelUpScreen({super.key});

  @override
  State<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends State<LevelUpScreen> {
  double _currentWeight = 45.0; 
  final double _targetWeight = 60.0; 

  String _todayBanglaDate = "";
  int _initialDayIndex = 0;
  late PageController _dietPageController;

  final List<String> _daysEn = ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  final Map<String, String> _daysBn = {
    'Saturday': 'শনিবার', 'Sunday': 'রবিবার', 'Monday': 'সোমবার',
    'Tuesday': 'মঙ্গলবার', 'Wednesday': 'বুধবার', 'Thursday': 'বৃহস্পতিবার', 'Friday': 'শুক্রবার'
  };

  final Map<String, Map<String, String>> _dietPlan = {
    'Saturday': { 'breakfast': 'দুধ, ২টা ডিম, কলা, পিনাট বাটার টোস্ট', 'lunch': 'ভাত, মুরগির মাংস, ঘন ডাল, সবজি', 'snacks': 'ছোলা ভাজা, মুড়ি বা দই', 'dinner': 'ভাত, বড় মাছ বা মাংস, দুধ' },
    'Sunday': { 'breakfast': 'ওটস বা সিরিয়াল, দুধ, ২টা ডিম, আপেল', 'lunch': 'ভাত, গরুর মাংস, ডাল, আলু ভর্তা', 'snacks': 'পিনাট বাটার দিয়ে ২টা রুটি, কলা', 'dinner': 'ভাত, ডিম ভুনা, সবজি, দুধ' },
    'Monday': { 'breakfast': 'পরোটা, ডাল ভুনা, ২টা ডিম ভাজা', 'lunch': 'ভাত, বড় মাছ, ঘন ডাল, সবজি', 'snacks': 'দুধ, বিস্কুট, মিক্সড বাদাম', 'dinner': 'ভাত, মুরগির মাংস, সালাদ' },
    'Tuesday': { 'breakfast': 'দুধ-কলা দিয়ে ভাত বা চিড়া, ২টা ডিম', 'lunch': 'ভাত, ডিমের কোরমা, ডাল, সবজি', 'snacks': 'ছোলা বুট, মুড়ি, চা', 'dinner': 'ভাত, মাছ ভাজা, ডাল, দুধ' },
    'Wednesday': { 'breakfast': 'পাউরুটি, পিনাট বাটার, দুধ, কলা', 'lunch': 'ভাত, গরুর মাংস বা খাসি, সালাদ', 'snacks': 'দই, চিড়া, গুড়', 'dinner': 'ভাত, ডাল, মুরগি, সবজি' },
    'Thursday': { 'breakfast': 'রুটি, ভাজি, ২টা ডিম, চা', 'lunch': 'ভাত, ছোট মাছ চচ্চড়ি, ঘন ডাল', 'snacks': 'কলা, মিক্সড বাদাম বা পিনাট বাটার', 'dinner': 'ভাত, ডিম ভুনা, দুধ' },
    'Friday': { 'breakfast': 'খিচুড়ি, ডিম ভাজা, সালাদ', 'lunch': 'পোলাও বা বিরিয়ানি, মুরগির রোস্ট', 'snacks': 'মিষ্টি বা পুডিং, দুধ', 'dinner': 'ভাত, হালকা মাংস বা মাছ, দুধ' },
  };

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final now = DateTime.now();
    final dayEn = DateFormat('EEEE').format(now);
    _initialDayIndex = _daysEn.indexOf(dayEn) != -1 ? _daysEn.indexOf(dayEn) : 0;
    
    int startPage = 1000 * 7 + _initialDayIndex;
    _dietPageController = PageController(initialPage: startPage, viewportFraction: 0.88);
    
    setState(() {
      _currentWeight = prefs.getDouble('current_weight') ?? 45.0;
      _todayBanglaDate = _getBanglaDate(now, dayEn);
    });
  }

  String _getBanglaDate(DateTime date, String dayEn) {
    const months = ['জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'];
    String day = date.day.toString();
    String year = date.year.toString();
    const enNum = ['0','1','2','3','4','5','6','7','8','9'];
    const bnNum = ['০','১','২','৩','৪','৫','৬','৭','৮','৯'];
    for (int i=0; i<10; i++) {
      day = day.replaceAll(enNum[i], bnNum[i]);
      year = year.replaceAll(enNum[i], bnNum[i]);
    }
    return "${_daysBn[dayEn]}, $day ${months[date.month-1]} $year";
  }

  void _showWeightDialog() {
    TextEditingController wc = TextEditingController(text: _currentWeight.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Update Weight", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        content: TextField(
          controller: wc, 
          keyboardType: TextInputType.number, 
          decoration: InputDecoration(
            hintText: "Enter weight in kg",
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          )
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10A37F),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              double nw = double.tryParse(wc.text) ?? _currentWeight;
              await prefs.setDouble('current_weight', nw);
              setState(() => _currentWeight = nw);
              Navigator.pop(context);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double progress = _currentWeight / _targetWeight;
    if (progress > 1.0) progress = 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), 
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(LucideIcons.leaf, color: Color(0xFF10A37F), size: 24),
            SizedBox(width: 8),
            Text("Fitness & Nutrition", style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, letterSpacing: -0.5, fontSize: 20)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 20, bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- WEIGHT TRACKER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildWeightCard(progress),
            ),
            const SizedBox(height: 32),

            // --- NUTRITION CYCLE HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Nutrition Cycle", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  Text(_todayBanglaDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10A37F))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // --- NUTRITION CARDS (Infinite Scroll) ---
            SizedBox(
              height: 320, // 🔥 FIX: Height increased to prevent overflow
              child: PageView.builder(
                controller: _dietPageController,
                itemBuilder: (context, index) {
                  int actualIndex = index % 7; 
                  String enDay = _daysEn[actualIndex];
                  bool isToday = actualIndex == _initialDayIndex;
                  return _buildDietCard(enDay, _dietPlan[enDay]!, isToday);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightCard(double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(28), 
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8))]
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF10A37F).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(LucideIcons.target, size: 16, color: Color(0xFF10A37F)),
                  ),
                  const SizedBox(width: 12),
                  const Text("Target: 60 KG", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ],
              ),
              GestureDetector(
                onTap: _showWeightDialog, 
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.settings2, size: 18, color: Color(0xFF64748B))
                )
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(_currentWeight.toStringAsFixed(1), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), height: 1)),
                  const SizedBox(width: 4),
                  const Text("kg", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                ],
              ),
              Text("${(progress * 100).toInt()}%", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10A37F))),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress, 
              minHeight: 12, 
              backgroundColor: const Color(0xFF10A37F).withOpacity(0.1), 
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10A37F))
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietCard(String dayEn, Map<String, String> dayPlan, bool isToday) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isToday ? const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null,
        color: isToday ? null : Colors.white, 
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isToday ? Colors.transparent : Colors.grey.shade100),
        boxShadow: [BoxShadow(color: (isToday ? const Color(0xFF0EA5E9) : Colors.black).withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_daysBn[dayEn]!, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isToday ? Colors.white : const Color(0xFF0F172A))),
              if (isToday) 
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(10)), 
                  child: const Text("TODAY", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2))
                ),
            ],
          ),
          const SizedBox(height: 24),
          _dietRowItem("সকাল", dayPlan['breakfast']!, LucideIcons.sunrise, isToday),
          _dietRowItem("দুপুর", dayPlan['lunch']!, LucideIcons.sun, isToday),
          _dietRowItem("বিকাল", dayPlan['snacks']!, LucideIcons.coffee, isToday),
          _dietRowItem("রাত", dayPlan['dinner']!, LucideIcons.moon, isToday),
        ],
      ),
    );
  }

  Widget _dietRowItem(String time, String food, IconData icon, bool isToday) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: isToday ? Colors.white70 : Colors.grey.shade400)
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isToday ? Colors.white.withOpacity(0.8) : const Color(0xFF94A3B8))),
                const SizedBox(height: 4),
                Text(food, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isToday ? Colors.white : const Color(0xFF334155), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}