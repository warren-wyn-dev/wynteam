package online.wynos.food.ui

/**
 * Native form checks only. Supabase Auth remains authoritative for password
 * requirements, duplicate-email handling, verification and rate limits.
 */
object FoodSignupValidation {
    private val emailPattern = Regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]{2,}$")

    fun canSubmit(email: String, password: String, confirmation: String): Boolean =
        emailPattern.matches(email.trim()) &&
            password.length in 8..128 &&
            password == confirmation
}
