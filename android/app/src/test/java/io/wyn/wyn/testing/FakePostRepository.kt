package io.wyn.wyn.testing

import io.wyn.wyn.core.data.ActivityPerson
import io.wyn.wyn.core.data.Comment
import io.wyn.wyn.core.data.FeedRow
import io.wyn.wyn.core.data.PostActivity
import io.wyn.wyn.core.data.PostRepository

/** In-memory posts and comments for the post detail screen. */
class FakePostRepository(
    val drops: MutableMap<String, FeedRow> = HomeFixture.rows.associateBy { it.id }.toMutableMap(),
    var comments: MutableList<Comment> = mutableListOf(),
) : PostRepository {
    val writes = mutableListOf<String>()
    var failWrites = false
    var views = 0
    private var nextId = 1

    private fun write(entry: String) { if (failWrites) error("write failed"); writes += entry }

    override suspend fun fetchDrop(dropId: String) = drops[dropId]
    override suspend fun fetchImages(dropId: String, fallback: String?) = listOfNotNull(fallback)
    override suspend fun fetchComments(userId: String, dropId: String, page: Int) =
        comments.filter { it.dropId == dropId }.drop(page * 50).take(50)
    override suspend fun addComment(userId: String, dropId: String, text: String, parentId: String?): Comment {
        write("comment:$dropId:${text.trim()}:${parentId.orEmpty()}")
        return Comment("new-${nextId++}", dropId, userId, text.trim(), "2026-09-27T10:00:00Z", parentId, "fixture", "Fixture").also { comments += it }
    }
    override suspend fun setCommentLiked(userId: String, commentId: String, liked: Boolean) = write("commentLike:$commentId:$liked")
    override suspend fun deleteComment(userId: String, commentId: String) = write("deleteComment:$commentId")
    override suspend fun fetchActivity(dropId: String) = PostActivity(
        likes = listOf(ActivityPerson("warren", "warren", "WARREN", null, false)),
        reposts = emptyList(),
    )
    override suspend fun editDrop(dropId: String, caption: String?) = write("edit:$dropId:${caption.orEmpty()}")
    override suspend fun deleteDrop(dropId: String) = write("delete:$dropId")
    override suspend fun recordView(dropId: String) { views++ }
}
