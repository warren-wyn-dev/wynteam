package online.wynos.food.ui

import online.wynos.food.data.FoodMenu
import online.wynos.food.data.FoodStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodHomeDiscoveryTest {
    private fun dish(id: String, name: String, category: String = "อาหารจานเดียว") =
        FoodMenu(id = id, name = name, category = category, description = null,
            price = "50", optionGroupNames = emptyList())

    private fun store(id: String, name: String, fee: String?, open: Boolean = true,
                      dishes: List<FoodMenu> = listOf(dish(id, "ผัดไทย"))) =
        FoodStore(id = id, name = name, description = null, isOpen = open,
            deliveryFee = fee, menu = dishes)

    @Test fun searchUsesOnlyRealStoreAndMenuNamesAndDeduplicates() {
        val a = store("a", "ร้านส้มตำ", "10", dishes = listOf(dish("m1", "ตำลาว", "ส้มตำ")))
        val b = store("b", "ร้านข้าวมันไก่", "15", dishes = listOf(dish("m2", "ข้าวมันไก่")))
        assertEquals(listOf("a"), visibleHomeStores(listOf(a, a, b), "ตำลาว", "all").map { it.id })
        assertEquals(listOf("b"), visibleHomeStores(listOf(a, b), "ข้าวมัน", "all").map { it.id })
        assertEquals(2, visibleHomeStores(listOf(a, a, b), "  ", "all").size)
    }

    @Test fun openAndActualCategoryFiltersWork() {
        val a = store("a", "A", "10", open = true,
            dishes = listOf(dish("m1", "ตำลาว", "ส้มตำ")))
        val b = store("b", "B", "2", open = false,
            dishes = listOf(dish("m2", "ข้าวมันไก่", "ข้าว")))
        assertEquals(listOf("a"), visibleHomeStores(listOf(a, b), "", "open").map { it.id })
        assertEquals(listOf("b"), visibleHomeStores(listOf(a, b), "", "category:ข้าว").map { it.id })
        assertEquals(listOf("ส้มตำ", "ข้าว"), publishedHomeCategories(listOf(a, b)))
    }

    @Test fun feeSortKeepsUnknownFeeLastAndStableWithinSameFee() {
        val a = store("a", "A", "10")
        val b = store("b", "B", null)
        val c = store("c", "C", "2.5")
        val d = store("d", "D", "10")
        assertEquals(listOf("c","a","d","b"),
            visibleHomeStores(listOf(a,b,c,d), "", "fee").map { it.id })
        assertTrue(canSortHomeByDeliveryFee(listOf(a,b)))
        assertFalse(canSortHomeByDeliveryFee(listOf(b)))
    }

    @Test fun noInventedCategoriesOrPriceFilterWhenCatalogEmpty() {
        assertTrue(publishedHomeCategories(emptyList()).isEmpty())
        assertFalse(canSortHomeByDeliveryFee(emptyList()))
        assertTrue(visibleHomeStores(emptyList(), "a", "all").isEmpty())
    }
}
