import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

class ClanArenaView extends StatefulWidget {
  final Map<String, dynamic> clanData;

  const ClanArenaView({super.key, required this.clanData});

  @override
  State<ClanArenaView> createState() => _ClanArenaViewState();
}

class _ClanArenaViewState extends State<ClanArenaView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  // ডামি ডাটা: ডাটাবেস থেকে রিয়েল ব্যাটল আসার আগ পর্যন্ত UI দেখানোর জন্য
  final bool _isBattleActive = true; 
  final String _opponentName = "RAJUK TITANS";
  final String _opponentSchool = "Rajuk Uttara Model College";
  final int _myClanXp = 14500;
  final int _opponentXp = 12200;

  @override
  void initState() {
    super.initState();
    // লাইভ গ্লো ইফেক্টের জন্য এনিমেশন
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBattleActive) {
      return _buildNoBattleState();
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================================
          // ⚔️ VERSUS HEADER
          // ==========================================
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.withOpacity(0.3))),
              child: const Text("🔥 LIVE WARFARE", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
          ),
          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // MY CLAN (Blue Side)
              Expanded(child: _buildFighterCard(widget.clanData['clan_name'], "Ally", Colors.blue)),
              
              // VS ICON
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.1),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [Colors.blue, Colors.red]),
                          boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 15, spreadRadius: _pulseController.value * 5)],
                        ),
                        child: const Text("VS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, fontStyle: FontStyle.italic)),
                      ),
                    );
                  }
                ),
              ),

              // OPPONENT CLAN (Red Side)
              Expanded(child: _buildFighterCard(_opponentName, "Enemy", Colors.redAccent, isRightAligned: true)),
            ],
          ),

          const SizedBox(height: 40),

          // ==========================================
          // 📊 THE BLOOD-BAR (Tug of War Progress)
          // ==========================================
          const Text("BATTLE DOMINANCE", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          
          _buildLiveProgressBar(),

          const SizedBox(height: 40),

          // ==========================================
          // 🏆 TOP STRIKERS (Top Contributors in this match)
          // ==========================================
          const Text("YOUR TOP STRIKERS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          
          Container(
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
            child: Column(
              children: [
                _buildStrikerTile("You", 5200, isMe: true),
                const Divider(color: Colors.white12, height: 1),
                _buildStrikerTile("Rakib Hasan", 3100),
                const Divider(color: Colors.white12, height: 1),
                _buildStrikerTile("Fahim Morshed", 1850),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  Widget _buildFighterCard(String name, String subtitle, Color color, {bool isRightAligned = false}) {
    return Column(
      crossAxisAlignment: isRightAligned ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(subtitle.toUpperCase(), style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(name.toUpperCase(), 
          textAlign: isRightAligned ? TextAlign.right : TextAlign.left,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.2),
          maxLines: 2, overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildLiveProgressBar() {
    final int totalXp = _myClanXp + _opponentXp;
    final double myPercentage = totalXp == 0 ? 0.5 : _myClanXp / totalXp;
    final double opponentPercentage = totalXp == 0 ? 0.5 : _opponentXp / totalXp;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("${NumberFormat.compact().format(_myClanXp)} XP", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w900, fontSize: 16)),
            Text("${NumberFormat.compact().format(_opponentXp)} XP", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 12),
        // The Bar
        Container(
          height: 24,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade900,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 5)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  width: MediaQuery.of(context).size.width * 0.85 * myPercentage, // approximate width calculation
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF1E3A8A), Colors.blue]),
                  ),
                ),
                Container(width: 4, color: Colors.white), // The clash point
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.redAccent, Color(0xFF7F1D1D)]),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("${(myPercentage * 100).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            const Text("TUG OF WAR", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            Text("${(opponentPercentage * 100).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  Widget _buildStrikerTile(String name, int xp, {bool isMe = false}) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(radius: 16, backgroundColor: Colors.blue.withOpacity(0.2), child: Icon(LucideIcons.user, size: 16, color: isMe ? Colors.white : Colors.blue)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: TextStyle(color: isMe ? Colors.white : Colors.grey.shade300, fontWeight: isMe ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
          ),
          Row(
            children: [
              const Icon(LucideIcons.sword, color: Colors.orange, size: 14),
              const SizedBox(width: 4),
              Text("+${NumberFormat.compact().format(xp)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildNoBattleState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.shieldAlert, size: 64, color: Colors.grey.shade800),
          const SizedBox(height: 24),
          const Text("NO ACTIVE WAR", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 8),
          const Text("Your squad is currently resting.\nMatchmaking occurs every Friday.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
        ],
      ),
    );
  }
}