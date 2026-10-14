package online.wynos.food.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import online.wynos.food.R

/** UI friction is not authorization: the server RPC and staging build gate decide. */
object FoodAccountDeletionConfirmation {
    fun isConfirmed(input: String, phrase: String): Boolean =
        phrase.isNotBlank() && input.trim() == phrase
}

@Composable
fun FoodAccountDeletionDialog(
    enabled: Boolean,
    busy: Boolean,
    failed: Boolean,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    var enteredPhrase by remember { mutableStateOf("") }
    var finalConfirmation by remember { mutableStateOf(false) }
    val phrase = stringResource(R.string.account_delete_phrase)
    val canDelete = enabled && !busy &&
        FoodAccountDeletionConfirmation.isConfirmed(enteredPhrase, phrase)

    Dialog(onDismissRequest = { if (!busy) onDismiss() }) {
        androidx.compose.material3.Surface(
            color = Color.White,
            shape = androidx.compose.foundation.shape.RoundedCornerShape(20.dp),
        ) {
            Column(
                Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(stringResource(R.string.account_delete_title), fontWeight = FontWeight.Bold)
                Text(stringResource(R.string.account_delete_shared_warning),
                    color = Color(0xFFB3261E))
                Text(stringResource(R.string.account_delete_cannot_undo))
                if (!enabled) {
                    Text(stringResource(R.string.account_delete_staging_only),
                        color = Color(0xFFB3261E))
                }
                Text(stringResource(R.string.account_delete_type_instruction, phrase))
                OutlinedTextField(
                    value = enteredPhrase,
                    onValueChange = { enteredPhrase = it },
                    enabled = enabled && !busy,
                    singleLine = true,
                    label = { Text(stringResource(R.string.account_delete_confirmation_label)) },
                    modifier = Modifier.fillMaxWidth(),
                )
                if (failed) {
                    Text(stringResource(R.string.account_delete_failed),
                        color = Color(0xFFB3261E))
                }
                if (busy) CircularProgressIndicator()
                Button(
                    onClick = { finalConfirmation = true },
                    enabled = canDelete,
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFB3261E)),
                    modifier = Modifier.fillMaxWidth(),
                ) { Text(stringResource(R.string.account_delete_action)) }
                TextButton(onClick = onDismiss, enabled = !busy) {
                    Text(stringResource(R.string.address_cancel))
                }
            }
        }
    }
    if (finalConfirmation) {
        AlertDialog(
            onDismissRequest = { if (!busy) finalConfirmation = false },
            title = { Text(stringResource(R.string.account_delete_final_title)) },
            text = { Text(stringResource(R.string.account_delete_final_warning)) },
            confirmButton = {
                TextButton(onClick = {
                    finalConfirmation = false
                    onConfirm()
                }, enabled = canDelete) {
                    Text(stringResource(R.string.account_delete_action),
                        color = Color(0xFFB3261E))
                }
            },
            dismissButton = {
                TextButton(onClick = { finalConfirmation = false }, enabled = !busy) {
                    Text(stringResource(R.string.address_cancel))
                }
            },
        )
    }
}
