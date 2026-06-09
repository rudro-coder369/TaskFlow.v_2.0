import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class NotificationScreen extends StatefulWidget {
  final bool hasClan;
  final String? userRole; // 'Leader', 'Moderator', 'Member', or null

  const NotificationScreen({
    super.key,
    required this.hasClan,
    this.userRole,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // ডামি ডাটা: যারা ক্ল্যানে জয়েন করার রিকোয়েস্ট পাঠিয়েছে (শুধু লিডার/মডারেটরদের জন্য)
  List<Map<String, dynamic>> _joinRequests = [
    {"id": "1", "name": "Ayan Shafiq", "username": "@ayan_s", "xp": 1200, "type": "join_request"},
    {"id": "2", "name": "Mahmudul Hasan", "username": "@mahmudul_x", "xp": 450, "type": "join_request"},
  ];

  // ডামি ডাটা: যেসব ক্ল্যান থেকে ইউজারের কাছে ইনভাইট এসেছে (যাদের ক্ল্যান নেই তাদের জন্য)
  List<Map<String, dynamic>> _clanInvites = [
    {"id": "101", "clan_name": "ALPHA BOYS", "tag": "#BOG8X2", "members": 24, "type": "clan_invite"},
  ];

  bool get _isAdmin => widget.userRole == 'Leader' || widget.userRole == 'Moderator';

  // ==========================================
  // ⚙️ ACTION HANDLERS
  // ==========================================
  void _handleJoinRequest(String id, String name, bool isAccepted) {
    setState(() => _joinRequests.removeWhere((req) => req['id'] == id));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isAccepted ? "Accepted $name into the squad!" : "Rejected $name's request."),
        backgroundColor: isAccepted ? const Color(0xFF10A37F) : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleClanInvite(String id, String clanName, bool isAccepted) {
    setState(() => _clanInvites.removeWhere((inv) => inv['id'] == id));

    if (isAccepted) {
      // রিয়েল অ্যাপে এখানে ক্ল্যানে জয়েন করার Supabase লজিক চলবে এবং ড্যাশবোর্ডে রিডাইরেক্ট করবে
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Welcome to $clanName!"), backgroundColor: const Color(0xFF10A37F)),
      );
      Navigator.pop(context); // ইনবক্স থেকে বের করে মেইন ড্যাশবোর্ডে পাঠাবে
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Declined invite from $clanName."), backgroundColor: Colors.grey),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ইউজারের স্ট্যাটাস অনুযায়ী লিস্ট ফিল্টার করা
    List<Map<String, dynamic>> displayList = [];
    if (_isAdmin) {
      displayList.addAll(_joinRequests);
    }
    if (!widget.hasClan) {
      displayList.addAll(_clanInvites);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        elevation: 0,
        title: const Text("COMMAND INBOX", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1.5)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: displayList.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: displayList.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = displayList[index];
                if (item['type'] == 'join_request') {
                  return _buildJoinRequestTile(item);
                } else {
                  return _buildClanInviteTile(item);
                }
              },
            ),
    );
  }

  // ==========================================
  // 🛡️ WIDGET: JOIN REQUEST TILE (For Admins)
  // ==========================================
  Widget _buildJoinRequestTile(Map<String, dynamic> req) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.userPlus, color: Colors.orangeAccent, size: 20),
              const SizedBox(width: 8),
              const Text("RECRUITMENT REQUEST", style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(radius: 20, backgroundColor: Colors.white12, child: const Icon(LucideIcons.user, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(req['username'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("CURRENT XP", style: TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
                  Text(req['xp'].toString(), style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleJoinRequest(req['id'], req['name'], false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Reject", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleJoinRequest(req['id'], req['name'], true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10A37F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Accept", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // ==========================================
  // 📩 WIDGET: CLAN INVITE TILE (For Normal Users)
  // ==========================================
  Widget _buildClanInviteTile(Map<String, dynamic> inv) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10A37F).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.mail, color: Color(0xFF10A37F), size: 20),
              const SizedBox(width: 8),
              const Text("SQUAD INVITATION", style: TextStyle(color: Color(0xFF10A37F), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                child: const Icon(LucideIcons.shield, color: Color(0xFF10A37F), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv['clan_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("Tag: ${inv['tag']} • ${inv['members']}/25", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleClanInvite(inv['id'], inv['clan_name'], false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Decline", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleClanInvite(inv['id'], inv['clan_name'], true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10A37F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Join Squad", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.bellOff, size: 64, color: Colors.grey.shade800),
          const SizedBox(height: 16),
          const Text("ALL CLEAR", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          const Text("No pending requests or invites\nat the moment.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
        ],
      ),
    );
  }
}