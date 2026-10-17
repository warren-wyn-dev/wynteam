package online.wynos.food.ui

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import online.wynos.food.R

/**
 * Visual selection ONLY. Never persist the URI, invoke a payment RPC, upload
 * customer media, or imply a merchant received proof of payment here.
 *
 * The real manual/QR slip submission needs the isolated Food+Merchant staging
 * contract, buyer-owned Storage policy, cancellation/expiry rules and QA.
 */
internal fun shouldShowStagingSlipPreview(
    stagingPaymentEnabled: Boolean,
    orderStatus: String,
    paymentStatus: String,
): Boolean = stagingPaymentEnabled &&
    orderStatus == "pending_acceptance" &&
    paymentStatus in setOf("pending", "issue")

@Composable
internal fun FoodStagingSlipPicker(orderId: String) {
    // Local to this order/dialog. Never cross-account cache or persist a
    // sensitive payment image to app preferences or a shared filesystem.
    var selectedUri by remember(orderId) { mutableStateOf<Uri?>(null) }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) selectedUri = uri
    }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.slip_preview_title))
        Text(stringResource(R.string.slip_preview_no_upload))
        selectedUri?.let { uri ->
            AsyncImage(
                model = uri,
                contentDescription = stringResource(R.string.slip_preview_image_description),
                modifier = Modifier.fillMaxWidth().height(180.dp)
                    .clip(RoundedCornerShape(12.dp)),
                contentScale = ContentScale.Fit,
            )
            Text(stringResource(R.string.slip_preview_selected_local))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = { picker.launch("image/*") }) {
                Text(stringResource(
                    if (selectedUri == null) R.string.slip_preview_choose
                    else R.string.slip_preview_replace
                ))
            }
            if (selectedUri != null) {
                TextButton(onClick = { selectedUri = null }) {
                    Text(stringResource(R.string.slip_preview_remove))
                }
            }
        }
    }
}
