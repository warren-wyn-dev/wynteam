package online.wynos.food.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.NotificationsNone
import androidx.compose.material.icons.outlined.ReceiptLong
import androidx.compose.material.icons.outlined.Redeem
import androidx.compose.material3.Icon
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.TextButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val ZokyMessageRed = Color(0xFFD91F4E)
private val ZokyMessageInk = Color(0xFF24212B)
private val ZokyMessageSub = Color(0xFF66636C)

/** One messages destination with Notifications first, Chats second.
 * Do not fabricate push or chat messages: show only scoped backend data.
 */
@Composable
fun ZokyMessageCenter(
    state: FoodUiState,
    onOrders: () -> Unit,
    onRefresh: () -> Unit,
    onMarkRead: (String) -> Unit,
    onOpenChat: (String) -> Unit,
    onCloseChat: () -> Unit,
    onRefreshChat: () -> Unit,
    onSendChat: (String) -> Unit,
) {
    var selected by rememberSaveable { mutableIntStateOf(0) }
    Column(Modifier.fillMaxSize().background(Color.White)) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 11.dp)
                .clip(RoundedCornerShape(14.dp)).background(Color(0xFFF7F6F8)).padding(4.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            listOf("การแจ้งเตือน", "แชต").forEachIndexed { index, label ->
                Box(
                    Modifier.weight(1f).clip(RoundedCornerShape(11.dp))
                        .background(if (selected == index) Color.White else Color.Transparent)
                        .clickable { selected = index }.padding(vertical = 11.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(label, fontWeight = FontWeight.SemiBold,
                        color = if (selected == index) ZokyMessageRed else ZokyMessageSub,
                        fontSize = 14.sp)
                }
            }
        }
        if (selected == 0) {
            LazyColumn(
                Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(9.dp),
            ) {
                if (state.orderStatusNotice != null) {
                    item(key = "order-notice") {
                        Row(
                            Modifier.fillMaxWidth().clickable(onClick = onOrders)
                                .padding(horizontal = 18.dp, vertical = 15.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            Icon(Icons.Outlined.ReceiptLong, null, tint = ZokyMessageRed,
                                modifier = Modifier.size(29.dp))
                            Column(Modifier.weight(1f)) {
                                Text("อัปเดตคำสั่งซื้อ",
                                    fontWeight = FontWeight.Bold, color = ZokyMessageInk)
                                Text("ออเดอร์ #${state.orderStatusNotice.number}: ${state.orderStatusNotice.status}",
                                    color = ZokyMessageSub, fontSize = 12.sp)
                            }
                        }
                    }
                }
                // Server-read buyer orders are status summaries, not synthetic push events.
                if (state.orders.isNotEmpty()) {
                    items(state.orders.take(8), key = { "order-status-" + it.id }) { order ->
                        Row(
                            Modifier.fillMaxWidth().clickable(onClick = onOrders)
                                .padding(horizontal = 18.dp, vertical = 13.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            Icon(Icons.Outlined.ReceiptLong, null, tint = ZokyMessageRed,
                                modifier = Modifier.size(28.dp))
                            Column(Modifier.weight(1f)) {
                                Text("ออเดอร์ #${order.number}", color = ZokyMessageInk,
                                    fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                Text("สถานะ: ${order.status} · ชำระเงิน: ${order.paymentStatus}",
                                    color = ZokyMessageSub, fontSize = 12.sp)
                            }
                        }
                    }
                }
                if (state.promotions.isNotEmpty()) {
                    items(state.promotions, key = { it.id }) { notice ->
                        Row(
                            Modifier.fillMaxWidth()
                                .clickable { onMarkRead(notice.id) }
                                .padding(horizontal = 18.dp, vertical = 13.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            Icon(Icons.Outlined.Redeem, null, tint = ZokyMessageRed,
                                modifier = Modifier.size(28.dp))
                            Column(Modifier.weight(1f)) {
                                Text(notice.title,
                                    fontWeight = if (notice.isUnread) FontWeight.Bold else FontWeight.Medium,
                                    color = ZokyMessageInk, fontSize = 15.sp)
                                Text(notice.body,
                                    color = ZokyMessageSub, fontSize = 12.sp, maxLines = 3)
                                if (notice.couponCode != null) {
                                    Text("รหัส: ${notice.couponCode} (ต้องตรวจสิทธิ์ก่อนใช้)",
                                        color = ZokyMessageRed, fontSize = 12.sp)
                                }
                            }
                        }
                    }
                }
                if (state.promotions.isEmpty() && state.orders.isEmpty() && state.orderStatusNotice == null) {
                    item(key = "empty-notices") {
                        Column(
                            Modifier.fillMaxWidth().padding(28.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Icon(Icons.Outlined.NotificationsNone, null, tint = ZokyMessageSub,
                                modifier = Modifier.size(40.dp))
                            Text("ยังไม่มีการแจ้งเตือน", color = ZokyMessageInk,
                                fontWeight = FontWeight.Bold)
                            Text(
                                if (state.accountEmail == null)
                                    "เข้าสู่ระบบเพื่อดูการแจ้งเตือนจากบัญชีของคุณ"
                                else
                                    "ข้อมูลคำสั่งซื้อและข่าวสารที่เชื่อมต่อแล้วจะปรากฏที่นี่",
                                color = ZokyMessageSub, fontSize = 13.sp,
                                textAlign = TextAlign.Center)
                        }
                    }
                }
                if (state.accountEmail != null) {
                    item(key = "refresh-notices") {
                        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                            OutlinedButton(onClick = onRefresh) { Text("รีเฟรชการแจ้งเตือน") }
                        }
                    }
                }
            }
        } else {
            if (!state.chatEnabled) {
                Column(
                    Modifier.fillMaxSize().padding(25.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Icon(Icons.Outlined.ChatBubbleOutline, null, tint = ZokyMessageRed,
                        modifier = Modifier.size(43.dp))
                    Spacer(Modifier.size(13.dp))
                    Text("แชตกับร้านอาหาร", fontWeight = FontWeight.Bold,
                        color = ZokyMessageInk, fontSize = 19.sp)
                    Spacer(Modifier.size(6.dp))
                    Text("ระบบแชตยังไม่เปิดใช้งานใน APK นี้\\nต้องผ่านการทดสอบ Staging และสิทธิ์ของร้านก่อน",
                        color = ZokyMessageSub, fontSize = 13.sp, textAlign = TextAlign.Center)
                }
            } else if (state.accountEmail == null) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("เข้าสู่ระบบเพื่อแชตเกี่ยวกับออเดอร์ของคุณ",
                        color = ZokyMessageSub, textAlign = TextAlign.Center)
                }
            } else if (state.chatOrderId == null) {
                LazyColumn(Modifier.fillMaxSize(), contentPadding =
                    androidx.compose.foundation.layout.PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    item {
                        Text("เลือกออเดอร์เพื่อแชตกับร้าน", color = ZokyMessageInk,
                            fontWeight = FontWeight.Bold, fontSize = 17.sp)
                    }
                    if (state.orders.isEmpty()) {
                        item { Text("ยังไม่มีออเดอร์ที่สามารถเริ่มแชตได้", color = ZokyMessageSub) }
                    }
                    items(state.orders, key = { it.id }) { order ->
                        Row(
                            Modifier.fillMaxWidth()
                                .clip(RoundedCornerShape(14.dp))
                                .background(Color(0xFFFFF0F4))
                                .clickable { onOpenChat(order.id) }
                                .padding(15.dp),
                            verticalAlignment = Alignment.CenterVertically) {
                            Text("ออเดอร์ #${order.number}",
                                color = ZokyMessageInk, fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.weight(1f))
                            Text("แชต  ›", color = ZokyMessageRed, fontSize = 13.sp)
                        }
                    }
                }
            } else {
                var draft by remember(state.chatOrderId) { mutableStateOf("") }
                var submitted by remember(state.chatOrderId) { mutableStateOf("") }
                LaunchedEffect(state.chatSending, state.chatSendFailed) {
                    if (submitted.isNotEmpty() && !state.chatSending) {
                        if (state.chatSendFailed) draft = submitted
                        submitted = ""
                    }
                }
                Column(Modifier.fillMaxSize().padding(horizontal = 14.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        TextButton(onClick = onCloseChat) { Text("‹ ออเดอร์ทั้งหมด") }
                        Text("แชตออเดอร์", color = ZokyMessageInk,
                            fontWeight = FontWeight.Bold)
                    }
                    if (state.chatFailed) {
                        Text("โหลดแชตไม่สำเร็จ", color = ZokyMessageRed)
                    }
                    OutlinedButton(onClick = onRefreshChat) { Text("รีเฟรชข้อความ") }
                    LazyColumn(Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(state.chatMessages, key = { it.id }) { msg ->
                            Box(Modifier.fillMaxWidth(),
                                contentAlignment = if (msg.isMine) Alignment.CenterEnd
                                                   else Alignment.CenterStart) {
                                Text(msg.body,
                                    modifier = Modifier.clip(RoundedCornerShape(15.dp))
                                        .background(if (msg.isMine) Color(0xFFFFE1EA)
                                                    else Color(0xFFF3F3F5))
                                        .padding(12.dp),
                                    fontSize = 14.sp, color = ZokyMessageInk)
                            }
                        }
                    }
                    if (state.chatSendFailed) {
                        Text("ส่งไม่สำเร็จ ข้อความของคุณยังไม่ได้ถูกยืนยัน",
                            color = ZokyMessageRed, fontSize = 12.sp)
                    }
                    OutlinedTextField(
                        value = draft, onValueChange = { if (it.length <= 1200) draft = it },
                        placeholder = { Text("พิมพ์ข้อความถึงร้านอาหาร…") },
                        modifier = Modifier.fillMaxWidth(),
                        maxLines = 4,
                    )
                    Button(
                        onClick = {
                            submitted = draft.trim()
                            onSendChat(submitted)
                            draft = ""
                        },
                        enabled = draft.isNotBlank() && !state.chatSending,
                    ) { Text(if (state.chatSending) "กำลังส่ง…" else "ส่งข้อความ") }
                    Spacer(Modifier.size(6.dp))
                }
            }
        }
    }
}
