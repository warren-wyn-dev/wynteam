package online.wynos.merchant

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale

private fun JSONObject.label(key: String): String =
    optString(key).takeUnless { it == "null" } ?: ""
private val baht = NumberFormat.getCurrencyInstance(Locale.forLanguageTag("th-TH"))
private fun price(value: Double) = baht.format(value)

@Composable
fun MerchantExtraScreen(page: MerchantPage, state: MerchantState, vm: MerchantViewModel) {
    when (page) {
        MerchantPage.FEEDBACK -> FeedbackNative(state, vm)
        MerchantPage.STAFF -> StaffNative(state, vm)
        MerchantPage.ADS -> AdsNative(state, vm)
        MerchantPage.CAMPAIGNS -> PlatformCampaignNative(state, vm)
        MerchantPage.NOTIFICATIONS -> NotificationsNative(state, vm)
        MerchantPage.HELP -> HelpNative(state)
        MerchantPage.PROMOTIONS -> PromotionsNative(state, vm)
        else -> Text("ไม่พบหน้า")
    }
}

@Composable
private fun ToolTitle(value: String, onRefresh: () -> Unit, busy: Boolean) {
    Row(Modifier.fillMaxWidth().padding(bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold,
            modifier = Modifier.weight(1f))
        TextButton(onClick = onRefresh, enabled = !busy) { Text("รีเฟรช") }
    }
}

@Composable
private fun DetailCard(content: @Composable ColumnScope.() -> Unit) {
    ElevatedCard(Modifier.fillMaxWidth().padding(bottom = 10.dp)) {
        Column(Modifier.padding(14.dp), content = content)
    }
}

@Composable
private fun FeedbackNative(s: MerchantState, vm: MerchantViewModel) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        ToolTitle("ฟีดแบ็กจากลูกค้า", { vm.loadExtras(MerchantPage.FEEDBACK) }, s.busy)
        val feed = s.reviews
        if (feed == null) { Text("ยังไม่มีข้อมูลรีวิว หรือไม่มีสิทธิ์เข้าถึง"); return@Column }
        Text("คะแนนเฉลี่ย " + feed.optDouble("average") + "/5 · " +
            feed.optInt("count") + " รีวิว · " + feed.optInt("unanswered") + " ยังไม่ได้ตอบ")
        val reviews = feed.optJSONArray("reviews")?.asObjects().orEmpty()
        if (reviews.isEmpty()) Text("ยังไม่มีรีวิว")
        reviews.forEach { review ->
            var reply by remember(review.label("id"), review.label("merchant_reply")) {
                mutableStateOf(review.label("merchant_reply"))
            }
            DetailCard {
                Text("★".repeat(review.optInt("rating").coerceIn(0, 5)) + " · " +
                    review.label("reviewer_label"), fontWeight = FontWeight.Bold)
                Text(review.label("created_at"), style = MaterialTheme.typography.bodySmall)
                if (review.label("review_text").isNotBlank()) Text(review.label("review_text"))
                val tags = review.optJSONArray("tags")
                if (tags != null) Text((0 until tags.length()).joinToString(" · ") { tags.optString(it) })
                if (review.label("merchant_reply").isNotBlank()) {
                    Text("ร้านตอบแล้ว: " + review.label("merchant_reply"))
                } else {
                    OutlinedTextField(value = reply, onValueChange = { reply = it.take(1000) },
                        label = { Text("ตอบกลับรีวิว") }, modifier = Modifier.fillMaxWidth())
                    Button(enabled = !s.busy && reply.isNotBlank(),
                        onClick = { vm.replyReview(review, reply) }) { Text("ส่งคำตอบ") }
                }
            }
        }
    }
}

private val staffRoles = listOf("admin" to "แอดมิน", "manager" to "ผู้จัดการ",
    "orders" to "ออเดอร์", "support" to "ช่วยเหลือ", "delivery" to "จัดส่ง")

@Composable
private fun RolePicker(role: String, change: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        OutlinedButton(onClick = { expanded = true }) {
            Text("บทบาท: " + (staffRoles.find { it.first == role }?.second ?: role) + " ▾")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            staffRoles.forEach { (id, title) ->
                DropdownMenuItem(text = { Text(title) }, onClick = { change(id); expanded = false })
            }
        }
    }
}

