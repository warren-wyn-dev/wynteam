package online.wynos.food.ui

import androidx.activity.compose.BackHandler
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
import androidx.compose.foundation.text.KeyboardOptions
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
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import online.wynos.food.R
import online.wynos.food.data.FoodMenu
import online.wynos.food.data.FoodCartDraft
import online.wynos.food.data.FoodStore

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FoodApp(vm: FoodViewModel = viewModel()) {
    val state by vm.uiState.collectAsStateWithLifecycle()
    var tab by rememberSaveable { mutableIntStateOf(0) }
    var selectedStoreId by rememberSaveable { mutableStateOf<String?>(null) }
    var homeCart by rememberSaveable { mutableStateOf(false) }
    val guest = state.accountEmail == null
    val selectedStore = state.stores.firstOrNull { it.id == selectedStoreId }

    BackHandler(enabled = selectedStore != null && tab == 0) {
        selectedStoreId = null
    }

    Scaffold(
        containerColor = androidx.compose.ui.graphics.Color.White,
        topBar = {
            if (selectedStore == null) {
                if (tab == 0) {
                    WebHomeHeader(
                        guest = guest,
                        cartCount = state.cart.itemCount,
                        onAccount = { selectedStoreId = null; tab = 3 },
                        onCart = { homeCart = true },
                    )
                } else if (!guest) {
                    val title = when (tab) {
                        1 -> stringResource(R.string.my_orders_title)
                        2 -> stringResource(R.string.messages)
                        else -> stringResource(R.string.account)
                    }
                    WebTabHeader(title)
                }
            }
        },
        bottomBar = {
            // Signed-out website is a guest storefront without a bottom bar.
            if (!guest) {
                WebBottomNavigation(
                    tab = tab,
                    onTab = { tab = it; selectedStoreId = null },
                )
            }
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when {
                tab == 0 && selectedStore != null -> WebStoreScreen(
                    store = selectedStore,
                    cart = state.cart,
                    cartError = state.cartError,
                    guest = guest,
                    onBack = { selectedStoreId = null },
                    onAccount = { selectedStoreId = null; tab = 3 },
                    onAdd = vm::addToCart,
                    onClear = vm::clearCart,
                )
                tab == 0 -> WebHomeScreen(
                    state = state,
                    guest = guest,
                    onAccount = { tab = 3 },
                    onStore = { selectedStoreId = it },
                    onRetry = vm::refreshCatalog,
                )
                tab == 1 -> WebOrdersPage(
                    state = state,
                    onRetry = vm::refreshOrders,
                    onBrowse = { tab = 0 },
                )
                tab == 2 -> WebMessagesPage()
                else -> WebAccountPage(
                    state = state,
                    onSignIn = vm::signIn,
                    onSignOut = vm::signOut,
                    onResetPassword = vm::requestPasswordReset,
                    onOrders = { tab = 1 },
                )
            }
        }
    }
    if (homeCart) {
        FoodCartPreview(
            cart = state.cart,
            onDismiss = { homeCart = false },
            onClear = { vm.clearCart(); homeCart = false },
        )
    }
}

@Composable
private fun ReadOnlyNotice() {
    Surface(color = MaterialTheme.colorScheme.primary.copy(alpha = 0.09f)) {
        Text(
            text = stringResource(R.string.readonly_notice),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
        )
    }
}

