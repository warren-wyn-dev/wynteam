package io.wyn.wyn.feature.profile

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.net.Uri
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.exifinterface.media.ExifInterface
import io.wyn.wyn.R
import io.wyn.wyn.core.design.ErrorText
import io.wyn.wyn.core.design.Wyn
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import kotlin.math.roundToInt

/** web profile-photo-cropper.tsx geometry: offsets are in viewport widths, the image covers the square at zoom 1. */
object CropMath {
    const val OUTPUT_SIZE = 512
    const val MIN_ZOOM = 1f
    const val MAX_ZOOM = 4f
    const val MAX_PIXELS = 50_000_000L

    fun base(width: Int, height: Int): Pair<Float, Float> =
        maxOf(1f, width.toFloat() / height) to maxOf(1f, height.toFloat() / width)

    fun clampZoom(value: Float) = value.coerceIn(MIN_ZOOM, MAX_ZOOM)

    fun clampOffset(offset: Offset, zoom: Float, width: Int, height: Int): Offset {
        val (bw, bh) = base(width, height)
        val mx = (bw * zoom - 1) / 2
        val my = (bh * zoom - 1) / 2
        return Offset(offset.x.coerceIn(-mx, mx), offset.y.coerceIn(-my, my))
    }

    /** The square [OUTPUT_SIZE] JPEG (quality 90, white behind), like the web's canvas.toBlob. */
    fun render(source: Bitmap, zoom: Float, offset: Offset): ByteArray {
        val size = OUTPUT_SIZE.toFloat()
        val (bw, bh) = base(source.width, source.height)
        val drawW = bw * zoom * size
        val drawH = bh * zoom * size
        val left = (size - drawW) / 2 + offset.x * size
        val top = (size - drawH) / 2 + offset.y * size
        val out = Bitmap.createBitmap(OUTPUT_SIZE, OUTPUT_SIZE, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(out)
        canvas.drawColor(android.graphics.Color.WHITE)
        canvas.drawBitmap(source, null, RectF(left, top, left + drawW, top + drawH), Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG))
        return ByteArrayOutputStream().use { stream ->
            out.compress(Bitmap.CompressFormat.JPEG, 90, stream)
            out.recycle()
            stream.toByteArray()
        }
    }

    /** Decodes a local photo for cropping only: downsampled, upright, never uploaded as-is. */
    fun load(context: Context, uri: Uri): Bitmap? {
        val resolver = context.contentResolver
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        if (bounds.outWidth.toLong() * bounds.outHeight > MAX_PIXELS) return null
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= 2048) sample *= 2
        val bitmap = resolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
        } ?: return null
        val degrees = runCatching { resolver.openInputStream(uri)?.use { ExifInterface(it).rotationDegrees } ?: 0 }.getOrDefault(0)
        if (degrees == 0) return bitmap
        val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, Matrix().apply { postRotate(degrees.toFloat()) }, true)
        if (rotated != bitmap) bitmap.recycle()
        return rotated
    }
}

