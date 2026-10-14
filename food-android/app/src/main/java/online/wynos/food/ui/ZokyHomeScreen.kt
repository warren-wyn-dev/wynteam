package online.wynos.food.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.ArrowForwardIos
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.LocalOffer
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Zoky service hub. Food browsing/search remains a separate native destination. */
private val ZokyRed = Color(0xFFD91F4E)
private val ZokyPink = Color(0xFFFF7196)
private val ZokyInk = Color(0xFF24212B)
private val ZokySub = Color(0xFF66636C)
private val ZokyBlush = Color(0xFFFFF0F4)

@Composable
fun ZokyHomeScreen(
    state: FoodUiState,
    onFood: () -> Unit,
    onFavorites: () -> Unit,
    onDeals: () -> Unit,
    onLocation: () -> Unit,
) {
    var slide by rememberSaveable { mutableIntStateOf(0) }
    LazyColumn(
        modifier = Modifier.fillMaxSize().background(Color.White),
        horizontalAlignment = Alignment.CenterHorizontally,
        contentPadding = PaddingValues(bottom = 32.dp),
    ) {
        item(key = "zoky-logo-and-favorite") {
            Row(
                Modifier.widthIn(max = 720.dp).fillMaxWidth()
                    .padding(start = 18.dp, end = 14.dp, top = 16.dp, bottom = 13.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text("Zoky", fontSize = 35.sp, lineHeight = 42.sp,
                        color = ZokyRed, fontWeight = FontWeight.ExtraBold)
                    Row(
                        Modifier.clip(RoundedCornerShape(10.dp))
                            .clickable(onClick = onLocation).padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Outlined.LocationOn, null, tint = ZokyRed,
                            modifier = Modifier.size(19.dp))
                        Spacer(Modifier.width(3.dp))
                        Text("เลือกที่อยู่จัดส่ง", color = ZokySub, fontSize = 13.sp)
                        Text("  ⌄", color = ZokySub, fontSize = 18.sp)
                    }
                }
                Box(Modifier.size(49.dp).clip(CircleShape).background(ZokyBlush),
                    contentAlignment = Alignment.Center) {
                    IconButton(onClick = onFavorites) {
                        Icon(Icons.Filled.Favorite, contentDescription = "รายการโปรด",
                            tint = ZokyRed, modifier = Modifier.size(25.dp))
                    }
                }
            }
        }
        item(key = "zoky-hero") {
            Box(Modifier.widthIn(max = 720.dp).fillMaxWidth().padding(horizontal = 14.dp)) {
                Row(
                    Modifier.fillMaxWidth().height(155.dp)
                        .shadow(2.dp, RoundedCornerShape(20.dp))
                        .clip(RoundedCornerShape(20.dp))
                        .background(Brush.horizontalGradient(listOf(Color(0xFFE70043), ZokyRed, ZokyPink)))
                        .clickable(onClick = onDeals)
                        .padding(start = 17.dp, end = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1.2f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Text("ดีลคุ้ม!", color = Color.White, fontWeight = FontWeight.ExtraBold,
                            fontSize = 31.sp, lineHeight = 33.sp, maxLines = 1)
                        Text("ดีลแรงวันนี้", color = Color.White, fontWeight = FontWeight.Bold,
                            fontSize = 23.sp, lineHeight = 26.sp, maxLines = 1)
                        Text("อร่อยง่าย ส่งไว ใกล้คุณ", color = Color.White,
                            fontSize = 11.sp, maxLines = 1)
                        Row(
                            Modifier.clip(CircleShape).background(Color.White)
                                .clickable(onClick = onDeals)
                                .padding(horizontal = 12.dp, vertical = 7.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text("ดูดีลทั้งหมด", color = ZokyRed, fontSize = 12.sp,
                                fontWeight = FontWeight.Bold)
                            Icon(Icons.Outlined.ArrowForwardIos, null, tint = ZokyRed,
                                modifier = Modifier.padding(start = 6.dp).size(11.dp))
                        }
                    }
                    // Decorative illustration only: no invented discount amount or merchant offer.
                    Box(Modifier.weight(.86f), contentAlignment = Alignment.Center) {
                        Text("🍔", fontSize = 84.sp, lineHeight = 100.sp)
                        Text("🍟", modifier = Modifier.align(Alignment.BottomEnd),
                            fontSize = 39.sp)
                        Text("🥤", modifier = Modifier.align(Alignment.TopEnd),
                            fontSize = 35.sp)
                    }
                }
            }
        }
        item(key = "hero-dots") {
            Row(
                Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 12.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                repeat(4) { index ->
                    Box(Modifier.padding(horizontal = 3.dp)
                        .size(if (slide == index) 18.dp else 7.dp, 7.dp)
                        .clip(CircleShape)
                        .background(if (slide == index) ZokyRed else Color(0xFFE1E1E6))
                        .clickable { slide = index })
                }
            }
        }
        item(key = "service-label") {
            Text("บริการของ Zoky",
                modifier = Modifier.widthIn(max = 720.dp).fillMaxWidth()
                    .padding(horizontal = 17.dp, vertical = 6.dp),
                fontSize = 21.sp, fontWeight = FontWeight.ExtraBold, color = ZokyInk)
        }
        item(key = "food-entry") {
            Row(
                Modifier.widthIn(max = 720.dp).fillMaxWidth()
                    .padding(horizontal = 14.dp, vertical = 5.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(Brush.horizontalGradient(listOf(Color(0xFFFFF0F3), Color(0xFFFFDFEA))))
                    .clickable(onClick = onFood)
                    .height(148.dp).padding(start = 17.dp, end = 7.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1.15f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text("สั่งอาหาร", fontSize = 27.sp, color = ZokyInk,
                        fontWeight = FontWeight.ExtraBold, maxLines = 1)
                    Text("ร้านอร่อยใกล้คุณ\nเลือกเมนูโปรดได้ง่าย", color = ZokySub,
                        fontSize = 12.sp, lineHeight = 17.sp)
                    Row(
                        Modifier.clip(CircleShape).background(ZokyRed)
                            .clickable(onClick = onFood)
                            .padding(horizontal = 16.dp, vertical = 7.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("เลือกอาหาร", color = Color.White, fontWeight = FontWeight.Bold,
                            fontSize = 13.sp)
                        Icon(Icons.Outlined.ArrowForwardIos, null, tint = Color.White,
                            modifier = Modifier.padding(start = 9.dp).size(12.dp))
                    }
                }
                Box(Modifier.weight(.9f), contentAlignment = Alignment.Center) {
                    Box(Modifier.size(134.dp).clip(CircleShape)
                        .background(Color(0xFFFFCCD9)))
                    Text("🍛", fontSize = 86.sp, lineHeight = 90.sp)
                    Text("🍳", modifier = Modifier.align(Alignment.TopEnd),
                        fontSize = 36.sp)
                }
            }
        }
        item(key = "deals-title") {
            Row(
                Modifier.widthIn(max = 720.dp).fillMaxWidth()
                    .padding(start = 17.dp, end = 17.dp, top = 20.dp, bottom = 9.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("ดีลคุ้ม! ดีลแรงวันนี้", modifier = Modifier.weight(1f),
                    fontSize = 21.sp, color = ZokyInk, fontWeight = FontWeight.ExtraBold)
                Text("ดูทั้งหมด  ›", color = ZokyRed, fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clip(RoundedCornerShape(8.dp))
                        .clickable(onClick = onDeals).padding(vertical = 6.dp))
            }
        }
        if (state.promotions.isNotEmpty()) {
            item(key = "verified-offers") {
                LazyRow(
                    modifier = Modifier.widthIn(max = 720.dp).fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 4.dp),
                ) {
                    items(state.promotions.take(8), key = { it.id }) { promotion ->
                        Column(
                            Modifier.width(225.dp).shadow(2.dp, RoundedCornerShape(15.dp))
                                .clip(RoundedCornerShape(15.dp)).background(Color.White)
                                .clickable(onClick = onDeals),
                        ) {
                            Box(Modifier.fillMaxWidth().height(114.dp)
                                .background(Brush.horizontalGradient(listOf(
                                    Color(0xFFFFC0D2), Color(0xFFFFEEF2)))),
                                contentAlignment = Alignment.Center,
                            ) {
                                Icon(Icons.Outlined.LocalOffer, null, tint = ZokyRed,
                                    modifier = Modifier.size(45.dp))
                            }
                            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                                Text(promotion.title, color = ZokyInk,
                                    fontWeight = FontWeight.Bold, fontSize = 14.sp,
                                    maxLines = 2, overflow = TextOverflow.Ellipsis)
                                Text("ดูรายละเอียดและตรวจสอบเงื่อนไข",
                                    color = ZokySub, fontSize = 11.sp)
                            }
                        }
                    }
                }
            }
        } else {
            item(key = "offers-not-available") {
                Row(
                    Modifier.widthIn(max = 720.dp).fillMaxWidth()
                        .padding(horizontal = 14.dp)
                        .clip(RoundedCornerShape(16.dp)).background(ZokyBlush)
                        .clickable(onClick = onDeals)
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text("🍕", fontSize = 40.sp)
                    Column(Modifier.weight(1f)) {
                        Text("ดีลใหม่ ๆ กำลังมา", color = ZokyInk,
                            fontWeight = FontWeight.Bold, fontSize = 15.sp)
                        Text("ตรวจสอบโปรโมชันได้ที่แท็บข้อความ",
                            color = ZokySub, fontSize = 12.sp)
                    }
                    Icon(Icons.Outlined.ArrowForwardIos, null, tint = ZokyRed,
                        modifier = Modifier.size(15.dp))
                }
            }
        }
    }
}
