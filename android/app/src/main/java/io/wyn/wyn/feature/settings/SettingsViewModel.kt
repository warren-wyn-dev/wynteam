package io.wyn.wyn.feature.settings

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.wyn.wyn.R
import io.wyn.wyn.core.data.AppLanguage
import io.wyn.wyn.core.data.DevicePreferences
import io.wyn.wyn.core.data.LegalDocument
import io.wyn.wyn.core.data.PasswordChangeException
import io.wyn.wyn.core.data.PasswordFormError
import io.wyn.wyn.core.data.Person
import io.wyn.wyn.core.data.PrivacyField
import io.wyn.wyn.core.data.PrivacySettings
import io.wyn.wyn.core.data.SettingsRepository
import io.wyn.wyn.core.data.ThemePreference
import io.wyn.wyn.core.data.validatePasswordChange
import io.wyn.wyn.feature.auth.UiText
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.coroutines.cancellation.CancellationException

enum class SettingsSection { Root, Privacy, Account, Password, Theme, Language, Legal }

/** A question the web asks with window.confirm(). */
enum class SettingsConfirm { SignOut, DeleteAccount, DeleteAccountAgain }

/** The theme / language on this phone, and where to save the account's choice. */
interface AppearanceStore {
    val theme: ThemePreference?
    val language: AppLanguage?
    fun applyTheme(value: ThemePreference?)
    /** True when the language shown changes. */
    fun applyLanguage(value: AppLanguage?): Boolean
}

class DeviceAppearance(private val device: DevicePreferences) : AppearanceStore {
    override val theme get() = device.theme
    override val language get() = device.language
    override fun applyTheme(value: ThemePreference?) = device.applyTheme(value)
    override fun applyLanguage(value: AppLanguage?) = device.applyLanguage(value)
}

/** Theme and language kept only in memory (tests, or no device store). */
class InMemoryAppearance(override var theme: ThemePreference? = null, override var language: AppLanguage? = null) : AppearanceStore {
    override fun applyTheme(value: ThemePreference?) { theme = value }
    override fun applyLanguage(value: AppLanguage?): Boolean {
        if (value == language) return false
        language = value
        return true
    }
}

/**
 * web settings-route.tsx: account, privacy, blocked / muted, data export and
 * account deletion, password, theme, language and legal documents.
 * Notifications keep their own screen (M4).
 */
