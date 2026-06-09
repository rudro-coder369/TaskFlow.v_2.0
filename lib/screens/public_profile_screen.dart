import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PublicProfileScreen extends StatefulWidget {
  final String targetUserId; 

  const PublicProfileScreen({super.key, required this.targetUserId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  
  Map<String, dynamic>? _profileData;
  int _totalFocusSeconds = 0; 

  @override
  void initState() {
    super.initState();
    _fetchPublicProfile();
  }

  Future<void> _fetchPublicProfile() async {
    try {
      // ১. প্রোফাইল ডাটা আনা
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('username, full_name, school_name, academic_class, academic_group, bio, badges, tags, avatar_seed, created_at')
          .eq('id', widget.targetUserId)
          .maybeSingle();

      if (profileResponse == null) {
        setState(() => _hasError = true);
        return;
      }

      // ২. টোটাল স্টাডি টাইম ক্যালকুলেট করা (🔥 100% Lifetime Data)
      final logsResponse = await Supabase.instance.client
          .from('daily_logs')
          .select('study_seconds')
          .eq('user_id', widget.targetUserId);

      int totalSeconds = 0;
      for (var log in logsResponse as List) {
        totalSeconds += (int.tryParse(log['study_seconds'].toString()) ?? 0);
      }

      setState(() {
        _profileData = profileResponse;
        _totalFocusSeconds = totalSeconds;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint("Public Profile Error: $e");
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  // 🚀 ELITE STATS CALCULATION
  Map<String, dynamic> _calculateEliteStats(int totalSeconds) {
    final hours = totalSeconds / 3600;
    final level = (hours / 2).floor() + 1;
    final finalXp = (hours * 99).floor();

    String rankName = 'Silver';
    if (finalXp >= 24750) rankName = 'Legend';
    else if (finalXp >= 14850) rankName = 'Emperor';
    else if (finalXp >= 7920) rankName = 'Prime';
    else if (finalXp >= 3960) rankName = 'Elite';
    else if (finalXp >= 1485) rankName = 'Platinum';

    return {'level': level, 'finalXp': finalXp, 'rankName': rankName};
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return "Unknown";
    final date = DateTime.parse(isoString);
    return DateFormat('MMMM yyyy').format(date); 
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF10A37F))),
      );
    }

    if (_hasError || _profileData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
        body: const Center(child: Text("Scholar not found or private.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
      );
    }

    final p = _profileData!;
    final badges = p['badges'] as List<dynamic>? ?? [];
    final tags = p['tags'] as List<dynamic>? ?? [];
    final bioText = p['bio']?.toString().trim() ?? "";
    final currentAvatar = p['avatar_seed'] ?? 'Felix';
    
    final double focusHours = _totalFocusSeconds / 3600.0;
    
    final eliteStats = _calculateEliteStats(_totalFocusSeconds);
    final String rankName = eliteStats['rankName'];
    final int currentXp = eliteStats['finalXp'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // 🔥 SLEEK CENTERED APP BAR (Compact Height)
          SliverAppBar(
            expandedHeight: bioText.isNotEmpty ? 270.0 : 240.0, // 🔥 Height Reduced
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF10A37F), 
            iconTheme: const IconThemeData(color: Colors.white),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)), 
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF10A37F), Color(0xFF0D8C6C)], 
                    begin: Alignment.topCenter, 
                    end: Alignment.bottomCenter
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end, // 🔥 Pushes content down to respect top nav
                    children: [
                      // 🔥 Centered Avatar
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.2)),
                        child: CircleAvatar(
                          radius: 36, 
                          backgroundColor: Colors.white,
                          backgroundImage: NetworkImage('https://api.dicebear.com/8.x/notionists/png?seed=$currentAvatar&backgroundColor=f8fafc'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(p['full_name'] ?? "Unknown Scholar", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text("@${p['username'] ?? 'user'}", style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500)),
                      if (bioText.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            bioText, 
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)), 
                            maxLines: 2, 
                            overflow: TextOverflow.ellipsis
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 16), 

                      // 🔥 PREMIUM CENTERED STATS BOX (Level | Rank | XP)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.15), // Darker glassmorphism
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // LEVEL
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("${eliteStats['level']}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text("LEVEL", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ],
                            ),
                            
                            // DIVIDER
                            Container(width: 1, height: 24, color: Colors.white.withOpacity(0.2)),

                            // RANK (🔥 Icon Removed, Color is White)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(rankName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 2),
                                Text("RANK", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ],
                            ),

                            // DIVIDER
                            Container(width: 1, height: 24, color: Colors.white.withOpacity(0.2)),

                            // XP
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(NumberFormat.compact().format(currentXp), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text("TOTAL XP", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // 🔥 Bottom Spacing to keep the card slightly elevated from the bottom edge
                      const SizedBox(height: 24), 
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 🔥 BODY CONTENT
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CUSTOM TAGS ---
                  if (tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10A37F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF10A37F).withOpacity(0.3)),
                        ),
                        child: Text(tag.toString(), style: const TextStyle(color: Color(0xFF10A37F), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // --- Stats Row ---
                  Row(
                    children: [
                      Expanded(child: _buildStatCard(LucideIcons.flame, "${focusHours.toStringAsFixed(1)}h", "Focused")),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard(LucideIcons.medal, "${badges.length}", "Badges")),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- Academic Identity ---
                  const Text("Academic Identity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Column(
                      children: [
                        _buildInfoTile(LucideIcons.building, "Institution", p['school_name'] ?? "Not specified"),
                        const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F9)),
                        _buildInfoTile(LucideIcons.graduationCap, "Class", p['academic_class'] != null ? "Class ${p['academic_class']}" : "Not specified"),
                        const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F9)),
                        _buildInfoTile(LucideIcons.layers, "Group", p['academic_group']?.toString().toUpperCase() ?? "Not specified"),
                        const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F9)),
                        _buildInfoTile(LucideIcons.calendarCheck, "Joined TaskFlow", _formatDate(p['created_at'])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- Badges Showcase ---
                  const Row(
                    children: [
                      Text("Honor Badges", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Spacer(),
                      Icon(LucideIcons.shieldCheck, color: Color(0xFF10A37F), size: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (badges.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid)),
                      child: const Column(
                        children: [
                          Icon(LucideIcons.lock, color: Colors.grey, size: 32),
                          SizedBox(height: 8),
                          Text("No badges earned yet", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: badges.map((badgeName) => _buildBadgeItem(badgeName.toString())).toList(),
                    ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.lightBlue.shade50), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF10A37F).withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFF10A37F), size: 16),
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: const Color(0xFF10A37F)),
      ),
      title: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
    );
  }

  Widget _buildBadgeItem(String badgeName) {
    IconData bIcon = LucideIcons.award;
    Color bColor = Colors.orange;

    if (badgeName.toLowerCase().contains("math")) { bIcon = LucideIcons.calculator; bColor = Colors.blue; } 
    else if (badgeName.toLowerCase().contains("night")) { bIcon = LucideIcons.moon; bColor = Colors.indigo; } 
    else if (badgeName.toLowerCase().contains("fire") || badgeName.toLowerCase().contains("streak")) { bIcon = LucideIcons.flame; bColor = Colors.deepOrange; }

    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: bColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(bIcon, color: bColor, size: 32),
          const SizedBox(height: 8),
          Text(badgeName, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: bColor.withOpacity(0.8))),
        ],
      ),
    );
  }
}