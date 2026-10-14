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
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Zoky Home visual reference: founder-approved pink mockup.
 * Food illustrations are decorative high-density crops of the source mockup.
 * The marketing headline, CTA, service copy and deal-card labels are native Compose
 * text, never baked into bitmaps. No fabricated discount percentages.
 *
 * Image resampling improves display sampling but cannot recover source detail.
 * Keep Home separate from the Food merchant/catalog search destination.
 */
private val ZokyRed = Color(0xFFD91F4E)
private val ZokyDeepRed = Color(0xFFE70847)
private val ZokyInk = Color(0xFF24212B)
private val ZokySub = Color(0xFF66636C)
private val ZokyBlush = Color(0xFFFFF0F4)

@Composable
private fun ZokyArt(
    name: String,
    description: String?,
    modifier: Modifier = Modifier,
    scale: ContentScale = ContentScale.Crop,
) {
    val context = LocalContext.current
    // Offline bundling avoids unstable image fetches and Redfinger network latency.
    val image = remember(context, name) {
        runCatching {
            val encoded = context.assets.open("$name.webp.b64")
                .bufferedReader().use { it.readText() }
            val bytes = Base64.decode(encoded.trim(), Base64.DEFAULT)
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap()
        }.getOrNull()
    }
    if (image != null) {
        Image(bitmap = image, contentDescription = description,
            modifier = modifier, contentScale = scale)
    } else {
        Box(modifier.background(ZokyBlush), contentAlignment = Alignment.Center) {
            if (description != null) Text(description, fontSize = 13.sp, color = ZokyInk)
        }
    }
}

