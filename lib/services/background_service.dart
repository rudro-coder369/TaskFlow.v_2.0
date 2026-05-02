import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🔥 ব্যাকগ্রাউন্ড থেকে পজ বাটন চাপলে এই ফাংশন কাজ করবে
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  final service = FlutterBackgroundService();
  if (response.actionId == 'pause_task') {
    service.invoke('stopService'); // ব্যাকগ্রাউন্ডকে থামার নির্দেশ
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'timer_foreground',
    'Timer Service',
    description: 'Running timer in background',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    ),
    onDidReceiveNotificationResponse: (response) {
      final srv = FlutterBackgroundService();
      if (response.actionId == 'pause_task') {
        srv.invoke('stopService'); // ব্যাকগ্রাউন্ডকে থামার নির্দেশ
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'timer_foreground',
      initialNotificationTitle: 'TaskFlow Focus',
      initialNotificationContent: 'Initializing timer...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // 🔥 মাস্টার লজিক: সার্ভিস স্টপ হলে যা যা ঘটবে
  service.on('stopService').listen((event) async {
    await flutterLocalNotificationsPlugin.cancel(888); // ১. নোটিফিকেশন ক্লিয়ার
    service.invoke('pause_ui'); // ২. মেইন অ্যাপকে সিগন্যাল পাঠানো
    
    // ৩. সেফটি: অ্যাপ কিল থাকলেও যেন টাইমার পজ হয়
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_task_id');
    await prefs.remove('active_task_start');

    service.stopSelf(); // ৪. সার্ভিস স্টপ
  });

  // UI থেকে ডেটা রিসিভ করবে
  service.on('updateTimer').listen((event) {
    if (event != null && event.containsKey('seconds') && event.containsKey('taskName')) {
      int seconds = event['seconds'];
      String taskName = event['taskName'];
      String? subjectName = event['subjectName'];
      
      int h = (seconds / 3600).floor();
      int m = ((seconds % 3600) / 60).floor();
      int s = seconds % 60;
      
      String timeStr = "";
      if (h > 0) {
        timeStr = "${h}h ${m}m ${s}s";
      } else {
        timeStr = "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
      }

      String displayTitle = (subjectName != null && subjectName.isNotEmpty && subjectName != 'null')
          ? '$subjectName: $taskName'
          : taskName;

      if (service is AndroidServiceInstance) {
        flutterLocalNotificationsPlugin.show(
          888,
          displayTitle,
          'Focus Time: $timeStr',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'timer_foreground',
              'Timer Service',
              icon: '@mipmap/launcher_icon',
              ongoing: true,
              onlyAlertOnce: true,
              actions: <AndroidNotificationAction>[
                AndroidNotificationAction(
                  'pause_task', 
                  'Pause', 
                  cancelNotification: true, 
                ),
              ],
            ),
          ),
        );
      }
    }
  });
}