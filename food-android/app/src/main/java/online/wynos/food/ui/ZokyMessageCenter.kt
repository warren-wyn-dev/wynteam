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
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
                if (state.promotions.isNotEmpty()) {
                    items(state.promotions, key = { it.id }) { notice ->
                        Row(
                            Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 13.dp),
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
                if (state.promotions.isEmpty() && state.orderStatusNotice == null) {
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
                Text("กำลังเชื่อมต่อระบบแชตจริง\nยังไม่เปิดรับส่งข้อความใน APK ทดสอบ",
                    color = ZokyMessageSub, fontSize = 13.sp, textAlign = TextAlign.Center)
            }
        }
    }
}