@Composable
fun ZokyHomeScreen(
    state: FoodUiState,
    onFood: () -> Unit,
    onFavorites: () -> Unit,
    onDeals: () -> Unit,
    onLocation: () -> Unit,
) {
    val small = LocalConfiguration.current.screenWidthDp < 380
    LazyColumn(
        modifier = Modifier.fillMaxSize().background(Color.White),
        horizontalAlignment = Alignment.CenterHorizontally,
        contentPadding = PaddingValues(bottom = 30.dp),
    ) {
        item(key = "zoky-header") {
            Row(
                Modifier.widthIn(max = 720.dp).fillMaxWidth()
                    .padding(start = 19.dp, end = 15.dp, top = 4.dp, bottom = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text("Zoky", fontSize = 34.sp, lineHeight = 40.sp,
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
            Box(
                modifier = Modifier.widthIn(max = 720.dp).fillMaxWidth()
                    .padding(horizontal = 14.dp)
                    .aspectRatio(514f / 220f)
                    .clip(RoundedCornerShape(18.dp))
                    .background(Brush.horizontalGradient(listOf(
                        Color(0xFFE60945), Color(0xFFF42465), Color(0xFFFF9CBD))))
                    .clickable(onClick = onDeals),
            ) {
                ZokyArt(
                    "zoky_hero_hd_art", null,
                    modifier = Modifier.align(Alignment.CenterEnd)
                        .fillMaxWidth(.66f).fillMaxHeight(),
                    scale = ContentScale.FillBounds,
                )
                // Gentle fade protects the native white headline from illustration contrast.
                Box(Modifier.align(Alignment.CenterStart).fillMaxWidth(.50f).fillMaxHeight()
                    .background(Brush.horizontalGradient(listOf(
                        Color(0xFFE60945).copy(alpha = .78f), Color.Transparent))))
                Column(
                    Modifier.align(Alignment.CenterStart)
                        .fillMaxWidth(.65f)
                        .padding(start = if (small) 12.dp else 17.dp),
                    verticalArrangement = Arrangement.spacedBy(if (small) 1.dp else 2.dp),
                ) {
                    Text("ดีลคุ้ม!", color = Color.White, fontWeight = FontWeight.ExtraBold,
                        fontSize = if (small) 26.sp else 30.sp,
                        lineHeight = if (small) 29.sp else 33.sp, maxLines = 1)
                    Text("ดีลแรงวันนี้", color = Color(0xFFFFF0CF),
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = if (small) 21.sp else 25.sp,
                        lineHeight = if (small) 25.sp else 29.sp, maxLines = 1)
                    Text("อร่อยง่าย ส่งไว ใกล้คุณ", color = Color.White,
                        fontSize = if (small) 10.sp else 12.sp,
                        maxLines = 1,
                        modifier = Modifier.padding(top = 1.dp))
                    Row(
                        Modifier.padding(top = if (small) 2.dp else 5.dp)
                            .clip(CircleShape).background(Color.White)
                            .clickable(onClick = onDeals)
                            .padding(horizontal = if (small) 10.dp else 13.dp,
                                vertical = if (small) 6.dp else 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("ดูดีลทั้งหมด", color = ZokyRed,
                            fontWeight = FontWeight.Bold,
                            fontSize = if (small) 11.sp else 12.sp)
                        Icon(Icons.Outlined.ChevronRight, null, tint = ZokyRed,
                            modifier = Modifier.padding(start = 5.dp).size(15.dp))
                    }
                }
            }
        }
        item(key = "zoky-hero-indicator") {
            // A single live banner: no fake carousel pagination controls.
            Box(Modifier.padding(top = 8.dp, bottom = 10.dp)
                .size(width = 18.dp, height = 6.dp).clip(CircleShape)
                .background(ZokyRed))
        }
        item(key = "zoky-services-heading") {
            Text("บริการของ Zoky",
                modifier = Modifier.widthIn(max = 720.dp).fillMaxWidth()
                    .padding(start = 17.dp, end = 17.dp, top = 3.dp, bottom = 7.dp),
                fontSize = 20.sp, fontWeight = FontWeight.ExtraBold, color = ZokyInk)
        }
        item(key = "zoky-approved-food-card") {
            Box(
                modifier = Modifier.widthIn(max = 720.dp).fillMaxWidth()
                    .padding(horizontal = 14.dp)
                    .aspectRatio(520f / 195f)
                    .clip(RoundedCornerShape(19.dp))
                    .background(Brush.horizontalGradient(listOf(
                        Color(0xFFFFF1F4), Color(0xFFFFE3ED))))
                    .clickable(onClick = onFood),
            ) {
                ZokyArt(
                    "zoky_food_hd_art", null,
                    modifier = Modifier.align(Alignment.CenterEnd)
                        .fillMaxWidth(.59f).fillMaxHeight(),
                    scale = ContentScale.FillBounds,
                )
                Column(
                    Modifier.align(Alignment.CenterStart)
                        .fillMaxWidth(.56f)
                        .padding(start = if (small) 12.dp else 17.dp),
                    verticalArrangement = Arrangement.spacedBy(3.dp),
                ) {
                    Text("สั่งอาหาร", color = ZokyInk, fontWeight = FontWeight.ExtraBold,
                        fontSize = if (small) 24.sp else 28.sp,
                        lineHeight = if (small) 29.sp else 33.sp,
                        maxLines = 1)
                    Text("ร้านอร่อยใกล้คุณ\nเลือกเมนูโปรดได้ง่าย",
                        color = ZokySub,
                        fontSize = if (small) 11.sp else 12.sp,
                        lineHeight = if (small) 15.sp else 17.sp,
                        maxLines = 2,
                    )
                    Row(
                        Modifier.padding(top = 3.dp).clip(CircleShape)
                            .background(ZokyDeepRed)
                            .clickable(onClick = onFood)
                            .padding(horizontal = if (small) 12.dp else 15.dp,
                                vertical = if (small) 6.dp else 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("เลือกอาหาร", color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = if (small) 12.sp else 14.sp)
                        Icon(Icons.Outlined.ChevronRight, null, tint = Color.White,
                            modifier = Modifier.padding(start = 6.dp).size(16.dp))
                    }
                }
            }
        }
        item(key = "zoky-deals-heading") {
            Row(
                Modifier.widthIn(max = 720.dp).fillMaxWidth()
                    .padding(start = 17.dp, end = 17.dp, top = 16.dp, bottom = 9.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("ดีลคุ้ม! ดีลแรงวันนี้", modifier = Modifier.weight(1f),
                    fontSize = 20.sp, color = ZokyInk, fontWeight = FontWeight.ExtraBold)
                Row(
                    Modifier.clip(RoundedCornerShape(9.dp)).clickable(onClick = onDeals)
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
            // Illustrative deal cards are NOT server-confirmed discounts. When
            // live offers exist, titles derive from buyer-scoped Backend data.
            val offers = state.promotions
            val previews = if (offers.isEmpty()) listOf(
                Triple("ดีลร้านดัง", "ภาพประกอบ · ยังไม่มีดีลจริง", "zoky_pizza_hd"),
                Triple("เครื่องดื่มสุดฮิต", "ภาพประกอบ · รอโปรโมชัน", "zoky_drinks_hd"),
                Triple("เมนูน่าลอง", "ภาพประกอบ · รอโปรโมชัน", "zoky_third_hd"),
            ) else offers.take(8).mapIndexed { index, offer ->
                val picture = when (index % 3) {
                    0 -> "zoky_pizza_hd"
                    1 -> "zoky_drinks_hd"
                    else -> "zoky_third_hd"
                }
                Triple(offer.title, "ตรวจสอบเงื่อนไขก่อนใช้", picture)
            }
            val dealWidthDp = (LocalConfiguration.current.screenWidthDp * .41f)
                .coerceIn(128f, 240f)
            LazyRow(
                modifier = Modifier.widthIn(max = 720.dp).fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                contentPadding = PaddingValues(horizontal = 14.dp, vertical = 3.dp),
            ) {
                items(previews) { (title, subtitle, artwork) ->
                    Column(
                        Modifier.width(dealWidthDp.dp)
                            .shadow(2.dp, RoundedCornerShape(15.dp))
                            .clip(RoundedCornerShape(15.dp))
                            .background(Color.White)
                            .clickable(onClick = onDeals),
                    ) {
                        ZokyArt(artwork, title,
                            modifier = Modifier.fillMaxWidth()
                                .height((dealWidthDp * .60f).dp),
                            scale = ContentScale.Crop)
                        Row(Modifier.fillMaxWidth()
                                .padding(start = 10.dp, end = 8.dp, top = 9.dp, bottom = 10.dp),
                            verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f),
                                verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text(title, color = ZokyInk,
                                    fontWeight = FontWeight.Bold, fontSize = 13.sp,
                                    maxLines = 1, overflow = TextOverflow.Ellipsis)
                                Text(subtitle, color = ZokySub, fontSize = 10.sp,
                                    maxLines = 1, overflow = TextOverflow.Ellipsis)
                            }
                            Box(Modifier.padding(start = 3.dp).size(28.dp)
                                .clip(CircleShape).background(ZokyBlush),
                                contentAlignment = Alignment.Center) {
                                Icon(Icons.Outlined.ChevronRight, null,
                                    tint = ZokyInk, modifier = Modifier.size(18.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}