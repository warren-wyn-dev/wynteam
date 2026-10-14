package online.wynos.food.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.DirectionsBike
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.KeyboardArrowDown
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.PersonOutline
import androidx.compose.material.icons.outlined.ReceiptLong
import androidx.compose.material.icons.outlined.Restaurant
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.ShoppingBag
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material.icons.outlined.ArrowForward
import androidx.compose.material.icons.outlined.Storefront
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.distinctUntilChanged
import online.wynos.food.R
import online.wynos.food.data.FoodCartDraft
import online.wynos.food.data.FoodHomeBanner
import online.wynos.food.data.FoodMenu
import online.wynos.food.data.FoodPublicMedia
import online.wynos.food.data.FoodStore

// Tokens based on web/app/food/food-app.css (fx-app, Oct 2026).
private val WebRed = Color(0xFFE40036)
private val WebRedDark = Color(0xFFC8002E)
private val WebRedSoft = Color(0xFFFCEDF0)
private val WebInk = Color(0xFF16161A)
private val WebSub = Color(0xFF6B6B76)
private val WebMuted = Color(0xFF8A8A94)
private val WebChip = Color(0xFFF3F3F6)
private val WebSurface = Color(0xFFF6F6F8)
private val WebLine = Color(0xFFEBEBEF)
private val WebGreen = Color(0xFF1F8A4C)

