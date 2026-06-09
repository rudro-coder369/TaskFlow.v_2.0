import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:intl/intl.dart';

import 'package:lucide_icons/lucide_icons.dart';

import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:supabase_flutter/supabase_flutter.dart';



import '../providers/progress_provider.dart';

import '../providers/elite_stats_provider.dart';



class AccountScreen extends StatefulWidget {

  const AccountScreen({super.key});



  @override

  State<AccountScreen> createState() => _AccountScreenState();

}



class _AccountScreenState extends State<AccountScreen> {

  final _supabase = Supabase.instance.client;

 

  bool _loading = true;

  bool _isSaving = false;

 

  Map<String, dynamic>? _profileData;

  String? _userId;

  String _userEmail = "";



  // Controllers for Edit Profile

  final _usernameController = TextEditingController();

  final _fullNameController = TextEditingController();

  final _bioController = TextEditingController();

  final _phoneController = TextEditingController();

  final _schoolController = TextEditingController();

 

  String _selectedClass = '10';

  String _selectedGroup = 'science';

  String _selectedAvatar = 'Felix';



  final List<String> _avatars = ['Felix', 'Aneka', 'Oliver', 'Mimi', 'Jack', 'Sophia', 'Leo', 'Zoe', 'Alexander', 'Mia', 'Lucas', 'Lily', 'Ethan', 'Chloe'];



  final List<String> _classes = ['9', '10', '11', '12', 'Admission'];

  final List<String> _groups = ['science', 'arts', 'commerce'];



  final List<Map<String, dynamic>> _rankTiers = [

    { 'name': 'Legend', 'hours': '250h+', 'xp': '24,750+ XP', 'color': Colors.purple.shade600, 'bg': Colors.purple.shade50, 'border': Colors.purple.shade200 },

    { 'name': 'Emperor', 'hours': '150 - 250h', 'xp': '14,850 XP', 'color': Colors.red.shade600, 'bg': Colors.red.shade50, 'border': Colors.red.shade200 },

    { 'name': 'Prime', 'hours': '80 - 150h', 'xp': '7,920 XP', 'color': Colors.indigo.shade600, 'bg': Colors.indigo.shade50, 'border': Colors.indigo.shade200 },

    { 'name': 'Elite', 'hours': '40 - 80h', 'xp': '3,960 XP', 'color': Colors.orange.shade600, 'bg': Colors.orange.shade50, 'border': Colors.orange.shade200 },

    { 'name': 'Platinum', 'hours': '15 - 40h', 'xp': '1,485 XP', 'color': Colors.lightBlue.shade600, 'bg': Colors.lightBlue.shade50, 'border': Colors.lightBlue.shade200 },

    { 'name': 'Silver', 'hours': '0 - 15h', 'xp': '0 XP', 'color': Colors.grey.shade500, 'bg': Colors.grey.shade50, 'border': Colors.grey.shade200 }

  ];



  @override

  void initState() {

    super.initState();

    _fetchUserData();

  }



  @override

  void dispose() {

    _usernameController.dispose();

    _fullNameController.dispose();

    _bioController.dispose();

    _phoneController.dispose();

    _schoolController.dispose();

    super.dispose();

  }



  Future<void> _fetchUserData() async {

    final session = _supabase.auth.currentSession;

    if (session != null) {

      _userEmail = session.user.email ?? "";

      _userId = session.user.id;



      try {

        final profileResponse = await _supabase

            .from('profiles')

            .select('username, full_name, school_name, academic_class, academic_group, bio, phone, avatar_seed, created_at')

            .eq('id', _userId!)

            .single();



        final logsResponse = await _supabase.from('daily_logs').select('study_seconds').eq('user_id', _userId!);

        int totalSecs = 0;

        for (var log in (logsResponse as List)) {

          totalSecs += int.tryParse(log['study_seconds'].toString()) ?? 0;

        }



        if (mounted) {

          Provider.of<EliteStatsProvider>(context, listen: false).updateLifetimeSeconds(totalSecs);



          setState(() {

            _profileData = profileResponse;

            _usernameController.text = profileResponse['username'] ?? "";

            _fullNameController.text = profileResponse['full_name'] ?? "";

            _bioController.text = profileResponse['bio'] ?? "";

            _phoneController.text = profileResponse['phone'] ?? "";

            _schoolController.text = profileResponse['school_name'] ?? "";

            _selectedClass = profileResponse['academic_class'] ?? '10';

            _selectedGroup = profileResponse['academic_group'] ?? 'science';

            _selectedAvatar = profileResponse['avatar_seed'] ?? 'Felix';



            if (!_classes.contains(_selectedClass)) _selectedClass = '10';

            if (!_groups.contains(_selectedGroup)) _selectedGroup = 'science';

          });

        }

      } catch (e) {

        debugPrint("Fetch User Error: $e");

      }

    }

    if (mounted) setState(() => _loading = false);

  }



