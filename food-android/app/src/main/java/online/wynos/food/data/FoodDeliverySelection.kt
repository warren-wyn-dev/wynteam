package online.wynos.food.data

/**
 * Shared Android choice of where Food would be delivered. This is a local,
 * authenticated address selection, not a backend default-address mutation.
 * The quote/order RPC must still validate the chosen address and delivery pin.
 */
object FoodDeliverySelection {
    fun current(
        addresses: List<FoodCustomerAddress>,
        selectedAddressId: String?,
    ): FoodCustomerAddress? =
        addresses.firstOrNull { it.id == selectedAddressId }
            ?: addresses.firstOrNull { it.isDefault }
            ?: addresses.firstOrNull()

    fun label(
        addresses: List<FoodCustomerAddress>,
        selectedAddressId: String?,
    ): String? =
        current(addresses, selectedAddressId)?.let { address ->
            address.label.trim().takeIf { it.isNotBlank() }
                ?: address.address.trim().takeIf { it.isNotBlank() }
        }
}
