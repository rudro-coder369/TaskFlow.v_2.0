import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HealthHabitsWidget extends StatelessWidget {
  final Map<String, int> habits;
  final bool sleepChecked;
  final bool exerciseChecked;
  final Function(String, dynamic) onUpdateHabit;

  const HealthHabitsWidget({super.key, required this.habits, required this.sleepChecked, required this.exerciseChecked, required this.onUpdateHabit});

  Widget _buildHabitTracker(String label, int current, int max, IconData icon, Color color, Function(int) onUpdate) {
    return Container(
      padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.lightBlue.shade50)),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]), Text("$current/$max", style: const TextStyle(fontSize: 10, color: Colors.grey))]),
          const SizedBox(height: 12),
          Wrap(spacing: 4, runSpacing: 4, children: List.generate(max, (i) => GestureDetector(onTap: () => onUpdate(current + 1), child: Container(width: max > 5 ? 20 : 32, height: max > 5 ? 20 : 32, decoration: BoxDecoration(color: i < current ? color : Colors.grey.shade50, shape: BoxShape.circle, border: Border.all(color: i < current ? color : Colors.grey.shade200)), child: i < current ? Icon(Icons.check, size: max > 5 ? 10 : 16, color: Colors.white) : null))))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 24), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.lightBlue.shade50.withOpacity(0.4), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.lightBlue.shade100.withOpacity(0.6)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Daily Health & Habits", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildHabitTracker("Water", habits['water']!, 12, LucideIcons.droplets, Colors.lightBlue, (v) => onUpdateHabit('water', v))),
              const SizedBox(width: 12),
              Expanded(child: _buildHabitTracker("Meals", habits['meal']!, 4, LucideIcons.utensils, Colors.orange, (v) => onUpdateHabit('meal', v))),
            ],
          ),
          const SizedBox(height: 12),
          _buildHabitTracker("Prayers", habits['prayer']!, 5, LucideIcons.moon, Colors.indigo, (v) => onUpdateHabit('prayer', v)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.lightBlue.shade50)),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => onUpdateHabit('sleep', null),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [const Icon(LucideIcons.moon, size: 16, color: Colors.purple), const SizedBox(width: 8), Text("Get 7+ Hours Sleep", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: sleepChecked ? Colors.grey : Colors.black87, decoration: sleepChecked ? TextDecoration.lineThrough : null))]), Container(width: 24, height: 24, decoration: BoxDecoration(color: sleepChecked ? Colors.green : Colors.transparent, border: Border.all(color: sleepChecked ? Colors.green : Colors.grey.shade300), borderRadius: BorderRadius.circular(6)), child: sleepChecked ? const Icon(Icons.check, color: Colors.white, size: 16) : null)]),
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                GestureDetector(
                  onTap: () => onUpdateHabit('workout', null),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [const Icon(LucideIcons.activity, size: 16, color: Colors.red), const SizedBox(width: 8), Text("Exercise (30 Mins)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: exerciseChecked ? Colors.grey : Colors.black87, decoration: exerciseChecked ? TextDecoration.lineThrough : null))]), Container(width: 24, height: 24, decoration: BoxDecoration(color: exerciseChecked ? Colors.green : Colors.transparent, border: Border.all(color: exerciseChecked ? Colors.green : Colors.grey.shade300), borderRadius: BorderRadius.circular(6)), child: exerciseChecked ? const Icon(Icons.check, color: Colors.white, size: 16) : null)]),
                ),
              ],
            ),
          )
        ],
      )
    );
  }
}