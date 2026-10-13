package online.wynos.food.data

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigDecimal

class FoodCheckoutReviewGuardTest {
    private val menu = FoodMenu("menu-1","Food","Main",null,"60",emptyList())
    private val store = FoodStore("store-1","Restaurant",null,true,"10",listOf(menu))
    private val cart = FoodCartDraft().add(store,menu,emptyMap(),1,"")
    private val quote = FoodServerQuote(
        BigDecimal("60"), BigDecimal("10"), BigDecimal.ZERO, BigDecimal.ZERO,
        BigDecimal("70"), null, false, null,
    )
    private val address = FoodCustomerAddress("address-1","Home","QA","081","Street",null,
        true,16.0,103.0)

    @Test fun reviewRequiresServerQuoteAndValidPinnedAddress() {
        assertTrue(FoodCheckoutReviewGuard.canReview(cart,quote,address,false,false))
        assertFalse(FoodCheckoutReviewGuard.canReview(cart,null,address,false,false))
        assertFalse(FoodCheckoutReviewGuard.canReview(cart,quote,null,false,false))
        assertFalse(FoodCheckoutReviewGuard.canReview(cart,quote,address.copy(latitude=null),false,false))
        assertFalse(FoodCheckoutReviewGuard.canReview(cart,quote,address,true,false))
        assertFalse(FoodCheckoutReviewGuard.canReview(cart,quote,address,false,true))
        assertFalse(FoodCheckoutReviewGuard.canReview(FoodCartDraft(),quote,address,false,false))
        assertFalse(FoodCheckoutReviewGuard.canReview(cart,quote.copy(needsLocation=true),address,false,false))
    }
}
