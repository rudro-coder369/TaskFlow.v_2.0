import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

class ClanSquadView extends StatefulWidget {
  final Map<String, dynamic> clanData;
  final Map<String, dynamic> roleInfo;

  const ClanSquadView({
    super.key,
    required this.clanData,
    required this.roleInfo,
  });

  @override
  State<ClanSquadView> createState() => _ClanSquadViewState();
}

class _ClanSquadViewState extends State<ClanSquadView> {
  // ডামি মেম্বার লিস্ট (ডাটাবেস থেকে আসার আগ পর্যন্ত)
  // রিয়েল অ্যাপে এটা Supabase থেকে order('contribution_xp', ascending: false) দিয়ে আনবি
  final List<Map<String, dynamic>> _mockMembers = [
    {"id": "1", "name": "You", "username": "@sourav", "role": "Leader", "xp": 14500, "isMe": true},
    {"id": "2", "name": "Rakib Hasan", "username": "@rakib99", "role": "Moderator", "xp": 11200, "isMe": false},
    {"id": "3", "name": "Fahim Morshed", "username": "@fahim_m", "role": "Member", "xp": 8450, "isMe": false},
    {"id": "4", "name": "Sadia Islam", "username": "@sadia_x", "role": "Member", "xp": 6300, "isMe": false},
    {"id": "5", "name": "Nafis Ahmed", "username": "@nafis22", "role": "Member", "xp": 2100, "isMe": false},
  ];

  bool get _isAdmin => widget.roleInfo['role'] == 'Leader' || widget.roleInfo['role'] == 'Moderator';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================================
          // 🛡️ HEADER & INVITE BUTTON
          // ==========================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("SQUAD HQ", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text("${widget.clanData['member_count']} / 25 Members", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              // Invite Button
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Open User Search Modal to invite by @username
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invite Player modal coming soon!")));
                },
                icon: const Icon(LucideIcons.userPlus, size: 16, color: Colors.white),
                label: const Text("Recruit", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10A37F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),

          // ==========================================
          // 🚨 ADMIN PANEL (Only for Leaders & Mods)
          // ==========================================
          if (_isAdmin) ...[
            const Text("COMMAND CENTER", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: ListTile(
                leading: const Icon(LucideIcons.mailWarning, color: Colors.orange),
                title: const Text("Pending Join Requests", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("3 players want to join", style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                trailing: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text("Review", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],

          // ==========================================
          // 👥 MEMBER RANKINGS
          // ==========================================
          const Text("SQUAD ROSTER (Ranked by XP)", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _mockMembers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final member = _mockMembers[index];
              return _buildMemberTile(member, index + 1);
            },
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET: MEMBER TILE
  // ==========================================
  Widget _buildMemberTile(Map<String, dynamic> member, int rank) {
    final bool isMe = member['isMe'];
    final String role = member['role'];
    
    // Role Colors
    Color roleColor = Colors.grey;
    if (role == 'Leader') roleColor = Colors.amber;
    if (role == 'Moderator') roleColor = Colors.purpleAccent;
    if (role == 'Member') roleColor = Colors.blueAccent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF10A37F).withOpacity(0.1) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isMe ? const Color(0xFF10A37F).withOpacity(0.5) : Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
            child: Text("#$rank", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: roleColor.withOpacity(0.2),
            child: Icon(LucideIcons.user, color: roleColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Name & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(member['name'], style: TextStyle(color: isMe ? Colors.white : Colors.grey.shade300, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: roleColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text(role.toUpperCase(), style: TextStyle(color: roleColor, fontSize: 8, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 2),
                Text("${member['username']} • ${NumberFormat.compact().format(member['xp'])} XP", style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),

          // Action Menu (3-dots)
          // Rules: Admin can see menu for others. Leaders can kick mods. Mods cannot kick leaders.
          if (_isAdmin && !isMe) 
            _buildAdminMenu(member, role),
        ],
      ),
    );
  }

  // ==========================================
  // ⚙️ ADMIN ACTION MENU (Kick, Promote)
  // ==========================================
  Widget _buildAdminMenu(Map<String, dynamic> targetMember, String targetRole) {
    final myRole = widget.roleInfo['role'];

    // মডারেটররা লিডারকে কিক বা প্রমোট করতে পারবে না
    if (myRole == 'Moderator' && targetRole == 'Leader') {
      return const SizedBox.shrink(); 
    }

    return PopupMenuButton<String>(
      icon: const Icon(LucideIcons.moreVertical, color: Colors.grey),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'kick') {
          _showKickConfirmation(targetMember['name']);
        } else if (value == 'promote') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Promoted ${targetMember['name']} to Moderator!")));
        }
      },
      itemBuilder: (context) => [
        if (myRole == 'Leader' && targetRole == 'Member')
          const PopupMenuItem(value: 'promote', child: Row(children: [Icon(LucideIcons.shield, color: Colors.purpleAccent, size: 18), SizedBox(width: 8), Text("Promote to Mod", style: TextStyle(color: Colors.white))])),
        const PopupMenuItem(value: 'kick', child: Row(children: [Icon(LucideIcons.userMinus, color: Colors.redAccent, size: 18), SizedBox(width: 8), Text("Kick from Squad", style: TextStyle(color: Colors.redAccent))])),
      ],
    );
  }

  void _showKickConfirmation(String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(LucideIcons.alertTriangle, color: Colors.red), SizedBox(width: 8), Text("Kick Member?", style: TextStyle(color: Colors.white))]),
        content: Text("Are you sure you want to kick $name from the squad? They will lose their current battle XP.", style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$name was kicked from the squad."), backgroundColor: Colors.red));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Kick", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}