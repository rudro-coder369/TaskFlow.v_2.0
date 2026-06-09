import 'package:flutter/material.dart';
import 'global_flow_zone.dart';
import 'squad_zone.dart';

class LiveRoomScreen extends StatefulWidget {
  final String? myCurrentChapter;
  final String? myCurrentSubject; 
  final String? mySchool;         

  const LiveRoomScreen({
    super.key, 
    this.myCurrentChapter, 
    this.myCurrentSubject, 
    this.mySchool
  });

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // 🔥 SafeArea অ্যাড করা হলো যাতে স্ট্যাটাস বারের সাথে ক্ল্যাশ না করে, কিন্তু কোনো এক্সট্রা গ্যাপও না নেয়
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 🌟 TabBar Container (০ পিক্সেল গ্যাপ, একদম টাইট)
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF10A37F),
                indicatorWeight: 3,
                labelColor: const Color(0xFF10A37F),
                unselectedLabelColor: const Color(0xFF94A3B8),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                // Tab এর হাইট ৪৪ পিক্সেল করে দেওয়া হলো যাতে স্লিক লাগে
                tabs: const [
                  Tab(height: 44, text: "GROUP STUDY"), // ১ম ট্যাব
                  Tab(height: 44, text: "GLOBAL ROOM"), // ২য় ট্যাব
                ],
              ),
            ),
            
            // 🚀 Main Content Area
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ১ম স্ক্রিন: Group Study
                  const SquadZone(), 
                  
                  // ২য় স্ক্রিন: Global Room
                  GlobalFlowZone(    
                    myCurrentChapter: widget.myCurrentChapter,
                    myCurrentSubject: widget.myCurrentSubject,
                    mySchool: widget.mySchool,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}