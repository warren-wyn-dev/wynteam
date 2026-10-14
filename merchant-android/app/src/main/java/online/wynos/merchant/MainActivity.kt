package online.wynos.merchant

import android.os.Bundle
import android.net.Uri
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale

private val Red = Color(0xFFE32636)
private val Grey = Color(0xFF6B7280)
private val Money = NumberFormat.getCurrencyInstance(Locale.forLanguageTag("th-TH"))
private fun money(value: Double): String = Money.format(value)
private fun JSONObject.text(key: String): String =
    optString(key).takeUnless { it == "null" } ?: ""
private fun JSONObject.amount(key: String): Double = optDouble(key, 0.0)
private fun JSONObject.orderTitle(): String = "#" + text("order_number")
private fun orderStatus(status: String): String = when (status) {
    "pending_acceptance" -> "ออเดอร์ใหม่"
    "preparing" -> "กำลังเตรียม"
    "ready_for_delivery" -> "พร้อมจัดส่ง"
    "out_for_delivery" -> "กำลังจัดส่ง"
    "delivered" -> "ส่งสำเร็จ"
    "cancelled" -> "ยกเลิก"
    else -> status
}
private fun orderNext(status: String): String = when (status) {
    "pending_acceptance" -> "รับออเดอร์"
    "preparing" -> "อาหารพร้อมแล้ว"
    "ready_for_delivery" -> "เริ่มจัดส่ง"
    else -> ""
}
private fun filterOrder(order: JSONObject, tab: String): Boolean = when (tab) {
    "new" -> order.text("status") == "pending_acceptance"
    "cooking" -> order.text("status") in listOf("preparing", "ready_for_delivery")
    "delivery" -> order.text("status") == "out_for_delivery"
    "done" -> isRecentCompleted(order)
    else -> false
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val vm: MerchantViewModel = viewModel()
            MaterialTheme(colorScheme = lightColorScheme(primary = Red, background = Color.White)) {
                MerchantApp(vm)
            }
        }
    }
}

@Composable
private fun MerchantApp(vm: MerchantViewModel) {
    val s = vm.state
    if (!s.configured) {
        Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
            Text("ต้องกำหนด WYNOS_SUPABASE_URL และ WYNOS_SUPABASE_PUBLISHABLE_KEY ใน Gradle ก่อนทดสอบแอป")
        }
        return
    }
    if (!s.signedIn) {
        LoginScreen(busy = s.busy, error = s.error, onSignIn = vm::signIn)
        return
    }
    Scaffold(
        topBar = {
            Column {
                Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("WYNOS Merchant", style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold, color = Red)
                    Spacer(Modifier.weight(1f))
                    TextButton(onClick = vm::refresh, enabled = !s.busy) { Text("รีเฟรช") }
                }
                StorePicker(s.stores, s.store, vm::selectStore)
                if (s.busy) LinearProgressIndicator(Modifier.fillMaxWidth())
                if (s.error.isNotEmpty()) Text(s.error, Modifier.fillMaxWidth().padding(12.dp), color = MaterialTheme.colorScheme.error)
                if (s.notice.isNotEmpty()) Text(s.notice, Modifier.fillMaxWidth().padding(horizontal = 12.dp), color = Grey)
            }
        },
        bottomBar = {
            NavigationBar(containerColor = Color.White) {
                listOf(
                    MerchantPage.HOME to "หน้าหลัก",
                    MerchantPage.ORDERS to "รับออเดอร์",
                    MerchantPage.MENU to "เมนู",
                    MerchantPage.MORE to "เพิ่มเติม"
                ).forEach { (page, title) ->
                    NavigationBarItem(
                        selected = s.page == page || (page == MerchantPage.MORE && s.page !in listOf(
                            MerchantPage.HOME, MerchantPage.ORDERS, MerchantPage.MENU)),
                        onClick = { vm.openPage(page) },
                        icon = { Text(when (page) {
                            MerchantPage.HOME -> "⌂"
                            MerchantPage.ORDERS -> "▤"
                            MerchantPage.MENU -> "☰"
                            else -> "•••"
                        }) },
                        label = { Text(title) }
                    )
                }
            }
        }
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when (s.page) {
                MerchantPage.HOME -> HomeScreen(s, vm)
                MerchantPage.ORDERS -> OrdersScreen(s, vm)
                MerchantPage.MENU -> MenuScreen(s, vm)
                MerchantPage.MORE -> MoreScreen(vm)
                MerchantPage.REPORTS -> SalesScreen(s, vm)
                MerchantPage.FINANCE -> FinanceScreen(s)
                MerchantPage.STORE -> StoreScreen(s, vm)
                MerchantPage.HISTORY -> HistoryScreen(s, vm)
            }
        }
    }
}

