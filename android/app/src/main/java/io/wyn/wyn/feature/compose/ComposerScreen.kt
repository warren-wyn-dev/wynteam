package io.wyn.wyn.feature.compose

import android.content.Context
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import coil3.compose.AsyncImage
import io.wyn.wyn.R
import io.wyn.wyn.core.data.AspectChoice
import io.wyn.wyn.core.data.Audience
import io.wyn.wyn.core.data.MAX_POLL_OPTIONS
import io.wyn.wyn.core.data.MAX_POST_IMAGES
import io.wyn.wyn.core.data.PickedImage
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.Wyn
import io.wyn.wyn.core.design.WynAvatar
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.feature.auth.text
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

private val DangerRed = Color(0xFFDC2626)

/** The web's Beta4 composer, as a full-height sheet. */
@Composable
fun ComposerScreen(vm: ComposerViewModel) {
    val c = Wyn.colors
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    fun accept(uris: List<Uri>) {
        if (uris.isEmpty()) return
        scope.launch {
            val picked = mutableListOf<PickedImage>()
            for (uri in uris) {
                try {
                    picked += withContext(Dispatchers.IO) { PhotoReader.read(context, uri) }
                } catch (e: PhotoRejected) {
                    vm.rejectPhoto(e.reason)
                    return@launch
                }
            }
            vm.addImages(picked)
        }
    }
    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(MAX_POST_IMAGES)) { accept(it) }
    var cameraUri by rememberSaveable { mutableStateOf<String?>(null) }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { saved ->
        val uri = cameraUri?.let(Uri::parse)
        if (saved && uri != null) accept(listOf(uri))
    }
    BackHandler { if (vm.closePrompt) vm.dismissClosePrompt() else vm.requestClose() }

    Box(Modifier.fillMaxSize().background(Color(0x5C0A0A0A))) {
        Column(
            Modifier.fillMaxSize().statusBarsPadding().padding(top = 36.dp)
                .clip(RoundedCornerShape(topStart = 26.dp, topEnd = 26.dp)).background(c.bg).imePadding(),
        ) {
            Box(Modifier.fillMaxWidth().padding(top = 10.dp).clickable(onClickLabel = stringResource(R.string.close)) { vm.requestClose() }, contentAlignment = Alignment.Center) {
                Box(Modifier.size(38.dp, 5.dp).clip(RoundedCornerShape(999.dp)).background(c.border))
            }
            Header(vm)
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 18.dp)) {
                Row {
                    WynAvatar(vm.identity?.avatarUrl, 44, modifier = Modifier.padding(top = 6.dp))
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) {
                        Text(
                            vm.identity?.displayName?.trim()?.takeIf { it.isNotEmpty() } ?: vm.identity?.username ?: "WYNOS",
                            color = c.text, fontSize = 16.sp, fontWeight = FontWeight.Bold,
                        )
                        CaptionField(vm)
                        vm.uploadProgress?.let { (done, total) -> UploadProgress(done, total) }
                        if (vm.mode == ComposeMode.Image) Photos(vm) else PollEditor(vm)
                        ErrorText(vm.error.text() ?: vm.serverError)
                        when (vm.autosaveStatus) {
                            AutosaveStatus.Saving -> DraftStatus(stringResource(R.string.draft_saving), false)
                            AutosaveStatus.Saved -> DraftStatus(stringResource(R.string.draft_saved), false)
                            AutosaveStatus.Error -> DraftStatus(stringResource(R.string.draft_save_failed), true)
                            AutosaveStatus.Idle -> Unit
                        }
                    }
                }
            }
            QuickActions(
                vm,
                onGallery = { gallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
                onCamera = {
                    val uri = newCameraUri(context)
                    cameraUri = uri.toString()
                    camera.launch(uri)
                },
            )
        }
        if (vm.audienceOpen) AudienceSheet(vm)
        if (vm.closePrompt) ClosePrompt(vm)
    }
}

/** A private cache file for the camera, shared only with the camera app for this one capture. */
internal fun newCameraUri(context: Context): Uri {
    val dir = File(context.cacheDir, "camera").apply { mkdirs() }
    val file = File.createTempFile("capture", ".jpg", dir)
    return FileProvider.getUriForFile(context, "${context.packageName}.files", file)
}

