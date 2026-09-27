package io.wyn.wyn.testing

import io.wyn.wyn.core.data.FeedRepository
import io.wyn.wyn.core.data.FeedRow
import io.wyn.wyn.core.data.FollowState
import io.wyn.wyn.core.data.HomeIdentity
import io.wyn.wyn.core.data.ViewerState
import java.time.Instant

/** An in-memory feed; [failWrites] makes every action fail so rollbacks can be tested. */
class FakeFeedRepository(
    var ranked: List<FeedRow> = HomeFixture.rows,
    var following: List<FeedRow> = emptyList(),
    var viewer: ViewerState = HomeFixture.viewer,
    var images: Map<String, List<String>> = HomeFixture.images,
) : FeedRepository {
    val writes = mutableListOf<String>()
    var failWrites = false
    var failReads = false
    var reads = 0

    override suspend fun fetchRanked(): List<FeedRow> { reads++; if (failReads) error("offline"); return ranked }
    override suspend fun fetchFollowing(userId: String): List<FeedRow> { reads++; if (failReads) error("offline"); return following }
    override suspend fun fetchImages(rows: List<FeedRow>) = images.filterKeys { id -> rows.any { it.id == id } }
    override suspend fun loadViewer(userId: String, rows: List<FeedRow>) = viewer
    override suspend fun fetchIdentity(userId: String) = HomeIdentity("fixture", "Fixture", null)

    private fun write(entry: String) { if (failWrites) error("write failed"); writes += entry }
    override suspend fun setLiked(userId: String, dropId: String, liked: Boolean) = write("like:$dropId:$liked")
    override suspend fun setSaved(userId: String, dropId: String, saved: Boolean) = write("save:$dropId:$saved")
    override suspend fun setRedropped(userId: String, dropId: String, redropped: Boolean) = write("redrop:$dropId:$redropped")
    override suspend fun deleteRedrop(userId: String, redropId: String) = write("deleteRedrop:$redropId")
    override suspend fun toggleFollow(userId: String, authorId: String, following: Boolean, requested: Boolean, isPrivate: Boolean): FollowState {
        write("follow:$authorId")
        return io.wyn.wyn.core.data.predictFollowState(following, requested, isPrivate)
    }
    override suspend fun hide(userId: String, dropId: String) = write("hide:$dropId")
    override suspend fun unhide(userId: String, dropId: String) = write("unhide:$dropId")
    override suspend fun report(dropId: String, category: String, detail: String?) = write("report:$dropId:$category:${detail.orEmpty()}")
}

/** The same rows as the web's Home fixture (web/components/home/home-fixture.tsx). */
object HomeFixture {
    const val VIEWER = "11111111-1111-4111-8111-111111111111"
    private fun ago(hours: Long) = Instant.now().minusSeconds(hours * 3600).toString()
    val rows = listOf(
        FeedRow(
            id = "drop-1", authorId = "warren", authorUsername = "warren", authorDisplayName = "WARREN",
            createdAt = "2026-09-04T10:00:00.000Z",
            caption = "WYNOS เริ่มจากคำถามง่าย ๆ ว่า...\n“ทำไม Social Media กับการซื้อของ ต้องแยกกัน?”\n\nเราเห็นของที่ชอบจากโซเชียล แต่พออยากซื้อ\nกลับต้องไปหาในอีกแอป 😅\n\nเราเลยอยากลองสร้างพื้นที่ที่รวมทั้ง Social + E-commerce ไว้ด้วยกัน...\n\n#WYNOS #SocialCommerce #Ecommerce\n#Startup #WYNOSThailand",
            likeCount = 6, commentCount = 2, redropCount = 2, redropId = "redrop-fixture-1", redropperUsername = "WYNOS", audience = "everyone",
        ),
        FeedRow(
            id = "drop-2", authorId = "warren-followed", authorUsername = "warren", authorDisplayName = "WARREN",
            createdAt = "2026-08-25T10:00:00.000Z",
            caption = "WYNOS เริ่มจากคำถามง่าย ๆ ว่า...\n“ทำไม Social Media กับการซื้อของ ต้องแยกกัน?”\n\nเราเห็นของที่ชอบจากโซเชียล แต่พออยากซื้อกลับต้องไปหาในอีกแอป 😅",
            likeCount = 12, commentCount = 3, redropCount = 4, redropId = "redrop-fixture-2", redropperUsername = "sky_blue", audience = "everyone",
        ),
        FeedRow(
            id = "drop-3", authorId = "mint", authorUsername = "mint", authorDisplayName = "mint", createdAt = ago(1),
            caption = "เช้านี้กาแฟดีมาก ☕\nพร้อมลุยงานต่อแล้ว 💪", likeCount = 28, commentCount = 5, audience = "everyone",
        ),
        FeedRow(
            id = "drop-4", authorId = "techdaily", authorUsername = "techdaily", authorDisplayName = "TechDaily", createdAt = ago(3),
            caption = "Apple เปิดตัวชิปใหม่ที่เน้นประสิทธิภาพด้าน AI มากขึ้น คาดว่าจะใช้ใน Mac รุ่นถัดไปเร็ว ๆ นี้",
            imageUrl = "https://example.invalid/fixture.jpg", imageWidth = 1200, imageHeight = 900, imageCount = 1, audience = "everyone",
        ),
    )
    val viewer = ViewerState(liked = setOf("drop-1"), following = setOf("warren-followed", "techdaily"))
    val images = mapOf("drop-4" to listOf("https://example.invalid/fixture.jpg"))
}