@Composable
private fun WebImage(
    path: String?,
    bucket: String,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
    imageAlignment: Alignment = Alignment.Center,
) {
    val url = FoodPublicMedia.url(bucket, path)
    Box(modifier.background(WebSurface), contentAlignment = Alignment.Center) {
        if (url == null) {
            Icon(Icons.Outlined.Restaurant, null, tint = WebMuted, modifier = Modifier.size(30.dp))
        } else {
            AsyncImage(
                model = url,
                contentDescription = null,
                contentScale = contentScale,
                alignment = imageAlignment,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

@Composable
fun WebHomeHeader(
    state: FoodUiState,
    guest: Boolean,
    cartCount: Int,
    onAccount: () -> Unit,
    onCart: () -> Unit,
    onSelectAddress: (String?) -> Unit,
    onRefreshAddresses: () -> Unit,
    scrolled: Boolean = false,
) {
    // Only elevate the sticky header when content is actually moving behind it.
    BoxWithConstraints(
        Modifier.fillMaxWidth()
            .shadow(if (scrolled) 2.dp else 0.dp)
            .background(Color.White),
    ) {
        val geometry = foodAdaptiveLayout(maxWidth.value)
        Column(
            Modifier.widthIn(max = geometry.headerMaxWidthDp.dp).fillMaxWidth()
                .align(Alignment.TopCenter)
                .padding(horizontal = geometry.horizontalPaddingDp.dp, vertical = 6.dp),
        ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Image(
                    painter = painterResource(R.drawable.food_logo),
                    contentDescription = null,
                    modifier = Modifier.size(32.dp).clip(RoundedCornerShape(9.dp)),
                )
                Text(
                    text = buildAnnotatedString {
                        append("WYNOS ")
                        withStyle(SpanStyle(color = WebRed)) { append("Food") }
                    },
                    modifier = Modifier.weight(1f),
                    fontSize = 18.sp, maxLines = 1, overflow = TextOverflow.Ellipsis,
                    color = WebInk, fontWeight = FontWeight.Bold,
                )
            }
            if (guest) {
                OutlinedButton(
                    onClick = onAccount,
                    shape = CircleShape,
                    border = androidx.compose.foundation.BorderStroke(1.dp, WebRed),
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    modifier = Modifier.height(36.dp),
                ) {
                    Text(stringResource(R.string.guest_sign_in), color = WebRed, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                }
            } else {
                IconButton(onClick = onCart, modifier = Modifier.size(42.dp)) {
                    Box {
                        Icon(Icons.Outlined.ShoppingBag, stringResource(R.string.cart_title), tint = WebInk)
                        if (cartCount > 0) {
                            Box(Modifier.align(Alignment.TopEnd).offset(x = 8.dp, y = (-8).dp).size(17.dp).background(WebRed, CircleShape), contentAlignment = Alignment.Center) {
                                Text(cartCount.coerceAtMost(9).toString(), color = Color.White, fontSize = 10.sp)
                            }
                        }
                    }
                }
            }
        }
        if (!guest) {
            FoodHomeDelivery(
                state = state,
                onSelectAddress = onSelectAddress,
                onRefreshAddresses = onRefreshAddresses,
                onManageAddresses = onAccount,
            )
        }
        }
    }
}

@Composable
fun WebPageHeader(title: String, onBack: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().height(56.dp).background(Color.White).padding(horizontal = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = onBack) { Icon(Icons.Outlined.ArrowBack, stringResource(R.string.back), tint = WebInk) }
        Text(title, fontSize = 23.sp, color = WebInk, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun WebBottomNavigation(tab: Int, onTab: (Int) -> Unit, modifier: Modifier = Modifier) {
    // Fixed and compact native navigation; retains Messages and all four routes.
    val tabs = listOf(
        Triple(0, R.string.home, Icons.Outlined.Home),
        Triple(1, R.string.orders, Icons.Outlined.ReceiptLong),
        Triple(2, R.string.messages, Icons.Outlined.ChatBubbleOutline),
        Triple(3, R.string.account, Icons.Outlined.PersonOutline),
    )
    Column(
        modifier.fillMaxWidth().shadow(3.dp, RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp))
            .clip(RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp))
            .background(Color.White).navigationBarsPadding(),
    ) {
        Row(
            Modifier.widthIn(max = 720.dp).fillMaxWidth()
                .align(Alignment.CenterHorizontally)
                .height(66.dp).padding(horizontal = 12.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            tabs.forEach { (index, label, icon) ->
                val active = index == tab
                Column(
                    Modifier.weight(1f).fillMaxSize().clip(RoundedCornerShape(14.dp))
                        .clickable { onTab(index) },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Box(
                        Modifier.size(43.dp, 29.dp)
                            .clip(CircleShape)
                            .background(
                                Brush.verticalGradient(
                                    if (active) listOf(Color(0xFFFFF4F7), Color(0xFFFFD9E3))
                                    else listOf(Color.Transparent, Color.Transparent),
                                )
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(icon, null, tint = if (active) WebRed else WebMuted, modifier = Modifier.size(22.dp))
                    }
                    Text(
                        stringResource(label), color = if (active) WebRed else WebMuted,
                        fontSize = 11.sp, maxLines = 1, overflow = TextOverflow.Ellipsis,
                        fontWeight = if (active) FontWeight.Bold else FontWeight.Medium,
                    )
                }
            }
        }
    }
}

/** Matches the website's 2-column mobile grid and 3-column wide-screen grid. */
internal fun homeGridColumnsForWidth(widthDp: Float): Int = if (widthDp >= 680f) 3 else 2

// Keep visual hierarchy on narrower Android viewports without disabling
// Android's user-selected accessibility font scaling.
internal fun compactFoodHomeForWidth(widthDp: Float): Boolean = widthDp < 400f

/**
 * The first Home section displays published, real catalog stores—not
 * synthetic recommendations. Searching, filtering or tapping See all
 * exposes the ordinary grid instead of a potentially misleading carousel.
 */
internal fun shouldShowRecommendedHomeStrip(
    query: String,
    filter: String,
    showAll: Boolean,
): Boolean = query.isBlank() && filter == "all" && !showAll

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WebHomeScreen(
    state: FoodUiState,
    guest: Boolean,
    onAccount: () -> Unit,
    onStore: (String) -> Unit,
    onDish: (String, String) -> Unit,
    onRetry: () -> Unit,
    onScrolledChange: (Boolean) -> Unit = {},
) {
    var query by rememberSaveable { mutableStateOf("") }
    var filter by rememberSaveable { mutableStateOf("all") }
    var showAllStores by rememberSaveable { mutableStateOf(false) }
    var filtersOpen by rememberSaveable { mutableStateOf(false) }
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    val latestOnScrolledChange by rememberUpdatedState(onScrolledChange)
    LaunchedEffect(listState) {
        snapshotFlow {
            listState.firstVisibleItemIndex > 0 || listState.firstVisibleItemScrollOffset > 0
        }.distinctUntilChanged().collect { latestOnScrolledChange(it) }
    }
    val filtered = visibleHomeStores(state.stores, query, filter)
    // Use the actual composable width rather than assuming two columns on
    // every screen. With only one published store, the old 2-column grid
    // squeezed its photo into the left half and left the right half blank.
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val geometry = foodAdaptiveLayout(maxWidth.value)
        // A medium window can still be narrower than its allowed max width.
        val measuredContentWidthDp = minOf(maxWidth.value, geometry.maxContentWidthDp)
        val homeGridColumns = homeGridColumnsForWidth(measuredContentWidthDp)
        val compactHome = compactFoodHomeForWidth(measuredContentWidthDp)
        LazyColumn(
            state = listState,
            modifier = Modifier.widthIn(max = geometry.maxContentWidthDp.dp)
                .fillMaxWidth().fillMaxHeight().align(Alignment.TopCenter)
                .background(Color.White),
            contentPadding = PaddingValues(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(0.dp),
        ) {
        item(key = "search-with-filter-button") {
            Row(
                modifier = Modifier.fillMaxWidth()
                    .padding(start = geometry.horizontalPaddingDp.dp, end = geometry.horizontalPaddingDp.dp, top = 3.dp, bottom = 5.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Row(
                    modifier = Modifier.weight(1f).height(48.dp).padding(vertical = 2.dp)
                        .shadow(1.dp, CircleShape)
                        .clip(CircleShape).background(Color.White)
                        .padding(horizontal = 13.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(Icons.Outlined.Search, null, tint = WebMuted, modifier = Modifier.size(20.dp))
                    BasicTextField(
                        value = query,
                        onValueChange = { query = it },
                        singleLine = true,
                        textStyle = androidx.compose.ui.text.TextStyle(color = WebInk, fontSize = 14.sp),
                        modifier = Modifier.weight(1f),
                        decorationBox = { inner ->
                            Box {
                                if (query.isEmpty()) Text(
                                    stringResource(R.string.search_food_hint), color = WebMuted, fontSize = 14.sp,
                                )
                                inner()
                            }
                        },
                    )
                    if (query.isNotEmpty()) {
                        Icon(Icons.Outlined.Close, stringResource(R.string.clear_search), tint = WebMuted,
                            modifier = Modifier.size(24.dp).clickable { query = "" })
                    }
                }
                // 44dp visual icon control / 48dp accessible tap area.
                Box(
                    modifier = Modifier.size(48.dp).clickable { filtersOpen = true },
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        Modifier.size(geometry.filterVisualSizeDp.dp)
                            .shadow(1.dp, RoundedCornerShape(14.dp))
                            .clip(RoundedCornerShape(14.dp)).background(Color.White),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(Icons.Outlined.Tune, stringResource(R.string.filters_title),
                            tint = if (filter == "all") WebInk else WebRed,
                            modifier = Modifier.size(20.dp))
                    }
                }
            }
        }
        // A genuine merchant/banner picture is preferred. The branded fallback
        // carries no fictional discounts, ratings or delivery time promises.
        if (query.isBlank()) {
            if (state.banners.isNotEmpty()) {
                item(key = "live-banner") { BannerStrip(state.banners, onStore, geometry.heroHeightDp, geometry.horizontalPaddingDp) }
            } else {
                item(key = "brand-banner") {
                    FoodBrandHeroBanner(state.stores.firstOrNull(), geometry.heroHeightDp, geometry.horizontalPaddingDp, onBrowse = {
                        scope.launch {
                            val last = (listState.layoutInfo.totalItemsCount - 1).coerceAtLeast(0)
                            listState.animateScrollToItem(minOf(3, last))
                        }
                    })
                }
            }
        }
        // Public coupon eligibility/collection is not yet available.
        if (query.isBlank() && filter == "all" && !showAllStores) {
            item(key = "coupon-section") { CouponPreviewUnavailable(geometry.horizontalPaddingDp) }
        }
        // The approved Home is content-first: no visible horizontal chip strip.
        // Verified filters remain available in the dedicated search filter sheet.
        when {
            !state.configured -> item { CenterStateText(R.string.configure_supabase) }
            state.catalogLoading -> item {
                Box(Modifier.fillMaxWidth().padding(26.dp), contentAlignment = Alignment.Center) {
                    androidx.compose.material3.CircularProgressIndicator(color = WebRed)
                }
            }
            state.catalogFailed -> item {
                Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    CenterStateText(R.string.catalog_load_failed)
                    OutlinedButton(onClick = onRetry) { Text(stringResource(R.string.retry)) }
                }
            }
            filtered.isEmpty() -> item { CenterStateText(R.string.no_stores) }
            else -> {
                val recommendedMode = shouldShowRecommendedHomeStrip(query, filter, showAllStores)
                item(key = "store-section-header") {
                    Row(
                        modifier = Modifier.fillMaxWidth()
                            .padding(start = geometry.horizontalPaddingDp.dp, end = geometry.horizontalPaddingDp.dp, top = 7.dp, bottom = 3.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            stringResource(if (recommendedMode) R.string.recommended_stores else R.string.public_stores),
                            modifier = Modifier.weight(1f),
                            fontSize = if (compactHome) 18.sp else 19.sp,
                            fontWeight = FontWeight.Bold,
                            color = WebInk,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        // "See all" always does something: open the full native grid.
                        // "Back" restores the horizontal recommendation section.
                        if (query.isBlank() && filter == "all") {
                            Text(
                                stringResource(if (recommendedMode) R.string.see_all else R.string.back),
                                fontSize = 13.sp,
                                color = WebRed,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.clickable { showAllStores = !showAllStores }
                                    .padding(vertical = 10.dp, horizontal = 2.dp),
                            )
                        }
                    }
                }
                if (recommendedMode) {
                    items(filtered.take(2), key = { "featured-${it.id}" }) { store ->
                        FoodFeaturedRestaurantHome(store, onStore, onDish,
                            geometry.storeCoverSizeDp, geometry.menuImageSizeDp,
                            geometry.horizontalPaddingDp, geometry.featuredGapDp)
                    }
                } else {
                    items(filtered.chunked(homeGridColumns), key = { row -> row.first().id }) { row ->
                        Row(
                            Modifier.fillMaxWidth().padding(horizontal = geometry.horizontalPaddingDp.dp, vertical = 8.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            row.forEach { store ->
                                StoreCardWeb(
                                    store, Modifier.weight(1f),
                                    showRating = false,
                                    onClick = { onStore(store.id) },
                                )
                            }
                            if (row.size < homeGridColumns) {
                                Spacer(Modifier.weight(1f))
                            }
                        }
                    }
                }
            }
        }
        }
        if (filtersOpen) {
            ModalBottomSheet(
                onDismissRequest = { filtersOpen = false },
                containerColor = Color.White,
            ) {
                Column(
                    Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 10.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    Text(stringResource(R.string.filters_title), fontWeight = FontWeight.Bold,
                        fontSize = 20.sp, color = WebInk)
                    Row(
                        modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        FilterChipWeb(stringResource(R.string.filter_all), filter == "all") {
                            filter = "all"; filtersOpen = false
                        }
                        FilterChipWeb(stringResource(R.string.filter_open), filter == "open") {
                            filter = "open"; filtersOpen = false
                        }
                        if (canSortHomeByDeliveryFee(state.stores)) {
                            FilterChipWeb(stringResource(R.string.sort_delivery_fee_lowest), filter == "fee") {
                                filter = "fee"; filtersOpen = false
                            }
                        }
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        publishedHomeCategories(state.stores).forEach { category ->
                            val code = "category:$category"
                            FilterChipWeb(category, filter == code) {
                                filter = code; filtersOpen = false
                            }
                        }
                    }
                    Spacer(Modifier.height(12.dp))
                }
            }
        }
    }
}

/**
 * Rich, compact native restaurant card. Only public catalog fields are used:
 * published photos, cuisine categories, current open flag, delivery fee and
 * menu prices. No invented ratings, distances, ETAs or discount badges.
 */
@Composable
private fun FoodFeaturedRestaurantHome(
    store: FoodStore,
    onStore: (String) -> Unit,
    onDish: (String, String) -> Unit,
    coverDp: Float,
    menuDp: Float,
    edgeDp: Float,
    menuGapDp: Float,
) {
    val cuisines = store.menu.map { it.category.trim() }
        .filter { it.isNotBlank() }.distinct().take(2).joinToString(" · ")
    // Open, frameless layout: no Surface, rounded restaurant card, border or drop shadow.
    // Padding aligns restaurant photo and 1:1 menu thumbnails with other Home content.
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = edgeDp.dp, vertical = 5.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
            Row(
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(13.dp))
                    .clickable { onStore(store.id) },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(Modifier.size(coverDp.dp).clip(RoundedCornerShape(13.dp))) {
                    WebImage(store.coverPath, "food-public", Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop, imageAlignment = Alignment.BottomCenter)
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(store.name, color = WebInk, fontWeight = FontWeight.Bold, fontSize = 16.sp,
                        lineHeight = 20.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    if (cuisines.isNotBlank()) {
                        Text(cuisines, color = WebSub, fontSize = 12.sp,
                            maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    Row(verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        store.deliveryFee?.let { fee ->
                            Row(verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                                Icon(Icons.Outlined.DirectionsBike, null,
                                    tint = WebRed, modifier = Modifier.size(16.dp))
                                Text("฿$fee", color = WebInk, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                        Text(
                            stringResource(if (store.isOpen) R.string.filter_open else R.string.public_store_closed),
                            color = if (store.isOpen) WebGreen else WebRed,
                            fontSize = 11.sp, fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.clip(CircleShape)
                                .background(if (store.isOpen) Color(0xFFE7F8ED) else WebRedSoft)
                                .padding(horizontal = 8.dp, vertical = 4.dp),
                        )
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(stringResource(R.string.featured_view_store), color = WebRed,
                            fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        Icon(Icons.Outlined.ChevronRight, null, tint = WebRed,
                            modifier = Modifier.size(15.dp))
                    }
                }
            }
            val dishes = store.menu.take(5)
            if (dishes.isNotEmpty()) {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(menuGapDp.dp)) {
                    items(dishes, key = { it.id }) { dish ->
                        Column(
                            modifier = Modifier.width(menuDp.dp)
                                .clip(RoundedCornerShape(11.dp))
                                .clickable { onDish(store.id, dish.id) },
                            verticalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            // Fixed 1:1 menu photos without add-to-cart overlays.
                            // Tapping the photo or text still opens the existing real menu
                            // detail flow (including mandatory add-ons).
                            Box(Modifier.size(menuDp.dp).clip(RoundedCornerShape(10.dp))) {
                                WebImage(
                                    dish.imagePath, "food-public", Modifier.fillMaxSize(),
                                    contentScale = ContentScale.Crop,
                                )
                                if (!dish.isAvailable() || !store.isOpen) {
                                    Box(
                                        Modifier.fillMaxSize().background(Color.White.copy(alpha = 0.40f)),
                                    )
                                }
                            }
                            // Equal two-line name slot keeps every price on the same baseline,
                            // without forcing fixed heights that break large-text settings.
                            Text(dish.name, color = WebInk, fontSize = 12.sp,
                                fontWeight = FontWeight.Medium, minLines = 2, maxLines = 2,
                                lineHeight = 16.sp, overflow = TextOverflow.Ellipsis)
                            Text("฿${dish.price}", color = WebInk, fontSize = 12.sp,
                                fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        // Gentle separator between restaurant sections instead of outer borders.
        HorizontalDivider(
            color = Color(0xFFF0F0F2),
            thickness = 0.7.dp,
            modifier = Modifier.padding(top = 6.dp),
        )
    }
}


/** Minimal honest coupon area until verified customer claim/eligibility API exists. */
@Composable
private fun CouponPreviewUnavailable(edgeDp: Float) {
    val shape = RoundedCornerShape(16.dp)
    Row(
        modifier = Modifier.fillMaxWidth()
            .padding(horizontal = edgeDp.dp, vertical = 3.dp)
            .shadow(1.dp, shape).clip(shape)
            .background(Brush.horizontalGradient(listOf(Color.White, Color(0xFFFFF3F6))))
            .padding(horizontal = 12.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            modifier = Modifier.size(30.dp).shadow(2.dp, RoundedCornerShape(9.dp))
                .clip(RoundedCornerShape(10.dp))
                .background(Brush.verticalGradient(
                    listOf(Color(0xFFFF7196), WebRed, WebRedDark))),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Outlined.ReceiptLong, null, tint = Color.White,
                modifier = Modifier.size(20.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(R.string.coupon_section_title), color = WebInk,
                fontWeight = FontWeight.Bold, fontSize = 15.sp)
            Text(stringResource(R.string.coupon_live_empty), color = WebSub,
                fontSize = 11.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

/** A compact editorial banner using an actual published restaurant image. */
@Composable
private fun FoodBrandHeroBanner(store: FoodStore?, heightDp: Float, edgeDp: Float, onBrowse: () -> Unit) {
    val cover = store?.menu?.firstOrNull { it.imagePath != null }?.imagePath ?: store?.coverPath
    val shape = RoundedCornerShape(18.dp)
    Box(
        Modifier.fillMaxWidth()
            .padding(start = edgeDp.dp, end = edgeDp.dp, top = 6.dp, bottom = 6.dp)
            .height(heightDp.dp).shadow(2.dp, shape)
            .clip(shape)
            .background(Brush.horizontalGradient(
                listOf(Color(0xFFFFDFE9), Color(0xFFFFAFC4), Color(0xFFED648C)))),
    ) {
        // Food imagery is drawn only when this restaurant image actually exists.
        if (cover != null) {
            WebImage(cover, "food-public", Modifier.align(Alignment.CenterEnd)
                .fillMaxWidth(0.56f).fillMaxHeight(), contentScale = ContentScale.Crop)
        } else {
            Image(painter = painterResource(R.drawable.food_rider_hero), contentDescription = null,
                modifier = Modifier.align(Alignment.BottomEnd).size((heightDp * .95f).dp),
                contentScale = ContentScale.Fit)
        }
        Box(Modifier.fillMaxSize().background(
            Brush.horizontalGradient(
                0f to Color(0xFFFFE8EF),
                0.56f to Color(0xFFFFDDE8).copy(alpha = .98f),
                0.80f to Color(0xFFFFDDE8).copy(alpha = .09f),
                1f to Color.Transparent,
            )))
        Column(
            Modifier.align(Alignment.CenterStart).fillMaxWidth(0.60f)
                .padding(start = 17.dp, end = 5.dp),
            verticalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Text(stringResource(R.string.brand_hero_title), fontSize = 20.sp,
                lineHeight = 25.sp, fontWeight = FontWeight.ExtraBold,
                color = WebInk, maxLines = 2)
            Text(stringResource(R.string.brand_hero_subtitle), fontSize = 12.sp,
                lineHeight = 16.sp, color = WebInk, maxLines = 2)
            Box(
                Modifier.padding(top = 3.dp).height(31.dp)
                    .shadow(3.dp, CircleShape).clip(CircleShape)
                    .background(Brush.verticalGradient(listOf(Color(0xFFFF3370), WebRed, WebRedDark)))
                    .clickable(onClick = onBrowse)
                    .padding(horizontal = 12.dp),
                contentAlignment = Alignment.Center,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text(stringResource(R.string.browse_restaurants), color = Color.White,
                        fontSize = 11.sp, fontWeight = FontWeight.Bold, maxLines = 1)
                    Icon(Icons.Outlined.ArrowForward, null, tint = Color.White,
                        modifier = Modifier.size(14.dp))
                }
            }
        }
    }
}

@Composable
private fun BannerStrip(banners: List<FoodHomeBanner>, onStore: (String) -> Unit, heightDp: Float, edgeDp: Float) {
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val width = (maxWidth - (2 * edgeDp).dp).coerceAtMost(700.dp)
        LazyRow(
            contentPadding = PaddingValues(horizontal = edgeDp.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            items(banners, key = { it.id }) { banner ->
                Box(
                    Modifier.width(width).height(heightDp.dp).clip(RoundedCornerShape(16.dp))
                        .clickable(enabled = banner.destinationStoreId != null) {
                            banner.destinationStoreId?.let(onStore)
                        },
                ) {
                    WebImage(banner.imagePath, "food-banners", Modifier.fillMaxSize())
                    Box(
                        Modifier.fillMaxSize().background(
                            Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = .48f)))
                        )
                    )
                    Column(Modifier.align(Alignment.BottomStart).padding(14.dp)) {
                        Text(banner.title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        banner.subtitle?.let { Text(it, color = Color.White, fontSize = 12.sp) }
                    }
                }
            }
        }
    }
}

@Composable
private fun SectionTitleWeb(title: String, topSpacing: Int = 21, compact: Boolean = false) {
    Text(
        title,
        color = WebInk,
        fontWeight = FontWeight.Bold,
        fontSize = if (compact) 17.sp else 18.sp,
        modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = topSpacing.dp, bottom = 5.dp),
    )
}

@Composable
private fun CenterStateText(message: Int) {
    Box(Modifier.fillMaxWidth().padding(24.dp).clip(RoundedCornerShape(14.dp)).background(WebSurface), contentAlignment = Alignment.Center) {
        Text(stringResource(message), color = WebSub, fontSize = 14.sp, modifier = Modifier.padding(18.dp))
    }
}

@Composable
private fun FilterChipWeb(title: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier.height(36.dp).shadow(if (selected) 3.dp else 1.dp, CircleShape)
            .clip(CircleShape)
            .background(
                Brush.verticalGradient(
                    if (selected) listOf(Color(0xFFFF235B), WebRed, WebRedDark)
                    else listOf(Color.White, Color(0xFFFDFBFC))
                )
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 13.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, fontSize = 12.5.sp,
            color = if (selected) Color.White else WebInk,
            fontWeight = FontWeight.SemiBold, maxLines = 1)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun StoreCardWeb(store: FoodStore, modifier: Modifier, showRating: Boolean, onClick: () -> Unit) {
    Column(
        modifier = modifier.clickable(onClick = onClick),
        verticalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Box(Modifier.fillMaxWidth().aspectRatio(4f / 3f).clip(RoundedCornerShape(16.dp))) {
            // Match the website's full-width 4:3 card. Cropping from the
            // TOP preserves text/labels placed along the bottom of store art.
            // Store detail uses Fit so the full original remains accessible.
            WebImage(
                store.coverPath, "food-public", Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
                imageAlignment = Alignment.BottomCenter,
            )
            if (!store.isOpen) {
                Box(
                    Modifier.align(Alignment.TopEnd).padding(8.dp).clip(CircleShape)
                        .background(WebRed).padding(horizontal = 9.dp, vertical = 4.dp),
                ) {
                    Text(stringResource(R.string.public_store_closed), color = Color.White, fontWeight = FontWeight.Bold, fontSize = 11.sp)
                }
            }
        }
        Text(store.name, color = WebInk, fontWeight = FontWeight.Bold, fontSize = 15.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
        if (showRating) {
            // The signed-in site shows a rating row; public guest cards don't.
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(Icons.Outlined.Star, null, tint = Color(0xFFF5A623), modifier = Modifier.size(13.dp))
                Text(stringResource(R.string.store_new), color = WebInk, fontWeight = FontWeight.Bold, fontSize = 12.sp)
            }
        }
        val menuCountTag = stringResource(R.string.store_menu_count, store.menu.size)
        val deliveryTag = store.deliveryFee?.let { stringResource(R.string.store_delivery, "฿$it") }
        // Only show verified public-catalog values; never invent a fee or ETA.
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            TagWeb(menuCountTag)
            if (deliveryTag != null) TagWeb(deliveryTag)
        }
    }
}

@Composable
private fun TagWeb(title: String) {
    Text(
        title, color = WebSub, fontSize = 11.5.sp, maxLines = 1,
        modifier = Modifier.clip(RoundedCornerShape(6.dp)).background(WebChip)
            .padding(horizontal = 7.dp, vertical = 2.dp),
    )
}

/** Avoid showing the merchant's location twice when copied into its description. */
internal fun shouldShowStoreDescription(description: String?, address: String?): Boolean {
    val value = description?.trim().orEmpty()
    if (value.isBlank()) return false
    val normalized = value.filterNot(Char::isWhitespace).lowercase()
    val normalizedAddress = address?.filterNot(Char::isWhitespace)?.lowercase().orEmpty()
    return normalized != normalizedAddress
}

@Composable
fun WebStoreScreen(
    store: FoodStore,
    initialMenuId: String?,
    cart: FoodCartDraft,
    cartError: Boolean,
    state: FoodUiState,
    guest: Boolean,
    onBack: () -> Unit,
    onAccount: () -> Unit,
    onAdd: (FoodStore, FoodMenu, Map<String, Set<String>>, Int, String) -> Boolean,
    onClear: () -> Unit,
    onQuote: () -> Unit,
    onSelectAddress: (String?) -> Unit,
    onChangeQuantity: (String, Int) -> Unit,
    onCreateOrder: (String) -> Unit,
    onPrepareStagingPayment: suspend (String) -> online.wynos.food.data.FoodMobilePaymentIntent,
    onPaymentSheetCompleted: () -> Unit,
) {
    var selectedMenu by remember(store.id, initialMenuId) {
        mutableStateOf(store.menu.firstOrNull { it.id == initialMenuId })
    }
    var showCart by remember(store.id) { mutableStateOf(false) }
    var storeTab by rememberSaveable(store.id) { mutableIntStateOf(0) }
    var category by rememberSaveable(store.id) { mutableStateOf("") }
    val categories = listOf("") + store.menu.map { it.category }.filter { it.isNotBlank() }.distinct()
    val available = store.menu.filter { it.isAvailable() }
    val fallbackMenuCategory = stringResource(R.string.store_tab_menu)
    val groupedMenus = store.menu
        .filter { category.isEmpty() || category == it.category }
        .groupBy { it.category.ifBlank { fallbackMenuCategory } }
    LazyColumn(
        Modifier.fillMaxSize().background(Color.White),
        contentPadding = PaddingValues(bottom = 24.dp),
    ) {
        item {
            // Constrain the cover to a responsive 16:9 crop (max 200dp).
            // Avoid the oversized Fit image and the unused gray side margins.
            Column(verticalArrangement = Arrangement.spacedBy((-16).dp)) {
                BoxWithConstraints(Modifier.fillMaxWidth()) {
                    val coverHeight = (maxWidth.value * 9f / 16f).coerceAtMost(200f).dp
                    Box(Modifier.fillMaxWidth().height(coverHeight)) {
                    WebImage(store.coverPath, "food-public", Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                    Box(Modifier.fillMaxWidth().height(80.dp).background(
                        Brush.verticalGradient(listOf(Color.Black.copy(alpha = .36f), Color.Transparent))
                    ))
                    Row(
                        Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        RoundHeroButton(Icons.Outlined.ArrowBack, onClick = onBack)
                        if (guest) {
                            Surface(
                                shape = CircleShape, color = Color.White,
                                modifier = Modifier.clickable(onClick = onAccount),
                            ) {
                                Text(stringResource(R.string.guest_sign_in), color = WebRed, fontSize = 14.sp,
                                    fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 16.dp, vertical = 11.dp))
                            }
                        } else {
                            RoundHeroButton(Icons.Outlined.ShoppingBag, onClick = { showCart = true })
                        }
                    }
                    if (!store.isOpen) {
                        Box(Modifier.align(Alignment.Center).clip(CircleShape).background(WebRed).padding(horizontal = 18.dp, vertical = 9.dp)) {
                            Text(stringResource(R.string.public_store_closed), color = Color.White, fontWeight = FontWeight.Bold)
                        }
                    }
                    }
                }
                Column(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp))
                        .background(Color.White).padding(start = 16.dp, end = 16.dp, top = 15.dp, bottom = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(store.name, fontSize = 21.sp, lineHeight = 25.sp,
                        fontWeight = FontWeight.Bold, color = WebInk, maxLines = 2,
                        overflow = TextOverflow.Ellipsis)
                    // Real catalog metadata on both guest and authenticated screens;
                    // never insert an unverified "new" rating or discount claim.
                    Text(
                        stringResource(R.string.store_meta_guest, store.menu.size, store.deliveryFee ?: "—"),
                        color = WebSub, fontSize = 13.sp, lineHeight = 18.sp,
                        maxLines = 2, overflow = TextOverflow.Ellipsis,
                    )
                    if (store.isOpen) {
                        Box(Modifier.clip(CircleShape).background(Color(0xFFE8F8EF))
                            .padding(horizontal = 10.dp, vertical = 4.dp)) {
                            Text(stringResource(R.string.store_open_now), color = WebGreen,
                                fontWeight = FontWeight.Bold, fontSize = 12.sp)
                        }
                    } else {
                        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(WebRedSoft).padding(12.dp)) {
                            Text(stringResource(R.string.store_closed_now), color = WebRedDark, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            Text(stringResource(R.string.store_closed_note), color = WebSub, fontSize = 13.sp)
                        }
                    }
                    if (shouldShowStoreDescription(store.description, store.address)) {
                        Text(store.description!!.trim(), color = WebSub, fontSize = 13.sp,
                            maxLines = 2, overflow = TextOverflow.Ellipsis)
                    }
                    if (guest && !store.address.isNullOrBlank()) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            Icon(Icons.Outlined.LocationOn, null, tint = WebSub, modifier = Modifier.size(14.dp))
                            Text(store.address, color = WebSub, fontSize = 12.sp,
                                maxLines = 2, overflow = TextOverflow.Ellipsis)
                        }
                    }
                }
            }
        }
        if (!guest) item {
            Row(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(0.dp)) {
                listOf(R.string.store_tab_menu, R.string.store_tab_reviews, R.string.store_tab_info).forEachIndexed { i, label ->
                    Column(
                        Modifier.weight(1f).clickable { storeTab = i },
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Box(Modifier.heightIn(min = 46.dp), contentAlignment = Alignment.Center) {
                            Text(stringResource(label), fontSize = 15.sp,
                                fontWeight = if (storeTab == i) FontWeight.Bold else FontWeight.Medium,
                                color = if (storeTab == i) WebRed else WebSub)
                        }
                        Box(Modifier.fillMaxWidth().height(3.dp).background(if (storeTab == i) WebRed else Color.Transparent))
                    }
                }
            }
            HorizontalDivider(color = WebLine)
        }
        if (storeTab == 0) {
            if (!guest && categories.size > 1) {
                item {
                    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 10.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        categories.forEach { name ->
                            FilterChipWeb(if (name.isEmpty()) stringResource(R.string.filter_all) else name, selected = name == category, onClick = { category = name })
                        }
                    }
                }
            }
            if (!guest && category.isEmpty() && available.size >= 3) {
                item { SectionTitleWeb(stringResource(R.string.popular_menu), topSpacing = 12) }
                item {
                    Row(
                        Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 4.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        available.take(6).forEach { item ->
                            Column(Modifier.width(136.dp).clickable { selectedMenu = item }, verticalArrangement = Arrangement.spacedBy(5.dp)) {
                                WebImage(item.imagePath, "food-public", Modifier.fillMaxWidth().aspectRatio(1f).clip(RoundedCornerShape(12.dp)))
                                Text(item.name, fontSize = 13.sp, color = WebInk, maxLines = 2)
                                Text("฿" + item.price, color = WebRed, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            }
                        }
                    }
                }
            }
            if (groupedMenus.isEmpty()) {
                item { CenterStateText(R.string.no_menu) }
            }
            groupedMenus.forEach { (name, menus) ->
                item { SectionTitleWeb(name, topSpacing = 12) }
                items(menus, key = { it.id }) { menu ->
                    WebMenuRow(
                        menu = menu,
                        enabled = store.isOpen && menu.isAvailable(),
                        onClick = { selectedMenu = menu },
                    )
                }
            }
            if (cart.storeId == store.id && cart.itemCount > 0) {
                item {
                    Button(
                        onClick = { showCart = true },
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                        shape = CircleShape,
                        colors = ButtonDefaults.buttonColors(containerColor = WebRed),
                    ) { Text(stringResource(R.string.view_cart, cart.itemCount), fontWeight = FontWeight.Bold) }
                }
            }
            if (cartError) item { Text(stringResource(R.string.cart_validation_error), color = WebRed, modifier = Modifier.padding(16.dp)) }
            item { CenterStateText(R.string.checkout_unavailable) }
        } else if (storeTab == 1) {
            item { CenterStateText(R.string.store_reviews_unavailable) }
        } else {
            item {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(store.description ?: stringResource(R.string.store_info_no_details), color = WebSub, fontSize = 14.sp)
                    if (!store.address.isNullOrBlank()) {
                        HorizontalDivider(color = WebLine)
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Outlined.LocationOn, null, tint = WebRed)
                            Column {
                                Text(stringResource(R.string.store_info_address), color = WebSub, fontSize = 12.sp)
                                Text(store.address, color = WebInk, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                            }
                        }
                    }
                }
            }
        }
    }
    selectedMenu?.let { menu ->
        FoodMenuOptionsDialog(
            menu = menu,
            onDismiss = { selectedMenu = null },
            onAdd = { opts, qty, note -> if (onAdd(store, menu, opts, qty, note)) selectedMenu = null },
        )
    }
    if (showCart) FoodCartPreview(
        cart = cart,
        state = state,
        onDismiss = { showCart = false },
        onClear = { onClear(); showCart = false },
        onQuote = onQuote,
        onSelectAddress = onSelectAddress,
        onChangeQuantity = onChangeQuantity,
        onCreateOrder = onCreateOrder,
        onPrepareStagingPayment = onPrepareStagingPayment,
        onPaymentSheetCompleted = onPaymentSheetCompleted,
    )
}

@Composable
private fun RoundHeroButton(icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    Surface(shape = CircleShape, color = Color.White, modifier = Modifier.size(40.dp).clickable(onClick = onClick), shadowElevation = 3.dp) {
        Box(contentAlignment = Alignment.Center) { Icon(icon, null, tint = WebInk, modifier = Modifier.size(21.dp)) }
    }
}

@Composable
private fun WebMenuRow(menu: FoodMenu, enabled: Boolean, onClick: () -> Unit) {
    Column(Modifier.fillMaxWidth().background(Color.White)) {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 112.dp)
                .clickable(enabled = enabled, onClick = onClick)
                .padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // One consistent 1:1 photograph, matching the native Home.
            Box(Modifier.size(96.dp).clip(RoundedCornerShape(12.dp))) {
                WebImage(menu.imagePath, "food-public", Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop)
                if (!enabled) {
                    Box(Modifier.align(Alignment.BottomCenter).clip(CircleShape)
                        .background(WebRedSoft).padding(5.dp)) {
                        Text(stringResource(R.string.menu_unavailable), color = WebRedDark, fontSize = 10.sp)
                    }
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(menu.name, color = WebInk, fontWeight = FontWeight.SemiBold,
                    fontSize = 15.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
                menu.description?.takeIf { it.isNotBlank() }?.let {
                    Text(it, color = WebSub, fontSize = 12.sp,
                        maxLines = 2, overflow = TextOverflow.Ellipsis)
                }
                Text("฿" + menu.price, color = WebInk,
                    fontWeight = FontWeight.Bold, fontSize = 15.sp)
            }
            if (enabled) {
                // The row opens the existing option-detail flow. No
                // misleading quick-order "+" surface is shown on this page.
                Icon(Icons.Outlined.ChevronRight, null, tint = WebMuted,
                    modifier = Modifier.size(20.dp))
            }
        }
        HorizontalDivider(color = WebLine.copy(alpha = .45f),
            modifier = Modifier.padding(horizontal = 16.dp))
    }
}
