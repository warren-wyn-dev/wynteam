package io.wyn.wyn.feature.chat

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.wyn.wyn.R
import io.wyn.wyn.core.data.ChatRepository
import io.wyn.wyn.core.data.WyniiPet
import io.wyn.wyn.core.data.WyniiStage
import io.wyn.wyn.core.data.WyniiStatus
import io.wyn.wyn.core.data.wyniiNextMilestone
import io.wyn.wyn.core.data.wyniiProgress
import io.wyn.wyn.core.data.wyniiStage
import io.wyn.wyn.core.data.wyniiStatus
import io.wyn.wyn.core.design.WynIcons
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.feature.auth.text
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

/** web WyniiConversationHeader state: the pet, starting one, and the sheet. */
class WyniiViewModel(private val repo: ChatRepository, val userId: String, val conversationId: String) : ViewModel() {
    var pet by mutableStateOf<WyniiPet?>(null); private set
    var loaded by mutableStateOf(false); private set
    var starting by mutableStateOf(false); private set
    var sheetOpen by mutableStateOf(false); private set
    var error by mutableStateOf<UiText?>(null); private set

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            try {
                pet = repo.wynii(conversationId)
                error = null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.wynii_load_failed)
            } finally {
                loaded = true
            }
        }
    }

    fun openSheet(open: Boolean) { sheetOpen = open }

    /** Only an accepted conversation can start one (web canStart). */
    fun begin(canStart: Boolean) {
        if (!canStart || starting) return
        starting = true
        error = null
        viewModelScope.launch {
            try {
                pet = repo.startWynii(conversationId)
                sheetOpen = true
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.wynii_start_failed)
            } finally {
                starting = false
            }
        }
    }
}

@Composable
private fun rememberNow(): Long {
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(60_000)
            now = System.currentTimeMillis()
        }
    }
    return now
}

@Composable
fun wyniiShort(status: WyniiStatus): String = when (status) {
    WyniiStatus.Resting -> stringResource(R.string.wynii_resting)
    WyniiStatus.WaitingForOther -> stringResource(R.string.wynii_waiting_other)
    WyniiStatus.YourTurn -> stringResource(R.string.wynii_your_turn)
    WyniiStatus.DoneToday -> stringResource(R.string.wynii_done_today)
    is WyniiStatus.InRound -> stringResource(R.string.wynii_days, status.ageDays)
    is WyniiStatus.Idle -> stringResource(R.string.wynii_days, status.ageDays)
}

@Composable
private fun wyniiDetail(status: WyniiStatus): String = stringResource(
    when (status) {
        WyniiStatus.Resting -> R.string.wynii_resting_detail
        WyniiStatus.WaitingForOther -> R.string.wynii_waiting_other_detail
        WyniiStatus.YourTurn -> R.string.wynii_your_turn_detail
        WyniiStatus.DoneToday -> R.string.wynii_done_today_detail
        is WyniiStatus.InRound -> R.string.wynii_in_round_detail
        is WyniiStatus.Idle -> R.string.wynii_idle_detail
    },
)

@Composable
private fun stageLabel(stage: WyniiStage): String = stringResource(
    when (stage) {
        WyniiStage.Egg -> R.string.wynii_stage_egg
        WyniiStage.Hatching -> R.string.wynii_stage_hatching
        WyniiStage.Baby -> R.string.wynii_stage_baby
        WyniiStage.Growing -> R.string.wynii_stage_growing
        WyniiStage.Mature -> R.string.wynii_stage_mature
        WyniiStage.Max -> R.string.wynii_stage_max
    },
)

