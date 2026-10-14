package online.wynos.food.data

/**
 * Mirrors web FoodCustomerInner.homeLocationLabel, with no network/API write.
 * The default address is preferred; place_name wins over the short label.
 * Selecting or editing an address still happens on the native Account page.
 */
object FoodHomeDeliveryLabel {
    fun fromAddresses(addresses: List<FoodCustomerAddress>): String? {
        val primary = addresses.find { it.isDefault } ?: addresses.firstOrNull() ?: return null
        return primary.placeName.trim().takeIf(String::isNotEmpty)
            ?: primary.label.trim().takeIf(String::isNotEmpty)
    }
}
