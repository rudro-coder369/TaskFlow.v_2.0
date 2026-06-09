import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class NativeBlockerChannel {
  // 🔥 এই নামটা অ্যান্ড্রয়েড সাইডের (MainActivity.kt) ফাইলের সাথে হুবহু মিলতে হবে
  static const MethodChannel _channel = MethodChannel('com.example.task_flow/blocker');

  // ==========================================
  // 🛡️ 1. PERMISSION HANDLING (ACCESSIBILITY)
  // ==========================================
  
  /// চেক করবে ইউজারের ফোনে Accessibility Service অন করা আছে কিনা
  static Future<bool> isAccessibilityPermissionGranted() async {
    try {
      final bool result = await _channel.invokeMethod('checkAccessibilityPermission');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to check accessibility: '${e.message}'.");
      return false;
    }
  }

  /// ইউজারকে সরাসরি ফোনের Accessibility Settings পেজে নিয়ে যাবে
  static Future<void> requestAccessibilityPermission() async {
    try {
      await _channel.invokeMethod('requestAccessibilityPermission');
    } on PlatformException catch (e) {
      debugPrint("Failed to request accessibility: '${e.message}'.");
    }
  }

  // ==========================================
  // 🔲 2. PERMISSION HANDLING (OVERLAY / DISPLAY OVER OTHER APPS)
  // ==========================================
  
  /// চেক করবে আমাদের অ্যাপ অন্য অ্যাপের ওপর ওয়ার্নিং স্ক্রিন ভাসাতে পারবে কিনা
  static Future<bool> isOverlayPermissionGranted() async {
    try {
      final bool result = await _channel.invokeMethod('checkOverlayPermission');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to check overlay permission: '${e.message}'.");
      return false;
    }
  }

  /// ইউজারকে সরাসরি ফোনের "Display over other apps" সেটিংস পেজে নিয়ে যাবে
  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on PlatformException catch (e) {
      debugPrint("Failed to request overlay permission: '${e.message}'.");
    }
  }

  // ==========================================
  // 🚀 3. THE MAIN ENGINE (START / STOP)
  // ==========================================
  
  /// হিটলিস্ট (packages) গুলো নেটিভ অ্যান্ড্রয়েডের কাছে পাঠাবে ব্লকিং শুরু করার জন্য
  static Future<bool> startBlocking(List<String> packagesToBlock) async {
    try {
      // Kotlin-এর কাছে Map হিসেবে ডাটা পাঠাচ্ছি
      final bool result = await _channel.invokeMethod('startBlocking', {
        'packages': packagesToBlock,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("Failed to start blocking: '${e.message}'.");
      return false;
    }
  }

  /// ফোকাস মোড অফ করে দেবে
  static Future<void> stopBlocking() async {
    try {
      await _channel.invokeMethod('stopBlocking');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop blocking: '${e.message}'.");
    }
  } 
}