import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

class ClanHomeView extends StatelessWidget {
  final Map<String, dynamic> clanData;
  final Map<String, dynamic> roleInfo;

  const ClanHomeView({
    super.key, 
    required this.clanData, 
    required this.roleInfo,
  });

  // ক্ল্যান ট্যাগ কপি করার ফাংশন
  void _copyClanTag(BuildContext context) {
    // ডাটাবেসে যদি ট্যাগ না থাকে, তবে ডামি একটা ট্যাগ দেখাবো আপাতত
    final String tag = clanData['tag'] ?? '#CLAN${clanData['id'].toString().substring(0, 4).toUpperCase()}';
    Clipboard.setData(ClipboardData(text: tag));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Clan Tag $tag copied to clipboard!"),
        backgroundColor: const Color(0xFF10A37F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ফলব্যাক ট্যাগ জেনারেট (যদি ডাটাবেসে tag কলাম এখনো অ্যাড না করে থাকিস)
    final String clanTag = clanData['tag'] ?? '#CLAN${clanData['id'].toString().substring(0, 4).toUpperCase()}';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================================
          // 🔥 THE COMMAND CENTER BANNER
          // ==========================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)], 
                begin: Alignment.topLeft, 
                end: Alignment.bottomRight
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Tag & Role
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => _copyClanTag(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10A37F).withOpacity(0.2), 
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10A37F).withOpacity(0.5))
                        ),
                        child: Row(
                          children: [
                            Text(clanTag, style: const TextStyle(color: Color(0xFF10A37F), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                            const SizedBox(width: 6),
                            const Icon(LucideIcons.copy, size: 12, color: Color(0xFF10A37F)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(roleInfo['role'].toString().toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                
                // Clan & School Name
                Text(clanData['clan_name'].toString().toUpperCase(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                const SizedBox(height: 4),
                Text("Represents: ${clanData['school_name']}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                
                const SizedBox(height: 24),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),

                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(LucideIcons.star, "TOTAL XP", NumberFormat.compact().format(clanData['total_xp']), Colors.orange),
                    Container(height: 30, width: 1, color: Colors.white12),
                    _buildStatColumn(LucideIcons.users, "SQUAD", "${clanData['member_count']} / 25", Colors.lightBlue),
                  ],
                )
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // ==========================================
          // ⚔️ LIVE WAR STATUS
          // ==========================================
          const Text("WAR STATUS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(LucideIcons.swords, color: Colors.redAccent, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Matchmaking Phase", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("Next battle starts in 2d 14h. Gather your squad!", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ==========================================
          // 🚀 QUICK ACTIONS
          // ==========================================
          const Text("COMMANDS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: LucideIcons.userPlus,
                  label: "Invite Scholar",
                  color: const Color(0xFF10A37F),
                  onTap: () {
                    // TODO: Open Search User Modal
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  icon: LucideIcons.share2,
                  label: "Share Tag",
                  color: Colors.blueAccent,
                  onTap: () => _copyClanTag(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper function for Stats
  Widget _buildStatColumn(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }

  // Helper function for Action Buttons
  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}