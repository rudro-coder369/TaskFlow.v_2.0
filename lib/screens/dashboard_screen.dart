import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // ইউটিউব লিংকের জন্য

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;

  // Countdown Variables
  Map<String, int> _timeLeft = {'days': 0, 'hours': 0, 'minutes': 0, 'seconds': 0};
  Timer? _countdownTimer;
  DateTime _targetDate = DateTime(2026, 12, 31, 23, 59, 59); // Default
  String _examTitle = "EXAM";

  // Banner Slider Variables
  final PageController _pageController = PageController(initialPage: 0);
  int _currentBannerPage = 0;
  Timer? _bannerTimer;

  // Clan Variables
  String? _topClanName;
  int? _topClanHours;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    await _fetchUserDataAndLogic();
    _startCountdown();
    _startBannerAutoScroll();
    
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchUserDataAndLogic() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // ১. ইউজারের ক্লাস ফেচ করে কাউন্টডাউন সেট করা
      final profileData = await _supabase.from('profiles').select('academic_class').eq('id', userId).maybeSingle();
      
      if (profileData != null) {
        final academicClass = profileData['academic_class']?.toString() ?? '';
        if (academicClass == '11' || academicClass == '12') {
          // HSC Target: May 31, 2027
          _targetDate = DateTime(2027, 5, 31, 23, 59, 59);
          _examTitle = "HSC 2027";
        } else if (academicClass == '9' || academicClass == '10' || academicClass == 'SSC') {
          // SSC Target: Dec 31, 2026
          _targetDate = DateTime(2026, 12, 31, 23, 59, 59);
          _examTitle = "SSC 2027";
        }
      }

      // ২. টপ ক্ল্যান ফেচ করা (আপাতত null রাখছি, ডাটাবেসে থাকলে ফেচ করে নিবি)
      // _topClanName = "Bogura Zilla School"; // যদি ডাটা পাস, আনকমেন্ট করবি
      // _topClanHours = 1250;
      
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _bannerTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ==============================
  // COUNTDOWN LOGIC
  // ==============================
  void _startCountdown() {
    _calculateTimeLeft();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _calculateTimeLeft();
    });
  }

  void _calculateTimeLeft() {
    final diff = _targetDate.difference(DateTime.now());
    if (diff.isNegative) return;
    setState(() {
      _timeLeft = {
        'days': diff.inDays,
        'hours': diff.inHours % 24,
        'minutes': diff.inMinutes % 60,
        'seconds': diff.inSeconds % 60
      };
    });
  }

  // ==============================
  // BANNER SLIDER LOGIC
  // ==============================
  void _startBannerAutoScroll() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_currentBannerPage < 3) {
        _currentBannerPage++;
      } else {
        _currentBannerPage = 0;
      }
      
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentBannerPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ইউটিউব লিংক ওপেন করার ফাংশন
  Future<void> _launchYouTubeVideo() async {
    final Uri url = Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ'); // 👈 তোর টিউটোরিয়াল লিংক দিবি
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: Text(
            "LOADING DASHBOARD...",
            style: TextStyle(color: Color(0xFF10A37F), fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // ==========================================
            // 1. BANNER SLIDER (SPONSORS / EVENTS)
            // ==========================================
            SizedBox(
              height: 180, 
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentBannerPage = page;
                  });
                },
                children: [
                  _buildImageBanner('assets/poster1.jpg'), 
                  _buildImageBanner('assets/poster2.jpg'),
                  _buildImageBanner('assets/poster3.jpg'),
                  _buildImageBanner('assets/poster4.jpg'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentBannerPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentBannerPage == index ? const Color(0xFF10A37F) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 2. BREAKING NEWS (GLASSMORPHISM)
            // ==========================================
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text("UPDATE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Qaave Elite Room is now live! Join your clan and start grinding.",
                          style: TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 3. DYNAMIC EXAM COUNTDOWN
            // ==========================================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.lightBlue.shade50),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(color: Color(0xFFF0F9FF), shape: BoxShape.circle),
                        child: const Icon(LucideIcons.timer, color: Colors.lightBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_examTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          const Text("TIME LEFT TO PREPARE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1.5)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTimeBox(_timeLeft['days'] ?? 0, "DAY"),
                      const Text(":", style: TextStyle(fontSize: 24, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w300)),
                      _buildTimeBox(_timeLeft['hours'] ?? 0, "HR"),
                      const Text(":", style: TextStyle(fontSize: 24, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w300)),
                      _buildTimeBox(_timeLeft['minutes'] ?? 0, "MIN"),
                      const Text(":", style: TextStyle(fontSize: 24, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w300)),
                      _buildTimeBox(_timeLeft['seconds'] ?? 0, "SEC", isHighlight: true),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 4. WEEKLY TOP CLAN (Conditional Rendering)
            // ==========================================
            if (_topClanName != null && _topClanName!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFEDD5), Color(0xFFFFFBFC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.orange.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.trophy, color: Colors.orange, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("WEEKLY TOP CLAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange, letterSpacing: 1.5)),
                          const SizedBox(height: 4),
                          Text(
                            _topClanName!,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Icon(LucideIcons.flame, color: Colors.orange, size: 16),
                        const SizedBox(height: 4),
                        Text(
                          "${_topClanHours}h",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.orange),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ==========================================
            // 5. YOUTUBE TUTORIAL SECTION
            // ==========================================
            const Text("How to use Qaave?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _launchYouTubeVideo,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFF0F172A), // ডার্ক ব্যাকগ্রাউন্ড (থাম্বনেইলের বদলে)
                  image: const DecorationImage(
                    image: AssetImage('assets/poster1.jpg'), // 👈 থাম্বনেইল হিসেবে আপাতত পোস্টার দিলাম, তুই চাইলে অন্য ছবি দিতে পারিস
                    fit: BoxFit.cover,
                    opacity: 0.6, // ডার্ক ওভারলে
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))
                  ],
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                    ),
                    child: const Icon(LucideIcons.play, color: Colors.white, size: 36), // ইউটিউব প্লে বাটন
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  // ==============================
  // HELPER WIDGETS
  // ==============================
  Widget _buildTimeBox(int value, String label, {bool isHighlight = false}) {
    return Container(
      width: 65, height: 75,
      decoration: BoxDecoration(
        color: isHighlight ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isHighlight ? const Color(0xFF10A37F).withOpacity(0.3) : Colors.transparent),
        boxShadow: isHighlight ? [BoxShadow(color: const Color(0xFF10A37F).withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))] : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toString().padLeft(2, '0'), 
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isHighlight ? const Color(0xFF10A37F) : const Color(0xFF334155), fontFamily: 'monospace')
          ),
          Text(
            label, 
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isHighlight ? const Color(0xFF10A37F).withOpacity(0.7) : const Color(0xFF94A3B8))
          ),
        ],
      ),
    );
  }

  Widget _buildImageBanner(String imagePath) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
             return Container(
               color: Colors.grey.shade300,
               child: const Center(child: Icon(LucideIcons.image, color: Colors.grey, size: 40)),
             );
          },
        ),
      ),
    );
  }
}