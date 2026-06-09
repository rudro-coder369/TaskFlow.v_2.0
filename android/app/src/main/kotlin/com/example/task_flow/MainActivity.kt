package com.example.task_flow

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // 🔥 এই চ্যানেল নামটা Flutter-এর MethodChannel এর সাথে হুবহু মিলতে হবে
    private val CHANNEL = "com.example.task_flow/blocker"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // ১. Accessibility Permission চেক করা
                "checkAccessibilityPermission" -> {
                    result.success(isAccessibilityEnabled())
                }
                
                // ২. Accessibility Settings পেজ ওপেন করা
                "requestAccessibilityPermission" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                
                // ৩. Overlay (Draw over other apps) Permission চেক করা
                "checkOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true) // পুরানো অ্যান্ড্রয়েডে এই পারমিশন লাগে না
                    }
                }
                
                // ৪. Overlay Settings পেজ ওপেন করা
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                        startActivity(intent)
                    }
                    result.success(null)
                }
                
                // ৫. ব্লকার চালু করা (হিটলিস্ট সেভ করে)
                "startBlocking" -> {
                    val packages = call.argument<List<String>>("packages") ?: listOf()
                    val prefs = getSharedPreferences("TaskFlowBlockerPrefs", Context.MODE_PRIVATE)
                    prefs.edit().apply {
                        putBoolean("isBlockingActive", true)
                        putString("blockedPackages", packages.joinToString(","))
                        apply()
                    }
                    result.success(true)
                }
                
                // ৬. ব্লকার বন্ধ করা
                "stopBlocking" -> {
                    val prefs = getSharedPreferences("TaskFlowBlockerPrefs", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("isBlockingActive", false).apply()
                    result.success(true)
                }
                
                else -> result.notImplemented()
            }
        }
    }

    // Accessibility Service অন করা আছে কিনা চেক করার ইন্টারনাল লজিক
    private fun isAccessibilityEnabled(): Boolean {
        var accessibilityEnabled = 0
        try {
            accessibilityEnabled = Settings.Secure.getInt(
                applicationContext.contentResolver,
                Settings.Secure.ACCESSIBILITY_ENABLED
            )
        } catch (e: Settings.SettingNotFoundException) {
            // Error handling
        }

        if (accessibilityEnabled == 1) {
            val settingValue = Settings.Secure.getString(
                applicationContext.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
            if (settingValue != null) {
                return settingValue.contains(packageName)
            }
        }
        return false
    }
}