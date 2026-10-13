package online.wynos.food.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AccountCircle
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.PersonOutline
import androidx.compose.material.icons.outlined.ReceiptLong
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import online.wynos.food.R

private val BrandRed = Color(0xFFE40036)
private val PrimaryInk = Color(0xFF16161A)
private val SoftText = Color(0xFF6B6B76)
private val ThinLine = Color(0xFFEBEBEF)
private val ChipGrey = Color(0xFFF3F3F6)
private val SoftRed = Color(0xFFFCEDF0)

@Composable
fun WebTabHeader(title: String) {
    Box(
        modifier = Modifier.fillMaxWidth().height(56.dp)
            .background(Color.White).padding(horizontal = 16.dp),
        contentAlignment = Alignment.CenterStart,
    ) {
        Text(title, fontSize = 24.sp, fontWeight = FontWeight.Bold, color = PrimaryInk)
    }
}

@Composable
fun WebOrdersPage(state: FoodUiState, onRetry: () -> Unit, onBrowse: () -> Unit) {
    var selection by rememberSaveable { mutableIntStateOf(0) }
    val active = state.orders.filter { it.status !in setOf("delivered", "cancelled") }
    val history = state.orders.filter { it.status in setOf("delivered", "cancelled") }
    val current = if (selection == 0) active else history

    LazyColumn(
        modifier = Modifier.fillMaxSize().background(Color.White),
        contentPadding = PaddingValues(bottom = 22.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                listOf(
                    stringResource(R.string.active_orders),
                    stringResource(R.string.order_history_tab),
                ).forEachIndexed { id, title ->
                    val selected = selection == id
                    Surface(
                        modifier = Modifier.weight(1f).height(44.dp).clickable { selection = id },
                        shape = CircleShape,
                        color = if (selected) SoftRed else Color.White,
                        border = BorderStroke(if (selected) 1.5.dp else 1.dp, if (selected) BrandRed else ThinLine),
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(
                                title + if (id == 0 && active.isNotEmpty()) " (${active.size})" else "",
                                color = if (selected) BrandRed else SoftText,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 14.sp,
                            )
                        }
                    }
                }
            }
        }
        when {
            !state.configured -> item { EmptyPanel(stringResource(R.string.configure_supabase)) }
            state.accountEmail == null -> item { EmptyPanel(stringResource(R.string.sign_in_to_view_orders)) }
            state.ordersLoading -> item { Box(Modifier.fillMaxWidth().padding(30.dp), Alignment.Center) { CircularProgressIndicator(color = BrandRed) } }
            state.ordersFailed -> item {
                EmptyPanel(stringResource(R.string.orders_load_failed))
                OutlinedButton(
                    onClick = onRetry,
                    modifier = Modifier.padding(horizontal = 16.dp),
                ) { Text(stringResource(R.string.retry)) }
            }
            current.isEmpty() -> item {
                EmptyPanel(
                    stringResource(if (selection == 0) R.string.no_active_orders else R.string.no_past_orders)
                )
                Button(
                    onClick = onBrowse,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = BrandRed),
                    shape = CircleShape,
                ) { Text(stringResource(R.string.browse_food_now)) }
            }
            else -> {
                items(current, key = { it.id }) { order ->
                    Card(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                        shape = RoundedCornerShape(18.dp),
                        colors = CardDefaults.cardColors(containerColor = Color.White),
                        border = BorderStroke(1.dp, ThinLine),
                    ) {
                        Column(
                            modifier = Modifier.fillMaxWidth().padding(14.dp),
                            verticalArrangement = Arrangement.spacedBy(7.dp),
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text("#" + order.number, fontWeight = FontWeight.Bold, fontSize = 15.sp, color = PrimaryInk)
                                Text(
                                    order.status,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 12.sp,
                                    color = if (order.status == "delivered") Color(0xFF1F8A4C) else BrandRed,
                                    modifier = Modifier.clip(CircleShape).background(SoftRed)
                                        .padding(horizontal = 9.dp, vertical = 4.dp),
                                )
                            }
                            Text(stringResource(R.string.baht_price, order.total), fontSize = 14.sp, color = PrimaryInk, fontWeight = FontWeight.Bold)
                            Text(order.createdAt.take(16), fontSize = 12.sp, color = SoftText)
                            Text(stringResource(R.string.readonly_order_notice), fontSize = 12.sp, color = SoftText)
                        }
                    }
                }
                item {
                    OutlinedButton(onClick = onRetry, modifier = Modifier.padding(horizontal = 16.dp)) {
                        Text(stringResource(R.string.refresh_orders))
                    }
                }
            }
        }
    }
}

@Composable
fun WebMessagesPage() {
    Box(Modifier.fillMaxSize().background(Color.White), contentAlignment = Alignment.Center) {
        Column(
            Modifier.padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(Icons.Outlined.ChatBubbleOutline, null, tint = SoftText, modifier = Modifier.size(48.dp))
            Text(stringResource(R.string.no_messages), fontWeight = FontWeight.Bold, fontSize = 20.sp, color = PrimaryInk)
            Text(stringResource(R.string.messages_note), color = SoftText, fontSize = 14.sp)
        }
    }
}

