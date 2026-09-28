package io.wyn.wyn.core.data

/** web WyniiRow: the pet two people raise in their conversation. */
data class WyniiPet(
    val conversationId: String,
    val userAId: String,
    val userBId: String,
    val ageDays: Int,
    val cycleStartedAt: String? = null,
    val userADone: Boolean = false,
    val userBDone: Boolean = false,
    val nextCycleAt: String,
    val lastCompletedAt: String? = null,
)

enum class WyniiStage { Egg, Hatching, Baby, Growing, Mature, Max }

/** web wyniiStage(). */
fun wyniiStage(ageDays: Int): WyniiStage = when {
    ageDays <= 0 -> WyniiStage.Egg
    ageDays <= 6 -> WyniiStage.Hatching
    ageDays <= 29 -> WyniiStage.Baby
    ageDays <= 99 -> WyniiStage.Growing
    ageDays <= 364 -> WyniiStage.Mature
    else -> WyniiStage.Max
}

/** web wyniiNextMilestone(): null once MAX. */
fun wyniiNextMilestone(ageDays: Int): Int? = when {
    ageDays < 1 -> 1
    ageDays < 7 -> 7
    ageDays < 30 -> 30
    ageDays < 100 -> 100
    ageDays < 365 -> 365
    else -> null
}

/** web progressFor(): percent of the way from the last milestone to the next. */
fun wyniiProgress(ageDays: Int, next: Int?): Float {
    if (next == null) return 100f
    val previous = when (next) { 1 -> 0; 7 -> 1; 30 -> 7; 100 -> 30; else -> 100 }
    val span = maxOf(1, next - previous)
    return (((ageDays - previous).toFloat() / span) * 100f).coerceIn(0f, 100f)
}

/** What the pill and sheet say (web statusFor()). */
sealed interface WyniiStatus {
    val mineDone: Boolean
    val otherDone: Boolean
    /** The last round was not finished within 24 hours. */
    data object Resting : WyniiStatus { override val mineDone = false; override val otherDone = false }
    data object WaitingForOther : WyniiStatus { override val mineDone = true; override val otherDone = false }
    data object YourTurn : WyniiStatus { override val mineDone = false; override val otherDone = true }
    data class InRound(val ageDays: Int, override val mineDone: Boolean, override val otherDone: Boolean) : WyniiStatus
    data object DoneToday : WyniiStatus { override val mineDone = true; override val otherDone = true }
    data class Idle(val ageDays: Int) : WyniiStatus { override val mineDone = false; override val otherDone = false }
}

private const val DAY_MS = 24 * 60 * 60 * 1000L

fun wyniiStatus(pet: WyniiPet, userId: String, nowMs: Long): WyniiStatus {
    val mineIsA = userId == pet.userAId
    val mineDone = if (mineIsA) pet.userADone else pet.userBDone
    val otherDone = if (mineIsA) pet.userBDone else pet.userADone
    val started = pet.cycleStartedAt?.let(::instantMillis)
    val expired = started != null && nowMs > started + DAY_MS
    val nextCycle = instantMillis(pet.nextCycleAt)
    if (expired) return WyniiStatus.Resting
    if (started != null) {
        if (mineDone && !otherDone) return WyniiStatus.WaitingForOther
        if (!mineDone && otherDone) return WyniiStatus.YourTurn
        return WyniiStatus.InRound(pet.ageDays, mineDone, otherDone)
    }
    if (pet.lastCompletedAt != null && nowMs < nextCycle) return WyniiStatus.DoneToday
    return WyniiStatus.Idle(pet.ageDays)
}
