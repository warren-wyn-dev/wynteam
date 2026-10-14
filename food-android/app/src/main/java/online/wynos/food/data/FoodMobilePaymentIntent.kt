package online.wynos.food.data

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.util.UUID

/**
 * Ephemeral Stripe PaymentSheet response. A client secret is usable only for
 * its specific PaymentIntent and must NEVER be logged or saved in SavedState.
 * PaymentSheet completion isn't proof of payment: use verified server status.
 */
class FoodMobilePaymentIntent(
    val orderId: String,
    val paymentIntentId: String,
    val clientSecret: String,
    val publishableKey: String,
    val connectedAccountId: String,
) {
    override fun toString(): String = "FoodMobilePaymentIntent(redacted)"
}

object FoodMobilePaymentIntentParser {
    fun parse(raw: String, expectedOrderId: String): FoodMobilePaymentIntent {
        val payload = Json.parseToJsonElement(raw) as? JsonObject
            ?: throw IllegalArgumentException("invalid_mobile_payment_response")
        fun value(name: String): String =
            (payload[name] as? JsonPrimitive)?.content
                ?: throw IllegalArgumentException("invalid_mobile_payment_response")
        val order = value("orderId")
        require(order == expectedOrderId && runCatching { UUID.fromString(order) }.isSuccess) {
            "mobile_payment_order_mismatch"
        }
        val intentId = value("paymentIntentId")
        val clientSecret = value("clientSecret")
        val publishable = value("publishableKey")
        val connected = value("connectedAccountId")
        require(intentId.startsWith("pi_") &&
            clientSecret.startsWith(intentId + "_secret_") &&
            publishable.startsWith("pk_test_") &&
            connected.matches(Regex("acct_[a-zA-Z0-9]+"))
        ) { "mobile_payment_invalid_stripe_credentials" }
        return FoodMobilePaymentIntent(order, intentId, clientSecret, publishable, connected)
    }
}
