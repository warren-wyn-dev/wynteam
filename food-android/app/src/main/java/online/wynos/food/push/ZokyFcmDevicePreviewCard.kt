package online.wynos.food.push

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
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
    var status by remember { mutableStateOf(
        if (enabled) "เปิดรับข้อความทดสอบจาก Firebase บนอุปกรณ์นี้แล้ว"
        else "ยังไม่ได้เปิดการทดสอบ Firebase บนอุปกรณ์"
    ) }

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
                enabled = true
                token = value
                ZokyPushConsent.setEnabled(context, true)
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
                        val messaging = FirebaseMessaging.getInstance()
                        messaging.isAutoInitEnabled = false
                        messaging.deleteToken().addOnCompleteListener {
                            working = false
                            status = "ปิดรับข้อความทดสอบแล้ว"
                        }
                    },
                ) { Text("ปิดการทดสอบ") }
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
        }
    }
}
