package online.wynos.food.ui

import android.graphics.BitmapFactory
import android.util.Base64
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
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
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Artwork is from the owner's approved mockup and embedded for offline QA.
 * Assets contain the mockup's Thai copy; screen readers receive descriptions.
 * Do not use illustrative mock offer amounts as server-confirmed discounts.
 */
private val ZokyRed = Color(0xFFD91F4E)
private val ZokyInk = Color(0xFF24212B)
private val ZokySub = Color(0xFF66636C)
private val ZokyBlush = Color(0xFFFFF0F4)

@Composable
private fun ZokyArt(
    name: String,
    description: String,
    modifier: Modifier = Modifier,
    scale: ContentScale = ContentScale.FillBounds,
) {
    val context = LocalContext.current
    val image = remember(context, name) {
        runCatching {
            val encoded = context.assets.open("$name.webp.b64")
                .bufferedReader().use { it.readText() }
            val bytes = Base64.decode(encoded.trim(), Base64.DEFAULT)
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap()
        }.getOrNull()
    }
    if (image != null) {
        Image(
            bitmap = image,
            contentDescription = description,
            modifier = modifier,
            contentScale = scale,
        )
    } else {
        Box(modifier.background(ZokyBlush), contentAlignment = Alignment.Center) {
            Text(description, fontSize = 14.sp, color = ZokyInk)
        }
    }
}

/**
 * Dedicated native Zoky service hub, not the Food restaurant catalog.
 * UI reference: user's approved pink mockup. No search field or emoji artwork.
 */
@Composable
fun ZokyHomeScreen(
    state: FoodUiState,
    onFood: () -> Unit,
    onFavorites: () -> Unit,
    onDeals: () -> Unit,
    onLocation: () -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize().background(Color.White),
        horizontalAlignment = Alignment.CenterHorizontally,
        contentPadding = PaddingValues(bottom = 30.dp),
    ) {
        item(key = "zoky-header") {
            Row(
                Modifier.widthIn(max = 720.dp).fillMaxWidth()
                    .padding(start = 19.dp, end = 15.dp, top = 12.dp, bottom = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text("Zoky", fontSize = 36.sp, lineHeight = 43.sp,
                        color = ZokyRed, fontWeight = FontWeight.ExtraBold)
                    Row(
                        Modifier.clip(RoundedCornerShape(9.dp)).clickable(onClick = onLocation)
                            .padding(vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Outlined.LocationOn, null, tint = ZokyRed,
                            modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("เลือกที่อยู่จัดส่ง", color = ZokySub,
                            fontSize = 13.sp, maxLines = 1)
                        Icon(Icons.Outlined.ChevronRight, null, tint = ZokySub,
                            modifier = Modifier.padding(start = 4.dp).size(15.dp))
                    }
                }
                Box(Modifier.size(48.dp).clip(CircleShape).background(ZokyBlush),
                    contentAlignment = Alignment.Center) {
                    IconButton(onClick = onFavorites) {
                        Icon(Icons.Filled.Favorite, "รายการโปรด", tint = ZokyRed,
                            modifier = Modifier.size(24.dp))
                    }
                }
            }
        }
        item(key = "zoky-approved-hero") {
            ZokyArt(
                "zoky_hero",
                "ดีลคุ้ม ดีลแรงวันนี้ อร่อยง่าย ส่งไว ใกล้คุณ ดูดีลทั้งหมด",
                modifier = Modifier.widthIn(max = 720.dp).fillMaxWidth()
                    .padding(horizontal = 14.dp)
                    .aspectRatio(514f / 220f)
                    .clip(RoundedCornerShape(18.dp))
                    .clickable(onClick = onDeals),
            )
        }
        item(key = "zoky-hero-indicator") {
            // One verified local banner: never show non-functional carousel pages.
            Box(
                Modifier.padding(top = 8.dp, bottom = 10.dp)
                    .size(width = 18.dp, height = 6.dp).clip(CircleShape)
                    .background(ZokyRed),
            )
        }
        item(key = "zoky-services-heading") {
            Text("บริการของ Zoky",
                modifier = Modifier.widthIn(max = 720.dp).fillMaxWidth()
                    .padding(start = 17.dp, end = 17.dp, top = 3.dp, bottom = 7.dp),
                fontSize = 20.sp, fontWeight = FontWeight.ExtraBold,
                color = ZokyInk)
        }
        item(key = "zoky-approved-food-card") {
            ZokyArt(
                "zoky_service",
                "สั่งอาหาร ร้านอร่อยใกล้คุณ เลือกเมนูโปรดได้ง่าย เลือกอาหาร",
                modifier = Modifier.widthIn(max = 720.dp).fillMaxWidth()
                    .padding(horizontal = 14.dp)
                    .aspectRatio(520f / 195f)
                    .clip(RoundedCornerShape(19.dp))
                    .clickable(onClick = onFood),
            )
        }
        item(key = "zoky-deals-heading") {
            Row(
                Modifier.widthIn(max = 720.dp).fillMaxWidth()
                    .padding(start = 17.dp, end = 17.dp, top = 16.dp, bottom = 9.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("ดีลคุ้ม! ดีลแรงวันนี้", modifier = Modifier.weight(1f),
                    fontSize = 20.sp, color = ZokyInk,
                    fontWeight = FontWeight.ExtraBold)
                Row(
                    Modifier.clip(RoundedCornerShape(9.dp))
                        .clickable(onClick = onDeals)
                        .padding(vertical = 7.dp, horizontal = 2.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("ดูทั้งหมด", color = ZokyRed, fontSize = 13.sp)
                    Icon(Icons.Outlined.ChevronRight, null, tint = ZokyRed,
                        modifier = Modifier.size(18.dp))
                }
            }
        }
        item(key = "zoky-deal-cards") {
            // These are visual previews. A public discount must be provided by
            // a verified server promotion, never copied from the reference image.
            val offers = state.promotions
            val previews = if (offers.isEmpty()) listOf(
                Triple("ภาพประกอบเมนู", "ยังไม่มีดีลที่เปิดใช้งาน", "dealpizza_crop"),
                Triple("ภาพประกอบเครื่องดื่ม", "รอโปรโมชันที่ยืนยันจากระบบ", "dealdrinks_crop"),
            ) else offers.take(8).mapIndexed { index, offer ->
                Triple(offer.title, "ตรวจสอบเงื่อนไขก่อนใช้", if (index % 2 == 0) "dealpizza_crop" else "dealdrinks_crop")
            }
            LazyRow(
                modifier = Modifier.widthIn(max = 720.dp).fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                contentPadding = PaddingValues(horizontal = 14.dp, vertical = 3.dp),
            ) {
                items(previews) { (title, subtitle, artwork) ->
                    Column(
                        Modifier.width(212.dp)
                            .shadow(2.dp, RoundedCornerShape(16.dp))
                            .clip(RoundedCornerShape(16.dp))
                            .background(Color.White)
                            .clickable(onClick = onDeals),
                    ) {
                        ZokyArt(
                            artwork, title,
                            modifier = Modifier.fillMaxWidth().height(130.dp),
                            scale = ContentScale.Crop,
                        )
                        Column(
                            Modifier.padding(horizontal = 11.dp, vertical = 10.dp),
                            verticalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            Text(title, color = ZokyInk,
                                fontWeight = FontWeight.Bold, fontSize = 14.sp,
                                maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text(subtitle, color = ZokySub, fontSize = 11.sp,
                                maxLines = 2, overflow = TextOverflow.Ellipsis)
                        }
                    }
                }
            }
        }
    }
}
