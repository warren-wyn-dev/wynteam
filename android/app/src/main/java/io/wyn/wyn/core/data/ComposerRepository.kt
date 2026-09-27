package io.wyn.wyn.core.data

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.exceptions.RestException
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.storage.storage
import io.ktor.http.ContentType
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import java.io.IOException
import java.time.Instant
import java.util.UUID
import kotlin.coroutines.cancellation.CancellationException

const val MAX_POST_IMAGES = 9
const val MAX_CAPTION = 500
const val MAX_POLL_OPTIONS = 4
const val MAX_POLL_OPTION_LENGTH = 80
/** Flutter's default and the web's fixed value: the design has no duration picker. */
const val POLL_DURATION_DAYS = 1
const val IMAGE_MAX_BYTES = 20 * 1024 * 1024

enum class Audience(val value: String) { Everyone("everyone"), Friends("friends"), OnlyMe("only_me") }
enum class AspectChoice(val value: String) { Original("original"), Square("1:1"), Portrait("4:5"), Wide("16:9") }

/** A photo ready to upload: validated bytes, type, and pixel size (web imageUploadType + imageDimensions). */
data class PickedImage(val bytes: ByteArray, val contentType: String, val extension: String, val width: Int, val height: Int) {
    override fun equals(other: Any?) = other is PickedImage && bytes.contentEquals(other.bytes)
    override fun hashCode() = bytes.contentHashCode()
}

data class Draft(
    val id: String,
    val imageUrl: String?,
    val caption: String?,
    val pollOptions: List<String>?,
    val pollDurationDays: Int?,
    val updatedAt: String,
)

data class DraftInput(
    val draftId: String?,
    val image: PickedImage?,
    val existingImageUrl: String?,
    val caption: String,
    val pollOptions: List<String>?,
    val pollDurationDays: Int?,
)

/** The server may or may not have created the post; retry only with the same content (web DropPublicationStateUnknownError). */
class PublicationStateUnknownException(val operationId: String) : Exception()

/** Composer writes, mirroring web/lib/drop-publication.ts and web/lib/drafts.ts exactly. */
interface ComposerRepository {
    suspend fun publishDrop(
        userId: String,
        caption: String,
        images: List<PickedImage>,
        operationId: String,
        audience: Audience,
        aspect: AspectChoice,
        onUploaded: (Int, Int) -> Unit = { _, _ -> },
    ): String

    suspend fun publishPoll(caption: String, options: List<String>, audience: Audience)
    suspend fun fetchDrafts(userId: String): List<Draft>
    suspend fun fetchDraft(draftId: String): Draft?
    suspend fun saveDraft(userId: String, input: DraftInput): String
    suspend fun deleteDraft(draftId: String)
    suspend fun loadDraftImage(userId: String, imageUrl: String): PickedImage
}

private const val BUCKET = "drop-images"

