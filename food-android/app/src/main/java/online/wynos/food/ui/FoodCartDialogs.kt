package online.wynos.food.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Restaurant
import androidx.compose.material.icons.outlined.ShoppingBag
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil.compose.AsyncImage
import online.wynos.food.R
import online.wynos.food.data.FoodCartDraft
import online.wynos.food.data.FoodMenu
import online.wynos.food.data.FoodPublicMedia
import java.math.BigDecimal

private val Red = Color(0xFFE40036)
private val RedSoft = Color(0xFFFCEDF0)
private val Ink = Color(0xFF16161A)
private val Sub = Color(0xFF6B6B76)
private val SurfaceGrey = Color(0xFFF6F6F8)
private val Line = Color(0xFFEBEBEF)

/**
 * Web's guest item panel is a whole-screen page, not a small alert dialog.
 * Preserve a real native screen with vertical radio options for spicy level.
 * This remains a LOCAL CART only; no server order or payment is created.
 */
@Composable
fun FoodMenuOptionsDialog(
    menu: FoodMenu,
    onDismiss: () -> Unit,
    onAdd: (Map<String, Set<String>>, Int, String) -> Unit,
) {
    var selection by remember(menu.id) { mutableStateOf<Map<String, Set<String>>>(emptyMap()) }
    var quantity by remember(menu.id) { mutableIntStateOf(1) }
    var note by rememberSaveable(menu.id) { mutableStateOf("") }
    val valid = menu.optionGroups.all { !it.required || selection[it.id].orEmpty().isNotEmpty() }
    val extra = menu.optionGroups.fold(BigDecimal.ZERO) { sum, group ->
        sum + group.choices.filter { it.id in selection[group.id].orEmpty() }
            .fold(BigDecimal.ZERO) { total, choice -> total + (choice.price.toBigDecimalOrNull() ?: BigDecimal.ZERO) }
    }
    val unit = (menu.price.toBigDecimalOrNull() ?: BigDecimal.ZERO) + extra
    val estimate = unit * quantity.toBigDecimal()

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Surface(color = Color.White, modifier = Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize()) {
                Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
                    BoxWithConstraints(Modifier.fillMaxWidth()) {
                        val photoHeight = (maxWidth * 0.64f).coerceAtMost(300.dp)
                        Box(Modifier.fillMaxWidth().height(photoHeight).background(SurfaceGrey)) {
                            val url = FoodPublicMedia.url("food-public", menu.imagePath)
                            if (url == null) {
                                Icon(Icons.Outlined.Restaurant, contentDescription = null,
                                    modifier = Modifier.align(Alignment.Center).size(44.dp), tint = Sub)
                            } else {
                                AsyncImage(model = url, contentDescription = null,
                                    contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                            }
                            Surface(
                                shape = CircleShape, color = Color.White,
                                modifier = Modifier.align(Alignment.TopStart).padding(14.dp)
                                    .size(42.dp).clickable(onClick = onDismiss),
                                shadowElevation = 3.dp,
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Icon(Icons.Outlined.Close, stringResource(R.string.close), tint = Ink)
                                }
                            }
                        }
                    }
                    Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 18.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(menu.name, color = Ink, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                        menu.description?.let { Text(it, fontSize = 14.sp, color = Sub) }
                        Text("฿" + unit.stripTrailingZeros().toPlainString(), color = Ink, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                    }
                    Box(Modifier.fillMaxWidth().height(8.dp).background(SurfaceGrey))
                    menu.optionGroups.forEach { group ->
                        Column(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 17.dp, bottom = 6.dp)) {
                            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween) {
                                Text(group.name, color = Ink, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                                if (group.required) {
                                    val groupComplete = selection[group.id].orEmpty().isNotEmpty()
                                    Text(
                                        stringResource(if (groupComplete) R.string.option_selected else R.string.required_option),
                                        color = if (groupComplete) Color(0xFF1F8A4C) else Red,
                                        fontSize = 12.sp, fontWeight = FontWeight.Bold,
                                        modifier = Modifier.clip(CircleShape)
                                            .background(if (groupComplete) Color(0xFFE9F7EF) else RedSoft)
                                            .padding(horizontal = 11.dp, vertical = 4.dp))
                                } else {
                                    Text(
                                        if (group.maxSelect == 1) stringResource(R.string.option_single_allowed)
                                        else stringResource(R.string.option_up_to, group.maxSelect),
                                        fontSize = 12.sp, color = Sub)
                                }
                            }
                            if (group.required) {
                                Text(
                                    if (group.maxSelect == 1) stringResource(R.string.option_required_single)
                                    else stringResource(R.string.option_up_to, group.maxSelect),
                                    fontSize = 12.sp, color = Sub,
                                    modifier = Modifier.padding(top = 3.dp),
                                )
                            }
                            group.choices.forEach { choice ->
                                val chosen = choice.id in selection[group.id].orEmpty()
                                val toggle = {
                                    val previous = selection[group.id].orEmpty()
                                    val next = if (group.maxSelect == 1) {
                                        if (chosen && !group.required) emptySet() else setOf(choice.id)
                                    } else if (chosen) previous - choice.id
                                    else if (previous.size < group.maxSelect) previous + choice.id
                                    else previous
                                    selection = selection + (group.id to next)
                                }
                                Row(
                                    modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp)
                                        .clickable(role = if (group.maxSelect == 1) Role.RadioButton else Role.Checkbox) { toggle() },
                                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    val shape = if (group.maxSelect == 1) CircleShape else RoundedCornerShape(6.dp)
                                    Box(
                                        Modifier.size(22.dp)
                                            .background(if (group.maxSelect > 1 && chosen) Red else Color.White, shape)
                                            .border(
                                                if (group.maxSelect == 1 && chosen) 7.dp else 2.dp,
                                                if (chosen) Red else Color(0xFFC9C9D1), shape),
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        if (group.maxSelect > 1 && chosen) {
                                            Icon(Icons.Outlined.Check, contentDescription = null,
                                                tint = Color.White, modifier = Modifier.size(14.dp))
                                        }
                                    }
                                    Text(choice.name, color = Ink, fontSize = 15.sp, modifier = Modifier.weight(1f))
                                    if (choice.price != "0") Text(
                                        stringResource(R.string.option_extra_price, choice.price),
                                        fontSize = 14.sp, color = Sub)
                                }
                                HorizontalDivider(color = SurfaceGrey)
                            }
                        }
                    }
                    if (!valid) {
                        Box(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp)
                                .clip(RoundedCornerShape(13.dp)).background(Color(0xFFFFF6E5))
                                .padding(horizontal = 14.dp, vertical = 13.dp),
                        ) {
                            Text(stringResource(R.string.select_required_hint),
                                color = Color(0xFF9A5800), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }
                    Column(
                        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(stringResource(R.string.menu_note_title), color = Ink, fontSize = 16.sp,
                                fontWeight = FontWeight.Bold)
                            Text("${note.length}/250", color = Sub, fontSize = 12.sp)
                        }
                        OutlinedTextField(
                            value = note,
                            onValueChange = { note = it.take(250) },
                            placeholder = { Text(stringResource(R.string.menu_note_hint), color = Sub) },
                            shape = RoundedCornerShape(14.dp),
                            minLines = 2,
                            maxLines = 4,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                    Spacer(Modifier.height(22.dp))
                }
                Row(
                    modifier = Modifier.fillMaxWidth().shadow(7.dp).background(Color.White)
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Row(
                        modifier = Modifier.clip(CircleShape).background(SurfaceGrey).height(52.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        TextButton(
                            onClick = { quantity = (quantity - 1).coerceAtLeast(1) },
                            enabled = quantity > 1) { Text("−", fontSize = 22.sp, color = Ink) }
                        Text(quantity.toString(), fontSize = 16.sp, color = Ink, fontWeight = FontWeight.Bold)
                        TextButton(
                            onClick = { quantity = (quantity + 1).coerceAtMost(99) },
                            enabled = quantity < 99) { Text("+", fontSize = 21.sp, color = Ink) }
                    }
                    Button(
                        onClick = { onAdd(selection, quantity, note.trim()) },
                        enabled = valid,
                        modifier = Modifier.weight(1f).height(52.dp),
                        shape = CircleShape,
                        colors = ButtonDefaults.buttonColors(containerColor = Red),
                    ) {
                        Text(
                            if (valid) stringResource(R.string.cart_add_total, estimate.stripTrailingZeros().toPlainString())
                            else stringResource(R.string.select_required_options),
                            fontSize = 14.sp, fontWeight = FontWeight.Bold,
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun FoodCartPreview(
    cart: FoodCartDraft,
    onDismiss: () -> Unit,
    onClear: () -> Unit,
    state: FoodUiState? = null,
    onQuote: () -> Unit = {},
    onSelectAddress: (String?) -> Unit = {},
    onChangeQuantity: (String, Int) -> Unit = { _, _ -> },
) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Surface(color = Color.White, modifier = Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize()) {
                Row(
                    modifier = Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Outlined.ArrowBack, stringResource(R.string.back), tint = Ink)
                    }
                    Text(stringResource(R.string.cart_title), fontWeight = FontWeight.Bold,
                        fontSize = 19.sp, color = Ink, modifier = Modifier.weight(1f))
                    TextButton(onClick = onClear) {
                        Text(stringResource(R.string.clear_cart), color = Red)
                    }
                }
                HorizontalDivider(color = Line)
                Column(
                    Modifier.weight(1f).verticalScroll(rememberScrollState())
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    if (cart.lines.isEmpty()) {
                        Text(stringResource(R.string.cart_empty), color = Sub)
                    } else {
                        cart.lines.forEach { line ->
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.Top) {
                                Column(Modifier.weight(1f)) {
                                    Text(line.name, color = Ink, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                                    ) {
                                        OutlinedButton(
                                            onClick = { onChangeQuantity(line.identity, line.quantity - 1) },
                                            modifier = Modifier.height(36.dp),
                                            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp),
                                        ) { Text("−", fontSize = 16.sp) }
                                        Text(line.quantity.toString(), fontSize = 14.sp, color = Ink)
                                        OutlinedButton(
                                            onClick = { onChangeQuantity(line.identity, line.quantity + 1) },
                                            enabled = line.quantity < 99,
                                            modifier = Modifier.height(36.dp),
                                            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp),
                                        ) { Text("+", fontSize = 16.sp) }
                                    }
                                    if (line.options.isNotEmpty()) Text(
                                        line.options.joinToString(" · ") { it.name },
                                        color = Sub, fontSize = 12.sp)
                                    if (line.note.isNotBlank()) Text(
                                        stringResource(R.string.menu_note_title) + ": " + line.note,
                                        color = Sub, fontSize = 12.sp)
                                }
                                Text("฿" + line.estimatedTotal().stripTrailingZeros().toPlainString(),
                                    fontWeight = FontWeight.Bold, color = Ink)
                            }
                            HorizontalDivider(color = Line)
                        }
                    }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(stringResource(R.string.estimated_subtotal_label), color = Ink, fontWeight = FontWeight.SemiBold)
                        Text("฿" + cart.estimatedSubtotal.stripTrailingZeros().toPlainString(),
                            color = Ink, fontWeight = FontWeight.Bold)
                    }
                    Text(stringResource(R.string.estimate_not_final), color = Sub, fontSize = 12.sp)
                    if (state != null && cart.lines.isNotEmpty()) {
                        HorizontalDivider(color = Line)
                        Text(stringResource(R.string.delivery_addresses),
                            color = Ink, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                        when {
                            state.accountEmail == null ->
                                Text(stringResource(R.string.sign_in_to_quote), color = Sub, fontSize = 13.sp)
                            state.addressesLoading ->
                                Text(stringResource(R.string.loading_addresses), color = Sub, fontSize = 13.sp)
                            state.addressesFailed ->
                                Text(stringResource(R.string.addresses_load_error), color = Red, fontSize = 13.sp)
                            state.addresses.isEmpty() ->
                                Text(stringResource(R.string.no_saved_addresses), color = Sub, fontSize = 13.sp)
                            else -> state.addresses.forEach { address ->
                                val selected = state.selectedAddressId == address.id
                                Row(
                                    Modifier.fillMaxWidth().clip(RoundedCornerShape(13.dp))
                                        .background(if (selected) RedSoft else SurfaceGrey)
                                        .clickable { onSelectAddress(address.id) }
                                        .padding(12.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                                ) {
                                    androidx.compose.material3.RadioButton(
                                        selected = selected, onClick = { onSelectAddress(address.id) },
                                        colors = androidx.compose.material3.RadioButtonDefaults.colors(selectedColor = Red),
                                    )
                                    Column(Modifier.weight(1f)) {
                                        Text(address.label, fontWeight = FontWeight.Bold, color = Ink)
                                        Text(address.address, color = Sub, fontSize = 12.sp)
                                    }
                                }
                            }
                        }
                        OutlinedButton(
                            onClick = onQuote,
                            enabled = state.accountEmail != null && !state.quoteLoading,
                            modifier = Modifier.fillMaxWidth(),
                        ) { Text(stringResource(R.string.server_quote_button)) }
                        if (state.quoteLoading) {
                            Text(stringResource(R.string.server_quote_loading), color = Sub, fontSize = 13.sp)
                        }
                        if (state.quoteFailed) {
                            Text(stringResource(R.string.server_quote_error), color = Red, fontSize = 13.sp)
                        }
                        state.quote?.let { quote ->
                            Column(
                                Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp))
                                    .background(SurfaceGrey).padding(14.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp),
                            ) {
                                Text(stringResource(R.string.server_quote_label), color = Ink,
                                    fontSize = 16.sp, fontWeight = FontWeight.Bold)
                                QuoteRow(stringResource(R.string.estimated_subtotal_label), quote.subtotal.toPlainString())
                                QuoteRow(stringResource(R.string.server_delivery_fee), quote.deliveryFee.toPlainString())
                                QuoteRow(stringResource(R.string.server_campaign_discount), "-" + quote.campaignDiscount.toPlainString())
                                QuoteRow(stringResource(R.string.server_delivery_discount), "-" + quote.deliveryDiscount.toPlainString())
                                HorizontalDivider(color = Line)
                                QuoteRow(stringResource(R.string.server_quote_total), quote.total.toPlainString())
                                if (quote.needsLocation) {
                                    Text(stringResource(R.string.server_quote_needs_pin),
                                        color = Red, fontSize = 12.sp)
                                }
                                Text(stringResource(R.string.server_quote_not_payment), color = Sub, fontSize = 12.sp)
                            }
                        }
                    }
                }
                Box(Modifier.fillMaxWidth().shadow(8.dp).padding(16.dp)) {
                    Button(
                        onClick = {}, enabled = false,
                        modifier = Modifier.fillMaxWidth().height(52.dp),
                        shape = CircleShape,
                    ) { Text(stringResource(R.string.checkout_unavailable)) }
                }
            }
        }
    }
}

@Composable
private fun QuoteRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = Sub, fontSize = 13.sp, modifier = Modifier.weight(1f))
        Text("฿" + value, color = Ink, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
    }
}