@Composable
private fun HomeContent(
    state: FoodUiState,
    onSelectStore: (String) -> Unit,
    onRetry: () -> Unit,
) {
    var query by rememberSaveable { mutableStateOf("") }
    val filteredStores = state.stores.filter { store ->
        query.isBlank() || store.name.contains(query.trim(), ignoreCase = true) ||
            store.menu.any { it.name.contains(query.trim(), ignoreCase = true) }
    }
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item {
            Text(stringResource(R.string.browse_heading), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Text(stringResource(R.string.browse_intro), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                label = { Text(stringResource(R.string.search_stores)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        when {
            !state.configured -> item { InfoState(R.string.configure_supabase) }
            state.catalogLoading -> item { LoadingState() }
            state.catalogFailed -> item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    InfoState(R.string.catalog_load_failed)
                    OutlinedButton(onClick = onRetry) { Text(stringResource(R.string.retry)) }
                }
            }
            filteredStores.isEmpty() -> item { InfoState(R.string.no_stores) }
            else -> {
                item { Text(stringResource(R.string.stores_heading), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
                items(filteredStores, key = { it.id }) { store ->
                    Card(
                        onClick = { onSelectStore(store.id) },
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                        shape = RoundedCornerShape(16.dp),
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(14.dp),
                        ) {
                            Icon(Icons.Outlined.RestaurantMenu, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(34.dp))
                            Column(Modifier.weight(1f)) {
                                Text(store.name, fontWeight = FontWeight.SemiBold)
                                store.description?.let {
                                    Text(it, style = MaterialTheme.typography.bodySmall, maxLines = 2)
                                }
                                Text(
                                    stringResource(if (store.isOpen) R.string.store_open else R.string.store_closed),
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
    }
}

@Composable
private fun StoreContent(
    store: FoodStore,
    cart: FoodCartDraft,
    cartError: Boolean,
    onAdd: (FoodStore, FoodMenu, Map<String, Set<String>>, Int) -> Boolean,
    onClear: () -> Unit,
) {
    var selectedMenu by androidx.compose.runtime.remember(store.id) { mutableStateOf<FoodMenu?>(null) }
    var showCart by androidx.compose.runtime.remember(store.id) { mutableStateOf(false) }
    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text(store.name, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            store.description?.let { Text(it) }
            Text(
                stringResource(if (store.isOpen) R.string.store_open else R.string.store_closed),
                color = MaterialTheme.colorScheme.primary,
            )
            store.deliveryFee?.let {
                Text(stringResource(R.string.delivery_fee, it), style = MaterialTheme.typography.bodySmall)
            }
            Spacer(Modifier.height(12.dp))
            Text(stringResource(R.string.menu_heading), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        }
        if (store.menu.isEmpty()) {
            item { InfoState(R.string.no_menu) }
        } else {
            items(store.menu, key = { it.id }) { menu ->
                MenuRow(menu, enabled = store.isOpen && menu.isAvailable()) { selectedMenu = menu }
            }
        }
        item {
            HorizontalDivider()
            if (cart.storeId == store.id && cart.itemCount > 0) {
                Button(onClick = { showCart = true }, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.view_cart, cart.itemCount))
                }
            }
            if (cartError) Text(
                stringResource(R.string.cart_validation_error),
                color = MaterialTheme.colorScheme.error,
            )
            Text(stringResource(R.string.checkout_unavailable), style = MaterialTheme.typography.bodySmall)
            Button(onClick = {}, enabled = false, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.order_disabled))
            }
        }
    }
    selectedMenu?.let { menu ->
        FoodMenuOptionsDialog(
            menu = menu,
            onDismiss = { selectedMenu = null },
            onAdd = { selected, quantity ->
                if (onAdd(store, menu, selected, quantity)) selectedMenu = null
            },
        )
    }
    if (showCart) {
        FoodCartPreview(
            cart = cart,
            onDismiss = { showCart = false },
            onClear = { onClear(); showCart = false },
        )
    }
}

@Composable
private fun MenuRow(menu: FoodMenu, enabled: Boolean, onClick: () -> Unit) {
    Card(
        onClick = onClick,
        enabled = enabled,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        shape = RoundedCornerShape(14.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text(menu.name, fontWeight = FontWeight.SemiBold)
                if (menu.category.isNotBlank()) Text(menu.category, style = MaterialTheme.typography.bodySmall)
                menu.description?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
                if (!enabled) Text(stringResource(R.string.menu_unavailable), style = MaterialTheme.typography.labelSmall)
                if (menu.optionGroupNames.isNotEmpty()) {
                    Text(
                        stringResource(R.string.menu_options, menu.optionGroupNames.joinToString(" · ")),
                        style = MaterialTheme.typography.labelSmall,
                    )
                }
            }
            Text(stringResource(R.string.baht_price, menu.price), color = MaterialTheme.colorScheme.primary)
        }
    }
}

@Composable
private fun AccountContent(
    state: FoodUiState,
    onSignIn: (String, String) -> Unit,
    onSignOut: () -> Unit,
    onResetPassword: (String) -> Unit,
) {
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    Column(
        modifier = Modifier.fillMaxSize().padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(stringResource(R.string.wynos_account), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        if (!state.configured) {
            InfoState(R.string.configure_supabase)
        } else if (state.accountLoading) {
            LoadingState()
        } else if (state.accountEmail != null) {
            Text(stringResource(R.string.signed_in_as, state.accountEmail.orEmpty()))
            OutlinedButton(onClick = onSignOut, enabled = !state.accountBusy) {
                Text(stringResource(R.string.sign_out))
            }
        } else {
            Text(stringResource(R.string.existing_accounts_only), style = MaterialTheme.typography.bodySmall)
            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text(stringResource(R.string.email)) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text(stringResource(R.string.password)) },
                visualTransformation = PasswordVisualTransformation(),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Button(
                onClick = { onSignIn(email, password) },
                enabled = !state.accountBusy && email.isNotBlank() && password.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(stringResource(R.string.sign_in))
            }
            OutlinedButton(
                onClick = { onResetPassword(email) },
                enabled = !state.accountBusy && email.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(stringResource(R.string.forgot_password))
            }
            if (state.resetEmailSent) Text(stringResource(R.string.reset_email_sent))
        }
        if (state.accountBusy) LoadingState()
        if (state.accountFailed) InfoState(R.string.account_action_failed)
    }
}

@Composable
private fun InfoState(messageRes: Int) {
    Text(
        stringResource(messageRes),
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f),
        modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
    )
}

@Composable
private fun LoadingState() {
    Box(Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) {
        CircularProgressIndicator()
    }
}

@Composable
private fun OrdersContent(state: FoodUiState, onRetry: () -> Unit) {
    LazyColumn(
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text(stringResource(R.string.orders), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        }
        when {
            !state.configured -> item { InfoState(R.string.configure_supabase) }
            state.accountLoading -> item { LoadingState() }
            state.accountEmail == null -> item { InfoState(R.string.sign_in_to_view_orders) }
            state.ordersLoading -> item { LoadingState() }
            state.ordersFailed -> item {
                InfoState(R.string.orders_load_failed)
                OutlinedButton(onClick = onRetry) { Text(stringResource(R.string.retry)) }
            }
            state.orders.isEmpty() -> item { InfoState(R.string.orders_none) }
            else -> {
                item { OutlinedButton(onClick = onRetry) { Text(stringResource(R.string.refresh_orders)) } }
                items(state.orders, key = { it.id }) { order ->
                    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
                        Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(order.number, fontWeight = FontWeight.SemiBold)
                            Text(stringResource(R.string.order_status_value, order.status))
                            Text(stringResource(R.string.order_payment_value, order.paymentStatus))
                            Text(stringResource(R.string.baht_price, order.total))
                            Text(order.createdAt.take(16), style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Placeholder(messageRes: Int) {
    Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
        Text(stringResource(messageRes), style = MaterialTheme.typography.bodyMedium)
    }
}
