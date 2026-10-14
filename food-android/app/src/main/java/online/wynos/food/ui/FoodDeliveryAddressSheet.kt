package online.wynos.food.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import online.wynos.food.R
import online.wynos.food.data.FoodDeliverySelection

private val SheetRed = Color(0xFFE40036)
private val SheetText = Color(0xFF16161A)
private val SheetSub = Color(0xFF6B6B76)
private val SheetLine = Color(0xFFEBEBEF)
private val SheetSelected = Color(0xFFFCEDF0)

/** Native Android bottom sheet, mirroring the website delivery-address choice.
 * Choosing a saved address updates the current order destination and invalidates
 * any server quote. It does not change the backend's persisted default address.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FoodDeliveryAddressSheet(
    state: FoodUiState,
    onSelectAddress: (String?) -> Unit,
    onManageAddresses: () -> Unit,
    onDismiss: () -> Unit,
) {
    val selected = FoodDeliverySelection.current(state.addresses, state.selectedAddressId)?.id
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = Color.White,
    ) {
        Column(
            Modifier.fillMaxWidth().heightIn(max = 540.dp)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                stringResource(R.string.delivery_location_title),
                color = SheetText, fontSize = 21.sp, fontWeight = FontWeight.Bold,
            )
            Text(
                stringResource(R.string.delivery_location_note),
                color = SheetSub, fontSize = 13.sp,
            )
            when {
                state.addressesLoading && state.addresses.isEmpty() ->
                    Text(stringResource(R.string.loading_addresses), color = SheetSub)
                state.addressesFailed ->
                    Text(stringResource(R.string.addresses_load_error), color = SheetRed)
                state.addresses.isEmpty() ->
                    Text(stringResource(R.string.no_saved_addresses), color = SheetSub)
                else -> state.addresses.forEach { address ->
                    val isSelected = selected == address.id
                    Column(
                        Modifier.fillMaxWidth()
                            .background(
                                if (isSelected) SheetSelected else Color(0xFFF6F6F8),
                                RoundedCornerShape(14.dp),
                            )
                            .clickable {
                                onSelectAddress(address.id)
                                onDismiss()
                            }
                            .padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Row(
                            Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            RadioButton(
                                selected = isSelected,
                                onClick = {
                                    onSelectAddress(address.id)
                                    onDismiss()
                                },
                                colors = RadioButtonDefaults.colors(selectedColor = SheetRed),
                            )
                            Column(Modifier.weight(1f)) {
                                Text(address.label, color = SheetText,
                                    fontWeight = FontWeight.Bold, fontSize = 15.sp,
                                    maxLines = 1, overflow = TextOverflow.Ellipsis)
                                Text(
                                    address.recipientName + " · " + address.recipientPhone,
                                    color = SheetSub, fontSize = 12.sp,
                                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                                )
                            }
                        }
                        Text(address.address, color = SheetSub, fontSize = 12.sp,
                            maxLines = 3, overflow = TextOverflow.Ellipsis)
                        if (!address.validPin) {
                            Text(stringResource(R.string.address_missing_pin),
                                color = SheetRed, fontSize = 12.sp)
                        }
                    }
                }
            }
            HorizontalDivider(color = SheetLine)
            TextButton(
                onClick = {
                    onDismiss()
                    onManageAddresses()
                },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(stringResource(R.string.delivery_location_manage), color = SheetRed,
                    fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
