package io.wyn.wyn.feature.clubs

import android.content.Context
import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import io.wyn.wyn.R
import io.wyn.wyn.core.data.Club
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.core.design.WynPrimaryButton
import io.wyn.wyn.core.design.WynTextField
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.home.ReportCategories
import io.wyn.wyn.feature.home.SnackBar
import io.wyn.wyn.feature.home.Toast
import io.wyn.wyn.feature.profile.ReportLabels
import kotlinx.coroutines.delay
import java.text.NumberFormat
import java.util.Locale

internal val DangerRed = Color(0xFFB42318)

/** Member counts grouped the Thai way ("1,234"), like toLocaleString("th-TH"). */
fun memberCount(value: Int): String = NumberFormat.getIntegerInstance(Locale.forLanguageTag("th-TH")).format(value)

/** Opens the system share sheet with a web link. */
fun shareLink(context: Context, title: String, url: String) {
    val send = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_SUBJECT, title)
        putExtra(Intent.EXTRA_TEXT, url)
    }
    context.startActivity(Intent.createChooser(send, null))
}

/** A plain title bar with a back button (web AppChrome header). */
@Composable
fun ClubTopBar(title: String, onBack: (() -> Unit)?) {
    val c = Wyn.colors
    Box(Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 8.dp)) {
        if (onBack != null) {
            val back = stringResource(R.string.back)
            Icon(
                WynIcons.Back, contentDescription = back, tint = c.text,
                modifier = Modifier.align(Alignment.CenterStart).size(44.dp).clip(CircleShape)
                    .clickable(role = Role.Button, onClickLabel = back, onClick = onBack).padding(10.dp),
            )
        }
        Text(
            title, color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold, maxLines = 1,
            modifier = Modifier.align(Alignment.Center).padding(horizontal = 56.dp),
        )
    }
    HorizontalDivider(color = c.border, thickness = 1.dp)
}

/** audit-club-avatar: the Club photo, or its first letter. */
@Composable
fun ClubAvatar(club: Club, size: Int = 44) {
    val c = Wyn.colors
    Box(
        Modifier.size(size.dp).clip(CircleShape).border(1.dp, c.border, CircleShape).background(c.surface),
        contentAlignment = Alignment.Center,
    ) {
        if (club.iconUrl != null) {
            AsyncImage(club.iconUrl, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        } else {
            Text(club.name.trim().take(1).uppercase().ifEmpty { "C" }, color = c.text, fontSize = (size * 0.36f).sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
fun ClubLoading() {
    Box(Modifier.fillMaxWidth().padding(48.dp), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(color = Wyn.colors.textSecondary, strokeWidth = 2.dp, modifier = Modifier.size(24.dp))
    }
}

@Composable
fun ClubEmpty(message: String) {
    Text(
        message, color = Wyn.colors.textSecondary, fontSize = 15.sp, textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 48.dp),
    )
}

/** golden-club-sheet: a bottom sheet with a grip. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClubSheet(onDismiss: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    val c = Wyn.colors
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = c.bg,
        shape = RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp),
        dragHandle = { Box(Modifier.padding(top = 10.dp, bottom = 8.dp).size(38.dp, 4.dp).clip(RoundedCornerShape(999.dp)).background(c.border)) },
    ) {
        Column(Modifier.padding(bottom = 10.dp), content = content)
    }
}

/** golden-club-sheet-row. */
@Composable
fun SheetRow(icon: ImageVector, label: String, first: Boolean = false, danger: Boolean = false, enabled: Boolean = true, onClick: () -> Unit) {
    val c = Wyn.colors
    val tint = (if (danger) DangerRed else c.text).copy(alpha = if (enabled) 1f else 0.5f)
    if (!first) HorizontalDivider(color = c.border, thickness = 1.dp)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().heightIn(min = 54.dp).clickable(enabled = enabled, role = Role.Button, onClick = onClick).padding(horizontal = 20.dp),
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(14.dp))
        Text(label, color = tint, fontSize = 15.sp)
    }
}

/** web ReportSheet for a Club, a Club post or a Club message. */
@Composable
fun ClubReportSheet(report: ClubReport) {
    val target = report.target ?: return
    val c = Wyn.colors
    ClubSheet(onDismiss = { if (!report.busy) report.open(null) }) {
        Column(
            Modifier.verticalScroll(rememberScrollState()).padding(start = 18.dp, end = 18.dp, bottom = 14.dp, top = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(target.label.text().orEmpty(), color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            Column(Modifier.border(1.dp, c.border, RoundedCornerShape(14.dp)).clip(RoundedCornerShape(14.dp))) {
                ReportCategories.forEachIndexed { index, key ->
                    if (index > 0) HorizontalDivider(color = c.border, thickness = 1.dp)
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth().heightIn(min = 46.dp)
                            .selectable(report.category == key, role = Role.RadioButton) { report.choose(key) }
                            .padding(horizontal = 4.dp),
                    ) {
                        RadioButton(selected = report.category == key, onClick = null, colors = RadioButtonDefaults.colors(selectedColor = c.text), modifier = Modifier.padding(horizontal = 8.dp))
                        Text(stringResource(ReportLabels.getValue(key)), color = c.text, fontSize = 14.sp)
                    }
                }
            }
            if (report.category == "other") {
                WynTextField(stringResource(R.string.report_detail), report.detail, report::updateDetail, stringResource(R.string.report_detail), singleLine = false, minHeight = 96)
            }
            ErrorText(report.error.text())
            WynPrimaryButton(stringResource(R.string.report_send), report::submit, enabled = !report.busy)
        }
    }
}

/** window.confirm(): a question with a red action. */
@Composable
fun ClubConfirmDialog(title: String, confirm: String, onConfirm: () -> Unit, onCancel: () -> Unit) {
    val c = Wyn.colors
    AlertDialog(
        onDismissRequest = onCancel,
        containerColor = c.bg,
        title = { Text(title, color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold) },
        confirmButton = { TextButton(onClick = onConfirm) { Text(confirm, color = DangerRed, fontWeight = FontWeight.Bold) } },
        dismissButton = { TextButton(onClick = onCancel) { Text(stringResource(R.string.cancel), color = c.textSecondary) } },
    )
}

/** The web Toast at the bottom of the screen; it hides itself after 4 seconds. */
@Composable
fun ClubToast(toast: Toast?, onDismiss: () -> Unit, modifier: Modifier = Modifier) {
    LaunchedEffect(toast) {
        if (toast != null) {
            delay(4000)
            onDismiss()
        }
    }
    if (toast == null) return
    Box(modifier.fillMaxWidth().padding(14.dp)) {
        SnackBar(toast.text.text().orEmpty(), toast.actionLabel.text(), toast.action)
    }
}
