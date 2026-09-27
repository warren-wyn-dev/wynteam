package io.wyn.wyn.core.design

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.wyn.wyn.R

// Web: .auth-ref-viewport .field — 12px label, 56px box, 18px radius, border-strong.
private val FieldShape = RoundedCornerShape(18.dp)

@Composable
fun FieldLabel(text: String) {
    Text(
        text, color = Wyn.colors.textSecondary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
        modifier = Modifier.padding(bottom = 5.dp),
    )
}

@Composable
fun WynTextField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    password: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    prefix: String? = null,
    enabled: Boolean = true,
    minHeight: Int = 56,
    singleLine: Boolean = true,
) {
    val c = Wyn.colors
    Column(modifier.fillMaxWidth().padding(bottom = 14.dp)) {
        FieldLabel(label)
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            enabled = enabled,
            singleLine = singleLine,
            textStyle = TextStyle(color = c.text, fontSize = 16.sp),
            cursorBrush = SolidColor(c.text),
            visualTransformation = if (password) PasswordVisualTransformation() else VisualTransformation.None,
            keyboardOptions = KeyboardOptions(keyboardType = if (password) KeyboardType.Password else keyboardType),
            modifier = Modifier.fillMaxWidth().semantics { contentDescription = label },
            decorationBox = { inner ->
                Row(
                    verticalAlignment = if (singleLine) Alignment.CenterVertically else Alignment.Top,
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = minHeight.dp)
                        .border(1.dp, c.borderStrong, FieldShape)
                        .background(c.bg, FieldShape)
                        .padding(horizontal = 18.dp, vertical = if (singleLine) 0.dp else 10.dp),
                ) {
                    if (prefix != null) Text(prefix, color = c.textMuted, fontSize = 16.sp)
                    Box(Modifier.weight(1f)) {
                        if (value.isEmpty()) Text(placeholder, color = c.textMuted, fontSize = 16.sp)
                        inner()
                    }
                }
            },
        )
    }
}

/** The web's `.wyn-select`: a 56px box that opens a menu. */
@Composable
fun <T> WynSelect(
    label: String,
    placeholder: String,
    selected: T?,
    options: List<T>,
    optionLabel: (T) -> String,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
) {
    val c = Wyn.colors
    var open by remember { mutableStateOf(false) }
    Box(modifier) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp)
                .border(1.dp, c.borderStrong, FieldShape)
                .background(c.bg, FieldShape)
                .clickable { open = true }
                .semantics { contentDescription = label }
                .padding(start = 10.dp, end = 4.dp),
        ) {
            Text(
                selected?.let(optionLabel) ?: placeholder,
                color = c.text, fontSize = 15.sp, maxLines = 1, modifier = Modifier.weight(1f),
            )
            Icon(Icons.Filled.KeyboardArrowDown, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(18.dp))
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }, modifier = Modifier.heightIn(max = 320.dp)) {
            options.forEach { option ->
                DropdownMenuItem(text = { Text(optionLabel(option)) }, onClick = { open = false; onSelect(option) })
            }
        }
    }
}

/** Web: .topbar with the back button and an optional "1/2" step. */
@Composable
fun BackTopbar(onBack: () -> Unit, step: String? = null) {
    val c = Wyn.colors
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 6.dp, vertical = 2.dp),
    ) {
        IconButton(onClick = onBack) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back), tint = c.text, modifier = Modifier.size(20.dp))
        }
        if (step != null) Text(step, color = c.textMuted, fontSize = 12.sp, modifier = Modifier.padding(end = 10.dp))
    }
}

@Composable
fun ErrorText(text: String?) {
    if (text.isNullOrEmpty()) return
    Text(text, color = Wyn.colors.accent, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp))
}

@Composable
fun ScreenTitle(title: String, subtitle: String? = null) {
    val c = Wyn.colors
    Text(title, color = c.text, fontSize = 32.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.6).sp)
    if (subtitle != null) {
        Spacer(Modifier.height(6.dp))
        Text(subtitle, color = c.textSecondary, fontSize = 13.sp, lineHeight = 19.sp)
    }
    Spacer(Modifier.height(20.dp))
}

@Composable
fun Gap(dp: Int) = Spacer(Modifier.height(dp.dp).width(dp.dp))
