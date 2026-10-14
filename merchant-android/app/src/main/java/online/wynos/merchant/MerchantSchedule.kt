package online.wynos.merchant

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.json.JSONArray
import org.json.JSONObject
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZonedDateTime

data class MerchantHours(val enabled: Boolean, val open: String, val close: String)

private val days = listOf("mon" to "จันทร์", "tue" to "อังคาร", "wed" to "พุธ",
    "thu" to "พฤหัสบดี", "fri" to "ศุกร์", "sat" to "เสาร์", "sun" to "อาทิตย์")
private val hhmm = Regex("^([01][0-9]|2[0-3]):[0-5][0-9]$")
private val ymd = Regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")

@Composable
fun MerchantScheduleEditor(store: JSONObject, busy: Boolean, save: (JSONObject) -> Unit) {
    val existing = store.optJSONObject("business_schedule")?.optJSONObject("weekly")
    var schedule by remember(store) {
        mutableStateOf(days.associate { (key, _) ->
            val row = existing?.optJSONObject(key)
            key to MerchantHours(row?.optBoolean("enabled") ?: true,
                row?.optString("open") ?: "09:00",
                row?.optString("close") ?: "21:00")
        })
    }
    var closedDates by remember(store) {
        mutableStateOf(store.optJSONArray("special_closed_dates")?.let { array ->
            (0 until array.length()).map { array.optString(it) }
        }.orEmpty())
    }
    var newDate by remember(store) { mutableStateOf("") }
    var closedUntil by remember(store) {
        mutableStateOf(store.optString("temporary_closed_until").takeUnless { it == "null" }.orEmpty())
    }
    var reason by remember(store) {
        mutableStateOf(store.optString("temporary_closed_reason").takeUnless { it == "null" }.orEmpty())
    }
    var error by remember(store) { mutableStateOf("") }
    HorizontalDivider(Modifier.padding(vertical = 12.dp))
    Text("เวลาเปิด–ปิดรายวัน", style = MaterialTheme.typography.titleMedium)
    Text("เวลาไทย · รองรับเวลาเปิดข้ามเที่ยงคืน", style = MaterialTheme.typography.bodySmall)
    days.forEach { (key, title) ->
        val day = schedule.getValue(key)
        Column(Modifier.padding(vertical = 5.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(title, Modifier.weight(1f))
                Switch(day.enabled, onCheckedChange = {
                    schedule = schedule + (key to day.copy(enabled = it))
                })
            }
            if (day.enabled) {
                Row {
                    OutlinedTextField(day.open, onValueChange = {
                        schedule = schedule + (key to day.copy(open = it.take(5)))
                    }, label = { Text("เปิด HH:mm") }, modifier = Modifier.weight(1f))
                    Spacer(Modifier.width(6.dp))
                    OutlinedTextField(day.close, onValueChange = {
                        schedule = schedule + (key to day.copy(close = it.take(5)))
                    }, label = { Text("ปิด HH:mm") }, modifier = Modifier.weight(1f))
                }
            }
        }
    }
    HorizontalDivider(Modifier.padding(vertical = 12.dp))
    Text("วันหยุดพิเศษ", style = MaterialTheme.typography.titleMedium)
    OutlinedTextField(newDate, { newDate = it.take(10) },
        label = { Text("YYYY-MM-DD") }, modifier = Modifier.fillMaxWidth())
    OutlinedButton(onClick = {
        val valid = runCatching { java.time.LocalDate.parse(newDate) }.isSuccess
        if (valid && newDate !in closedDates) {
            closedDates = (closedDates + newDate).sorted()
            newDate = ""
            error = ""
        } else error = "วันที่ไม่ถูกต้อง หรือซ้ำกัน"
    }, enabled = newDate.isNotBlank()) { Text("+ เพิ่มวันหยุด") }
    closedDates.forEach { date ->
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(date, Modifier.weight(1f))
            TextButton(onClick = { closedDates = closedDates - date }) { Text("ลบ") }
        }
    }
    HorizontalDivider(Modifier.padding(vertical = 12.dp))
    Text("ปิดร้านชั่วคราว", style = MaterialTheme.typography.titleMedium)
    Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
        listOf(30 to "30 นาที", 60 to "1 ชม.", 180 to "3 ชม.").forEach { (minutes, name) ->
            OutlinedButton(onClick = {
                closedUntil = ZonedDateTime.now(ZoneId.of("Asia/Bangkok"))
                    .plusMinutes(minutes.toLong()).toOffsetDateTime().toString()
            }) { Text(name, style = MaterialTheme.typography.labelSmall) }
        }
    }
    TextButton(onClick = { closedUntil = ""; reason = "" }) { Text("ยกเลิกปิดชั่วคราว") }
    OutlinedTextField(closedUntil, { closedUntil = it },
        label = { Text("ปิดถึง (ISO วันที่และเวลาพร้อมโซน)") }, modifier = Modifier.fillMaxWidth())
    OutlinedTextField(reason, { reason = it.take(200) },
        label = { Text("เหตุผล") }, modifier = Modifier.fillMaxWidth())
    if (error.isNotBlank()) Text(error, color = MaterialTheme.colorScheme.error)
    Button(enabled = !busy, modifier = Modifier.fillMaxWidth(),
        onClick = {
            val validHours = schedule.values.all { !it.enabled ||
                (hhmm.matches(it.open) && hhmm.matches(it.close)) }
            val validDates = closedDates.all { ymd.matches(it) &&
                runCatching { java.time.LocalDate.parse(it) }.isSuccess }
            val until = if (closedUntil.isBlank()) null else
                runCatching { OffsetDateTime.parse(closedUntil).toInstant() }.getOrNull()
            if (!validHours || !validDates || (closedUntil.isNotBlank() && until == null)) {
                error = "โปรดตรวจสอบเวลาเปิด–ปิดและวันหยุด"
            } else {
                val weekly = JSONObject()
                days.forEach { (key, _) ->
                    val slot = schedule.getValue(key)
                    weekly.put(key, JSONObject().put("enabled", slot.enabled)
                        .put("open", slot.open).put("close", slot.close))
                }
                save(JSONObject()
                    .put("business_schedule", JSONObject().put("weekly", weekly))
                    .put("special_closed_dates", JSONArray(closedDates))
                    .put("temporary_closed_until", until?.toString() ?: JSONObject.NULL)
                    .put("temporary_closed_reason", reason.ifBlank { JSONObject.NULL }))
                error = ""
            }
        }) { Text("บันทึกตารางเวลาและวันหยุด") }
}
