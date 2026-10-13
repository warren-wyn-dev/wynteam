package online.wynos.food.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class FoodCartTest {
    private val spice = FoodOptionGroup("spicy", "ระดับความเผ็ด", true, 1,
        listOf(FoodOptionChoice("low", "เผ็ดน้อย", "0"), FoodOptionChoice("high", "เผ็ดมาก", "5")))
    private val menu = FoodMenu("menu", "ข้าวผัด", "อาหารไทย", null, "60", listOf("ระดับความเผ็ด"), listOf(spice))
    private val store = FoodStore("store", "ร้าน", null, true, "10", listOf(menu))

    @Test fun requiredChoicesAndTotals() {
        val draft = FoodCartDraft().add(store, menu, mapOf("spicy" to setOf("high")), 2)
        assertEquals("130", draft.estimatedSubtotal.stripTrailingZeros().toPlainString())
        assertEquals(2, draft.itemCount)
        val merged = draft.add(store, menu, mapOf("spicy" to setOf("high")), 1)
        assertEquals(1, merged.lines.size)
        assertEquals(3, merged.itemCount)
    }

    @Test(expected = IllegalArgumentException::class)
    fun missingRequiredChoiceFailsClosed() { FoodCartDraft().add(store, menu, emptyMap(), 1) }

    @Test(expected = IllegalArgumentException::class)
    fun crossStoreCartIsNotSilentlyCombined() {
        val first = FoodCartDraft().add(store, menu, mapOf("spicy" to setOf("low")), 1)
        first.add(store.copy(id = "other"), menu, mapOf("spicy" to setOf("low")), 1)
    }

    @Test(expected = IllegalArgumentException::class)
    fun unknownChoiceIsRejected() { FoodCartDraft().add(store, menu, mapOf("spicy" to setOf("forged")), 1) }

    @Test fun soldOutItemUnavailable() {
        assertTrue(!menu.copy(soldOutUntil = "2999-01-01T00:00:00Z").isAvailable(Instant.parse("2026-10-13T00:00:00Z")))
    }
    @Test fun merchantNotesKeepSeparatelyConfiguredLines() {
        val a = FoodCartDraft().add(store, menu, mapOf("spicy" to setOf("low")), 1, "ไม่ใส่ผัก")
        val b = a.add(store, menu, mapOf("spicy" to setOf("low")), 1, "แยกน้ำจิ้ม")
        assertEquals(2, b.lines.size)
        assertEquals("ไม่ใส่ผัก", b.lines[0].note)
        assertEquals("แยกน้ำจิ้ม", b.lines[1].note)
        assertEquals("120", b.estimatedSubtotal.stripTrailingZeros().toPlainString())
    }

    @Test(expected = IllegalArgumentException::class)
    fun notesCannotExceedWebLength() {
        FoodCartDraft().add(store, menu, mapOf("spicy" to setOf("low")), 1, "x".repeat(251))
    }
    @Test fun quantityUpdatesAndRemovesSpecificCustomizedItems() {
        val first = FoodCartDraft().add(store, menu, mapOf("spicy" to setOf("low")), 2, "ไม่ใส่ผัก")
        val another = first.add(store, menu, mapOf("spicy" to setOf("high")), 1, "ปกติ")
        val edited = another.withQuantity(first.lines[0].identity, 1)
        assertEquals(2, edited.lines.size)
        assertEquals(1, edited.lines[0].quantity)
        val removed = edited.withQuantity(first.lines[0].identity, 0)
        assertEquals(1, removed.lines.size)
        assertEquals("ปกติ", removed.lines.first().note)
        val empty = removed.withQuantity(removed.lines.first().identity, 0)
        assertEquals(0, empty.lines.size)
        assertEquals(null, empty.storeId)
    }
    @Test(expected = IllegalArgumentException::class)
    fun quantityEditRejectsUnknownLines() {
        FoodCartDraft().add(store, menu, mapOf("spicy" to setOf("low")), 1)
            .withQuantity("untrusted", 1)
    }

}
