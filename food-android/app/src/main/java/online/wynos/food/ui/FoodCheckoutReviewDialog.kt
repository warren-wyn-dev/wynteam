package online.wynos.food.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import online.wynos.food.R
import online.wynos.food.data.FoodCartDraft
import online.wynos.food.data.FoodCustomerAddress
import online.wynos.food.data.FoodServerQuote

private val CheckoutInk = Color(0xFF16161A)
private val CheckoutSub = Color(0xFF6B6B76)
private val CheckoutRed = Color(0xFFE40036)

/**
 * Native checkout review, using ONLY server quoted amounts.
 * Production order creation and Stripe remain disabled until a mobile-authenticated
 * idempotent payment contract passes staging E2E. A disposable staging debug build
 * may submit ONE legacy RPC order without charging a card.
 */
@Composable
fun FoodCheckoutReviewDialog(
    cart: FoodCartDraft,
    address: FoodCustomerAddress,
    quote: FoodServerQuote,
    onDismiss: () -> Unit,
    stagingOrderEnabled: Boolean = false,
    stagingOrderBusy: Boolean = false,
    stagingOrderUncertain: Boolean = false,
    stagingOrderCreatedId: String? = null,
    stagingOrderAttemptId: String? = null,
    stagingMobilePaymentEnabled: Boolean = false,
    onPrepareStagingPayment: suspend (String) -> online.wynos.food.data.FoodMobilePaymentIntent = {
        throw IllegalStateException("staging_mobile_payment_disabled")
    },
    onPaymentSheetCompleted: () -> Unit = {},
    onCreateOrder: (String) -> Unit = {},
) {
    var showStagingConfirm by remember { mutableStateOf(false) }
    var customerNote by rememberSaveable { mutableStateOf("") }
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Surface(color = Color.White, modifier = Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize()) {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(stringResource(R.string.checkout_review_title), color = CheckoutInk,
                        fontWeight = FontWeight.Bold, fontSize = 22.sp)
                    TextButton(onClick = onDismiss) {
                        Text(stringResource(R.string.address_cancel), color = CheckoutSub)
                    }
                }
                HorizontalDivider()
                Column(
                    Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    Column(Modifier.fillMaxWidth().background(Color(0xFFF6F6F8),
                        RoundedCornerShape(16.dp)).padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Text(stringResource(R.string.checkout_review_address), color = CheckoutInk,
                            fontWeight = FontWeight.Bold)
                        Text(address.label + " · " + address.recipientName, color = CheckoutInk)
                        Text(address.recipientPhone, color = CheckoutSub, fontSize = 13.sp)
                        Text(address.address, color = CheckoutSub, fontSize = 13.sp)
                        address.deliveryNote?.takeIf { it.isNotBlank() }?.let {
                            Text(it, color = CheckoutSub, fontSize = 12.sp)
                        }
                    }
                    Text(stringResource(R.string.checkout_review_items), color = CheckoutInk,
                        fontWeight = FontWeight.Bold)
                    cart.lines.forEach { item ->
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(item.name + " × " + item.quantity, color = CheckoutInk)
                                if (item.options.isNotEmpty())
                                    Text(item.options.joinToString(" · ") { it.name },
                                        color = CheckoutSub, fontSize = 12.sp)
                                if (item.note.isNotBlank()) Text(
                                    stringResource(R.string.menu_note_title) + ": " + item.note,
                                    color = CheckoutSub, fontSize = 12.sp)
                            }
                        }
                    }
                    HorizontalDivider()
                    Text(stringResource(R.string.server_quote_label),
                        color = CheckoutInk, fontWeight = FontWeight.Bold)
                    ReviewRow(stringResource(R.string.estimated_subtotal_label), quote.subtotal.toPlainString())
                    ReviewRow(stringResource(R.string.server_delivery_fee), quote.deliveryFee.toPlainString())
                    ReviewRow(stringResource(R.string.server_campaign_discount), "-" + quote.campaignDiscount.toPlainString())
                    ReviewRow(stringResource(R.string.server_delivery_discount), "-" + quote.deliveryDiscount.toPlainString())
                    HorizontalDivider()
                    ReviewRow(stringResource(R.string.server_quote_total), quote.total.toPlainString(), highlight = true)
                    Text(stringResource(R.string.checkout_review_not_final), color = CheckoutSub, fontSize = 12.sp)
                }
                HorizontalDivider()
                Column(
                    Modifier.fillMaxWidth().navigationBarsPadding().imePadding()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    if (stagingOrderEnabled) {
                        OutlinedTextField(
                            value = customerNote,
                            onValueChange = { customerNote = it.take(800) },
                            label = { Text(stringResource(R.string.staging_order_customer_note)) },
                            modifier = Modifier.fillMaxWidth(),
                            maxLines = 2,
                            enabled = !stagingOrderBusy && stagingOrderCreatedId == null,
                        )
                    }
                    Button(
                        onClick = { showStagingConfirm = true },
                        enabled = stagingOrderEnabled && !stagingOrderBusy &&
                            !stagingOrderUncertain && stagingOrderCreatedId == null,
                        modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = CheckoutRed),
                    ) {
                        Text(
                            stringResource(
                                if (stagingOrderEnabled) R.string.staging_order_create_action
                                else R.string.checkout_locked_short
                            ),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                    if (stagingMobilePaymentEnabled && stagingOrderEnabled &&
                        stagingOrderCreatedId != null && !stagingOrderBusy && !stagingOrderUncertain
                    ) {
                        FoodStagingPaymentSheet(
                            orderId = stagingOrderCreatedId,
                            onPrepare = onPrepareStagingPayment,
                            onPaymentSheetCompleted = onPaymentSheetCompleted,
                        )
                    }
                    when {
                        stagingOrderBusy ->
                            Text(stringResource(R.string.staging_order_in_progress),
                                color = CheckoutSub, fontSize = 12.sp)
                        stagingOrderCreatedId != null ->
                            Text(stringResource(R.string.staging_order_created, stagingOrderCreatedId),
                                color = CheckoutInk, fontSize = 12.sp)
                        stagingOrderUncertain -> {
                            Text(stringResource(R.string.staging_order_uncertain),
                                color = CheckoutRed, fontSize = 12.sp)
                            stagingOrderAttemptId?.let { attempt ->
                                Text(stringResource(R.string.staging_order_attempt_reference, attempt),
                                    color = CheckoutInk, fontSize = 12.sp)
                            }
                        }
                        else ->
                            Text(stringResource(
                                if (stagingOrderEnabled) R.string.staging_order_notice
                                else R.string.checkout_review_staging_notice
                            ), color = CheckoutSub, fontSize = 12.sp)
                    }
                }
            }
        }
    }
    if (showStagingConfirm && stagingOrderEnabled && !stagingOrderBusy &&
        !stagingOrderUncertain && stagingOrderCreatedId == null
    ) {
        AlertDialog(
            onDismissRequest = { showStagingConfirm = false },
            title = { Text(stringResource(R.string.staging_order_confirm_title)) },
            text = { Text(stringResource(R.string.staging_order_confirm_text)) },
            confirmButton = {
                TextButton(onClick = {
                    showStagingConfirm = false
                    onCreateOrder(customerNote)
                }) { Text(stringResource(R.string.staging_order_create_action)) }
            },
            dismissButton = {
                TextButton(onClick = { showStagingConfirm = false }) {
                    Text(stringResource(R.string.address_cancel))
                }
            },
        )
    }
}

@Composable
private fun ReviewRow(label: String, amount: String, highlight: Boolean = false) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = if (highlight) CheckoutInk else CheckoutSub,
            fontWeight = if (highlight) FontWeight.Bold else FontWeight.Normal)
        Text("฿" + amount, color = CheckoutInk,
            fontWeight = if (highlight) FontWeight.Bold else FontWeight.Medium)
    }
}
