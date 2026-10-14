package online.wynos.food.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.stripe.android.PaymentConfiguration
import com.stripe.android.paymentsheet.PaymentSheet
import com.stripe.android.paymentsheet.PaymentSheetResult
import kotlinx.coroutines.launch
import online.wynos.food.R
import online.wynos.food.data.FoodMobilePaymentIntent

/**
 * Stripe PaymentSheet is a NATIVE Android payment UI, not a WebView.
 * Test payments only; the server fails closed on Production and live keys.
 * Backend-confirmed orderHistory payment_status is the source of truth.
 */
@Composable
fun FoodStagingPaymentSheet(
    orderId: String,
    onPrepare: suspend (String) -> FoodMobilePaymentIntent,
    onPaymentSheetCompleted: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var preparing by remember(orderId) { mutableStateOf(false) }
    var resultMessage by remember(orderId) { mutableIntStateOf(R.string.staging_payment_not_paid) }

    val sheet = PaymentSheet.Builder { result ->
        when (result) {
            is PaymentSheetResult.Completed -> {
                // PaymentSheet callback is NOT a substitute for a signed
                // Stripe webhook and server-side payment verification.
                resultMessage = R.string.staging_payment_checking
                onPaymentSheetCompleted()
            }
            is PaymentSheetResult.Canceled ->
                resultMessage = R.string.staging_payment_cancelled
            is PaymentSheetResult.Failed ->
                resultMessage = R.string.staging_payment_failed
        }
    }.build()

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Button(
            modifier = Modifier.fillMaxWidth(),
            enabled = !preparing,
            onClick = {
                if (preparing) return@Button
                preparing = true
                scope.launch {
                    try {
                        val intent = onPrepare(orderId)
                        check(intent.orderId == orderId && intent.publishableKey.startsWith("pk_test_"))
                        PaymentConfiguration.init(
                            context, intent.publishableKey, intent.connectedAccountId,
                        )
                        resultMessage = R.string.staging_payment_not_paid
                        sheet.presentWithPaymentIntent(
                            intent.clientSecret,
                            PaymentSheet.Configuration(merchantDisplayName = "WYNOS Food Test"),
                        )
                    } catch (_: Exception) {
                        resultMessage = R.string.staging_payment_unavailable
                    } finally {
                        preparing = false
                    }
                }
            },
        ) {
            if (preparing) CircularProgressIndicator()
            else Text(stringResource(R.string.staging_payment_action))
        }
        Text(stringResource(resultMessage))
    }
}
