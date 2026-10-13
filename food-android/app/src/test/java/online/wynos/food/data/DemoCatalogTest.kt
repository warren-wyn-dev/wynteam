package online.wynos.food.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DemoCatalogTest {
    @Test fun storesUseUniqueIdentifiers() {
        assertEquals(DemoCatalog.stores.size, DemoCatalog.stores.map { it.id }.distinct().size)
    }

    @Test fun samplePricesArePositiveAndNeverUsedForCheckout() {
        assertTrue(DemoCatalog.stores.flatMap { it.dishes }.all { it.priceBaht > 0 })
    }

    @Test fun unknownStoreIsNotFound() {
        assertNull(DemoCatalog.store("no-such-store"))
    }
}
