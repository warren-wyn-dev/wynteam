package io.wyn.wyn.testing

import io.wyn.wyn.core.data.AppLanguage
import io.wyn.wyn.core.data.LegalDocument
import io.wyn.wyn.core.data.PasswordChangeException
import io.wyn.wyn.core.data.Person
import io.wyn.wyn.core.data.PrivacyField
import io.wyn.wyn.core.data.PrivacySettings
import io.wyn.wyn.core.data.SettingsRepository
import io.wyn.wyn.core.data.ThemePreference

/** Settings in memory; [fail] makes writes fail so rollbacks can be tested. */
class FakeSettingsRepository : SettingsRepository {
    var privacy = PrivacySettings(dmPermission = "people_i_follow")
    var online = true
    var blocked = mutableListOf(Person("b1", "spam_bot", "Spam Bot", null, isVerified = false, isPrivate = false, following = false, requested = false))
    var muted = mutableListOf<Person>()
    var theme: ThemePreference? = null
    var language: AppLanguage? = null
    var fail = false
    var failReads = false
    var deleted = false
    var password = "current-password-123"
    val writes = mutableListOf<String>()

    private fun check() { if (fail) error("offline") }

    override suspend fun privacy(userId: String) = privacy.also { if (failReads) error("offline") }
    override suspend fun setPrivacy(userId: String, field: PrivacyField, value: Any) { check(); writes += "${field.column}=$value" }
    override suspend fun showOnline(userId: String) = online
    override suspend fun setShowOnline(userId: String, value: Boolean) { check(); online = value }
    override suspend fun blocked(userId: String) = blocked.toList()
    override suspend fun unblock(profileId: String) { check(); blocked.removeAll { it.id == profileId } }
    override suspend fun muted(userId: String) = muted.toList()
    override suspend fun unmute(userId: String, profileId: String) { check(); muted.removeAll { it.id == profileId } }
    override suspend fun exportData() = "{\"profile\":{}}".also { check() }
    override suspend fun deleteAccount() { check(); deleted = true }
    override suspend fun legal(type: String) = LegalDocument(type, "3", "ข้อกำหนดการให้บริการ", "เนื้อหา").also { check() }
    override suspend fun theme(userId: String) = theme.also { if (failReads) error("offline") }
    override suspend fun saveTheme(userId: String, value: ThemePreference) { check(); theme = value }
    override suspend fun language(userId: String) = language.also { if (failReads) error("offline") }
    override suspend fun saveLanguage(userId: String, value: AppLanguage) { check(); language = value }
    override suspend fun changePassword(userId: String, current: String, next: String) {
        check()
        if (current != password) throw PasswordChangeException(PasswordChangeException.Reason.WrongPassword)
        password = next
    }
}
