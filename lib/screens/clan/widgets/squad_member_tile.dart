import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

class SquadMemberTile extends StatelessWidget {
  final Map<String, dynamic> member;
  final int rank;
  final bool isAdmin;
  final String myRole;
  final VoidCallback onKick;
  final VoidCallback onPromote;

  const SquadMemberTile({
    super.key,
    required this.member,
    required this.rank,
    required this.isAdmin,
    required this.myRole,
    required this.onKick,
    required this.onPromote,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMe = member['isMe'] ?? false;
    final String role = member['role'] ?? 'Member';
    
    // Role অনুযায়ী কালার
    Color roleColor = Colors.grey;
    if (role == 'Leader') roleColor = Colors.amber;
    if (role == 'Moderator') roleColor = Colors.purpleAccent;
    if (role == 'Member') roleColor = Colors.blueAccent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF10A37F).withOpacity(0.1) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? const Color(0xFF10A37F).withOpacity(0.5) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          // ==========================================
          // 🏅 RANK BADGE
          // ==========================================
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black26, 
              borderRadius: BorderRadius.circular(8)
            ),
            child: Text(
              "#$rank", 
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)
            ),
          ),
          const SizedBox(width: 12),
          
          // ==========================================
          // 👤 AVATAR
          // ==========================================
          CircleAvatar(
            radius: 20,
            backgroundColor: roleColor.withOpacity(0.2),
            child: Icon(LucideIcons.user, color: roleColor, size: 20),
          ),
          const SizedBox(width: 12),

          // ==========================================
          // 📜 NAME, USERNAME & XP
          // ==========================================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member['name'], 
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.grey.shade300, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 15
                        ), 
                        overflow: TextOverflow.ellipsis
                      )
                    ),
                    const SizedBox(width: 6),
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.2), 
                        borderRadius: BorderRadius.circular(4)
                      ),
                      child: Text(
                        role.toUpperCase(), 
                        style: TextStyle(color: roleColor, fontSize: 8, fontWeight: FontWeight.bold)
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "${member['username']} • ${NumberFormat.compact().format(member['xp'])} XP", 
                  style: const TextStyle(color: Colors.grey, fontSize: 11)
                ),
              ],
            ),
          ),

          // ==========================================
          // ⚙️ ACTION MENU (3-Dots)
          // ==========================================
          if (isAdmin && !isMe) 
            _buildAdminMenu(context, role, member['name']),
        ],
      ),
    );
  }

  Widget _buildAdminMenu(BuildContext context, String targetRole, String targetName) {
    // 🛡️ Hierarchy Logic: মডারেটররা লিডারকে কিক বা প্রমোট করতে পারবে না
    if (myRole == 'Moderator' && targetRole == 'Leader') {
      return const SizedBox.shrink(); 
    }

    return PopupMenuButton<String>(
      icon: const Icon(LucideIcons.moreVertical, color: Colors.grey),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'kick') {
          _showKickConfirmation(context, targetName);
        } else if (value == 'promote') {
          onPromote(); // Parent থেকে আসা ফাংশন কল হবে
        }
      },
      itemBuilder: (context) => [
        if (myRole == 'Leader' && targetRole == 'Member')
          const PopupMenuItem(
            value: 'promote', 
            child: Row(children: [
              Icon(LucideIcons.shieldChevrons, color: Colors.purpleAccent, size: 18), 
              SizedBox(width: 8), 
              Text("Promote to Mod", style: TextStyle(color: Colors.white))
            ])
          ),
        const PopupMenuItem(
          value: 'kick', 
          child: Row(children: [
            Icon(LucideIcons.userMinus, color: Colors.redAccent, size: 18), 
            SizedBox(width: 8), 
            Text("Kick from Squad", style: TextStyle(color: Colors.redAccent))
          ])
        ),
      ],
    );
  }

  void _showKickConfirmation(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(LucideIcons.alertTriangle, color: Colors.red), 
          SizedBox(width: 8), 
          Text("Kick Member?", style: TextStyle(color: Colors.white))
        ]),
        content: Text(
          "Are you sure you want to kick $name from the squad? They will lose their current battle XP.", 
          style: const TextStyle(color: Colors.grey)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancel", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // ডায়ালগ কাটবে
              onKick(); // Parent থেকে আসা আসল কিক ফাংশনটা রান করবে
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Kick", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}