package online.wynos.food.ui

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodSignupValidationTest {
    @Test fun acceptsValidMatchingCredentials() {
        assertTrue(FoodSignupValidation.canSubmit(" user@example.com ", "safe-passphrase", "safe-passphrase"))
    }

    @Test fun rejectsMalformedEmailAndWhitespace() {
        assertFalse(FoodSignupValidation.canSubmit("userexample.com", "safe-passphrase", "safe-passphrase"))
        assertFalse(FoodSignupValidation.canSubmit("user @example.com", "safe-passphrase", "safe-passphrase"))
        assertFalse(FoodSignupValidation.canSubmit("u@localhost", "safe-passphrase", "safe-passphrase"))
    }

    @Test fun rejectsShortMismatchedOrExcessivePasswords() {
        assertFalse(FoodSignupValidation.canSubmit("user@example.com", "short", "short"))
        assertFalse(FoodSignupValidation.canSubmit("user@example.com", "safe-passphrase", "different"))
        assertFalse(FoodSignupValidation.canSubmit("user@example.com", "a".repeat(129), "a".repeat(129)))
    }
}
