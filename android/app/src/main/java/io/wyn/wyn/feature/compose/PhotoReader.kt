package io.wyn.wyn.feature.compose

import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.OpenableColumns
import androidx.exifinterface.media.ExifInterface
import io.wyn.wyn.R
import io.wyn.wyn.core.data.IMAGE_MAX_BYTES
import io.wyn.wyn.core.data.ImageRules
import io.wyn.wyn.core.data.PickedImage
import java.io.File

/** A photo the composer cannot use, with the web's message. */
class PhotoRejected(val reason: Int) : Exception()

/**
 * Reads a picked or captured photo the way the web's imageUploadType() +
 * imageDimensions() do: allowed image types only, 20MB at most, the stored
 * extension from the real type, and the displayed size (EXIF rotation
 * applied). GPS location is removed from JPEG metadata before upload.
 */
object PhotoReader {
    fun read(context: Context, uri: Uri): PickedImage {
        val resolver = context.contentResolver
        var name: String? = null
        var size: Long? = null
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                name = cursor.getString(0)
                if (!cursor.isNull(1)) size = cursor.getLong(1)
            }
        }
        if (size != null && (size!! <= 0 || size!! > IMAGE_MAX_BYTES)) throw PhotoRejected(R.string.photo_too_large)
        val (contentType, extension) = ImageRules.uploadType(resolver.getType(uri), name) ?: throw PhotoRejected(R.string.photo_wrong_type)
        val bytes = resolver.openInputStream(uri)?.use { input ->
            val buffer = input.readBytes()
            if (buffer.size > IMAGE_MAX_BYTES) throw PhotoRejected(R.string.photo_too_large)
            buffer
        } ?: throw PhotoRejected(R.string.photo_wrong_type)
        val cleaned = if (contentType == "image/jpeg") stripLocation(context, bytes) else bytes
        return describe(cleaned, contentType, extension)
    }

    /** Pixel size as displayed; an undecodable header falls back to 1×1 like the web. */
    fun describe(bytes: ByteArray, contentType: String, extension: String = ImageRules.uploadType(contentType, null)?.second ?: "jpg"): PickedImage {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
        var width = options.outWidth.takeIf { it > 0 } ?: 1
        var height = options.outHeight.takeIf { it > 0 } ?: 1
        val rotated = runCatching {
            ExifInterface(bytes.inputStream()).rotationDegrees.let { it == 90 || it == 270 }
        }.getOrDefault(false)
        if (rotated) width = height.also { height = width }
        return PickedImage(bytes, contentType, extension, width, height)
    }

    private val locationTags = listOf(
        ExifInterface.TAG_GPS_LATITUDE, ExifInterface.TAG_GPS_LATITUDE_REF, ExifInterface.TAG_GPS_LONGITUDE,
        ExifInterface.TAG_GPS_LONGITUDE_REF, ExifInterface.TAG_GPS_ALTITUDE, ExifInterface.TAG_GPS_ALTITUDE_REF,
        ExifInterface.TAG_GPS_TIMESTAMP, ExifInterface.TAG_GPS_DATESTAMP, ExifInterface.TAG_GPS_PROCESSING_METHOD,
        ExifInterface.TAG_GPS_AREA_INFORMATION, ExifInterface.TAG_GPS_DEST_LATITUDE, ExifInterface.TAG_GPS_DEST_LONGITUDE,
        ExifInterface.TAG_GPS_IMG_DIRECTION, ExifInterface.TAG_GPS_SPEED, ExifInterface.TAG_GPS_TRACK,
    )

    /** Posts are public: never publish where a photo was taken. Pixels are untouched. */
    private fun stripLocation(context: Context, bytes: ByteArray): ByteArray {
        val temp = File.createTempFile("wynos-upload", ".jpg", context.cacheDir)
        return try {
            temp.writeBytes(bytes)
            val exif = ExifInterface(temp)
            if (exif.latLong == null && locationTags.all { exif.getAttribute(it) == null }) return bytes
            locationTags.forEach { exif.setAttribute(it, null) }
            exif.saveAttributes()
            temp.readBytes()
        } catch (e: Exception) {
            // If the metadata cannot be rewritten safely, refuse rather than leak a location.
            throw PhotoRejected(R.string.photo_wrong_type)
        } finally {
            temp.delete()
        }
    }
}
