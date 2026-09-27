package io.wyn.wyn.feature.clubs

import io.wyn.wyn.R
import io.wyn.wyn.core.data.Club
import io.wyn.wyn.core.data.ClubMembership
import io.wyn.wyn.core.data.EngagementSync
import io.wyn.wyn.core.data.PickedImage
import io.wyn.wyn.core.data.exploreSections
import io.wyn.wyn.feature.auth.UiText
import io.wyn.wyn.testing.ClubFixture
import io.wyn.wyn.testing.FakeClubRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.Instant

@OptIn(ExperimentalCoroutinesApi::class)
class ClubViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val repo = FakeClubRepository()
    private val sync = EngagementSync()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    private fun TestScope.club(id: String = ClubFixture.CLUB) = ClubViewModel(repo, ClubFixture.ME, id, sync).also { advanceUntilIdle() }

    // ---- Rules --------------------------------------------------------------------

    @Test fun exploreSplitsPopularAndNewestWithoutJoinedClubs() {
        val clubs = (1..25).map { Club("c$it", "Club $it", privacy = "public", createdAt = "2026-09-%02dT00:00:00Z".format(it), memberCount = it) }
        val sections = exploreSections(clubs, approved = setOf("c25"), pending = setOf("c3"))
        assertEquals((24 downTo 15).map { "c$it" }, sections.popular.map { it.id })
        // web WYN-185: newest never repeats a popular Club.
        assertEquals((14 downTo 5).map { "c$it" }, sections.newest.map { it.id })
        assertEquals(setOf("c3"), sections.pending)
    }

    @Test fun pollTimeMatchesTheWebLabels() {
        val now = Instant.parse("2026-09-27T10:00:00Z")
        assertEquals(PollTime.None, pollTime(null, now))
        assertEquals(PollTime.Closed, pollTime("2026-09-27T09:59:00Z", now))
        assertEquals(PollTime.Days(2), pollTime("2026-09-29T11:00:00Z", now))
        assertEquals(PollTime.Hours(5), pollTime("2026-09-27T15:30:00Z", now))
        assertEquals(PollTime.Minutes(1), pollTime("2026-09-27T10:00:20Z", now))
        val post = ClubFixture.posts[1]
        assertEquals(55, post.pollPercent(0))
        assertEquals(20, post.pollPercent(2))
        assertNull(post.copy(pollTotalVotes = null).pollPercent(0))
    }

    @Test fun postPermissionsFollowTheWebMenu() {
        val theirs = ClubFixture.posts[0]
        val mine = ClubFixture.posts[2]
        assertFalse(theirs.canDelete(ClubFixture.ME))
        assertFalse(theirs.canPin(ClubFixture.ME))
        assertTrue(mine.canDelete(ClubFixture.ME))
        assertFalse("nobody pins their own post", mine.copy(myRole = "admin").canPin(ClubFixture.ME))
        assertTrue(theirs.copy(myRole = "moderator").canPin(ClubFixture.ME))
        assertTrue(theirs.copy(myRole = "owner").canDelete(ClubFixture.ME))
    }

    @Test fun aboutTabsDependOnMembership() {
        assertEquals(listOf(AboutTab.Details, AboutTab.Members), aboutTabs(null))
        assertEquals(listOf(AboutTab.Details, AboutTab.Members), aboutTabs(ClubMembership("member", "pending")))
        assertEquals(listOf(AboutTab.Details, AboutTab.Members, AboutTab.Events), aboutTabs(ClubMembership("moderator", "approved")))
        assertEquals(AboutTab.entries.toList(), aboutTabs(ClubMembership("admin", "approved")))
        assertEquals("Likes And Comments", insightLabel("likes_and_comments"))
        assertEquals("1,284", memberCount(1284))
    }

    // ---- Explore, My Clubs, create --------------------------------------------------

    @Test fun exploreJoinsAndMovesTheClubOut() = runTest(dispatcher) {
        repo.memberships.clear()
        val vm = ExploreClubsViewModel(repo, ClubFixture.ME); advanceUntilIdle()
        assertTrue(vm.popular.any { it.id == ClubFixture.CLUB })
        vm.join(repo.clubs.getValue(ClubFixture.PRIVATE_CLUB)); advanceUntilIdle()
        assertTrue("a private Club waits for approval", vm.pending(repo.clubs.getValue(ClubFixture.PRIVATE_CLUB)))
        vm.join(repo.clubs.getValue(ClubFixture.CLUB)); advanceUntilIdle()
        assertFalse(vm.popular.any { it.id == ClubFixture.CLUB } || vm.newest.any { it.id == ClubFixture.CLUB })
        vm.updateQuery("film")
        assertEquals(listOf("c3"), (vm.popular + vm.newest).map { it.id })
    }

    @Test fun exploreJoinFailureSaysSo() = runTest(dispatcher) {
        repo.memberships.clear()
        val vm = ExploreClubsViewModel(repo, ClubFixture.ME); advanceUntilIdle()
        repo.failJoin = true
        vm.join(repo.clubs.getValue(ClubFixture.CLUB)); advanceUntilIdle()
        assertEquals(UiText(R.string.clubs_join_failed), vm.error)
        assertNull(vm.joining)
    }

    @Test fun myClubsListsApprovedOnly() = runTest(dispatcher) {
        repo.memberships[ClubFixture.PRIVATE_CLUB] = ClubMembership("member", "pending")
        val vm = MyClubsViewModel(repo, ClubFixture.ME); advanceUntilIdle()
        assertEquals(listOf(ClubFixture.CLUB), vm.rows.map { it.id })
        repo.fail = true
        vm.load(); advanceUntilIdle()
        assertEquals(UiText(R.string.my_clubs_failed), vm.error)
    }

    @Test fun createNeedsANameAndLimitsFields() = runTest(dispatcher) {
        val vm = CreateClubViewModel(repo, ClubFixture.ME)
        assertFalse(vm.canSubmit)
        vm.updateName("   "); vm.submit(); advanceUntilIdle()
        assertNull(repo.created)
        vm.updateName("x".repeat(80))
        assertEquals(50, vm.name.length)
        vm.updateDescription("d".repeat(900))
        assertEquals(500, vm.description.length)
        vm.choosePrivacy("secret")
        assertEquals("public", vm.privacy)
        vm.choosePrivacy("private")
        vm.submit(); advanceUntilIdle()
        assertEquals("new-club", vm.createdId)
        assertEquals("private", repo.clubs.getValue("new-club").privacy)
    }

    // ---- Club page -------------------------------------------------------------------

    @Test fun joinIsOptimisticAndRollsBack() = runTest(dispatcher) {
        repo.memberships.clear()
        val vm = club()
        assertEquals(1284, vm.detail?.club?.memberCount)
        repo.failJoin = true
        vm.onMembershipTap()
        assertTrue("shown before the server answers", vm.approved)
        assertEquals(1285, vm.detail?.club?.memberCount)
        advanceUntilIdle()
        assertFalse(vm.approved)
        assertEquals(1284, vm.detail?.club?.memberCount)
        assertEquals(UiText(R.string.club_membership_failed), vm.error)
    }

    @Test fun leavingAndCancellingAskFirst() = runTest(dispatcher) {
        val vm = club()
        vm.onMembershipTap()
        assertEquals(ClubConfirm.Leave, vm.confirm)
        vm.dismissConfirm()
        assertTrue(vm.approved)
        vm.onMembershipTap(); vm.confirmNow(); advanceUntilIdle()
        assertNull(vm.membership)
        assertEquals(1283, vm.detail?.club?.memberCount)

        repo.memberships[ClubFixture.PRIVATE_CLUB] = ClubMembership("member", "pending")
        val pending = club(ClubFixture.PRIVATE_CLUB)
        assertTrue("a private Club hides posts until approved", !pending.canReadPosts && pending.posts.isEmpty())
        pending.leaveFromMenu()
        assertEquals(ClubConfirm.CancelRequest, pending.confirm)
        pending.confirmNow(); advanceUntilIdle()
        assertNull(pending.membership)
    }

    @Test fun ownerCannotLeave() = runTest(dispatcher) {
        repo.memberships[ClubFixture.CLUB] = ClubMembership("owner", "approved")
        val vm = club()
        vm.onMembershipTap()
        assertNull(vm.confirm)
        assertTrue(vm.canManage)
    }

    @Test fun muteManageAndReportClub() = runTest(dispatcher) {
        val vm = club()
        vm.openMenu(true)
        vm.toggleMute(); advanceUntilIdle()
        assertTrue(vm.detail?.muted == true)
        assertFalse(vm.menuOpen)
        vm.reportClub()
        vm.report.choose("other")
        vm.report.submit()
        assertEquals(UiText(R.string.report_detail_required), vm.report.error)
        vm.report.updateDetail("spam links"); vm.report.submit(); advanceUntilIdle()
        assertNull(vm.report.target)
        assertEquals(Triple("club", ClubFixture.CLUB, "other"), repo.reports.single())
    }

    @Test fun likeSyncsToHomeAndRollsBack() = runTest(dispatcher) {
        val home = ClubFeedViewModel(repo, ClubFixture.ME, sync)
        home.load(); advanceUntilIdle()
        val vm = club()
        val post = vm.posts.first()
        vm.toggleLike(post); advanceUntilIdle()
        assertEquals(25, vm.posts.first().likeCount)
        assertTrue(home.posts.first { it.id == post.id }.liked)
        repo.failLike = true
        vm.toggleLike(vm.posts.first()); advanceUntilIdle()
        assertTrue("rolled back", vm.posts.first().liked)
        assertEquals(UiText(R.string.club_like_failed), vm.toast?.text)
        assertTrue(home.posts.first { it.id == post.id }.liked)
    }

    @Test fun saveOffersUndo() = runTest(dispatcher) {
        val vm = club()
        val post = vm.posts.first()
        vm.saveFromMenu(post); advanceUntilIdle()
        assertTrue(vm.posts.first().saved)
        assertEquals(UiText(R.string.club_saved), vm.toast?.text)
        vm.toast?.action?.invoke(); advanceUntilIdle()
        assertFalse(vm.posts.first().saved)
        assertFalse(repo.posts.first().saved)
    }

    @Test fun deletePinAndVoteFollowPermissions() = runTest(dispatcher) {
        val vm = club()
        val theirs = vm.posts[0]
        vm.askDelete(theirs)
        assertNull("a member cannot delete someone else's post", vm.confirm)
        val mine = vm.posts.first { it.authorId == ClubFixture.ME }
        vm.askDelete(mine)
        vm.confirmNow(); advanceUntilIdle()
        assertFalse(vm.posts.any { it.id == mine.id })

        vm.vote(vm.posts.first { it.pollId != null }, 1); advanceUntilIdle()
        assertEquals(listOf("poll1" to 1), repo.votes)

        repo.memberships[ClubFixture.CLUB] = ClubMembership("moderator", "approved")
        repo.posts = repo.posts.map { it.copy(myRole = "moderator") }.toMutableList()
        val mod = club()
        mod.togglePin(mod.posts.first { it.id == "p2" }); advanceUntilIdle()
        assertTrue(repo.posts.first { it.id == "p2" }.pinned)
    }

    // ---- Chat and About ---------------------------------------------------------------

    @Test fun chatLoadsSendsAndMarksRead() = runTest(dispatcher) {
        val vm = club()
        vm.select(ClubTab.Chat)
        vm.chat.reload(); advanceUntilIdle()
        assertEquals(ClubFixture.GENERAL, vm.chat.channelId)
        assertEquals(2, vm.chat.messages.size)
        assertEquals(1, repo.marked)
        vm.chat.reload(); advanceUntilIdle()
        assertEquals("nothing new, no second read mark", 1, repo.marked)
        assertFalse(vm.chat.canSend)
        vm.chat.updateDraft("  สวัสดี  ")
        vm.chat.send(); advanceUntilIdle()
        assertEquals("สวัสดี", repo.sent.single().second)
        assertEquals("", vm.chat.draft)
        assertEquals(3, vm.chat.messages.size)
        vm.chat.attach(PickedImage(byteArrayOf(1), "image/png", "png", 1, 1))
        assertTrue(vm.chat.canSend)
        vm.chat.select(ClubFixture.RANDOM); advanceUntilIdle()
        assertTrue(vm.chat.messages.isEmpty())
    }

    @Test fun chatMoreDeletesMineAndReportsOthers() = runTest(dispatcher) {
        val vm = club()
        vm.chat.reload(); advanceUntilIdle()
        val theirs = vm.chat.messages.first { it.authorId != ClubFixture.ME }
        vm.chat.onMore(theirs)
        assertEquals("club_channel_message", vm.report.target?.type)
        vm.report.open(null)
        val mine = vm.chat.messages.first { it.authorId == ClubFixture.ME }
        vm.chat.onMore(mine)
        assertEquals(ClubConfirm.DeleteMessage(mine), vm.confirm)
        vm.confirmNow(); advanceUntilIdle()
        assertFalse(vm.chat.messages.any { it.id == mine.id })
    }

    @Test fun chatIsForApprovedMembersOnly() = runTest(dispatcher) {
        repo.memberships.clear()
        val vm = club()
        vm.chat.reload(); advanceUntilIdle()
        assertFalse(vm.chat.approved)
        assertTrue(vm.chat.messages.isEmpty())
        vm.chat.updateDraft("hi"); vm.chat.send(); advanceUntilIdle()
        assertTrue(repo.sent.isEmpty())
    }

    @Test fun aboutLoadsEachSection() = runTest(dispatcher) {
        val vm = club()
        vm.about.select(AboutTab.Members); advanceUntilIdle()
        assertEquals(2, vm.about.members.size)
        vm.about.select(AboutTab.Insights); advanceUntilIdle()
        assertEquals("new_members", vm.about.insights?.first()?.first)
        repo.fail = true
        vm.about.select(AboutTab.Events); advanceUntilIdle()
        assertEquals(UiText(R.string.about_failed), vm.about.error)
    }

    // ---- Home, post and invite ----------------------------------------------------------

    @Test fun homeFeedShowsMyClubsPosts() = runTest(dispatcher) {
        val home = ClubFeedViewModel(repo, ClubFixture.ME, sync)
        home.load(); advanceUntilIdle()
        assertEquals(3, home.posts.size)
        repo.memberships.clear()
        home.load(pull = true); advanceUntilIdle()
        assertTrue(home.posts.isEmpty())
        assertFalse(home.refreshing)
    }

    @Test fun postPageAndInvite() = runTest(dispatcher) {
        val post = ClubPostViewModel(repo, "p1"); advanceUntilIdle()
        assertEquals("คนรักกาแฟ", post.page?.clubName)
        val missing = ClubPostViewModel(repo, "nope"); advanceUntilIdle()
        assertNull(missing.page)

        repo.memberships.clear()
        val invite = ClubInviteViewModel(repo, "CODE"); advanceUntilIdle()
        invite.redeem(); advanceUntilIdle()
        assertEquals(ClubFixture.CLUB, invite.joinedId)
        assertEquals(UiText(R.string.invite_joined), invite.message)

        repo.invite = repo.invite?.copy(status = "expired")
        val expired = ClubInviteViewModel(repo, "OLD"); advanceUntilIdle()
        expired.redeem(); advanceUntilIdle()
        assertNull(expired.joinedId)
    }
}
