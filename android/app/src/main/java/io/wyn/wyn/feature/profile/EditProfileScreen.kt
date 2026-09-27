package io.wyn.wyn.feature.profile

import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import io.wyn.wyn.R
import io.wyn.wyn.core.data.AVATAR_MAX_BYTES
import io.wyn.wyn.core.data.ProfileImage
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.core.design.WynTextField
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.feature.auth.text
import io.wyn.wyn.feature.compose.PhotoReader
import io.wyn.wyn.feature.compose.PhotoRejected
import io.wyn.wyn.feature.compose.newCameraUri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private val Danger = Color(0xFFE0203D)

/** web EditProfile (profile-route.tsx). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditProfileScreen(vm: EditProfileViewModel, onClose: () -> Unit) {
    val c = Wyn.colors
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var target by rememberSaveable { mutableStateOf(ProfileImage.Avatar) }
    var cropUri by rememberSaveable { mutableStateOf<String?>(null) }
    var cameraUri by rememberSaveable { mutableStateOf<String?>(null) }

    fun accept(uri: Uri?) {
        if (uri == null) return
        val kind = target
        scope.launch {
            try {
                // Type and size are checked first; a cover keeps its format with location removed,
                // an avatar is re-drawn by the cropper and never uploaded as picked.
                val photo = withContext(Dispatchers.IO) { PhotoReader.read(context, uri, AVATAR_MAX_BYTES, R.string.profile_photo_too_large) }
                if (kind == ProfileImage.Avatar) {
                    vm.showError(null)
                    cropUri = uri.toString()
                } else {
                    vm.uploadPhoto(kind, ProfilePhoto(photo.bytes, photo.contentType, photo.extension))
                }
            } catch (e: PhotoRejected) {
                vm.showError(UiText(e.reason))
            } catch (e: kotlin.coroutines.cancellation.CancellationException) {
                throw e
            } catch (e: Exception) {
                vm.showError(UiText(R.string.photo_wrong_type))
            }
        }
    }
    val library = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { accept(it) }
    val files = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { accept(it) }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { saved ->
        if (saved) accept(cameraUri?.let(Uri::parse))
    }

    BackHandler(enabled = !vm.saving, onBack = onClose)
    Column(Modifier.fillMaxSize().background(c.bg).statusBarsPadding().imePadding()) {
        Box(Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 8.dp)) {
            val back = stringResource(R.string.back)
            Icon(
                WynIcons.Back, contentDescription = back, tint = c.text,
                modifier = Modifier.align(Alignment.CenterStart).size(44.dp).clip(CircleShape)
                    .clickable(enabled = !vm.saving, role = Role.Button, onClickLabel = back, onClick = onClose).padding(10.dp),
            )
            Text(stringResource(R.string.profile_edit), color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold, modifier = Modifier.align(Alignment.Center))
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
            Box(
                Modifier.fillMaxWidth().height(150.dp).background(Brush.linearGradient(listOf(Color(0xFF111111), Color(0xFF35363B)))),
            ) {
                vm.coverUrl?.let { AsyncImage(it, contentDescription = stringResource(R.string.profile_cover), contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize()) }
                CameraButton(stringResource(R.string.profile_change_cover), 21, !vm.saving, Modifier.align(Alignment.BottomEnd).padding(12.dp)) { vm.openPhotoMenu(ProfileImage.Cover) }
            }
            Row(Modifier.padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                Box {
                    WynAvatar(vm.avatarUrl, 96, contentDescription = stringResource(R.string.profile_avatar))
                    CameraButton(stringResource(R.string.profile_change_avatar), 18, !vm.saving, Modifier.align(Alignment.BottomEnd)) { vm.openPhotoMenu(ProfileImage.Avatar) }
                }
                Column(Modifier.padding(start = 14.dp)) {
                    Text(stringResource(R.string.profile_avatar), color = c.text, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                    Text(stringResource(R.string.profile_avatar_hint), color = c.textSecondary, fontSize = 12.sp)
                }
            }
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(stringResource(R.string.profile_info), color = c.text, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                WynTextField(stringResource(R.string.display_name), vm.displayName, vm::updateDisplayName, stringResource(R.string.display_name), enabled = !vm.saving)
                WynTextField(stringResource(R.string.username), vm.username, vm::updateUsername, "username", prefix = "@", keyboardType = KeyboardType.Ascii, enabled = !vm.saving)
                Column {
                    WynTextField(stringResource(R.string.profile_bio), vm.bio, vm::updateBio, stringResource(R.string.profile_bio), singleLine = false, minHeight = 110, enabled = !vm.saving)
                    Text("${vm.bio.length}/$BIO_MAX", color = c.textSecondary, fontSize = 12.sp, modifier = Modifier.align(Alignment.End).padding(top = 4.dp))
                }
                WynTextField(stringResource(R.string.profile_website), vm.website, vm::updateWebsite, "example.com", keyboardType = KeyboardType.Uri, enabled = !vm.saving)
                ErrorText(vm.error.text())
            }
            Spacer(Modifier.height(24.dp))
        }
        Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            PillButton(stringResource(R.string.cancel), filled = false, outlined = true, enabled = !vm.saving, modifier = Modifier.weight(1f), onClick = onClose)
            PillButton(stringResource(if (vm.saving) R.string.saving else R.string.save_profile), filled = true, enabled = !vm.saving, modifier = Modifier.weight(1f), onClick = vm::save)
        }
    }

    vm.photoMenu?.let { kind ->
        ModalBottomSheet(
            onDismissRequest = { vm.openPhotoMenu(null) },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = c.bg,
            shape = RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp),
        ) {
            Column(Modifier.padding(bottom = 12.dp)) {
                Text(
                    stringResource(if (kind == ProfileImage.Avatar) R.string.profile_avatar else R.string.profile_cover),
                    color = c.text, fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 20.dp, bottom = 6.dp),
                )
                fun choose(action: () -> Unit) { target = kind; vm.openPhotoMenu(null); action() }
                SourceRow(WynIcons.Image, stringResource(R.string.photo_library)) {
                    choose { library.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }
                }
                SourceRow(WynIcons.Camera, stringResource(R.string.photo_camera)) {
                    choose {
                        val uri = newCameraUri(context)
                        cameraUri = uri.toString()
                        camera.launch(uri)
                    }
                }
                SourceRow(WynIcons.FileText, stringResource(R.string.photo_files)) { choose { files.launch("image/*") } }
                val current = if (kind == ProfileImage.Avatar) vm.avatarUrl else vm.coverUrl
                if (current != null) {
                    SourceRow(WynIcons.Trash, stringResource(if (kind == ProfileImage.Avatar) R.string.profile_remove_avatar else R.string.profile_remove_cover), danger = true) {
                        vm.askRemove(kind)
                    }
                }
                SourceRow(null, stringResource(R.string.cancel)) { vm.openPhotoMenu(null) }
            }
        }
    }
    vm.confirmRemove?.let { kind ->
        AlertDialog(
            onDismissRequest = vm::dismissRemove,
            containerColor = c.bg,
            title = { Text(stringResource(if (kind == ProfileImage.Avatar) R.string.profile_remove_avatar_confirm else R.string.profile_remove_cover_confirm), color = c.text, fontWeight = FontWeight.Bold, fontSize = 17.sp) },
            confirmButton = { TextButton(onClick = vm::removePhoto) { Text(stringResource(R.string.remove), color = Danger, fontWeight = FontWeight.Bold) } },
            dismissButton = { TextButton(onClick = vm::dismissRemove) { Text(stringResource(R.string.cancel), color = c.textSecondary) } },
        )
    }
    cropUri?.let { uri ->
        PhotoCropper(
            Uri.parse(uri),
            onCancel = { cropUri = null },
            onConfirm = { jpeg ->
                vm.uploadPhoto(ProfileImage.Avatar, ProfilePhoto(jpeg, "image/jpeg", "jpg"))
                cropUri = null
            },
        )
    }
}

@Composable
private fun CameraButton(label: String, size: Int, enabled: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier.size(size.dp + 16.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.72f)).border(2.dp, Color.White, CircleShape)
            .clickable(enabled = enabled, role = Role.Button, onClickLabel = label, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(WynIcons.Camera, contentDescription = label, tint = Color.White, modifier = Modifier.size(size.dp))
    }
}

@Composable
private fun SourceRow(icon: ImageVector?, label: String, danger: Boolean = false, onClick: () -> Unit) {
    val c = Wyn.colors
    val tint = if (danger) Danger else c.text
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().heightIn(min = 54.dp).clickable(role = Role.Button, onClick = onClick).padding(horizontal = 20.dp),
    ) {
        if (icon != null) {
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(22.dp))
            Spacer(Modifier.width(14.dp))
        }
        Text(label, color = tint, fontSize = 15.sp, fontWeight = if (icon == null) FontWeight.SemiBold else FontWeight.Normal)
    }
}
