package online.wynos.food.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.LocalOffer
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val FeatureRed = Color(0xFFD91F4E)
private val FeatureInk = Color(0xFF24212B)
private val FeatureMuted = Color(0xFF66636C)
private val FeaturePink = Color(0xFFFFF0F4)

/** Actual saved addresses from the signed-in buyer, never a device GPS guess. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ZokyHomeAddressPicker(
    state: FoodUiState,
    onDismiss: () -> Unit,
    onSelect: (String) -> Unit,
    onRefresh: () -> Unit,
    onManage: () -> Unit,
    onSignIn: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = Color.White) {
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("เลือกที่อยู่จัดส่ง", color = FeatureInk,
                fontWeight = FontWeight.ExtraBold, fontSize = 23.sp)
            if (state.accountEmail == null) {
                Text("เข้าสู่ระบบเพื่อเลือกที่อยู่ที่บันทึกไว้", color = FeatureMuted)
                Button(onClick = onSignIn,
                    colors = ButtonDefaults.buttonColors(containerColor = FeatureRed)) {
                    Text("เข้าสู่ระบบ")
                }
            } else {
                when {
                    state.addressesLoading -> CircularProgressIndicator(color = FeatureRed)
                    state.addressesFailed -> Text("โหลดที่อยู่ไม่สำเร็จ กรุณาลองอีกครั้ง", color = FeatureRed)
                    state.addresses.isEmpty() ->
                        Text("ยังไม่มีที่อยู่จัดส่ง กรุณาเพิ่มที่อยู่ในหน้าบัญชี", color = FeatureMuted)
                    else -> state.addresses.forEach { address ->
                        Row(
                            Modifier.fillMaxWidth()
                                .clip(RoundedCornerShape(14.dp))
                                .background(if (address.id == state.selectedAddressId) FeaturePink
                                            else Color(0xFFF8F8FA))
                                .clickable { onSelect(address.id) }
                                .padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            Icon(Icons.Outlined.LocationOn, null, tint = FeatureRed)
                            Column(Modifier.weight(1f)) {
                                Text(address.label, color = FeatureInk, fontWeight = FontWeight.Bold)
                                Text(address.address, color = FeatureMuted,
                                    fontSize = 12.sp, maxLines = 3,
                                    overflow = TextOverflow.Ellipsis)
                            }
                            if (address.id == state.selectedAddressId) {
                                Text("เลือกอยู่", fontSize = 11.sp,
                                    color = FeatureRed, fontWeight = FontWeight.Bold)
                            } else {
                                Icon(Icons.Outlined.ChevronRight, null, tint = FeatureMuted)
                            }
                        }
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedButton(onClick = onRefresh) { Text("รีเฟรช") }
                    Button(
                        onClick = onManage,
                        colors = ButtonDefaults.buttonColors(containerColor = FeatureRed),
                    ) { Text("จัดการที่อยู่") }
                }
            }
            Spacer(Modifier.height(14.dp))
        }
    }
}

/** Campaign inbox is not the same as verified coupon eligibility.
 * No invented merchant discounts, checkout, or coupon claims.
 */
@Composable
fun ZokyHomeDealsPage(
    state: FoodUiState,
    onBack: () -> Unit,
    onRefresh: () -> Unit,
    onBrowseFood: () -> Unit,
    onSignIn: () -> Unit,
    onMarkRead: (String) -> Unit,
) {
    var selectedId by remember { mutableStateOf<String?>(null) }
    val selected = state.promotions.firstOrNull { it.id == selectedId }
    Column(Modifier.background(Color.White)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) {
                Icon(Icons.Outlined.ArrowBack, contentDescription = "ย้อนกลับ")
            }
            Text("ดีลและโปรโมชัน", fontSize = 22.sp,
                fontWeight = FontWeight.ExtraBold, color = FeatureInk)
        }
        LazyColumn(contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item {
                Text("โปรโมชั่นจริงจาก Zoky เท่านั้น ตรวจสอบเงื่อนไขกับระบบก่อนใช้ส่วนลด",
                    color = FeatureMuted, fontSize = 12.sp)
            }
            if (state.accountEmail == null) {
                item {
                    Text("เข้าสู่ระบบเพื่อดูข้อเสนอที่ส่งถึงบัญชีของคุณ",
                        color = FeatureInk, fontSize = 14.sp)
                    Button(onClick = onSignIn,
                        colors = ButtonDefaults.buttonColors(containerColor = FeatureRed)) {
                        Text("เข้าสู่ระบบ")
                    }
                }
            } else {
                when {
                    state.promotionsLoading -> item {
                        CircularProgressIndicator(color = FeatureRed)
                    }
                    state.promotionsFailed -> item {
                        Text("โหลดโปรโมชันไม่สำเร็จ", color = FeatureRed)
                        OutlinedButton(onClick = onRefresh) { Text("ลองอีกครั้ง") }
                    }
                    state.promotions.isEmpty() -> item {
                        Text("ขณะนี้ยังไม่มีโปรโมชันสำหรับบัญชีนี้", color = FeatureMuted)
                        OutlinedButton(onClick = onRefresh) { Text("ตรวจสอบอีกครั้ง") }
                    }
                    else -> {
                        items(state.promotions, key = { it.id }) { notice ->
                            Row(
                                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp))
                                    .background(FeaturePink)
                                    .clickable { selectedId = notice.id; onMarkRead(notice.id) }
                                    .padding(14.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                Box(Modifier.size(43.dp).background(Color.White, CircleShape),
                                    contentAlignment = Alignment.Center) {
                                    Icon(Icons.Outlined.LocalOffer, null, tint = FeatureRed)
                                }
                                Column(Modifier.weight(1f)) {
                                    Text(notice.title, color = FeatureInk,
                                        fontWeight = FontWeight.Bold, maxLines = 2)
                                    Text(notice.body, color = FeatureMuted,
                                        fontSize = 12.sp, maxLines = 2,
                                        overflow = TextOverflow.Ellipsis)
                                    notice.couponCode?.let { code ->
                                        Text("โค้ด: $code", color = FeatureRed, fontSize = 12.sp)
                                    }
                                }
                                Icon(Icons.Outlined.ChevronRight, null, tint = FeatureRed)
                            }
                        }
                    }
                }
            }
            item {
                HorizontalDivider(color = Color(0xFFE9E8EE))
                Text("มองหาเมนูอร่อยเพิ่มเติม?", color = FeatureInk,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(top = 10.dp))
                OutlinedButton(onClick = onBrowseFood) { Text("ไปหน้าสั่งอาหาร") }
            }
        }
    }
    if (selected != null) {
        AlertDialog(
            onDismissRequest = { selectedId = null },
            title = { Text(selected.title) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(selected.body)
                    selected.couponCode?.let { Text("โค้ด: $it", color = FeatureRed) }
                    Text("โปรโมชันนี้ไม่รับรองสิทธิ์ส่วนลดจนกว่าจะตรวจสอบกับระบบ",
                        fontSize = 12.sp, color = FeatureMuted)
                }
            },
            confirmButton = {
                TextButton(onClick = { selectedId = null }) { Text("ปิด") }
            },
        )
    }
}
