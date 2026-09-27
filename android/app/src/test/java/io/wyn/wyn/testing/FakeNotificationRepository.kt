package io.wyn.wyn.testing

import io.wyn.wyn.core.data.NotificationItem
import io.wyn.wyn.core.data.NotificationPrefs
import io.wyn.wyn.core.data.NotificationRepository
import io.wyn.wyn.core.data.PushTokenRepository
import io.wyn.wyn.core.push.DeviceToken
import java.time.Instant

class FakeNotificationRepository(var items: List<NotificationItem> = NotificationFixture.rows) : NotificationRepository {
    var prefs = NotificationPrefs()
    var failReads = false
    var failWrites = false
    var unread = 3
    val marked = mutableListOf<String?>()
    val writes = mutableListOf<String>()

    override suspend fun page(page: Int): List<NotificationItem> {
        if (failReads) error("offline")
        return items.drop(page * 30).take(30)
    }
    override suspend fun unreadCount(userId: String): Int { if (failReads) error("offline"); return unread }
    override suspend fun markAllRead(userId: String, newestSeenAt: String?) {
        if (failWrites) error("write failed")
        marked += newestSeenAt
        unread = 0
    }
    override suspend fun prefs(): NotificationPrefs { if (failReads) error("offline"); return prefs }
    override suspend fun setPref(userId: String, key: String, value: Boolean) {
        if (failWrites) error("write failed")
        writes += "$key:$value"
        prefs = prefs.with(key, value)
    }
}

class FakePushTokens : PushTokenRepository {
    val registered = mutableMapOf<String, String>() // token -> user
    var fail = false
    override suspend fun register(userId: String, token: String) { if (fail) error("offline"); registered[token] = userId }
    override suspend fun unregister(token: String) { if (fail) error("offline"); registered.remove(token) }
    override suspend fun isRegistered(userId: String, token: String): Boolean { if (fail) error("offline"); return registered[token] == userId }
}

class FakeDeviceToken(var value: String? = "device-token-1", override var configured: Boolean = true) : DeviceToken {
    var deleted = 0
    override suspend fun token() = value
    override suspend fun delete() { deleted++ }
}

object NotificationFixture {
    private fun ago(minutes: Long) = Instant.now().minusSeconds(minutes * 60).toString()
    private fun daysAgo(days: Long) = Instant.now().minusSeconds(days * 86_400 + 3_600).toString()
    const val DROP = "d1000000-0000-4000-8000-000000000001"
    val rows = listOf(
        NotificationItem("n1", "like_drop", ago(5), actorId = "a1", actorUsername = "mint", actorDisplayName = "mint", dropId = DROP, contentPreview = "WYNOS เริ่มจากคำถามง่าย ๆ ว่า..."),
        NotificationItem("n2", "like_drop", ago(20), actorId = "a2", actorUsername = "sky_blue", actorDisplayName = "Sky", dropId = DROP),
        NotificationItem("n3", "like_drop", ago(30), actorId = "a3", actorUsername = "techdaily", actorDisplayName = "TechDaily", dropId = DROP),
        NotificationItem("n4", "follow", ago(60), actorId = "a2", actorUsername = "sky_blue", actorDisplayName = "Sky"),
        NotificationItem("n5", "comment_drop", ago(180), isRead = true, actorId = "a3", actorUsername = "techdaily", actorDisplayName = "TechDaily", dropId = DROP, contentPreview = "เช้านี้กาแฟดีมาก ☕"),
        NotificationItem("n6", "redrop", daysAgo(1), isRead = true, actorId = "a4", actorUsername = "warren", actorDisplayName = "WARREN", dropId = DROP),
        NotificationItem("n7", "mention_drop", daysAgo(1), isRead = true, actorId = "a1", actorUsername = "mint", actorDisplayName = "mint", dropId = DROP),
        NotificationItem("n8", "system", daysAgo(5), isRead = true, reason = "ยินดีต้อนรับสู่ WYNOS Beta 1"),
    )
}