/** The "Wynii 12 วัน" pill beside @username (web styles.pill). */
@Composable
fun WyniiPill(vm: WyniiViewModel) {
    val pet = vm.pet ?: return
    val status = wyniiStatus(pet, vm.userId, rememberNow())
    val short = wyniiShort(status)
    val label = "Wynii $short"
    Row(
        Modifier.height(24.dp).widthIn(max = 154.dp).clip(RoundedCornerShape(999.dp)).border(1.dp, Color(0xFFECECF2), RoundedCornerShape(999.dp))
            .background(Color(0xFFF7F7FA)).clickable(role = Role.Button, onClickLabel = label) { vm.openSheet(true) }
            .semantics { contentDescription = label }.padding(start = 6.dp, end = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        WyniiGlyph(wyniiStage(pet.ageDays), Modifier.size(17.dp))
        Text(label, color = Color(0xFF73758A), fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** web "Wynii ของเรา" sheet: the pet, this round, growth, and the rule; or the egg and a start button. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WyniiSheet(vm: WyniiViewModel, otherName: String, canStart: Boolean) {
    if (!vm.sheetOpen) return
    val ink = Color(0xFF111111)
    val grey = Color(0xFF858585)
    ModalBottomSheet(
        onDismissRequest = { vm.openSheet(false) },
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = Color.White,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        dragHandle = null,
    ) {
        Column(Modifier.verticalScroll(rememberScrollState()).padding(start = 18.dp, end = 18.dp, top = 16.dp, bottom = 24.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.wynii_sheet_title), color = ink, fontSize = 18.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                val close = stringResource(R.string.close)
                Box(
                    Modifier.size(36.dp).clip(CircleShape).background(Color(0xFFF3F3F3)).clickable(role = Role.Button, onClickLabel = close) { vm.openSheet(false) }
                        .semantics { contentDescription = close },
                    contentAlignment = Alignment.Center,
                ) { Icon(WynIcons.Close, contentDescription = null, tint = ink, modifier = Modifier.size(19.dp)) }
            }
            val pet = vm.pet
            if (pet == null) {
                Hero(WyniiStage.Egg, stringResource(R.string.wynii_start_title), stringResource(R.string.wynii_start_body))
                vm.error?.let { Rule(it.text().orEmpty()) }
                val enabled = canStart && !vm.starting
                Box(
                    Modifier.padding(top = 14.dp).fillMaxWidth().heightIn(min = 48.dp).clip(RoundedCornerShape(999.dp)).background(ink.copy(alpha = if (enabled) 1f else 0.5f))
                        .clickable(enabled = enabled, role = Role.Button) { vm.begin(canStart) },
                    contentAlignment = Alignment.Center,
                ) { Text(stringResource(if (vm.starting) R.string.wynii_starting else R.string.wynii_start), color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold) }
                return@Column
            }
            val stage = wyniiStage(pet.ageDays)
            val status = wyniiStatus(pet, vm.userId, rememberNow())
            val next = wyniiNextMilestone(pet.ageDays)
            Hero(stage, stringResource(R.string.wynii_days, pet.ageDays), stageLabel(stage) + if (stage == WyniiStage.Max) stringResource(R.string.wynii_max_suffix) else "")
            Column(
                Modifier.padding(top = 12.dp).fillMaxWidth().clip(RoundedCornerShape(18.dp)).border(1.dp, Color(0xFFEDEDED), RoundedCornerShape(18.dp))
                    .background(Color(0xFFFAFAFA)).padding(horizontal = 15.dp, vertical = 14.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(wyniiShort(status), color = ink, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                    Text(wyniiDetail(status), color = Color(0xFF777777), fontSize = 13.sp, textAlign = TextAlign.End, modifier = Modifier.weight(1f))
                }
                Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Member(stringResource(R.string.club_chat_you), status.mineDone, Modifier.weight(1f))
                    Member(otherName, status.otherDone, Modifier.weight(1f))
                }
                Row(Modifier.padding(top = 14.dp)) {
                    Text(stageLabel(stage), color = Color(0xFF777777), fontSize = 12.sp, modifier = Modifier.weight(1f))
                    Text(
                        if (next == null) "MAX" else stringResource(R.string.wynii_days_left, maxOf(0, next - pet.ageDays)),
                        color = Color(0xFF777777), fontSize = 12.sp,
                    )
                }
                Box(Modifier.padding(top = 7.dp).fillMaxWidth().height(7.dp).clip(RoundedCornerShape(999.dp)).background(Color(0xFFEFEFF2))) {
                    Box(
                        Modifier.fillMaxHeight().fillMaxWidth(wyniiProgress(pet.ageDays, next) / 100f).clip(RoundedCornerShape(999.dp))
                            .background(Brush.horizontalGradient(listOf(Color(0xFFA99CE7), Color(0xFF8FB9FF), Color(0xFFB8A4ED)))),
                    )
                }
            }
            Rule(stringResource(R.string.wynii_rule))
            vm.error?.let { Rule(it.text().orEmpty()) }
        }
    }
}

@Composable
private fun Hero(stage: WyniiStage, title: String, subtitle: String) {
    Column(Modifier.fillMaxWidth().padding(top = 18.dp, bottom = 10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        WyniiGlyph(stage, Modifier.size(164.dp))
        Text(title, color = Color(0xFF111111), fontSize = 26.sp, lineHeight = 29.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 4.dp, bottom = 2.dp))
        Text(subtitle, color = Color(0xFF858585), fontSize = 14.sp, textAlign = TextAlign.Center)
    }
}

@Composable
private fun Member(name: String, done: Boolean, modifier: Modifier) {
    Row(
        modifier.heightIn(min = 42.dp).clip(RoundedCornerShape(12.dp)).background(Color.White).padding(horizontal = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(name, color = Color(0xFF333333), fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        Spacer(Modifier.size(8.dp))
        Text(
            stringResource(if (done) R.string.wynii_sent else R.string.wynii_wait), fontSize = 13.sp,
            color = if (done) Color(0xFF1E8D54) else Color(0xFF999999), fontWeight = if (done) FontWeight.Bold else FontWeight.Normal,
        )
    }
}

@Composable
private fun Rule(text: String) {
    Text(text, color = Color(0xFF858585), fontSize = 12.sp, lineHeight = 18.6.sp, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(start = 2.dp, end = 2.dp, top = 14.dp))
}

// ---- The pet, drawn from the web's SVG (WyniiGlyph) --------------------------------

private val parsed = HashMap<String, androidx.compose.ui.graphics.Path>()
private fun path(d: String) = parsed.getOrPut(d) { PathParser().parsePathString(d).toPath() }

private fun DrawScope.fill(d: String, brush: Brush, alpha: Float = 1f) = drawPath(path(d), brush, alpha = alpha)
private fun DrawScope.line(d: String, color: Color, width: Float) =
    drawPath(path(d), color, style = Stroke(width, cap = StrokeCap.Round, join = StrokeJoin.Round))

private fun ellipse(cx: Float, cy: Float, rx: Float, ry: Float) = "M${cx - rx} ${cy}a$rx $ry 0 1 0 ${2 * rx} 0a$rx $ry 0 1 0 ${-2 * rx} 0Z"

/** web WyniiGlyph: an egg (cracked while hatching), then the creature growing with its stage. */
@Composable
fun WyniiGlyph(stage: WyniiStage, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        if (stage == WyniiStage.Egg || stage == WyniiStage.Hatching) {
            scale(size.width / 64f, size.height / 64f, pivot = Offset.Zero) { drawEgg(stage == WyniiStage.Hatching) }
        } else {
            scale(size.width / 180f, size.height / 180f, pivot = Offset.Zero) { drawCreature(stage) }
        }
    }
}

private fun DrawScope.drawEgg(hatching: Boolean) {
    val shell = "M32 5C19 5 10 24 10 39c0 12 9 20 22 20s22-8 22-20C54 24 45 5 32 5Z"
    fill(shell, Brush.linearGradient(0f to Color.White, 0.48f to Color(0xFFECE9FF), 1f to Color(0xFFB9D7FF), start = Offset(8f, 6f), end = Offset(56f, 58f)))
    drawPath(path(shell), Color(0xFFD8D5E7), style = Stroke(2f))
    if (hatching) line("m15 32 8-5 6 6 7-9 6 8 8-4", Color(0xFFA89BD0), 2f)
    fill(
        "M32 24c-4-6-13-2-11 5 1 5 7 9 11 12 4-3 10-7 11-12 2-7-7-11-11-5Z",
        Brush.linearGradient(listOf(Color(0xFFCAB9FF), Color(0xFF83C8FF)), start = Offset(22f, 22f), end = Offset(43f, 43f)), alpha = 0.96f,
    )
    drawCircle(Color.White.copy(alpha = 0.85f), radius = 3f, center = Offset(32f, 31f))
}

private fun DrawScope.drawCreature(stage: WyniiStage) {
    val grown = stage == WyniiStage.Growing || stage == WyniiStage.Mature || stage == WyniiStage.Max
    val mature = stage == WyniiStage.Mature || stage == WyniiStage.Max
    val max = stage == WyniiStage.Max
    val body = Brush.radialGradient(0f to Color.White, 0.65f to Color(0xFFFBFBFF), 1f to Color(0xFFE9ECFF), center = Offset(90f, 83f), radius = 80f)
    val glow = Brush.linearGradient(0f to Color(0xFFC5AEF9), 0.5f to Color(0xFF91C9FF), 1f to Color(0xFFC4A9EF), start = Offset(52f, 52f), end = Offset(132f, 142f))
    fun eye(cx: Float) = Brush.radialGradient(0f to Color(0xFFD6C8FF), 0.42f to Color(0xFF6E78D8), 1f to Color(0xFF25244A), center = Offset(cx, 83.5f), radius = 19f)
    if (grown) {
        fill(
            if (mature) "M139 111c23 1 31 21 18 34-10 10-25 1-29-8 6 3 16 2 18-5 2-7-5-13-14-13Z" else "M138 116c17 3 23 17 13 27-8 8-19 1-22-6 5 2 11 1 13-4 2-5-3-9-10-10Z",
            glow, alpha = if (max) 1f else 0.78f,
        )
    }
    for (ear in listOf("M55 55 30 33c-4-4-10 0-8 6l11 34Z", "m125 55 25-22c4-4 10 0 8 6l-11 34Z")) {
        fill(ear, body)
        drawPath(path(ear), Color(0xFFDDDFF0), style = Stroke(2f))
    }
    if (mature) {
        fill("M48 56 31 43l7 25Z", glow, alpha = 0.72f)
        fill("m132 56 17-13-7 25Z", glow, alpha = 0.72f)
    }
    val bodyShape = ellipse(90f, 96f, if (grown) 58f else 53f, if (grown) 61f else 56f)
    fill(bodyShape, body)
    drawPath(path(bodyShape), Color(0xFFE0E1EF), style = Stroke(2f))
    if (max) fill("M75 42c6-12 24-12 30 0-7-3-10 1-15 7-5-6-8-10-15-7Z", glow, alpha = 0.9f)
    drawOval(eye(68f), topLeft = Offset(56f, 73f), size = Size(24f, 30f))
    drawOval(eye(112f), topLeft = Offset(100f, 73f), size = Size(24f, 30f))
    drawCircle(Color.White, radius = 4f, center = Offset(64f, 82f))
    drawCircle(Color.White, radius = 4f, center = Offset(108f, 82f))
    line("M86 103c2 2 6 2 8 0", Color(0xFF77718B), 2.4f)
    line("M90 105c0 6-5 9-10 8m10-8c0 6 5 9 10 8", Color(0xFF77718B), 2f)
    fill("M90 119c-7-10-21-5-18 6 2 8 11 14 18 19 7-5 16-11 18-19 3-11-11-16-18-6Z", glow)
    fill("M90 124c-3-4-9-2-8 3 1 4 5 7 8 9 3-2 7-5 8-9 1-5-5-7-8-3Z", Brush.linearGradient(listOf(Color.White, Color.White)), alpha = 0.78f)
    if (max) {
        drawCircle(glow, radius = 3f, center = Offset(30f, 92f))
        drawCircle(glow, radius = 2.5f, center = Offset(151f, 82f))
        drawCircle(glow, radius = 2f, center = Offset(138f, 38f))
    }
}
