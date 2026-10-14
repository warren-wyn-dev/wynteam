package online.wynos.food.ui

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodAccountDeletionConfirmationTest {
    @Test fun thaiConfirmationRequiresExactPhrase() {
        assertTrue(FoodAccountDeletionConfirmation.isConfirmed(" ลบบัญชี ", "ลบบัญชี"))
        assertFalse(FoodAccountDeletionConfirmation.isConfirmed("ลบ บัญชี", "ลบบัญชี"))
    }

    @Test fun englishConfirmationIsCaseSensitive() {
        assertTrue(FoodAccountDeletionConfirmation.isConfirmed("DELETE WYNOS", "DELETE WYNOS"))
        assertFalse(FoodAccountDeletionConfirmation.isConfirmed("delete wynos", "DELETE WYNOS"))
        assertFalse(FoodAccountDeletionConfirmation.isConfirmed("", "DELETE WYNOS"))
    }
}