@Composable
private fun LoginScreen(busy: Boolean, error: String, onSignIn: (String, String) -> Unit) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center) {
        Text("WYNOS Merchant", style = MaterialTheme.typography.headlineMedium, color = Red,
            fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text("เข้าสู่ระบบร้านค้า", color = Grey)
        Spacer(Modifier.height(20.dp))
        OutlinedTextField(email, { email = it }, Modifier.fillMaxWidth(),
            label = { Text("อีเมล") }, singleLine = true)
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(password, { password = it }, Modifier.fillMaxWidth(),
            label = { Text("รหัสผ่าน") }, singleLine = true,
            visualTransformation = PasswordVisualTransformation())
        if (error.isNotEmpty()) Text(error, Modifier.padding(vertical = 10.dp),
            color = MaterialTheme.colorScheme.error)
        Spacer(Modifier.height(16.dp))
        Button(onClick = { onSignIn(email, password) },
            enabled = !busy && email.isNotBlank() && password.isNotBlank(),
            modifier = Modifier.fillMaxWidth()) { Text(if (busy) "กำลังเข้าสู่ระบบ..." else "เข้าสู่ระบบ") }
    }
}

@Composable
private fun StorePicker(stores: List<JSONObject>, store: JSONObject?, choose: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    if (stores.isEmpty()) return
    Box(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        TextButton(onClick = { expanded = true }) {
            Text("ร้าน: " + (store?.text("name") ?: "เลือกร้าน"), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(" ▾")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            stores.forEach { item ->
                DropdownMenuItem(text = { Text(item.text("name")) }, onClick = {
                    expanded = false
                    choose(item.text("id"))
                })
            }
        }
    }
}

@Composable
private fun SectionHeading(title: String) {
    Text(title, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleLarge,
        modifier = Modifier.padding(bottom = 12.dp))
}

@Composable
private fun SummaryCard(title: String, value: String, onClick: (() -> Unit)? = null) {
    ElevatedCard(modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp),
        onClick = onClick ?: {}) {
        Column(Modifier.padding(16.dp)) {
            Text(title, color = Grey, style = MaterialTheme.typography.bodySmall)
            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun HomeScreen(s: MerchantState, vm: MerchantViewModel) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        SectionHeading("ภาพรวมร้าน")
        if (s.store == null) {
            Text("บัญชีนี้ยังไม่มีร้านค้า กรุณาลงทะเบียนร้านผ่านระบบที่ได้รับสิทธิ์")
            return@Column
        }
        val today = s.sales
        SummaryCard("ยอดขายวันนี้", today?.let { money(it.amount("today_sales")) } ?: "—")
        SummaryCard("ออเดอร์วันนี้", today?.optInt("today_orders")?.toString() ?: "—")
        SummaryCard("ออเดอร์รอรับ", s.orders.count { it.text("status") == "pending_acceptance" }.toString()) {
            vm.openPage(MerchantPage.ORDERS)
        }
        SummaryCard("เมนูเปิดขาย", s.menu.count { it.optBoolean("is_available") }.toString()) {
            vm.openPage(MerchantPage.MENU)
        }
        Text("ตัวเลขยอดขายมาจาก merchant_sales_report บนเซิร์ฟเวอร์", color = Grey,
            style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
private fun OrdersScreen(s: MerchantState, vm: MerchantViewModel) {
    val order = s.selectedOrder
    if (order != null) {
        OrderDetail(order, vm, s)
        return
    }
    Column(Modifier.fillMaxSize().padding(12.dp)) {
        SectionHeading("รับออเดอร์")
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf("new" to "ใหม่", "cooking" to "กำลังเตรียม",
                "delivery" to "จัดส่ง", "done" to "เสร็จแล้ว").forEach { (value, title) ->
                FilterChip(selected = s.orderFilter == value, onClick = { vm.orderFilter(value) },
                    label = { Text(title, style = MaterialTheme.typography.labelSmall) })
            }
        }
        val orders = s.orders.filter { filterOrder(it, s.orderFilter) }
        if (s.hasMoreOrders) Text("กำลังแสดงออเดอร์ล่าสุด 100 รายการ", color = Grey)
        if (orders.isEmpty()) Text("ยังไม่มีออเดอร์ในหมวดนี้", Modifier.padding(16.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(orders, key = { it.text("id") }) { item ->
                ElevatedCard(onClick = { vm.selectOrder(item) }, modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Text(item.orderTitle(), fontWeight = FontWeight.Bold)
                        Text(item.text("recipient_name") + " · " + orderStatus(item.text("status")))
                        Text(money(item.amount("total")), color = Red)
                    }
                }
            }
        }
    }
}

@Composable
private fun OrderDetail(order: JSONObject, vm: MerchantViewModel, state: MerchantState) {
    val busy = state.busy
    val status = order.text("status")
    val payment = order.text("payment_status")
    val next = if (status == "pending_acceptance" && payment != "paid") "" else orderNext(status)
    val slipPath = order.text("payment_slip_path")
    val bitmap = state.slipBitmap.takeIf {
        state.slipPreviewOrderId == order.text("id") && state.slipPreviewPath == slipPath
    }
    var reviewed by remember(order.text("id"), slipPath) { mutableStateOf(false) }
    var eta by remember(order.text("id")) { mutableIntStateOf(order.optInt("eta_minutes", 30).takeIf { it in listOf(15, 30, 45, 60) } ?: 30) }
    var method by remember(order.text("id")) { mutableStateOf("direct") }
    var locationNote by remember(order.text("id")) { mutableStateOf("") }
    var deliveryUri by remember(order.text("id")) { mutableStateOf<Uri?>(null) }
    val context = LocalContext.current
    var deliveryPreview by remember(deliveryUri) { mutableStateOf<Bitmap?>(null) }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) {
        deliveryUri = it
    }
    LaunchedEffect(deliveryUri) {
        val uri = deliveryUri
        deliveryPreview = if (uri == null) null else withContext(Dispatchers.IO) {
            runCatching {
                val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
                var sample = 1
                while (options.outWidth / sample > 800 || options.outHeight / sample > 800) sample *= 2
                context.contentResolver.openInputStream(uri)?.use {
                    BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
                }
            }.getOrNull()
        }
    }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        TextButton(onClick = { vm.selectOrder(null) }) { Text("‹ กลับไปออเดอร์") }
        SectionHeading(order.orderTitle())
        Text(orderStatus(status), color = Red, fontWeight = FontWeight.Bold)
        if (order.text("scheduled_for").isNotBlank()) Text("ออเดอร์ล่วงหน้า: " + order.text("scheduled_for"), color = Grey)
        Spacer(Modifier.height(12.dp))
        Text("ลูกค้า: " + order.text("recipient_name"))
        Text("โทรศัพท์: " + order.text("recipient_phone"))
        Text("จัดส่ง: " + order.text("shipping_address"))
        if (order.text("customer_note").isNotBlank()) Text("หมายเหตุ: " + order.text("customer_note"))
        Spacer(Modifier.height(12.dp))
        Text("รายการอาหาร", fontWeight = FontWeight.Bold)
        val lines = order.optJSONArray("food_order_items") ?: org.json.JSONArray()
        lines.asObjects().forEach { item ->
            Text(item.text("item_name") + " × " + item.optInt("quantity") +
                " — " + money(item.amount("unit_price") * item.optInt("quantity")))
            item.optJSONArray("selected_options")?.asObjects()?.forEach { option ->
                Text("  + " + option.text("choice_name"), color = Grey)
            }
            if (item.text("item_note").isNotBlank()) Text("  " + item.text("item_note"), color = Grey)
        }
        HorizontalDivider(Modifier.padding(vertical = 12.dp))
        Text("ค่าอาหาร: " + money(order.amount("subtotal")))
        Text("ค่าส่ง: " + money(order.amount("delivery_fee")))
        Text("ยอดชำระ: " + money(order.amount("total")), fontWeight = FontWeight.Bold)
        Text("การชำระเงิน: " + payment)

        if (status == "pending_acceptance") {
            Spacer(Modifier.height(16.dp))
            if (payment == "submitted") {
                Text("ตรวจสลิปและยืนยันว่าเงินเข้าจริงก่อนรับออเดอร์", fontWeight = FontWeight.Bold)
                if (bitmap != null) {
                    Image(bitmap = bitmap.asImageBitmap(), contentDescription = "สลิปชำระเงิน",
                        contentScale = ContentScale.Fit,
                        modifier = Modifier.fillMaxWidth().heightIn(max = 390.dp).padding(vertical = 8.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = reviewed, onCheckedChange = { reviewed = it })
                        Text("ฉันได้ตรวจสอบสลิปและยอดเงินแล้ว")
                    }
                } else Text(if (busy) "กำลังโหลดสลิป..." else "ไม่สามารถโหลดสลิปได้ ห้ามยืนยันรับชำระเงิน", color = Grey)
                Text("เวลาเตรียมอาหาร", fontWeight = FontWeight.Medium)
                Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    listOf(15, 30, 45, 60).forEach { minute ->
                        FilterChip(selected = eta == minute, onClick = { eta = minute },
                            label = { Text("$minute นาที", style = MaterialTheme.typography.labelSmall) })
                    }
                }
                Button(
                    onClick = { vm.approveSlipAndAccept(order, reviewed, eta) },
                    enabled = !busy && bitmap != null && reviewed,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("เงินเข้าแล้ว · รับออเดอร์") }
                OutlinedButton(onClick = { vm.rejectSlip(order) }, enabled = !busy,
                    modifier = Modifier.fillMaxWidth()) { Text("สลิปมีปัญหา") }
            } else if (payment == "paid") {
                Text("เวลาเตรียมอาหาร")
                Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    listOf(15, 30, 45, 60).forEach { minute ->
                        FilterChip(selected = eta == minute, onClick = { eta = minute },
                            label = { Text("$minute นาที", style = MaterialTheme.typography.labelSmall) })
                    }
                }
                Button(onClick = { vm.actionOrder(order, eta) }, enabled = !busy,
                    modifier = Modifier.fillMaxWidth()) { Text("รับออเดอร์") }
            } else {
                Text(if (payment == "issue") "สลิปมีปัญหา · รอลูกค้าส่งใหม่" else "รอลูกค้าชำระเงิน", color = Grey)
            }
        } else if (next.isNotBlank()) {
            Spacer(Modifier.height(20.dp))
            Button(onClick = { vm.actionOrder(order) }, enabled = !busy,
                modifier = Modifier.fillMaxWidth()) { Text(next) }
        }

        if (status == "out_for_delivery") {
            Spacer(Modifier.height(16.dp))
            Text("ยืนยันการจัดส่ง", fontWeight = FontWeight.Bold)
            Row {
                FilterChip(selected = method == "direct", onClick = { method = "direct" },
                    label = { Text("ส่งให้ลูกค้า") })
                Spacer(Modifier.width(8.dp))
                FilterChip(selected = method == "dropoff", onClick = { method = "dropoff" },
                    label = { Text("วางสินค้าไว้") })
            }
            if (method == "dropoff") {
                OutlinedTextField(value = locationNote, onValueChange = { locationNote = it },
                    label = { Text("วางสินค้าไว้ที่ไหน?") }, modifier = Modifier.fillMaxWidth())
            }
            OutlinedButton(onClick = { picker.launch("image/*") }, enabled = !busy) {
                Text(if (deliveryUri == null) "เลือกรูปหลักฐานการจัดส่ง" else "เปลี่ยนรูปหลักฐาน")
            }
            if (deliveryPreview != null) {
                Image(bitmap = deliveryPreview!!.asImageBitmap(), contentDescription = "ตัวอย่างรูปหลักฐาน",
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.fillMaxWidth().heightIn(max = 260.dp))
                TextButton(onClick = { deliveryUri = null }) { Text("ลบรูปที่เลือก") }
            }
            Text("จำเป็นต้องแนบรูปจริง ภาพจะถูกแปลงเพื่อตัดข้อมูล GPS/EXIF ก่อนอัปโหลด",
                color = Grey, style = MaterialTheme.typography.bodySmall)
            Button(
                onClick = { vm.completeOrder(order, method, locationNote, deliveryUri) },
                enabled = !busy && deliveryUri != null && deliveryPreview != null &&
                    (method != "dropoff" || locationNote.isNotBlank()),
                modifier = Modifier.fillMaxWidth()
            ) { Text("ยืนยันส่งสำเร็จ") }
        }
    }
}

