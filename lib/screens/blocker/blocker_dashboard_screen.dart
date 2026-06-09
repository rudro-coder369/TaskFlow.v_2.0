import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:device_apps/device_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

// আমাদের বানানো ফাইলগুলো ইমপোর্ট
import 'app_selection_screen.dart';
import '../../services/native_blocker_channel.dart';

class BlockerDashboardScreen extends StatefulWidget {
  const BlockerDashboardScreen({super.key});

  @override
  State<BlockerDashboardScreen> createState() => _BlockerDashboardScreenState();
}

class _BlockerDashboardScreenState extends State<BlockerDashboardScreen> with SingleTickerProviderStateMixin {
  bool _isBlockingActive = false;
  bool _isLoadingApps = false;
  
  // ডেমো রিমুভড: এখন একদম ফাঁকা থাকবে, ইউজার নিজে অ্যাড করবে
  List<String> _blockedPackageNames = [];
  List<Application> _blockedAppsDetails = [];

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  // ==========================================
  // 💾 LOAD REAL DATA FROM DEVICE MEMORY
  // ==========================================
  Future<void> _loadSavedSettings() async {
    setState(() => _isLoadingApps = true);
    final prefs = await SharedPreferences.getInstance();
    
    // অ্যাপ রিস্টার্ট দিলেও যেন আগের স্টেট মনে রাখে
    _isBlockingActive = prefs.getBool('is_blocking_active') ?? false;
    _blockedPackageNames = prefs.getStringList('blocked_apps_list') ?? [];

    await _fetchAppIcons(_blockedPackageNames);
  }

  Future<void> _fetchAppIcons(List<String> packages) async {
    List<Application> apps = [];
    for (String pkg in packages) {
      Application? app = await DeviceApps.getApp(pkg, true);
      if (app != null) {
        apps.add(app);
      }
    }

    if (mounted) {
      setState(() {
        _blockedAppsDetails = apps;
        _isLoadingApps = false;
      });
    }
  }

  // ==========================================
  // ⚙️ THE MAIN TOGGLE ENGINE (Native Connection)
  // ==========================================
  Future<void> _toggleFocusMode() async {
    if (_blockedPackageNames.isEmpty && !_isBlockingActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add some apps to block first!"), backgroundColor: Colors.orange),
      );
      return;
    }

    // ১. পারমিশন চেক
    bool hasAccessibility = await NativeBlockerChannel.isAccessibilityPermissionGranted();
    bool hasOverlay = await NativeBlockerChannel.isOverlayPermissionGranted();

    if (!hasAccessibility) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Need Accessibility Permission!"), backgroundColor: Colors.redAccent));
      await NativeBlockerChannel.requestAccessibilityPermission();
      return; 
    }

    if (!hasOverlay) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Need Overlay Permission!"), backgroundColor: Colors.redAccent));
      await NativeBlockerChannel.requestOverlayPermission();
      return;
    }

    // ২. স্টেট চেঞ্জ ও সেভ
    setState(() {
      _isBlockingActive = !_isBlockingActive;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_blocking_active', _isBlockingActive);

    // ৩. নেটিভ ইঞ্জিনকে সিগন্যাল পাঠানো
    if (_isBlockingActive) {
      await NativeBlockerChannel.startBlocking(_blockedPackageNames);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🛡️ Focus Mode Activated! Distractions locked."), backgroundColor: Color(0xFF10A37F)),
        );
      }
    } else {
      await NativeBlockerChannel.stopBlocking();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Focus Mode Deactivated."), backgroundColor: Colors.orange),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Signature White/Light Background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text("FOCUS MODE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A), letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // 🎛️ THE MASTER SWITCH CARD (White & Green)
              // ==========================================
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _isBlockingActive ? const Color(0xFF10A37F).withOpacity(0.5) : Colors.grey.shade200,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isBlockingActive ? const Color(0xFF10A37F).withOpacity(0.15) : Colors.black.withOpacity(0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _isBlockingActive ? const Color(0xFF10A37F).withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isBlockingActive ? LucideIcons.shieldCheck : LucideIcons.shieldAlert,
                          size: 48,
                          color: _isBlockingActive ? const Color(0xFF10A37F) : Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isBlockingActive ? "SYSTEM SECURED" : "VULNERABLE",
                        style: TextStyle(
                          color: _isBlockingActive ? const Color(0xFF10A37F) : Colors.redAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isBlockingActive ? "Distracting apps are currently blocked." : "Your device is open to distractions.",
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      
                      // 🔘 Action Button
                      GestureDetector(
                        onTap: _toggleFocusMode,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                          decoration: BoxDecoration(
                            color: _isBlockingActive ? Colors.white : const Color(0xFF10A37F),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF10A37F), width: 2),
                          ),
                          child: Text(
                            _isBlockingActive ? "DEACTIVATE" : "ACTIVATE SHIELD",
                            style: TextStyle(
                              color: _isBlockingActive ? const Color(0xFF10A37F) : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ==========================================
              // 📋 THE TARGET HITLIST (Blocked Apps)
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("RESTRICTED APPS", style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  TextButton.icon(
                    onPressed: () async {
                      // 🚀 Navigate to App Selection Screen
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppSelectionScreen(alreadyBlockedPackages: _blockedPackageNames),
                        ),
                      );

                      if (result != null && result is List<String>) {
                        setState(() {
                          _blockedPackageNames = result;
                        });
                        
                        // Save new list to SharedPreferences
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setStringList('blocked_apps_list', _blockedPackageNames);

                        _fetchAppIcons(_blockedPackageNames); 
                        
                        // Update native engine immediately if blocking is active
                        if (_isBlockingActive) {
                          NativeBlockerChannel.startBlocking(_blockedPackageNames);
                        }
                      }
                    },
                    icon: const Icon(LucideIcons.plus, size: 16, color: Color(0xFF10A37F)),
                    label: const Text("Edit List", style: TextStyle(color: Color(0xFF10A37F), fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 8),

              // 📱 Apps List
              Expanded(
                child: _isLoadingApps 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF10A37F)))
                    : _blockedAppsDetails.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _blockedAppsDetails.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final app = _blockedAppsDetails[index];
                              final appWithIcon = app as ApplicationWithIcon;

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        appWithIcon.icon,
                                        width: 40,
                                        height: 40,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(app.appName, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15)),
                                          Text(app.packageName, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    const Icon(LucideIcons.lock, color: Color(0xFF10A37F), size: 20),
                                  ],
                                ),
                              );
                            },
                          ),
              )
            ],
          ),
        ),
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
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(LucideIcons.ghost, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          const Text("NO APPS SELECTED", style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          const Text("Add distracting apps to your hitlist\nto start blocking them.", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), height: 1.5)),
        ],
      ),
    );
  }
}