@Composable
private fun Header(vm: ComposerViewModel) {
    val c = Wyn.colors
    Box(Modifier.fillMaxWidth().height(76.dp).padding(horizontal = 20.dp)) {
        Text(
            stringResource(R.string.cancel), color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.align(Alignment.CenterStart).heightIn(min = 44.dp).clickable(role = Role.Button) { vm.requestClose() }.padding(vertical = 12.dp),
        )
        Text(
            stringResource(R.string.drafts_title), color = c.text, fontSize = 17.sp, fontWeight = FontWeight.ExtraBold,
            modifier = Modifier.align(Alignment.Center).clickable(role = Role.Button) { vm.requestClose(toDrafts = true) }.padding(12.dp),
        )
        val enabled = vm.canPublish
        Box(
            Modifier.align(Alignment.CenterEnd).widthIn(min = 74.dp).height(42.dp).clip(RoundedCornerShape(999.dp))
                .background(if (enabled) c.text else c.border)
                .clickable(enabled = enabled, role = Role.Button, onClick = vm::publish).padding(horizontal = 19.dp),
            contentAlignment = Alignment.Center,
        ) {
            if (vm.busy) {
                CircularProgressIndicator(color = c.bg, strokeWidth = 2.dp, modifier = Modifier.size(16.dp))
            } else {
                Text(stringResource(R.string.publish), color = if (enabled) c.bg else c.textMuted, fontSize = 16.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun CaptionField(vm: ComposerViewModel) {
    val c = Wyn.colors
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
    val placeholder = stringResource(if (vm.mode == ComposeMode.Poll) R.string.poll_question_placeholder else R.string.compose_placeholder)
    BasicTextField(
        value = vm.caption,
        onValueChange = vm::updateCaption,
        enabled = !vm.busy,
        textStyle = TextStyle(color = c.text, fontSize = 16.sp, lineHeight = 22.sp),
        cursorBrush = SolidColor(c.text),
        modifier = Modifier.fillMaxWidth().padding(top = 2.dp).heightIn(min = 28.dp, max = 168.dp).focusRequester(focus)
            .semantics { contentDescription = placeholder },
        decorationBox = { inner ->
            Box {
                if (vm.caption.isEmpty()) Text(placeholder, color = c.textMuted, fontSize = 16.sp, lineHeight = 22.sp)
                inner()
            }
        },
    )
}

@Composable
private fun UploadProgress(done: Int, total: Int) {
    val c = Wyn.colors
    Column(Modifier.padding(top = 8.dp)) {
        Text(stringResource(R.string.uploading_photos, done, total, done * 100 / total), color = c.textSecondary, fontSize = 13.sp)
        Box(Modifier.padding(top = 5.dp).fillMaxWidth().height(3.dp).background(c.border)) {
            Box(Modifier.fillMaxWidth(done.toFloat() / total).height(3.dp).background(c.text))
        }
    }
}

private fun AspectChoice.ratio(): Float = when (this) {
    AspectChoice.Square -> 1f
    AspectChoice.Wide -> 16f / 9f
    AspectChoice.Portrait, AspectChoice.Original -> 4f / 5f
}

@Composable
private fun Photos(vm: ComposerViewModel) {
    val c = Wyn.colors
    if (vm.images.isEmpty() && vm.existingImageUrl == null) return
    Column(Modifier.padding(top = 10.dp)) {
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            vm.existingImageUrl?.takeIf { vm.images.isEmpty() }?.let { url ->
                item(key = "existing") {
                    PhotoTile(Modifier.fillParentMaxWidth(), vm.aspect, stringResource(R.string.remove_draft_photo), vm::removeExistingImage) {
                        AsyncImage(model = url, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                    }
                }
            }
            itemsIndexed(vm.images, key = { index, image -> "${image.hashCode()}:$index" }) { index, image ->
                val bitmap = remember(image) {
                    android.graphics.BitmapFactory.decodeByteArray(image.bytes, 0, image.bytes.size, android.graphics.BitmapFactory.Options().apply { inSampleSize = 4 })?.asImageBitmap()
                }
                PhotoTile(Modifier.fillParentMaxWidth(), vm.aspect, stringResource(R.string.remove_photo, index + 1), { vm.removeImage(index) }) {
                    if (bitmap != null) {
                        Image(bitmap, contentDescription = null, contentScale = if (vm.aspect == AspectChoice.Original) ContentScale.Fit else ContentScale.Crop, modifier = Modifier.fillMaxSize())
                    }
                }
            }
        }
        Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            AspectChoice.entries.forEach { choice ->
                val active = vm.aspect == choice
                Box(
                    Modifier.heightIn(min = 34.dp).clip(RoundedCornerShape(999.dp))
                        .border(BorderStroke(1.dp, if (active) c.text else c.border), RoundedCornerShape(999.dp))
                        .clickable(role = Role.RadioButton) { vm.chooseAspect(choice) }.padding(horizontal = 12.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        if (choice == AspectChoice.Original) stringResource(R.string.aspect_original) else choice.value,
                        color = if (active) c.text else c.textSecondary, fontSize = 13.sp,
                        fontWeight = if (active) FontWeight.SemiBold else FontWeight.Normal,
                    )
                }
            }
        }
        Text("${vm.images.size}/$MAX_POST_IMAGES", color = c.textSecondary, fontSize = 13.sp, modifier = Modifier.padding(top = 6.dp))
    }
}

@Composable
private fun PhotoTile(modifier: Modifier, aspect: AspectChoice, removeLabel: String, onRemove: () -> Unit, content: @Composable () -> Unit) {
    val c = Wyn.colors
    Box(modifier.aspectRatio(aspect.ratio()).clip(RoundedCornerShape(16.dp)).background(c.surface)) {
        content()
        Box(
            Modifier.align(Alignment.TopEnd).padding(8.dp).size(28.dp).clip(CircleShape).background(Color(0xCC000000))
                .clickable(role = Role.Button, onClick = onRemove).semantics { contentDescription = removeLabel },
            contentAlignment = Alignment.Center,
        ) { Icon(WynIcons.Close, contentDescription = null, tint = Color.White, modifier = Modifier.size(13.dp)) }
    }
}

@Composable
private fun PollEditor(vm: ComposerViewModel) {
    val c = Wyn.colors
    Column(Modifier.padding(top = 10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        vm.pollOptions.forEachIndexed { index, value ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).clip(RoundedCornerShape(12.dp)).border(1.dp, c.border, RoundedCornerShape(12.dp)).padding(start = 12.dp),
            ) {
                val placeholder = stringResource(R.string.poll_option_placeholder, index + 1)
                BasicTextField(
                    value = value, onValueChange = { vm.updatePollOption(index, it) }, singleLine = true, enabled = !vm.busy,
                    textStyle = TextStyle(color = c.text, fontSize = 16.sp), cursorBrush = SolidColor(c.text),
                    modifier = Modifier.weight(1f).semantics { contentDescription = placeholder },
                    decorationBox = { inner -> Box { if (value.isEmpty()) Text(placeholder, color = c.textMuted, fontSize = 16.sp); inner() } },
                )
                if (index >= 2) {
                    val remove = stringResource(R.string.remove_poll_option, index + 1)
                    Box(Modifier.size(40.dp, 46.dp).clickable { vm.removePollOption(index) }.semantics { contentDescription = remove }, contentAlignment = Alignment.Center) {
                        Icon(WynIcons.Close, contentDescription = null, tint = c.textSecondary, modifier = Modifier.size(18.dp))
                    }
                } else {
                    Spacer(Modifier.width(12.dp))
                }
            }
        }
        if (vm.pollOptions.size < MAX_POLL_OPTIONS) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.clickable(enabled = !vm.busy, role = Role.Button, onClick = vm::addPollOption).padding(vertical = 8.dp),
            ) {
                Icon(WynIcons.Plus, contentDescription = null, tint = c.text, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(stringResource(R.string.add_poll_option), color = c.text, fontSize = 15.sp)
            }
        }
    }
}

@Composable
private fun DraftStatus(text: String, failed: Boolean) {
    Text(text, color = if (failed) DangerRed else Wyn.colors.textSecondary, fontSize = 13.sp, modifier = Modifier.padding(top = 8.dp))
}

@Composable
private fun QuickActions(vm: ComposerViewModel, onGallery: () -> Unit, onCamera: () -> Unit) {
    val photosFull = vm.mode == ComposeMode.Poll || vm.images.size >= MAX_POST_IMAGES
    val audienceIcon = when (vm.audience) {
        Audience.Everyone -> WynIcons.Globe
        Audience.Friends -> WynIcons.Users
        Audience.OnlyMe -> WynIcons.LockKeyhole
    }
    Row(
        Modifier.fillMaxWidth().background(Wyn.colors.bg).navigationBarsPadding().padding(start = 16.dp, end = 16.dp, top = 10.dp, bottom = 14.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        QuickAction(audienceIcon, stringResource(audienceLabel(vm.audience)), !vm.busy, false, stringResource(R.string.choose_audience)) { vm.openAudience(true) }
        QuickAction(WynIcons.ImagePlus, stringResource(R.string.add_photos), !vm.busy && !photosFull, false, null, onGallery)
        QuickAction(WynIcons.Camera, stringResource(R.string.take_photo), !vm.busy && !photosFull, false, null, onCamera)
        QuickAction(WynIcons.PollBold, stringResource(R.string.add_poll), !vm.busy, vm.mode == ComposeMode.Poll, null, vm::toggleMode)
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.QuickAction(
    icon: ImageVector, label: String, enabled: Boolean, active: Boolean, description: String?, onClick: () -> Unit,
) {
    val c = Wyn.colors
    Column(
        Modifier.weight(1f).heightIn(min = 96.dp).alpha(if (enabled) 1f else 0.35f).clip(RoundedCornerShape(20.dp))
            .border(if (active) 1.5.dp else 1.dp, if (active) c.text else c.border, RoundedCornerShape(20.dp)).background(c.bg)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .semantics { if (description != null) contentDescription = description }
            .padding(start = 6.dp, end = 6.dp, top = 12.dp, bottom = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(icon, contentDescription = null, tint = c.text, modifier = Modifier.size(25.dp))
        Spacer(Modifier.height(8.dp))
        Text(label, color = c.text, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

private fun audienceLabel(value: Audience) = when (value) {
    Audience.Everyone -> R.string.audience_everyone
    Audience.Friends -> R.string.audience_friends
    Audience.OnlyMe -> R.string.audience_only_me
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AudienceSheet(vm: ComposerViewModel) {
    val c = Wyn.colors
    ModalBottomSheet(
        onDismissRequest = { vm.openAudience(false) }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = c.bg, shape = RoundedCornerShape(topStart = 26.dp, topEnd = 26.dp),
        dragHandle = { Box(Modifier.padding(top = 9.dp, bottom = 10.dp).size(34.dp, 4.dp).clip(RoundedCornerShape(999.dp)).background(c.border)) },
    ) {
        Column(Modifier.padding(start = 18.dp, end = 18.dp, bottom = 18.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().heightIn(min = 44.dp)) {
                Text(stringResource(R.string.audience_title), color = c.text, fontSize = 18.sp, fontWeight = FontWeight.ExtraBold, modifier = Modifier.weight(1f))
                Box(Modifier.size(38.dp).clip(CircleShape).background(c.surface).clickable { vm.openAudience(false) }, contentAlignment = Alignment.Center) {
                    Icon(WynIcons.Close, contentDescription = stringResource(R.string.close), tint = c.text, modifier = Modifier.size(20.dp))
                }
            }
            Spacer(Modifier.height(8.dp))
            listOf(
                Triple(Audience.Everyone, WynIcons.Globe, R.string.audience_everyone_desc),
                Triple(Audience.Friends, WynIcons.Users, R.string.audience_friends_desc),
                Triple(Audience.OnlyMe, WynIcons.LockKeyhole, R.string.audience_only_me_desc),
            ).forEach { (value, icon, description) ->
                val selected = vm.audience == value
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 68.dp).clip(RoundedCornerShape(16.dp))
                        .background(if (selected) c.surface else c.bg).clickable(role = Role.RadioButton) { vm.chooseAudience(value) }.padding(12.dp),
                ) {
                    Box(Modifier.size(42.dp).clip(CircleShape).background(c.surface), contentAlignment = Alignment.Center) {
                        Icon(icon, contentDescription = null, tint = c.text, modifier = Modifier.size(21.dp))
                    }
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(stringResource(audienceLabel(value)), color = c.text, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                        Text(stringResource(description), color = c.textSecondary, fontSize = 13.sp)
                    }
                    Box(
                        Modifier.size(22.dp).clip(CircleShape).then(if (selected) Modifier.background(c.text) else Modifier.border(1.5.dp, c.borderStrong, CircleShape)),
                        contentAlignment = Alignment.Center,
                    ) { if (selected) Icon(WynIcons.Check, contentDescription = null, tint = c.bg, modifier = Modifier.size(14.dp)) }
                }
            }
        }
    }
}

@Composable
private fun ClosePrompt(vm: ComposerViewModel) {
    val c = Wyn.colors
    AlertDialog(
        onDismissRequest = vm::dismissClosePrompt,
        containerColor = c.bg,
        title = { Text(stringResource(R.string.save_draft_prompt), color = c.text, fontSize = 17.sp, fontWeight = FontWeight.Bold) },
        text = vm.draftError?.let { { ErrorText(it.text()) } },
        confirmButton = {
            TextButton(onClick = vm::saveDraftAndClose, enabled = !vm.savingDraft) {
                Text(stringResource(R.string.save_draft), color = c.text, fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            Row {
                TextButton(onClick = vm::discard, enabled = !vm.savingDraft) { Text(stringResource(R.string.discard), color = Color(0xFFB42318)) }
                TextButton(onClick = vm::dismissClosePrompt, enabled = !vm.savingDraft) { Text(stringResource(R.string.cancel), color = c.textSecondary) }
            }
        },
    )
}
