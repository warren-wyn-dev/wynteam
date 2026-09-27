package io.wyn.wyn.feature.auth

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.graphics.scale
import io.wyn.wyn.R
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.Gap
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynPrimaryButton
import io.wyn.wyn.core.design.WynTextField
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

/** Mirrors the web's OnboardingProfileScreen: optional photo and bio, or skip. */
@Composable
fun OnboardingScreen(vm: AccountFlowViewModel) {
    val c = Wyn.colors
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) {
            scope.launch {
                val result = withContext(Dispatchers.IO) { prepareAvatar(context, uri) }
                result.fold({ vm.setAvatar(it) }, { vm.setAvatar(null, (it as? AvatarError)?.text ?: UiText(R.string.err_image_type)) })
            }
        }
    }
    val preview = remember(vm.avatar) { vm.avatar?.let { BitmapFactory.decodeByteArray(it, 0, it.size)?.asImageBitmap() } }

    AuthPage {
        Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 16.dp), horizontalArrangement = Arrangement.End) {
            Text(
                stringResource(R.string.skip), color = c.textSecondary, fontSize = 13.sp,
                modifier = Modifier.clickable(enabled = !vm.onboardingLoading, role = Role.Button) { vm.finishOnboarding(skip = true) },
            )
        }
        Column(Modifier.weight(1f).padding(horizontal = 20.dp)) {
            Column(Modifier.fillMaxWidth().padding(bottom = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(stringResource(R.string.onboarding_title), color = c.text, fontSize = 32.sp, fontWeight = androidx.compose.ui.text.font.FontWeight.ExtraBold)
                Gap(6)
                Text(stringResource(R.string.onboarding_subtitle), color = c.textSecondary, fontSize = 13.sp, textAlign = TextAlign.Center)
            }
            Box(Modifier.fillMaxWidth().padding(bottom = 24.dp), contentAlignment = Alignment.Center) {
                val label = stringResource(R.string.onboarding_pick_photo)
                Box(
                    Modifier.size(96.dp).clickable(enabled = !vm.onboardingLoading, onClickLabel = label, role = Role.Button) {
                        picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    },
                ) {
                    if (preview != null) {
                        Image(preview, contentDescription = label, contentScale = ContentScale.Crop, modifier = Modifier.size(96.dp).clip(CircleShape))
                    } else {
                        Box(Modifier.size(96.dp).clip(CircleShape).background(c.border))
                    }
                    Box(
                        Modifier.align(Alignment.BottomEnd).offset((-2).dp, (-2).dp).size(30.dp).clip(CircleShape)
                            .background(c.text).border(2.dp, c.bg, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(Icons.Filled.Add, contentDescription = null, tint = c.bg, modifier = Modifier.size(16.dp))
                    }
                }
            }
            WynTextField(
                stringResource(R.string.onboarding_bio), vm.bio, vm::updateBio, stringResource(R.string.onboarding_bio_placeholder),
                singleLine = false, minHeight = 70,
            )
            ErrorText(vm.onboardingError.text())
        }
        Column(Modifier.padding(horizontal = 20.dp, vertical = 16.dp)) {
            WynPrimaryButton(
                stringResource(if (vm.onboardingLoading) R.string.saving else R.string.onboarding_start),
                { vm.finishOnboarding() }, enabled = !vm.onboardingLoading,
            )
        }
    }
}

class AvatarError(res: Int) : Exception() {
    val text = UiText(res)
}

/**
 * Same limits as the web (10MB, images only), then a centred square
 * scaled to 1024px JPEG — the web's cropper output size.
 */
private fun prepareAvatar(context: Context, uri: Uri): Result<ByteArray> = runCatching {
    val resolver = context.contentResolver
    val size = resolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
        if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getLong(0) else null
    }
    if (size != null && (size == 0L || size > AuthRules.AVATAR_MAX_BYTES)) throw AvatarError(R.string.err_image_size)
    val type = resolver.getType(uri).orEmpty()
    if (!type.startsWith("image/")) throw AvatarError(R.string.err_image_type)
    val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        ImageDecoder.decodeBitmap(ImageDecoder.createSource(resolver, uri)) { decoder, _, _ ->
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
        }
    } else {
        resolver.openInputStream(uri)?.use(BitmapFactory::decodeStream)
    } ?: throw AvatarError(R.string.err_image_type)
    val side = minOf(bitmap.width, bitmap.height)
    val square = Bitmap.createBitmap(bitmap, (bitmap.width - side) / 2, (bitmap.height - side) / 2, side, side)
    val target = minOf(side, 1024)
    val scaled = if (target == side) square else square.scale(target, target)
    ByteArrayOutputStream().use { out ->
        scaled.compress(Bitmap.CompressFormat.JPEG, 90, out)
        out.toByteArray()
    }
}
