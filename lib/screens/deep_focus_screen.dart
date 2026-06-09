import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/timer_provider.dart';

class DeepFocusScreen extends StatefulWidget {
  final String subjectName;
  final String chapterName;
  final DateTime startTime; 
  final int initialSeconds; 

  const DeepFocusScreen({
    super.key,
    required this.subjectName,
    required this.chapterName,
    required this.startTime,
    this.initialSeconds = 0,
  });

  @override
  State<DeepFocusScreen> createState() => _DeepFocusScreenState();
}

class _DeepFocusScreenState extends State<DeepFocusScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  RealtimeChannel? _liveChannel;

  @override
  void initState() {
    super.initState();
    
    _setupPresence(); 

    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine));

    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
  }

  Future<void> _setupPresence() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;

    try {
      final profile = await supabase.from('profiles').select('full_name, avatar_seed').eq('id', userId).single();

      _liveChannel = supabase.channel('live_study_room');
      _liveChannel!.subscribe((status, [error]) async {
        if (status == 'SUBSCRIBED') {
          await _liveChannel!.track({
            'user_id': userId,
            'full_name': profile['full_name'] ?? 'Scholar',
            'avatar_seed': profile['avatar_seed'] ?? 'Felix',
            'subject': widget.subjectName,
            'chapter': widget.chapterName,
          });
        }
      });
    } catch (e) {
      debugPrint("Presence Setup Error: $e");
    }
  }

  void _togglePause() {
    final timerProvider = Provider.of<TimerProvider>(context, listen: false);
    
    if (timerProvider.isRunning) {
      timerProvider.stopTimer(); 
      _pulseController.stop();
      _fadeController.stop();
      _liveChannel?.untrack(); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Please resume from the Study Table.", style: TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.orangeAccent,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context); 
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _liveChannel?.unsubscribe(); 
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    if (hours > 0) return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildResponsiveLayout(bool isPaused, TimerProvider timerProvider, BoxConstraints constraints) {
    final bool isLandscape = constraints.maxHeight < 500;
    
    // Dynamic text and button sizing based on orientation
    final double titleSize = isLandscape ? 20.0 : 28.0;
    final double chapterSize = isLandscape ? 12.0 : 14.0;
    final double buttonPadding = isLandscape ? 12.0 : 20.0;
    final double buttonIconSize = isLandscape ? 24.0 : 32.0;

    // Calculate maximum safe circle size so it never overflows
    final double availableHeightForCircle = constraints.maxHeight - (titleSize + chapterSize + 120); 
    final double circleSize = max(100.0, min(availableHeightForCircle, constraints.maxWidth * 0.65));
    final double timerFontSize = circleSize * 0.32;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.subjectName.toUpperCase(), 
            style: TextStyle(color: Colors.white, fontSize: titleSize, fontWeight: FontWeight.w900, letterSpacing: 4.0), 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 8),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Text(
              widget.chapterName, 
              textAlign: TextAlign.center, 
              style: TextStyle(color: const Color(0xFF10A37F), fontSize: chapterSize, fontWeight: FontWeight.w600, letterSpacing: 1.5)
            ),
          ),
          
          SizedBox(height: isLandscape ? 20 : 80),
          
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: circleSize, height: circleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, 
                        boxShadow: [
                          BoxShadow(
                            color: isPaused ? Colors.transparent : const Color(0xFF10A37F).withOpacity(0.08), 
                            blurRadius: circleSize * 0.3, 
                            spreadRadius: circleSize * 0.08
                          )
                        ]
                      ),
                    ),
                  );
                },
              ),
              Text(
                _formatTime(timerProvider.currentTaskSeconds), 
                style: TextStyle(
                  color: isPaused ? Colors.white38 : Colors.white, 
                  fontSize: timerFontSize, 
                  fontWeight: FontWeight.w200, 
                  fontFeatures: const [FontFeature.tabularFigures()]
                )
              ),
            ],
          ),
          
          SizedBox(height: isLandscape ? 20 : 60),
          
          GestureDetector(
            onTap: _togglePause,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.all(buttonPadding),
              decoration: BoxDecoration(
                color: isPaused ? Colors.white10 : const Color(0xFF10A37F).withOpacity(0.15), 
                shape: BoxShape.circle, 
                border: Border.all(color: isPaused ? Colors.white24 : const Color(0xFF10A37F).withOpacity(0.5), width: 1.5)
              ),
              child: Icon(
                isPaused ? LucideIcons.play : LucideIcons.pause, 
                color: isPaused ? Colors.white54 : const Color(0xFF10A37F), 
                size: buttonIconSize
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(LucideIcons.minimize2, color: Colors.white38, size: 24),
                  onPressed: () => Navigator.of(context).pop(), 
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Consumer<TimerProvider>(
                  builder: (context, timerProvider, child) {
                    final isPaused = !timerProvider.isRunning;
                    
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildResponsiveLayout(isPaused, timerProvider, constraints);
                      },
                    );
                  }
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}