@Composable
private fun StaffNative(s: MerchantState, vm: MerchantViewModel) {
    var username by remember { mutableStateOf("") }
    var role by remember { mutableStateOf("orders") }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        ToolTitle("ทีมงานร้านค้า", { vm.loadExtras(MerchantPage.STAFF) }, s.busy)
        DetailCard {
            Text("เพิ่มทีมงานด้วยบัญชี WYNOS", fontWeight = FontWeight.Bold)
            OutlinedTextField(username, { username = it }, modifier = Modifier.fillMaxWidth(),
                label = { Text("@username") })
            RolePicker(role, { role = it })
            Button(onClick = { vm.addStaff(username, role); username = "" },
                enabled = !s.busy && username.isNotBlank()) { Text("เพิ่มพนักงาน") }
        }
        s.staff.forEach { member ->
            var nextRole by remember(member.label("user_id")) { mutableStateOf(member.label("role")) }
            var nextActive by remember(member.label("user_id")) { mutableStateOf(member.optBoolean("active")) }
            DetailCard {
                Text("@" + member.label("username"), fontWeight = FontWeight.Bold)
                Text(member.label("display_name"))
                if (member.label("role") == "owner") {
                    Text("เจ้าของร้าน — ไม่สามารถแก้ไขสิทธิ์ในหน้านี้")
                } else {
                    RolePicker(nextRole, { nextRole = it })
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("เปิดสิทธิ์พนักงาน", Modifier.weight(1f))
                        Switch(checked = nextActive, onCheckedChange = { nextActive = it })
                    }
                    Button(onClick = { vm.updateStaff(member, nextRole, nextActive) },
                        enabled = !s.busy) { Text("บันทึกสิทธิ์") }
                }
            }
        }
    }
}

@Composable
private fun AdsNative(s: MerchantState, vm: MerchantViewModel) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        ToolTitle("โฆษณาร้านค้า", { vm.loadExtras(MerchantPage.ADS) }, s.busy)
        val ads = s.ads
        if (ads == null) { Text("ไม่มีข้อมูลโฆษณา"); return@Column }
        DetailCard {
            Text("เครดิตคงเหลือ", style = MaterialTheme.typography.labelLarge)
            Text(price(ads.optDouble("balance")), style = MaterialTheme.typography.headlineMedium)
            Text("คลิกละ " + price(ads.optDouble("cost_per_click")) +
                " · วันนี้ " + ads.optInt("clicks_today") + " คลิก")
            Text("7 วัน: " + ads.optInt("clicks_7d") + " คลิก · ใช้ไป " +
                price(ads.optDouble("spend_7d")))
            Text("สถานะ: " + ads.label("status"))
            if (ads.label("stop_reason").isNotBlank()) Text(ads.label("stop_reason"))
            if (ads.optBoolean("can_manage") && ads.label("status") !in setOf("stopped", "none")) {
                Button(onClick = { vm.adActive(ads.label("status") != "active") },
                    enabled = !s.busy) {
                    Text(if (ads.label("status") == "active") "หยุดโฆษณา" else "เปิดโฆษณา")
                }
            }
        }
        DetailCard {
            Text("เติมเครดิต: " + ads.label("wynos_promptpay_id"))
            Text("ขั้นต่ำ " + price(ads.optDouble("min_topup")))
            Text("การแนบสลิปเติมเงินยังต้องพัฒนาเพิ่มเติม")
        }
        ads.optJSONArray("topups")?.asObjects()?.forEach { topup ->
            DetailCard {
                Text(price(topup.optDouble("amount")) + " · " + topup.label("status"))
                Text(topup.label("created_at"))
            }
        }
    }
}

