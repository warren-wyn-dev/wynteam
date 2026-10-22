import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/merchant_controller.dart';
import '../data/merchant_repository.dart';
import 'order_dialogs.dart';

const green = Color(0xFF087F5B), ink = Color(0xFF182B25);
String money(dynamic value) =>
    '฿${(num.tryParse('$value') ?? 0).toStringAsFixed(2)}';
String dateLabel(dynamic value) {
  final date = DateTime.tryParse(
    '$value',
  )?.toUtc().add(const Duration(hours: 7));
  if (date == null) return '—';
  return '${date.day}/${date.month}/${date.year + 543} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class MerchantHome extends StatefulWidget {
  const MerchantHome({
    super.key,
    required this.repository,
    required this.onSignOut,
  });
  final MerchantRepository repository;
  final Future<void> Function() onSignOut;
  @override
  State<MerchantHome> createState() => _MerchantHomeState();
}

class _MerchantHomeState extends State<MerchantHome>
    with WidgetsBindingObserver {
  late final MerchantController c;
  Timer? timer;
  StreamSubscription<void>? orderSubscription;
  String? subscribedStore;
  bool pushEnabled = false, pushBusy = false;
  int page = 0;
  String query = '';
  bool foreground = true, signingOut = false;
  final labels = ['ภาพรวม', 'ออเดอร์', 'เมนูอาหาร', 'ยอดขาย', 'ร้านของฉัน'];
  final icons = [
    Icons.grid_view_rounded,
    Icons.receipt_long_outlined,
    Icons.restaurant_menu,
    Icons.bar_chart_rounded,
    Icons.storefront_outlined,
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c = MerchantController(widget.repository)..addListener(changed);
    unawaited(c.initialize());
    orderSubscription = widget.repository.orderChanges.listen((_) {
      if (!mounted) return;
      notice('มีการเปลี่ยนแปลงออเดอร์ กำลังอัปเดต');
      unawaited(c.refresh());
    });
    unawaited(readPushStatus());
    timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (foreground) unawaited(c.refresh());
    });
  }

  void changed() {
    if (!mounted) return;
    if (c.storeId != null && c.storeId != subscribedStore) {
      subscribedStore = c.storeId;
      unawaited(
        widget.repository.subscribe(c.storeId!).catchError((Object _) {}),
      );
    }
    setState(() {});
  }

  Future<void> readPushStatus() async {
    try {
      final value = await widget.repository.pushStatus();
      if (mounted) setState(() => pushEnabled = value['enabled'] == true);
    } catch (_) {}
  }

  Future<void> enablePush() async {
    if (pushBusy) return;
    setState(() => pushBusy = true);
    try {
      final result = await widget.repository.pushEnable();
      if (result['ok'] == true) {
        await readPushStatus();
        notice('เปิดการแจ้งเตือนแล้ว');
      } else {
        notice(switch (result['reason']) {
          'install-required' => 'บน iPhone/iPad กรุณาเพิ่มเว็บลงหน้าจอโฮมก่อน',
          'denied' => 'เบราว์เซอร์ปิดสิทธิ์แจ้งเตือน กรุณาเปิดในตั้งค่า',
          'not-configured' => 'ระบบแจ้งเตือนยังไม่ได้ตั้งค่า',
          _ => 'เปิดแจ้งเตือนไม่สำเร็จ กรุณาตรวจสิทธิ์เบราว์เซอร์',
        });
      }
    } catch (e) {
      notice(errorMessage(e));
    } finally {
      if (mounted) setState(() => pushBusy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) unawaited(c.refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    unawaited(orderSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(changed);
    c.dispose();
    super.dispose();
  }

  void notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> signOut() async {
    if (c.busy || signingOut) return;
    setState(() => signingOut = true);
    try {
      await widget.onSignOut();
    } catch (_) {
      notice('ออกจากระบบไม่สำเร็จ กรุณาลองอีกครั้ง');
    } finally {
      if (mounted) setState(() => signingOut = false);
    }
  }

  void navigate(int index) {
    setState(() => page = index);
    if (index == 0 && c.status != 'pending_acceptance') {
      unawaited(c.selectStatus('pending_acceptance'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              SizedBox(
                width: 230,
                child: Material(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(28, 28, 20, 0),
                        child: Text(
                          'zoky.',
                          style: TextStyle(
                            color: green,
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -3,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(28, 0, 20, 36),
                        child: Text(
                          'MERCHANT',
                          style: TextStyle(
                            color: green,
                            letterSpacing: 3,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      for (var i = 0; i < labels.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          child: ListTile(
                            selected: page == i,
                            selectedColor: green,
                            selectedTileColor: const Color(0xFFE6F4EC),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: Icon(icons[i]),
                            title: Text(labels[i]),
                            onTap: () => navigate(i),
                          ),
                        ),
                      const Spacer(),
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'เติบโตไปด้วยกัน 🌱\nทุกออเดอร์คือโอกาสใหม่',
                          style: TextStyle(color: green, height: 1.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        if (!wide)
                          const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Text(
                              'z.',
                              style: TextStyle(
                                fontSize: 32,
                                color: green,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        Expanded(
                          child: c.stores.length > 1
                              ? DropdownButtonFormField<String>(
                                  initialValue: c.storeId,
                                  isExpanded: true,
                                  items: c.stores
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s['id'] as String,
                                          child: Text(
                                            s['name'] as String,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: c.loading || c.busy
                                      ? null
                                      : (v) {
                                          if (v != null) {
                                            unawaited(c.selectStore(v));
                                          }
                                        },
                                )
                              : Text(
                                  c.store?['name'] ?? 'Zoky Merchant',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                        IconButton(
                          tooltip: 'รีเฟรชข้อมูล',
                          onPressed: c.loading || c.busy ? null : c.refresh,
                          icon: const Icon(Icons.refresh),
                        ),
                        IconButton(
                          tooltip: 'ออกจากระบบ',
                          onPressed: c.busy || signingOut ? null : signOut,
                          icon: const Icon(Icons.logout),
                        ),
                      ],
                    ),
                  ),
                  if (c.loading || c.busy)
                    const LinearProgressIndicator(minHeight: 3),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: c.refresh,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              wide ? 36 : 18,
                              16,
                              wide ? 36 : 18,
                              32,
                            ),
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    c.error == null
                                        ? Icons.cloud_done_outlined
                                        : Icons.cloud_off,
                                    color: c.error == null ? green : Colors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      c.updatedAt == null
                                          ? 'กำลังเชื่อมต่อร้านของคุณ'
                                          : 'ข้อมูลจริง • อัปเดต ${dateLabel(c.updatedAt!.toIso8601String())}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (c.error != null) errorBox(c.error!),
                              if (c.store == null &&
                                  !c.loading &&
                                  c.error == null)
                                box(
                                  Column(
                                    children: [
                                      const Icon(
                                        Icons.storefront_outlined,
                                        size: 52,
                                        color: green,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'ไม่พบร้านที่บัญชีนี้มีสิทธิ์จัดการ',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'ใช้บัญชีเจ้าของร้านเดิม หรือให้เจ้าของร้านเพิ่มคุณเป็นทีมงาน',
                                      ),
                                      TextButton(
                                        onPressed: openOriginal,
                                        child: const Text(
                                          'เปิด WYNOS Merchant',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (c.store != null)
                                ...switch (page) {
                                  0 => dashboard(),
                                  1 => orderPage(),
                                  2 => menuPage(),
                                  3 => reportPage(),
                                  _ => settingsPage(),
                                },
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: page,
              onDestinationSelected: navigate,
              destinations: List.generate(
                labels.length,
                (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  label: labels[i],
                ),
              ),
            ),
    );
  }

  Future<void> openOriginal() async {
    if (!await launchUrl(
      Uri.base.resolve('/merchant'),
      mode: LaunchMode.externalApplication,
    )) {
      notice('เปิดเว็บเดิมไม่สำเร็จ');
    }
  }

  Widget box(Widget child) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
  Widget errorBox(String text) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF9A2525))),
    ),
  );
  Widget heading(String title, String subtitle, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        ?action,
      ],
    ),
  );
  Widget section(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 14),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: ink,
      ),
    ),
  );
  Widget metric(String title, String value, IconData icon, String hint) => box(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: green),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: ink,
          ),
        ),
        Text(hint, style: const TextStyle(fontSize: 11, color: green)),
      ],
    ),
  );
  Widget stats() => LayoutBuilder(
    builder: (context, size) {
      final cols = size.maxWidth >= 800 ? 4 : 2;
      final data = [
        metric(
          'ยอดขายวันนี้',
          c.reportError == null ? money(c.report['today_sales']) : '—',
          Icons.payments_outlined,
          'ออเดอร์สำเร็จ • เวลาไทย',
        ),
        metric(
          'สำเร็จวันนี้',
          c.reportError == null ? '${c.report['today_orders'] ?? 0}' : '—',
          Icons.receipt_long_outlined,
          'นับตามวันที่สั่งซื้อ',
        ),
        metric(
          'ยอดขายเดือนนี้',
          c.reportError == null ? money(c.report['month_sales']) : '—',
          Icons.trending_up,
          'รวมทุกออเดอร์สำเร็จ',
        ),
        metric(
          'เมนูเปิดขาย',
          '${c.menu.where((f) => f['is_available'] == true).length}',
          Icons.restaurant_menu,
          'จาก ${c.menu.length} เมนู',
        ),
      ];
      return Wrap(
        spacing: 12,
        children: data
            .map(
              (w) => SizedBox(
                width: (size.maxWidth - 12 * (cols - 1)) / cols,
                child: w,
              ),
            )
            .toList(),
      );
    },
  );
  List<Widget> dashboard() => [
    heading('สวัสดี เจ้าของร้าน 👋', 'ดูแลทุกออเดอร์ เติบโตไปด้วยกัน'),
    Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: ink,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'พร้อมเสิร์ฟความอร่อยแล้วหรือยัง?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  c.store!['is_open'] == true
                      ? 'เปิดรับออเดอร์ • อัปเดตอัตโนมัติทุก 20 วินาที'
                      : 'ร้านปิดรับออเดอร์อยู่',
                  style: const TextStyle(color: Color(0xFFB7D6C8)),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => navigate(1),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD8F28C),
                    foregroundColor: ink,
                  ),
                  child: const Text('จัดการออเดอร์ →'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.ramen_dining, color: Color(0xFFD8F28C), size: 48),
        ],
      ),
    ),
    if (c.reportError != null) errorBox(c.reportError!),
    stats(),
    section('ออเดอร์รอรับ'),
    if (c.status == 'pending_acceptance') ...[
      if (c.orders.isEmpty && !c.loading)
        box(const Text('ยังไม่มีออเดอร์รอรับ')),
      ...c.orders.take(3).map(orderCard),
    ] else
      TextButton(
        onPressed: () => c.selectStatus('pending_acceptance'),
        child: const Text('ดูออเดอร์รอรับ'),
      ),
    section('โปรโมชั่นของร้าน'),
    if (c.campaignError != null) errorBox(c.campaignError!),
    ...c.campaigns.map(
      (p) => box(
        Row(
          children: [
            const Icon(Icons.local_offer_outlined, color: green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    campaignLabel(p),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(
              value: p['is_active'] == true,
              onChanged: c.writable && c.canCampaigns
                  ? (value) => c.mutate(
                      () => widget.repository.setCampaignActive(
                        c.storeId!,
                        p['id'],
                        value,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    ),
    if (c.campaigns.isEmpty && c.campaignError == null)
      box(const Text('ยังไม่มีโปรโมชั่น')),
    if (c.canCampaigns)
      OutlinedButton.icon(
        onPressed: c.writable ? addCampaign : null,
        icon: const Icon(Icons.add),
        label: const Text('สร้างโปรโมชั่น'),
      ),
  ];
  String campaignLabel(Json p) => switch (p['campaign_type']) {
    'free_delivery' =>
      'ส่งฟรี • ${p['scope'] == 'items' ? 'เฉพาะเมนู' : 'ทั้งร้าน'}',
    'fixed' => 'ลด ${money(p['discount_value'])}',
    _ =>
      'ลด ${p['discount_value']}% • ${p['scope'] == 'items' ? 'เฉพาะเมนู' : 'ทั้งร้าน'}',
  };
  List<Widget> orderPage() => [
    heading('ออเดอร์', 'ตรวจชำระเงินก่อนรับ และเริ่มจัดส่งเมื่อพร้อม'),
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: orderStatuses.entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: c.status == e.key,
                  onSelected: c.loading || c.busy
                      ? null
                      : (_) => c.selectStatus(e.key),
                ),
              ),
            )
            .toList(),
      ),
    ),
    const SizedBox(height: 20),
    if (c.orders.isEmpty && !c.loading)
      box(
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('ยังไม่มีออเดอร์ในสถานะนี้')),
        ),
      ),
    ...c.orders.map(orderCard),
    if (c.hasMore)
      OutlinedButton(
        onPressed: c.writable ? c.loadMore : null,
        child: const Text('โหลดออเดอร์เพิ่มเติม'),
      ),
    const SizedBox(height: 12),
    const Text(
      'อัปเดตผ่าน Realtime และตรวจข้อมูลซ้ำทุก 20 วินาที',
      style: TextStyle(color: Colors.grey, fontSize: 12),
    ),
  ];
  Widget orderCard(Json o) {
    final status = o['status'] as String;
    final next = nextStatuses[status];
    final allowed = status == 'ready_for_delivery'
        ? c.canDelivery
        : c.canOrders;
    return box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '#${o['order_number']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Chip(
                label: Text(orderStatuses[status] ?? status),
                backgroundColor: const Color(0xFFEDF5EE),
                side: BorderSide.none,
              ),
            ],
          ),
          Text(
            '${o['recipient_name']} • ${dateLabel(o['created_at'])}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          if (o['scheduled_for'] != null)
            Text(
              'นัดส่ง: ${dateLabel(o['scheduled_for'])}',
              style: const TextStyle(color: green),
            ),
          const Divider(height: 28),
          for (final item in (o['food_order_items'] as List? ?? []))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['item_name']} × ${item['quantity']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (item['selected_options'] is List &&
                      (item['selected_options'] as List).isNotEmpty)
                    Text(
                      optionLabel(item['selected_options'] as List),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  if ((item['item_note'] ?? '').toString().isNotEmpty)
                    Text(
                      'หมายเหตุเมนู: ${item['item_note']}',
                      style: const TextStyle(color: Color(0xFFAD7016)),
                    ),
                ],
              ),
            ),
          if ((o['customer_note'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'หมายเหตุลูกค้า: ${o['customer_note']}',
                style: const TextStyle(color: Color(0xFFAD7016)),
              ),
            ),
          Text(
            paymentStatuses[o['payment_status']] ?? o['payment_status'],
            style: TextStyle(
              color: o['payment_status'] == 'paid'
                  ? green
                  : Colors.orange.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (status == 'pending_acceptance' && o['payment_status'] != 'paid')
            if (o['payment_provider'] == 'stripe' ||
                (o['stripe_checkout_session_id'] != null &&
                    o['payment_slip_path'] == null))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'รอระบบยืนยันการชำระเงินอัตโนมัติ',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              )
            else if (o['payment_slip_path'] != null)
              TextButton(
                onPressed: c.writable && c.canOrders
                    ? () => reviewPayment(o)
                    : null,
                child: const Text('ตรวจการชำระเงิน'),
              ),
          if (o['payment_slip_path'] != null && o['payment_status'] == 'paid')
            TextButton(
              onPressed: () => showEvidence(o, 'slip'),
              child: const Text('ดูสลิปการชำระเงิน'),
            ),

          const SizedBox(height: 12),
          Text('จัดส่ง: ${o['shipping_address']}'),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: '${o['recipient_phone']}'),
              );
              notice('คัดลอกเบอร์โทรแล้ว');
            },
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: Text('${o['recipient_phone']}'),
          ),
          const SizedBox(height: 8),
          Text(
            'อาหาร ${money(o['subtotal'])} • ค่าส่ง ${money(o['delivery_fee'])}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          if ((num.tryParse('${o['campaign_discount']}') ?? 0) +
                  (num.tryParse('${o['delivery_discount']}') ?? 0) >
              0)
            Text(
              'ส่วนลด ${money((num.tryParse('${o['campaign_discount']}') ?? 0) + (num.tryParse('${o['delivery_discount']}') ?? 0))}',
              style: const TextStyle(fontSize: 12, color: green),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                money(o['total']),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              if (next != null)
                FilledButton(
                  onPressed:
                      c.writable &&
                          allowed &&
                          (status != 'pending_acceptance' ||
                              o['payment_status'] == 'paid')
                      ? () => advance(o, next)
                      : null,
                  child: Text(nextActions[status]!),
                ),
            ],
          ),
          if (status == 'out_for_delivery')
            FilledButton.icon(
              onPressed: c.writable && c.canDelivery
                  ? () => finishDelivery(o)
                  : null,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('แนบรูปและยืนยันส่งสำเร็จ'),
            ),
          if (status == 'delivered')
            TextButton(
              onPressed: () => showEvidence(o, 'proof'),
              child: const Text('ดูหลักฐานส่งสำเร็จ'),
            ),
          if (status != 'delivered' && status != 'cancelled' && c.canOrders)
            TextButton(
              onPressed: c.writable ? () => cancelOrder(o) : null,
              child: const Text(
                'ยกเลิกออเดอร์',
                style: TextStyle(color: Colors.red),
              ),
            ),
          if (o['refund_status'] == 'pending')
            const Text(
              'รอคืนเงิน • จัดการคืนเงินผ่านหน้าการเงินร้าน',
              style: TextStyle(color: Colors.orange),
            ),
        ],
      ),
    );
  }

  String optionLabel(List options) => options
      .map((e) {
        if (e is! Map) return '$e';
        final choices = e['choices'];
        if (choices is List) {
          return '${e['name'] ?? ''}: ${choices.map((v) => v is Map ? v['name'] ?? '' : '$v').join(', ')}';
        }
        return '${e['name'] ?? e['choice_name'] ?? ''}';
      })
      .join(' • ');
  Future<void> advance(Json o, String status) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nextActions[o['status']]!),
        content: Text(
          'ออเดอร์ #${o['order_number']}\n${o['recipient_name']} • ${money(o['total'])}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('กลับ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      if (await c.mutate(
        () => widget.repository.transition(c.storeId!, o['id'], status),
      )) {
        notice('อัปเดตออเดอร์แล้ว');
      }
    }
  }

  List<Widget> menuPage() => [
    heading(
      'เมนูอาหาร',
      'การบันทึกมีผลกับเมนูที่ลูกค้าเห็น',
      action: c.canManage
          ? FilledButton.icon(
              onPressed: c.writable ? () => editMenu() : null,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มเมนู'),
            )
          : null,
    ),
    TextField(
      onChanged: (v) => setState(() => query = v),
      decoration: const InputDecoration(
        hintText: 'ค้นหาเมนูอาหาร',
        prefixIcon: Icon(Icons.search),
      ),
    ),
    const SizedBox(height: 18),
    if (c.menu
        .where(
          (m) => '${m['name']}'.toLowerCase().contains(query.toLowerCase()),
        )
        .isEmpty)
      box(const Text('ไม่พบเมนู')),
    ...c.menu
        .where(
          (m) => '${m['name']}'.toLowerCase().contains(query.toLowerCase()),
        )
        .map(
          (m) => box(
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF5EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.restaurant, color: green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${m['category']} • ${money(m['price'])}',
                        style: const TextStyle(color: green, fontSize: 12),
                      ),
                      if (m['sold_out_until'] != null)
                        Text(
                          'หมดชั่วคราวถึง ${dateLabel(m['sold_out_until'])}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                          ),
                        ),
                    ],
                  ),
                ),
                if (c.canManage)
                  IconButton(
                    tooltip: 'แก้ไขเมนู',
                    onPressed: c.writable ? () => editMenu(m) : null,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                Switch(
                  value: m['is_available'] == true,
                  onChanged: c.writable && c.canManage
                      ? (v) => c.mutate(
                          () => widget.repository.saveMenu(c.storeId!, {
                            'is_available': v,
                          }, id: m['id']),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
  ];
  List<Widget> reportPage() => [
    heading('ยอดขายของร้าน', 'คำนวณจากข้อมูลทั้งหมดในระบบเดิม'),
    if (c.reportError != null) errorBox(c.reportError!),
    stats(),
    section('สรุปยอดขาย'),
    box(
      Column(
        children: [
          summary(
            'สัปดาห์นี้',
            c.reportError == null ? money(c.report['week_sales']) : '—',
          ),
          summary(
            'ยอดเฉลี่ยต่อออเดอร์',
            c.reportError == null ? money(c.report['average_order']) : '—',
          ),
          summary(
            'ออเดอร์สำเร็จทั้งหมด',
            c.reportError == null ? '${c.report['total_orders'] ?? 0}' : '—',
          ),
        ],
      ),
    ),
    section('เมนูขายดีตลอดการขาย'),
    box(
      Column(
        children: [
          if ((c.report['best'] as List? ?? []).isEmpty)
            const Text('ยังไม่มีข้อมูลการขาย'),
          for (final m in (c.report['best'] as List? ?? []))
            summary('${m['name']}', '${m['quantity']} รายการ'),
        ],
      ),
    ),
    const Text(
      'ยอดขายแสดงยอดรวมที่ลูกค้าชำระของออเดอร์สำเร็จ ยังไม่หัก GP หรือค่าธรรมเนียม',
      style: TextStyle(fontSize: 12, color: Colors.grey),
    ),
  ];
  Widget summary(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, color: green),
        ),
      ],
    ),
  );
  List<Widget> settingsPage() => [
    heading('ร้านของฉัน', 'ข้อมูลร้านเชื่อมกับระบบ WYNOS เดิม'),
    box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.storefront_outlined, size: 56, color: green),
          const SizedBox(height: 12),
          Text(
            c.store!['name'],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Text('โทร: ${c.store!['phone'] ?? '—'}'),
          const SizedBox(height: 8),
          Text('ที่อยู่: ${c.store!['address'] ?? '—'}'),
          if (c.store!['admin_suspended_at'] != null)
            errorBox('ร้านถูกระงับ กรุณาติดต่อทีม WYNOS'),
          if (c.store!['temporary_closed_until'] != null)
            Text(
              'พักร้านชั่วคราวถึง ${dateLabel(c.store!['temporary_closed_until'])}',
              style: const TextStyle(color: Colors.orange),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('เปิดรับออเดอร์'),
            subtitle: Text(
              c.store!['is_published'] == true
                  ? 'ร้านเผยแพร่อยู่ • ยึดเวลาเปิดและวันหยุดตามระบบเดิม'
                  : 'ร้านยังไม่เผยแพร่ ลูกค้ายังไม่เห็นร้าน',
            ),
            value: c.store!['is_open'] == true,
            onChanged:
                c.writable &&
                    c.canManage &&
                    c.store!['admin_suspended_at'] == null
                ? (v) => c.mutate(
                    () =>
                        widget.repository.saveStore(c.storeId!, {'is_open': v}),
                  )
                : null,
          ),
          if (c.canManage)
            OutlinedButton.icon(
              onPressed: c.writable ? editStore : null,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('แก้ไขข้อมูลร้าน'),
            ),
        ],
      ),
    ),
    box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'การแจ้งเตือนและบริการเพิ่มเติม',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'อัปเดตออเดอร์ผ่าน Realtime และตรวจซ้ำทุก 20 วินาที\nการเงิน คืนเงิน ทีมงาน ตั้งเวลา และตั้งค่ารับเงิน ใช้บริการเดิมของ Food',
          ),
          FilledButton.icon(
            onPressed: pushBusy ? null : enablePush,
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(
              pushBusy
                  ? 'กำลังเปิดแจ้งเตือน…'
                  : pushEnabled
                  ? 'ตรวจการแจ้งเตือนอีกครั้ง'
                  : 'เปิดแจ้งเตือนออเดอร์',
            ),
          ),
          TextButton(
            onPressed: openOriginal,
            child: const Text('การเงิน ทีมงาน และเครื่องมือร้านเพิ่มเติม →'),
          ),
        ],
      ),
    ),
  ];

  Future<void> reviewPayment(Json order) async {
    final id = c.storeId!;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentReviewDialog(
        repository: widget.repository,
        storeId: id,
        order: order,
        store: c.store ?? {},
        save: (status, note) => c.mutate(
          () => widget.repository.payment(id, order['id'], status, note: note),
        ),
        error: () => c.error,
      ),
    );
    if (result == true) notice('บันทึกการตรวจชำระเงินแล้ว');
  }

  Future<void> finishDelivery(Json order) async {
    final id = c.storeId!;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeliveryProofDialog(
        repository: widget.repository,
        storeId: id,
        orderId: order['id'],
        save: (method, path, note) => c.mutate(
          () => widget.repository.completeDelivery(
            id,
            order['id'],
            method,
            path,
            locationNote: note,
          ),
        ),
        error: () => c.error,
      ),
    );
    if (result == true) notice('ส่งสำเร็จและแจ้งลูกค้าแล้ว');
  }

  Future<void> cancelOrder(Json order) async {
    final note = await requestCancellation(
      context,
      order['order_number'],
      order['payment_status'] == 'paid',
    );
    if (note == null || !mounted) return;
    if (await c.mutate(
      () => widget.repository.transition(
        c.storeId!,
        order['id'],
        'cancelled',
        note: note,
      ),
    )) {
      notice('ยกเลิกออเดอร์แล้ว');
    }
  }

  Future<void> showEvidence(Json order, String kind) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(kind == 'slip' ? 'สลิปการชำระเงิน' : 'หลักฐานส่งสำเร็จ'),
        content: SizedBox(
          width: 480,
          child: FutureBuilder<String?>(
            future: widget.repository.signedUrl(c.storeId!, order['id'], kind),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) return Text(errorMessage(snapshot.error!));
              if (snapshot.data == null) {
                return const Text('ยังไม่มีรูปหลักฐาน');
              }
              return InteractiveViewer(
                child: Image.network(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, error, stack) =>
                      const Text('โหลดรูปไม่สำเร็จ กรุณาลองใหม่'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  Future<void> editMenu([Json? item]) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditorDialog(
        title: item == null ? 'เพิ่มเมนูอาหาร' : 'แก้ไขเมนูอาหาร',
        fields: [
          EditorField(
            'name',
            'ชื่อเมนู',
            initial: item?['name'] ?? '',
            maxLength: 160,
          ),
          EditorField(
            'price',
            'ราคา (บาท)',
            initial: item?['price']?.toString() ?? '',
            numeric: true,
          ),
          EditorField(
            'category',
            'หมวดหมู่',
            initial: item?['category'] ?? 'อาหาร',
            maxLength: 60,
          ),
          EditorField(
            'description',
            'รายละเอียดเมนู',
            initial: item?['description'] ?? '',
            required: false,
            maxLength: 1000,
          ),
        ],
        save: (values) => c.mutate(
          () => widget.repository.saveMenu(c.storeId!, {
            ...values,
            'price': double.parse(values['price']!),
          }, id: item?['id']),
        ),
        error: () => c.error,
      ),
    );
  }

  Future<void> editStore() async {
    final store = c.store!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditorDialog(
        title: 'แก้ไขข้อมูลร้าน',
        fields: [
          EditorField(
            'name',
            'ชื่อร้าน',
            initial: store['name'],
            maxLength: 120,
          ),
          EditorField(
            'phone',
            'เบอร์โทร',
            initial: store['phone'] ?? '',
            maxLength: 50,
          ),
          EditorField(
            'address',
            'ที่อยู่ร้าน',
            initial: store['address'] ?? '',
            maxLength: 800,
          ),
        ],
        save: (values) =>
            c.mutate(() => widget.repository.saveStore(c.storeId!, values)),
        error: () => c.error,
      ),
    );
  }

  Future<void> addCampaign() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditorDialog(
        title: 'สร้างโปรโมชั่นลดทั้งร้าน',
        description:
            'เริ่มใช้ทันที ไม่มีวันสิ้นสุด ลูกค้าจะได้รับส่วนลดผ่านระบบเดิม',
        fields: [
          const EditorField(
            'name',
            'ชื่อโปรโมชั่น',
            maxLength: 80,
            minLength: 2,
          ),
          const EditorField(
            'discount',
            'ส่วนลด (%)',
            numeric: true,
            percentage: true,
          ),
        ],
        save: (values) => c.mutate(
          () => widget.repository.createCampaign(
            c.storeId!,
            values['name']!,
            double.parse(values['discount']!),
          ),
        ),
        error: () => c.error,
      ),
    );
  }
}

