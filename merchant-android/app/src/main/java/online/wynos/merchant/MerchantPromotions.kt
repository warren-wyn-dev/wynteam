package online.wynos.merchant

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.OffsetDateTime

private fun JSONObject.v(key: String): String =
    optString(key).takeIf { it != "null" }.orEmpty()

@Composable
fun PromotionsNative(state: MerchantState, vm: MerchantViewModel) {
    val snapshot = state.promotions
    var editor by remember { mutableStateOf<JSONObject?>(null) }
    var remove by remember { mutableStateOf<JSONObject?>(null) }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("โปรโมชั่นของร้าน", style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.weight(1f), fontWeight = FontWeight.Bold)
            TextButton(onClick = { vm.loadExtras(MerchantPage.PROMOTIONS) },
                enabled = !state.busy) { Text("รีเฟรช") }
        }
        Text("สร้างส่วนลดของร้านเอง · ระบบเลือกส่วนลดที่ดีที่สุดหนึ่งรายการต่อออเดอร์")
        if (snapshot == null) {
            Text("ไม่พบข้อมูลโปรโมชั่น")
            return@Column
        }
        if (snapshot.optBoolean("can_manage")) {
            Button(onClick = { editor = JSONObject() }, enabled = !state.busy) {
                Text("+ สร้างโปรโมชั่น")
            }
        }
        val offers = snapshot.optJSONArray("campaigns")?.asObjects().orEmpty()
        if (offers.isEmpty()) Text("ยังไม่มีโปรโมชั่น")
        offers.forEach { offer ->
            ElevatedCard(Modifier.fillMaxWidth().padding(vertical = 5.dp)) {
                Column(Modifier.padding(14.dp)) {
                    Text(offer.v("name"), fontWeight = FontWeight.Bold)
                    Text(when (offer.v("campaign_type")) {
                        "percentage" -> "ลด " + offer.v("discount_value") + "%"
                        "fixed" -> "ลด " + offer.v("discount_value") + " บาท"
                        else -> "ส่งฟรี"
                    })
                    Text("ขั้นต่ำ " + offer.v("min_subtotal") + " บาท · " +
                        if (offer.optBoolean("is_active")) "เปิดใช้งาน" else "หยุดชั่วคราว")
                    Text("ใช้แล้ว " + offer.optInt("usage_count") + " ครั้ง · ยอดขาย " +
                        offer.v("sales_total") + " บาท")
                    if (snapshot.optBoolean("can_manage")) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("เปิดใช้งาน", Modifier.weight(1f))
                            Switch(checked = offer.optBoolean("is_active"), enabled = !state.busy,
                                onCheckedChange = { vm.promotionActive(offer, it) })
                        }
                        Row {
                            TextButton(onClick = { editor = offer }, enabled = !state.busy) {
                                Text("แก้ไข")
                            }
                            TextButton(onClick = { remove = offer }, enabled = !state.busy) {
                                Text("ลบ")
                            }
                        }
                    }
                }
            }
        }
    }
    if (editor != null) {
        val item = editor!!
        val existing = item.v("id").isNotBlank()
        var name by remember(item) { mutableStateOf(item.v("name")) }
        var kind by remember(item) { mutableStateOf(item.v("campaign_type").ifBlank { "percentage" }) }
        var scope by remember(item) { mutableStateOf(item.v("scope").ifBlank { "store" }) }
        var discount by remember(item) { mutableStateOf(item.v("discount_value").ifBlank { "10" }) }
        var minSubtotal by remember(item) { mutableStateOf(item.v("min_subtotal").ifBlank { "0" }) }
        var maxDiscount by remember(item) { mutableStateOf(item.v("max_discount")) }
        var start by remember(item) { mutableStateOf(item.v("starts_at").ifBlank { Instant.now().toString() }) }
        var end by remember(item) { mutableStateOf(item.v("ends_at")) }
        var usageLimit by remember(item) { mutableStateOf(item.v("usage_limit")) }
        var selectedIds by remember(item) {
            mutableStateOf(item.optJSONArray("item_ids")?.let { ids ->
                (0 until ids.length()).map { i -> ids.optString(i) }.toSet()
            } ?: emptySet())
        }
        var error by remember(item) { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { editor = null },
            title = { Text(if (existing) "แก้ไขโปรโมชั่น" else "สร้างโปรโมชั่น") },
            text = {
                Column(Modifier.heightIn(max = 460.dp).verticalScroll(rememberScrollState())) {
                    OutlinedTextField(name, { name = it.take(80) }, label = { Text("ชื่อโปรโมชั่น") },
                        modifier = Modifier.fillMaxWidth())
                    Text("ประเภทส่วนลด", fontWeight = FontWeight.Medium)
                    listOf("percentage" to "เปอร์เซ็นต์", "fixed" to "บาท", "free_delivery" to "ส่งฟรี")
                        .forEach { (value, label) ->
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                RadioButton(selected = kind == value, onClick = { kind = value })
                                Text(label)
                            }
                        }
                    if (kind != "free_delivery") {
                        OutlinedTextField(discount, { discount = it },
                            label = { Text(if (kind == "percentage") "ส่วนลด %" else "ส่วนลด บาท") },
                            modifier = Modifier.fillMaxWidth())
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            RadioButton(selected = scope == "store", onClick = { scope = "store" })
                            Text("ทั้งร้าน")
                            RadioButton(selected = scope == "items", onClick = { scope = "items" })
                            Text("เฉพาะเมนู")
                        }
                        if (scope == "items") {
                            Text("เลือกเมนู", fontWeight = FontWeight.Medium)
                            state.menu.forEach { food ->
                                val id = food.v("id")
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Checkbox(checked = id in selectedIds, onCheckedChange = { checked ->
                                        selectedIds = if (checked) selectedIds + id else selectedIds - id
                                    })
                                    Text(food.v("name"))
                                }
                            }
                        }
                    }
                    OutlinedTextField(minSubtotal, { minSubtotal = it },
                        label = { Text("ยอดอาหารขั้นต่ำ (บาท)") }, modifier = Modifier.fillMaxWidth())
                    if (kind == "percentage") OutlinedTextField(maxDiscount,
                        { maxDiscount = it }, label = { Text("ลดสูงสุด (บาท) · ว่าง=ไม่จำกัด") },
                        modifier = Modifier.fillMaxWidth())
                    Text("วันที่เวลาเป็น ISO-8601 เช่น 2026-10-14T10:00:00+07:00",
                        style = MaterialTheme.typography.bodySmall)
                    OutlinedTextField(start, { start = it }, label = { Text("เริ่มโปรโมชั่น") },
                        modifier = Modifier.fillMaxWidth())
                    OutlinedTextField(end, { end = it }, label = { Text("สิ้นสุด (เว้นว่าง=ไม่กำหนด)") },
                        modifier = Modifier.fillMaxWidth())
                    OutlinedTextField(usageLimit, { usageLimit = it },
                        label = { Text("จำกัดสิทธิ์ (เว้นว่าง=ไม่จำกัด)") }, modifier = Modifier.fillMaxWidth())
                    if (error.isNotEmpty()) Text(error, color = MaterialTheme.colorScheme.error)
                }
            },
            confirmButton = {
                Button(enabled = !state.busy, onClick = {
                    val value = discount.toDoubleOrNull() ?: 0.0
                    val floor = minSubtotal.toDoubleOrNull()
                    val parsedStart = runCatching { OffsetDateTime.parse(start).toInstant() }
                        .getOrElse { runCatching { Instant.parse(start) }.getOrNull() }
                    val parsedEnd = if (end.isBlank()) null else
                        runCatching { OffsetDateTime.parse(end).toInstant() }
                            .getOrElse { runCatching { Instant.parse(end) }.getOrNull() }
                    val valid = name.isNotBlank() && floor != null && floor >= 0.0 &&
                        parsedStart != null && (end.isBlank() || parsedEnd != null) &&
                        (parsedEnd == null || parsedEnd.isAfter(parsedStart)) &&
                        (kind == "free_delivery" || (value > 0 && (kind != "percentage" || value <= 100))) &&
                        (maxDiscount.isBlank() || (maxDiscount.toDoubleOrNull()?.let { it > 0 } == true)) &&
                        (usageLimit.isBlank() || (usageLimit.toIntOrNull()?.let { it > 0 } == true)) &&
                        (kind == "free_delivery" || scope == "store" || selectedIds.isNotEmpty())
                    if (!valid) error = "โปรดตรวจสอบชื่อ ราคา วันที่ และเมนูที่เลือก"
                    else {
                        val draft = JSONObject()
                            .put("name", name.trim())
                            .put("campaign_type", kind)
                            .put("scope", if (kind == "free_delivery") "store" else scope)
                            .put("discount_value", if (kind == "free_delivery") 0 else value)
                            .put("min_subtotal", floor)
                            .put("max_discount", if (maxDiscount.isBlank()) JSONObject.NULL else maxDiscount.toDouble())
                            .put("starts_at", parsedStart.toString())
                            .put("ends_at", parsedEnd?.toString() ?: JSONObject.NULL)
                            .put("usage_limit", if (usageLimit.isBlank()) JSONObject.NULL else usageLimit.toInt())
                            .put("item_ids", JSONArray(selectedIds.toList()))
                        if (existing) draft.put("id", item.v("id"))
                        vm.savePromotion(draft)
                        editor = null
                    }
                }) { Text("บันทึก") }
            },
            dismissButton = { TextButton(onClick = { editor = null }) { Text("ยกเลิก") } }
        )
    }
    val selected = remove
    if (selected != null) {
        AlertDialog(onDismissRequest = { remove = null },
            title = { Text("ลบโปรโมชั่น?") },
            text = { Text("ยืนยันลบ " + selected.v("name")) },
            confirmButton = {
                Button(onClick = { vm.deletePromotion(selected); remove = null },
                    enabled = !state.busy) { Text("ลบ") }
            },
            dismissButton = { TextButton(onClick = { remove = null }) { Text("ยกเลิก") } })
    }
}