@Composable
private fun MenuScreen(s: MerchantState, vm: MerchantViewModel) {
    val editing = s.selectedMenu
    if (editing != null) {
        MenuEditor(editing, busy = s.busy, save = vm::saveMenu,
            delete = vm::deleteMenu, dismiss = { vm.selectMenu(null) })
    }
    var sorting by remember { mutableStateOf(false) }
    var orderIds by remember(s.menu) { mutableStateOf(s.menu.map { it.text("id") }) }
    val ordered = orderIds.mapNotNull { id -> s.menu.find { it.text("id") == id } }
    Column(Modifier.fillMaxSize().padding(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            SectionHeading("จัดการเมนู")
            Spacer(Modifier.weight(1f))
            TextButton(onClick = { vm.selectMenu(JSONObject()) }) { Text("+ เพิ่มเมนู") }
        }
        Row {
            if (sorting) {
                TextButton(onClick = { sorting = false; orderIds = s.menu.map { it.text("id") } }) {
                    Text("ยกเลิก")
                }
                Button(onClick = { vm.reorderMenu(orderIds); sorting = false }, enabled = !s.busy) {
                    Text("บันทึกลำดับ")
                }
            } else OutlinedButton(onClick = { sorting = true }) { Text("จัดเรียงเมนู") }
        }
        LazyColumn {
            items(ordered, key = { it.text("id") }) { item ->
                val soldUntil = item.text("sold_out_until")
                val sold = runCatching {
                    java.time.OffsetDateTime.parse(soldUntil).toInstant().isAfter(java.time.Instant.now())
                }.getOrDefault(false)
                ElevatedCard(modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp)) {
                    Column(Modifier.padding(12.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f).clickable { if (!sorting) vm.selectMenu(item) }) {
                                Text(item.text("name"), fontWeight = FontWeight.Bold)
                                Text(item.text("category") + " · " + money(item.amount("price")), color = Grey)
                            }
                            if (!sorting) Switch(checked = item.optBoolean("is_available"),
                                enabled = !s.busy, onCheckedChange = { vm.setAvailability(item, it) })
                        }
                        if (sorting) {
                            val index = orderIds.indexOf(item.text("id"))
                            Row {
                                TextButton(onClick = {
                                    if (index > 0 && ordered[index - 1].text("category") == item.text("category")) {
                                        orderIds = orderIds.toMutableList().apply { add(index - 1, removeAt(index)) }
                                    }
                                }, enabled = index > 0 && ordered[index - 1].text("category") == item.text("category")) {
                                    Text("↑ เลื่อนขึ้น")
                                }
                                TextButton(onClick = {
                                    if (index < ordered.lastIndex && ordered[index + 1].text("category") == item.text("category")) {
                                        orderIds = orderIds.toMutableList().apply { add(index + 1, removeAt(index)) }
                                    }
                                }, enabled = index < ordered.lastIndex &&
                                        ordered[index + 1].text("category") == item.text("category")) {
                                    Text("↓ เลื่อนลง")
                                }
                            }
                        } else {
                            TextButton(onClick = { vm.soldOutToday(item, !sold) }, enabled = !s.busy) {
                                Text(if (sold) "ยกเลิกหมดวันนี้" else "หมดวันนี้")
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MenuEditor(item: JSONObject, busy: Boolean, save: (JSONObject) -> Unit,
                       delete: (JSONObject) -> Unit, dismiss: () -> Unit) {
    var name by remember(item) { mutableStateOf(item.text("name")) }
    var category by remember(item) { mutableStateOf(item.text("category").ifBlank { "อาหาร" }) }
    var description by remember(item) { mutableStateOf(item.text("description")) }
    var price by remember(item) { mutableStateOf(item.text("price")) }
    var stock by remember(item) {
        mutableStateOf(item.opt("daily_stock_limit")?.toString()?.takeUnless { it == "null" } ?: "")
    }
    var available by remember(item) { mutableStateOf(item.optBoolean("is_available", true)) }
    var options by remember(item) { mutableStateOf(parseMenuOptions(item.optJSONArray("options"))) }
    var confirmDelete by remember(item) { mutableStateOf(false) }
    AlertDialog(onDismissRequest = dismiss,
        title = { Text(if (item.text("id").isBlank()) "เพิ่มเมนู" else "แก้ไขเมนู") },
        text = {
            Column(Modifier.heightIn(max = 470.dp).verticalScroll(rememberScrollState())) {
                OutlinedTextField(name, { name = it }, label = { Text("ชื่อเมนู") },
                    modifier = Modifier.fillMaxWidth())
                OutlinedTextField(category, { category = it }, label = { Text("หมวดหมู่") },
                    modifier = Modifier.fillMaxWidth())
                OutlinedTextField(description, { description = it }, label = { Text("รายละเอียด") },
                    modifier = Modifier.fillMaxWidth())
                OutlinedTextField(price, { price = it }, label = { Text("ราคา (บาท)") },
                    modifier = Modifier.fillMaxWidth())
                OutlinedTextField(stock, { stock = it }, label = { Text("จำนวนขายต่อวัน (ว่าง = ไม่จำกัด)") },
                    modifier = Modifier.fillMaxWidth())
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("เปิดขาย", Modifier.weight(1f))
                    Switch(checked = available, onCheckedChange = { available = it })
                }
                HorizontalDivider(Modifier.padding(vertical = 12.dp))
                MenuOptionsEditor(options, onChange = { options = it })
                if (item.text("id").isNotBlank()) {
                    TextButton(onClick = { confirmDelete = true }, enabled = !busy) {
                        Text("ลบเมนู", color = MaterialTheme.colorScheme.error)
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                enabled = !busy && name.isNotBlank() &&
                    (price.toDoubleOrNull()?.let { it >= 0 } == true) &&
                    (stock.isBlank() || (stock.toIntOrNull()?.let { it > 0 } == true)),
                onClick = {
                    val draft = JSONObject(item.toString()).put("name", name).put("category", category)
                        .put("description", description).put("price", price.toDouble())
                        .put("daily_stock_limit", if (stock.isBlank()) JSONObject.NULL else stock.toInt())
                        .put("options", encodeMenuOptions(options))
                        .put("is_available", available)
                    save(draft)
                }) { Text("บันทึก") }
        },
        dismissButton = { TextButton(onClick = dismiss) { Text("ยกเลิก") } }
    )
    if (confirmDelete) {
        AlertDialog(onDismissRequest = { confirmDelete = false },
            title = { Text("ลบเมนูนี้?") },
            text = { Text("การลบรายการอาหารไม่สามารถย้อนกลับได้") },
            confirmButton = {
                Button(enabled = !busy, onClick = { confirmDelete = false; delete(item) }) { Text("ลบเมนู") }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text("ยกเลิก") }
            })
    }
}

@Composable
private fun MoreScreen(vm: MerchantViewModel) {
    val pages = listOf(
        MerchantPage.REPORTS to "รายงานยอดขาย",
        MerchantPage.HISTORY to "ประวัติออเดอร์",
        MerchantPage.FINANCE to "การเงินร้านค้า",
        MerchantPage.STORE to "ตั้งค่าร้าน"
    )
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        SectionHeading("เพิ่มเติม")
        pages.forEach { (page, label) ->
            OutlinedButton(onClick = { vm.openPage(page) }, modifier = Modifier.fillMaxWidth()) { Text(label) }
        }
        Spacer(Modifier.height(16.dp))
        Text("ฟีเจอร์เว็บไซต์ที่กำลังพัฒนาเป็น Native Android", color = Grey)
        listOf("ฟีดแบ็ก", "โปรโมชันร้าน", "แคมเปญ WYNOS", "โฆษณา",
            "ศูนย์การแจ้งเตือน", "จัดการตัวเลือกเสริม/หมวดหมู่", "พิมพ์ใบเสร็จและที่อยู่",
            "แผนที่/พื้นที่จัดส่ง", "ช่วยเหลือ").forEach { label ->
            Text("• " + label, Modifier.padding(vertical = 7.dp), color = Grey)
        }
        Spacer(Modifier.height(12.dp))
        OutlinedButton(onClick = vm::signOut) { Text("ออกจากระบบ") }
    }
}

@Composable
private fun SalesScreen(s: MerchantState, vm: MerchantViewModel) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        SectionHeading("รายงานยอดขาย")
        TextButton(onClick = vm::reloadSales, enabled = !s.busy) { Text("อัปเดตรายงาน") }
        val report = s.sales
        if (report == null) Text("ยังไม่สามารถโหลดรายงานได้")
        else {
            SummaryCard("ยอดขายวันนี้", money(report.amount("today_sales")))
            SummaryCard("ยอดขายสัปดาห์นี้", money(report.amount("week_sales")))
            SummaryCard("ยอดขายเดือนนี้", money(report.amount("month_sales")))
            SummaryCard("จำนวนออเดอร์ทั้งหมด", report.optInt("total_orders").toString())
            SummaryCard("ยอดเฉลี่ยต่อออเดอร์", money(report.amount("average_order")))
        }
    }
}

@Composable
private fun FinanceScreen(s: MerchantState) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        SectionHeading("การเงินร้านค้า")
        Text("ข้อมูลเดือนปัจจุบัน — คำนวณโดย Backend", color = Grey)
        val data = s.finance
        if (data == null) Text("ยังไม่สามารถโหลดข้อมูลการเงินได้ หรือบัญชีไม่มีสิทธิ์ดู")
        else {
            listOf(
                "ยอดขายสุทธิ" to "sales_net",
                "ค่าอาหาร" to "food",
                "ค่าส่ง" to "delivery",
                "ส่วนลดโปรโมชั่น" to "discounts",
                "เงินคืนลูกค้า" to "refunds",
                "ค่าโฆษณา" to "ad_spend",
                "GP WYNOS" to "gp",
                "รายได้ร้าน" to "income"
            ).forEach { (label, field) -> SummaryCard(label, money(data.amount(field))) }
        }
    }
}