class SettingsViewModel(
    private val repo: SettingsRepository,
    private val appearance: AppearanceStore,
    val userId: String,
    private val deviceLanguage: AppLanguage = DevicePreferences.deviceLanguage(),
) : ViewModel() {
    var section by mutableStateOf(SettingsSection.Root); private set
    var privacy by mutableStateOf<PrivacySettings?>(null); private set
    var online by mutableStateOf(true); private set
    var blocked by mutableStateOf<List<Person>>(emptyList()); private set
    var muted by mutableStateOf<List<Person>>(emptyList()); private set
    var loading by mutableStateOf(true); private set
    var loadFailed by mutableStateOf(false); private set
    var busy by mutableStateOf(false); private set
    var error by mutableStateOf<UiText?>(null); private set
    var confirm by mutableStateOf<SettingsConfirm?>(null); private set
    var document by mutableStateOf<LegalDocument?>(null); private set
    var themeSaveFailed by mutableStateOf(false); private set
    var languageSaveFailed by mutableStateOf(false); private set
    /** Set after the account is deleted; the app then signs out. */
    var deleted by mutableStateOf(false); private set

    // Change password
    var currentPassword by mutableStateOf(""); private set
    var newPassword by mutableStateOf(""); private set
    var confirmPassword by mutableStateOf(""); private set
    var passwordBusy by mutableStateOf(false); private set
    var passwordError by mutableStateOf<UiText?>(null); private set
    var passwordSaved by mutableStateOf(false); private set

    private val saves = Mutex()
    private var loadJob: Job? = null

    init {
        load()
    }

    val theme: ThemePreference get() = appearance.theme ?: ThemePreference.System
    val language: AppLanguage get() = appearance.language ?: deviceLanguage

    fun load() {
        loadJob?.cancel()
        loading = true
        loadFailed = false
        loadJob = viewModelScope.launch {
            try {
                privacy = repo.privacy(userId)
                online = repo.showOnline(userId)
                blocked = repo.blocked(userId)
                muted = repo.muted(userId)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                loadFailed = true
            } finally {
                loading = false
            }
        }
    }

    fun open(next: SettingsSection) {
        error = null
        if (next == SettingsSection.Password) resetPassword()
        section = next
    }

    /** The header's back: Password returns to Account, the rest to the list. Returns false at the list. */
    fun back(): Boolean {
        if (section == SettingsSection.Root) return false
        section = if (section == SettingsSection.Password) SettingsSection.Account else SettingsSection.Root
        return true
    }

    fun ask(value: SettingsConfirm?) { confirm = value }

    // ---- Privacy -----------------------------------------------------------------

    fun setPrivacy(field: PrivacyField, value: Any) {
        val previous = privacy ?: return
        if (busy) return
        privacy = when (field) {
            PrivacyField.IsPrivate -> previous.copy(isPrivate = value as Boolean)
            PrivacyField.Dm -> previous.copy(dmPermission = value as String)
            PrivacyField.Mention -> previous.copy(mentionPermission = value as String)
            PrivacyField.Comment -> previous.copy(commentPermission = value as String)
            PrivacyField.Likes -> previous.copy(likesVisibility = value as String)
        }
        busy = true
        error = null
        viewModelScope.launch {
            try {
                repo.setPrivacy(userId, field, value)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                privacy = previous
                error = UiText(R.string.settings_save_failed)
            } finally {
                busy = false
            }
        }
    }

    fun toggleOnline(value: Boolean) {
        if (busy) return
        val previous = online
        online = value
        busy = true
        viewModelScope.launch {
            try {
                repo.setShowOnline(userId, value)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                online = previous
                error = UiText(R.string.settings_online_failed)
            } finally {
                busy = false
            }
        }
    }

    // ---- Account -----------------------------------------------------------------

    fun unblock(person: Person) {
        viewModelScope.launch {
            try {
                repo.unblock(person.id)
                blocked = blocked.filterNot { it.id == person.id }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.settings_unblock_failed)
            }
        }
    }

    fun unmute(person: Person) {
        viewModelScope.launch {
            try {
                repo.unmute(userId, person.id)
                muted = muted.filterNot { it.id == person.id }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.settings_unmute_failed)
            }
        }
    }

    /** export_my_data; the screen saves the JSON where the person chooses. */
    fun exportData(onReady: (String) -> Unit) {
        if (busy) return
        busy = true
        error = null
        viewModelScope.launch {
            try {
                onReady(repo.exportData())
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.settings_export_failed)
            } finally {
                busy = false
            }
        }
    }

    fun exportSaveFailed() { error = UiText(R.string.settings_export_failed) }

    /** web deleteAccount(): asks twice, then deletes and signs out. */
    fun confirmNow() {
        when (confirm) {
            SettingsConfirm.DeleteAccount -> confirm = SettingsConfirm.DeleteAccountAgain
            SettingsConfirm.DeleteAccountAgain -> { confirm = null; deleteAccount() }
            else -> confirm = null
        }
    }

    private fun deleteAccount() {
        if (busy) return
        busy = true
        error = null
        viewModelScope.launch {
            try {
                repo.deleteAccount()
                deleted = true
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.settings_delete_failed)
                busy = false
            }
        }
    }

    // ---- Legal -------------------------------------------------------------------

    fun openDocument(type: String) {
        if (busy) return
        busy = true
        error = null
        viewModelScope.launch {
            try {
                document = repo.legal(type)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = UiText(R.string.settings_document_failed)
            } finally {
                busy = false
            }
        }
    }

    fun closeDocument() { document = null }

    // ---- Theme and language ---------------------------------------------------------

    /** Applies on this phone at once; saves to the account in order, so quick taps end on the last choice. */
    fun chooseTheme(value: ThemePreference) {
        appearance.applyTheme(value)
        viewModelScope.launch {
            val saved = saves.withLock { runCatching { repo.saveTheme(userId, value) }.isSuccess }
            themeSaveFailed = !saved
        }
    }

    /** Returns true when the screen must be rebuilt in the new language. */
    fun chooseLanguage(value: AppLanguage): Boolean {
        val changed = appearance.applyLanguage(value)
        viewModelScope.launch {
            val saved = saves.withLock { runCatching { repo.saveLanguage(userId, value) }.isSuccess }
            languageSaveFailed = !saved
        }
        return changed
    }

    // ---- Password ----------------------------------------------------------------

    fun updateCurrent(value: String) { currentPassword = value }
    fun updateNew(value: String) { newPassword = value }
    fun updateConfirm(value: String) { confirmPassword = value }

    private fun resetPassword() {
        currentPassword = ""; newPassword = ""; confirmPassword = ""
        passwordError = null
        passwordSaved = false
    }

    fun submitPassword() {
        if (passwordBusy || passwordSaved) return
        passwordError = null
        validatePasswordChange(currentPassword, newPassword, confirmPassword)?.let { problem ->
            passwordError = when (problem) {
                PasswordFormError.Missing -> UiText(R.string.password_missing)
                PasswordFormError.TooShort -> UiText(R.string.password_too_short, listOf(io.wyn.wyn.core.data.MIN_PASSWORD_LENGTH))
                PasswordFormError.Mismatch -> UiText(R.string.password_mismatch)
                PasswordFormError.Same -> UiText(R.string.password_same)
            }
            return
        }
        passwordBusy = true
        viewModelScope.launch {
            try {
                repo.changePassword(userId, currentPassword, newPassword)
                resetPassword()
                passwordSaved = true
            } catch (e: CancellationException) {
                throw e
            } catch (e: PasswordChangeException) {
                passwordError = when (e.reason) {
                    PasswordChangeException.Reason.WrongPassword -> { currentPassword = ""; UiText(R.string.password_wrong) }
                    PasswordChangeException.Reason.AccountChanged -> { resetPassword(); UiText(R.string.password_account_changed) }
                    PasswordChangeException.Reason.NoEmail, PasswordChangeException.Reason.ReauthenticationRequired -> UiText(R.string.password_needs_email)
                    PasswordChangeException.Reason.UpdateFailed -> UiText(R.string.password_failed)
                }
            } catch (e: Exception) {
                passwordError = UiText(R.string.password_network)
            } finally {
                passwordBusy = false
            }
        }
    }
}
