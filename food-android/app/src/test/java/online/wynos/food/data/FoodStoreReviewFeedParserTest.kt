package online.wynos.food.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodStoreReviewFeedParserTest {
    @Test fun parsesVerifiedReviewAndRestaurantReplyFromWebRpc() {
        val response = FoodStoreReviewFeedParser.parse(
            """{"average":4.5,"count":2,"reviews":[
                {"id":"review-1","rating":5,"review_text":"อร่อย",
                 "tags":["ตรงปก","คุ้มราคา","ตรงปก"],
                 "reviewer_label":"พ***ม","verified_order":true,
                 "created_at":"2026-10-14T02:00:00Z",
                 "merchant_reply":"ขอบคุณค่ะ"},
                {"id":"review-2","rating":4,"review_text":null,
                 "verified_order":false,"tags":[]}
            ]}"""
        )
        assertEquals(4.5, response.average, 0.001)
        assertEquals(2, response.count)
        assertEquals(2, response.reviews.size)
        assertEquals(listOf("ตรงปก","คุ้มราคา"), response.reviews[0].tags)
        assertEquals("ขอบคุณค่ะ", response.reviews[0].merchantReply)
        assertTrue(response.reviews[0].verifiedOrder)
        assertFalse(response.reviews[1].verifiedOrder)
        assertEquals(null, response.reviews[1].text)
    }

    @Test fun rejectsMalformedAndDoesNotFabricateValidRatings() {
        assertThrows(IllegalArgumentException::class.java) {
            FoodStoreReviewFeedParser.parse("""[]""")
        }
        assertThrows(IllegalArgumentException::class.java) {
            FoodStoreReviewFeedParser.parse("""{"average":4.8,"reviews":[]}""")
        }
        assertThrows(IllegalArgumentException::class.java) {
            FoodStoreReviewFeedParser.parse("""{"average":8.1,"count":0,"reviews":[]}""")
        }
        val parsed = FoodStoreReviewFeedParser.parse(
            """{"average":0,"count":0,"reviews":[
                {"id":"fake-review","rating":6},{"id":"","rating":5}]}"""
        )
        assertTrue(parsed.reviews.isEmpty())
        assertEquals(0, parsed.count)
    }
}
