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
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.ui.input.pointer.pointerInput
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
        LoginScreen(busy = s.busy, error = s.error, notice = s.notice,
            onSignIn = vm::signIn, onReset = vm::requestPasswordReset)
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
                MerchantPage.FINANCE -> FinanceScreen(s, vm)
                MerchantPage.STORE -> StoreScreen(s, vm)
                MerchantPage.HISTORY -> HistoryScreen(s, vm)
                MerchantPage.FEEDBACK, MerchantPage.PROMOTIONS, MerchantPage.CAMPAIGNS,
                MerchantPage.ADS, MerchantPage.NOTIFICATIONS, MerchantPage.STAFF,
                MerchantPage.HELP -> MerchantExtraScreen(s.page, s, vm)
            }
        }
    }
}

@Composable
private fun LoginScreen(busy: Boolean, error: String, notice: String,
    onSignIn: (String, String) -> Unit, onReset: (String) -> Unit) {
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
        TextButton(onClick = { onReset(email) }, enabled = !busy && email.contains("@"),
            modifier = Modifier.fillMaxWidth()) { Text("ลืมรหัสผ่าน? ส่งลิงก์ตั้งรหัสผ่านใหม่") }
        if (notice.isNotEmpty()) Text(notice, color = Grey,
            modifier = Modifier.padding(top = 8.dp))
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
        if (s.hasMoreOrders) Text("มีออเดอร์เก่ากว่านี้ กดโหลดเพิ่มด้านล่าง", color = Grey)
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
            if (s.hasMoreOrders) item {
                OutlinedButton(onClick = vm::loadMoreOrders, enabled = !s.busy,
                    modifier = Modifier.fillMaxWidth()) { Text("โหลดออเดอร์เก่ากว่านี้") }
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
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = {
                state.store?.let { MerchantPrinter.print(context, it, order, false) }
            }) { Text("พิมพ์ใบเสร็จ") }
            OutlinedButton(onClick = {
                state.store?.let { MerchantPrinter.print(context, it, order, true) }
            }) { Text("พิมพ์ใบจ่าหน้า") }
        }
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
    var managingCategories by remember { mutableStateOf(false) }
    if (managingCategories) {
        MerchantCategoryManager(s, vm, onClose = { managingCategories = false })
        return
    }
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
        TextButton(onClick = { managingCategories = true }) { Text("จัดการหมวดหมู่") }
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
                val moveItem: (Int) -> Unit = { delta ->
                    val oldIndex = orderIds.indexOf(item.text("id"))
                    val target = oldIndex + delta
                    val targets = orderIds.mapNotNull { id -> s.menu.find { it.text("id") == id } }
                    if (oldIndex >= 0 && target in targets.indices &&
                        targets[oldIndex].text("category") == targets[target].text("category")) {
                        orderIds = orderIds.toMutableList().apply { add(target, removeAt(oldIndex)) }
                    }
                }
                val latestMove by rememberUpdatedState(moveItem)
                val drag = if (sorting) Modifier.pointerInput(item.text("id")) {
                    var deltaY = 0f
                    detectDragGesturesAfterLongPress(
                        onDragStart = { deltaY = 0f },
                        onDragEnd = { deltaY = 0f },
                        onDragCancel = { deltaY = 0f },
                        onDrag = { change, amount ->
                            change.consume()
                            deltaY += amount.y
                            val threshold = 52.dp.toPx()
                            if (deltaY > threshold) {
                                latestMove(1)
                                deltaY = 0f
                            } else if (deltaY < -threshold) {
                                latestMove(-1)
                                deltaY = 0f
                            }
                        }
                    )
                } else Modifier
                ElevatedCard(modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp).then(drag)) {
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
private fun MenuEditor(item: JSONObject, busy: Boolean, save: (JSONObject, Uri?) -> Unit,
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
    var imageUri by remember(item) { mutableStateOf<Uri?>(null) }
    var clearImage by remember(item) { mutableStateOf(false) }
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
                MerchantImagePicker("รูปเมนูอาหาร", imageUri,
                    if (clearImage) null else item.text("image_path"), !busy,
                    onSelect = { imageUri = it; if (it != null) clearImage = false })
                if (item.text("image_path").isNotBlank() && !clearImage) {
                    TextButton(enabled = !busy, onClick = {
                        imageUri = null; clearImage = true
                    }) { Text("ลบรูปเดิม") }
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
                    if (clearImage) draft.put("image_path", JSONObject.NULL)
                    save(draft, imageUri)
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
        MerchantPage.FEEDBACK to "ฟีดแบ็ก",
        MerchantPage.FINANCE to "การเงินร้านค้า",
        MerchantPage.PROMOTIONS to "โปรโมชั่นของร้าน",
        MerchantPage.CAMPAIGNS to "แคมเปญ WYNOS",
        MerchantPage.ADS to "โฆษณา",
        MerchantPage.STORE to "ตั้งค่าร้าน",
        MerchantPage.STAFF to "จัดการทีมงาน",
        MerchantPage.NOTIFICATIONS to "การแจ้งเตือน",
        MerchantPage.HELP to "ช่วยเหลือ"
    )
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        SectionHeading("เพิ่มเติม")
        pages.forEach { (page, label) ->
            OutlinedButton(onClick = { vm.openPage(page) }, modifier = Modifier.fillMaxWidth()) {
                Text(label)
            }
        }
        Spacer(Modifier.height(16.dp))
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
private fun FinanceScreen(s: MerchantState, vm: MerchantViewModel) {
    val context = LocalContext.current
    val fields = listOf(
        "ยอดขายสุทธิ" to "sales_net", "ค่าอาหาร" to "food", "ค่าส่ง" to "delivery",
        "ส่วนลดโปรโมชั่น" to "discounts", "คืนเงินลูกค้า" to "refunds",
        "ค่าโฆษณา" to "ad_spend", "GP WYNOS" to "gp",
        "WYNOS ร่วมจ่ายส่วนลด" to "platform_funded", "รายได้ร้าน" to "income")
    val csvPicker = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri ->
        val info = s.finance
        if (uri != null && info != null) {
            val csv = buildString {
                append("\uFEFFรายการ,จำนวนเงิน (บาท)\n")
                append("ช่วงเริ่มต้น,").append(s.financeFrom).append("\n")
                append("สิ้นสุด,").append(s.financeTo).append("\n")
                fields.forEach { (title, key) ->
                    append("\"").append(title).append("\",")
                    append(info.optDouble(key, 0.0)).append("\n")
                }
            }
            runCatching {
                context.contentResolver.openOutputStream(uri)?.use { stream ->
                    stream.write(csv.toByteArray(Charsets.UTF_8))
                }
            }
        }
    }
    var customStart by remember(s.financeFrom) { mutableStateOf(s.financeFrom) }
    var customEnd by remember(s.financeTo) { mutableStateOf(s.financeTo) }
    val today = java.time.LocalDate.now(java.time.ZoneId.of("Asia/Bangkok"))
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        SectionHeading("การเงินร้านค้า")
        Text("ยอดเงินและค่าธรรมเนียมคำนวณจาก Backend · เวลาไทย", color = Grey)
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            listOf("วันนี้" to (today to today),
                "เมื่อวาน" to (today.minusDays(1) to today.minusDays(1)),
                "สัปดาห์" to (today.minusDays((today.dayOfWeek.value - 1).toLong()) to today),
                "เดือน" to (today.withDayOfMonth(1) to today)).forEach { (label, range) ->
                FilterChip(selected = s.financeFrom == range.first.toString() &&
                    s.financeTo == range.second.toString(),
                    onClick = { vm.setFinanceRange(range.first.toString(), range.second.toString()) },
                    label = { Text(label, style = MaterialTheme.typography.labelSmall) })
            }
        }
        OutlinedTextField(customStart, { customStart = it },
            label = { Text("เริ่มต้น YYYY-MM-DD") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(customEnd, { customEnd = it },
            label = { Text("สิ้นสุด YYYY-MM-DD") }, modifier = Modifier.fillMaxWidth())
        Button(onClick = { vm.setFinanceRange(customStart, customEnd) },
            enabled = !s.busy, modifier = Modifier.fillMaxWidth()) { Text("ดูช่วงวันที่เลือก") }
        Text("ช่วง " + s.financeFrom + " ถึง " + s.financeTo)
        val data = s.finance
        if (data == null) Text("ยังไม่สามารถโหลดข้อมูลการเงินได้ หรือบัญชีไม่มีสิทธิ์ดู")
        else {
            SummaryCard("ยอดขายสุทธิ", money(data.amount("sales_net")))
            SummaryCard("รายได้ร้าน", money(data.amount("income")))
            fields.filterNot { it.second in listOf("sales_net", "income") }.forEach { (label, key) ->
                SummaryCard(label, money(data.amount(key)))
            }
            if (data.optInt("pending_slip_count") > 0) {
                Text("รอตรวจสลิป " + data.optInt("pending_slip_count") + " ออเดอร์", color = Red)
                TextButton(onClick = { vm.openPage(MerchantPage.ORDERS) }) { Text("ไปหน้าออเดอร์") }
            }
            OutlinedButton(
                onClick = { csvPicker.launch("wynos-finance-" + s.financeFrom + "_" + s.financeTo + ".csv") },
                modifier = Modifier.fillMaxWidth()
            ) { Text("ดาวน์โหลด CSV") }
        }
        val stripe = s.stripeStatus
        if (stripe != null && stripe.optBoolean("connected")) {
            SectionHeading("Stripe")
            SummaryCard("ยอดรอดำเนินการ", money(stripe.optDouble("balance_pending_satang") / 100.0))
            SummaryCard("พร้อมโอน", money(stripe.optDouble("balance_available_satang") / 100.0))
            SummaryCard("โอนเข้าบัญชีวันนี้", money(stripe.optDouble("payouts_paid_today_satang") / 100.0))
            Text("สถานะการรับเงิน: " + stripe.optString("status"))
        }
    }
}

@Composable
private fun StoreScreen(s: MerchantState, vm: MerchantViewModel) {
    MerchantStoreSettings(s, vm)
}

@Composable
private fun HistoryScreen(s: MerchantState, vm: MerchantViewModel) {
    Column(Modifier.fillMaxSize().padding(16.dp)) {
        SectionHeading("ประวัติออเดอร์")
        OutlinedTextField(value = s.historySearch, onValueChange = vm::setHistorySearch,
            label = { Text("ค้นหาเลขออเดอร์") },
            modifier = Modifier.fillMaxWidth(), singleLine = true)
        Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            listOf("all" to "ทั้งหมด", "delivered" to "ส่งสำเร็จ",
                "cancelled" to "ยกเลิก").forEach { (key, label) ->
                FilterChip(selected = s.historyStatus == key,
                    onClick = { vm.setHistoryStatus(key) }, label = { Text(label) })
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            listOf(null to "ทั้งหมด", 7 to "7 วัน", 30 to "30 วัน").forEach { (key, label) ->
                FilterChip(selected = s.historyDays == key,
                    onClick = { vm.setHistoryDays(key) }, label = { Text(label) })
            }
        }
        OutlinedButton(onClick = { vm.loadHistory() }, enabled = !s.busy,
            modifier = Modifier.fillMaxWidth()) { Text("ค้นหา / รีเฟรช") }
        if (s.history.isEmpty()) Text("ไม่พบประวัติออเดอร์", color = Grey)
        LazyColumn {
            items(s.history, key = { it.text("id") }) { item ->
                ElevatedCard(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                    Column(Modifier.padding(12.dp)) {
                        Text(item.orderTitle(), fontWeight = FontWeight.Bold)
                        Text(orderStatus(item.text("status")))
                        Text(money(item.amount("total")), color = Red)
                        Text(item.text("created_at"), color = Grey,
                            style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
            if (s.historyHasMore) item {
                Button(onClick = { vm.loadHistory(true) },
                    enabled = !s.busy, modifier = Modifier.fillMaxWidth()) {
                    Text("โหลดออเดอร์เก่ากว่านี้")
                }
            }
        }
    }
}