class SupabaseComposerRepository(
    private val clientOrNull: SupabaseClient?,
    /** Reads pixel size and type from downloaded draft bytes (platform decoder). */
    private val describe: (ByteArray, String) -> PickedImage,
) : ComposerRepository {
    private val client: SupabaseClient get() = clientOrNull ?: throw NotConfiguredException()

    override suspend fun publishDrop(
        userId: String,
        caption: String,
        images: List<PickedImage>,
        operationId: String,
        audience: Audience,
        aspect: AspectChoice,
        onUploaded: (Int, Int) -> Unit,
    ): String {
        val text = caption.trim()
        val files = images.take(MAX_POST_IMAGES)
        require(text.isNotEmpty() || files.isNotEmpty())
        require(text.length <= MAX_CAPTION)
        val bucket = client.storage.from(BUCKET)
        val uploaded = mutableListOf<String>()
        val metadata = buildJsonArray {
            onUploaded(0, files.size)
            try {
                files.forEachIndexed { index, image ->
                    // Deterministic per publication: a retry reuses the same objects instead of duplicating them.
                    val path = "$userId/publications/$operationId/$index.${image.extension}"
                    try {
                        bucket.upload(path, image.bytes) {
                            upsert = false
                            contentType = ContentType.parse(image.contentType)
                        }
                        uploaded += path
                    } catch (e: RestException) {
                        if (!isConflict(e)) throw e
                    }
                    add(
                        buildJsonObject {
                            put("image_url", bucket.publicUrl(path))
                            put("position", index)
                            put("image_width", image.width)
                            put("image_height", image.height)
                        },
                    )
                    onUploaded(index + 1, files.size)
                }
            } catch (e: CancellationException) {
                removeBestEffort(uploaded)
                throw e
            } catch (e: Exception) {
                removeBestEffort(uploaded)
                throw e
            }
        }
        val primary = metadata.firstOrNull() as? JsonObject
        val params = buildJsonObject {
            put("p_operation_id", operationId)
            put("p_image_url", primary?.get("image_url") ?: JsonNull)
            put("p_caption", text.ifEmpty { null })
            put("p_audience", audience.value)
            putJsonArray("p_excluded_friend_ids") {}
            put("p_images", metadata)
            putJsonArray("p_mentioned_user_ids") {}
            put("p_location", null as String?)
            put("p_location_lat", null as Double?)
            put("p_location_lon", null as Double?)
            put("p_location_place_id", null as String?)
            put("p_image_width", primary?.get("image_width") ?: JsonNull)
            put("p_image_height", primary?.get("image_height") ?: JsonNull)
            put("p_image_aspect_ratio", aspect.value)
        }
        return try {
            client.postgrest.rpc("publish_drop", params).decodeAs<String>()
        } catch (e: CancellationException) {
            throw e
        } catch (e: IOException) {
            // The request may have reached the server: ask which post this operation created.
            reconcile(operationId, uploaded, e)
        } catch (e: Exception) {
            removeBestEffort(uploaded)
            throw e
        }
    }

    private suspend fun reconcile(operationId: String, uploaded: List<String>, original: Exception): String {
        val result = try {
            client.postgrest.rpc("drop_id_for_publication", buildJsonObject { put("p_operation_id", operationId) })
                .decodeAs<kotlinx.serialization.json.JsonElement>()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            throw PublicationStateUnknownException(operationId)
        }
        val id = (result as? JsonPrimitive)?.takeIf { it.isString }?.content
        if (id != null) return id
        removeBestEffort(uploaded)
        throw original
    }

    private suspend fun removeBestEffort(paths: List<String>) {
        if (paths.isEmpty()) return
        runCatching { client.storage.from(BUCKET).delete(paths) }.onFailure { if (it is CancellationException) throw it }
    }

    private fun isConflict(e: RestException) =
        e.statusCode == 409 || e.message.orEmpty().contains("already exists", ignoreCase = true) || e.error.contains("Duplicate", ignoreCase = true)

    override suspend fun publishPoll(caption: String, options: List<String>, audience: Audience) {
        client.postgrest.rpc(
            "create_poll_drop",
            buildJsonObject {
                put("p_caption", caption.trim())
                putJsonArray("p_options") { options.forEach { add(JsonPrimitive(it.trim())) } }
                put("p_duration_days", POLL_DURATION_DAYS)
                putJsonArray("p_mentioned_user_ids") {}
                put("p_audience", audience.value)
                putJsonArray("p_excluded_friend_ids") {}
                put("p_location", null as String?)
                put("p_location_lat", null as Double?)
                put("p_location_lon", null as Double?)
                put("p_location_place_id", null as String?)
            },
        )
    }

    override suspend fun fetchDrafts(userId: String): List<Draft> =
        client.from("drop_drafts").select(Columns.list("id", "image_url", "caption", "poll_options", "poll_duration_days", "updated_at")) {
            filter { eq("author_id", userId) }
            order("updated_at", Order.DESCENDING)
        }.decodeList<JsonObject>().map(::parseDraft)

    override suspend fun fetchDraft(draftId: String): Draft? =
        client.from("drop_drafts").select(Columns.list("id", "image_url", "caption", "poll_options", "poll_duration_days", "updated_at")) {
            filter { eq("id", draftId) }
        }.decodeList<JsonObject>().firstOrNull()?.let(::parseDraft)

    /** Insert when new, update in place otherwise; one image per draft (drop_drafts.image_url), like web and Flutter. */
    override suspend fun saveDraft(userId: String, input: DraftInput): String {
        val id = input.draftId ?: UUID.randomUUID().toString()
        var imageUrl = input.existingImageUrl
        input.image?.let { image ->
            val path = "$userId/drafts/$id.${image.extension}"
            val bucket = client.storage.from(BUCKET)
            bucket.upload(path, image.bytes) {
                upsert = true
                contentType = ContentType.parse(image.contentType)
            }
            imageUrl = "${bucket.publicUrl(path)}?v=${UUID.randomUUID()}"
        }
        val row = buildJsonObject {
            put("author_id", userId)
            put("image_url", imageUrl)
            put("caption", input.caption.trim().ifEmpty { null })
            if (input.pollOptions.isNullOrEmpty()) {
                put("poll_options", null as String?)
            } else {
                putJsonArray("poll_options") { input.pollOptions.forEach { add(JsonPrimitive(it)) } }
            }
            put("poll_duration_days", input.pollDurationDays)
            put("updated_at", Instant.now().toString())
        }
        return if (input.draftId != null) {
            client.from("drop_drafts").update(row) {
                filter { eq("id", id) }
                select(Columns.list("id"))
            }.decodeSingle<JsonObject>().text("id") ?: id
        } else {
            client.from("drop_drafts").insert(JsonObject(row + ("id" to JsonPrimitive(id)))) {
                select(Columns.list("id"))
            }.decodeSingle<JsonObject>().text("id") ?: id
        }
    }

    override suspend fun deleteDraft(draftId: String) {
        client.from("drop_drafts").delete { filter { eq("id", draftId) } }
    }

    /** Only ever reads from this account's own drafts folder (web loadDraftImageFile). */
    override suspend fun loadDraftImage(userId: String, imageUrl: String): PickedImage {
        val bucket = client.storage.from(BUCKET)
        val name = DraftPaths.ownDraftFileName(bucket.publicUrl("$userId/drafts/"), imageUrl)
            ?: throw IllegalArgumentException("draft image outside this account")
        val bytes = bucket.downloadAuthenticated("$userId/drafts/$name")
        val ext = name.substringAfterLast('.').lowercase()
        return describe(bytes, ImageRules.typeForExtension(ext) ?: "image/jpeg")
    }

    private fun parseDraft(row: JsonObject): Draft = Draft(
        id = row.text("id").orEmpty(),
        imageUrl = row.text("image_url"),
        caption = row.text("caption"),
        pollOptions = (row["poll_options"] as? kotlinx.serialization.json.JsonArray)?.mapNotNull { (it as? JsonPrimitive)?.content },
        pollDurationDays = row.int("poll_duration_days"),
        updatedAt = row.text("updated_at").orEmpty(),
    )
}

