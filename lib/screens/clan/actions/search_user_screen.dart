import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SearchUserScreen extends StatefulWidget {
  final String clanSchoolName; // ক্ল্যানের নিজস্ব স্কুল (ভেরিফিকেশনের জন্য)

  const SearchUserScreen({super.key, required this.clanSchoolName});

  @override
  State<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends State<SearchUserScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // ডামি সার্চ রেজাল্ট (রিয়েল অ্যাপে Supabase-এর profiles টেবিল থেকে আসবে)
  List<Map<String, dynamic>> _searchResults = [];

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    // ডামি সার্চ লজিক: টেস্টিংয়ের জন্য বিভিন্ন কন্ডিশনাল ডাটা তৈরি করা হলো
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = [
            // 🟢 Eligible: Same school, no clan
            {
              "name": "Arif Mahmud", 
              "username": "@arif_${query.toLowerCase()}", 
              "school": widget.clanSchoolName, 
              "status": "available"
            },
            // 🔴 Ineligible: Different school (Anti-Mercenary Rule)
            {
              "name": "Nafis Iqbal", 
              "username": "@nafis_pro", 
              "school": "Cantonment Public School", 
              "status": "available"
            },
            // ⚪ Unavailable: Already in a clan
            {
              "name": "Zahid Hasan", 
              "username": "@zahid_x", 
              "school": widget.clanSchoolName, 
              "status": "in_clan"
            },
          ];
        });
      }
    });
  }

  void _sendInvite(Map<String, dynamic> user) {
    // TODO: Insert into 'clan_invitations' table in Supabase
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Recruitment invite sent to ${user['username']}!"),
        backgroundColor: const Color(0xFF10A37F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        elevation: 0,
        title: const Text("RECRUIT SCHOLAR", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1.5)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // 🔍 SEARCH BAR (By Username)
            // ==========================================
            const Text("SEARCH DATABASE", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              onSubmitted: _performSearch,
              decoration: InputDecoration(
                hintText: "Enter @username or name...",
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: const Icon(LucideIcons.atSign, color: Color(0xFF10A37F)),
                suffixIcon: _isSearching 
                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10A37F)))
                    : IconButton(icon: const Icon(LucideIcons.search, color: Colors.grey), onPressed: () => _performSearch(_searchController.text)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF10A37F))),
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 📜 SEARCH RESULTS
            // ==========================================
            if (_searchResults.isNotEmpty)
              const Text("PLAYERS FOUND", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            
            const SizedBox(height: 12),

            Expanded(
              child: _searchResults.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return _buildPlayerTile(user);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 🎯 PLAYER TILE (With Smart Validation)
  // ==========================================
  Widget _buildPlayerTile(Map<String, dynamic> user) {
    final bool isMySchool = user['school'] == widget.clanSchoolName;
    final bool isAvailable = user['status'] == 'available';
    
    // Status Logic
    String buttonText = "INVITE";
    Color buttonColor = const Color(0xFF10A37F);
    bool isButtonEnabled = true;

    if (!isAvailable) {
      buttonText = "IN CLAN";
      buttonColor = Colors.grey.shade700;
      isButtonEnabled = false;
    } else if (!isMySchool) {
      buttonText = "INELIGIBLE";
      buttonColor = Colors.redAccent;
      isButtonEnabled = false;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.blueAccent.withOpacity(0.2),
            child: const Icon(LucideIcons.user, color: Colors.blueAccent),
          ),
          const SizedBox(width: 16),
          
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(user['username'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 6),
                
                // School Indicator
                Row(
                  children: [
                    Icon(isMySchool ? LucideIcons.checkCircle2 : LucideIcons.xCircle, 
                         size: 12, color: isMySchool ? const Color(0xFF10A37F) : Colors.redAccent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(user['school'], 
                        style: TextStyle(color: isMySchool ? const Color(0xFF10A37F) : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold), 
                        maxLines: 1, overflow: TextOverflow.ellipsis
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Action Button
          ElevatedButton(
            onPressed: isButtonEnabled ? () => _sendInvite(user) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              disabledBackgroundColor: buttonColor.withOpacity(0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(buttonText, style: TextStyle(color: isButtonEnabled ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 11)),
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
          Icon(LucideIcons.radar, size: 64, color: Colors.grey.shade800),
          const SizedBox(height: 16),
          const Text("AWAITING TARGET", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          const Text("Search for a specific @username or name\nto recruit them to your squad.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
        ],
      ),
    );
  }
}