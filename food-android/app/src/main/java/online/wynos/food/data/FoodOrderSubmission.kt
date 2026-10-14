package online.wynos.food.data

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.util.UUID

/**
 * Contract for public.food_create_order, verified against the current SQL signature.
 *
 * This is deliberately NOT a payment request, and the legacy RPC is NOT idempotent.
 * Never expose it for production mobile checkout. A separate mobile checkout API must
 * atomically bind a client attempt ID to one order and reconcile payment/webhook state.
 */
object FoodOrderSubmission {
    fun request(cart: FoodCartDraft, address: FoodCustomerAddress, customerNote: String = ""): JsonObject {
        require(address.validPin) { "valid_delivery_pin_required" }
        require(address.recipientName.trim().length in 1..120) { "invalid_recipient_name" }
        require(address.recipientPhone.trim().length in 1..50) { "invalid_recipient_phone" }
        require(address.address.trim().length in 1..800) { "invalid_shipping_address" }
        require(customerNote.length <= 800) { "invalid_customer_note" }
        require(cart.lines.isNotEmpty() && cart.lines.size <= 50) { "invalid_items" }
        UUID.fromString(cart.storeId ?: throw IllegalArgumentException("missing_store_id"))
        cart.lines.forEach {
            UUID.fromString(it.menuId)
            require(it.quantity in 1..99 && it.note.length <= 250) { "invalid_cart_line" }
        }

        val quoteParams = FoodQuoteRequest.fromCart(cart, address)
        val items = quoteParams["p_items"] as JsonArray
        val withNotes = buildJsonArray {
            items.forEachIndexed { index, item ->
                val original = item as JsonObject
                add(buildJsonObject {
                    original.forEach { (key, value) -> put(key, value) }
                    put("note", cart.lines[index].note)
                })
            }
        }
        return buildJsonObject {
            quoteParams.forEach { (key, value) -> put(key, value) }
            put("p_items", withNotes)
            put("p_recipient_name", address.recipientName.trim())
            put("p_recipient_phone", address.recipientPhone.trim())
            put("p_shipping_address", address.address.trim())
            put("p_customer_note", customerNote.trim())
        }
    }
}
