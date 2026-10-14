package online.wynos.merchant

import androidx.compose.foundation.layout.*
import android.net.Uri
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import org.json.JSONObject

private data class StoreField(val key: String, val title: String, val numeric: Boolean = false)
private val details = listOf(
    StoreField("name", "ชื่อร้าน"),
    StoreField("description", "รายละเอียดร้าน"),
    StoreField("phone", "เบอร์ติดต่อ"),
    StoreField("address", "ที่อยู่"),
    StoreField("business_hours", "คำอธิบายเวลาเปิด–ปิด"),
    StoreField("prep_time_min_minutes", "เวลาเตรียมขั้นต่ำ (นาที)", true),
    StoreField("prep_time_max_minutes", "เวลาเตรียมสูงสุด (นาที)", true),
    StoreField("temporary_closed_reason", "เหตุผลปิดชั่วคราว")
)
private val delivery = listOf(
    StoreField("delivery_area", "พื้นที่จัดส่ง"),
    StoreField("delivery_fee", "ค่าส่งพื้นฐาน (บาท)", true),
    StoreField("minimum_order", "ยอดขั้นต่ำ (บาท)", true),
    StoreField("delivery_radius_km", "รัศมีจัดส่ง (กม.)", true),
    StoreField("delivery_base_km", "ระยะพื้นฐาน (กม.)", true),
    StoreField("delivery_fee_per_km", "ค่าส่งเพิ่มต่อ กม. (บาท)", true),
    StoreField("pickup_note", "คำแนะนำจุดรับอาหาร")
)
private val payments = listOf(
    StoreField("promptpay_name", "ชื่อบัญชีพร้อมเพย์"),
    StoreField("promptpay_id", "หมายเลขพร้อมเพย์"),
    StoreField("bank_name", "ธนาคาร"),
    StoreField("bank_account_name", "ชื่อบัญชีธนาคาร"),
    StoreField("bank_account_number", "เลขที่บัญชี")
)
private val scheduled = listOf(
    StoreField("scheduled_min_notice_minutes", "จองล่วงหน้าอย่างน้อย (นาที)", true),
    StoreField("scheduled_max_days", "จองล่วงหน้าได้สูงสุด (วัน)", true)
)
private val taxes = listOf(
    StoreField("tax_legal_name", "ชื่อนิติบุคคล / ผู้ประกอบการ"),
    StoreField("tax_id", "เลขผู้เสียภาษี"),
    StoreField("tax_branch", "สาขา"),
    StoreField("tax_address", "ที่อยู่สำหรับเอกสารภาษี")
)
private val allFields = details + delivery + payments + scheduled + taxes