  Map<String, int> _getNextRankProgress(int currentXp) {

    if (currentXp < 1485) return {'min': 0, 'max': 1485};

    if (currentXp < 3960) return {'min': 1485, 'max': 3960};

    if (currentXp < 7920) return {'min': 3960, 'max': 7920};

    if (currentXp < 14850) return {'min': 7920, 'max': 14850};

    if (currentXp < 24750) return {'min': 14850, 'max': 24750};

    return {'min': 24750, 'max': 50000};

  }



  void _showEditProfileSheet() {

    showModalBottomSheet(

      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (context) => StatefulBuilder(

        builder: (context, setSheetState) {

          return Container(

            height: MediaQuery.of(context).size.height * 0.9,

            decoration: const BoxDecoration(

              color: Colors.white,

              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),

            ),

            child: SafeArea(

              child: Column(

                children: [

                  Container(

                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),

                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),

                    child: Row(

                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [

                        const Text("Edit Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),

                        IconButton(icon: const Icon(LucideIcons.x, color: Colors.grey), onPressed: () => Navigator.pop(context)),

                      ],

                    ),

                  ),

                  Expanded(

                    child: SingleChildScrollView(

                      padding: const EdgeInsets.all(24),

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          const Text("CHOOSE AVATAR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),

                          const SizedBox(height: 12),

                          SizedBox(

                            height: 72,

                            child: ListView.builder(

                              scrollDirection: Axis.horizontal,

                              itemCount: _avatars.length,

                              itemBuilder: (context, index) {

                                final seed = _avatars[index];

                                final isSelected = _selectedAvatar == seed;

                                return GestureDetector(

                                  onTap: () => setSheetState(() => _selectedAvatar = seed),

                                  child: Container(

                                    margin: const EdgeInsets.only(right: 12),

                                    padding: const EdgeInsets.all(2),

                                    decoration: BoxDecoration(

                                      shape: BoxShape.circle,

                                      border: Border.all(color: isSelected ? const Color(0xFF10A37F) : Colors.transparent, width: 3),

                                    ),

                                    child: CircleAvatar(

                                      radius: 32,

                                      backgroundColor: Colors.grey.shade100,

                                      backgroundImage: NetworkImage('https://api.dicebear.com/8.x/notionists/png?seed=$seed&backgroundColor=f8fafc'),

                                    ),

                                  ),

                                );

                              },

                            ),

                          ),

                          const SizedBox(height: 24),



                          _buildEditField("FULL NAME (Only letters & spaces)", _fullNameController, LucideIcons.userCheck,

                            formatter: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))]

                          ),

                          const SizedBox(height: 16),



                          _buildEditField("USERNAME (Lowercase, numbers & underscore)", _usernameController, LucideIcons.atSign,

                            formatter: [FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]'))]

                          ),

                          const SizedBox(height: 16),

                         

                          _buildEditField("BIO (Max 50 Characters)", _bioController, LucideIcons.penTool, maxLines: 2, maxLength: 50),

                          const SizedBox(height: 16),

                         

                          Row(

                            children: [

                              Expanded(child: _buildEditDropdown("CLASS", _selectedClass, _classes, (v) => setSheetState(() => _selectedClass = v!))),

                              const SizedBox(width: 12),

                              Expanded(child: _buildEditDropdown("GROUP", _selectedGroup, _groups, (v) => setSheetState(() => _selectedGroup = v!))),

                            ],

                          ),

                          const SizedBox(height: 16),

                          _buildEditField("SCHOOL / COLLEGE", _schoolController, LucideIcons.building),

                          const SizedBox(height: 16),

                          _buildEditField("MOBILE NUMBER", _phoneController, LucideIcons.phone, inputType: TextInputType.phone),

                          const SizedBox(height: 32),

                         

                          SizedBox(

                            width: double.infinity,

                            height: 56,

                            child: ElevatedButton(

                              onPressed: _isSaving ? null : () async {

                                final username = _usernameController.text.trim();

                                final fullName = _fullNameController.text.trim();



                                if (fullName.isEmpty || !RegExp(r'^[a-zA-Z\s]+$').hasMatch(fullName)) {

                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Full Name! Only letters and spaces allowed."), backgroundColor: Colors.red));

                                  return;

                                }



                                if (username.isEmpty || !RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {

                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Username! Only lowercase, numbers, and underscores allowed."), backgroundColor: Colors.red));

                                  return;

                                }



                                setSheetState(() => _isSaving = true);

                                await _saveProfileChanges();

                                setSheetState(() => _isSaving = false);

                                if (mounted) Navigator.pop(context);

                              },

                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10A37F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),

                              child: _isSaving

                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))

                                : const Text("Save Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),

                            ),

                          ),

                          Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom)),

                        ],

                      ),

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



  Future<void> _saveProfileChanges() async {

    try {

      final updates = {

        'username': _usernameController.text.trim(),

        'full_name': _fullNameController.text.trim(),

        'bio': _bioController.text.trim(),

        'school_name': _schoolController.text.trim(),

        'phone': _phoneController.text.trim(),

        'academic_class': _selectedClass,

        'academic_group': _selectedGroup,

        'avatar_seed': _selectedAvatar,

      };



      await _supabase.from('profiles').update(updates).eq('id', _userId!);

     

      setState(() {

        if (_profileData != null) {

          _profileData!['username'] = updates['username'];

          _profileData!['full_name'] = updates['full_name'];

          _profileData!['bio'] = updates['bio'];

          _profileData!['school_name'] = updates['school_name'];

          _profileData!['phone'] = updates['phone'];

          _profileData!['academic_class'] = updates['academic_class'];

          _profileData!['academic_group'] = updates['academic_group'];

          _profileData!['avatar_seed'] = updates['avatar_seed'];

        }

      });

     

      if (mounted) {

        Provider.of<ProgressProvider>(context, listen: false).fetchProfileData();

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Colors.green));

      }

    } catch (e) {

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update profile. Username might be taken."), backgroundColor: Colors.red));

    }

  }



  Future<void> _handleHardReset() async {

    bool confirm = await showDialog(

      context: context,

      builder: (context) => AlertDialog(

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

        title: const Row(children: [Icon(LucideIcons.alertTriangle, color: Colors.red), SizedBox(width: 8), Text("WARNING", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),

        content: const Text("This will PERMANENTLY wipe your entire Syllabus progress and Daily logs from the Database!"),

        actions: [

          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),

          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text("Delete Everything", style: TextStyle(color: Colors.white))),

        ],

      ),

    ) ?? false;



    if (!confirm) return;



    setState(() => _loading = true);

    try {

      if (_userId != null) {

        await _supabase.from('daily_logs').delete().eq('user_id', _userId!);

        await _supabase.from('profiles').update({'syllabus_progress': {}}).eq('id', _userId!);

        final prefs = await SharedPreferences.getInstance();

        await prefs.remove('active_task_id');

        await prefs.remove('active_task_start');

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syllabus Data Deleted! 🚀"), backgroundColor: Colors.green));

      }

    } catch (e) {

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not complete the request."), backgroundColor: Colors.red));

    } finally {

      if (mounted) setState(() => _loading = false);

    }

  }



  Future<void> _handleLogout() async {

    await _supabase.auth.signOut();

    if (mounted) Navigator.of(context).pop();

  }



  String _formatDate(String? isoString) {

    if (isoString == null) return "Unknown";

    final date = DateTime.parse(isoString);

    return DateFormat('MMMM yyyy').format(date);

  }



  @override

  Widget build(BuildContext context) {

    if (_loading || _profileData == null) {

      return const Scaffold(backgroundColor: Color(0xFFF8FAFC), body: Center(child: CircularProgressIndicator(color: Color(0xFF10A37F))));

    }



    final p = _profileData!;

    final bioText = p['bio']?.toString().trim() ?? "";

    final currentAvatar = p['avatar_seed'] ?? 'Felix';



    final eliteStats = Provider.of<EliteStatsProvider>(context).stats;

    final int currentXp = eliteStats['finalXp'] ?? 0;

    final rankInfo = eliteStats['rank'];

   

    final progressBounds = _getNextRankProgress(currentXp);

    final minXp = progressBounds['min']!;

    final maxXp = progressBounds['max']!;

   

    double progressPercent = 1.0;

    if (maxXp > minXp && currentXp < maxXp) {

      progressPercent = (currentXp - minXp) / (maxXp - minXp);

    }

    if (progressPercent < 0) progressPercent = 0;

    if (progressPercent > 1) progressPercent = 1;



    return Scaffold(

      backgroundColor: const Color(0xFFF8FAFC),

      body: CustomScrollView(

        slivers: [

          // 🔥 SLEEK & COMPACT APP BAR WITH EMBEDDED STATS

          SliverAppBar(

            expandedHeight: 250.0, // Fixed compact height

            floating: false,

            pinned: true,

            backgroundColor: const Color(0xFF10A37F),

            iconTheme: const IconThemeData(color: Colors.white),

            shape: const RoundedRectangleBorder(

              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),

            ),

            actions: [

              IconButton(

                icon: const Icon(LucideIcons.edit, color: Colors.white),

                onPressed: _showEditProfileSheet,

                tooltip: "Edit Profile",

              ),

              const SizedBox(width: 8),

            ],

            flexibleSpace: FlexibleSpaceBar(

              background: Container(

                decoration: const BoxDecoration(

                  gradient: LinearGradient(

                    colors: [Color(0xFF10A37F), Color(0xFF0D8C6C)],

                    begin: Alignment.topCenter,

                    end: Alignment.bottomCenter

                  ),

                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),

                ),

                child: SafeArea(

                  child: Padding(

                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),

                    child: Column(

                      children: [

                        // Profile Info Row

                        Row(

                          children: [

                            Container(

                              padding: const EdgeInsets.all(3),

                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.2)),

                              child: CircleAvatar(

                                radius: 28, // Compact Avatar

                                backgroundColor: Colors.white,

                                backgroundImage: NetworkImage('https://api.dicebear.com/8.x/notionists/png?seed=$currentAvatar&backgroundColor=f8fafc'),

                              ),

                            ),

                            const SizedBox(width: 16),

                            Expanded(

                              child: Column(

                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [

                                  Text(p['full_name'] ?? "Scholar", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),

                                  const SizedBox(height: 2),

                                  Text("@${p['username'] ?? 'user'}", style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500)),

                                  if (bioText.isNotEmpty) ...[

                                    const SizedBox(height: 4),

                                    Text(bioText, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.9)), maxLines: 1, overflow: TextOverflow.ellipsis),

                                  ]

                                ],

                              ),

                            )

                          ],

                        ),

                       

                        const SizedBox(height: 20),



                        // 🔥 EMBEDDED GLASSMORPHISM STATS BOX

                        Container(

                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

                          decoration: BoxDecoration(

                            color: Colors.black.withOpacity(0.15),

                            borderRadius: BorderRadius.circular(16),

                            border: Border.all(color: Colors.white.withOpacity(0.1)),

                          ),

                          child: Column(

                            children: [

                              Row(

                                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                                children: [

                                  Row(

                                    children: [

                                      Text("Lvl ${eliteStats['level']} • ", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),

                                      Text(rankInfo['name'], style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600)),

                                    ],

                                  ),

                                  Text("${NumberFormat('#,###').format(currentXp)} XP", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),

                                ],

                              ),

                              const SizedBox(height: 10),

                              ClipRRect(

                                borderRadius: BorderRadius.circular(4),

                                child: LinearProgressIndicator(

                                  value: progressPercent,

                                  minHeight: 4,

                                  backgroundColor: Colors.white.withOpacity(0.2),

                                  color: Colors.white,

                                ),

                              ),

                              const SizedBox(height: 6),

                              Row(

                                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                                children: [

                                  Text(rankInfo['name'] == 'Legend' ? "MAX LEVEL" : "PROGRESS", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),

                                  if (rankInfo['name'] != 'Legend')

                                    Text("${NumberFormat('#,###').format(maxXp)} XP NEXT", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),

                                ],

                              )

                            ],

                          ),

                        )

                      ],

                    ),

                  ),

                ),

              ),

            ),

          ),



          // 🔥 BODY CONTENT

          SliverToBoxAdapter(

            child: Padding(

              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  // --- Academic Identity ---

                  const Text("Academic Identity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),

                  const SizedBox(height: 12),

                  Container(

                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),

                    child: Column(

                      children: [

                        _buildInfoTile(LucideIcons.building, "Institution", p['school_name'] ?? "Not specified"),

                        const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F9)),

                        _buildInfoTile(LucideIcons.graduationCap, "Class", p['academic_class'] != null ? "Class ${p['academic_class']}" : "Not specified"),

                        const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F9)),

                        _buildInfoTile(LucideIcons.layers, "Group", p['academic_group']?.toString().toUpperCase() ?? "Not specified"),

                        const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F9)),

                        _buildInfoTile(LucideIcons.phone, "Mobile", p['phone'] ?? "Not specified"),

                        const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F9)),

                        _buildInfoTile(LucideIcons.mail, "Email", _userEmail),

                        const Divider(height: 1, indent: 48, color: Color(0xFFF1F5F9)),

                        _buildInfoTile(LucideIcons.calendarCheck, "Joined TaskFlow", _formatDate(p['created_at'])),

                      ],

                    ),

                  ),

                  const SizedBox(height: 32),



                  // ⚙️ SETTINGS & ACTIONS

                  const Text("Preferences & Actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),

                  const SizedBox(height: 12),

                  Container(

                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),

                    child: Column(

                      children: [

                        ListTile(

                          onTap: _handleHardReset,

                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),

                          leading: const Icon(LucideIcons.trash2, color: Colors.redAccent),

                          title: const Text("Delete Syllabus Data", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),

                          subtitle: const Text("Permanently delete progress", style: TextStyle(fontSize: 11, color: Colors.grey)),

                          trailing: const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),

                        ),

                        const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),

                        ListTile(

                          onTap: _handleLogout,

                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),

                          leading: const Icon(LucideIcons.logOut, color: Colors.grey),

                          title: const Text("Sign Out", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),

                          trailing: const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),

                        ),

                      ],

                    ),

                  ),



                  const SizedBox(height: 32),

                 

                  // 🏆 RANK TIERS INFO

                  Container(

                    width: double.infinity, padding: const EdgeInsets.all(20),

                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),

                    child: Column(

                      children: [

                        const Row(children: [Icon(LucideIcons.info, size: 18, color: Color(0xFF10A37F)), SizedBox(width: 8), Text("Rank Tiers Overview", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))]),

                        const SizedBox(height: 16),

                        ..._rankTiers.map((rank) => Container(

                          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),

                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),

                          child: Row(

                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [

                              Row(

                                children: [

                                  Container(width: 40, height: 40, decoration: BoxDecoration(color: rank['bg'], shape: BoxShape.circle, border: Border.all(color: rank['border'])), child: Icon(LucideIcons.medal, size: 18, color: rank['color'])),

                                  const SizedBox(width: 12),

                                  Column(

                                    crossAxisAlignment: CrossAxisAlignment.start,

                                    children: [

                                      Text(rank['name'], style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: rank['color'])),

                                      Row(children: [const Icon(LucideIcons.zap, size: 10, color: Colors.grey), const SizedBox(width: 4), Text("${rank['hours']} Focus", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey))])

                                    ]

                                  ),

                                ],

                              ),

                              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)), child: Text(rank['xp'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),

                            ],

                          ),

                        )),

                      ],

                    ),

                  ),

                ],

              ),

            ),

          ),

        ],

      ),

    );

  }



  // --- Helpers for Display ---

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {

    return ListTile(

      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: const Color(0xFF10A37F))),

      title: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),

      subtitle: Text(subtitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),

    );

  }



  // --- Helpers for Edit Bottom Sheet ---

  Widget _buildEditField(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1, int? maxLength, TextInputType inputType = TextInputType.text, List<TextInputFormatter>? formatter}) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),

        const SizedBox(height: 6),

        TextField(

          controller: ctrl, maxLines: maxLines, maxLength: maxLength, keyboardType: inputType, inputFormatters: formatter,

          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),

          decoration: InputDecoration(

            prefixIcon: maxLines == 1 ? Icon(icon, size: 18, color: const Color(0xFF10A37F)) : null,

            filled: true, fillColor: const Color(0xFFF8FAFC),

            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),

            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),

            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF10A37F))),

          ),

        ),

      ],

    );

  }



  Widget _buildEditDropdown(String label, String value, List<String> items, Function(String?) onChanged) {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),

        const SizedBox(height: 6),

        DropdownButtonFormField<String>(

          value: value,

          icon: const Icon(LucideIcons.chevronDown, size: 16),

          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),

          decoration: InputDecoration(

            filled: true, fillColor: const Color(0xFFF8FAFC),

            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),

            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),

          ),

          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),

          onChanged: onChanged,

        ),

      ],

    );

  }

} 