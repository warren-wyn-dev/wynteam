package online.wynos.food.data

/** Order-anchored text only. No attachments or unsupervised direct messages. */
data class FoodOrderChatMessage(
    val id: String,
    val body: String,
    val createdAt: String,
    val isMine: Boolean,
)
