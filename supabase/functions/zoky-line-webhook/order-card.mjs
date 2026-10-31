// Pure LINE Flex card builder. NEVER send phone, address, slip, or customer PII.
// The receiver is selected server-side after verifying the active store link.
// Postback parameters are NOT proof of permission: the webhook must re-check
// LINE sender, store membership, payment state, and current order state.
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function makeOrderFlexCard(input) {
  if (!input || typeof input !== 'object') throw new TypeError('invalid_order');
  const orderId = input.orderId;
  const orderNumber = input.orderNumber;
  const storeName = input.storeName;
  const totalBaht = input.totalBaht;
  if (typeof orderId !== 'string' || !UUID.test(orderId)) throw new TypeError('invalid_order_id');
  if (typeof orderNumber !== 'string' || !/^[A-Za-z0-9_-]{1,40}$/.test(orderNumber)) {
    throw new TypeError('invalid_order_number');
  }
  if (typeof storeName !== 'string' || storeName.trim().length < 1 ||
      storeName.trim().length > 80) throw new TypeError('invalid_store_name');
  if (typeof totalBaht !== 'number' || !Number.isFinite(totalBaht) ||
      totalBaht < 0 || totalBaht > 1000000) throw new TypeError('invalid_total');
  const total = totalBaht.toLocaleString('th-TH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const action = (label, kind, style) => ({
    type: 'button',
    style,
    height: 'sm',
    action: {
      type: 'postback',
      label,
      data: 'v=1&a=' + kind + '&oid=' + orderId,
      displayText: label + ' #' + orderNumber,
    },
  });
  return {
    type: 'flex',
    altText: 'ออเดอร์ใหม่ #' + orderNumber + ' รอร้านตอบรับ',
    contents: {
      type: 'bubble',
      body: {
        type: 'box',
        layout: 'vertical',
        spacing: 'md',
        contents: [
          { type: 'text', text: 'ออเดอร์ใหม่', weight: 'bold', size: 'xl', color: '#F93384' },
          { type: 'text', text: '#' + orderNumber, weight: 'bold', size: 'lg' },
          { type: 'text', text: storeName.trim(), size: 'sm', color: '#666666', wrap: true },
          { type: 'text', text: 'ยอดรวม ' + total + ' บาท', size: 'md', weight: 'bold' },
        ],
      },
      footer: {
        type: 'box',
        layout: 'vertical',
        spacing: 'sm',
        contents: [action('รับออเดอร์', 'accept', 'primary'), action('ปฏิเสธ', 'reject', 'secondary')],
      },
    },
  };
}

export function parseOrderPostback(value) {
  if (typeof value !== 'string' || value.length > 250) return null;
  const params = new URLSearchParams(value);
  const keys = [...params.keys()];
  if (keys.length !== 3 || new Set(keys).size !== 3) return null;
  if (params.get('v') !== '1') return null;
  const action = params.get('a');
  const orderId = params.get('oid');
  if (!['accept', 'reject'].includes(action) || !orderId || !UUID.test(orderId)) return null;
  return { action, orderId };
}
