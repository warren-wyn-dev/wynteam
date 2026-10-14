package online.wynos.food.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodMobilePaymentIntentParserTest {
    private val orderId = "11111111-1111-4111-8111-111111111111"
    private val response = """
      {
        "orderId":"$orderId",
        "paymentIntentId":"pi_test123",
        "clientSecret":"pi_test123_secret_hidden",
        "publishableKey":"pk_test_public",
        "connectedAccountId":"acct_test123"
      }
    """.trimIndent()

    @Test fun onlyAcceptsTestModeAndExpectedOrder() {
        val parsed = FoodMobilePaymentIntentParser.parse(response, orderId)
        assertEquals(orderId, parsed.orderId)
        assertEquals("acct_test123", parsed.connectedAccountId)
        assertEquals("pk_test_public", parsed.publishableKey)
        assertEquals("pi_test123_secret_hidden", parsed.clientSecret)
        assertFalse(parsed.toString().contains("hidden"))
    }

    @Test fun crossOrderCredentialsAreNeverAccepted() {
        val other = "22222222-2222-4222-8222-222222222222"
        try {
            FoodMobilePaymentIntentParser.parse(response, other)
            throw AssertionError("expected wrong order failure")
        } catch (_: IllegalArgumentException) { }
    }

    @Test fun rejectsLiveKeysOrMismatchedStripeSecrets() {
        for (bad in listOf(
            response.replace("pk_test_public", "pk_live_public"),
            response.replace("pi_test123_secret_hidden", "pi_attacker_secret_hidden"),
            response.replace("acct_test123", "not_account"),
            "{}",
        )) {
            try {
                FoodMobilePaymentIntentParser.parse(bad, orderId)
                throw AssertionError("expected invalid payment credentials")
            } catch (_: IllegalArgumentException) { }
        }
    }
}
