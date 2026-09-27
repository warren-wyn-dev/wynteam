package io.wyn.wyn.feature.notifications

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import io.wyn.wyn.R
import io.wyn.wyn.core.push.PushBlock
import io.wyn.wyn.core.push.PushController
import io.wyn.wyn.core.push.notificationsAllowed

private tailrec fun Context.activity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.activity()
    else -> null
}

/** Android can still show its permission question (not "don't ask again"). */
fun canAskNotificationPermission(context: Context, push: PushController): Boolean {
    if (notificationsAllowed(context)) return true
    if (Build.VERSION.SDK_INT < 33) return false // Off in system settings: only the phone's settings can undo it.
    val activity = context.activity() ?: return false
    return !push.permissionAsked || activity.shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)
}

/**
 * Asks Android for notification permission (only from a tap, like the web),
 * then reports whether notifications are allowed.
 */
@Composable
fun rememberNotificationPermission(push: PushController, onResult: (Boolean) -> Unit): () -> Unit {
    val context = LocalContext.current
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        onResult(granted && notificationsAllowed(context))
    }
    return {
        when {
            notificationsAllowed(context) -> onResult(true)
            Build.VERSION.SDK_INT >= 33 && canAskNotificationPermission(context, push) -> {
                push.markPermissionAsked()
                launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
            else -> onResult(false)
        }
    }
}

/** The app's notification settings page in Android Settings. */
fun openNotificationSettings(context: Context) {
    val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
    runCatching { context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }.onFailure {
        runCatching {
            context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }
}

/** web pushReasonDescription(), for a phone. */
fun pushReasonText(reason: PushBlock): Int = when (reason) {
    PushBlock.NotConfigured -> R.string.push_reason_not_configured
    PushBlock.Denied -> R.string.push_reason_denied
    PushBlock.Dismissed -> R.string.push_reason_dismissed
    PushBlock.NoToken -> R.string.push_reason_no_token
    PushBlock.ServerFailed -> R.string.push_reason_server_failed
    PushBlock.Temporary -> R.string.push_reason_temporary
}
