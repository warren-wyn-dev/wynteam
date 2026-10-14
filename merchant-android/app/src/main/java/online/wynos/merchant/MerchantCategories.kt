package online.wynos.merchant

import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import org.json.JSONObject

data class CategoryDraft(val original: String?, val name: String)

@Composable
fun MerchantCategoryManager(
    state: MerchantState,
    vm: MerchantViewModel,
    onClose: () -> Unit
) {
    val preferred = state.store?.optJSONArray("menu_category_order")?.let { array ->
        (0 until array.length()).map { array.optString(it) }
    }.orEmpty()
    val discovered = state.menu.map { it.optString("category").ifBlank { "อื่น ๆ" } }.distinct()
    val initial = (preferred + discovered).filter { it.isNotBlank() }.distinct()
    var rows by remember(state.store) { mutableStateOf(initial.map { CategoryDraft(it, it) }) }
    var newName by remember { mutableStateOf("") }
    var moving by remember { mutableIntStateOf(-1) }
    val latestRows by rememberUpdatedState(rows)
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        TextButton(onClick = onClose) { Text("‹ กลับไปเมนู") }
        Text("จัดการหมวดหมู่", style = MaterialTheme.typography.titleLarge)
        Text("แตะค้างแล้วลากทั้งแถวเพื่อจัดเรียง หรือใช้ปุ่มขึ้น–ลง")
        OutlinedTextField(newName, { newName = it }, label = { Text("หมวดหมู่ใหม่") },
            modifier = Modifier.fillMaxWidth())
        Button(onClick = {
            val name = newName.trim()
            if (name.isNotEmpty() && rows.none { it.name.equals(name, true) }) {
                rows = rows + CategoryDraft(null, name)
                newName = ""
            }
        }, enabled = newName.isNotBlank()) { Text("+ เพิ่มหมวดหมู่") }
        rows.forEachIndexed { index, item ->
            val move: (Int) -> Unit = { step ->
                val now = latestRows
                val current = now.indexOfFirst { it.original == item.original && it.name == item.name }
                val target = current + step
                if (current >= 0 && target in now.indices)
                    rows = now.toMutableList().apply { add(target, removeAt(current)) }
            }
            val currentMove by rememberUpdatedState(move)
            ElevatedCard(
                modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp)
                    .pointerInput(item.original, item.name) {
                        var dy = 0f
                        detectDragGesturesAfterLongPress(
                            onDragStart = { dy = 0f },
                            onDragEnd = { dy = 0f },
                            onDragCancel = { dy = 0f },
                            onDrag = { change, amount ->
                                change.consume()
                                dy += amount.y
                                val threshold = 52.dp.toPx()
                                if (dy > threshold) { currentMove(1); dy = 0f }
                                if (dy < -threshold) { currentMove(-1); dy = 0f }
                            }
                        )
                    }
            ) {
                Column(Modifier.padding(12.dp)) {
                    OutlinedTextField(item.name, { next ->
                        rows = rows.toMutableList().apply { set(index, item.copy(name = next)) }
                    }, label = { Text("ชื่อหมวดหมู่") }, modifier = Modifier.fillMaxWidth())
                    Row {
                        TextButton(onClick = { move(-1) }, enabled = index > 0) { Text("↑ ขึ้น") }
                        TextButton(onClick = { move(1) }, enabled = index < rows.lastIndex) { Text("↓ ลง") }
                    }
                }
            }
        }
        Row {
            TextButton(onClick = onClose) { Text("ยกเลิก") }
            Spacer(Modifier.width(8.dp))
            Button(onClick = { vm.saveCategoryChanges(rows); onClose() },
                enabled = !state.busy && rows.isNotEmpty() &&
                    rows.none { it.name.isBlank() } &&
                    rows.map { it.name.trim().lowercase() }.distinct().size == rows.size) {
                Text("บันทึกหมวดหมู่")
            }
        }
    }
}