@Composable
fun MerchantStoreSettings(s: MerchantState, vm: MerchantViewModel) {
    val store = s.store ?: return
    var fields by remember(store) {
        mutableStateOf(allFields.associate { it.key to
            store.optString(it.key).takeUnless { value -> value == "null" }.orEmpty() })
    }
    var toggles by remember(store) {
        mutableStateOf(mapOf(
            "is_open" to store.optBoolean("is_open"),
            "scheduled_orders_enabled" to store.optBoolean("scheduled_orders_enabled"),
            "tax_invoice_enabled" to store.optBoolean("tax_invoice_enabled")
        ))
    }
    var validation by remember(store) { mutableStateOf("") }
    var logoUri by remember(store) { mutableStateOf<Uri?>(null) }
    var coverUri by remember(store) { mutableStateOf<Uri?>(null) }
    var qrUri by remember(store) { mutableStateOf<Uri?>(null) }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        Text("ตั้งค่าร้านค้า", style = MaterialTheme.typography.headlineSmall)
        Spacer(Modifier.height(12.dp))
        Text("ความพร้อมสำหรับเผยแพร่", style = MaterialTheme.typography.titleMedium)
        val checks = s.readiness?.optJSONObject("checks")
        if (checks != null) {
            val total = checks.length()
            val ready = checks.keys().asSequence().count { checks.optBoolean(it) }
            Text("ตรวจแล้ว $ready / $total หัวข้อ")
            checks.keys().asSequence().forEach { key ->
                Text((if (checks.optBoolean(key)) "✓ " else "• ") + key)
            }
        } else Text("ยังไม่ได้โหลดเกณฑ์ความพร้อม")
        Text("สถานะเผยแพร่: " +
            if (store.optBoolean("is_published")) "เผยแพร่แล้ว" else "ยังไม่เผยแพร่",
            color = Color.Gray)
        Button(
            enabled = !s.busy && (store.optBoolean("is_published") ||
                s.readiness?.optBoolean("ready") == true) &&
                (store.optString("admin_suspended_at") in setOf("", "null")),
            onClick = { vm.togglePublished(!store.optBoolean("is_published")) },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(if (store.optBoolean("is_published")) "ซ่อนร้านจาก WYNOS Food"
                else "เผยแพร่ร้านบน WYNOS Food")
        }
        if (store.optString("admin_suspended_at").isNotBlank() &&
            store.optString("admin_suspended_at") != "null") {
            Text("ร้านถูกระงับโดยผู้ดูแลระบบ", color = MaterialTheme.colorScheme.error)
        }
        HorizontalDivider(Modifier.padding(vertical = 14.dp))

        @Composable fun fieldGroup(title: String, group: List<StoreField>) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(5.dp))
            group.forEach { item ->
                OutlinedTextField(
                    value = fields[item.key].orEmpty(),
                    onValueChange = { value -> fields = fields + (item.key to value) },
                    label = { Text(item.title) },
                    modifier = Modifier.fillMaxWidth().padding(bottom = 6.dp),
                )
            }
            Spacer(Modifier.height(12.dp))
        }
        Text("รูปภาพร้านค้า", style = MaterialTheme.typography.titleMedium)
        MerchantImagePicker("โลโก้ร้าน", logoUri, store.optString("logo_path"), !s.busy,
            onSelect = { logoUri = it })
        Row {
            Button(enabled = logoUri != null && !s.busy, onClick = {
                vm.saveStoreImage("logo", logoUri); logoUri = null
            }) { Text("บันทึกโลโก้") }
            TextButton(enabled = !s.busy && store.optString("logo_path").isNotBlank(), onClick = {
                vm.saveStoreImage("logo", null)
            }) { Text("ลบโลโก้") }
        }
        MerchantImagePicker("รูปปกร้าน", coverUri, store.optString("cover_path"), !s.busy,
            onSelect = { coverUri = it })
        Row {
            Button(enabled = coverUri != null && !s.busy, onClick = {
                vm.saveStoreImage("cover", coverUri); coverUri = null
            }) { Text("บันทึกรูปปก") }
            TextButton(enabled = !s.busy && store.optString("cover_path").isNotBlank(), onClick = {
                vm.saveStoreImage("cover", null)
            }) { Text("ลบรูปปก") }
        }
        fieldGroup("ข้อมูลร้านและเวลาเตรียม", details)
        MerchantScheduleEditor(store, s.busy, vm::saveStore)
        HorizontalDivider(Modifier.padding(vertical = 14.dp))
        MerchantLocationsEditor(s, vm)
        HorizontalDivider(Modifier.padding(vertical = 14.dp))
        Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
            Text("เปิดรับออเดอร์", Modifier.weight(1f))
            Switch(checked = toggles["is_open"] == true,
                onCheckedChange = { toggles = toggles + ("is_open" to it) })
        }
        fieldGroup("พื้นที่จัดส่งและค่าส่ง", delivery)
        fieldGroup("ช่องทางชำระเงิน", payments)
        MerchantImagePicker("QR รับชำระเงิน", qrUri, store.optString("payment_qr_path"),
            !s.busy, onSelect = { qrUri = it })
        Row {
            Button(onClick = { vm.saveStoreImage("payment", qrUri); qrUri = null },
                enabled = qrUri != null && !s.busy) { Text("บันทึก QR") }
            TextButton(onClick = { vm.saveStoreImage("payment", null) },
                enabled = !s.busy && store.optString("payment_qr_path").isNotBlank()) {
                Text("ลบ QR")
            }
        }
        Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
            Text("เปิดรับออเดอร์ล่วงหน้า", Modifier.weight(1f))
            Switch(checked = toggles["scheduled_orders_enabled"] == true,
                onCheckedChange = { toggles = toggles + ("scheduled_orders_enabled" to it) })
        }
        if (toggles["scheduled_orders_enabled"] == true) fieldGroup("ออเดอร์ล่วงหน้า", scheduled)
        Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
            Text("แสดงข้อมูลภาษีบนใบเสร็จ", Modifier.weight(1f))
            Switch(checked = toggles["tax_invoice_enabled"] == true,
                onCheckedChange = { toggles = toggles + ("tax_invoice_enabled" to it) })
        }
        if (toggles["tax_invoice_enabled"] == true) fieldGroup("ข้อมูลภาษี", taxes)
        if (validation.isNotBlank()) Text(validation, color = MaterialTheme.colorScheme.error)
        Button(
            enabled = !s.busy && !fields["name"].isNullOrBlank(),
            onClick = {
                val invalid = allFields.firstOrNull { it.numeric && fields[it.key]?.isNotBlank() == true &&
                    (fields[it.key]?.toDoubleOrNull()?.let { num -> num >= 0 } != true) }
                if (invalid != null) {
                    validation = "ตัวเลขไม่ถูกต้อง: " + invalid.title
                } else {
                    validation = ""
                    val payload = JSONObject()
                    allFields.forEach { field ->
                        val raw = fields[field.key].orEmpty()
                        if (field.numeric) {
                            if (raw.isNotBlank()) {
                                val integerFields = setOf("prep_time_min_minutes", "prep_time_max_minutes",
                                    "scheduled_min_notice_minutes", "scheduled_max_days")
                                if (field.key in integerFields) {
                                    val number = raw.toIntOrNull()
                                    if (number == null) { validation = "กรุณากรอกจำนวนเต็มสำหรับ " + field.title; return@Button }
                                    payload.put(field.key, number)
                                } else payload.put(field.key, raw.toDouble())
                            }
                        } else payload.put(field.key, if (raw.isBlank()) JSONObject.NULL else raw)
                    }
                    toggles.forEach { (key, value) -> payload.put(key, value) }
                    vm.saveStore(payload)
                }
            }, modifier = Modifier.fillMaxWidth()
        ) { Text("บันทึกการตั้งค่า") }
        Spacer(Modifier.height(14.dp))
        OutlinedButton(onClick = vm::loadStoreDetails, enabled = !s.busy,
            modifier = Modifier.fillMaxWidth()) { Text("ดูความพร้อมและประวัติแก้ไขล่าสุด") }
        Text("ประวัติการแก้ไขร้าน", style = MaterialTheme.typography.titleMedium)
        s.audit.take(12).forEach { item ->
            Text(item.optString("event_type") + " · " + item.optString("created_at"),
                style = MaterialTheme.typography.bodySmall)
        }
        if (s.audit.isEmpty()) Text("ยังไม่มีรายการประวัติ")
        Text("แผนที่ในแอปและการตั้งค่าบัญชี Stripe Connect ยังคงเป็นงานที่ต้องพัฒนาต่อ",
            color = Color.Gray, style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.padding(top = 12.dp))
    }
}
