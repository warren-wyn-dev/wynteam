package io.wyn.wyn.feature.profile

import io.wyn.wyn.R
import io.wyn.wyn.core.data.ProfileImage
import io.wyn.wyn.testing.FakeProfileRepository
import io.wyn.wyn.testing.HomeFixture
import io.wyn.wyn.testing.ProfileFixture
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
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
class EditProfileViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val repo = FakeProfileRepository()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    private fun edit() = EditProfileViewModel(repo, HomeFixture.VIEWER, ProfileFixture.own.profile)

    @Test fun fieldsFollowTheWebLimits() {
        val vm = edit()
        vm.updateUsername("@@Hello World!_.x")
        assertEquals("HelloWorld_.x", vm.username)
        vm.updateDisplayName("x".repeat(80))
        assertEquals(DISPLAY_NAME_MAX, vm.displayName.length)
        vm.updateBio("y".repeat(400))
        assertEquals(BIO_MAX, vm.bio.length)
    }

    @Test fun savesBasicsKeepingOtherLinks() = runTest(dispatcher) {
        val vm = edit()
        vm.updateWebsite("shop.wynos.online/new")
        vm.updateUsername("Warren2")
        vm.save(); advanceUntilIdle()
        assertTrue(vm.done)
        assertEquals(
            listOf("username:warren2", "basics:WARREN:${ProfileFixture.own.profile.bio}:{website=https://shop.wynos.online/new, x=https://x.com/wynos}"),
            repo.writes,
        )
    }

    @Test fun clearingTheWebsiteRemovesOnlyIt() = runTest(dispatcher) {
        val vm = edit()
        vm.updateWebsite("")
        vm.save(); advanceUntilIdle()
        assertEquals(listOf("basics:WARREN:${ProfileFixture.own.profile.bio}:{x=https://x.com/wynos}"), repo.writes)
    }

    @Test fun rejectsUnsafeWebsitesAndTakenUsernames() = runTest(dispatcher) {
        val vm = edit()
        vm.updateWebsite("javascript:alert(1)")
        vm.save(); advanceUntilIdle()
        assertEquals(R.string.profile_website_invalid, vm.error?.res)
        vm.updateWebsite("hello")
        vm.save(); advanceUntilIdle()
        assertEquals(R.string.profile_website_invalid, vm.error?.res)
        vm.updateWebsite("")
        vm.updateUsername("taken")
        vm.save(); advanceUntilIdle()
        assertEquals(R.string.profile_username_taken, vm.error?.res)
        assertFalse(vm.done)
        assertTrue(repo.writes.isEmpty())
    }

    @Test fun aNewNameIsRequiredOnlyWhenThereWasNone() = runTest(dispatcher) {
        val vm = EditProfileViewModel(repo, HomeFixture.VIEWER, ProfileFixture.own.profile.copy(displayName = null))
        vm.save(); advanceUntilIdle()
        assertEquals(R.string.profile_name_required, vm.error?.res)
    }

    @Test fun photosUploadAndRemoveAfterConfirming() = runTest(dispatcher) {
        val vm = edit()
        vm.uploadPhoto(ProfileImage.Avatar, ProfilePhoto(ByteArray(10), "image/jpeg", "jpg")); advanceUntilIdle()
        assertEquals("https://example.invalid/avatar.jpg?v=1", vm.avatarUrl)
        vm.askRemove(ProfileImage.Avatar)
        assertEquals(ProfileImage.Avatar, vm.confirmRemove)
        vm.removePhoto(); advanceUntilIdle()
        assertNull(vm.avatarUrl)
        assertEquals(listOf("upload:Avatar:image/jpeg:jpg:10", "remove:Avatar"), repo.writes)
    }

    @Test fun aFailedUploadShowsAnError() = runTest(dispatcher) {
        repo.failWrites = true
        val vm = edit()
        vm.uploadPhoto(ProfileImage.Cover, ProfilePhoto(ByteArray(10), "image/png", "png")); advanceUntilIdle()
        assertEquals(R.string.profile_photo_upload_failed, vm.error?.res)
        assertNull(vm.coverUrl)
    }
}
