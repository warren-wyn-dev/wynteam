package online.wynos.merchant

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

data class NativeChoice(val id: String, val name: String, val price: String)
data class NativeGroup(
    val id: String,
    val name: String,
    val required: Boolean,
    val maxSelect: Int,
    val choices: List<NativeChoice>,
)

fun parseMenuOptions(raw: JSONArray?): List<NativeGroup> {
    if (raw == null) return emptyList()
    return (0 until raw.length()).mapNotNull { i ->
        val group = raw.optJSONObject(i) ?: return@mapNotNull null
        val choices = group.optJSONArray("choices")
        NativeGroup(
            id = group.optString("id").ifBlank { UUID.randomUUID().toString() },
            name = group.optString("name"),
            required = group.optBoolean("required"),
            maxSelect = group.optInt("max_select", 1).coerceAtLeast(1),
            choices = (0 until (choices?.length() ?: 0)).mapNotNull { j ->
                val choice = choices?.optJSONObject(j) ?: return@mapNotNull null
                NativeChoice(
                    id = choice.optString("id").ifBlank { UUID.randomUUID().toString() },
                    name = choice.optString("name"),
                    price = choice.opt("price")?.toString() ?: "0"
                )
            }
        )
    }
}

fun encodeMenuOptions(groups: List<NativeGroup>): JSONArray {
    val output = JSONArray()
    groups.forEach { group ->
        val choices = JSONArray()
        group.choices.forEach { choice ->
            if (choice.name.trim().isNotBlank()) {
                choices.put(JSONObject().put("id", choice.id)
                    .put("name", choice.name.trim())
                    .put("price", (choice.price.toDoubleOrNull() ?: 0.0).coerceAtLeast(0.0)))
            }
        }
        if (group.name.trim().isNotBlank() && choices.length() > 0) {
            output.put(JSONObject().put("id", group.id)
                .put("name", group.name.trim())
                .put("required", group.required)
                .put("max_select", group.maxSelect.coerceIn(1, 20))
                .put("choices", choices))
        }
    }
    return output
}

@Composable
fun MenuOptionsEditor(groups: List<NativeGroup>, onChange: (List<NativeGroup>) -> Unit) {
    Column(Modifier.fillMaxWidth()) {
        Text("ตัวเลือกเสริม", style = MaterialTheme.typography.titleMedium)
        Text("ขนาด · ความเผ็ด · ท็อปปิง · ของเสริม", style = MaterialTheme.typography.bodySmall)
        groups.forEachIndexed { index, group ->
            ElevatedCard(Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
                Column(Modifier.padding(12.dp)) {
                    OutlinedTextField(value = group.name,
                        onValueChange = { value -> onChange(groups.toMutableList().apply { set(index, group.copy(name = value)) }) },
                        label = { Text("ชื่อกลุ่ม") }, modifier = Modifier.fillMaxWidth())
                    Row {
                        Text("บังคับเลือก", modifier = Modifier.weight(1f))
                        Switch(checked = group.required, onCheckedChange = {
                            onChange(groups.toMutableList().apply { set(index, group.copy(required = it)) })
                        })
                    }
                    OutlinedTextField(
                        value = group.maxSelect.toString(),
                        onValueChange = { value ->
                            onChange(groups.toMutableList().apply {
                                set(index, group.copy(maxSelect = (value.toIntOrNull() ?: 1).coerceIn(1, 20)))
                            })
                        },
                        label = { Text("เลือกได้สูงสุด") }, modifier = Modifier.fillMaxWidth()
                    )
                    group.choices.forEachIndexed { child, choice ->
                        OutlinedTextField(value = choice.name, onValueChange = { value ->
                            onChange(groups.toMutableList().apply {
                                set(index, group.copy(choices = group.choices.toMutableList().apply {
                                    set(child, choice.copy(name = value))
                                }))
                            })
                        }, label = { Text("ชื่อตัวเลือก") }, modifier = Modifier.fillMaxWidth())
                        OutlinedTextField(value = choice.price, onValueChange = { value ->
                            onChange(groups.toMutableList().apply {
                                set(index, group.copy(choices = group.choices.toMutableList().apply {
                                    set(child, choice.copy(price = value))
                                }))
                            })
                        }, label = { Text("ราคาเพิ่ม (บาท)") }, modifier = Modifier.fillMaxWidth())
                        TextButton(onClick = {
                            onChange(groups.toMutableList().apply {
                                set(index, group.copy(choices = group.choices.filterIndexed { j, _ -> j != child }))
                            })
                        }) { Text("ลบตัวเลือก") }
                    }
                    OutlinedButton(onClick = {
                        onChange(groups.toMutableList().apply {
                            set(index, group.copy(choices = group.choices + NativeChoice(
                                "choice-" + UUID.randomUUID(), "", "0")))
                        })
                    }) { Text("+ เพิ่มตัวเลือก") }
                    TextButton(onClick = { onChange(groups.filterIndexed { j, _ -> j != index }) }) {
                        Text("ลบกลุ่ม")
                    }
                }
            }
        }
        OutlinedButton(onClick = {
            onChange(groups + NativeGroup(
                "group-" + UUID.randomUUID(), "", false, 1,
                listOf(NativeChoice("choice-" + UUID.randomUUID(), "", "0"))
            ))
        }, modifier = Modifier.fillMaxWidth()) { Text("+ เพิ่มกลุ่มตัวเลือก") }
    }
}
