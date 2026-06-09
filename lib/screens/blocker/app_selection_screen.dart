import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:device_apps/device_apps.dart';

class AppSelectionScreen extends StatefulWidget {
  final List<String> alreadyBlockedPackages;

  const AppSelectionScreen({super.key, required this.alreadyBlockedPackages});

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  bool _isLoading = true;
  List<Application> _allApps = [];
  List<Application> _filteredApps = [];
  
  // দ্রুত চেক করার জন্য Set ব্যবহার করা হচ্ছে
  late Set<String> _selectedPackages;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedPackages = Set.from(widget.alreadyBlockedPackages);
    _fetchInstalledApps();
  }

  // ==========================================
  // 📱 FETCH APPS FROM DEVICE (REAL DATA)
  // ==========================================
  Future<void> _fetchInstalledApps() async {
    setState(() => _isLoading = true);
    
    // সিস্টেম অ্যাপ বাদে শুধুমাত্র যেসব অ্যাপ ওপেন করা যায় সেগুলো আনবে
    List<Application> apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      includeSystemApps: false, 
      onlyAppsWithLaunchIntent: true,
    );

    // নাম অনুযায়ী সর্ট করা (A-Z)
    apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));

    if (mounted) {
      setState(() {
        _allApps = apps;
        _filteredApps = apps;
        _isLoading = false;
      });
    }
  }

  // ==========================================
  // 🔍 SEARCH LOGIC
  // ==========================================
  void _filterApps(String query) {
    if (query.isEmpty) {
      setState(() => _filteredApps = _allApps);
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredApps = _allApps.where((app) {
        return app.appName.toLowerCase().contains(lowercaseQuery);
      }).toList();
    });
  }

  // ==========================================
  // 💾 SAVE HITLIST & RETURN TO DASHBOARD
  // ==========================================
  void _saveSelection() {
    // সিলেক্টেড প্যাকেজগুলোর লিস্ট ড্যাশবোর্ডে রিটার্ন করে দিচ্ছি
    Navigator.pop(context, _selectedPackages.toList());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Signature Light Background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text("TARGET SELECTION", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A), letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveSelection,
            child: const Text("SAVE", style: TextStyle(color: Color(0xFF10A37F), fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10A37F)))
          : Column(
              children: [
                // ==========================================
                // 🔍 SEARCH BAR
                // ==========================================
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    onChanged: _filterApps,
                    decoration: InputDecoration(
                      hintText: "Search apps (e.g. Facebook)",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: const Icon(LucideIcons.search, color: Color(0xFF10A37F)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF10A37F), width: 1.5)),
                    ),
                  ),
                ),

                // ==========================================
                // 📜 APP LIST
                // ==========================================
                Expanded(
                  child: _filteredApps.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          itemCount: _filteredApps.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final app = _filteredApps[index];
                            final bool isSelected = _selectedPackages.contains(app.packageName);
                            final ApplicationWithIcon appWithIcon = app as ApplicationWithIcon; // আইকনের জন্য কাস্ট করা হলো

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedPackages.remove(app.packageName);
                                  } else {
                                    _selectedPackages.add(app.packageName);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF10A37F).withOpacity(0.05) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF10A37F).withOpacity(0.5) : Colors.grey.shade200,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    if (!isSelected)
                                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // 📱 App Original Icon
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        appWithIcon.icon,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // App Name & Package
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            app.appName, 
                                            style: TextStyle(
                                              color: isSelected ? const Color(0xFF10A37F) : const Color(0xFF0F172A), 
                                              fontWeight: FontWeight.bold, 
                                              fontSize: 15
                                            )
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            app.packageName, 
                                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11), 
                                            maxLines: 1, 
                                            overflow: TextOverflow.ellipsis
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Checkbox / Lock Icon
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF10A37F) : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: isSelected ? const Color(0xFF10A37F) : Colors.grey.shade300),
                                      ),
                                      child: Icon(
                                        isSelected ? LucideIcons.lock : LucideIcons.unlock,
                                        color: isSelected ? Colors.white : Colors.grey.shade400,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                
                // Bottom Gradient Shadow for aesthetics
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [const Color(0xFFF8FAFC), const Color(0xFFF8FAFC).withOpacity(0)],
                    ),
                  ),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)),
            child: Icon(LucideIcons.searchX, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          const Text("NO APPS FOUND", style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          const Text("Try searching with a different name.", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), height: 1.5)),
        ],
      ),
    );
  }
}