class EditorField {
  const EditorField(
    this.key,
    this.label, {
    this.initial = '',
    this.required = true,
    this.numeric = false,
    this.percentage = false,
    this.maxLength = 100,
    this.minLength = 1,
  });
  final String key, label, initial;
  final bool required, numeric, percentage;
  final int maxLength, minLength;
}

class EditorDialog extends StatefulWidget {
  const EditorDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.save,
    required this.error,
    this.description,
  });
  final String title;
  final String? description;
  final List<EditorField> fields;
  final Future<bool> Function(Map<String, String>) save;
  final String? Function() error;
  @override
  State<EditorDialog> createState() => _EditorDialogState();
}

class _EditorDialogState extends State<EditorDialog> {
  final form = GlobalKey<FormState>();
  late final controllers = {
    for (final field in widget.fields)
      field.key: TextEditingController(text: field.initial),
  };
  bool saving = false, failed = false;
  String? error;
  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving || failed || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final ok = await widget.save({
        for (final e in controllers.entries) e.key: e.value.text.trim(),
      });
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        saving = false;
        failed = true;
        error =
            widget.error() ??
            'บันทึกไม่สำเร็จ กรุณาปิดแล้วรีเฟรชข้อมูลก่อนลองอีกครั้ง';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          failed = true;
          error = 'บันทึกไม่สำเร็จ กรุณาปิดแล้วรีเฟรชข้อมูลก่อนลองอีกครั้ง';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.description != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(widget.description!),
                  ),
                for (final field in widget.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextFormField(
                      controller: controllers[field.key],
                      enabled: !saving && !failed,
                      maxLength: field.maxLength,
                      keyboardType: field.numeric
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                      decoration: InputDecoration(labelText: field.label),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (field.required && value.length < field.minLength) {
                          return 'กรุณาใส่${field.label}อย่างน้อย ${field.minLength} ตัวอักษร';
                        }
                        if (field.numeric) {
                          final number = double.tryParse(value);
                          if (number == null ||
                              !number.isFinite ||
                              number < 0 ||
                              number > 999999 ||
                              (field.percentage &&
                                  (number <= 0 || number > 100))) {
                            return field.percentage
                                ? 'กรุณาใส่ส่วนลดมากกว่า 0 ถึง 100%'
                                : 'กรุณาใส่ราคา 0–999999 บาท';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                if (error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
        FilledButton(
          onPressed: saving || failed ? null : save,
          child: Text(saving ? 'กำลังบันทึก…' : 'บันทึก'),
        ),
      ],
    ),
  );
}
