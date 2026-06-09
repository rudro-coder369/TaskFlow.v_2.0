import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; 
import '../providers/progress_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  bool _isLogin = true;
  bool _showPassword = false;
  bool _isLoadingSchools = false;
  
  // 🔥 নতুন স্টেট: পাসওয়ার্ড রিসেট মোডের জন্য
  bool _isResettingPassword = false;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController(); // নতুন পাসওয়ার্ডের জন্য
  
  // 🔑 Auth State Listener Subscription
  late final StreamSubscription<AuthState> _authSubscription;

  // Selections
  String _selectedSchool = "";
  String _searchedSchoolText = ""; 
  String? _selectedClass;
  String? _selectedGroup;
  String? _selectedGender;
  String? _selectedDivision;
  String? _selectedDistrict;

  // Dropdown Lists
  final List<String> _classes = ['Select', '9', '10', '11', '12', 'Admission'];
  final List<String> _groups = ['Select', 'Science', 'Arts', 'Commerce'];
  final List<String> _genders = ['Select', 'Male', 'Female', 'Other'];

  final List<String> _divisions = ['Dhaka', 'Rajshahi', 'Chattogram', 'Khulna', 'Barishal', 'Sylhet', 'Rangpur', 'Mymensingh'];

  final Map<String, List<String>> _districtsMap = {
    'Dhaka': ['Dhaka', 'Gazipur', 'Narayanganj', 'Tangail', 'Faridpur', 'Manikganj', 'Munshiganj', 'Rajbari', 'Madaripur', 'Gopalganj', 'Shariatpur', 'Kishoreganj', 'Narsingdi'],
    'Rajshahi': ['Bogura', 'Rajshahi', 'Pabna', 'Sirajganj', 'Naogaon', 'Natore', 'Chapainawabganj', 'Joypurhat'],
    'Chattogram': ['Chattogram', 'Cox\'s Bazar', 'Cumilla', 'Feni', 'Noakhali', 'Brahmanbaria', 'Chandpur', 'Lakshmipur', 'Khagrachhari', 'Rangamati', 'Bandarban'],
    'Khulna': ['Khulna', 'Jashore', 'Satkhira', 'Meherpur', 'Narail', 'Chuadanga', 'Kushtia', 'Magura', 'Bagerhat', 'Jhenaidah'],
    'Barishal': ['Barishal', 'Bhola', 'Patuakhali', 'Pirojpur', 'Jhalokati', 'Barguna'],
    'Sylhet': ['Sylhet', 'Moulvibazar', 'Habiganj', 'Sunamganj'],
    'Rangpur': ['Rangpur', 'Dinajpur', 'Kurigram', 'Gaibandha', 'Nilphamari', 'Panchagarh', 'Thakurgaon', 'Lalmonirhat'],
    'Mymensingh': ['Mymensingh', 'Jamalpur', 'Sherpur', 'Netrokona'],
  };

  List<String> _schoolDatabase = [];
  bool _isCustomSchool = false;

  String _authMsgType = '';
  String _authMsgText = '';

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkFirstVisit();

    // 🔥 ম্যাজিক লিসেনার: লিংকে ক্লিক করলে পুরো স্ক্রিন পাসওয়ার্ড রিসেট মোডে চলে যাবে
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          _isResettingPassword = true; // স্ক্রিন চেঞ্জ হবে
          _authMsgType = 'success';
          _authMsgText = 'Set your new secure password below.';
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel(); 
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // --- 🏫 FETCH SCHOOLS ---
  Future<void> _fetchSchoolsByDistrict(String district) async {
    setState(() => _isLoadingSchools = true);
    try {
      final res = await _supabase.from('banbeis_schools').select('school_name').eq('district', district);
      List<String> schools = [];
      for (var row in res as List) {
        String sName = row['school_name']?.toString().trim() ?? "";
        if (sName.isNotEmpty) schools.add(sName);
      }
      if (mounted) {
        setState(() {
          _schoolDatabase = schools..sort();
          _isLoadingSchools = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSchools = false);
    }
  }

  Future<void> _checkFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final hasVisited = prefs.getBool('has_visited_qaave') ?? false; // qaave update
    if (!hasVisited) {
      await prefs.setBool('has_visited_qaave', true);
      setState(() => _isLogin = false); 
    }
  }

  // --- 🔑 FORGOT PASSWORD LINK REQUEST ---
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _authMsgType = 'error';
        _authMsgText = 'Please enter your email first to reset password.';
      });
      return;
    }
    
    setState(() => _loading = true);
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'Qaave://reset-password', // qaave update
      );
      setState(() {
        _authMsgType = 'success';
        _authMsgText = 'Password reset link sent! Check your inbox.';
      });
    } catch (e) {
      setState(() {
        _authMsgType = 'error';
        _authMsgText = 'Error sending reset link. Please try again.';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // --- 🛠️ UPDATE NEW PASSWORD (Full Screen Mode) ---
  Future<void> _handleUpdatePassword() async {
    final newPass = _newPasswordController.text.trim();
    if (newPass.length < 6) {
      setState(() {
        _authMsgType = 'error';
        _authMsgText = 'Password must be at least 6 characters.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _authMsgText = '';
    });
    
    try {
      await _supabase.auth.updateUser(UserAttributes(
        password: newPass,
      ));
      
      setState(() {
        _authMsgType = 'success';
        _authMsgText = "Password saved successfully! Logging in...";
      });

      if (!mounted) return;
      Future.delayed(const Duration(seconds: 1), () {
        Provider.of<ProgressProvider>(context, listen: false).fetchProfileData();
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (route) => false, 
        );
      });

    } on AuthException catch (e) {
      setState(() {
        _authMsgType = 'error';
        _authMsgText = e.message;
      });
    } catch (e) {
      setState(() {
        _authMsgType = 'error';
        _authMsgText = "Something went wrong! Try again.";
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- 🚀 CORE AUTHENTICATION ---
  Future<void> _handleAuthAction() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _authMsgType = 'error';
        _authMsgText = 'Email and Password are required!';
      });
      return;
    }

    if (!_isLogin) {
      if (_nameController.text.isEmpty || 
          _usernameController.text.isEmpty || 
          _selectedSchool.trim().isEmpty || 
          _phoneController.text.isEmpty ||
          _selectedDivision == null || _selectedDivision == 'Select' ||
          _selectedDistrict == null || _selectedDistrict == 'Select' ||
          _selectedClass == null || _selectedClass == 'Select' ||
          _selectedGroup == null || _selectedGroup == 'Select' ||
          _selectedGender == null || _selectedGender == 'Select') {
        setState(() {
          _authMsgType = 'error';
          _authMsgText = 'All fields including Location, Class and Mobile are required!';
        });
        return;
      }
      if (_usernameController.text.length < 3) {
        setState(() {
          _authMsgType = 'error';
          _authMsgText = 'Username must be 3+ characters.';
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _authMsgText = '';
    });
    HapticFeedback.mediumImpact();

    try {
      if (_isLogin) {
        final res = await _supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        
        if (res.session != null) {
          if (!mounted) return;
          Provider.of<ProgressProvider>(context, listen: false).fetchProfileData();
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigation()));
        }
      } else {
        final res = await _supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        
        if (res.user != null) {
          if (_isCustomSchool && _selectedSchool.isNotEmpty) {
            try {
              await _supabase.from('banbeis_schools').insert({
                'division': _selectedDivision,
                'district': _selectedDistrict,
                'school_name': _selectedSchool.trim().toUpperCase(),
              });
            } catch (e) {
              debugPrint("School already exists or error: $e");
            }
          }

          await _supabase.from('profiles').upsert({
            'id': res.user!.id,
            'full_name': _nameController.text.trim(),
            'username': _usernameController.text.trim(),
            'phone': _phoneController.text.trim(), 
            'school_name': _selectedSchool.trim().toUpperCase(),
            'academic_class': _selectedClass,
            'academic_group': _selectedGroup,
            'gender': _selectedGender,
            'division': _selectedDivision,
            'district': _selectedDistrict,
            'school_status': 'approved', 
          });

          if (!mounted) return;
          Provider.of<ProgressProvider>(context, listen: false).fetchProfileData();
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigation()));
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
        _authMsgText = "DB Error: ${error.toString()}";
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), 
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420), 
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40), 
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 40, offset: const Offset(0, 10))
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🎨 Logo and Branding updated to qaave
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/qaave_logo.png', // 👈 তোর লোগোর পাথ
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text("Qaave", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 📝 Dynamic Headers based on Mode
                  Text(
                    _isResettingPassword 
                        ? "Reset Password" 
                        : (_isLogin ? "Welcome back" : "Create Account"),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isResettingPassword 
                        ? "Create a new strong password for your account."
                        : (_isLogin ? "Continue your elite focus journey." : "Setup your professional qaave profile."),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 32),

                  // 🔔 Message Box
                  if (_authMsgText.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _authMsgType == 'error' ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _authMsgType == 'error' ? Colors.red.shade100 : Colors.green.shade100),
                      ),
                      child: Text(
                        _authMsgText,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _authMsgType == 'error' ? Colors.red.shade700 : Colors.green.shade700),
                      ),
                    ),

                  // ---------------------------------------------------------
                  // 🔐 PASSWORD RESET UI (ONLY SHOWS WHEN _isResettingPassword IS TRUE)
                  // ---------------------------------------------------------
                  if (_isResettingPassword) ...[
                    _buildBilingualLabel("NEW PASSWORD", "নতুন পাসওয়ার্ড"),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: !_showPassword,
                      style: const TextStyle(fontSize: 14),
                      decoration: _inputStyle("••••••••", LucideIcons.lock).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword ? LucideIcons.eyeOff : LucideIcons.eye, color: Colors.grey.shade400, size: 20),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 56, 
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleUpdatePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10A37F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _loading 
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text("Save Password", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                SizedBox(width: 8),
                                Icon(LucideIcons.checkCircle, size: 18),
                              ],
                            ),
                      ),
                    ),
                  ] 
                  // ---------------------------------------------------------
                  // 📝 REGULAR LOGIN / SIGNUP UI
                  // ---------------------------------------------------------
                  else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_isLogin) ...[
                          _buildBilingualLabel("FULL NAME", "পুরো নাম"),
                          _buildTextField(_nameController, "Rudro Sarkar", LucideIcons.user),
                          const SizedBox(height: 16),

                          _buildBilingualLabel("USERNAME", "ইউজারনেম"),
                          _buildTextField(_usernameController, "Rudrox", LucideIcons.atSign),
                          const SizedBox(height: 16),
                          
                          _buildBilingualLabel("GENDER", "লিঙ্গ"),
                          _buildDropdown(_selectedGender ?? "Select", _genders, (v) => setState(() => _selectedGender = v!)),
                          const SizedBox(height: 16),

                          _buildBilingualLabel("DIVISION", "বিভাগ"),
                          _buildDropdown(_selectedDivision ?? "Select", ['Select', ..._divisions], (v) {
                            if (v != 'Select') {
                              setState(() {
                                _selectedDivision = v;
                                _selectedDistrict = null;
                              });
                            }
                          }),
                          const SizedBox(height: 16),

                          _buildBilingualLabel("DISTRICT", "জেলা"),
                          _buildDropdown(
                            _selectedDistrict ?? "Select", 
                            ['Select', ...(_selectedDivision != null && _selectedDivision != 'Select' ? _districtsMap[_selectedDivision]! : [])], 
                            (v) {
                              if (v != 'Select') {
                                setState(() {
                                  _selectedDistrict = v;
                                  _schoolDatabase.clear();
                                  _selectedSchool = "";
                                });
                                _fetchSchoolsByDistrict(v!); 
                              }
                            }
                          ),
                          const SizedBox(height: 16),

                          _buildBilingualLabel("CLASS", "ক্লাস"),
                          _buildDropdown(_selectedClass ?? "Select", _classes, (v) => setState(() => _selectedClass = v!)),
                          const SizedBox(height: 16),

                          _buildBilingualLabel("GROUP", "বিভাগ"),
                          _buildDropdown(_selectedGroup ?? "Select", _groups, (v) => setState(() => _selectedGroup = v!)),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildBilingualLabel("SCHOOL / COLLEGE", "স্কুল বা কলেজ"),
                              if (_isLoadingSchools) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10A37F))),
                            ],
                          ),
                          Autocomplete<String>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (_selectedDistrict == null || _selectedDistrict == 'Select') return ['__SELECT_DISTRICT_FIRST__'];
                              if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                              
                              final query = textEditingValue.text.toLowerCase();
                              final matches = _schoolDatabase.where((s) => s.toLowerCase().contains(query)).toList();
                              
                              if (matches.isEmpty) return ['__NOT_FOUND__'];
                              return matches;
                            },
                            onSelected: (String selection) {
                              FocusManager.instance.primaryFocus?.unfocus();
                              if (selection == '__SELECT_DISTRICT_FIRST__' || selection == '__NOT_FOUND__') return;
                              
                              setState(() {
                                _selectedSchool = selection;
                                _isCustomSchool = false; 
                              });
                            },
                            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                onChanged: (val) {
                                  _searchedSchoolText = val;
                                  _selectedSchool = val; 
                                  _isCustomSchool = true; 
                                },
                                textCapitalization: TextCapitalization.words,
                                style: const TextStyle(fontSize: 14),
                                decoration: _inputStyle("Search your school...", LucideIcons.building),
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 8.0, shadowColor: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: MediaQuery.of(context).size.width - 48, constraints: const BoxConstraints(maxHeight: 220),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                                    child: ListView.separated(
                                      padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length,
                                      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade50),
                                      itemBuilder: (context, index) {
                                        final String option = options.elementAt(index);
                                        
                                        if (option == '__SELECT_DISTRICT_FIRST__') {
                                          return const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Text("Please select a District first.", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                                          );
                                        }

                                        if (option == '__NOT_FOUND__') {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            child: Row(
                                              children: [
                                                const Icon(LucideIcons.alertCircle, color: Colors.orange, size: 16),
                                                const SizedBox(width: 8),
                                                const Expanded(child: Text("Not found", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600))),
                                                ElevatedButton.icon(
                                                  onPressed: () {
                                                    onSelected(_searchedSchoolText);
                                                    setState(() {
                                                      _isCustomSchool = true;
                                                      _selectedSchool = _searchedSchoolText;
                                                    }); 
                                                  },
                                                  icon: const Icon(LucideIcons.plus, size: 12),
                                                  label: const Text("Add Custom", style: TextStyle(fontSize: 11)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF10A37F),
                                                    foregroundColor: Colors.white,
                                                    minimumSize: Size.zero,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                )
                                              ],
                                            ),
                                          );
                                        }

                                        return InkWell(
                                          onTap: () => onSelected(option),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                            child: Row(children: [const Icon(LucideIcons.mapPin, size: 14, color: Color(0xFF10A37F)), const SizedBox(width: 12), Expanded(child: Text(option, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))))]),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          _buildBilingualLabel("MOBILE NUMBER", "মোবাইল নম্বর"),
                          _buildTextField(_phoneController, "017XXXXXXXX", LucideIcons.phone, inputType: TextInputType.phone),
                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
                          const SizedBox(height: 24),
                        ],

                        _buildBilingualLabel("EMAIL", "ইমেইল"),
                        _buildTextField(_emailController, "email@example.com", LucideIcons.mail, inputType: TextInputType.emailAddress),
                        const SizedBox(height: 16),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildBilingualLabel("PASSWORD", "পাসওয়ার্ড"),
                            if (_isLogin)
                              GestureDetector(
                                onTap: _handleForgotPassword,
                                child: const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Text("Forgot Password?", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10A37F))),
                                ),
                              )
                          ],
                        ),
                        TextField(
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          style: const TextStyle(fontSize: 14),
                          decoration: _inputStyle("••••••••", LucideIcons.lock).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_showPassword ? LucideIcons.eyeOff : LucideIcons.eye, color: Colors.grey.shade400, size: 20),
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 56, 
                          child: ElevatedButton(
                            onPressed: _loading ? null : _handleAuthAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10A37F),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: _loading 
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(_isLogin ? "Secure Login" : "Create Profile", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                    const SizedBox(width: 8),
                                    const Icon(LucideIcons.arrowRight, size: 18),
                                  ],
                                ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_isLogin ? "Don't have an account?" : "Already have an account?", style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            TextButton(
                              onPressed: () => setState(() { _isLogin = !_isLogin; _authMsgText = ''; }),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                              child: Text(_isLogin ? "Sign up" : "Log in", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF10A37F))),
                            )
                          ],
                        )
                      ],
                    )
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- UI Helpers ---
  Widget _buildBilingualLabel(String en, String bn) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: RichText(
        text: TextSpan(
          text: "$en ",
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF334155), letterSpacing: 0.5),
          children: [
            TextSpan(text: "• $bn", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
          ]
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon, {TextInputType inputType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      textCapitalization: inputType == TextInputType.text ? TextCapitalization.words : TextCapitalization.none,
      style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
      decoration: _inputStyle(hint, icon),
    );
  }

  InputDecoration _inputStyle(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF10A37F)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), 
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.transparent)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF10A37F), width: 1.5)),
    );
  }

  Widget _buildDropdown(String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      dropdownColor: Colors.white,
      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
      icon: const Icon(LucideIcons.chevronDown, size: 16, color: Color(0xFF94A3B8)),
      decoration: _inputStyle("", LucideIcons.circleDot).copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))))).toList(),
      onChanged: onChanged,
    );
  }
}