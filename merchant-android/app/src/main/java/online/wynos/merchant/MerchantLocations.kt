package online.wynos.merchant

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import org.json.JSONObject

private fun coordinateText(store: JSONObject, key: String): String =
    store.optString(key).takeUnless { it == "null" }.orEmpty()

/** Native editing of restaurant/pickup coordinates and store delivery places.
 * Uses the existing tenant-scoped food_stores and food_store_places backend,
 * rather than embedding the merchant website in a WebView.
 */
@Composable
fun MerchantLocationsEditor(state: MerchantState, vm: MerchantViewModel) {
    val store = state.store ?: return
    val context = LocalContext.current
    val id = store.optString("id")
    var latitude by remember(id, store.optString("latitude")) {
        mutableStateOf(coordinateText(store, "latitude"))
    }
    var longitude by remember(id, store.optString("longitude")) {
        mutableStateOf(coordinateText(store, "longitude"))
    }
    var pickupLat by remember(id, store.optString("pickup_latitude")) {
        mutableStateOf(coordinateText(store, "pickup_latitude"))
    }
    var pickupLon by remember(id, store.optString("pickup_longitude")) {
        mutableStateOf(coordinateText(store, "pickup_longitude"))
    }
    var error by remember(id) { mutableStateOf("") }

    Text("พิกัดร้านและจุดรับอาหาร", style = MaterialTheme.typography.titleMedium)
    Text("ระบุพิกัด GPS จากแผนที่ (องศาทศนิยม) เพื่อให้การจัดส่งคำนวณตำแหน่งถูกต้อง",
        style = MaterialTheme.typography.bodySmall)
    OutlinedTextField(latitude, { latitude = it }, label = { Text("ละติจูดร้าน (-90 ถึง 90)") },
        modifier = Modifier.fillMaxWidth(), singleLine = true)
    OutlinedTextField(longitude, { longitude = it }, label = { Text("ลองจิจูดร้าน (-180 ถึง 180)") },
        modifier = Modifier.fillMaxWidth(), singleLine = true)
    OutlinedTextField(pickupLat, { pickupLat = it }, label = { Text("ละติจูดจุดรับอาหาร") },
        modifier = Modifier.fillMaxWidth(), singleLine = true)
    OutlinedTextField(pickupLon, { pickupLon = it }, label = { Text("ลองจิจูดจุดรับอาหาร") },
        modifier = Modifier.fillMaxWidth(), singleLine = true)
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        OutlinedButton(onClick = {
            val lat = latitude.toDoubleOrNull() ?: 13.7563
            val lon = longitude.toDoubleOrNull() ?: 100.5018
            val link = Uri.parse("geo:$lat,$lon?q=$lat,$lon")
            runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, link)) }
                .onFailure { error = "ไม่พบแอปแผนที่บนอุปกรณ์" }
        }) { Text("เปิดแผนที่เพื่อเทียบตำแหน่ง") }
    }
    Button(onClick = {
        fun parse(v: String, lower: Double, upper: Double): Any? {
            val value = v.trim()
            if (value.isEmpty()) return JSONObject.NULL
            val number = value.toDoubleOrNull() ?: return null
            return number.takeIf { it.isFinite() && it in lower..upper }
        }
        val a = parse(latitude, -90.0, 90.0)
        val b = parse(longitude, -180.0, 180.0)
        val c = parse(pickupLat, -90.0, 90.0)
        val d = parse(pickupLon, -180.0, 180.0)
        val complete = listOf(a, b, c, d).none { it == null }
        val restaurantPair = (a == JSONObject.NULL) == (b == JSONObject.NULL)
        val pickupPair = (c == JSONObject.NULL) == (d == JSONObject.NULL)
        if (!complete || !restaurantPair || !pickupPair) {
            error = "พิกัดต้องอยู่ในช่วงที่ถูกต้อง และต้องระบุละติจูด/ลองจิจูดเป็นคู่"
        } else {
            error = ""
            vm.saveCoordinates(JSONObject()
                .put("latitude", a).put("longitude", b)
                .put("pickup_latitude", c).put("pickup_longitude", d))
        }
    }, enabled = !state.busy, modifier = Modifier.fillMaxWidth()) {
        Text("บันทึกพิกัด")
    }
    if (error.isNotEmpty()) Text(error, color = MaterialTheme.colorScheme.error,
        style = MaterialTheme.typography.bodySmall)
    HorizontalDivider(Modifier.padding(vertical = 14.dp))

    Text("สถานที่จัดส่งที่บันทึกไว้", style = MaterialTheme.typography.titleMedium)
    val places = state.places
    if (places == null) {
        Text("ยังไม่สามารถโหลดสถานที่จัดส่งได้ โปรดตรวจสอบว่าฐานข้อมูลรองรับฟีเจอร์นี้",
            style = MaterialTheme.typography.bodySmall)
        return
    }
    var editing by remember(id) { mutableStateOf<JSONObject?>(null) }
    var name by remember(id) { mutableStateOf("") }
    var detail by remember(id) { mutableStateOf("") }
    var placeLat by remember(id) { mutableStateOf("") }
    var placeLon by remember(id) { mutableStateOf("") }
    var active by remember(id) { mutableStateOf(true) }
    var placeError by remember(id) { mutableStateOf("") }
    var pendingDelete by remember(id) { mutableStateOf<JSONObject?>(null) }

    fun clearForm() {
        editing = null
        name = ""
        detail = ""
        placeLat = ""
        placeLon = ""
        active = true
        placeError = ""
    }
    for (place in places) {
        Row(modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween) {
            Text(place.optString("name") +
                if (place.optBoolean("is_active")) "" else " (ปิดใช้งาน)",
                modifier = Modifier.weight(1f))
            TextButton(onClick = {
                editing = place
                name = place.optString("name")
                detail = coordinateText(place, "detail")
                placeLat = coordinateText(place, "latitude")
                placeLon = coordinateText(place, "longitude")
                active = place.optBoolean("is_active", true)
                placeError = ""
            }) { Text("แก้ไข") }
            TextButton(onClick = { pendingDelete = place }) { Text("ลบ") }
        }
    }
    if (places.isEmpty()) Text("ยังไม่มีสถานที่จัดส่งที่บันทึกไว้")

    Text(if (editing == null) "เพิ่มสถานที่" else "แก้ไขสถานที่",
        style = MaterialTheme.typography.titleSmall)
    OutlinedTextField(name, { name = it.take(120) },
        label = { Text("ชื่อสถานที่") }, modifier = Modifier.fillMaxWidth())
    OutlinedTextField(detail, { detail = it.take(200) },
        label = { Text("รายละเอียด") }, modifier = Modifier.fillMaxWidth())
    OutlinedTextField(placeLat, { placeLat = it },
        label = { Text("ละติจูด") }, modifier = Modifier.fillMaxWidth())
    OutlinedTextField(placeLon, { placeLon = it },
        label = { Text("ลองจิจูด") }, modifier = Modifier.fillMaxWidth())
    Row {
        Text("เปิดใช้งาน", modifier = Modifier.weight(1f))
        Switch(checked = active, onCheckedChange = { active = it })
    }
    if (placeError.isNotBlank()) Text(placeError, color = MaterialTheme.colorScheme.error)
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Button(enabled = !state.busy, onClick = {
            val la = placeLat.trim().toDoubleOrNull()
            val lo = placeLon.trim().toDoubleOrNull()
            if (name.isBlank() || la == null || lo == null ||
                !la.isFinite() || !lo.isFinite() || la !in -90.0..90.0 ||
                lo !in -180.0..180.0) {
                placeError = "กรุณากรอกชื่อและพิกัดสถานที่ให้ถูกต้อง"
            } else {
                val draft = JSONObject().put("name", name.trim()).put("detail", detail.trim())
                    .put("latitude", la).put("longitude", lo).put("is_active", active)
                editing?.optString("id")?.let { draft.put("id", it) }
                vm.savePlace(draft)
                clearForm()
            }
        }) { Text("บันทึกสถานที่") }
        if (editing != null) OutlinedButton(onClick = ::clearForm) { Text("ยกเลิก") }
    }
    val target = pendingDelete
    if (target != null) {
        AlertDialog(onDismissRequest = { pendingDelete = null },
            title = { Text("ยืนยันการลบสถานที่") },
            text = { Text("ต้องการลบ " + target.optString("name") + " ใช่ไหม?") },
            confirmButton = {
                TextButton(onClick = {
                    vm.deletePlace(target.optString("id"))
                    pendingDelete = null
                }) { Text("ลบ") }
            },
            dismissButton = {
                TextButton(onClick = { pendingDelete = null }) { Text("ยกเลิก") }
            })
    }
}
