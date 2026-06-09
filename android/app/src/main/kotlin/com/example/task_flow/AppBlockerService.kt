package com.example.task_flow // 🔥 প্যাকেজ নেম ঠিক করে দিয়েছি

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent

class AppBlockerService : AccessibilityService() {

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var isOverlayShowing = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.packageName == null) return

        val currentPackage = event.packageName.toString()
        
        // SharedPreferences থেকে ফ্লাটারের পাঠানো ডাটা রিড করা
        val prefs = getSharedPreferences("TaskFlowBlockerPrefs", Context.MODE_PRIVATE)
        val isBlockingActive = prefs.getBoolean("isBlockingActive", false)
        val blockedAppsString = prefs.getString("blockedPackages", "") ?: ""
        val blockedPackages = blockedAppsString.split(",").filter { it.isNotEmpty() }

        if (isBlockingActive && blockedPackages.contains(currentPackage)) {
            showOverlay()
            // ইউজারকে হোম স্ক্রিনে পাঠিয়ে দেওয়া যাতে ব্লকড অ্যাপ ব্যাকগ্রাউন্ডে চলে যায়
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(homeIntent)
        } else {
            // যদি অন্য অ্যাপে থাকে, ওভারলে সরিয়ে নেওয়া (প্যাকেজ নেম ঠিক করা হয়েছে)
            if (currentPackage != "com.example.task_flow") { 
               hideOverlay()
            }
        }
    }

    private fun showOverlay() {
        if (isOverlayShowing) return

        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )

        val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        // এখন আর 'R' এ এরর দেবে না!
        overlayView = inflater.inflate(R.layout.blocker_overlay, null)

        windowManager?.addView(overlayView, layoutParams)
        isOverlayShowing = true
    }

    private fun hideOverlay() {
        if (isOverlayShowing && overlayView != null) {
            windowManager?.removeView(overlayView)
            overlayView = null
            isOverlayShowing = false
        }
    }

    override fun onInterrupt() {}
}