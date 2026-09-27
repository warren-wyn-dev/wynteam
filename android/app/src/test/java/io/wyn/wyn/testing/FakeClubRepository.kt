package io.wyn.wyn.testing

import io.wyn.wyn.core.data.Club
import io.wyn.wyn.core.data.ClubChannel
import io.wyn.wyn.core.data.ClubDetail
import io.wyn.wyn.core.data.ClubEvent
import io.wyn.wyn.core.data.ClubInvitePreview
import io.wyn.wyn.core.data.ClubMember
import io.wyn.wyn.core.data.ClubMembership
import io.wyn.wyn.core.data.ClubMessage
import io.wyn.wyn.core.data.ClubPost
import io.wyn.wyn.core.data.ClubPostPage
import io.wyn.wyn.core.data.ClubRepository
import io.wyn.wyn.core.data.ClubSections
import io.wyn.wyn.core.data.PickedImage
import io.wyn.wyn.core.data.exploreSections
import java.time.Instant
import java.time.temporal.ChronoUnit

object ClubFixture {
    const val ME = "11111111-1111-4111-8111-111111111111"
    const val OTHER = "22222222-2222-4222-8222-222222222222"
    const val CLUB = "c0000000-0000-4000-8000-000000000001"
    const val PRIVATE_CLUB = "c0000000-0000-4000-8000-000000000002"
    const val GENERAL = "ch000000-0000-4000-8000-000000000001"
    const val RANDOM = "ch000000-0000-4000-8000-000000000002"

    private fun ago(hours: Long) = Instant.now().minus(hours, ChronoUnit.HOURS).toString()

    val coffee = Club(
        CLUB, "คนรักกาแฟ", description = "แลกเปลี่ยนร้านกาแฟและวิธีชงที่ชอบ ☕", category = "อาหาร", privacy = "public",
        createdAt = ago(300), memberCount = 1284, rules = "สุภาพต่อกัน\nไม่ขายของ", ownerId = OTHER,
    )
    val runners = Club(PRIVATE_CLUB, "Bangkok Runners", description = "วิ่งเช้าวันเสาร์", category = "กีฬา", privacy = "private", createdAt = ago(40), memberCount = 86)
    val explore = listOf(
        coffee,
        runners,
        Club("c3", "Film Photo TH", category = "ถ่ายภาพ", privacy = "public", createdAt = ago(5), memberCount = 540),
        Club("c4", "นักอ่านยามดึก", privacy = "public", createdAt = ago(2), memberCount = 12),
        Club("c5", "Indie Games", privacy = "public", createdAt = ago(1), memberCount = 3),
    )

    val posts = listOf(
        ClubPost(
            "p1", CLUB, OTHER, "mind_coffee", "มายด์", content = "ร้านใหม่แถวอารีย์ เมล็ดคั่วอ่อนหอมมาก ใครไปแล้วบ้าง?",
            pinned = true, createdAt = ago(3), likeCount = 24, commentCount = 5, myRole = "member",
        ),
        ClubPost(
            "p2", CLUB, "33333333-3333-4333-8333-333333333333", "sky", "Sky", content = "โหวตกันหน่อย ชอบกาแฟแบบไหนที่สุด",
            createdAt = ago(8), likeCount = 9, liked = true, myRole = "member",
            pollId = "poll1", pollOptions = listOf("ดริป", "เอสเปรสโซ", "โคลด์บรูว์"), pollExpiresAt = Instant.now().plus(3, ChronoUnit.DAYS).plusSeconds(3600).toString(),
            pollMyVote = 0, pollTotalVotes = 40, pollOptionCounts = listOf(22, 10, 8),
        ),
        ClubPost(
            "p3", CLUB, ME, "wyn_me", "ฉันเอง", content = "แชร์ลิงก์สูตรโคลด์บรูว์", linkUrl = "https://example.com/cold-brew",
            createdAt = ago(30), likeCount = 0, myRole = "member",
        ),
    )

    val messages = listOf(
        ClubMessage("m1", OTHER, "สวัสดีทุกคน วันนี้ใครว่างไปคาเฟ่บ้าง", null, ago(2), "mind_coffee", "มายด์", null),
        ClubMessage("m2", ME, "ไปด้วย!", null, ago(1), "wyn_me", "ฉันเอง", null),
    )
}

/** In-memory Clubs with the web's rules; tests change the fields to shape each case. */
class FakeClubRepository : ClubRepository {
    val clubs = ClubFixture.explore.associateBy { it.id }.toMutableMap()
    val memberships = mutableMapOf<String, ClubMembership>(ClubFixture.CLUB to ClubMembership("member", "approved"))
    val channels = mutableMapOf(ClubFixture.CLUB to listOf(ClubChannel(ClubFixture.GENERAL, "ทั่วไป"), ClubChannel(ClubFixture.RANDOM, "คุยเล่น")))
    val muted = mutableSetOf<String>()
    var posts = ClubFixture.posts.toMutableList()
    val messages = mutableMapOf(ClubFixture.GENERAL to ClubFixture.messages.toMutableList())
    val reports = mutableListOf<Triple<String, String, String>>()
    val votes = mutableListOf<Pair<String, Int>>()
    val sent = mutableListOf<Triple<String, String?, PickedImage?>>()
    var created: String? = null
    var invite: ClubInvitePreview? = ClubInvitePreview("valid", ClubFixture.CLUB, "คนรักกาแฟ", "public", null)
    var fail = false
    var failJoin = false
    var failLike = false
    var marked = 0

