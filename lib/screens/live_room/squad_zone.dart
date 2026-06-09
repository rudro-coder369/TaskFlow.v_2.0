import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../public_profile_screen.dart';

class SquadZone extends StatefulWidget {
  const SquadZone({super.key});

  @override
  State<SquadZone> createState() => _SquadZoneState();
}

class _SquadZoneState extends State<SquadZone> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  String? _mySquadId;
  Map<String, dynamic>? _mySquadInfo;
  
  List<Map<String, dynamic>> _onlineMembers = [];
  List<Map<String, dynamic>> _allMembers = [];
  List<Map<String, dynamic>> _pendingInvites = [];

  final Color _primaryGreen = const Color(0xFF10A37F);

  @override
  void initState() {
    super.initState();
    _loadAllSquadData();
  }

  Future<void> _loadAllSquadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final squadRes = await _supabase
          .from('squad_members')
          .select('id, squad_id, squads(*)')
          .eq('user_id', userId)
          .eq('status', 'accepted')
          .maybeSingle();

      if (squadRes != null) {
        _mySquadId = squadRes['squad_id'];
        _mySquadInfo = squadRes['squads'];
        await _fetchSquadMembers(_mySquadId!);
      } else {
        _mySquadId = null;
        _mySquadInfo = null;
        final inviteRes = await _supabase
            .from('squad_members')
            .select('id, squads(name, admin_id)')
            .eq('user_id', userId)
            .eq('status', 'pending');
        _pendingInvites = List<Map<String, dynamic>>.from(inviteRes);
      }
    } catch (e) {
      debugPrint("Data Load Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSquadMembers(String squadId) async {
    try {
      final res = await _supabase
          .from('squad_members')
          .select('id, user_id, status, profiles(username, avatar_seed, active_task, active_subject)')
          .eq('squad_id', squadId)
          .eq('status', 'accepted');
          
      final fetchedMembers = List<Map<String, dynamic>>.from(res);
      
      List<Map<String, dynamic>> online = [];
      List<Map<String, dynamic>> all = [];

      for (var member in fetchedMembers) {
        all.add(member);
        if (member['profiles']['active_task'] != null) {
          online.add(member);
        }
      }

      setState(() {
        _allMembers = all;
        _onlineMembers = online;
      });
      
    } catch (e) {
      debugPrint("Members Fetch Error: $e");
    }
  }

  Future<void> _createSquad(String name) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final newSquad = await _supabase.from('squads').insert({
        'name': name,
        'admin_id': userId,
      }).select().single();

      await _supabase.from('squad_members').insert({
        'squad_id': newSquad['id'],
        'user_id': userId,
        'status': 'accepted',
      });

      _showSnackBar("Squad created successfully.", isSuccess: true);
      _loadAllSquadData();
    } catch (e) {
      debugPrint("Create Squad Error: $e");
      _showSnackBar("Failed to create squad.");
    }
  }

  Future<void> _acceptInvitation(String memberRecordId) async {
    try {
      await _supabase.from('squad_members').update({'status': 'accepted'}).eq('id', memberRecordId);
      _showSnackBar("Joined squad successfully.", isSuccess: true);
      _loadAllSquadData();
    } catch (e) {
      _showSnackBar("Error joining squad.");
    }
  }

  Future<void> _sendInvite(String targetUserId) async {
    if (_mySquadId == null) return;
    try {
      await _supabase.from('squad_members').insert({
        'squad_id': _mySquadId,
        'user_id': targetUserId,
        'status': 'pending',
      });
      _showSnackBar("Invitation sent.", isSuccess: true);
    } catch (e) {
      debugPrint("Invite Error: $e");
      _showSnackBar("User is already invited or an error occurred.");
    }
  }

  Future<void> _deleteSquad() async {
    try {
      await _supabase.from('squads').delete().eq('id', _mySquadId!);
      _showSnackBar("Squad deleted successfully.", isSuccess: true);
      _loadAllSquadData();
    } catch (e) {
      debugPrint("Delete Squad Error: $e");
      _showSnackBar("Error deleting squad.");
    }
  }

  Future<void> _leaveSquad() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('squad_members').delete().eq('squad_id', _mySquadId!).eq('user_id', userId);
      _showSnackBar("You left the squad.", isSuccess: true);
      _loadAllSquadData();
    } catch (e) {
      _showSnackBar("Error leaving squad.");
    }
  }

  // 🔥 NEW: Admin can remove a member
  Future<void> _removeMember(String memberUserId) async {
    try {
      await _supabase.from('squad_members').delete().eq('squad_id', _mySquadId!).eq('user_id', memberUserId);
      _showSnackBar("Member removed from squad.", isSuccess: true);
      _loadAllSquadData();
    } catch (e) {
      _showSnackBar("Error removing member.");
    }
  }

  void _showSnackBar(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: isSuccess ? _primaryGreen : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showCreateSquadModal() {
    final nameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Create Squad", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 24),
            TextField(
              controller: nameCtrl, 
              decoration: InputDecoration(
                labelText: "Squad Name", 
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryGreen, width: 1.5))
              )
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  _createSquad(nameCtrl.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen, elevation: 0, minimumSize: const Size(double.infinity, 54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Create", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showInvitationsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pending Invitations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 24),
            if (_pendingInvites.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text("No pending invitations.", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              )
            else
              ..._pendingInvites.map((inv) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle), child: Icon(LucideIcons.users, color: Colors.grey.shade700, size: 20)),
                  title: Text(inv['squads']['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _acceptInvitation(inv['id']);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text("Accept", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              )).toList(),
          ],
        ),
      ),
    );
  }

  void _showInviteMembersModal() {
    bool isSearching = false;
    List<Map<String, dynamic>> searchResults = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> searchUsers(String query) async {
            if (query.trim().isEmpty) {
              setModalState(() => searchResults = []);
              return;
            }
            setModalState(() => isSearching = true);
            try {
              final myId = _supabase.auth.currentUser!.id;
              final res = await _supabase.from('profiles').select('id, username, school_name, avatar_seed')
                  .neq('id', myId)
                  .ilike('username', '%$query%') 
                  .limit(15);
              
              setModalState(() {
                searchResults = List<Map<String, dynamic>>.from(res);
                isSearching = false;
              });
            } catch (e) {
              debugPrint("Search Error: $e");
              setModalState(() => isSearching = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Invite Members", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 24),
                  TextField(
                    onChanged: (val) => searchUsers(val),
                    decoration: InputDecoration(
                      hintText: "Search username",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: Icon(LucideIcons.search, color: Colors.grey.shade500, size: 20),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryGreen, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isSearching)
                    Center(child: CircularProgressIndicator(color: _primaryGreen, strokeWidth: 2))
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final user = searchResults[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: CircleAvatar(backgroundColor: Colors.grey.shade100, backgroundImage: NetworkImage('https://api.dicebear.com/8.x/notionists/png?seed=${user['avatar_seed']}&backgroundColor=f8fafc')),
                            title: Text(user['username'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            subtitle: Text(user['school_name'] ?? 'School not specified', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            trailing: OutlinedButton(
                              onPressed: () {
                                _sendInvite(user['id']);
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(side: BorderSide(color: _primaryGreen), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              child: Text("Invite", style: TextStyle(color: _primaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
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
      ),
    );
  }

  // 🔥 UPDATE: Admin kick feature added to UI
  Widget _buildUserCard(Map<String, dynamic> member, bool isOnline, bool isAdmin) {
    final profile = member['profiles'];
    final memberUserId = member['user_id'];
    final currentUserId = _supabase.auth.currentUser?.id;
    final isMe = memberUserId == currentUserId;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: isOnline ? _primaryGreen.withOpacity(0.3) : Colors.grey.shade200, width: isOnline ? 1.5 : 1)
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20, 
            backgroundColor: Colors.grey.shade100, 
            backgroundImage: NetworkImage('https://api.dicebear.com/8.x/notionists/png?seed=${profile['avatar_seed']}&backgroundColor=f8fafc')
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isMe ? "You" : profile['username'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                if (isOnline)
                  Text("Focusing on ${profile['active_subject']}", style: TextStyle(fontSize: 12, color: _primaryGreen, fontWeight: FontWeight.w500))
                else
                  Text("Offline", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOnline) 
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _primaryGreen.withOpacity(0.1), shape: BoxShape.circle), child: Icon(LucideIcons.focus, color: _primaryGreen, size: 14)),
              
              if (isAdmin && !isMe) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Remove Member", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        content: Text("Are you sure you want to remove ${profile['username']} from the squad?", style: const TextStyle(fontSize: 14)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _removeMember(memberUserId);
                            }, 
                            child: const Text("Remove", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      )
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                    child: Icon(LucideIcons.userX, color: Colors.red.shade400, size: 14),
                  ),
                ),
              ]
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _primaryGreen, strokeWidth: 2));
    }

    if (_mySquadId != null) {
      final bool isAdmin = _mySquadInfo?['admin_id'] == _supabase.auth.currentUser?.id;

      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC), 
        body: RefreshIndicator(
          onRefresh: _loadAllSquadData,
          color: _primaryGreen,
          backgroundColor: Colors.white,
          child: Stack(
            children: [
              Positioned(
                top: -100, left: -100, 
                child: Container(
                  width: 300, height: 300, 
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, 
                    gradient: RadialGradient(colors: [_primaryGreen.withOpacity(0.1), Colors.transparent])
                  )
                )
              ),

              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _primaryGreen.withOpacity(0.85), 
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                    child: const Text("ACTIVE SQUAD", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                  ),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: _showInviteMembersModal,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                          child: const Icon(LucideIcons.userPlus, color: Colors.white, size: 18),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text(isAdmin ? "Delete Squad" : "Leave Squad", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              content: Text(isAdmin ? "This will permanently remove the squad and all members." : "Are you sure you want to leave this squad?", style: const TextStyle(fontSize: 14)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    isAdmin ? _deleteSquad() : _leaveSquad();
                                                  }, 
                                                  child: Text(isAdmin ? "Delete" : "Leave", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            )
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                          child: const Icon(LucideIcons.logOut, color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(_mySquadInfo?['name'] ?? 'Squad', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    if (_onlineMembers.isNotEmpty) ...[
                      Text("ONLINE NOW", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.8)),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _onlineMembers.length,
                        itemBuilder: (context, index) => _buildUserCard(_onlineMembers[index], true, isAdmin),
                      ),
                      const SizedBox(height: 24),
                    ],

                    Text("ALL MEMBERS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.8)),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _allMembers.length,
                      itemBuilder: (context, index) {
                        final member = _allMembers[index];
                        final isOnline = member['profiles']['active_task'] != null;
                        return _buildUserCard(member, isOnline, isAdmin);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
      );
    }

    // 🌟 EMPTY STATE: CLEAN WHITE THEME
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Positioned(
            top: -100, left: -100, 
            child: Container(
              width: 300, height: 300, 
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                gradient: RadialGradient(colors: [_primaryGreen.withOpacity(0.08), Colors.transparent])
              )
            )
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _primaryGreen.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(LucideIcons.users, size: 32, color: _primaryGreen),
                    ),
                    const SizedBox(height: 24),
                    const Text("Form Your Squad", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    const SizedBox(height: 12),
                    Text("Create a dedicated space to study and collaborate with your peers.", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5)),
                    const SizedBox(height: 32),
                    
                    ElevatedButton(
                      onPressed: _showCreateSquadModal, 
                      style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen, elevation: 0, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text("Create Squad", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(height: 12),
                    
                    // 🔥 UPDATE: Red dot notification on View Invitations button
                    OutlinedButton(
                      onPressed: _showInvitationsModal, 
                      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade300, width: 1), backgroundColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("View Invitations", style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 14)),
                          if (_pendingInvites.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      )
    );
  }
}