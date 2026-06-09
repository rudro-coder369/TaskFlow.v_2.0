import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

class ClanLeaderboardView extends StatefulWidget {
  final Map<String, dynamic> clanData;

  const ClanLeaderboardView({super.key, required this.clanData});

  @override
  State<ClanLeaderboardView> createState() => _ClanLeaderboardViewState();
}

class _ClanLeaderboardViewState extends State<ClanLeaderboardView> {
  // লিডারবোর্ড টগল: Global (BD) vs Local 
  bool _isGlobal = true;

  // ডামি ডাটা: গ্লোবাল টপ ক্ল্যান (Supabase থেকে order('total_xp') দিয়ে আনবি)
  final List<Map<String, dynamic>> _globalRankings = [
    {"rank": 1, "clan": "TITANS", "school": "Rajuk Uttara Model College", "xp": 845000, "isMe": false},
    {"rank": 2, "clan": "ALPHA BOYS", "school": "Notre Dame College", "xp": 812000, "isMe": false},
    {"rank": 3, "clan": "SILVER BULLET", "school": "Dhaka Collegiate School", "xp": 790000, "isMe": false},
    {"rank": 4, "clan": "SPARTANS", "school": "Viqarunnisa Noon School", "xp": 750000, "isMe": false},
    {"rank": 5, "clan": "NINJAS", "school": "Ideal School and College", "xp": 710000, "isMe": false},
    {"rank": 84, "clan": "YOUR CLAN", "school": "Your School Name", "xp": 14500, "isMe": true}, // User's clan demo
  ];

  // ডামি ডাটা: লোকাল (বগুড়া রিজিয়ন) টপ ক্ল্যান
  final List<Map<String, dynamic>> _localRankings = [
    {"rank": 1, "clan": "BZS WARRIORS", "school": "Bogura Zilla School", "xp": 450000, "isMe": false},
    {"rank": 2, "clan": "YOUR CLAN", "school": "Your School Name", "xp": 14500, "isMe": true}, // User's clan demo
    {"rank": 3, "clan": "CANTONMENT X", "school": "Armed Forces Medical", "xp": 12000, "isMe": false},
    {"rank": 4, "clan": "RDA ELITES", "school": "RDA Laboratory School", "xp": 9500, "isMe": false},
    {"rank": 5, "clan": "BIAM KNIGHTS", "school": "BIAM Model School", "xp": 8200, "isMe": false},
  ];

  @override
  Widget build(BuildContext context) {
    final currentList = _isGlobal ? _globalRankings : _localRankings;
    
    // টপ ৩ জন এবং বাকিদের আলাদা করা
    final topThree = currentList.where((c) => c['rank'] <= 3).toList();
    final others = currentList.where((c) => c['rank'] > 3).toList();

    return Column(
      children: [
        // ==========================================
        // 🎛️ REGION TOGGLE (Global vs Local)
        // ==========================================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Container(
            height: 48,
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isGlobal = true),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _isGlobal ? const Color(0xFF10A37F) : Colors.transparent, borderRadius: BorderRadius.circular(24)),
                      child: Text("GLOBAL (BD)", style: TextStyle(color: _isGlobal ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isGlobal = false),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: !_isGlobal ? const Color(0xFF10A37F) : Colors.transparent, borderRadius: BorderRadius.circular(24)),
                      child: Text("BOGURA RANK", style: TextStyle(color: !_isGlobal ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // ==========================================
                // 🏆 THE PODIUM (Top 3 Clans)
                // ==========================================
                if (topThree.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 32, left: 20, right: 20),
                    child: SizedBox(
                      height: 220,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Rank 2 (Silver)
                          if (topThree.length >= 2) _buildPodiumItem(topThree[1], 140, Colors.blueGrey.shade300, "2"),
                          const SizedBox(width: 12),
                          // Rank 1 (Gold)
                          if (topThree.isNotEmpty) _buildPodiumItem(topThree[0], 180, Colors.amber, "1", isCenter: true),
                          const SizedBox(width: 12),
                          // Rank 3 (Bronze)
                          if (topThree.length >= 3) _buildPodiumItem(topThree[2], 120, const Color(0xFFCD7F32), "3"),
                        ],
                      ),
                    ),
                  ),

                // ==========================================
                // 📜 THE LIST (Rank 4 and below)
                // ==========================================
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("CONTENDERS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      const SizedBox(height: 16),
                      
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: others.length,
                        separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 24),
                        itemBuilder: (context, index) {
                          return _buildListTile(others[index]);
                        },
                      ),
                      const SizedBox(height: 40), // Padding for bottom nav
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // WIDGET: PODIUM ITEM (Top 3)
  // ==========================================
  Widget _buildPodiumItem(Map<String, dynamic> clan, double height, Color color, String rank, {bool isCenter = false}) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isCenter) const Icon(LucideIcons.crown, color: Colors.amber, size: 32),
          if (isCenter) const SizedBox(height: 8),
          
          Text(clan['clan'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isCenter ? 14 : 12)),
          Text(NumberFormat.compact().format(clan['xp']), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
          const SizedBox(height: 8),
          
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.8), color.withOpacity(0.2)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(top: BorderSide(color: color, width: 2)),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 12),
            child: Text(rank, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET: LIST TILE (Rank 4+)
  // ==========================================
  Widget _buildListTile(Map<String, dynamic> clan) {
    final bool isMe = clan['isMe'];

    return Container(
      padding: isMe ? const EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: isMe ? BoxDecoration(
        color: const Color(0xFF10A37F).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10A37F).withOpacity(0.5)),
      ) : null,
      child: Row(
        children: [
          SizedBox(width: 30, child: Text("#${clan['rank']}", style: TextStyle(color: isMe ? const Color(0xFF10A37F) : Colors.grey, fontWeight: FontWeight.bold, fontSize: 16))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clan['clan'], style: TextStyle(color: isMe ? Colors.white : Colors.grey.shade300, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(clan['school'], style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(LucideIcons.star, color: Colors.orange, size: 14),
              const SizedBox(width: 4),
              Text(NumberFormat.compact().format(clan['xp']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}