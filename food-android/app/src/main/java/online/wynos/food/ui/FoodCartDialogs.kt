package online.wynos.food.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import online.wynos.food.R
import online.wynos.food.data.FoodCartDraft
import online.wynos.food.data.FoodMenu

/**
 * Draft menu selections only. Radio controls are vertical for single-choice
 * groups (including spicy level). Multiple-choice options use checkboxes.
 */
@Composable
fun FoodMenuOptionsDialog(
    menu: FoodMenu,
    onDismiss: () -> Unit,
    onAdd: (Map<String, Set<String>>, Int) -> Unit,
) {
    var selected by remember(menu.id) { mutableStateOf<Map<String, Set<String>>>(emptyMap()) }
    var quantity by remember(menu.id) { mutableIntStateOf(1) }
    val requiredValid = menu.optionGroups.all { group ->
        !group.required || selected[group.id].orEmpty().isNotEmpty()
    }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(menu.name, fontWeight = FontWeight.Bold) },
        text = {
            LazyColumn(
                modifier = Modifier.heightIn(max = 440.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                menu.optionGroups.forEach { group ->
                    item(key = group.id) {
                        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Text(
                                group.name + if (group.required) " *" else "",
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.SemiBold,
                            )
                            group.choices.forEach { choice ->
                                val chosen = choice.id in selected[group.id].orEmpty()
                                val toggle = {
                                    val old = selected[group.id].orEmpty()
                                    val next = if (group.maxSelect == 1) {
                                        if (chosen && !group.required) emptySet() else setOf(choice.id)
                                    } else {
                                        if (chosen) old - choice.id
                                        else if (old.size < group.maxSelect) old + choice.id
                                        else old
                                    }
                                    selected = selected + (group.id to next)
                                }
                                Row(
                                    modifier = Modifier.fillMaxWidth().clickable { toggle() }.padding(vertical = 5.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                ) {
                                    if (group.maxSelect == 1) {
                                        RadioButton(selected = chosen, onClick = toggle)
                                    } else {
                                        Checkbox(checked = chosen, onCheckedChange = { toggle() })
                                    }
                                    Text(choice.name, modifier = Modifier.weight(1f))
                                    if (choice.price != "0") Text(stringResource(R.string.option_extra_price, choice.price))
                                }
                            }
                        }
                    }
                }
                item {
                    Text(stringResource(R.string.quantity_label, quantity), fontWeight = FontWeight.SemiBold)
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        OutlinedButton(onClick = { quantity = (quantity - 1).coerceAtLeast(1) }, enabled = quantity > 1) {
                            Text("−")
                        }
                        Text(quantity.toString())
                        OutlinedButton(onClick = { quantity = (quantity + 1).coerceAtMost(20) }, enabled = quantity < 20) {
                            Text("+")
                        }
                    }
                }
            }
        },
        confirmButton = {
            Button(onClick = { onAdd(selected, quantity) }, enabled = requiredValid) {
                Text(stringResource(R.string.add_to_cart))
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.back)) } },
    )
}

@Composable
fun FoodCartPreview(cart: FoodCartDraft, onDismiss: () -> Unit, onClear: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.cart_title)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                cart.lines.forEach { line ->
                    Text(stringResource(R.string.cart_line, line.name, line.quantity, line.estimatedTotal().stripTrailingZeros().toPlainString()))
                }
                Text(
                    stringResource(R.string.estimated_subtotal, cart.estimatedSubtotal.stripTrailingZeros().toPlainString()),
                    fontWeight = FontWeight.Bold,
                )
                Text(stringResource(R.string.estimate_not_final), style = MaterialTheme.typography.bodySmall)
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.back)) }
        },
        dismissButton = {
            TextButton(onClick = onClear) { Text(stringResource(R.string.clear_cart)) }
        },
    )
}
