package online.wynos.food.push

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.ActivityNotFoundException
import android.provider.Settings
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessaging
import online.wynos.food.BuildConfig

/**
 * Explicitly opt-in to the FCM *device test* only; no order push registration
 * or server send API exists. Don't imply that account notifications are enabled.
 */
@Composable
fun ZokyFcmDevicePreviewCard() {
    if (!BuildConfig.FCM_DEVICE_PREVIEW_ALLOWED) return
    val context = LocalContext.current
    var enabled by remember { mutableStateOf(ZokyPushConsent.enabled(context)) }
    var token by remember { mutableStateOf<String?>(null) }
    var working by remember { mutableStateOf(false) }
    var fcmCallbacks by remember { mutableStateOf(ZokyFcmPreviewReceipts.count(context)) }
    var displayStatus by remember { mutableStateOf(ZokyFcmPreviewReceipts.displayStatus(context)) }
    var notificationStatus by remember { mutableStateOf(ZokyFcmPreviewNotificationChannel.status(context)) }
    var status by remember { mutableStateOf(
        if (enabled) "เปิดรับข้อความทดสอบจาก Firebase บนอุปกรณ์นี้แล้ว"
        else "ยังไม่ได้เปิดการทดสอบ Firebase บนอุปกรณ์"
    ) }
    LaunchedEffect(enabled) {
        // Keep the device-only channel present after Activity/process recreation.
        // This performs no token request and no network operation.
        if (enabled) {
            ZokyFcmPreviewNotificationChannel.ensure(context)
            notificationStatus = ZokyFcmPreviewNotificationChannel.status(context)
            displayStatus = ZokyFcmPreviewReceipts.displayStatus(context)
        }
    }

    // A token is acquired only after the user taps, and remains local to the device.
    val activate: () -> Unit = {
        working = true
        status = "กำลังเชื่อมต่อ Firebase…"
        val messaging = FirebaseMessaging.getInstance()
        messaging.isAutoInitEnabled = true
        messaging.token.addOnCompleteListener { task ->
            working = false
            val value = if (task.isSuccessful) task.result else null
            if (!value.isNullOrBlank()) {
                val newlyOptedIn = !ZokyPushConsent.enabled(context)
                enabled = true
                token = value
                if (newlyOptedIn) ZokyFcmPreviewReceipts.clear(context)
                ZokyPushConsent.setEnabled(context, true)
                if (newlyOptedIn) {
                    fcmCallbacks = 0
                    displayStatus = ZokyFcmPreviewReceipts.displayStatus(context)
                }
                // The Firebase SDK must find the channel before a notification
                // message arrives while the app is backgrounded.
                ZokyFcmPreviewNotificationChannel.ensure(context)
                notificationStatus = ZokyFcmPreviewNotificationChannel.status(context)
                status = "เชื่อม Firebase สำหรับทดสอบอุปกรณ์แล้ว (ยังไม่เชื่อม Push ออเดอร์จริง)"
            } else {
                ZokyPushConsent.setEnabled(context, false)
                enabled = false
                messaging.isAutoInitEnabled = false
                status = "รับ Token ไม่สำเร็จ โปรดตรวจสอบ Google Play services และอินเทอร์เน็ต"
            }
        }
    }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) activate()
        else status = "ยังไม่ได้อนุญาตให้แสดงการแจ้งเตือนบนเครื่อง"
    }
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 9.dp)
            .background(Color(0xFFFFF0F4), RoundedCornerShape(14.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(9.dp),
    ) {
        Text("Firebase · การแจ้งเตือนทดสอบ", color = Color(0xFF24212B),
            fontWeight = FontWeight.Bold, fontSize = 14.sp)
        Text(status, color = Color(0xFF66636C), fontSize = 12.sp)
        Text("ใช้สำหรับตรวจสอบ Firebase Cloud Messaging เท่านั้น ยังไม่มีระบบ Push ของออเดอร์จริง",
            color = Color(0xFF66636C), fontSize = 11.sp)
        Text("Firebase Console: ใช้เฉพาะ Send test message → Test สำหรับเครื่องนี้ ห้ามกด Review หรือ Publish",
            color = Color(0xFFD91F4E), fontWeight = FontWeight.Medium, fontSize = 11.sp)

        if (!enabled) {
            Button(
                enabled = !working,
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFD91F4E)),
                onClick = {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        ContextCompat.checkSelfPermission(
                            context, Manifest.permission.POST_NOTIFICATIONS
                        ) != PackageManager.PERMISSION_GRANTED
                    ) {
                        permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                    } else activate()
                },
            ) { Text(if (working) "กำลังเชื่อม…" else "เปิดรับข้อความทดสอบ") }
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(
                    onClick = {
                        working = true
                        // Permission to stop showing notifications is immediate.
                        ZokyPushConsent.setEnabled(context, false)
                        enabled = false
                        token = null
                        notificationStatus = ZokyFcmPreviewNotificationChannel.status(context)
                        val messaging = FirebaseMessaging.getInstance()
                        messaging.isAutoInitEnabled = false
                        messaging.deleteToken().addOnCompleteListener { result ->
                            working = false
                            status = if (result.isSuccessful) {
                                "ปิดรับข้อความทดสอบและลบ Token บนอุปกรณ์แล้ว"
                            } else {
                                // App-side preview is off, but SDK delivery may still persist
                                // until the token deletion is confirmed. Do not claim success.
                                "ปิดการแสดงข้อความทดสอบในแอปแล้ว แต่ยังลบ Token ไม่สำเร็จ โปรดเชื่อมต่ออินเทอร์เน็ตแล้วลองใหม่"
                            }
                        }
                    },
                ) { Text("ปิดการทดสอบ") }
                if (token == null) {
                    // Local Compose state is lost after process recreation; allow the
                    // tester to recover a token without toggling consent off and on.
                    OutlinedButton(
                        enabled = !working,
                        onClick = {
                            if (Build.VERSION.SDK_INT >= 33 &&
                                ContextCompat.checkSelfPermission(
                                    context, Manifest.permission.POST_NOTIFICATIONS
                                ) != PackageManager.PERMISSION_GRANTED
                            ) {
                                permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                            } else activate()
                        },
                    ) { Text("รับ Token ทดสอบ") }
                }
                if (token != null) {
                    OutlinedButton(onClick = {
                        // Manual test only; never send tokens to the app backend,
                        // analytics or logs. Clipboard access is user-initiated.
                        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE)
                            as ClipboardManager
                        clipboard.setPrimaryClip(
                            ClipData.newPlainText("Zoky FCM Test Token", token!!)
                        )
                        status = "คัดลอก Token ทดสอบแล้ว เก็บไว้เป็นข้อมูลส่วนตัว"
                    }) { Text("คัดลอก Token ทดสอบ") }
                }
            }
            // Keep this diagnostic on a separate line on narrow phones.
            OutlinedButton(
                enabled = !working,
                onClick = { status = ZokyLocalNotificationQa.post(context) },
            ) { Text("ทดสอบแจ้งเตือนในเครื่อง") }
            Text(
                "การทดสอบนี้ไม่ผ่าน Firebase หากขึ้นใน Android แต่ Push ไม่ขึ้น ให้ตรวจเครือข่ายและ FCM ต่อ",
                color = Color(0xFF66636C), fontSize = 11.sp,
            )
            Text(
                "FCM ที่ Zoky รับขณะเปิดแอป: ${fcmCallbacks} ข้อความ",
                color = Color(0xFF24212B), fontWeight = FontWeight.SemiBold, fontSize = 12.sp,
            )
            Text(
                "การแสดงแจ้งเตือนจาก FCM ขณะเปิดแอป: ${displayStatus}",
                color = Color(0xFF66636C), fontSize = 11.sp,
            )
            Text(
                "สถานะหมวดแจ้งเตือน Android: ${notificationStatus}",
                color = Color(0xFF66636C), fontSize = 11.sp,
            )
            OutlinedButton(onClick = {
                val channelSettings = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    putExtra(Settings.EXTRA_CHANNEL_ID, ZokyFcmPreviewNotificationChannel.ID)
                }
                try {
                    context.startActivity(channelSettings)
                } catch (_: ActivityNotFoundException) {
                    // Redfinger builds may omit per-channel settings screens.
                    try {
                        context.startActivity(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                            }
                        )
                    } catch (_: ActivityNotFoundException) {
                        status = "เปิดตั้งค่า Android ไม่สำเร็จ ให้เปิด Settings → Apps → Zoky → Notifications"
                    }
                }
            }) { Text("เปิดตั้งค่าการแจ้งเตือน Android") }
            OutlinedButton(
                onClick = {
                    fcmCallbacks = ZokyFcmPreviewReceipts.count(context)
                    displayStatus = ZokyFcmPreviewReceipts.displayStatus(context)
                    notificationStatus = ZokyFcmPreviewNotificationChannel.status(context)
                },
            ) { Text("ตรวจผลการรับ FCM") }
            OutlinedButton(
                onClick = {
                    ZokyFcmPreviewReceipts.clear(context)
                    fcmCallbacks = 0
                    displayStatus = ZokyFcmPreviewReceipts.displayStatus(context)
                    status = "ล้างตัวนับแล้ว เปิด Zoky ค้างไว้แล้วส่ง Firebase Test อีกครั้ง"
                },
            ) { Text("เริ่มนับ FCM ใหม่") }
            Text(
                "ต้องเปิด Zoky ค้างไว้ขณะส่ง Firebase Test แล้วกดตรวจผล หลังส่งเสร็จ " +
                    "การแจ้งเตือน Firebase Console ที่เข้าเมื่อแอปอยู่เบื้องหลังอาจไม่ถูกนับ",
                color = Color(0xFF66636C), fontSize = 11.sp,
            )
        }
    }
}
