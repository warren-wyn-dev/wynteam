package io.wyn.wyn.core.design

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp

private val badgePath = PathParser().parsePathString(
    "M256 37 C268 37 278 54 312 86 L369 76 C386 73 393 82 395 99 L402 150 L455 176 C470 183 469 194 460 211 L436 254 L464 306 " +
        "C473 325 465 332 456 335 L402 360 L394 419 C393 433 383 438 369 435 L312 425 L269 469 C261 477 251 478 244 470 L201 425 " +
        "L143 435 C130 436 122 433 119 418 L112 360 L57 334 C44 327 43 318 50 305 L77 255 L48 203 C41 190 44 184 57 177 L110 151 " +
        "L119 95 C121 79 129 74 143 76 L201 86 L237 49 C244 41 249 37 256 37 Z",
).toPath()
private val checkPath = PathParser().parsePathString("M150 267 L214 326 L337 204").toPath()

/** web /verified-badge-v2.svg: the gold rosette with a white check. */
@Composable
fun VerifiedBadge(size: Int, modifier: Modifier = Modifier, label: String? = null) {
    Canvas(modifier.size(size.dp).semantics { if (label != null) contentDescription = label }) {
        val scale = this.size.width / 445f
        withTransform({ scale(scale, scale, Offset.Zero); translate(-34f, -34f) }) {
            val brush = Brush.linearGradient(
                0f to Color(0xFFFFE82A), 0.35f to Color(0xFFFFCF26), 0.65f to Color(0xFFFFA12E), 1f to Color(0xFFFF7045),
                start = Offset(34f, 34f + 445f * 0.3f), end = Offset(479f, 34f + 445f * 0.65f),
            )
            drawPath(badgePath, brush)
            drawPath(checkPath, Color.White, style = Stroke(width = 38f, cap = StrokeCap.Round, join = StrokeJoin.Round))
        }
    }
}
