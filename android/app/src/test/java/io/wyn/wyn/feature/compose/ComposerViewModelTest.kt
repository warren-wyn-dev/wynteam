package io.wyn.wyn.feature.compose

import io.wyn.wyn.R
import io.wyn.wyn.core.data.AspectChoice
import io.wyn.wyn.core.data.Audience
import io.wyn.wyn.core.data.PickedImage
import io.wyn.wyn.testing.FakeComposerRepository
import io.wyn.wyn.testing.FakeComposerRepository.Outcome
import io.wyn.wyn.testing.FakeFeedRepository
import io.wyn.wyn.testing.HomeFixture
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
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
class ComposerViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val repo = FakeComposerRepository()
    private var ops = 0

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    private fun TestScope.open(draft: String? = null) =
        ComposerViewModel(repo, FakeFeedRepository(), HomeFixture.VIEWER, draft) { "op-${++ops}" }.also { advanceUntilIdle() }

    private fun photo(seed: Int) = PickedImage(byteArrayOf(seed.toByte()), "image/jpeg", "jpg", 1200, 900)

    @Test fun textPostPublishesWithAudienceAndAspect() = runTest(dispatcher) {
        val vm = open()
        assertFalse(vm.canPublish)
        vm.updateCaption("  สวัสดี  ")
        vm.chooseAudience(Audience.Friends)
        vm.addImages(listOf(photo(1), photo(2)))
        vm.chooseAspect(AspectChoice.Square)
        assertTrue(vm.canPublish)
        vm.publish(); advanceUntilIdle()
        assertEquals(listOf("drop:สวัสดี:2:friends:1:1"), repo.published)
        assertEquals(ComposerExit.Published, vm.exit)
    }

    @Test fun atMostNinePhotos() = runTest(dispatcher) {
        val vm = open()
        vm.addImages((1..12).map(::photo))
        assertEquals(9, vm.images.size)
        assertEquals(R.string.max_images, vm.error?.res)
    }

    @Test fun pollNeedsAQuestionAndDistinctOptions() = runTest(dispatcher) {
        val vm = open()
        vm.toggleMode()
        vm.updatePollOption(0, "ชา"); vm.updatePollOption(1, "กาแฟ")
        assertFalse("no question yet", vm.canPublish)
        vm.updateCaption("ดื่มอะไรดี")
        assertTrue(vm.canPublish)
        vm.updatePollOption(1, " ชา ")
        assertFalse("duplicate options", vm.canPublish)
        vm.updatePollOption(1, "กาแฟ")
        vm.addPollOption(); vm.addPollOption(); vm.addPollOption()
        assertEquals(4, vm.pollOptions.size)
        assertFalse("empty third option", vm.canPublish)
        vm.removePollOption(3); vm.removePollOption(2)
        vm.removePollOption(1)
        assertEquals("never fewer than two", 2, vm.pollOptions.size)
        vm.publish(); advanceUntilIdle()
        assertEquals(listOf("poll:ดื่มอะไรดี:ชา|กาแฟ:everyone"), repo.published)
    }

    @Test fun autosaveWaitsForTypingToStopAndReusesOneDraft() = runTest(dispatcher) {
        val vm = open()
        vm.updateCaption("ก")
        advanceTimeBy(500)
        vm.updateCaption("กข")
        advanceTimeBy(500)
        assertEquals(0, repo.draftSaves)
        advanceUntilIdle()
        assertEquals(1, repo.draftSaves)
        assertEquals(AutosaveStatus.Saved, vm.autosaveStatus)
        vm.updateCaption("กขค"); advanceUntilIdle()
        assertEquals("the same draft row is updated", 1, repo.drafts.size)
        assertEquals("กขค", repo.drafts.values.single().caption)
    }

    @Test fun publishingDeletesTheDraft() = runTest(dispatcher) {
        val vm = open()
        vm.updateCaption("ร่าง"); advanceUntilIdle()
        val draft = vm.draftRecordId!!
        vm.publish(); advanceUntilIdle()
        assertEquals(listOf(draft), repo.deletedDrafts)
    }

    @Test fun anUnknownResultRetriesWithTheSameOperationOnly() = runTest(dispatcher) {
        val vm = open()
        vm.updateCaption("โพสต์เดียว")
        repo.nextPublish = Outcome.Unknown
        vm.publish(); advanceUntilIdle()
        assertEquals(R.string.publish_state_unclear, vm.error?.res)
        assertNull(vm.exit)
        // Editing after an unknown result is refused: it could publish different content under the old post.
        vm.updateCaption("แก้แล้ว")
        vm.publish(); advanceUntilIdle()
        assertEquals(R.string.publish_state_unclear_edit, vm.error?.res)
        vm.updateCaption("โพสต์เดียว")
        vm.publish(); advanceUntilIdle()
        assertEquals(listOf("op-1", "op-1"), repo.operationIds)
        assertEquals(ComposerExit.Published, vm.exit)
    }

    @Test fun aRejectedPublishStartsFreshNextTime() = runTest(dispatcher) {
        val vm = open()
        vm.updateCaption("x")
        repo.nextPublish = Outcome.Rejected
        vm.publish(); advanceUntilIdle()
        assertEquals(R.string.publish_failed, vm.error?.res)
        vm.publish(); advanceUntilIdle()
        assertEquals(listOf("op-1", "op-2"), repo.operationIds)
    }

    @Test fun aDroppedPollConnectionWarnsAboutDuplicates() = runTest(dispatcher) {
        val vm = open()
        vm.toggleMode(); vm.updateCaption("q"); vm.updatePollOption(0, "a"); vm.updatePollOption(1, "b")
        repo.nextPublish = Outcome.Network
        vm.publish(); advanceUntilIdle()
        assertEquals(R.string.poll_connection_lost, vm.error?.res)
        assertTrue(repo.published.isEmpty())
    }

    @Test fun closingAskAboutTheDraftOnlyWhenThereIsContent() = runTest(dispatcher) {
        val empty = open()
        empty.requestClose()
        assertEquals(ComposerExit.Closed, empty.exit)

        val vm = open()
        vm.updateCaption("ยังไม่เสร็จ")
        vm.requestClose(toDrafts = true)
        assertTrue(vm.closePrompt)
        vm.saveDraftAndClose(); advanceUntilIdle()
        assertEquals(ComposerExit.Drafts, vm.exit)
        assertEquals("ยังไม่เสร็จ", repo.drafts.values.single().caption)
    }

    @Test fun reopeningADraftRestoresItWithoutSavingAgain() = runTest(dispatcher) {
        repo.drafts["d1"] = io.wyn.wyn.core.data.Draft("d1", null, "คำถาม", listOf("ก", "ข"), 1, "2026-09-27T10:00:00Z")
        val vm = open("d1")
        advanceUntilIdle()
        assertEquals(ComposeMode.Poll, vm.mode)
        assertEquals("คำถาม", vm.caption)
        assertEquals(0, repo.draftSaves)
        vm.publish(); advanceUntilIdle()
        assertEquals(listOf("poll:คำถาม:ก|ข:everyone"), repo.published)
        assertEquals(listOf("d1"), repo.deletedDrafts)
    }

    @Test fun aSavedDraftPhotoIsPublishedFromTheDraft() = runTest(dispatcher) {
        repo.drafts["d2"] = io.wyn.wyn.core.data.Draft("d2", "https://storage.example/drop-images/x/drafts/d2.jpg", null, null, null, "2026-09-27T10:00:00Z")
        val vm = open("d2")
        advanceUntilIdle()
        assertTrue(vm.canPublish)
        vm.publish(); advanceUntilIdle()
        assertEquals(listOf("drop::1:everyone:4:5"), repo.published)
    }
}
