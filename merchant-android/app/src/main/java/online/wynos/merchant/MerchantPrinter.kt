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
import java.util.Locale

/** Native printing; no WebView and no silent truncation on long orders. */
object MerchantPrinter {
    private data class PrintLine(val value: String, val heading: Boolean = false)

    fun print(context: Context, store: JSONObject, order: JSONObject, addressOnly: Boolean) {
        val label = if (addressOnly) "Address" else "Receipt"
        val filename = "WYNOS-" + label + "-" + order.optString("order_number", "order") + ".pdf"
        val service = context.getSystemService(Context.PRINT_SERVICE) as PrintManager
        val content = buildContent(store, order, addressOnly)

        service.print(filename, object : PrintDocumentAdapter() {
            private var attributes = PrintAttributes.Builder()
                .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
                .setResolution(PrintAttributes.Resolution("pdf", "PDF", 300, 300))
                .setMinMargins(PrintAttributes.Margins.NO_MARGINS).build()

            override fun onLayout(oldAttributes: PrintAttributes?, newAttributes: PrintAttributes,
                                  cancellationSignal: CancellationSignal,
                                  callback: LayoutResultCallback, extras: Bundle?) {
                attributes = newAttributes
                if (cancellationSignal.isCanceled) {
                    callback.onLayoutCancelled()
                    return
                }
                // Layout depends on the physical printer's selected paper size/font fallback.
                callback.onLayoutFinished(
                    PrintDocumentInfo.Builder(filename)
                        .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                        .setPageCount(PrintDocumentInfo.PAGE_COUNT_UNKNOWN)
                        .build(),
                    true
                )
            }

            override fun onWrite(pages: Array<out PageRange>?, destination: ParcelFileDescriptor,
                                 cancellationSignal: CancellationSignal,
                                 callback: WriteResultCallback) {
                val document = PrintedPdfDocument(context, attributes)
                try {
                    if (cancellationSignal.isCanceled) {
                        callback.onWriteCancelled()
                        return
                    }
                    drawPaginated(document, content, cancellationSignal)
                    if (cancellationSignal.isCanceled) {
                        callback.onWriteCancelled()
                        return
                    }
                    FileOutputStream(destination.fileDescriptor).use { stream ->
                        document.writeTo(stream)
                    }
                    callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
                } catch (error: Exception) {
                    if (cancellationSignal.isCanceled) callback.onWriteCancelled()
                    else callback.onWriteFailed(error.message ?: "ไม่สามารถพิมพ์ได้")
                } finally {
                    document.close()
                }
            }
        }, PrintAttributes.Builder()
            .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
            .setColorMode(PrintAttributes.COLOR_MODE_MONOCHROME)
            .build())
    }

    private fun drawPaginated(document: PrintedPdfDocument, content: List<PrintLine>,
                              cancellationSignal: CancellationSignal) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = android.graphics.Color.BLACK
            typeface = Typeface.create("sans-serif", Typeface.NORMAL)
        }
        val margin = 34f
        var pageNumber = 0
        var page = document.startPage(pageNumber)
        var y = margin + 15f
        var maxWidth = (page.info.pageWidth - 2 * margin).coerceAtLeast(100f)
        var bottom = page.info.pageHeight - margin

        fun newPage() {
            document.finishPage(page)
            pageNumber++
            page = document.startPage(pageNumber)
            y = margin + 15f
            maxWidth = (page.info.pageWidth - 2 * margin).coerceAtLeast(100f)
            bottom = page.info.pageHeight - margin
        }

        for (line in content) {
            if (cancellationSignal.isCanceled) break
            paint.typeface = Typeface.create("sans-serif",
                if (line.heading) Typeface.BOLD else Typeface.NORMAL)
            paint.textSize = if (line.heading) 16f else 12f
            val lineHeight = if (line.heading) 23f else 18f
            for (paragraph in line.value.split("\n")) {
                if (cancellationSignal.isCanceled) break
                var remainder = paragraph
                if (remainder.isEmpty()) {
                    if (y + lineHeight > bottom) newPage()
                    y += lineHeight
                }
                while (remainder.isNotEmpty()) {
                    if (cancellationSignal.isCanceled) break
                    if (y + lineHeight > bottom) newPage()
                    val consumed = paint.breakText(remainder, true, maxWidth, null)
                        .coerceAtLeast(1)
                    page.canvas.drawText(remainder.substring(0, consumed), margin, y, paint)
                    remainder = remainder.substring(consumed)
                    y += lineHeight
                }
            }
        }
        document.finishPage(page)
    }

    private fun buildContent(store: JSONObject, order: JSONObject, addressOnly: Boolean): List<PrintLine> {
        val text = mutableListOf<PrintLine>()
        fun line(value: String, heading: Boolean = false) {
            text.add(PrintLine(value, heading))
        }

        val number = order.optString("order_number")
        if (addressOnly) {
            line("WYNOS Merchant · ใบจ่าหน้า", true)
            line("ออเดอร์ #" + number)
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
            // This is a merchant order record, not a certified electronic tax invoice.
            line("ใบออเดอร์ / เอกสารสรุปคำสั่งซื้อ")
            if (!order.isNull("receipt_legal_name")) line(order.optString("receipt_legal_name"))
            if (!order.isNull("receipt_tax_id")) line("เลขผู้เสียภาษี: " + order.optString("receipt_tax_id"))
            if (!order.isNull("receipt_tax_branch")) line("สาขา " + order.optString("receipt_tax_branch"))
            if (!order.isNull("receipt_tax_address")) line(order.optString("receipt_tax_address"))
            line("ออเดอร์ #" + number)
            line("เวลา: " + order.optString("created_at"))
            line("รายการอาหาร", true)
            val items = order.optJSONArray("food_order_items")
            for (index in 0 until (items?.length() ?: 0)) {
                val item = items?.optJSONObject(index) ?: continue
                val quantity = item.optInt("quantity", 1)
                line(quantity.toString() + " × " + item.optString("item_name") + "  " +
                    String.format(Locale.US, "%.2f บาท", item.optDouble("unit_price", 0.0) * quantity))
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
            line("ตรวจสอบความถูกต้องของข้อมูลภาษีก่อนนำไปใช้ทางบัญชี")
        }
        return text
    }
}
