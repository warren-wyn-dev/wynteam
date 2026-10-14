package online.wynos.merchant

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.PrintManager
import android.print.pdf.PrintedPdfDocument
import org.json.JSONObject
import java.io.FileOutputStream
import java.io.IOException

/**
 * Native Android Print Framework: no WebView or printer vendor SDK required.
 * Layout is adapted to printer-selected page dimensions; shops can save as PDF.
 */
object MerchantPrinter {
    fun print(context: Context, store: JSONObject, order: JSONObject, addressOnly: Boolean) {
        val title = if (addressOnly) "WYNOS-Address-" else "WYNOS-Receipt-"
        val filename = title + order.optString("order_number", "order") + ".pdf"
        val service = context.getSystemService(Context.PRINT_SERVICE) as PrintManager
        service.print(filename, object : PrintDocumentAdapter() {
            private var attributes: PrintAttributes = PrintAttributes.Builder()
                .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
                .setResolution(PrintAttributes.Resolution("pdf", "PDF", 300, 300))
                .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
                .build()

            override fun onLayout(oldAttributes: PrintAttributes?, newAttributes: PrintAttributes,
                                  cancellationSignal: CancellationSignal,
                                  callback: LayoutResultCallback, extras: Bundle?) {
                attributes = newAttributes
                if (cancellationSignal.isCanceled) {
                    callback.onLayoutCancelled()
                    return
                }
                val info = PrintDocumentInfo.Builder(filename)
                    .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                    .setPageCount(1).build()
                callback.onLayoutFinished(info, true)
            }

            override fun onWrite(pages: Array<out PageRange>?, destination: ParcelFileDescriptor,
                                 cancellationSignal: CancellationSignal,
                                 callback: WriteResultCallback) {
                if (cancellationSignal.isCanceled) {
                    callback.onWriteCancelled()
                    return
                }
                val document = PrintedPdfDocument(context, attributes)
                try {
                    val page = document.startPage(0)
                    drawPage(page.canvas, page.info.pageWidth.toFloat(),
                        page.info.pageHeight.toFloat(), store, order, addressOnly)
                    document.finishPage(page)
                    FileOutputStream(destination.fileDescriptor).use { document.writeTo(it) }
                    callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
                } catch (error: Exception) {
                    callback.onWriteFailed(error.message ?: "ไม่สามารถพิมพ์ได้")
                } finally {
                    document.close()
                }
            }
        }, PrintAttributes.Builder().setMediaSize(PrintAttributes.MediaSize.ISO_A4)
            .setColorMode(PrintAttributes.COLOR_MODE_MONOCHROME).build())
    }

    private fun drawPage(canvas: Canvas, width: Float, height: Float,
                         store: JSONObject, order: JSONObject, addressOnly: Boolean) {
        val pen = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = android.graphics.Color.BLACK
            textSize = 12f
            typeface = Typeface.create("sans-serif", Typeface.NORMAL)
        }
        val margin = 30f
        var y = margin + 15f
        val maxWidth = width - margin * 2
        fun line(raw: String, heading: Boolean = false) {
            pen.typeface = Typeface.create("sans-serif",
                if (heading) Typeface.BOLD else Typeface.NORMAL)
            pen.textSize = if (heading) 16f else 12f
            for (part in raw.split("\n")) {
                if (part.isBlank()) { y += 10f; continue }
                var remaining = part
                while (remaining.isNotEmpty() && y < height - margin) {
                    val count = pen.breakText(remaining, true, maxWidth, null).coerceAtLeast(1)
                    canvas.drawText(remaining.take(count), margin, y, pen)
                    remaining = remaining.drop(count)
                    y += if (heading) 23f else 18f
                }
            }
        }
        val number = order.optString("order_number")
        if (addressOnly) {
            line("WYNOS Merchant · ใบจ่าหน้า", true)
            line("ออเดอร์ #$number")
            line("ผู้รับ", true)
            line(order.optString("recipient_name"))
            line("โทร " + order.optString("recipient_phone"))
            line(order.optString("shipping_address"))
            if (!order.isNull("customer_note") && order.optString("customer_note").isNotBlank())
                line("หมายเหตุ: " + order.optString("customer_note"))
            line("ผู้ส่ง", true)
            line(store.optString("name"))
            if (!store.isNull("phone")) line(store.optString("phone"))
        } else {
            line(store.optString("name"), true)
            line(if (store.optBoolean("tax_invoice_enabled"))
                "ใบเสร็จรับเงิน / ข้อมูลภาษี" else "ใบออเดอร์ / ใบเสร็จอย่างย่อ")
            if (!order.isNull("receipt_legal_name")) line(order.optString("receipt_legal_name"))
            if (!order.isNull("receipt_tax_id")) line("เลขผู้เสียภาษี: " + order.optString("receipt_tax_id"))
            if (!order.isNull("receipt_tax_branch")) line("สาขา " + order.optString("receipt_tax_branch"))
            if (!order.isNull("receipt_tax_address")) line(order.optString("receipt_tax_address"))
            line("ออเดอร์ #$number")
            line("เวลา: " + order.optString("created_at"))
            val items = order.optJSONArray("food_order_items")
            line("รายการอาหาร", true)
            for (index in 0 until (items?.length() ?: 0)) {
                val item = items?.optJSONObject(index) ?: continue
                val quantity = item.optInt("quantity", 1)
                line("$quantity × " + item.optString("item_name") + "  " +
                    String.format(java.util.Locale.US, "%.2f บาท",
                        item.optDouble("unit_price", 0.0) * quantity))
                val options = item.optJSONArray("selected_options")
                for (choice in 0 until (options?.length() ?: 0)) {
                    line("  + " + options?.optJSONObject(choice)?.optString("choice_name"))
                }
                if (!item.isNull("item_note")) line("  " + item.optString("item_note"))
            }
            line("ค่าอาหาร: " + order.optString("subtotal") + " บาท")
            line("ส่วนลด: " + order.optString("campaign_discount", "0") + " บาท")
            line("ค่าส่ง: " + order.optString("delivery_fee") + " บาท")
            line("ส่วนลดค่าส่ง: " + order.optString("delivery_discount", "0") + " บาท")
            line("ยอดสุทธิ: " + order.optString("total") + " บาท", true)
            line("ผู้รับ: " + order.optString("recipient_name"))
            line("โทร: " + order.optString("recipient_phone"))
            line("ที่อยู่: " + order.optString("shipping_address"))
            line("โปรดตรวจสอบข้อมูลภาษีก่อนใช้เป็นเอกสารทางบัญชี")
        }
    }
}
