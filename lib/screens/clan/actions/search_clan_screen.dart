import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SearchClanScreen extends StatefulWidget {
  final String userSchool; // ইউজারের প্রোফাইল থেকে আসা অরিজিনাল স্কুল

  const SearchClanScreen({super.key, required this.userSchool});

  @override
  State<SearchClanScreen> createState() => _SearchClanScreenState();
}

class _SearchClanScreenState extends State<SearchClanScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // ডামি ডাটা: Supabase থেকে রিয়েল ডাটা আসার আগ পর্যন্ত
  // রিয়েল অ্যাপে প্রথমে ইউজারের নিজের স্কুলের ক্ল্যানগুলো অটো-সাজেস্ট হবে
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    // ঢোকার সাথেই ইউজারের নিজের স্কুলের কোনো ক্ল্যান আছে কিনা সেটা লোড করবে
    _loadMySchoolClans();
  }

  void _loadMySchoolClans() {
    // TODO: Fetch from Supabase: select * from clans where school_name = widget.userSchool
    setState(() {
      _searchResults = [
        {"tag": "#BOG8X2", "clan_name": "ALPHA BOYS", "school_name": widget.userSchool, "members": 24},
      ];
    });
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      _loadMySchoolClans();
      return;
    }

    setState(() => _isSearching = true);

    // ডামি সার্চ লজিক (রিয়েল অ্যাপে Supabase দিয়ে tag বা name দিয়ে খুঁজবি)
    Future.delayed(const Duration(milliseconds: 600), () {
      setState(() {
        _isSearching = false;
        // ইচ্ছে করে একটা অন্য স্কুলের ডাটা দেখাচ্ছি টেস্টিংয়ের জন্য
        _searchResults = [
          {"tag": query.toUpperCase(), "clan_name": "TITANS", "school_name": "Rajuk Uttara Model College", "members": 12},
        ];
      });
    });
  }

  // 🛡️ STRICT SECURITY CHECK
  void _requestToJoin(Map<String, dynamic> clan) {
    if (clan['school_name'] != widget.userSchool) {
      // 🚫 Security Breach: School doesn't match!
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [Icon(LucideIcons.shieldAlert, color: Colors.red), SizedBox(width: 8), Text("Access Denied", style: TextStyle(color: Colors.white))]),
          content: Text("Invalid! This is not your school's clan.\n\nYou can only join clans representing ${widget.userSchool}.", style: const TextStyle(color: Colors.grey, height: 1.5)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Understood", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    // ✅ Match Successful
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Join request sent to ${clan['clan_name']}!"), backgroundColor: const Color(0xFF10A37F)),
    );
    // TODO: Insert into join_requests table in Supabase
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        elevation: 0,
        title: const Text("JOIN SQUAD", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1.5)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // 🔍 THE SEARCH BAR (By Tag or Name)
            // ==========================================
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              onSubmitted: _performSearch,
              decoration: InputDecoration(
                hintText: "Search by Clan Tag (e.g. #BOG8X2)",
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: const Icon(LucideIcons.search, color: Color(0xFF10A37F)),
                suffixIcon: _isSearching 
                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10A37F)))
                    : IconButton(icon: const Icon(LucideIcons.xCircle, color: Colors.grey), onPressed: () {
                        _searchController.clear();
                        _loadMySchoolClans();
                      }),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF10A37F))),
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 🏫 RECOMMENDED / SEARCH RESULTS
            // ==========================================
            Text(
              _searchController.text.isEmpty ? "YOUR SCHOOL'S SQUADS" : "SEARCH RESULTS", 
              style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _searchResults.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final clan = _searchResults[index];
                        final bool isMySchool = clan['school_name'] == widget.userSchool;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isMySchool ? const Color(0xFF10A37F).withOpacity(0.3) : Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                                child: const Icon(LucideIcons.shield, color: Color(0xFF10A37F), size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(clan['clan_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                                          child: Text(clan['tag'], style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(clan['school_name'], style: TextStyle(color: isMySchool ? const Color(0xFF10A37F) : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text("${clan['members']} / 25 Members", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: clan['members'] >= 25 ? null : () => _requestToJoin(clan),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isMySchool ? const Color(0xFF10A37F) : Colors.redAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(clan['members'] >= 25 ? "FULL" : "JOIN", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              )
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.ghost, size: 64, color: Colors.grey.shade800),
          const SizedBox(height: 16),
          const Text("NO SQUADS FOUND", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text("There are no active squads for\n${widget.userSchool}.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, height: 1.5)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Navigate to Create Clan Screen
              Navigator.pop(context);
            },
            icon: const Icon(LucideIcons.flag, color: Colors.white),
            label: const Text("Found a New Clan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF10A37F), width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
            ),
          )
        ],
      ),
    );
  }
}