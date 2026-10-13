package online.wynos.food.data

/**
 * Fictional offline UI fixtures. Not sourced from WYNOS customer or merchant data.
 * Replace only after validating the real Supabase RLS/RPC contracts.
 */
data class DemoStore(
    val id: String,
    val name: String,
    val category: String,
    val dishes: List<DemoDish>,
)

data class DemoDish(val name: String, val priceBaht: Int)

object DemoCatalog {
    val stores = listOf(
        DemoStore(
            id = "sample-a",
            name = "ร้านตัวอย่าง A",
            category = "อาหารตามสั่ง",
            dishes = listOf(DemoDish("ข้าวกะเพรา", 55), DemoDish("ข้าวผัด", 50)),
        ),
        DemoStore(
            id = "sample-b",
            name = "ร้านตัวอย่าง B",
            category = "อาหารไทย",
            dishes = listOf(DemoDish("ผัดไทย", 65), DemoDish("ต้มยำ", 80)),
        ),
    )

    fun store(id: String): DemoStore? = stores.firstOrNull { it.id == id }
}
