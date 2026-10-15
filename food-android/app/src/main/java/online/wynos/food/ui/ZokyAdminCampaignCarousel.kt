package online.wynos.food.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Storefront
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import online.wynos.food.data.FoodHomeBanner
import online.wynos.food.data.FoodPublicMedia

/** Only the published, admin-controlled banners loaded by food_active_home_banners.
 * Never infer a clickable store route for a campaign without destination_store_id.
 */
@Composable
fun ZokyAdminCampaignCarousel(
    banners: List<FoodHomeBanner>,
    onStore: (String) -> Unit,
) {
    if (banners.isEmpty()) return
    val pager = rememberPagerState(pageCount = { banners.size })
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        HorizontalPager(
            state = pager,
            contentPadding = PaddingValues(horizontal = 14.dp),
            pageSpacing = 8.dp,
            modifier = Modifier.fillMaxWidth(),
        ) { index ->
            val banner = banners[index]
            Box(
                Modifier.fillMaxWidth().height(153.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(Brush.horizontalGradient(listOf(
                        Color(0xFFD91F4E), Color(0xFFFF7196))))
                    .clickable(enabled = banner.destinationStoreId != null) {
                        banner.destinationStoreId?.let(onStore)
                    },
            ) {
                val url = FoodPublicMedia.url("food-banners", banner.imagePath)
                if (url != null) {
                    AsyncImage(
                        model = url,
                        contentDescription = banner.title,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxWidth().fillMaxHeight(),
                    )
                } else {
                    Icon(Icons.Outlined.Storefront, null, tint = Color.White,
                        modifier = Modifier.align(Alignment.CenterEnd)
                            .padding(end = 22.dp).size(48.dp))
                }
                Box(Modifier.fillMaxWidth().fillMaxHeight().background(
                    Brush.horizontalGradient(listOf(
                        Color.Black.copy(alpha = .62f),
                        Color.Black.copy(alpha = .19f),
                        Color.Transparent,
                    ))))
                Column(
                    Modifier.align(Alignment.CenterStart).fillMaxWidth(.76f)
                        .padding(horizontal = 17.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(banner.title, color = Color.White, fontSize = 21.sp,
                        fontWeight = FontWeight.ExtraBold, maxLines = 2,
                        overflow = TextOverflow.Ellipsis)
                    banner.subtitle?.let {
                        Text(it, color = Color.White, fontSize = 12.sp,
                            maxLines = 2, overflow = TextOverflow.Ellipsis)
                    }
                    if (banner.destinationStoreId != null) {
                        Text("ดูร้านอาหาร  ›", color = Color.White,
                            fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
        if (banners.size > 1) {
            Row(Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically) {
                repeat(banners.size.coerceAtMost(10)) { index ->
                    Box(
                        Modifier.padding(horizontal = 3.dp)
                            .width(if (pager.currentPage == index) 18.dp else 7.dp)
                            .height(7.dp).clip(CircleShape)
                            .background(if (pager.currentPage == index)
                                Color(0xFFD91F4E) else Color(0xFFE1E1E6)),
                    )
                }
            }
        }
    }
}
