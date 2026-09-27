package io.wyn.wyn.feature.profile

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.wyn.wyn.R
import io.wyn.wyn.core.data.ExternalUrl
import io.wyn.wyn.core.data.Profile
import io.wyn.wyn.core.data.ProfileImage
import io.wyn.wyn.core.data.ProfileRepository
import io.wyn.wyn.core.data.ProfileRuleException
import io.wyn.wyn.feature.auth.UiText
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

const val DISPLAY_NAME_MAX = 50
const val USERNAME_MAX = 30
const val BIO_MAX = 300
const val WEBSITE_MAX = 300

/** A photo ready to upload: already validated (type, size, no location). */
class ProfilePhoto(val bytes: ByteArray, val contentType: String, val extension: String)

/** web EditProfile: photos, name, username, bio and website. */
class EditProfileViewModel(
    private val repo: ProfileRepository,
    val userId: String,
    private val original: Profile,
) : ViewModel() {
    var displayName by mutableStateOf(original.displayName.orEmpty()); private set
    var username by mutableStateOf(original.username); private set
    var bio by mutableStateOf(original.bio.orEmpty()); private set
    var website by mutableStateOf(original.website.orEmpty()); private set
    var avatarUrl by mutableStateOf(original.avatarUrl); private set
    var coverUrl by mutableStateOf(original.coverUrl); private set
    var saving by mutableStateOf(false); private set
    var error by mutableStateOf<UiText?>(null); private set
    var done by mutableStateOf(false); private set
    var photoMenu by mutableStateOf<ProfileImage?>(null); private set
    var confirmRemove by mutableStateOf<ProfileImage?>(null); private set

    fun updateDisplayName(value: String) { displayName = value.take(DISPLAY_NAME_MAX); error = null }

    /** The web's field: no leading @, only letters, digits, "_" and ".". */
    fun updateUsername(value: String) {
        username = value.trimStart('@').filter { it in 'a'..'z' || it in 'A'..'Z' || it in '0'..'9' || it == '_' || it == '.' }.take(USERNAME_MAX)
        error = null
    }

    fun updateBio(value: String) { bio = value.take(BIO_MAX); error = null }
    fun updateWebsite(value: String) { website = value.take(WEBSITE_MAX); error = null }

    fun openPhotoMenu(kind: ProfileImage?) {
        if (saving) return
        photoMenu = kind
    }

    fun showError(value: UiText?) {
        error = value
    }

    fun uploadPhoto(kind: ProfileImage, photo: ProfilePhoto) {
        if (saving) return
        saving = true
        error = null
        viewModelScope.launch {
            try {
                val url = repo.uploadImage(userId, kind, photo.bytes, photo.contentType, photo.extension)
                if (kind == ProfileImage.Avatar) avatarUrl = url else coverUrl = url
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.profile_photo_upload_failed)
            } finally {
                saving = false
            }
        }
    }

    fun askRemove(kind: ProfileImage) {
        photoMenu = null
        if (!saving) confirmRemove = kind
    }

    fun dismissRemove() {
        confirmRemove = null
    }

    fun removePhoto() {
        val kind = confirmRemove ?: return
        confirmRemove = null
        if (saving) return
        saving = true
        error = null
        viewModelScope.launch {
            try {
                repo.removeImage(userId, kind)
                if (kind == ProfileImage.Avatar) avatarUrl = null else coverUrl = null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(if (kind == ProfileImage.Avatar) R.string.profile_avatar_remove_failed else R.string.profile_cover_remove_failed)
            } finally {
                saving = false
            }
        }
    }

    fun save() {
        if (saving) return
        if (displayName.isBlank() && original.displayName == null) {
            error = UiText(R.string.profile_name_required)
            return
        }
        val normalizedWebsite = ExternalUrl.normalize(website)
        if (website.isNotBlank() && normalizedWebsite == null) {
            error = UiText(R.string.profile_website_invalid)
            return
        }
        saving = true
        error = null
        viewModelScope.launch {
            try {
                if (username.trim() != original.username) repo.updateUsername(userId, username)
                val links = original.socialLinks.toMutableMap()
                if (normalizedWebsite != null) links["website"] = normalizedWebsite else links.remove("website")
                repo.updateBasics(userId, displayName, bio, links)
                done = true
            } catch (e: CancellationException) {
                throw e
            } catch (e: ProfileRuleException) {
                error = UiText(R.string.profile_username_taken)
            } catch (e: Exception) {
                error = UiText(R.string.profile_save_failed)
            } finally {
                saving = false
            }
        }
    }
}
