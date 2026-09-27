package io.wyn.wyn.testing

import io.wyn.wyn.core.data.Club
import io.wyn.wyn.core.data.DiscoveryRepository
import io.wyn.wyn.core.data.FeedRow
import io.wyn.wyn.core.data.Person
import io.wyn.wyn.core.data.RankedHashtag
import io.wyn.wyn.core.data.SAVED_PAGE
import io.wyn.wyn.core.data.SEARCH_PEOPLE_PAGE
import io.wyn.wyn.core.data.SEARCH_POSTS_PAGE

object DiscoveryFixture {
    val hashtags = listOf(
        RankedHashtag("wynos", 12.0, 48),
        RankedHashtag("กาแฟ", 9.0, 31),
        RankedHashtag("bangkokrain", 6.5, 20),
        RankedHashtag("startup", 4.0, 12),
        RankedHashtag("เชียงใหม่", 2.0, 8),
        RankedHashtag("film", 1.0, 3),
    )
    val people = listOf(
        Person("u1", "mind_coffee", "มายด์", null, isVerified = true, isPrivate = false, following = false, requested = false),
        Person("u2", "sky_blue", "Sky", null, isVerified = false, isPrivate = true, following = false, requested = true),
        Person("u3", "techdaily", "TechDaily", null, isVerified = true, isPrivate = false, following = true, requested = false),
        Person("u4", "wyn_team", "WYN Team", null, isVerified = false, isPrivate = false, following = false, requested = false),
    )
}

/** Search and saved posts from fixed lists; `query` filters like the database would. */
class FakeDiscoveryRepository(
    var hashtags: List<RankedHashtag> = DiscoveryFixture.hashtags,
    var people: List<Person> = DiscoveryFixture.people,
    var posts: List<FeedRow> = HomeFixture.rows,
    var clubs: List<Club> = ClubFixture.explore,
    var saved: List<FeedRow> = HomeFixture.rows.take(2),
) : DiscoveryRepository {
    var fail = false
    val searches = mutableListOf<String>()
    private fun check() { if (fail) error("offline") }

    override suspend fun trending(limit: Int) = hashtags.take(limit).also { check() }
    override suspend fun suggested(viewerId: String, limit: Int) = people.take(limit).also { check() }
    override suspend fun searchPeople(viewerId: String, query: String, page: Int): List<Person> {
        check(); searches += "people:$query:$page"
        return people.filter { it.username.contains(query, true) || it.label.contains(query, true) }.drop(page * SEARCH_PEOPLE_PAGE).take(SEARCH_PEOPLE_PAGE)
    }
    override suspend fun searchPosts(query: String, page: Int): List<FeedRow> {
        check(); searches += "posts:$query:$page"
        return posts.filter { it.caption.orEmpty().contains(query, true) }.drop(page * SEARCH_POSTS_PAGE).take(SEARCH_POSTS_PAGE)
    }
    override suspend fun searchClubs(query: String, page: Int): List<Club> {
        check(); searches += "clubs:$query:$page"
        return clubs.filter { it.name.contains(query, true) }.drop(page * 20).take(20)
    }
    override suspend fun saved(userId: String, page: Int) = saved.drop(page * SAVED_PAGE).take(SAVED_PAGE).also { check() }
}
