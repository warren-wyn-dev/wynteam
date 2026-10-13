package online.wynos.food.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import online.wynos.food.R
import online.wynos.food.data.FoodOrderDetail
import online.wynos.food.data.FoodOrderEventDetail
import java.math.BigDecimal

private val DetailInk = Color(0xFF16161A)
private val DetailSub = Color(0xFF6B6B76)
private val DetailRed = Color(0xFFE40036)
private val DetailGrey = Color(0xFFF6F6F8)

@Composable
private fun paymentLabel(status: String): String = when (status) {
    "pending" -> stringResource(R.string.food_payment_pending)
    "submitted" -> stringResource(R.string.food_payment_submitted)
    "paid" -> stringResource(R.string.food_payment_paid)
    "issue" -> stringResource(R.string.food_payment_issue)
    "refunded" -> stringResource(R.string.food_payment_refunded)
    else -> status
}

@Composable
private fun eventLabel(event: FoodOrderEventDetail): String {
    val changedTo = event.toStatus
    if (changedTo in setOf("pending_acceptance", "preparing", "ready_for_delivery",
            "out_for_delivery", "delivered", "cancelled")) {
        return foodOrderStatusLabel(changedTo!!)
    }
    return when (event.type) {
        "created" -> stringResource(R.string.food_event_created)
        "payment_submitted" -> stringResource(R.string.food_payment_submitted)
        else -> event.type.replace('_', ' ')
    }
}

/**
 * Read-only details from the existing Food backend: no simulated delivery progress,
 * order submission, payment button, or unverified fulfillment claims.
 */
@Composable
fun FoodOrderDetailDialog(
    state: FoodUiState,
    onClose: () -> Unit,
    onRefresh: (String) -> Unit,
) {
    val orderId = state.selectedOrderId ?: return
    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Surface(color = Color.White, modifier = Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize()) {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(stringResource(R.string.food_order_detail_title),
                        fontSize = 21.sp, fontWeight = FontWeight.Bold, color = DetailInk)
                    IconButton(onClick = onClose) {
                        Icon(Icons.Outlined.Close, stringResource(R.string.close))
                    }
                }
                HorizontalDivider()
                when {
                    state.orderDetailLoading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = DetailRed)
                    }
                    state.orderDetailFailed || state.orderDetail == null -> Column(
                        Modifier.fillMaxSize().padding(20.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Text(stringResource(R.string.food_order_detail_error), color = DetailRed)
                        OutlinedButton(onClick = { onRefresh(orderId) }) {
                            Text(stringResource(R.string.retry))
                        }
                    }
                    else -> {
                        val detail = state.orderDetail
                        Column(
                            Modifier.weight(1f).verticalScroll(rememberScrollState())
                                .padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(14.dp),
                        ) {
                            Row(
                                Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                            ) {
                                Text("#" + detail.number, color = DetailInk,
                                    fontWeight = FontWeight.Bold, fontSize = 18.sp)
                                Text(foodOrderStatusLabel(detail.status), color = DetailRed,
                                    fontWeight = FontWeight.SemiBold)
                            }
                            Text(detail.createdAt.take(19).replace('T', ' '),
                                color = DetailSub, fontSize = 12.sp)
                            InfoSection {
                                Text(stringResource(R.string.food_order_detail_delivery),
                                    color = DetailInk, fontWeight = FontWeight.Bold)
                                Text(detail.recipientName, color = DetailInk)
                                Text(detail.recipientPhone, color = DetailSub, fontSize = 13.sp)
                                Text(detail.shippingAddress, color = DetailSub, fontSize = 13.sp)
                                detail.note?.takeIf { it.isNotBlank() }?.let {
                                    Text(stringResource(R.string.menu_note_title) + ": " + it,
                                        color = DetailSub, fontSize = 12.sp)
                                }
                            }
                            InfoSection {
                                Text(stringResource(R.string.food_order_detail_payment),
                                    color = DetailInk, fontWeight = FontWeight.Bold)
                                Text(paymentLabel(detail.paymentStatus),
                                    color = if (detail.paymentStatus == "paid") Color(0xFF187B43) else DetailRed)
                            }
                            InfoSection {
                                Text(stringResource(R.string.food_order_detail_items),
                                    color = DetailInk, fontWeight = FontWeight.Bold)
                                detail.items.forEach { item ->
                                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                            Text(item.name + " × " + item.quantity, color = DetailInk)
                                            if (item.options.isNotEmpty()) {
                                                Text(item.options.joinToString(" · "), color = DetailSub, fontSize = 12.sp)
                                            }
                                            item.note?.takeIf { it.isNotBlank() }?.let {
                                                Text(it, color = DetailSub, fontSize = 12.sp)
                                            }
                                        }
                                        val amount = item.unitPrice.toBigDecimalOrNull()
                                            ?.multiply(BigDecimal.valueOf(item.quantity.toLong()))
                                            ?.stripTrailingZeros()?.toPlainString() ?: "—"
                                        Text("฿" + amount, color = DetailInk, fontWeight = FontWeight.SemiBold)
                                    }
                                }
                                HorizontalDivider()
                                MoneyDetailRow(stringResource(R.string.estimated_subtotal_label), detail.subtotal)
                                MoneyDetailRow(stringResource(R.string.server_delivery_fee), detail.deliveryFee)
                                MoneyDetailRow(stringResource(R.string.server_campaign_discount), "-" + detail.campaignDiscount)
                                MoneyDetailRow(stringResource(R.string.server_delivery_discount), "-" + detail.deliveryDiscount)
                                HorizontalDivider()
                                MoneyDetailRow(stringResource(R.string.server_quote_total), detail.total, true)
                            }
                            InfoSection {
                                Text(stringResource(R.string.food_order_detail_events),
                                    color = DetailInk, fontWeight = FontWeight.Bold)
                                if (detail.events.isEmpty()) {
                                    Text(stringResource(R.string.food_order_detail_no_events), color = DetailSub)
                                } else detail.events.forEach { event ->
                                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                        Text(eventLabel(event), color = DetailInk,
                                            modifier = Modifier.weight(1f), fontSize = 13.sp)
                                        Text(event.createdAt.take(16).replace('T', ' '),
                                            color = DetailSub, fontSize = 11.sp)
                                    }
                                }
                            }
                            Text(stringResource(R.string.food_order_detail_readonly), color = DetailSub,
                                fontSize = 12.sp)
                        }
                        HorizontalDivider()
                        OutlinedButton(
                            onClick = { onRefresh(orderId) },
                            modifier = Modifier.fillMaxWidth().padding(16.dp),
                        ) { Text(stringResource(R.string.refresh_orders)) }
                    }
                }
            }
        }
    }
}

@Composable
private fun InfoSection(content: @Composable () -> Unit) {
    Column(
        Modifier.fillMaxWidth().background(DetailGrey, RoundedCornerShape(16.dp)).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(7.dp),
    ) { content() }
}

@Composable
private fun MoneyDetailRow(label: String, value: String, strong: Boolean = false) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = if (strong) DetailInk else DetailSub,
            fontWeight = if (strong) FontWeight.Bold else FontWeight.Normal)
        Text("฿" + value, color = DetailInk,
            fontWeight = if (strong) FontWeight.Bold else FontWeight.Medium)
    }
}
