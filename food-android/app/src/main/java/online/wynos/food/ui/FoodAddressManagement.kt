package online.wynos.food.ui

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat
import online.wynos.food.R
import online.wynos.food.data.FoodAddressDraft
import online.wynos.food.data.FoodCustomerAddress
import java.util.Locale

private val AddressRed = Color(0xFFE40036)
private val AddressInk = Color(0xFF16161A)
private val AddressSub = Color(0xFF6B6B76)
private val AddressBg = Color(0xFFF6F6F8)

/** Native, authenticated owner-address management. Writes are disabled outside staging. */
@Composable
fun FoodAddressManagement(
    state: FoodUiState,
    onRefresh: () -> Unit,
    onSave: (FoodAddressDraft) -> Unit,
    onDelete: (String) -> Unit,
    onClearStatus: () -> Unit,
) {
    var editing by remember { mutableStateOf<FoodCustomerAddress?>(null) }
    var showEditor by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf<FoodCustomerAddress?>(null) }

    LaunchedEffect(state.addressMutationSuccess) {
        if (state.addressMutationSuccess) {
            showEditor = false
            deleting = null
        }
    }

    Column(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween) {
            Text(stringResource(R.string.delivery_addresses),
                color = AddressInk, fontWeight = FontWeight.Bold, fontSize = 18.sp)
            if (state.addressWritesEnabled) {
                TextButton(onClick = {
                    onClearStatus()
                    editing = null
                    showEditor = true
                }) {
                    Icon(Icons.Outlined.Add, null)
                    Text(stringResource(R.string.address_add))
                }
            }
        }
        when {
            state.addressesLoading && state.addresses.isEmpty() ->
                CircularProgressIndicator(color = AddressRed)
            state.addressesFailed -> Text(stringResource(R.string.addresses_load_error), color = AddressRed)
            state.addresses.isEmpty() -> Text(stringResource(R.string.no_saved_addresses), color = AddressSub)
            else -> state.addresses.forEach { address ->
                Surface(color = AddressBg, shape = RoundedCornerShape(16.dp)) {
                    Column(Modifier.fillMaxWidth().padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically) {
                            Text(address.label + if (address.isDefault) " ★" else "",
                                color = AddressInk, fontWeight = FontWeight.Bold)
                            if (state.addressWritesEnabled) {
                                Row {
                                    TextButton(onClick = {
                                        onClearStatus()
                                        editing = address
                                        showEditor = true
                                    }) {
                                        Icon(Icons.Outlined.Edit, null, Modifier.size(17.dp))
                                        Text(stringResource(R.string.address_edit))
                                    }
                                    TextButton(onClick = {
                                        onClearStatus()
                                        deleting = address
                                    }) {
                                        Icon(Icons.Outlined.DeleteOutline, null, Modifier.size(17.dp))
                                        Text(stringResource(R.string.address_delete), color = AddressRed)
                                    }
                                }
                            }
                        }
                        Text(address.recipientName + " · " + address.recipientPhone,
                            fontSize = 13.sp, color = AddressInk)
                        Text(address.address, fontSize = 13.sp, color = AddressSub)
                        if (!address.validPin) {
                            Text(stringResource(R.string.address_missing_pin),
                                fontSize = 12.sp, color = AddressRed)
                        }
                    }
                }
            }
        }
        if (!state.addressWritesEnabled) {
            Text(stringResource(R.string.address_writes_staging_only),
                fontSize = 12.sp, color = AddressSub)
        }
        if (state.addressMutationError) {
            Text(stringResource(R.string.address_write_failed), color = AddressRed, fontSize = 13.sp)
        }
        TextButton(onClick = onRefresh, enabled = !state.addressBusy) {
            Text(stringResource(R.string.refresh_addresses), color = AddressRed)
        }
    }

    if (showEditor && state.addressWritesEnabled) {
        FoodAddressEditor(
            original = editing,
            saving = state.addressBusy,
            failed = state.addressMutationError,
            onSave = onSave,
            onDismiss = { if (!state.addressBusy) showEditor = false },
        )
    }

    deleting?.let { target ->
        AlertDialog(
            onDismissRequest = { if (!state.addressBusy) deleting = null },
            title = { Text(stringResource(R.string.address_delete_confirm_title)) },
            text = { Text(stringResource(R.string.address_delete_confirm_body, target.label)) },
            confirmButton = {
                TextButton(
                    enabled = !state.addressBusy,
                    onClick = { onDelete(target.id) },
                ) { Text(stringResource(R.string.address_delete), color = AddressRed) }
            },
            dismissButton = {
                TextButton(onClick = { deleting = null }, enabled = !state.addressBusy) {
                    Text(stringResource(R.string.address_cancel))
                }
            },
        )
    }
}

