package online.wynos.merchant

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Native picker with image preview before upload; all file operations are off the main thread. */
@Composable
fun MerchantImagePicker(
    label: String,
    selected: Uri?,
    existingPath: String?,
    enabled: Boolean,
    onSelect: (Uri?) -> Unit
) {
    val context = LocalContext.current
    var preview by remember(selected) { mutableStateOf<Bitmap?>(null) }
    var error by remember(selected) { mutableStateOf(false) }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) {
        onSelect(it)
    }
    LaunchedEffect(selected) {
        preview = null
        error = false
        if (selected != null) {
            preview = withContext(Dispatchers.IO) {
                runCatching {
                    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    context.contentResolver.openInputStream(selected)?.use {
                        BitmapFactory.decodeStream(it, null, bounds)
                    }
                    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return@runCatching null
                    var sample = 1
                    while (bounds.outWidth / sample > 1000 || bounds.outHeight / sample > 1000) sample *= 2
                    context.contentResolver.openInputStream(selected)?.use {
                        BitmapFactory.decodeStream(it, null,
                            BitmapFactory.Options().apply { inSampleSize = sample })
                    }
                }.getOrNull()
            }
            error = preview == null
        }
    }
    Column(Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
        Text(label, style = MaterialTheme.typography.titleSmall)
        if (preview != null) {
            Image(bitmap = preview!!.asImageBitmap(), contentDescription = "ตัวอย่าง" + label,
                contentScale = ContentScale.Fit,
                modifier = Modifier.fillMaxWidth().heightIn(max = 220.dp))
            Text("เลือกภาพแล้ว · จะอัปโหลดเมื่อกดบันทึก", style = MaterialTheme.typography.bodySmall)
        } else if (error) {
            Text("ไม่สามารถแสดงตัวอย่างภาพนี้ได้", color = MaterialTheme.colorScheme.error)
        } else if (!existingPath.isNullOrBlank()) {
            Text("มีรูปเดิมแล้ว · " + existingPath.substringAfterLast("/"),
                style = MaterialTheme.typography.bodySmall)
        } else {
            Text("ยังไม่ได้เลือกรูป", style = MaterialTheme.typography.bodySmall)
        }
        Row {
            OutlinedButton(onClick = { picker.launch("image/*") }, enabled = enabled) {
                Text(if (selected != null || !existingPath.isNullOrBlank()) "เปลี่ยนรูป" else "เลือกรูป")
            }
            if (selected != null) TextButton(onClick = { onSelect(null) }, enabled = enabled) {
                Text("ยกเลิกภาพที่เลือก")
            }
        }
    }
}
