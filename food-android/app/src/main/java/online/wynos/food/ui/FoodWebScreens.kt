package online.wynos.food.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.ChevronRight
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
import androidx.compose.material.icons.outlined.Storefront
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
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
private fun WebImage(path: String?, bucket: String, modifier: Modifier = Modifier) {
    val url = FoodPublicMedia.url(bucket, path)
    Box(modifier.background(WebSurface), contentAlignment = Alignment.Center) {
        if (url == null) {
            Icon(Icons.Outlined.Restaurant, null, tint = WebMuted, modifier = Modifier.size(30.dp))
        } else {
            AsyncImage(
                model = url,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

@Composable
fun WebHomeHeader(guest: Boolean, cartCount: Int, onAccount: () -> Unit, onCart: () -> Unit) {
    Column(Modifier.fillMaxWidth().background(Color.White).padding(start = 16.dp, end = 12.dp, top = 8.dp, bottom = 6.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Image(
                    painter = painterResource(R.drawable.food_logo),
                    contentDescription = null,
                    modifier = Modifier.size(32.dp).clip(RoundedCornerShape(9.dp)),
                )
                Text(buildAnnotatedString {
                    withStyle(SpanStyle(color = WebInk, fontWeight = FontWeight.Bold)) { append("WYNOS ") }
                    withStyle(SpanStyle(color = WebRed, fontWeight = FontWeight.Bold)) { append("Food") }
                }, fontSize = 20.sp)
            }
            if (guest) {
                OutlinedButton(
                    onClick = onAccount,
                    shape = CircleShape,
                    border = androidx.compose.foundation.BorderStroke(1.dp, WebRed),
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    modifier = Modifier.height(40.dp),
                ) {
                    Text(stringResource(R.string.guest_sign_in), color = WebRed, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
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
            Row(
                modifier = Modifier.padding(top = 3.dp, bottom = 2.dp).height(42.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(Icons.Outlined.LocationOn, null, tint = WebRed, modifier = Modifier.size(20.dp))
                Column {
                    Text(stringResource(R.string.delivery_to), fontSize = 12.sp, color = WebSub)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(stringResource(R.string.select_delivery), fontSize = 15.sp, color = WebInk, fontWeight = FontWeight.Bold)
                        Icon(Icons.Outlined.KeyboardArrowDown, null, tint = WebSub, modifier = Modifier.size(18.dp))
                    }
                }
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
fun WebBottomNavigation(tab: Int, onTab: (Int) -> Unit) {
    val items = listOf(
        Triple(0, R.string.home, Icons.Outlined.Home),
        Triple(1, R.string.orders, Icons.Outlined.ReceiptLong),
        Triple(2, R.string.messages, Icons.Outlined.ChatBubbleOutline),
        Triple(3, R.string.account, Icons.Outlined.PersonOutline),
    )
    Box(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 12.dp, vertical = 8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth().shadow(12.dp, RoundedCornerShape(30.dp))
                .clip(RoundedCornerShape(30.dp)).background(Color.White)
                .padding(horizontal = 6.dp, vertical = 4.dp).height(56.dp),
        ) {
            items.forEach { (id, label, image) ->
                val selected = tab == id
                Column(
                    modifier = Modifier.weight(1f).fillMaxSize().clip(RoundedCornerShape(28.dp)).clickable { onTab(id) },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Box(
                        modifier = Modifier.size(width = 48.dp, height = 28.dp)
                            .clip(CircleShape).background(if (selected) WebRedSoft else Color.Transparent),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(image, null, tint = if (selected) WebRed else WebMuted, modifier = Modifier.size(22.dp))
                    }
                    Text(
                        stringResource(label),
                        color = if (selected) WebRed else WebMuted,
                        fontSize = 10.5.sp,
                        fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                    )
                }
            }
        }
    }
}

@Composable
fun WebHomeScreen(
    state: FoodUiState,
    guest: Boolean,
    onAccount: () -> Unit,
    onStore: (String) -> Unit,
    onRetry: () -> Unit,
) {
    var query by rememberSaveable { mutableStateOf("") }
    var filter by rememberSaveable { mutableStateOf("all") }
    val filtered = state.stores.filter { store ->
        (query.isBlank() || store.name.contains(query.trim(), ignoreCase = true) ||
            store.menu.any { it.name.contains(query.trim(), ignoreCase = true) }) &&
            (filter != "open" || store.isOpen)
    }
    LazyColumn(
        modifier = Modifier.fillMaxSize().background(Color.White),
        contentPadding = PaddingValues(bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(0.dp),
    ) {
        if (guest) {
            item {
                Column(
                    Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 9.dp)
                        .clip(RoundedCornerShape(20.dp))
                        .background(Brush.horizontalGradient(listOf(WebRedSoft, Color.White)))
                        .padding(18.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Surface(color = Color.White, shape = CircleShape) {
                        Row(
                            Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            Icon(Icons.Outlined.LocationOn, null, tint = WebRed, modifier = Modifier.size(14.dp))
                            Text(stringResource(R.string.guest_location), color = WebRed, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
                        }
                    }
                    Text(stringResource(R.string.guest_hero_title), fontSize = 22.sp, lineHeight = 29.sp, fontWeight = FontWeight.Bold, color = WebInk)
                    Text(stringResource(R.string.guest_hero_note), fontSize = 14.sp, lineHeight = 22.sp, color = WebSub)
                }
            }
        }
        item {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp)
                    .height(48.dp).clip(CircleShape).background(WebChip).padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Icon(Icons.Outlined.Search, null, tint = WebMuted, modifier = Modifier.size(20.dp))
                BasicTextField(
                    value = query,
                    onValueChange = { query = it },
                    singleLine = true,
                    textStyle = androidx.compose.ui.text.TextStyle(color = WebInk, fontSize = 16.sp),
                    modifier = Modifier.weight(1f),
                    decorationBox = { inner ->
                        Box {
                            if (query.isEmpty()) Text(stringResource(R.string.search_food_hint), color = WebMuted, fontSize = 16.sp)
                            inner()
                        }
                    },
                )
                if (query.isNotEmpty()) {
                    Icon(Icons.Outlined.Close, null, tint = WebMuted, modifier = Modifier.size(19.dp).clickable { query = "" })
                }
            }
        }
        if (!guest) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    listOf(
                        "all" to R.string.filter_all,
                        "open" to R.string.filter_open,
                    ).forEach { (code, label) ->
                        FilterChipWeb(
                            title = stringResource(label),
                            selected = filter == code,
                            onClick = { filter = code },
                        )
                    }
                }
            }
        }
        if (query.isBlank() && state.banners.isNotEmpty()) {
            item { BannerStrip(state.banners, onStore) }
        }
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
                item { SectionTitleWeb(stringResource(if (guest) R.string.public_stores else R.string.recommended_stores)) }
                items(filtered.chunked(2), key = { row -> row.first().id }) { row ->
                    Row(
                        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        row.forEach { store ->
                            StoreCardWeb(store, Modifier.weight(1f), showRating = !guest, onClick = { onStore(store.id) })
                        }
                        if (row.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
                if (!guest) {
                    item { SectionTitleWeb(stringResource(R.string.public_stores)) }
                    items(filtered.chunked(2), key = { row -> "all_" + row.first().id }) { row ->
                        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            row.forEach { store -> StoreCardWeb(store, Modifier.weight(1f), showRating = true, onClick = { onStore(store.id) }) }
                            if (row.size == 1) Spacer(Modifier.weight(1f))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun BannerStrip(banners: List<FoodHomeBanner>, onStore: (String) -> Unit) {
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val width = (maxWidth * .9f).coerceAtMost(460.dp)
        LazyRow(
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            items(banners, key = { it.id }) { banner ->
                Box(
                    Modifier.width(width).aspectRatio(2.4f).clip(RoundedCornerShape(16.dp))
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
private fun SectionTitleWeb(title: String) {
    Text(
        title,
        color = WebInk,
        fontWeight = FontWeight.Bold,
        fontSize = 18.sp,
        modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 21.dp, bottom = 5.dp),
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
    Surface(
        shape = CircleShape,
        color = if (selected) WebRed else Color.White,
        border = if (selected) null else androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFDCDCE2)),
        modifier = Modifier.height(40.dp).clickable(onClick = onClick),
    ) {
        Box(Modifier.padding(horizontal = 16.dp), contentAlignment = Alignment.Center) {
            Text(title, fontSize = 14.sp, color = if (selected) Color.White else WebInk, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun StoreCardWeb(store: FoodStore, modifier: Modifier, showRating: Boolean, onClick: () -> Unit) {
    Column(
        modifier = modifier.clickable(onClick = onClick),
        verticalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Box(Modifier.fillMaxWidth().aspectRatio(4f / 3f).clip(RoundedCornerShape(16.dp))) {
            WebImage(store.coverPath, "food-public", Modifier.fillMaxSize())
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
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            TagWeb(stringResource(R.string.store_menu_count, store.menu.size))
            TagWeb(stringResource(R.string.store_delivery, "฿" + (store.deliveryFee ?: "—")))
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

@Composable
fun WebStoreScreen(
    store: FoodStore,
    cart: FoodCartDraft,
    cartError: Boolean,
    guest: Boolean,
    onBack: () -> Unit,
    onAccount: () -> Unit,
    onAdd: (FoodStore, FoodMenu, Map<String, Set<String>>, Int) -> Boolean,
    onClear: () -> Unit,
) {
    var selectedMenu by remember(store.id) { mutableStateOf<FoodMenu?>(null) }
    var showCart by remember(store.id) { mutableStateOf(false) }
    var storeTab by rememberSaveable(store.id) { mutableIntStateOf(0) }
    var category by rememberSaveable(store.id) { mutableStateOf("ทั้งหมด") }
    val categories = listOf("ทั้งหมด") + store.menu.map { it.category }.filter { it.isNotBlank() }.distinct()
    val available = store.menu.filter { it.isAvailable() }
    val groupedMenus = store.menu
        .filter { category == "ทั้งหมด" || category == it.category }
        .groupBy { if (it.category.isBlank()) "เมนูอาหาร" else it.category }
    LazyColumn(
        Modifier.fillMaxSize().background(Color.White),
        contentPadding = PaddingValues(bottom = 34.dp),
    ) {
        item {
            // CSS uses margin-top:-20px to overlap the cover. Negative
            // spacing overlaps in layout as well, avoiding a blank 20dp gap.
            Column(verticalArrangement = Arrangement.spacedBy((-20).dp)) {
                Box(Modifier.fillMaxWidth().height(230.dp)) {
                    WebImage(store.coverPath, "food-public", Modifier.fillMaxSize())
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
                Column(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp))
                        .background(Color.White).padding(start = 16.dp, end = 16.dp, top = 18.dp, bottom = 3.dp),
                    verticalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    Text(store.name, fontSize = 23.sp, lineHeight = 27.sp, fontWeight = FontWeight.Bold, color = WebInk)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (guest) {
                            Text(
                                stringResource(R.string.store_meta_guest, store.menu.size, store.deliveryFee ?: "—"),
                                color = WebSub, fontSize = 13.5.sp, lineHeight = 18.sp,
                            )
                        } else {
                            Icon(Icons.Outlined.Star, null, tint = Color(0xFFF5A623), modifier = Modifier.size(14.dp))
                            Text(" " + stringResource(R.string.store_new) + " · ", color = WebSub, fontSize = 13.sp)
                            Text(stringResource(R.string.store_menu_count, store.menu.size), color = WebSub, fontSize = 13.sp)
                            Text(" · ฿" + (store.deliveryFee ?: "—"), color = WebSub, fontSize = 13.sp)
                        }
                    }
                    if (store.isOpen) {
                        Text(stringResource(R.string.store_open_now), color = WebGreen, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    } else {
                        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(WebRedSoft).padding(12.dp)) {
                            Text(stringResource(R.string.store_closed_now), color = WebRedDark, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            Text(stringResource(R.string.store_closed_note), color = WebSub, fontSize = 13.sp)
                        }
                    }
                    store.description?.let { Text(it, color = WebSub, fontSize = 13.sp) }
                    if (guest && !store.address.isNullOrBlank()) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            Icon(Icons.Outlined.LocationOn, null, tint = WebSub, modifier = Modifier.size(14.dp))
                            Text(store.address, color = WebSub, fontSize = 13.sp)
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
                        Box(Modifier.height(43.dp), contentAlignment = Alignment.Center) {
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
                            FilterChipWeb(name, selected = name == category, onClick = { category = name })
                        }
                    }
                }
            }
            if (!guest && category == "ทั้งหมด" && available.size >= 3) {
                item { SectionTitleWeb(stringResource(R.string.popular_menu)) }
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
                item { SectionTitleWeb(name) }
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
            onAdd = { opts, qty -> if (onAdd(store, menu, opts, qty)) selectedMenu = null },
        )
    }
    if (showCart) FoodCartPreview(cart, onDismiss = { showCart = false }, onClear = { onClear(); showCart = false })
}

@Composable
private fun RoundHeroButton(icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    Surface(shape = CircleShape, color = Color.White, modifier = Modifier.size(40.dp).clickable(onClick = onClick), shadowElevation = 3.dp) {
        Box(contentAlignment = Alignment.Center) { Icon(icon, null, tint = WebInk, modifier = Modifier.size(21.dp)) }
    }
}

@Composable
private fun WebMenuRow(menu: FoodMenu, enabled: Boolean, onClick: () -> Unit) {
    Column {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 136.dp).clickable(enabled = enabled, onClick = onClick)
                .padding(horizontal = 16.dp, vertical = 16.dp),
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(13.dp),
        ) {
            Box(Modifier.size(104.dp)) {
                WebImage(menu.imagePath, "food-public", Modifier.fillMaxSize().clip(RoundedCornerShape(14.dp)))
                if (!enabled) {
                    Box(Modifier.align(Alignment.BottomCenter).clip(CircleShape).background(WebRedSoft).padding(5.dp)) {
                        Text(stringResource(R.string.menu_unavailable), color = WebRedDark, fontSize = 10.sp)
                    }
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Text(menu.name, color = WebInk, fontWeight = FontWeight.Bold, fontSize = 15.sp, maxLines = 2)
                menu.description?.let { Text(it, color = WebSub, fontSize = 12.sp, maxLines = 2) }
                Text("฿" + menu.price, color = WebInk, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
            if (enabled) {
                Box(
                    Modifier.size(36.dp).align(Alignment.Bottom).shadow(4.dp, CircleShape)
                        .background(WebRed, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Outlined.Add, null, tint = Color.White, modifier = Modifier.size(23.dp))
                }
            }
        }
        HorizontalDivider(color = WebLine.copy(alpha = .65f), modifier = Modifier.padding(horizontal = 16.dp))
    }
}
