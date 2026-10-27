import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/merchant_controller.dart';
import '../data/merchant_repository.dart';
import '../widgets/merchant_tool_icon.dart';
import 'order_dialogs.dart';
import 'fulfillment_panels.dart';
import 'store_settings_panels.dart';

const brand = Color(0xFFD61256), ink = Color(0xFF16161A);
const success = Color(0xFF1F8A4C), brandSoft = Color(0xFFFFEFF5);
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
  String? category;
  String menuSort = 'default';
  bool foreground = true, signingOut = false;
  final labels = ['หน้าหลัก', 'ออเดอร์', 'เมนูอาหาร', 'เพิ่มเติม'];
  final icons = [
    Icons.storefront_outlined,
    Icons.receipt_long_outlined,
    Icons.restaurant_menu,
    Icons.grid_view_rounded,
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
      backgroundColor: page == 0 ? const Color(0xFFF6F6F8) : Colors.white,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: page == 0
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFEFF5),
                    Color(0xFFF7FAFC),
                    Color(0xFFF6F6F8),
                  ],
                  stops: [0, .3, 1],
                )
              : null,
        ),
        child: SafeArea(
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
                        const SizedBox(height: 24),
                        for (var i = 0; i < labels.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            child: ListTile(
                              selected: (page >= 3 ? 3 : page) == i,
                              selectedColor: brand,
                              selectedTileColor: const Color(0xFFFFEFF5),
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
                            'ร้านของคุณ พร้อมเติบโต\nไปด้วยกันกับ ZOKY',
                            style: TextStyle(color: brand, height: 1.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    header(),
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
                              key: ValueKey(page),
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                wide ? 36 : 18,
                                16,
                                wide ? 36 : 18,
                                32,
                              ),
                              children: [
                                if (page != 0) ...[
                                  Row(
                                    children: [
                                      Icon(
                                        c.error == null
                                            ? Icons.cloud_done_outlined
                                            : Icons.cloud_off,
                                        color: c.error == null
                                            ? success
                                            : Colors.red,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          c.updatedAt == null
                                              ? 'กำลังเชื่อมต่อร้านของคุณ'
                                              : 'อัปเดตล่าสุด ${dateLabel(c.updatedAt!.toIso8601String())}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF6B6B76),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                ],
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
                                          color: brand,
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
                                if (c.store == null)
                                  TextButton.icon(
                                    onPressed: c.busy || signingOut
                                        ? null
                                        : signOut,
                                    icon: const Icon(Icons.logout),
                                    label: const Text('ออกจากระบบ'),
                                  ),
                                if (c.store != null && page > 3)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () => navigate(3),
                                      icon: const Icon(Icons.chevron_left),
                                      label: const Text('เพิ่มเติม'),
                                    ),
                                  ),
                                if (c.store != null)
                                  ...switch (page) {
                                    0 => dashboard(),
                                    1 => orderPage(),
                                    2 => menuPage(),
                                    3 => morePage(),
                                    4 => reportPage(),
                                    5 => settingsPage(),
                                    6 => promotionsPage(),
                                    _ => qualityPage(),
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
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: page >= 3 ? 3 : page,
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
      // legacy=1: /merchant itself now redirects back to this app.
      Uri.base.resolve('/merchant?legacy=1'),
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
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF6B6B76), fontSize: 13),
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
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: brandSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: brand, size: 22),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(color: Color(0xFF6B6B76), fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: ink,
          ),
        ),
        Text(
          hint,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B76)),
        ),
      ],
    ),
  );
  Widget stats() => LayoutBuilder(
    builder: (context, size) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
      final cols = size.maxWidth < 340 || largeText
          ? 1
          : (size.maxWidth >= 800 ? 4 : 2);
      final data = [
        metric(
          'ยอดขายวันนี้',
          c.updatedAt != null && c.reportError == null
              ? money(c.report['today_sales'])
              : '—',
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
  Widget header() => Container(
    padding: const EdgeInsets.fromLTRB(22, 18, 12, 8),
    color: page == 0 ? null : Colors.white,
    child: Row(
      children: [
        Expanded(
          child: c.stores.length > 1
              ? DropdownButton<String>(
                  value: c.storeId,
                  isExpanded: true,
                  hint: const Text('เลือกร้าน'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                  underline: const SizedBox.shrink(),
                  items: c.stores
                      .map(
                        (store) => DropdownMenuItem(
                          value: store['id'] as String,
                          child: Text(
                            store['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: c.loading || c.busy
                      ? null
                      : (id) {
                          if (id != null) unawaited(c.selectStore(id));
                        },
                )
              : Text(
                  c.store?['name'] ?? 'ร้านของคุณ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
        ),
        IconButton(
          tooltip: 'การแจ้งเตือน',
          onPressed: () => openTool('notifications'),
          icon: Icon(
            pushEnabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_outlined,
            color: brand,
          ),
        ),
      ],
    ),
  );

  Widget storeSwitch() => Switch.adaptive(
    value: c.store!['is_open'] == true,
    activeTrackColor: success,
    onChanged:
        c.writable && c.canManage && c.store!['admin_suspended_at'] == null
        ? (value) => c.mutate(
            () => widget.repository.saveStore(c.storeId!, {'is_open': value}),
          )
        : null,
  );

  Widget tool(
    String label,
    IconData icon,
    Color color,
    VoidCallback? onTap, {
    bool compact = false,
  }) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 6 : 14, horizontal: 4),
      child: Column(
        children: [
          Container(
            width: compact ? 44 : 58,
            height: compact ? 44 : 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: onTap == null ? const Color(0xFF8A8A94) : color,
              size: compact ? 24 : 30,
            ),
          ),
          SizedBox(height: compact ? 6 : 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );

  Widget tools(List<Widget> items, {bool compact = false}) => LayoutBuilder(
    builder: (context, size) {
      final cols =
          size.maxWidth < (compact ? 280 : 340) ||
              MediaQuery.textScalerOf(context).scale(14) > 19
          ? 2
          : 4;
      return Wrap(
        children: items
            .map((item) => SizedBox(width: size.maxWidth / cols, child: item))
            .toList(),
      );
    },
  );

  Future<void> openTool(String toolName) async {
    final storeId = c.storeId;
    if (storeId == null) return;
    final url = Uri.base
        .resolve('/merchant')
        .replace(
          queryParameters: {
            'legacy': '1',
            'merchant-tool': toolName,
            'merchant-store': storeId,
          },
        );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      notice('เปิดเครื่องมือร้านไม่สำเร็จ กรุณาลองอีกครั้ง');
    }
  }

  Widget homePanel(
    Widget child, {
    VoidCallback? onTap,
    String? label,
    double radius = 22,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
    Gradient? gradient,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    shadowColor: const Color(0x0D50364A),
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(gradient: gradient),
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : Semantics(
              container: true,
              explicitChildNodes: true,
              button: true,
              label: label,
              onTap: onTap,
              child: InkWell(
                excludeFromSemantics: true,
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
            ),
    ),
  );

  Widget homeTool(
    String label,
    int index,
    IconData fallback,
    VoidCallback? onTap,
  ) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Column(
          children: [
            Opacity(
              opacity: onTap == null ? .4 : 1,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: MerchantToolIcon(
                  index: index,
                  size: 60,
                  fallback: fallback,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: onTap == null ? const Color(0xFF8A8A94) : ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> showStoreStatus() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ListenableBuilder(
              listenable: c,
              builder: (context, _) {
                if (c.store == null) {
                  return const Text('ไม่พบร้านที่มีสิทธิ์จัดการ');
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'สถานะร้าน',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      c.store?['status_text'] ??
                          (c.store?['is_open'] == true
                              ? 'เปิดรับออเดอร์'
                              : 'ปิดรับออเดอร์'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: Text('สวิตช์รับออเดอร์ของร้าน')),
                        Semantics(
                          container: true,
                          label: 'เปิดรับออเดอร์',
                          child: storeSwitch(),
                        ),
                      ],
                    ),
                    const Text(
                      'ลูกค้าสั่งได้ตามเวลาเปิด วันหยุด และสถานะเผยแพร่ของร้าน',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B6B76)),
                    ),
                    if (c.error != null) errorBox(c.error!),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(openTool('store'));
                      },
                      icon: const Icon(Icons.schedule),
                      label: const Text('ตั้งเวลาเปิดร้านและวันหยุด'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<({String label, bool done, String? tool, int? destination})>
  readiness() {
    final store = c.store ?? {};
    bool filled(String key) => (store[key] ?? '').toString().trim().isNotEmpty;
    return [
      (
        label: 'ข้อมูลติดต่อ เวลาเปิด และพื้นที่จัดส่ง',
        done:
            filled('phone') &&
            filled('address') &&
            filled('business_hours') &&
            filled('delivery_area'),
        tool: 'store',
        destination: null,
      ),
      (
        label: 'ช่องทางรับเงิน',
        done:
            store['stripe_payments_enabled'] == true ||
            (filled('promptpay_name') && filled('promptpay_id')) ||
            (filled('bank_account_name') && filled('bank_account_number')) ||
            filled('payment_qr_path'),
        tool: 'store',
        destination: null,
      ),
      (
        label: 'เปิดขายเมนูอย่างน้อย 1 รายการ',
        done: c.menu.any((item) => item['is_available'] == true),
        tool: null,
        destination: 2,
      ),
      (
        label: 'เผยแพร่ร้านให้ลูกค้าเห็น',
        done: store['is_published'] == true,
        tool: 'store',
        destination: null,
      ),
    ];
  }

  Future<void> showReadiness() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'เตรียมร้านให้พร้อม',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ตรวจจากข้อมูลร้านปัจจุบัน การเผยแพร่ยังผ่านการตรวจของระบบ',
                  style: TextStyle(color: Color(0xFF6B6B76), fontSize: 12),
                ),
                for (final item in readiness())
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item.done
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: item.done ? success : const Color(0xFF8A8A94),
                    ),
                    title: Text(item.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (item.destination != null) {
                        navigate(item.destination!);
                      } else {
                        unawaited(openTool(item.tool!));
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget salesSummary() => homePanel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'ยอดขายวันนี้',
                style: TextStyle(fontSize: 15, color: Color(0xFF6B6B76)),
              ),
            ),
            Icon(Icons.chevron_right, color: Color(0xFF6B6B76)),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: salesAmount(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 16,
              color: Color(0xFF6B6B76),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.updatedAt == null
                    ? 'กำลังโหลดยอดขาย'
                    : c.reportError == null
                    ? '${c.report['today_orders'] ?? 0} ออเดอร์สำเร็จ'
                    : 'โหลดข้อมูลยอดขายไม่สำเร็จ',
                style: const TextStyle(color: Color(0xFF6B6B76), fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    ),
    onTap: () => navigate(4),
    label: 'ดูยอดขายวันนี้',
    gradient: const LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [Colors.white, Colors.white, Color(0xFFFFEFF5)],
      stops: [0, .45, 1],
    ),
  );

  Widget salesAmount() {
    if (c.updatedAt == null || c.reportError != null) {
      return const Text('—', style: TextStyle(fontSize: 36, color: brand));
    }
    final value = (num.tryParse('${c.report['today_sales']}') ?? 0)
        .toStringAsFixed(2)
        .split('.');
    final whole = value.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '฿$whole'),
          TextSpan(
            text: '.${value.last}',
            style: const TextStyle(fontSize: 25, letterSpacing: -.4),
          ),
        ],
      ),
      style: const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: brand,
        letterSpacing: -1,
      ),
    );
  }

  List<Widget> dashboard() {
    final store = c.store!;
    final effectiveOpen = store['effective_open'] == true;
    final steps = readiness();
    final done = steps.where((step) => step.done).length;
    return [
      homePanel(
        Row(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: effectiveOpen ? success : const Color(0xFF8A8A94),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    store['status_text'] ??
                        (store['is_open'] == true
                            ? 'เปิดรับออเดอร์'
                            : 'ปิดรับออเดอร์'),
                    style: TextStyle(
                      color: effectiveOpen ? success : ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if ((store['business_hours'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty)
                    Text(
                      '(${store['business_hours']})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B6B76),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: brand,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: Colors.white,
                size: 21,
              ),
            ),
          ],
        ),
        onTap: showStoreStatus,
        label: 'แก้ไขสถานะร้าน',
        radius: 40,
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      ),
      if (c.reportError != null) errorBox(c.reportError!),
      salesSummary(),
      homePanel(
        tools([
          homeTool(
            'การเงิน',
            0,
            Icons.account_balance_wallet_outlined,
            c.canManage ? () => openTool('finance') : null,
          ),
          homeTool(
            'โฆษณา',
            1,
            Icons.campaign_outlined,
            c.canManage ? () => openTool('ads') : null,
          ),
          homeTool(
            'โปรโมชั่น',
            2,
            Icons.local_offer_outlined,
            () => navigate(6),
          ),
          homeTool(
            'แคมเปญ',
            3,
            Icons.shopping_bag_outlined,
            c.canManage ? () => openTool('campaigns') : null,
          ),
          homeTool(
            'คุณภาพร้าน',
            4,
            Icons.verified_user_outlined,
            () => navigate(7),
          ),
          homeTool(
            'ฟีดแบ็ก',
            5,
            Icons.chat_bubble_outline,
            () => openTool('feedback'),
          ),
          homeTool(
            'ช่วยเหลือ',
            6,
            Icons.support_outlined,
            () => openTool('help'),
          ),
          homeTool('การตั้งค่า', 7, Icons.settings_outlined, () => navigate(5)),
        ], compact: true),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      homePanel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'เตรียมร้านให้พร้อม',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.chevron_right, color: Color(0xFF6B6B76)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'เช็กลิสต์การเตรียมร้าน',
                    style: TextStyle(color: Color(0xFF6B6B76), fontSize: 13),
                  ),
                ),
                Text(
                  c.updatedAt == null
                      ? '—/${steps.length}'
                      : '$done/${steps.length}',
                  style: const TextStyle(
                    color: brand,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Semantics(
              label: 'เตรียมร้านพร้อม $done จาก ${steps.length} ขั้นตอน',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: c.updatedAt == null ? null : done / steps.length,
                  minHeight: 7,
                  backgroundColor: brandSoft,
                  color: brand,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              c.updatedAt == null
                  ? 'กำลังตรวจข้อมูลร้าน'
                  : done == steps.length
                  ? 'ข้อมูลพื้นฐานครบแล้ว'
                  : 'เหลืออีก ${steps.length - done} ขั้นตอนที่ต้องทำ',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B76)),
            ),
          ],
        ),
        onTap: c.updatedAt == null ? null : showReadiness,
        label: 'เตรียมร้านให้พร้อม',
      ),
      if (c.updatedAt != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'อัปเดต ${dateLabel(c.updatedAt!.toIso8601String())}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B76)),
          ),
        ),
    ];
  }

  List<Widget> qualityPage() {
    final quality = c.qualityData;
    final qualityAvailable = quality['available'] == true;
    final reviewCount = (quality['count'] as num?)?.toInt() ?? 0;
    return [
      homePanel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'คุณภาพร้าน',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'รีวิวทั้งหมด',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B6B76)),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, size) {
                final items = [
                  qualityMetric(
                    'คะแนนร้าน',
                    qualityAvailable &&
                            reviewCount > 0 &&
                            quality['average'] is num
                        ? '${(quality['average'] as num).toStringAsFixed(1)} /5'
                        : '—',
                    Icons.star_border_rounded,
                  ),
                  qualityMetric(
                    'รีวิวรอตอบ',
                    qualityAvailable ? '${quality['unanswered'] ?? 0}' : '—',
                    Icons.chat_bubble_outline,
                  ),
                ];
                return MediaQuery.textScalerOf(context).scale(14) > 19
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          items.first,
                          const SizedBox(height: 14),
                          items.last,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: items.first),
                          Expanded(child: items.last),
                        ],
                      );
              },
            ),
            if (c.qualityError != null) ...[
              const SizedBox(height: 10),
              Text(
                c.qualityError!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9A2525)),
              ),
              TextButton(
                onPressed: c.loading ? null : c.refresh,
                child: const Text('ลองโหลดรีวิวอีกครั้ง'),
              ),
            ] else if (!qualityAvailable || reviewCount == 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  c.updatedAt == null
                      ? 'กำลังโหลดข้อมูลรีวิว'
                      : qualityAvailable
                      ? 'ยังไม่มีรีวิวจากลูกค้า'
                      : 'ยังไม่มีข้อมูลรีวิวสำหรับร้านนี้',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B6B76),
                  ),
                ),
              ),
          ],
        ),
      ),
      FilledButton.icon(
        onPressed: () => openTool('feedback'),
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('ดูรีวิวและตอบกลับ'),
      ),
    ];
  }

  Widget qualityMetric(String label, String value, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B76)),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: label == 'คะแนนร้าน' ? const Color(0xFFB77900) : brand,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ],
  );

  Widget emptyState(IconData icon, String title, String subtitle) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 12),
    child: Column(
      children: [
        Icon(icon, size: 48, color: const Color(0xFF8A8A94)),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B6B76),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B76)),
        ),
      ],
    ),
  );

  List<Widget> morePage() => [
    heading('เพิ่มเติม', 'เครื่องมือสำหรับร้านของคุณ'),
    box(
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.storefront_outlined, color: brand, size: 36),
        title: Text(
          c.store!['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          c.store!['is_published'] == true
              ? 'เผยแพร่บน ZOKY แล้ว'
              : 'ร้านยังไม่เผยแพร่',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => navigate(5),
      ),
    ),
    section('เครื่องมือร้าน'),
    tools([
      tool(
        'รายงานยอดขาย',
        Icons.bar_chart_rounded,
        const Color(0xFF8256CF),
        () => navigate(4),
      ),
      tool(
        'ประวัติออเดอร์',
        Icons.history,
        brand,
        c.loading || c.busy
            ? null
            : () {
                navigate(1);
                unawaited(c.selectStatus('delivered'));
              },
      ),
      tool('โปรโมชั่น', Icons.local_offer_outlined, brand, () => navigate(6)),
      tool(
        'ตั้งค่าร้าน',
        Icons.settings_outlined,
        const Color(0xFF2862A7),
        () => navigate(5),
      ),
    ]),
    const SizedBox(height: 18),
    box(
      Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined, color: brand),
            title: const Text('การแจ้งเตือน'),
            subtitle: Text(
              pushEnabled
                  ? 'เปิดแจ้งเตือนออเดอร์แล้ว'
                  : 'รับการแจ้งเตือนเมื่อมีออเดอร์ใหม่',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: pushBusy ? null : enablePush,
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.wallet_outlined, color: success),
            title: const Text('การเงินและเครื่องมือเพิ่มเติม'),
            subtitle: const Text(
              'เปิดหน้าจัดการเดิม: การเงิน แคมเปญ โฆษณา และทีมงาน',
            ),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: openOriginal,
          ),
        ],
      ),
    ),
    TextButton.icon(
      onPressed: c.busy || signingOut ? null : signOut,
      icon: const Icon(Icons.logout),
      label: const Text('ออกจากระบบ'),
    ),
  ];

  List<Widget> promotionsPage() => [
    heading('โปรโมชั่นของร้าน', 'จัดการส่วนลดและโปรโมชั่นที่ลูกค้าเห็น'),
    if (c.campaignError != null) errorBox(c.campaignError!),
    ...c.campaigns.map(
      (p) => box(
        Row(
          children: [
            const Icon(Icons.local_offer_outlined, color: brand),
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
                    style: const TextStyle(
                      color: Color(0xFF6B6B76),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              container: true,
              label: 'เปิดโปรโมชั่น ${p['name']}',
              child: Switch(
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
                  // Pickup orders ready for collection share this status.
                  label: Text(
                    e.key == 'ready_for_delivery' ? 'พร้อมส่ง/ให้รับ' : e.value,
                  ),
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
      emptyState(
        Icons.shopping_bag_outlined,
        'ไม่มีออเดอร์ในแท็บนี้',
        'ออเดอร์จะแสดงตามสถานะที่เลือก',
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
      style: TextStyle(color: Color(0xFF6B6B76), fontSize: 12),
    ),
  ];
  Widget orderCard(Json o) {
    final status = o['status'] as String;
    final next = orderNextStatus(o);
    // Collecting a pickup order is an order-desk step, not a delivery one.
    final allowed =
        status == 'ready_for_delivery' && o['fulfillment_type'] != 'pickup'
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
                label: Text(orderStatusLabel(o)),
                backgroundColor: status == 'delivered'
                    ? const Color(0xFFE9F7EF)
                    : brandSoft,
                labelStyle: TextStyle(
                  color: status == 'delivered' ? success : brand,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide.none,
              ),
            ],
          ),
          Text(
            '${o['recipient_name']} • ${dateLabel(o['created_at'])}',
            style: const TextStyle(color: Color(0xFF6B6B76), fontSize: 12),
          ),
          Chip(
            label: Text(
              o['fulfillment_type'] == 'pickup' ? 'รับเอง' : 'ส่งเอง',
            ),
          ),
          if (o['payment_method'] == 'cod')
            const Chip(label: Text('เก็บเงินปลายทาง')),
          if (o['fulfillment_type'] == 'pickup') ...[
            Text('เวลานัดรับ: ${dateLabel(o['pickup_at'])}'),
            Text('รหัสรับอาหาร: ${o['pickup_code'] ?? '—'}'),
          ],
          if (o['cancel_requested_at'] != null) ...[
            const Text(
              'ลูกค้าขอยกเลิก',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(o['cancel_request_note'] ?? ''),
            Wrap(
              children: [
                TextButton(
                  onPressed: c.writable && c.canOrders
                      ? () => resolveCancel(o, false)
                      : null,
                  child: const Text('ปฏิเสธคำขอยกเลิก'),
                ),
                TextButton(
                  onPressed: c.writable && c.canOrders
                      ? () => resolveCancel(o, true)
                      : null,
                  child: const Text('อนุมัติคำขอยกเลิก'),
                ),
              ],
            ),
          ],
          if (o['scheduled_for'] != null)
            Text(
              'นัดส่ง: ${dateLabel(o['scheduled_for'])}',
              style: const TextStyle(color: brand),
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
                      style: const TextStyle(
                        color: Color(0xFF6B6B76),
                        fontSize: 12,
                      ),
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
                  ? success
                  : Colors.orange.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!['delivered', 'cancelled'].contains(status) &&
              o['payment_method'] != 'cod' &&
              o['payment_status'] != 'paid')
            if (o['payment_provider'] == 'stripe' ||
                (o['stripe_checkout_session_id'] != null &&
                    o['payment_slip_path'] == null))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'รอระบบยืนยันการชำระเงินอัตโนมัติ',
                  style: TextStyle(color: Color(0xFF6B6B76), fontSize: 12),
                ),
              )
            else if (o['payment_slip_path'] != null ||
                o['payment_status'] == 'pending')
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
          if (o['fulfillment_type'] != 'pickup')
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
            style: const TextStyle(color: Color(0xFF6B6B76), fontSize: 12),
          ),
          if ((num.tryParse('${o['campaign_discount']}') ?? 0) +
                  (num.tryParse('${o['delivery_discount']}') ?? 0) >
              0)
            Text(
              'ส่วนลด ${money((num.tryParse('${o['campaign_discount']}') ?? 0) + (num.tryParse('${o['delivery_discount']}') ?? 0))}',
              style: const TextStyle(fontSize: 12, color: brand),
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
                              o['payment_status'] == 'paid' ||
                              o['payment_method'] == 'cod')
                      ? () => advance(o, next)
                      : null,
                  child: Text(orderNextAction(o)!),
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
          if (status == 'delivered' && o['fulfillment_type'] != 'pickup')
            TextButton(
              onPressed: () => showEvidence(o, 'proof'),
              child: const Text('ดูหลักฐานส่งสำเร็จ'),
            ),
          if (!['delivered', 'cancelled'].contains(status) && c.canOrders)
            TextButton(
              onPressed: c.writable ? () => cancelOrder(o) : null,
              child: const Text(
                'ยกเลิกออเดอร์',
                style: TextStyle(color: Colors.red),
              ),
            ),
          if (o['refund_status'] == 'pending' &&
              o['payment_provider'] != 'stripe' &&
              o['payment_method'] != 'cod')
            OutlinedButton(
              onPressed: c.writable && c.canManage
                  ? () => refundOrder(o)
                  : null,
              child: const Text('โอนคืนแล้ว + แนบสลิป'),
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
    int eta =
        (num.tryParse(
                  '${o['eta_minutes'] ?? c.store?['prep_time_max_minutes'] ?? 30}',
                )?.toInt() ??
                30)
            .clamp(1, 240);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(orderNextAction(o)!),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ออเดอร์ #${o['order_number']}\n${o['recipient_name']} • ${money(o['total'])}',
            ),
            if (status == 'preparing')
              DropdownButtonFormField<int>(
                initialValue: eta,
                decoration: const InputDecoration(labelText: 'เวลาทำโดยประมาณ'),
                items: ({15, 30, 45, 60, eta}.toList()..sort())
                    .map(
                      (minutes) => DropdownMenuItem(
                        value: minutes,
                        child: Text('$minutes นาที'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) eta = value;
                },
              ),
          ],
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
        () => widget.repository.transition(
          c.storeId!,
          o['id'],
          status,
          etaMinutes: status == 'preparing' ? eta : null,
        ),
      )) {
        notice('อัปเดตออเดอร์แล้ว');
      }
    }
  }

  List<Widget> menuPage() {
    final categories = c.menu
        .map((m) => '${m['category'] ?? 'ทั่วไป'}')
        .toSet()
        .toList();
    final selectedCategory = categories.contains(category) ? category : null;
    final rows = c.menu
        .where(
          (m) =>
              (selectedCategory == null ||
                  '${m['category'] ?? 'ทั่วไป'}' == selectedCategory) &&
              '${m['name']} ${m['category'] ?? ''}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    if (menuSort != 'default') {
      rows.sort(
        (a, b) => menuSort == 'price'
            ? ((a['price'] as num?) ?? 0).compareTo((b['price'] as num?) ?? 0)
            : '${a['name']}'.compareTo('${b['name']}'),
      );
    }
    final groups = <String, List<Json>>{};
    for (final row in rows) {
      groups.putIfAbsent('${row['category'] ?? 'ทั่วไป'}', () => []).add(row);
    }
    return [
      heading(
        'เมนูอาหาร',
        'จัดการเมนูที่ลูกค้าเห็น',
        action: c.canManage
            ? FilledButton.icon(
                onPressed: c.writable ? () => editMenu() : null,
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มเมนู'),
              )
            : null,
      ),
      TextField(
        onChanged: (value) => setState(() => query = value),
        decoration: InputDecoration(
          hintText: 'ค้นหาเมนูหรือหมวดหมู่',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32),
            borderSide: const BorderSide(color: Color(0xFFEBEBEF)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          PopupMenuButton<String>(
            initialValue: menuSort,
            tooltip: 'จัดลำดับเมนู',
            onSelected: (value) => setState(() => menuSort = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'default', child: Text('ลำดับร้าน')),
              PopupMenuItem(value: 'name', child: Text('ชื่อเมนู')),
              PopupMenuItem(value: 'price', child: Text('ราคาน้อยไปมาก')),
            ],
            child: const Chip(
              avatar: Icon(Icons.swap_vert, size: 18),
              label: Text('จัดลำดับ'),
              deleteIcon: Icon(Icons.expand_more),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'เลือกหมวดหมู่',
            onSelected: (value) =>
                setState(() => category = value == '' ? null : value),
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('ทุกหมวดหมู่')),
              ...categories.map(
                (name) => PopupMenuItem(value: name, child: Text(name)),
              ),
            ],
            child: Chip(
              avatar: const Icon(Icons.grid_view_outlined, size: 18),
              label: Text(selectedCategory ?? 'ทุกหมวดหมู่'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (rows.isEmpty)
        emptyState(
          Icons.restaurant_menu,
          'ไม่พบเมนู',
          'ลองค้นหาด้วยชื่ออื่น หรือเพิ่มเมนูใหม่',
        ),
      for (final group in groups.entries)
        Card(
          margin: const EdgeInsets.only(bottom: 18),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            initiallyExpanded: true,
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            title: Text(
              group.key,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${group.value.length} เมนู',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B76)),
            ),
            children: [
              for (var index = 0; index < group.value.length; index++) ...[
                const Divider(height: 1),
                menuRow(group.value[index]),
              ],
            ],
          ),
        ),
    ];
  }

  Widget menuRow(Json item) => LayoutBuilder(
    builder: (context, size) {
      final compact =
          size.maxWidth < 380 ||
          MediaQuery.textScalerOf(context).scale(14) > 19;
      final controls = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            label: 'เปิดขาย ${item['name']}',
            child: Switch.adaptive(
              value: item['is_available'] == true,
              activeTrackColor: success,
              onChanged: c.writable && c.canManage
                  ? (value) => c.mutate(
                      () => widget.repository.saveMenu(c.storeId!, {
                        'is_available': value,
                      }, id: item['id']),
                    )
                  : null,
            ),
          ),
          if (c.canManage)
            IconButton(
              tooltip: 'แก้ไขเมนู ${item['name']}',
              onPressed: c.writable ? () => editMenu(item) : null,
              icon: const Icon(Icons.more_horiz),
            ),
        ],
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child:
                        item['image_url'] is String &&
                            (item['image_url'] as String).isNotEmpty
                        ? Image.network(
                            item['image_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stack) =>
                                menuPlaceholder(),
                          )
                        : menuPlaceholder(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (item['options'] as List? ?? []).isEmpty
                            ? 'ไม่มีตัวเลือกเสริม'
                            : '${(item['options'] as List).length} กลุ่มตัวเลือกเสริม',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B6B76),
                        ),
                      ),
                      if (item['sold_out_until'] != null)
                        Text(
                          'หมดชั่วคราวถึง ${dateLabel(item['sold_out_until'])}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9A5800),
                          ),
                        ),
                      const SizedBox(height: 3),
                      Text(
                        money(item['price']),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (!compact) controls,
              ],
            ),
            if (compact)
              Align(alignment: Alignment.centerRight, child: controls),
          ],
        ),
      );
    },
  );

  Widget menuPlaceholder() => Container(
    color: brandSoft,
    child: const Icon(Icons.restaurant, color: brand, size: 28),
  );

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
      style: TextStyle(fontSize: 12, color: Color(0xFF6B6B76)),
    ),
  ];
  Widget summary(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, color: brand),
        ),
      ],
    ),
  );
  List<Widget> settingsPage() => [
    heading('ตั้งค่าร้าน', 'ข้อมูลที่ลูกค้าเห็นบน ZOKY'),
    box(
      FulfillmentSettingsPanel(
        store: c.store!,
        enabled: c.writable && c.canConfigure,
        save: (values) => c.mutate(
          () => widget.repository.setFulfillment(c.storeId!, values),
        ),
        error: () => c.error,
      ),
    ),
    if (c.canManage) ...[
      box(
        PaymentChannelsPanel(
          store: c.store!,
          enabled: c.writable,
          save: (values) =>
              c.mutate(() => widget.repository.saveStore(c.storeId!, values)),
          // A cancelled picker uploads nothing and changes nothing.
          pickQr: () =>
              c.mutate(() => widget.repository.pickPaymentQr(c.storeId!)),
          error: () => c.error,
        ),
      ),
      box(
        BusinessHoursPanel(
          store: c.store!,
          enabled: c.writable,
          save: (values) =>
              c.mutate(() => widget.repository.saveStore(c.storeId!, values)),
          error: () => c.error,
        ),
      ),
    ],
    box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.storefront_outlined, size: 56, color: brand),
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
            'อัปเดตออเดอร์ผ่าน Realtime และตรวจซ้ำทุก 20 วินาที\nการเงิน ทีมงาน โฆษณา และแคมเปญ ยังเปิดในหน้าร้านเดิม',
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
        save: (status, note, manualConfirmation) => c.mutate(
          () => widget.repository.payment(
            id,
            order['id'],
            status,
            note: note,
            manualConfirmation: manualConfirmation,
          ),
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
        cod: order['payment_method'] == 'cod',
        save: (method, path, note) async {
          // Recheck access/status before retrying the retained local photo.
          if (c.error != null) await c.refresh();
          if (c.storeId != id || !c.canDelivery) return false;
          return c.mutate(
            () => widget.repository.completeDelivery(
              id,
              order['id'],
              method,
              path,
              locationNote: note,
              cashReceived: order['payment_method'] == 'cod',
            ),
          );
        },
        error: () => c.error,
      ),
    );
    if (result == true) notice('ส่งสำเร็จและแจ้งลูกค้าแล้ว');
  }

  Future<void> resolveCancel(Json order, bool approve) async {
    final refund = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'อนุมัติคำขอยกเลิก' : 'ปฏิเสธคำขอยกเลิก'),
        content: const Text('ร้านเป็นผู้ตัดสินใจเรื่องคืนเงิน'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('กลับ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(approve ? 'ไม่คืนเงิน' : 'ยืนยัน'),
          ),
          if (approve && order['payment_status'] == 'paid')
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('คืนเงิน'),
            ),
        ],
      ),
    );
    if (refund == null || !mounted) return;
    await c.mutate(
      () => widget.repository.resolveCancel(
        c.storeId!,
        order['id'],
        approve,
        refund,
      ),
    );
  }

  Future<void> refundOrder(Json order) async {
    final id = c.storeId!;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RefundSlipDialog(
        repository: widget.repository,
        storeId: id,
        orderId: order['id'],
        save: (path) async {
          if (c.error != null) await c.refresh();
          if (c.storeId != id || !c.canManage) return false;
          return c.mutate(
            () => widget.repository.markRefunded(id, order['id'], path),
          );
        },
        error: () => c.error,
      ),
    );
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