@Composable
private fun FoodAddressEditor(
    original: FoodCustomerAddress?,
    saving: Boolean,
    failed: Boolean,
    onSave: (FoodAddressDraft) -> Unit,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    var draft by remember(original?.id) {
        mutableStateOf(original?.let(FoodAddressDraft::fromAddress) ?: FoodAddressDraft())
    }
    var locationError by remember { mutableStateOf(false) }
    val manager = remember(context) {
        context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    }

    fun useLocation() {
        val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        if (!fine && !coarse) {
            locationError = true
            return
        }
        val provider = if (fine && manager.isProviderEnabled(LocationManager.GPS_PROVIDER))
            LocationManager.GPS_PROVIDER
        else if (manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER))
            LocationManager.NETWORK_PROVIDER
        else null
        if (provider == null) {
            locationError = true
            return
        }
        try {
            locationError = false
            LocationManagerCompat.getCurrentLocation(
                manager, provider, null, ContextCompat.getMainExecutor(context)
            ) { location ->
                if (location != null) {
                    draft = draft.copy(latitude = location.latitude, longitude = location.longitude)
                    locationError = false
                } else {
                    locationError = true
                }
            }
        } catch (_: SecurityException) {
            locationError = true
        } catch (_: IllegalArgumentException) {
            locationError = true
        }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { granted ->
        if (granted.values.any { it }) useLocation() else locationError = true
    }
    val fields: @Composable () -> Unit = {
        @Composable fun field(label: String, value: String, changed: (String) -> Unit, numeric: Boolean = false) {
            OutlinedTextField(
                value = value, onValueChange = changed,
                label = { Text(label) }, modifier = Modifier.fillMaxWidth(),
                singleLine = true, shape = RoundedCornerShape(12.dp),
                keyboardOptions = KeyboardOptions(
                    keyboardType = if (numeric) KeyboardType.Number else KeyboardType.Text,
                ),
            )
        }
        field(stringResource(R.string.address_label), draft.label) { draft = draft.copy(label = it) }
        field(stringResource(R.string.address_recipient), draft.recipientName) { draft = draft.copy(recipientName = it) }
        field(stringResource(R.string.address_phone), draft.recipientPhone) { draft = draft.copy(recipientPhone = it) }
        field(stringResource(R.string.address_line1), draft.addressLine1) { draft = draft.copy(addressLine1 = it) }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.weight(1f)) {
                field(stringResource(R.string.address_moo), draft.moo) { draft = draft.copy(moo = it) }
            }
            Box(Modifier.weight(1f)) {
                field(stringResource(R.string.address_soi), draft.soi) { draft = draft.copy(soi = it) }
            }
        }
        field(stringResource(R.string.address_road), draft.road) { draft = draft.copy(road = it) }
        field(stringResource(R.string.address_subdistrict), draft.subdistrict) { draft = draft.copy(subdistrict = it) }
        field(stringResource(R.string.address_district), draft.district) { draft = draft.copy(district = it) }
        field(stringResource(R.string.address_province), draft.province) { draft = draft.copy(province = it) }
        field(stringResource(R.string.address_postal), draft.postalCode, { draft = draft.copy(postalCode = it) }, numeric = true)
        field(stringResource(R.string.address_building), draft.buildingName) { draft = draft.copy(buildingName = it) }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.weight(1f)) {
                field(stringResource(R.string.address_floor), draft.floor) { draft = draft.copy(floor = it) }
            }
            Box(Modifier.weight(1f)) {
                field(stringResource(R.string.address_room), draft.room) { draft = draft.copy(room = it) }
            }
        }
        field(stringResource(R.string.address_landmark), draft.landmark) { draft = draft.copy(landmark = it) }
        field(stringResource(R.string.address_note), draft.deliveryNote) { draft = draft.copy(deliveryNote = it) }
        HorizontalDivider()
        Text(stringResource(R.string.address_pin_title),
            color = AddressInk, fontWeight = FontWeight.Bold)
        Text(stringResource(R.string.address_pin_help), color = AddressSub, fontSize = 12.sp)
        OutlinedButton(
            enabled = !saving,
            onClick = {
                val permissionGranted = listOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ).any { permission ->
                    ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
                }
                if (permissionGranted) useLocation()
                else permissionLauncher.launch(arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ))
            },
        ) {
            Icon(Icons.Outlined.LocationOn, null)
            Text(stringResource(R.string.address_use_location))
        }
        if (draft.validPin) {
            Text(String.format(Locale.US, "%.6f, %.6f", draft.latitude, draft.longitude),
                color = AddressSub, fontSize = 12.sp)
        } else Text(stringResource(R.string.address_missing_pin), color = AddressRed, fontSize = 12.sp)
        if (locationError) Text(stringResource(R.string.address_location_failed),
            color = AddressRed, fontSize = 12.sp)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Checkbox(checked = draft.isDefault, onCheckedChange = { draft = draft.copy(isDefault = it) })
            Text(stringResource(R.string.address_default))
        }
        if (failed) Text(stringResource(R.string.address_write_failed), color = AddressRed)
        Spacer(Modifier.height(8.dp))
    }
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Surface(color = Color.White, modifier = Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize()) {
                Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        stringResource(if (original == null) R.string.address_add else R.string.address_edit),
                        fontSize = 22.sp, fontWeight = FontWeight.Bold, color = AddressInk,
                    )
                    TextButton(onClick = onDismiss, enabled = !saving) {
                        Text(stringResource(R.string.address_cancel), color = AddressSub)
                    }
                }
                HorizontalDivider()
                Column(
                    Modifier.weight(1f).verticalScroll(rememberScrollState())
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(9.dp),
                ) { fields() }
                HorizontalDivider()
                Button(
                    onClick = { onSave(draft) },
                    enabled = draft.validate() && !saving,
                    colors = ButtonDefaults.buttonColors(containerColor = AddressRed),
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    shape = RoundedCornerShape(16.dp),
                ) {
                    if (saving) CircularProgressIndicator(Modifier.size(18.dp), color = Color.White,
                        strokeWidth = 2.dp)
                    else Text(stringResource(R.string.address_save))
                }
            }
        }
    }
}
