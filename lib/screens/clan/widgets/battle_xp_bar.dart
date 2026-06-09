import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BattleXpBar extends StatelessWidget {
  final int myClanXp;
  final int opponentXp;

  const BattleXpBar({
    super.key,
    required this.myClanXp,
    required this.opponentXp,
  });

  @override
  Widget build(BuildContext context) {
    // XP ক্যালকুলেশন
    final int totalXp = myClanXp + opponentXp;
    // জিরো ডিভিশন এরর ঠেকানোর জন্য সেফ চেক
    final double myPercentage = totalXp == 0 ? 0.5 : myClanXp / totalXp;
    final double opponentPercentage = totalXp == 0 ? 0.5 : opponentXp / totalXp;

    return Column(
      children: [
        // ==========================================
        // 🔢 TOP ROW: XP NUMBERS
        // ==========================================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("${NumberFormat.compact().format(myClanXp)} XP", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w900, fontSize: 16)),
            Text("${NumberFormat.compact().format(opponentXp)} XP", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 12),

        // ==========================================
        // 📊 THE ANIMATED BAR (LayoutBuilder for pixel-perfect width)
        // ==========================================
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            
            return Container(
              height: 24,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade900,
                // গর্তের মতো ইফেক্ট (Inset Shadow)
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.8), offset: const Offset(0, 2), blurRadius: 6, spreadRadius: -2)
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    // 🟦 MY CLAN PROGRESS (Blue)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutElastic, // একটু বাউন্সি গেমিং ফিল
                      width: barWidth * myPercentage,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF1E3A8A), Colors.blue]),
                      ),
                    ),
                    
                    // ⚡ THE CLASH POINT (White Spark)
                    Container(
                      width: 4, 
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.8), blurRadius: 8, spreadRadius: 2)]
                      )
                    ), 
                    
                    // 🟥 OPPONENT PROGRESS (Red)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.redAccent, Color(0xFF7F1D1D)]),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          }
        ),
        const SizedBox(height: 12),
        
        // ==========================================
        // 📉 BOTTOM ROW: PERCENTAGES
        // ==========================================
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
}