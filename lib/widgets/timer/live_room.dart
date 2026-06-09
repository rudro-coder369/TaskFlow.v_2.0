import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LiveRoomWidget extends StatelessWidget {
  final List<Map<String, dynamic>> onlineUsers;
  
  const LiveRoomWidget({super.key, required this.onlineUsers});

  String _formatName(String? name) {
    if (name == null || name.trim().isEmpty) return "Scholar";
    return name.trim().split(' ')[0][0].toUpperCase() + name.trim().split(' ')[0].substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 24), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.lightBlue.shade50.withOpacity(0.4), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.lightBlue.shade100.withOpacity(0.6)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 16, runSpacing: 12,
            children: [
              const Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.users, color: Colors.lightBlue, size: 20), SizedBox(width: 8), Text("Live Study Room", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))]),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade200)), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)), const SizedBox(width: 6), Text("${onlineUsers.length} ACTIVE", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 1))]))
            ],
          ),
          const SizedBox(height: 16),
          onlineUsers.isEmpty 
            ? Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid)), child: const Center(child: Text("It's quiet here. Start a task to join.", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500))))
            : Wrap(
                spacing: 10, runSpacing: 10,
                children: onlineUsers.map((u) => Container(
                  width: (MediaQuery.of(context).size.width - 80) / 2, 
                  padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.lightBlue.shade50), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
                  child: Row(children: [
                    CircleAvatar(radius: 16, backgroundColor: const Color(0xFF10A37F), child: Text(_formatName(u['username'])[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_formatName(u['username']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis), Text(u['active_task'] ?? "Focusing", style: const TextStyle(fontSize: 9, color: Color(0xFF10A37F), fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)])),
                  ]),
                )).toList(),
              )
        ],
      )
    );
  }
}