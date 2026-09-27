package io.wyn.wyn.testing

import io.wyn.wyn.core.data.AspectChoice
import io.wyn.wyn.core.data.Audience
import io.wyn.wyn.core.data.ComposerRepository
import io.wyn.wyn.core.data.Draft
import io.wyn.wyn.core.data.DraftInput
import io.wyn.wyn.core.data.PickedImage
import io.wyn.wyn.core.data.PublicationStateUnknownException
import java.io.IOException

/** In-memory publishing and drafts; [nextPublish] scripts how the next publish ends. */
class FakeComposerRepository : ComposerRepository {
    enum class Outcome { Ok, Unknown, Network, Rejected }

    val published = mutableListOf<String>()
    val operationIds = mutableListOf<String>()
    val drafts = linkedMapOf<String, Draft>()
    val deletedDrafts = mutableListOf<String>()
    var nextPublish = Outcome.Ok
    var draftSaves = 0
    private var ids = 0

    override suspend fun publishDrop(
        userId: String, caption: String, images: List<PickedImage>, operationId: String, audience: Audience, aspect: AspectChoice, onUploaded: (Int, Int) -> Unit,
    ): String {
        operationIds += operationId
        images.indices.forEach { onUploaded(it + 1, images.size) }
        when (nextPublish.also { nextPublish = Outcome.Ok }) {
            Outcome.Unknown -> throw PublicationStateUnknownException(operationId)
            Outcome.Network -> throw IOException("reset")
            Outcome.Rejected -> error("rejected")
            Outcome.Ok -> Unit
        }
        published += "drop:${caption.trim()}:${images.size}:${audience.value}:${aspect.value}"
        return "drop-${published.size}"
    }

    override suspend fun publishPoll(caption: String, options: List<String>, audience: Audience) {
        if (nextPublish == Outcome.Network) { nextPublish = Outcome.Ok; throw IOException("reset") }
        published += "poll:${caption.trim()}:${options.joinToString("|") { it.trim() }}:${audience.value}"
    }

    override suspend fun fetchDrafts(userId: String) = drafts.values.toList().asReversed()
    override suspend fun fetchDraft(draftId: String) = drafts[draftId]

    override suspend fun saveDraft(userId: String, input: DraftInput): String {
        draftSaves++
        val id = input.draftId ?: "draft-${++ids}"
        drafts[id] = Draft(
            id, input.image?.let { "https://storage.example/drop-images/$userId/drafts/$id.${it.extension}" } ?: input.existingImageUrl,
            input.caption.trim().ifEmpty { null }, input.pollOptions?.takeIf { it.isNotEmpty() }, input.pollDurationDays, "2026-09-27T10:00:00Z",
        )
        return id
    }

    override suspend fun deleteDraft(draftId: String) {
        deletedDrafts += draftId
        drafts.remove(draftId)
    }

    override suspend fun loadDraftImage(userId: String, imageUrl: String) = PickedImage(byteArrayOf(9), "image/jpeg", "jpg", 1200, 1500)
}
