package io.wyn.wyn.feature.chat

import io.wyn.wyn.R
import io.wyn.wyn.core.data.PickedImage
import io.wyn.wyn.testing.ChatFixture
import io.wyn.wyn.testing.FakeChatRepository
import io.wyn.wyn.testing.FakeFeedRepository
import io.wyn.wyn.testing.FakeProfileRepository
import io.wyn.wyn.testing.ProfileFixture
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

@OptIn(ExperimentalCoroutinesApi::class)
class ChatViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val chat = FakeChatRepository()
    private val profiles = FakeProfileRepository().apply {
        summaries[ChatFixture.OTHER] = ProfileFixture.other.copy(profile = ProfileFixture.other.profile.copy(id = ChatFixture.OTHER, username = "mind_coffee", displayName = "มายด์"))
    }
    private val feed = FakeFeedRepository()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    private fun TestScope.conversation(id: String? = ChatFixture.CONVERSATION, user: String? = null) =
        ConversationViewModel(chat, profiles, feed, ChatFixture.ME, id, user).also { advanceUntilIdle() }

    @Test fun inboxShowsConversationsRequestsAndUnread() = runTest(dispatcher) {
        val vm = ChatInboxViewModel(chat, ChatFixture.ME); advanceUntilIdle()
        assertEquals(true, vm.allowed)
        assertEquals(3, vm.rows.size)
        assertEquals(1, vm.requests.size)
        assertEquals(1, vm.unreadCount)
        assertTrue(vm.rows[0].isUnread(ChatFixture.ME))
        assertFalse("my own last message is never unread", vm.rows[1].isUnread(ChatFixture.ME))
        vm.toggleSearch(); vm.updateQuery("sky")
        assertEquals(listOf("c2"), vm.visible { "" }.map { it.id })
    }

    @Test fun lockdownClosesChat() = runTest(dispatcher) {
        chat.open = false
        val vm = ChatInboxViewModel(chat, ChatFixture.ME); advanceUntilIdle()
        assertEquals(false, vm.allowed)
        assertTrue(vm.rows.isEmpty())
    }

    @Test fun requestsAcceptAndDeclineAfterConfirming() = runTest(dispatcher) {
        val vm = ChatInboxViewModel(chat, ChatFixture.ME); advanceUntilIdle()
        vm.show(InboxView.Requests)
        vm.askDecline(vm.requests.first())
        assertTrue(chat.writes.isEmpty())
        vm.decline(); advanceUntilIdle()
        assertEquals(listOf("decline:r1"), chat.writes)
        assertEquals(InboxView.Inbox, vm.view)
    }

    @Test fun previewsFollowTheWeb() {
        assertEquals(Preview.Text("แนะนำเลยถ้าผ่านแถวนั้น ☕️"), previewKind(ChatFixture.inbox[0]))
        assertEquals(Preview.Photo, previewKind(ChatFixture.inbox[1]))
        assertEquals(Preview.Deleted, previewKind(ChatFixture.inbox[2]))
        assertEquals(Preview.Waiting, previewKind(ChatFixture.inbox[0].copy(lastMessageText = null, status = "pending")))
    }

    @Test fun openingLoadsMarksReadAndShowsReceipts() = runTest(dispatcher) {
        val vm = conversation()
        assertEquals(listOf("m1", "m2", "m4", "m6"), vm.ordered.map { it.id })
        assertEquals("มายด์", vm.other?.label)
        assertTrue("read:${ChatFixture.CONVERSATION}" in chat.writes)
    }

    @Test fun sendingIsOptimisticAndRestoresTheDraftOnFailure() = runTest(dispatcher) {
        val vm = conversation()
        vm.updateDraft("  สวัสดี  ")
        vm.send()
        assertTrue(vm.ordered.last().pending)
        advanceUntilIdle()
        assertFalse(vm.ordered.any { it.pending })
        assertTrue("send:${ChatFixture.CONVERSATION}:สวัสดี:false" in chat.writes)

        chat.failSend = true
        vm.updateDraft("อีกข้อความ")
        vm.attach(PickedImage(ByteArray(4), "image/jpeg", "jpg", 1, 1))
        vm.send(); advanceUntilIdle()
        assertEquals("อีกข้อความ", vm.draft)
        assertTrue(vm.photo != null)
        assertEquals(R.string.chat_send_failed, vm.error?.res)
        assertFalse(vm.ordered.any { it.pending })
    }

    @Test fun onlyYourOwnMessagesCanBeDeletedAfterConfirming() = runTest(dispatcher) {
        val vm = conversation()
        val theirs = vm.ordered.first()
        vm.toggleReveal(theirs)
        assertNull(vm.revealed)
        vm.askDelete(theirs)
        assertNull(vm.confirm)
        val mine = vm.ordered.last()
        vm.toggleReveal(mine)
        assertEquals(mine.id, vm.revealed)
        vm.askDelete(mine)
        vm.confirmNow(); advanceUntilIdle()
        assertTrue("delete:${mine.id}" in chat.writes)
        assertTrue(vm.ordered.last().deletedAt != null)
    }

    @Test fun aNewConversationStartsOnlyAtTheFirstSend() = runTest(dispatcher) {
        chat.others.clear()
        val vm = conversation(id = null, user = "p9")
        assertTrue(vm.composeMode)
        assertTrue(chat.writes.none { it.startsWith("start") })
        vm.updateDraft("hello")
        vm.send(); advanceUntilIdle()
        assertEquals("start:p9", chat.writes.first())
        assertEquals("c-new", vm.conversationId)
        assertTrue(vm.requesterPending)
    }

    @Test fun anExistingConversationOpensInsteadOfANewOne() = runTest(dispatcher) {
        val vm = conversation(id = null, user = ChatFixture.OTHER)
        assertEquals(ChatFixture.CONVERSATION, vm.conversationId)
        assertEquals(4, vm.ordered.size)
    }

    @Test fun blockedPeopleCannotBeMessaged() = runTest(dispatcher) {
        chat.blockedWith += "p9"
        val vm = conversation(id = null, user = "p9")
        assertEquals(R.string.chat_cannot_open, vm.error?.res)
        vm.updateDraft("hi")
        assertFalse(vm.canSend)
        vm.send(); advanceUntilIdle()
        assertTrue(chat.writes.none { it.startsWith("start") || it.startsWith("send") })
    }

    @Test fun recipientOfARequestAcceptsOrDeclines() = runTest(dispatcher) {
        chat.metas[ChatFixture.CONVERSATION] = io.wyn.wyn.core.data.ConversationMeta("pending", ChatFixture.OTHER, null)
        val vm = conversation()
        assertTrue(vm.recipientPending)
        vm.decline()
        assertEquals(ChatConfirm.DeclineRequest, vm.confirm)
        vm.confirmNow(); advanceUntilIdle()
        assertTrue(vm.closed)
    }
}