@Composable
private fun StoreScreen(s: MerchantState, vm: MerchantViewModel) {
    val store = s.store ?: return
    var name by remember(store) { mutableStateOf(store.text("name")) }
    var phone by remember(store) { mutableStateOf(store.text("phone")) }
    var address by remember(store) { mutableStateOf(store.text("address")) }
    var deliveryArea by remember(store) { mutableStateOf(store.text("delivery_area")) }
    var open by remember(store) { mutableStateOf(store.optBoolean("is_open")) }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        SectionHeading("ตั้งค่าร้าน")
        OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text("ชื่อร้าน") })
        OutlinedTextField(phone, { phone = it }, Modifier.fillMaxWidth(), label = { Text("เบอร์โทรศัพท์") })
        OutlinedTextField(address, { address = it }, Modifier.fillMaxWidth(), label = { Text("ที่อยู่ร้าน") })
        OutlinedTextField(deliveryArea, { deliveryArea = it }, Modifier.fillMaxWidth(), label = { Text("พื้นที่จัดส่ง") })
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("เปิดรับออเดอร์", modifier = Modifier.weight(1f))
            Switch(checked = open, onCheckedChange = { open = it })
        }
        Button(enabled = !s.busy && name.isNotBlank(), onClick = {
            vm.saveStore(JSONObject().put("name", name).put("phone", phone)
                .put("address", address).put("delivery_area", deliveryArea).put("is_open", open))
        }, modifier = Modifier.fillMaxWidth()) { Text("บันทึกข้อมูลร้าน") }
        Text("หมายเหตุ: แผนที่ ตารางเวลา รูปภาพ การตั้งค่าการชำระเงิน และการเผยแพร่ร้าน ยังต้องพัฒนาเพิ่มเติม",
            Modifier.padding(top = 12.dp), color = Grey)
    }
}

@Composable
private fun HistoryScreen(s: MerchantState, vm: MerchantViewModel) {
    Column(Modifier.fillMaxSize().padding(16.dp)) {
        SectionHeading("ประวัติออเดอร์")
        TextButton(onClick = vm::loadHistory, enabled = !s.busy) { Text("รีเฟรช") }
        LazyColumn {
            items(s.history, key = { it.text("id") }) { item ->
                ElevatedCard(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                    Column(Modifier.padding(12.dp)) {
                        Text(item.orderTitle(), fontWeight = FontWeight.Bold)
                        Text(orderStatus(item.text("status")))
                        Text(money(item.amount("total")), color = Red)
                    }
                }
            }
        }
    }
}