@Composable
private fun PlatformCampaignNative(s: MerchantState, vm: MerchantViewModel) {
    var confirming by remember { mutableStateOf<JSONObject?>(null) }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        ToolTitle("แคมเปญจาก WYNOS", { vm.loadExtras(MerchantPage.CAMPAIGNS) }, s.busy)
        val snapshot = s.platformCampaigns
        if (snapshot == null) { Text("ไม่พบข้อมูลแคมเปญ"); return@Column }
        DetailCard {
            Text("ยอด WYNOS ค้างโอนคืนร้าน")
            Text(price(snapshot.optDouble("owed")), style = MaterialTheme.typography.headlineMedium)
            Text(snapshot.optInt("owed_orders").toString() + " ออเดอร์")
        }
        val campaigns = snapshot.optJSONArray("campaigns")?.asObjects().orEmpty()
        if (campaigns.isEmpty()) Text("ยังไม่มีแคมเปญจาก WYNOS")
        campaigns.forEach { campaign ->
            val share = campaign.optDouble("platform_share_percent").coerceIn(0.0, 100.0)
            DetailCard {
                Text(campaign.label("name"), fontWeight = FontWeight.Bold)
                if (campaign.label("description").isNotBlank()) Text(campaign.label("description"))
                Text("WYNOS ออก " + share + "% · ร้านออก " + (100 - share) + "%")
                Text("ขั้นต่ำ " + price(campaign.optDouble("min_subtotal")) +
                    " · ส่วนลด " + campaign.label("discount_value"))
                if (campaign.optBoolean("first_order_only")) Text("สำหรับลูกค้าใหม่เท่านั้น")
                Text(if (campaign.optBoolean("joined")) "เข้าร่วมแล้ว" else "ยังไม่เข้าร่วม")
                if (snapshot.optBoolean("can_manage")) {
                    OutlinedButton(enabled = !s.busy, onClick = {
                        if (campaign.optBoolean("joined")) vm.joinPlatformCampaign(campaign, false)
                        else confirming = campaign
                    }) { Text(if (campaign.optBoolean("joined")) "ออกจากแคมเปญ" else "เข้าร่วมแคมเปญ") }
                }
            }
        }
        snapshot.optJSONArray("settlements")?.asObjects()?.forEach { settlement ->
            DetailCard {
                Text("WYNOS โอนคืน · " + settlement.label("reference"))
                Text(price(settlement.optDouble("amount")) +
                    " · " + settlement.optInt("order_count") + " ออเดอร์")
            }
        }
    }
    val selected = confirming
    if (selected != null) {
        val share = selected.optDouble("platform_share_percent")
        AlertDialog(onDismissRequest = { confirming = null },
            title = { Text("ยืนยันเข้าร่วมแคมเปญ") },
            text = { Text(selected.label("name") + "\nWYNOS ออก " + share +
                "% ร้านออก " + (100-share) + "% ของส่วนลด") },
            confirmButton = {
                Button(onClick = { vm.joinPlatformCampaign(selected, true); confirming = null },
                    enabled = !s.busy) { Text("ยืนยันเข้าร่วม") }
            },
            dismissButton = { TextButton(onClick = { confirming = null }) { Text("ยกเลิก") } })
    }
}

@Composable
private fun NotificationsNative(s: MerchantState, vm: MerchantViewModel) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        ToolTitle("ศูนย์การแจ้งเตือน", { vm.loadExtras(MerchantPage.NOTIFICATIONS) }, s.busy)
        Row {
            OutlinedButton(onClick = vm::markAllNotificationsRead, enabled = !s.busy) { Text("อ่านทั้งหมด") }
            Spacer(Modifier.width(6.dp))
            TextButton(onClick = vm::sendTestNotification, enabled = !s.busy) { Text("ทดสอบแจ้งเตือน") }
        }
        Text("รายการแจ้งเตือนในแอป · การส่ง Push ขณะปิดแอปยังต้องใช้ FCM",
            style = MaterialTheme.typography.bodySmall)
        if (s.notifications.isEmpty()) Text("ไม่มีการแจ้งเตือน")
        s.notifications.forEach { notice ->
            DetailCard {
                Text(notice.label("type") + " · " + notice.label("reason"),
                    fontWeight = if (notice.label("read_at").isBlank()) FontWeight.Bold else FontWeight.Normal)
                Text(notice.label("created_at"), style = MaterialTheme.typography.bodySmall)
                if (notice.label("read_at").isBlank()) {
                    TextButton(onClick = { vm.markNotificationRead(notice.label("id")) },
                        enabled = !s.busy) { Text("ทำเครื่องหมายว่าอ่านแล้ว") }
                }
            }
        }
    }
}

@Composable
private fun HelpNative(s: MerchantState) {
    val context = LocalContext.current
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        Text("ศูนย์ช่วยเหลือร้านค้า", style = MaterialTheme.typography.titleLarge)
        Text("ติดต่อ Official @wynos_s ผ่าน WYNOS พร้อมชื่อร้านและรหัสร้าน")
        Button(onClick = {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://wynos.online")))
        }) { Text("เปิด WYNOS") }
        OutlinedButton(onClick = {
            val text = "WYNOS Merchant Android\nร้าน: " + s.store?.label("name") +
                "\nStore ID: " + s.store?.label("id") + "\nเวลา: " + java.time.Instant.now()
            val manager = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            manager.setPrimaryClip(ClipData.newPlainText("WYNOS Merchant diagnostics", text))
        }) { Text("คัดลอกข้อมูลสำหรับแจ้งปัญหา") }
        Text("ออเดอร์ไม่แจ้งเตือน: ตรวจสิทธิ์การแจ้งเตือนและเสียงของเครื่อง")
        Text("สลิปไม่ขึ้น: เปิดออเดอร์ใหม่แล้วรีเฟรช")
        Text("ร้านไม่ขึ้น WYNOS Food: ตรวจข้อมูลร้าน ตำแหน่ง เมนู การรับเงิน และสถานะเผยแพร่")
    }
}
