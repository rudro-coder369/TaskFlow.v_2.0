import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ClanBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ClanBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F19),
        // উপরের দিকে একটা হালকা সাদা বর্ডার, যাতে স্ক্রিন থেকে ন্যাভ বারটা আলাদা মনে হয়
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.05), 
            width: 1,
          ),
        ),
        // গেমিং ফিল আনার জন্য হালকা শ্যাডো
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: const Color(0xFF0B0F19), // ডার্ক গেমিং থিম
        type: BottomNavigationBarType.fixed, // আইটেমগুলো ফিক্সড থাকবে, নড়াচড়া করবে না
        elevation: 0,
        currentIndex: currentIndex,
        selectedItemColor: const Color(0xFF10A37F), // আমাদের সিগনেচার নিয়ন গ্রিন
        unselectedItemColor: Colors.grey.shade600,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
        onTap: onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4.0),
              child: Icon(LucideIcons.home),
            ),
            label: "HUB",
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4.0),
              child: Icon(LucideIcons.swords),
            ),
            label: "ARENA",
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4.0),
              child: Icon(LucideIcons.trophy),
            ),
            label: "RANK",
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4.0),
              child: Icon(LucideIcons.users),
            ),
            label: "SQUAD",
          ),
        ],
      ),
    );
  }
}