/** web imageUploadType(): allowed types, size limit, and the stored extension (never trusted from the file name). */
object ImageRules {
    private val extensionByType = mapOf(
        "image/jpeg" to "jpg", "image/png" to "png", "image/webp" to "webp", "image/gif" to "gif",
        "image/heic" to "heic", "image/heif" to "heif", "image/avif" to "avif",
    )
    private val typeByExtension = mapOf(
        "jpg" to "image/jpeg", "jpeg" to "image/jpeg", "png" to "image/png", "webp" to "image/webp",
        "gif" to "image/gif", "heic" to "image/heic", "heif" to "image/heif", "avif" to "image/avif",
    )

    fun typeForExtension(extension: String): String? = typeByExtension[extension.lowercase()]

    /** Null when the type is not an allowed image; the size check is separate. */
    fun uploadType(mimeType: String?, fileName: String?): Pair<String, String>? {
        val nameExtension = fileName?.substringAfterLast('.', "")?.lowercase().orEmpty()
        val contentType = when {
            mimeType != null && mimeType in extensionByType -> mimeType
            mimeType.isNullOrEmpty() -> typeByExtension[nameExtension]
            else -> null
        } ?: return null
        val extension = if (typeByExtension[nameExtension] == contentType) nameExtension else extensionByType.getValue(contentType)
        return contentType to extension
    }
}

object DraftPaths {
    private val safeName = Regex("^[A-Za-z0-9_-]+\\.(?:jpe?g|png|webp|gif|heic|heif)$", RegexOption.IGNORE_CASE)

    /** The file name inside [folderUrl] when [imageUrl] points there and is a plain draft name; otherwise null. */
    fun ownDraftFileName(folderUrl: String, imageUrl: String): String? {
        val base = runCatching { java.net.URI(folderUrl) }.getOrNull() ?: return null
        val candidate = runCatching { java.net.URI(imageUrl) }.getOrNull() ?: return null
        if (candidate.scheme != base.scheme || candidate.host != base.host || candidate.port != base.port) return null
        val basePath = base.rawPath ?: return null
        val path = candidate.rawPath ?: return null
        if (!path.startsWith(basePath)) return null
        val name = java.net.URLDecoder.decode(path.removePrefix(basePath), "UTF-8")
        return name.takeIf { safeName.matches(it) }
    }
}
