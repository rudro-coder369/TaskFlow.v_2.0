import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart'; // তোর হোম স্ক্রিনের পাথ

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = true;
  bool _isLogin = true;
  bool _showPassword = false;
  bool _needsUsername = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  String _authMsgType = '';
  String _authMsgText = '';

  final _supabase = Supabase.instance.client;
  late StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkFirstVisit();
    _setupAuthListener();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _authSubscription.cancel();
    super.dispose();
  }

  // SMART LOGIN/SIGNUP DETECTOR
  Future<void> _checkFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final hasVisited = prefs.getBool('has_visited_taskflow') ?? false;
    
    if (!hasVisited) {
      await prefs.setBool('has_visited_taskflow', true);
      setState(() {
        _isLogin = false; // প্রথমবার আসলে সাইন-আপ দেখাবে
      });
    }
  }

  void _setupAuthListener() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      _handleAuthTransition(session);
    });
  }

  Future<void> _handleAuthTransition(Session? session) async {
    if (session != null) {
      // 🚨 FIX: Force profile check before letting them go to Dashboard
      await _checkProfileStatus(session.user.id);
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkProfileStatus(String userId) async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final data = await _supabase.from('profiles').select('username').eq('id', userId).maybeSingle();
      
      if (data == null || data['username'] == null || data['username'].toString().trim().isEmpty) {
        // 🚨 Username block: Force user to stay on login screen and show username form
        if (mounted) setState(() {
          _needsUsername = true;
          _loading = false;
        });
      } else {
        // Profile has a username, safe to proceed to Dashboard
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()), 
          );
        }
      }
    } catch (e) {
      // On error, still enforce username check to be safe
      if (mounted) setState(() {
        _needsUsername = true;
        _loading = false;
      });
    }
  }

  Future<void> _handleAuthAction() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;

    setState(() {
      _loading = true;
      _authMsgText = '';
    });

    try {
      if (_isLogin) {
        await _supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        final res = await _supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (res.user != null && res.session == null) {
          setState(() {
            _authMsgType = 'success';
            _authMsgText = 'Verification link sent! Please check your email inbox.';
          });
        }
      }
    } on AuthException catch (error) {
      setState(() {
        _authMsgType = 'error';
        _authMsgText = error.message;
      });
    } catch (error) {
      setState(() {
        _authMsgType = 'error';
        _authMsgText = "Something went wrong. Please try again.";
      });
    } finally {
      if (mounted && _authMsgText.isNotEmpty) setState(() => _loading = false);
    }
  }

  Future<void> _saveUsernameAndStart() async {
    final cleanUsername = _usernameController.text.trim();
    if (cleanUsername.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Username must be at least 3 characters.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _loading = true);
    
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // 🚨 FIX: Force upsert and wait for confirmation
      await _supabase.from('profiles').upsert({
        'id': userId,
        'username': cleanUsername,
      });

      // 🚨 Secondary check to ensure it was saved before pushing
      final verify = await _supabase.from('profiles').select('username').eq('id', userId).single();
      if (verify['username'] == cleanUsername) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()), 
          );
        }
      } else {
        throw Exception("Failed to verify username save.");
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error saving username. It might be taken! Try another one."), backgroundColor: Colors.red),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // INITIAL LOADING STATE
    if (_loading && !_needsUsername && _authMsgText.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF10A37F), strokeWidth: 3),
              SizedBox(height: 16),
              Text(
                "TASKFLOW. SYNCING",
                style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
              )
            ],
          ),
        ),
      );
    }

    // MAIN UI
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    )
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // BRANDING
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.checkCircle, color: Color(0xFF10A37F), size: 28),
                        SizedBox(width: 8),
                        Text("TaskFlow.", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text(
                      _needsUsername ? "Set your username" : (_isLogin ? "Welcome back" : "Create your account"),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _needsUsername ? "Choose how you'll appear on the leaderboard." : (_isLogin ? "Continue your journey to elite focus." : "Start your journey to elite focus."),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 32),

                    // MESSAGE BOX
                    if (_authMsgText.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _authMsgType == 'error' ? Colors.red.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _authMsgType == 'error' ? Colors.red.shade100 : Colors.green.shade100),
                        ),
                        child: Text(
                          _authMsgText,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _authMsgType == 'error' ? Colors.red.shade700 : Colors.green.shade700),
                        ),
                      ),

                    // FORMS
                    if (_needsUsername)
                      // USERNAME FORM
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Display Name", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              hintText: "e.g. Scholar24",
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10A37F), width: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text("This is how you will appear to others on the leaderboard.", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _saveUsernameAndStart,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10A37F),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: _loading 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      )
                    else
                      // LOGIN/SIGNUP FORM
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Email address", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: "email@example.com",
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10A37F), width: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text("Password", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_showPassword,
                            decoration: InputDecoration(
                              hintText: "••••••••",
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10A37F), width: 1.5)),
                              suffixIcon: IconButton(
                                icon: Icon(_showPassword ? LucideIcons.eyeOff : LucideIcons.eye, color: Colors.grey.shade500, size: 20),
                                onPressed: () => setState(() => _showPassword = !_showPassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _handleAuthAction,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10A37F),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: _loading 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_isLogin ? "Don't have an account?" : "Already have an account?", style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isLogin = !_isLogin;
                                    _authMsgText = '';
                                  });
                                },
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                child: Text(_isLogin ? "Sign up" : "Log in", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF10A37F))),
                              )
                            ],
                          )
                        ],
                      )
                  ],
                ),
              ),

              const SizedBox(height: 32),
              // Subtle Copyright
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("PRIVACY POLICY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 1)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text("|", style: TextStyle(color: Colors.grey)),
                  ),
                  Text("TERMS OF SERVICE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 1)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}