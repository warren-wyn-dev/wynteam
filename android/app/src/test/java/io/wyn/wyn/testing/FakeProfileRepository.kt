package io.wyn.wyn.testing

import io.wyn.wyn.core.data.FeedRow
import io.wyn.wyn.core.data.FollowKind
import io.wyn.wyn.core.data.Person
import io.wyn.wyn.core.data.Profile
import io.wyn.wyn.core.data.ProfileImage
import io.wyn.wyn.core.data.ProfileRepository
import io.wyn.wyn.core.data.ProfileRuleException
import io.wyn.wyn.core.data.ProfileSummary
import io.wyn.wyn.core.data.ProfileTab

/** In-memory profiles; [failWrites] makes every change fail. */
class FakeProfileRepository(
    var summaries: MutableMap<String, ProfileSummary> = mutableMapOf(
        ProfileFixture.OTHER to ProfileFixture.other,
        HomeFixture.VIEWER to ProfileFixture.own,
    ),
    var tabs: Map<ProfileTab, List<FeedRow>> = mapOf(ProfileTab.Posts to HomeFixture.rows.take(2)),
    var followers: List<Person> = ProfileFixture.people,
    var following: List<Person> = ProfileFixture.people.take(1),
) : ProfileRepository {
    val writes = mutableListOf<String>()
    var failWrites = false
    var failReads = false
    var likesAllowed = true
    var suggested: List<Person> = ProfileFixture.people
    var takenUsernames = setOf("taken")

    private fun write(entry: String) { if (failWrites) error("write failed"); writes += entry }

    override suspend fun summary(viewerId: String, profileId: String): ProfileSummary? { if (failReads) error("offline"); return summaries[profileId] }
    override suspend fun profileIdForUsername(username: String) = summaries.values.firstOrNull { it.profile.username == username }?.profile?.id
    override suspend fun rows(profileId: String, tab: ProfileTab, page: Int) = if (page == 0) tabs[tab].orEmpty() else emptyList()
    override suspend fun canViewLikes(profileId: String) = likesAllowed
    override suspend fun people(viewerId: String, profileId: String, kind: FollowKind) = if (kind == FollowKind.Followers) followers else following
    override suspend fun suggestions(viewerId: String, viewedId: String) = suggested
    override suspend fun dismissSuggestion(viewerId: String, profileId: String) = write("dismiss:$profileId")
    override suspend fun setMuted(viewerId: String, profileId: String, muted: Boolean) = write("mute:$profileId:$muted")
    override suspend fun setBlocked(profileId: String, blocked: Boolean) {
        write("block:$profileId:$blocked")
        summaries[profileId]?.let { summaries[profileId] = it.copy(blocked = blocked, following = false, requested = false) }
    }
    override suspend fun report(profileId: String, category: String, detail: String?) = write("report:$profileId:$category:${detail.orEmpty()}")
    override suspend fun updateBasics(userId: String, displayName: String, bio: String, socialLinks: Map<String, String>) =
        write("basics:$displayName:$bio:${socialLinks.toSortedMap()}")
    override suspend fun updateUsername(userId: String, username: String) {
        if (username.lowercase() in takenUsernames) throw ProfileRuleException(ProfileRuleException.Reason.UsernameTaken)
        write("username:${username.lowercase()}")
    }
    override suspend fun uploadImage(userId: String, kind: ProfileImage, bytes: ByteArray, contentType: String, extension: String): String {
        write("upload:${kind.name}:$contentType:$extension:${bytes.size}")
        return "https://example.invalid/${kind.file}.$extension?v=1"
    }
    override suspend fun removeImage(userId: String, kind: ProfileImage) = write("remove:${kind.name}")
}

object ProfileFixture {
    const val OTHER = "22222222-2222-4222-8222-222222222222"
    val own = ProfileSummary(
        Profile(
            id = HomeFixture.VIEWER, username = "warren", displayName = "WARREN", isVerified = true,
            bio = "Founder of WYNOS ✨\nSocial + E-commerce #WYNOS", website = "https://wynos.online/",
            socialLinks = mapOf("website" to "https://wynos.online/", "x" to "https://x.com/wynos"),
        ),
        followerCount = 1024, followingCount = 128,
    )
    val other = ProfileSummary(
        Profile(id = OTHER, username = "mint", displayName = "mint", bio = "เช้านี้กาแฟดีมาก ☕"),
        followerCount = 12, followingCount = 3,
    )
    val people = listOf(
        Person("p1", "sky_blue", "Sky", null, isVerified = false, isPrivate = false, following = false, requested = false),
        Person("p2", "techdaily", "TechDaily", null, isVerified = true, isPrivate = true, following = false, requested = true),
    )
}
