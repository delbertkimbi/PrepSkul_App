
package com.prepskul.prepskul

import android.Manifest
import android.app.PictureInPictureParams
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Rational
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val NOTIFICATIONS_CHANNEL = "com.prepskul.prepskul/notifications"
    private val PERMISSIONS_CHANNEL = "com.prepskul.prepskul/permissions"
    private val CALL_PIP_CHANNEL = "com.prepskul.prepskul/call_pip"

    private val REQ_CODE_CAMERA_MIC = 31001
    private var pendingCameraMicResult: MethodChannel.Result? = null
    private var callPipChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Enable edge-to-edge display for Android 15+ (API 35+)
        // This addresses the Play Console recommendation about edge-to-edge compatibility
        // Apps targeting SDK 35+ should handle insets to ensure correct display on Android 15+
        if (Build.VERSION.SDK_INT >= 35) { // Android 15 (API 35)
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATIONS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationSettings" -> {
                        try {
                            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                }
                            } else {
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.fromParts("package", packageName, null)
                                }
                            }
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_SETTINGS_FAILED", e.message, null)
                        }
                    }
                    "openAppSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                            }
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_APP_SETTINGS_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSIONS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCameraMicStatus" -> {
                        result.success(getCameraMicStatus())
                    }
                    "requestCameraMic" -> {
                        if (pendingCameraMicResult != null) {
                            result.error("REQUEST_IN_PROGRESS", "A permission request is already in progress", null)
                            return@setMethodCallHandler
                        }

                        pendingCameraMicResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO),
                            REQ_CODE_CAMERA_MIC
                        )
                    }
                    "openAppSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                            }
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_APP_SETTINGS_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        callPipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_PIP_CHANNEL)
        callPipChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(isCallPipSupported())
                "enterPip" -> {
                    if (!isCallPipSupported()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val params = PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(16, 9))
                                .build()
                            val entered = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                enterPictureInPictureMode(params)
                            } else {
                                @Suppress("DEPRECATION")
                                enterPictureInPictureMode(params)
                                true
                            }
                            result.success(entered)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("PIP_ENTER_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isCallPipSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        callPipChannel?.invokeMethod(
            "pipModeChanged",
            mapOf("active" to isInPictureInPictureMode)
        )
    }

    private fun permissionState(permission: String): String {
        val granted = ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
        if (granted) return "granted"

        // If user previously denied with "Don't ask again", rationale will be false.
        val canAskAgain = ActivityCompat.shouldShowRequestPermissionRationale(this, permission)
        return if (!canAskAgain) "deniedPermanently" else "denied"
    }

    private fun getCameraMicStatus(): Map<String, String> {
        return mapOf(
            "camera" to permissionState(Manifest.permission.CAMERA),
            "microphone" to permissionState(Manifest.permission.RECORD_AUDIO)
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == REQ_CODE_CAMERA_MIC) {
            pendingCameraMicResult?.success(getCameraMicStatus())
            pendingCameraMicResult = null
        }
    }
}
