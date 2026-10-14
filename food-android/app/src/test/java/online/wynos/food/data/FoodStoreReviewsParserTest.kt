package online.wynos.food.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodStoreReviewsParserTest {
    @Test fun parsesOnlyValidApprovedWebReviewData() {
        val feed = FoodStoreReviewsParser.parse("""
          {
            "average": 4.5,
            "count": 12,
            "reviews": [
              {"id":"review-1","rating":5,"review_text":"อร่อย","tags":["แพ็กดี","คุ้มราคา"],
               "reviewer_label":"ว***น","verified_order":true,
               "created_at":"2026-10-14T01:23:00Z","merchant_reply":"ขอบคุณค่ะ"},
              {"id":"invalid","rating":9},
              {"rating":3,"review_text":"must not display"},
              {"id":"review-2","rating":4,"verified_order":false}
            ]
          }
        """.trimIndent())
        assertEquals(4.5, feed.average, 0.001)
        assertEquals(12, feed.count)
        assertEquals(2, feed.reviews.size)
        assertEquals("ว***น", feed.reviews[0].reviewerLabel)
        assertTrue(feed.reviews[0].verifiedOrder)
        assertEquals("ขอบคุณค่ะ", feed.reviews[0].merchantReply)
        assertEquals(listOf("แพ็กดี","คุ้มราคา"), feed.reviews[0].tags)
        assertNull(feed.reviews[1].text)
    }

    @Test fun untrustedReviewNumbersAreRejected() {
        val feed = FoodStoreReviewsParser.parse("""
          {"average":99,"count":-5,
           "reviews":[{"id":"bad","rating":-1},{"id":"okay","rating":1}]}
        """.trimIndent())
        assertEquals(0.0, feed.average, 0.01)
        assertEquals(0, feed.count)
        assertEquals(1, feed.reviews.size)
    }

    @Test fun unsupportedOrEmptyResponseIsSafe() {
        val feed = FoodStoreReviewsParser.parse("{}")
        assertEquals(0, feed.count)
        assertTrue(feed.reviews.isEmpty())
        assertTrue(FoodStoreReviewsParser.parse("[]").reviews.isEmpty())
    }
}