    private fun check() { if (fail) error("offline") }

    override suspend fun explore(userId: String): ClubSections {
        check()
        val approved = memberships.filterValues { it.approved }.keys
        val pending = memberships.filterValues { it.pending }.keys
        return exploreSections(clubs.values.toList(), approved, pending)
    }

    override suspend fun search(query: String, page: Int): List<Club> =
        clubs.values.filter { it.name.contains(query.trim(), ignoreCase = true) }.sortedByDescending { it.createdAt }.drop(page * 20).take(20).also { check() }

    override suspend fun myClubs(userId: String): List<Club> = memberships.filterValues { it.approved }.keys.mapNotNull(clubs::get).also { check() }

    override suspend fun join(userId: String, club: Club) {
        check(); if (failJoin) error("rls")
        memberships[club.id] = ClubMembership("member", if (club.isPrivate) "pending" else "approved")
        if (!club.isPrivate) clubs[club.id] = club.copy(memberCount = club.memberCount + 1)
    }

    override suspend fun leave(userId: String, clubId: String) {
        check(); if (failJoin) error("rls")
        val was = memberships.remove(clubId)
        if (was?.approved == true) clubs[clubId]?.let { clubs[clubId] = it.copy(memberCount = it.memberCount - 1) }
    }

    override suspend fun create(userId: String, name: String, description: String, category: String, privacy: String, icon: PickedImage?): String {
        check()
        val id = "new-club"
        clubs[id] = Club(id, name.trim(), description.ifBlank { null }, category.ifBlank { null }, privacy, ownerId = userId)
        memberships[id] = ClubMembership("owner", "approved")
        created = name
        return id
    }

    override suspend fun detail(userId: String, clubId: String): ClubDetail? {
        check()
        val club = clubs[clubId] ?: return null
        return ClubDetail(club, memberships[clubId], channels[clubId].orEmpty(), clubId in muted)
    }

    override suspend fun posts(userId: String, clubId: String?): List<ClubPost> {
        check()
        return if (clubId == null) posts.filter { memberships[it.clubId]?.approved == true } else posts.filter { it.clubId == clubId }
    }

    override suspend fun post(postId: String): ClubPostPage? = posts.firstOrNull { it.id == postId }?.let {
        ClubPostPage(it.id, it.clubId, clubs[it.clubId]?.name, it.authorUsername, it.authorDisplayName, it.authorAvatarUrl, it.content, it.imageUrls, it.createdAt)
    }

    override suspend fun setLiked(userId: String, postId: String, liked: Boolean) {
        check(); if (failLike) error("like")
        posts = posts.map { if (it.id == postId) it.copy(liked = liked, likeCount = it.likeCount + if (liked) 1 else -1) else it }.toMutableList()
    }

    override suspend fun setSaved(userId: String, postId: String, saved: Boolean) {
        check()
        posts = posts.map { if (it.id == postId) it.copy(saved = saved) else it }.toMutableList()
    }

    override suspend fun setPinned(postId: String, pinned: Boolean) {
        check()
        posts = posts.map { if (it.id == postId) it.copy(pinned = pinned) else it }.toMutableList()
    }

    override suspend fun deletePost(postId: String) { check(); posts.removeAll { it.id == postId } }

    override suspend fun vote(userId: String, pollId: String, option: Int) { check(); votes += pollId to option }

    override suspend fun setMuted(userId: String, clubId: String, muted: Boolean) {
        check()
        if (muted) this.muted += clubId else this.muted -= clubId
    }

    override suspend fun messages(channelId: String): List<ClubMessage> = messages[channelId].orEmpty().toList().also { check() }

    override suspend fun markChannelRead(channelId: String) { marked++ }

    override suspend fun sendMessage(userId: String, clubId: String, channelId: String, text: String?, image: PickedImage?) {
        check()
        sent += Triple(channelId, text, image)
        messages.getOrPut(channelId) { mutableListOf() } += ClubMessage("sent${sent.size}", userId, text, null, Instant.now().toString(), "wyn_me", "ฉันเอง", null)
    }

    override suspend fun deleteMessage(messageId: String) {
        check()
        messages.values.forEach { list -> list.removeAll { it.id == messageId } }
    }

    override suspend fun members(clubId: String): List<ClubMember> = listOf(
        ClubMember(ClubFixture.OTHER, "owner", "mind_coffee", "มายด์", null),
        ClubMember(ClubFixture.ME, "member", "wyn_me", "ฉันเอง", null),
    ).also { check() }

    override suspend fun events(clubId: String): List<ClubEvent> =
        listOf(ClubEvent("e1", "ทริปคาเฟ่อารีย์", "เจอกันหน้าสถานี", "2026-10-04T03:00:00Z", "place", "BTS อารีย์")).also { check() }

    override suspend fun insights(clubId: String): List<Pair<String, String>>? =
        listOf("new_members" to "12", "new_posts" to "30", "likes_and_comments" to "210", "active_members" to "48").also { check() }

    override suspend fun report(targetType: String, targetId: String, category: String, detail: String?) {
        check()
        reports += Triple(targetType, targetId, category)
    }

    override suspend fun previewInvite(code: String): ClubInvitePreview? = invite.also { check() }

    override suspend fun redeemInvite(code: String): String? {
        check()
        memberships[ClubFixture.CLUB] = ClubMembership("member", "approved")
        return invite?.clubId
    }
}