/** web ProfilePhotoCropper: drag and pinch inside the circle, zoom slider, reset. */
@Composable
fun PhotoCropper(uri: Uri, onCancel: () -> Unit, onConfirm: suspend (ByteArray) -> Unit, preloaded: Bitmap? = null) {
    val c = Wyn.colors
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var source by remember(uri) { mutableStateOf(preloaded) }
    var loadFailed by remember(uri) { mutableStateOf(false) }
    var zoom by remember(uri) { mutableFloatStateOf(1f) }
    var offset by remember(uri) { mutableStateOf(Offset.Zero) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<Int?>(null) }
    LaunchedEffect(uri) {
        if (source != null) return@LaunchedEffect
        val loaded = withContext(Dispatchers.IO) { runCatching { CropMath.load(context, uri) }.getOrNull() }
        if (loaded == null) loadFailed = true else source = loaded
    }
    androidx.activity.compose.BackHandler(enabled = !busy, onBack = onCancel)
    Column(
        Modifier.fillMaxSize().background(c.bg).statusBarsPadding().padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(stringResource(R.string.crop_title), color = c.text, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Text(stringResource(R.string.crop_hint), color = c.textSecondary, fontSize = 13.sp, textAlign = TextAlign.Center)
        val bitmap = source
        val label = stringResource(R.string.crop_viewport)
        Box(
            Modifier.widthIn(max = 340.dp).fillMaxWidth().aspectRatio(1f).clip(RoundedCornerShape(16.dp)).background(Color(0xFF111111))
                .semantics { contentDescription = label }
                .pointerInput(bitmap, busy) {
                    if (bitmap == null || busy) return@pointerInput
                    detectTransformGestures { _, pan, zoomChange, _ ->
                        val side = size.width.toFloat().coerceAtLeast(1f)
                        val next = CropMath.clampZoom(zoom * zoomChange)
                        zoom = next
                        offset = CropMath.clampOffset(offset + Offset(pan.x / side, pan.y / side), next, bitmap.width, bitmap.height)
                    }
                }
                .pointerInput(bitmap, busy) {
                    if (bitmap == null || busy) return@pointerInput
                    detectTapGestures(onDoubleTap = {
                        val next = if (zoom > 1f) 1f else 2f
                        zoom = next
                        offset = CropMath.clampOffset(offset, next, bitmap.width, bitmap.height)
                    })
                },
            contentAlignment = Alignment.Center,
        ) {
            if (bitmap == null) {
                Text(stringResource(if (loadFailed) R.string.crop_load_failed else R.string.crop_loading), color = Color.White, fontSize = 13.sp, textAlign = TextAlign.Center, modifier = Modifier.padding(16.dp))
            } else {
                val image = remember(bitmap) { bitmap.asImageBitmap() }
                Canvas(Modifier.fillMaxSize().graphicsLayer(compositingStrategy = CompositingStrategy.Offscreen)) {
                    val side = size.width
                    val (bw, bh) = CropMath.base(bitmap.width, bitmap.height)
                    val drawW = bw * zoom * side
                    val drawH = bh * zoom * side
                    drawImage(
                        image,
                        dstOffset = IntOffset(((side - drawW) / 2 + offset.x * side).roundToInt(), ((side - drawH) / 2 + offset.y * side).roundToInt()),
                        dstSize = IntSize(drawW.roundToInt(), drawH.roundToInt()),
                    )
                    // Dim outside the circle that becomes the profile photo.
                    drawRect(Color.Black.copy(alpha = 0.45f))
                    drawCircle(Color.Transparent, radius = side / 2, blendMode = BlendMode.Clear)
                    drawImage(
                        image,
                        dstOffset = IntOffset(((side - drawW) / 2 + offset.x * side).roundToInt(), ((side - drawH) / 2 + offset.y * side).roundToInt()),
                        dstSize = IntSize(drawW.roundToInt(), drawH.roundToInt()),
                        blendMode = BlendMode.DstOver,
                    )
                    drawCircle(Color.White.copy(alpha = 0.9f), radius = side / 2 - 1f, style = Stroke(2f))
                }
            }
        }
        Row(Modifier.widthIn(max = 340.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text("−", color = c.textSecondary, fontSize = 18.sp)
            Slider(
                value = zoom, onValueChange = { value ->
                    val b = bitmap ?: return@Slider
                    zoom = CropMath.clampZoom(value)
                    offset = CropMath.clampOffset(offset, zoom, b.width, b.height)
                },
                valueRange = CropMath.MIN_ZOOM..CropMath.MAX_ZOOM, enabled = bitmap != null && !busy,
                colors = SliderDefaults.colors(thumbColor = c.text, activeTrackColor = c.text, inactiveTrackColor = c.border),
                modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
            )
            Text("+", color = c.textSecondary, fontSize = 18.sp)
            PillButton(stringResource(R.string.crop_reset), filled = false, enabled = bitmap != null && !busy, height = 34.dp, fontSize = 13, modifier = Modifier.padding(start = 10.dp)) {
                zoom = 1f
                offset = Offset.Zero
            }
        }
        error?.let { ErrorText(stringResource(it)) }
        Row(Modifier.widthIn(max = 340.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            PillButton(stringResource(R.string.cancel), filled = false, outlined = true, enabled = !busy, modifier = Modifier.weight(1f), onClick = onCancel)
            PillButton(stringResource(if (busy) R.string.saving else R.string.crop_use), filled = true, enabled = bitmap != null && !busy, modifier = Modifier.weight(1f)) {
                val b = bitmap ?: return@PillButton
                busy = true
                error = null
                scope.launch {
                    try {
                        val bytes = withContext(Dispatchers.Default) { CropMath.render(b, zoom, offset) }
                        onConfirm(bytes)
                    } catch (e: kotlin.coroutines.cancellation.CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        error = R.string.crop_failed
                    } finally {
                        busy = false
                    }
                }
            }
        }
    }
}

