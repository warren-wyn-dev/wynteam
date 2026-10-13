package online.wynos.food.data

/** Explicit UI-only guard. Never authorizes creating an order or starting a payment. */
object FoodCheckoutReviewGuard {
    fun canReview(
        cart: FoodCartDraft,
        quote: FoodServerQuote?,
        address: FoodCustomerAddress?,
        quoteLoading: Boolean,
        addressesLoading: Boolean,
    ): Boolean = cart.lines.isNotEmpty() && !cart.storeId.isNullOrBlank() &&
        quote != null && !quote.needsLocation && address?.validPin == true &&
        !quoteLoading && !addressesLoading
}
