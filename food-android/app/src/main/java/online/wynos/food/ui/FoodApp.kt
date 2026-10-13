package online.wynos.food.ui

import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.PersonOutline
import androidx.compose.material.icons.outlined.ReceiptLong
import androidx.compose.material.icons.outlined.RestaurantMenu
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import online.wynos.food.R
import online.wynos.food.data.DemoCatalog
import online.wynos.food.data.DemoStore

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FoodApp() {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    var storeId by rememberSaveable { mutableStateOf<String?>(null) }
    val selectedStore = storeId?.let(DemoCatalog::store)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(selectedStore?.name ?: "WYNOS Food", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    if (selectedStore != null && tab == 0) {
                        IconButton(onClick = { storeId = null }) {
                            Icon(Icons.Outlined.ArrowBack, contentDescription = androidx.compose.ui.res.stringResource(R.string.back))
                        }
                    }
                },
            )
        },
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = tab == 0,
                    onClick = { tab = 0; storeId = null },
                    icon = { Icon(Icons.Outlined.Home, contentDescription = null) },
                    label = { Text(androidx.compose.ui.res.stringResource(R.string.home)) },
                )
                NavigationBarItem(
                    selected = tab == 1,
                    onClick = { tab = 1; storeId = null },
                    icon = { Icon(Icons.Outlined.ReceiptLong, contentDescription = null) },
                    label = { Text(androidx.compose.ui.res.stringResource(R.string.orders)) },
                )
                NavigationBarItem(
                    selected = tab == 2,
                    onClick = { tab = 2; storeId = null },
                    icon = { Icon(Icons.Outlined.PersonOutline, contentDescription = null) },
                    label = { Text(androidx.compose.ui.res.stringResource(R.string.account)) },
                )
            }
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            DemoNotice()
            when (tab) {
                0 -> if (selectedStore == null) {
                    HomeContent(onStore = { storeId = it })
                } else {
                    StoreContent(selectedStore)
                }
                1 -> Placeholder(R.string.orders_empty)
                else -> Placeholder(R.string.account_empty)
            }
        }
    }
}

@Composable
private fun DemoNotice() {
    Surface(color = MaterialTheme.colorScheme.primary.copy(alpha = 0.09f)) {
        Text(
            text = androidx.compose.ui.res.stringResource(R.string.demo_notice),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
        )
    }
}

@Composable
private fun HomeContent(onStore: (String) -> Unit) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item {
            Text(
                androidx.compose.ui.res.stringResource(R.string.browse_heading),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )
            Text(
                androidx.compose.ui.res.stringResource(R.string.browse_intro),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.65f),
            )
        }
        item {
            Surface(
                shape = RoundedCornerShape(18.dp),
                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.09f),
            ) {
                Column(Modifier.fillMaxWidth().padding(22.dp)) {
                    Text(
                        androidx.compose.ui.res.stringResource(R.string.promotional_title),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        androidx.compose.ui.res.stringResource(R.string.promotional_subtitle),
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        }
        item {
            Text(
                androidx.compose.ui.res.stringResource(R.string.stores_heading),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
        }
        items(DemoCatalog.stores, key = { it.id }) { store ->
            Card(
                onClick = { onStore(store.id) },
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                shape = RoundedCornerShape(16.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        modifier = Modifier.size(62.dp).background(
                            MaterialTheme.colorScheme.primary.copy(alpha = 0.13f),
                            RoundedCornerShape(12.dp),
                        ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(Icons.Outlined.RestaurantMenu, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    }
                    Column(Modifier.weight(1f).padding(start = 14.dp)) {
                        Text(store.name, fontWeight = FontWeight.SemiBold)
                        Text(store.category, style = MaterialTheme.typography.bodySmall)
                        Text(
                            androidx.compose.ui.res.stringResource(R.string.delivery_by_store),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    }
                    Icon(Icons.Outlined.ChevronRight, contentDescription = null)
                }
            }
        }
    }
}

@Composable
private fun StoreContent(store: DemoStore) {
    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text(
                androidx.compose.ui.res.stringResource(R.string.sample_store),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary,
            )
            Spacer(Modifier.height(8.dp))
            Text(store.name, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Text(store.category, style = MaterialTheme.typography.bodyMedium)
            Spacer(Modifier.height(16.dp))
            Text(
                androidx.compose.ui.res.stringResource(R.string.menu_heading),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
        }
        items(store.dishes, key = { it.name }) { dish ->
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                shape = RoundedCornerShape(14.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(dish.name, fontWeight = FontWeight.SemiBold)
                    Text("${dish.priceBaht} ฿", color = MaterialTheme.colorScheme.primary)
                }
            }
        }
        item {
            HorizontalDivider()
            Text(
                androidx.compose.ui.res.stringResource(R.string.demo_notice),
                style = MaterialTheme.typography.bodySmall,
            )
            Button(
                onClick = {},
                enabled = false,
                modifier = Modifier.fillMaxWidth(),
            ) { Text(androidx.compose.ui.res.stringResource(R.string.order_disabled)) }
        }
    }
}

@Composable
private fun Placeholder(messageRes: Int) {
    Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                androidx.compose.ui.res.stringResource(R.string.coming_soon),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                androidx.compose.ui.res.stringResource(messageRes),
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}
