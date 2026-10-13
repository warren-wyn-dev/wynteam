package online.wynos.food.data

import android.net.Uri
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import online.wynos.food.BuildConfig

/** Mirrors the signed-out website's public food_active_home_banners response. */
data class FoodHomeBanner(
    val id: String,
    val title: String,
    val subtitle: String?,
    val imagePath: String,
    val destinationStoreId: String?,
)

object FoodHomeBannerParser {
    fun parse(raw: String): List<FoodHomeBanner> = parse(Json.parseToJsonElement(raw))

    fun parse(raw: JsonElement): List<FoodHomeBanner> =
        (raw as? JsonArray)?.mapNotNull { item ->
            val o = item as? JsonObject ?: return@mapNotNull null
            fun text(name: String) = (o[name] as? JsonPrimitive)?.contentOrNull
            val id = text("id")?.takeIf { it.isNotBlank() } ?: return@mapNotNull null
            val image = text("image_path")?.takeIf { it.isNotBlank() } ?: return@mapNotNull null
            FoodHomeBanner(id, text("title").orEmpty(), text("subtitle"), image, text("destination_store_id"))
        } ?: emptyList()
}

/** Only generates public storage object URLs; never signed/private paths. */
object FoodPublicMedia {
    private val buckets = setOf("food-public", "food-banners")

    fun url(bucket: String, path: String?): String? {
        val base = BuildConfig.SUPABASE_URL.removeSuffix("/")
        if (bucket !in buckets || !base.startsWith("https://") || path.isNullOrBlank()) return null
        val segments = path.split("/")
        if (segments.any { it.isBlank() || it == "." || it == ".." }) return null
        return "$base/storage/v1/object/public/$bucket/" + segments.joinToString("/") { Uri.encode(it) }
    }
}
