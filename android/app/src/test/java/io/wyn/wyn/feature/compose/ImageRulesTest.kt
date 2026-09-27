package io.wyn.wyn.feature.compose

import io.wyn.wyn.core.data.DraftPaths
import io.wyn.wyn.core.data.ImageRules
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ImageRulesTest {
    @Test fun onlyImageTypesAndTheRealExtension() {
        assertEquals("image/jpeg" to "jpeg", ImageRules.uploadType("image/jpeg", "IMG.JPEG"))
        assertEquals("image/png" to "png", ImageRules.uploadType("image/png", "photo.jpg"))
        assertEquals("image/heic" to "heic", ImageRules.uploadType("", "IMG_1.HEIC"))
        assertNull(ImageRules.uploadType("application/pdf", "fake.jpg"))
        assertNull(ImageRules.uploadType("image/svg+xml", "x.svg"))
        assertNull(ImageRules.uploadType(null, "script.sh"))
    }

    @Test fun draftPhotosAreOnlyReadFromTheOwnersFolder() {
        val folder = "https://abc.supabase.co/storage/v1/object/public/drop-images/u1/drafts/"
        assertEquals("d1.jpg", DraftPaths.ownDraftFileName(folder, "${folder}d1.jpg?v=123"))
        assertNull("another account", DraftPaths.ownDraftFileName(folder, "https://abc.supabase.co/storage/v1/object/public/drop-images/u2/drafts/d1.jpg"))
        assertNull("another host", DraftPaths.ownDraftFileName(folder, "https://evil.example/storage/v1/object/public/drop-images/u1/drafts/d1.jpg"))
        assertNull("path traversal", DraftPaths.ownDraftFileName(folder, "${folder}..%2F..%2Fu2%2Fd.jpg"))
        assertNull("nested", DraftPaths.ownDraftFileName(folder, "${folder}a/b.jpg"))
        assertNull("not an image", DraftPaths.ownDraftFileName(folder, "${folder}d1.html"))
    }
}
