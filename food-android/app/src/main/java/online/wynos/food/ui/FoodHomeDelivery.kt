package online.wynos.food.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.KeyboardArrowDown
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import online.wynos.food.R
import online.wynos.food.data.FoodCustomerAddress

private val DeliveryRed = Color(0xFFE40036)
private val DeliveryInk = Color(0xFF16161A)
private val DeliverySecondary = Color(0xFF6B6B76)

/**
 * Selection is derived solely from the authenticated address list and the
 * selected ID owned by FoodViewModel. Never fabricate a location or silently
 * display another address when the selected ID is missing.
 */
internal fun resolvedHomeDeliveryAddress(
    addresses: List<FoodCustomerAddress>,
    selectedAddressId: String?,
): FoodCustomerAddress? = addresses.firstOrNull { it.id == selectedAddressId }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FoodHomeDelivery(
    state: FoodUiState,
    onSelectAddress: (String?) -> Unit,
    onRefreshAddresses: () -> Unit,
    onManageAddresses: () -> Unit,
) {
    var pickerOpen by remember(state.accountEmail) { mutableStateOf(false) }
    val address = resolvedHomeDeliveryAddress(state.addresses, state.selectedAddressId)

    Row(
        modifier = Modifier.fillMaxWidth()
            .clickable { pickerOpen = true }
            .padding(top = 5.dp, bottom = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            Icons.Outlined.LocationOn,
            contentDescription = null,
            tint = DeliveryRed,
            modifier = Modifier.size(20.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(stringResource(R.string.delivery_to), fontSize = 12.sp, color = DeliverySecondary)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = when {
                        address != null -> address.placeName.ifBlank {
                            address.label.ifBlank { address.address }
                        }
                        state.addressesLoading -> stringResource(R.string.loading_addresses)
                        state.addressesFailed -> stringResource(R.string.addresses_load_error)
                        else -> stringResource(R.string.select_delivery)
                    },
                    fontSize = 15.sp,
                    color = DeliveryInk,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                Icon(
                    Icons.Outlined.KeyboardArrowDown,
                    contentDescription = null,
                    tint = DeliverySecondary,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
    }

    if (pickerOpen) {
        ModalBottomSheet(onDismissRequest = { pickerOpen = false }) {
            Column(
                Modifier.fillMaxWidth()
                    .heightIn(max = 540.dp)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    stringResource(R.string.delivery_addresses),
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = DeliveryInk,
                )
                if (state.addressesLoading) {
                    CircularProgressIndicator(color = DeliveryRed, modifier = Modifier.size(24.dp))
                }
                if (state.addressesFailed) {
                    Text(stringResource(R.string.addresses_load_error), color = DeliveryRed)
                } else if (!state.addressesLoading && state.addresses.isEmpty()) {
                    Text(stringResource(R.string.no_saved_addresses), color = DeliverySecondary)
                }

                if (!state.addressesFailed) {
                    state.addresses.forEach { entry ->
                        Row(
                            modifier = Modifier.fillMaxWidth()
                                .clickable {
                                    onSelectAddress(entry.id)
                                    pickerOpen = false
                                }
                                .padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            RadioButton(
                                selected = entry.id == state.selectedAddressId,
                                onClick = {
                                    onSelectAddress(entry.id)
                                    pickerOpen = false
                                },
                            )
                            Column(Modifier.weight(1f)) {
                                Text(
                                    entry.label.ifBlank { entry.address },
                                    fontWeight = FontWeight.SemiBold,
                                    color = DeliveryInk,
                                )
                                Text(entry.address, color = DeliverySecondary, fontSize = 13.sp)
                                if (entry.isDefault) {
                                    Text(
                                        stringResource(R.string.address_default),
                                        color = DeliveryRed,
                                        fontSize = 12.sp,
                                    )
                                }
                                if (!entry.validPin) {
                                    Text(
                                        stringResource(R.string.address_missing_pin),
                                        color = DeliveryRed,
                                        fontSize = 12.sp,
                                    )
                                }
                            }
                        }
                        HorizontalDivider()
                    }
                }

                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    TextButton(onClick = onRefreshAddresses, enabled = !state.addressesLoading) {
                        Text(stringResource(R.string.refresh_addresses), color = DeliveryRed)
                    }
                    TextButton(onClick = {
                        pickerOpen = false
                        onManageAddresses()
                    }) {
                        Text(stringResource(R.string.manage_delivery_addresses), color = DeliveryRed)
                    }
                }
            }
        }
    }
}