@Composable
fun WebAccountPage(
    state: FoodUiState,
    onSignIn: (String, String) -> Unit,
    onSignOut: () -> Unit,
    onResetPassword: (String) -> Unit,
    onOrders: () -> Unit,
) {
    if (state.accountEmail == null) {
        WebLoginPage(state, onSignIn, onResetPassword)
    } else {
        LazyColumn(
            modifier = Modifier.fillMaxSize().background(Color.White),
            contentPadding = PaddingValues(top = 8.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)
                        .clip(RoundedCornerShape(18.dp)).background(Color(0xFFF6F6F8)).padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Surface(shape = CircleShape, color = ChipGrey, modifier = Modifier.size(48.dp)) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(Icons.Outlined.PersonOutline, null, tint = SoftText, modifier = Modifier.size(26.dp))
                        }
                    }
                    Column(Modifier.weight(1f)) {
                        Text(state.accountEmail.orEmpty(), fontWeight = FontWeight.Bold, color = PrimaryInk, fontSize = 15.sp)
                        Text(stringResource(R.string.wynos_food_profile), color = SoftText, fontSize = 12.sp)
                    }
                }
            }
            item {
                Text(stringResource(R.string.delivery_addresses), modifier = Modifier.padding(start = 16.dp, top = 12.dp),
                    fontWeight = FontWeight.Bold, fontSize = 18.sp, color = PrimaryInk)
                EmptyPanel(stringResource(R.string.addresses_not_yet_available))
            }
            item {
                HorizontalDivider(color = ThinLine, modifier = Modifier.padding(horizontal = 16.dp))
                Row(
                    modifier = Modifier.fillMaxWidth().clickable(onClick = onOrders)
                        .padding(horizontal = 16.dp, vertical = 18.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(Icons.Outlined.ReceiptLong, null, tint = PrimaryInk)
                    Text(stringResource(R.string.order_history_link), modifier = Modifier.weight(1f),
                        color = PrimaryInk, fontWeight = FontWeight.SemiBold)
                    Icon(Icons.Outlined.ChevronRight, null, tint = SoftText)
                }
                HorizontalDivider(color = ThinLine, modifier = Modifier.padding(horizontal = 16.dp))
                TextButton(onClick = onSignOut, enabled = !state.accountBusy, modifier = Modifier.padding(start = 16.dp)) {
                    Text(stringResource(R.string.sign_out), color = BrandRed, fontWeight = FontWeight.SemiBold)
                }
                if (state.accountBusy) CircularProgressIndicator(color = BrandRed, modifier = Modifier.padding(20.dp))
                if (state.accountFailed) Text(stringResource(R.string.account_action_failed), color = BrandRed, modifier = Modifier.padding(16.dp))
            }
        }
    }
}

@Composable
private fun WebLoginPage(
    state: FoodUiState,
    onSignIn: (String, String) -> Unit,
    onResetPassword: (String) -> Unit,
) {
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    Column(
        modifier = Modifier.fillMaxSize().background(Color.White)
            .imePadding().verticalScroll(rememberScrollState())
            .padding(horizontal = 18.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp))
                .background(Color.White).padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(11.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                androidx.compose.foundation.Image(
                    painterResource(R.drawable.food_logo),
                    contentDescription = null,
                    modifier = Modifier.size(48.dp).clip(RoundedCornerShape(14.dp)),
                )
                Text("WYNOS Food", fontSize = 21.sp, color = PrimaryInk, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(8.dp))
            Text(stringResource(R.string.food_login_heading), fontSize = 24.sp, color = PrimaryInk, fontWeight = FontWeight.Bold)
            Text(stringResource(R.string.food_login_note), fontSize = 12.5.sp, color = SoftText)
            Spacer(Modifier.height(6.dp))
            OutlinedTextField(
                value = email, onValueChange = { email = it },
                label = { Text(stringResource(R.string.email)) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                singleLine = true, shape = RoundedCornerShape(13.dp),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = password, onValueChange = { password = it },
                label = { Text(stringResource(R.string.password)) },
                visualTransformation = PasswordVisualTransformation(),
                singleLine = true, shape = RoundedCornerShape(13.dp),
                modifier = Modifier.fillMaxWidth(),
            )
            TextButton(
                enabled = email.isNotBlank() && !state.accountBusy,
                onClick = { onResetPassword(email) },
                modifier = Modifier.align(Alignment.End),
            ) {
                Text(stringResource(R.string.forgot_password), color = BrandRed, fontSize = 13.sp)
            }
            Button(
                onClick = { onSignIn(email, password) },
                enabled = email.isNotBlank() && password.isNotBlank() && !state.accountBusy,
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = CircleShape,
                colors = ButtonDefaults.buttonColors(containerColor = BrandRed),
            ) {
                Text(stringResource(R.string.sign_in), fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
            if (state.accountBusy || state.accountLoading) {
                CircularProgressIndicator(color = BrandRed, modifier = Modifier.padding(9.dp))
            }
            if (state.accountFailed) Text(stringResource(R.string.account_action_failed), color = BrandRed, fontSize = 13.sp)
            if (state.resetEmailSent) Text(stringResource(R.string.reset_email_sent), color = Color(0xFF1F8A4C), fontSize = 13.sp)
            if (!state.configured) Text(stringResource(R.string.configure_supabase), color = BrandRed)
            Text(stringResource(R.string.account_signup_pending), fontSize = 12.sp, color = SoftText)
        }
    }
}

@Composable
private fun EmptyPanel(message: String) {
    Box(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp)
            .clip(RoundedCornerShape(16.dp)).background(Color(0xFFF6F6F8))
            .padding(vertical = 24.dp, horizontal = 16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(message, fontSize = 14.sp, color = SoftText)
    }
}
