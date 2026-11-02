import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/merchant_controller.dart';
import '../data/merchant_repository.dart';
import '../widgets/merchant_tool_icon.dart';
import '../widgets/retained_page.dart';
import 'order_dialogs.dart';
import 'fulfillment_panels.dart';
import 'store_settings_panels.dart';
import 'finance_panel.dart';
import 'staff_panel.dart';
import 'growth_panels.dart';
import 'store_profile_panel.dart';

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
    this.onInitialContentReady,
  });
  final MerchantRepository repository;
  final Future<void> Function() onSignOut;
  final VoidCallback? onInitialContentReady;
  @override
  State<MerchantHome> createState() => _MerchantHomeState();
}

class _MerchantHomeState extends State<MerchantHome>
    with WidgetsBindingObserver {
  late MerchantController c;

  /// Preparation time picked on each pending order card, by order id.
  final Map<String, int> _etaChoice = {};
  Timer? timer;
  StreamSubscription<void>? orderSubscription;
  String? subscribedStore;
  bool pushEnabled = false, pushBusy = false;
  int page = 0;
  String query = '';
  String? category;
  bool soldOutOnly = false;
  String menuSort = 'default';
  // Retain only pages the merchant has visited. Hidden widget snapshots avoid
  // unrelated rebuilds and preserve drafts within the store/role/session scope.
  final Set<int> _visitedPages = {0};
  final Map<int, DateTime> _panelVisitedAt = {};
  final Map<int, DateTime> _panelRefreshAt = {};
  String _pageScope = '';
  int _repositoryGeneration = 0;
  final Set<String> _collapsedMenuCategories = {};
  List<Json>? _menuSource;
  String? _menuFilter;
  Map<String, List<Json>> _menuGroupsCache = {};
  static const _cachedPanelPages = {8, 9, 10, 11, 12};
  static const _panelFreshness = Duration(minutes: 1);
  bool foreground = true, signingOut = false;
  bool _initialContentNotified = false;
  bool _initialContentScheduled = false;
  bool _toolWarmupStarted = false;
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
    _bindRepository();
    timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (foreground) {
        unawaited(c.refreshOrders());
        _refreshVisibleDetails();
      }
    });
  }

  void _bindRepository() {
    c = MerchantController(widget.repository)..addListener(changed);
    unawaited(c.initialize());
    orderSubscription = widget.repository.orderChanges.listen((_) {
      if (!mounted) return;
      if (!foreground) {
        return;
      }
      unawaited(c.refreshOrders());
      _refreshVisibleDetails();
    });
    unawaited(readPushStatus());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_toolWarmupStarted) {
      _toolWarmupStarted = true;
      unawaited(MerchantToolIcon.warmup(context));
    }
  }

  @override
  void didUpdateWidget(covariant MerchantHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _repositoryGeneration++;
      unawaited(orderSubscription?.cancel());
      c.removeListener(changed);
      c.dispose();
      subscribedStore = null;
      pushEnabled = false;
      pushBusy = false;
      signingOut = false;
      _initialContentNotified = false;
      _initialContentScheduled = false;
      page = 0;
      _pageScope = '';
      _visitedPages
        ..clear()
        ..add(0);
      _panelVisitedAt.clear();
      _panelRefreshAt.clear();
      _bindRepository();
    }
  }

  void changed() {
    if (!mounted) return;
    if (c.storeId != null && c.storeId != subscribedStore) {
      subscribedStore = c.storeId;
      unawaited(
        widget.repository.subscribe(c.storeId!).catchError((Object _) {}),
      );
    }
    final scope =
        '$_repositoryGeneration:${c.storeId}:${c.canConfigure}:${c.canManage}:'
        '${c.canOrders}:${c.canDelivery}:${c.error == null}';
    if (scope != _pageScope) {
      _pageScope = scope;
      _visitedPages
        ..clear()
        ..add(page);
      _panelVisitedAt.clear();
      _panelRefreshAt.clear();
      _collapsedMenuCategories.clear();
      _menuSource = null;
      query = '';
      category = null;
    }
    setState(() {});
  }

  Future<void> readPushStatus() async {
    final repository = widget.repository;
    try {
      final value = await repository.pushStatus();
      if (mounted && identical(repository, widget.repository)) {
        setState(() => pushEnabled = value['enabled'] == true);
      }
    } catch (_) {}
  }

  Future<void> enablePush() async {
    if (pushBusy) return;
    final repository = widget.repository;
    setState(() => pushBusy = true);
    try {
      final result = await repository.pushEnable();
      if (!mounted || !identical(repository, widget.repository)) return;
      if (result['ok'] == true) {
        await readPushStatus();
        if (!mounted || !identical(repository, widget.repository)) return;
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
      if (mounted && identical(repository, widget.repository)) {
        notice(errorMessage(e));
      }
    } finally {
      if (mounted && identical(repository, widget.repository)) {
        setState(() => pushBusy = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) {
      unawaited(c.refreshOrders());
      _refreshVisibleDetails();
    }
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
    final repository = widget.repository;
    final onSignOut = widget.onSignOut;
    setState(() => signingOut = true);
    try {
      await onSignOut();
    } catch (_) {
      if (mounted && identical(repository, widget.repository)) {
        notice('ออกจากระบบไม่สำเร็จ กรุณาลองอีกครั้ง');
      }
    } finally {
      if (mounted && identical(repository, widget.repository)) {
        setState(() => signingOut = false);
      }
    }
  }

  void navigate(int index) {
    if (page == index) {
      if (index == 0 && c.status != 'pending_acceptance') {
        unawaited(c.selectStatus('pending_acceptance'));
      }
      return;
    }
    setState(() {
      page = index;
      _visitedPages.add(index);
      _refreshVisiblePanelIfStale();
    });
    _refreshVisibleDetails();
    if (index == 0 && c.status != 'pending_acceptance') {
      unawaited(c.selectStatus('pending_acceptance'));
    }
  }

  void _refreshVisiblePanelIfStale() {
    if (!_cachedPanelPages.contains(page)) return;
    final now = DateTime.now();
    final visitedAt = _panelVisitedAt[page];
    final detailsAt = c.detailsUpdatedAt;
    final visited =
        detailsAt != null && (visitedAt == null || detailsAt.isAfter(visitedAt))
        ? detailsAt
        : visitedAt;
    if (visitedAt == null) {
      _panelVisitedAt[page] = now;
    } else if (visited != null && now.difference(visited) >= _panelFreshness) {
      _panelRefreshAt[page] = now;
      _panelVisitedAt[page] = now;
    }
  }

  void _refreshVisibleDetails() {
    if (!foreground) return;
    if (const {0, 4, 6, 7}.contains(page)) {
      // Keep summaries current (including Bangkok day rollover) without
      // making historical reports part of every order poll or loading menu.
      unawaited(c.refreshSummariesIfStale());
    } else if (_cachedPanelPages.contains(page)) {
      final before = _panelRefreshAt[page];
      _refreshVisiblePanelIfStale();
      if (_panelRefreshAt[page] != before) setState(() {});
    }
  }

  DateTime? _panelRefresh(int index) {
    final local = _panelRefreshAt[index];
    final details = c.detailsUpdatedAt;
    return local != null && (details == null || local.isAfter(details))
        ? local
        : details;
  }

  Future<void> _refreshPage() async {
    if (_cachedPanelPages.contains(page)) {
      setState(() {
        _panelRefreshAt[page] = DateTime.now();
        _panelVisitedAt[page] = DateTime.now();
      });
      // The panel performs its own authorized read; do not refetch every other
      // tab's data just because a finance/ads screen was pulled to refresh.
      await c.refreshOrders();
    } else {
      await c.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    _notifyInitialContentAfterPaint();
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
                    RepaintBoundary(child: header()),
                    if (c.loading || c.busy || c.refreshing || c.ordersLoading)
                      const LinearProgressIndicator(minHeight: 3),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refreshPage,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1280),
                            child: Stack(
                              key: ValueKey(_pageScope),
                              fit: StackFit.expand,
                              children: [
                                for (final index in _visitedPages)
                                  RetainedMerchantPage(
                                    key: ValueKey(index),
                                    active: page == index,
                                    builder: (_) => _pageView(index, wide),
                                  ),
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
              animationDuration: Duration.zero,
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

  void _notifyInitialContentAfterPaint() {
    if (_initialContentNotified || _initialContentScheduled || c.loading) {
      return;
    }
    _initialContentScheduled = true;
    final repository = widget.repository;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(repository, widget.repository)) return;
      _initialContentScheduled = false;
      if (c.loading || _initialContentNotified) return;
      _initialContentNotified = true;
      widget.onInitialContentReady?.call();
    });
  }

  Widget _pageView(int index, bool wide) {
    final content = <Widget>[
      if (c.loading && c.updatedAt == null) const _MerchantLoadingSkeleton(),
      if (index != 0) ...[
        Row(
          children: [
            Icon(
              c.error == null ? Icons.cloud_done_outlined : Icons.cloud_off,
              color: c.error == null ? success : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.updatedAt == null
                    ? 'กำลังเชื่อมต่อร้านของคุณ'
                    : 'อัปเดตล่าสุด ${dateLabel(c.updatedAt!.toIso8601String())}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B76)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
      if (c.error != null) errorBox(c.error!),
      if (c.store == null && !c.loading && c.error == null)
        box(
          Column(
            children: [
              const Icon(Icons.storefront_outlined, size: 52, color: brand),
              const SizedBox(height: 16),
              const Text(
                'ไม่พบร้านที่บัญชีนี้มีสิทธิ์จัดการ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'ใช้บัญชีเจ้าของร้านเดิม หรือให้เจ้าของร้านเพิ่มคุณเป็นทีมงาน',
              ),
              TextButton(
                onPressed: openOriginal,
                child: const Text('เปิด WYNOS Merchant'),
              ),
            ],
          ),
        ),
      if (c.store == null && !c.loading)
        TextButton.icon(
          onPressed: c.busy || signingOut ? null : signOut,
          icon: const Icon(Icons.logout),
          label: const Text('ออกจากระบบ'),
        ),
      if (c.store != null && index > 3)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => navigate(3),
            icon: const Icon(Icons.chevron_left),
            label: const Text('เพิ่มเติม'),
          ),
        ),
      if (c.store != null && (!c.loading || c.updatedAt != null))
        ...switch (index) {
          0 => dashboard(),
          1 => orderPage(),
          2 => menuPage(),
          3 => morePage(),
          4 => reportPage(),
          5 => settingsPage(),
          6 => promotionsPage(),
          8 => financePage(),
          9 => staffPage(),
          10 => adsPage(),
          11 => zokyCampaignsPage(),
          12 => feedbackPage(),
          13 => helpPage(),
          _ => qualityPage(),
        },
    ];
    return CustomScrollView(
      key: PageStorageKey('$_pageScope:$index'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(wide ? 36 : 18, 16, wide ? 36 : 18, 0),
          sliver: SliverList.list(children: content),
        ),
        if (c.store != null && index == 2) ..._menuSlivers(wide),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
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
  bool get _reportReady => c.report.isNotEmpty && c.reportError == null;
  bool get _reportPending => c.report.isEmpty && c.summariesLoading;

  Widget stats() => LayoutBuilder(
    builder: (context, size) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
      final cols = size.maxWidth < 340 || largeText
          ? 1
          : (size.maxWidth >= 800 ? 4 : 2);
      final data = [
        metric(
          'ยอดขายวันนี้',
          _reportReady ? money(c.report['today_sales']) : '—',
          Icons.payments_outlined,
          'ออเดอร์สำเร็จ • เวลาไทย',
        ),
        metric(
          'สำเร็จวันนี้',
          _reportReady ? '${c.report['today_orders'] ?? 0}' : '—',
          Icons.receipt_long_outlined,
          'นับตามวันที่สั่งซื้อ',
        ),
        metric(
          'ยอดขายเดือนนี้',
          _reportReady ? money(c.report['month_sales']) : '—',
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
                  onChanged: c.busy
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
          onPressed: pushBusy ? null : enablePush,
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
            reload: MutationReload.orders,
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
                        navigate(5);
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
                      navigate(item.destination ?? 5);
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
                _reportPending || c.updatedAt == null
                    ? 'กำลังโหลดยอดขาย'
                    : _reportReady
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
    if (!_reportReady) {
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

  void openOrders(String status) {
    navigate(1);
    if (!c.busy && c.status != status) unawaited(c.selectStatus(status));
  }

  /// Founder 2026-11-01: open/close in one tap on the home screen. The switch
  /// keeps the server-side suspension and role checks of storeSwitch().
  Widget storeOpenPanel(Json store, bool effectiveOpen) {
    final open = store['is_open'] == true;
    final hours = '${store['business_hours'] ?? ''}'.trim();
    final subtitle = open
        ? (effectiveOpen ? 'ลูกค้าสั่งได้ตอนนี้' : 'นอกเวลาเปิดร้าน')
        : 'ลูกค้ายังสั่งไม่ได้';
    return homePanel(
      Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: effectiveOpen ? success : const Color(0xFF8A8A94),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store['status_text'] ??
                      (open ? 'เปิดรับออเดอร์' : 'ปิดรับออเดอร์'),
                  style: TextStyle(
                    color: effectiveOpen ? success : ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hours.isEmpty ? subtitle : '$subtitle · $hours',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B6B76),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            container: true,
            label: open ? 'ปิดรับออเดอร์ชั่วคราว' : 'เปิดรับออเดอร์',
            child: storeSwitch(),
          ),
        ],
      ),
      onTap: showStoreStatus,
      label: 'แก้ไขสถานะร้าน',
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      gradient: LinearGradient(
        colors: effectiveOpen
            ? const [Color(0xFFEAF8F0), Colors.white]
            : const [Color(0xFFF3EFF1), Colors.white],
      ),
    );
  }

  /// "ต้องทำตอนนี้": live counts from the orderCounts read; — while unknown.
  Widget todoPanel() {
    final counts = c.orderCounts;
    String value(String key) =>
        counts[key] is num ? '${(counts[key] as num).toInt()}' : '—';
    Widget cell(String key, String label, String status, Color fg, Color bg) =>
        Expanded(
          child: Semantics(
            button: true,
            label: '$label ${value(key)} รายการ',
            onTap: () => openOrders(status),
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => openOrders(status),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 6,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      value(key),
                      style: TextStyle(
                        color: fg,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    return homePanel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ต้องทำตอนนี้',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cell(
                'pending',
                'ออเดอร์ใหม่',
                'pending_acceptance',
                brand,
                brandSoft,
              ),
              const SizedBox(width: 8),
              cell(
                'review',
                'ตรวจสลิป',
                'pending_acceptance',
                const Color(0xFFB45309),
                const Color(0xFFFFF4E5),
              ),
              const SizedBox(width: 8),
              cell(
                'preparing',
                'กำลังเตรียม',
                'preparing',
                const Color(0xFF2862A7),
                const Color(0xFFEAF2FC),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => openOrders('pending_acceptance'),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('ไปที่ออเดอร์'),
          ),
        ],
      ),
    );
  }

  List<Widget> dashboard() {
    final store = c.store!;
    final effectiveOpen = store['effective_open'] == true;
    final steps = readiness();
    final done = steps.where((step) => step.done).length;
    return [
      storeOpenPanel(store, effectiveOpen),
      todoPanel(),
      if (c.reportError != null) errorBox(c.reportError!),
      salesSummary(),
      homePanel(
        tools([
          homeTool(
            'การเงิน',
            0,
            Icons.account_balance_wallet_outlined,
            c.canManage ? () => navigate(8) : null,
          ),
          homeTool(
            'โฆษณา',
            1,
            Icons.campaign_outlined,
            c.canManage ? () => navigate(10) : null,
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
            c.canManage ? () => navigate(11) : null,
          ),
          homeTool(
            'คุณภาพร้าน',
            4,
            Icons.verified_user_outlined,
            () => navigate(7),
          ),
          homeTool('ฟีดแบ็ก', 5, Icons.chat_bubble_outline, () => navigate(12)),
          homeTool('ช่วยเหลือ', 6, Icons.support_outlined, () => navigate(13)),
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
                  c.updatedAt == null ||
                          (c.qualityData.isEmpty && c.summariesLoading)
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
        onPressed: () => navigate(12),
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

  /// One row of the grouped "เพิ่มเติม" list. The accessible name is the label
  /// alone so screen readers and tests find each tool by its plain name.
  Widget moreRow(
    String label,
    VoidCallback? onTap, {
    int? icon3d,
    IconData icon = Icons.chevron_right,
    String? hint,
    Color? hintColor,
    IconData trailing = Icons.chevron_right,
  }) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Opacity(
                opacity: onTap == null ? .4 : 1,
                child: icon3d != null
                    ? MerchantToolIcon(index: icon3d, size: 40, fallback: icon)
                    : Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: brandSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: brand, size: 22),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: onTap == null ? const Color(0xFF8A8A94) : ink,
                      ),
                    ),
                    if (hint != null)
                      Text(
                        hint,
                        style: TextStyle(
                          fontSize: 12,
                          color: hintColor ?? const Color(0xFF6B6B76),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(trailing, size: 20, color: const Color(0xFF8A7F85)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget moreGroup(String title, List<Widget> rows) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5C5157),
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFEEE7EB)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: 66,
                    color: Color(0xFFF1EBEE),
                  ),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );

  /// Founder 2026-11-01 (ZOKY-MERCHANT-UX-002): grouped tools with 3D icons.
  List<Widget> morePage() => [
    homePanel(
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: brand,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${c.store!['name'] ?? ''}'.characters.firstOrNull ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          c.store!['name'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        subtitle: Text(
          c.store!['is_published'] == true
              ? 'เผยแพร่บน ZOKY แล้ว'
              : 'ร้านยังไม่เผยแพร่',
          style: TextStyle(
            color: c.store!['is_published'] == true
                ? success
                : const Color(0xFF9A5800),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => navigate(5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    moreGroup('ขายและเงิน', [
      moreRow(
        'รายงานยอดขาย',
        () => navigate(4),
        icon: Icons.bar_chart_rounded,
        hint: 'ยอดขายและเมนูขายดี',
      ),
      if (c.canManage)
        moreRow(
          'การเงิน',
          () => navigate(8),
          icon3d: 0,
          icon: Icons.account_balance_wallet_outlined,
          hint: 'ยอดเงินเข้าบัญชีร้าน',
        ),
      moreRow(
        'ประวัติออเดอร์',
        c.busy ? null : () => openOrders('delivered'),
        icon: Icons.history,
      ),
    ]),
    moreGroup('ร้านค้า', [
      moreRow(
        'ตั้งค่าร้าน',
        () => navigate(5),
        icon3d: 7,
        icon: Icons.settings_outlined,
        hint: 'ชื่อ รูป ที่อยู่ พื้นที่ส่ง ช่องทางรับเงิน',
      ),
      moreRow(
        'เวลาเปิด-ปิด',
        showStoreStatus,
        icon: Icons.schedule,
        hint: c.store!['is_open'] == true
            ? 'เปิดรับออเดอร์อยู่'
            : 'ปิดรับออเดอร์อยู่',
      ),
    ]),
    moreGroup('การตลาดและคุณภาพ', [
      moreRow(
        'โปรโมชั่น',
        () => navigate(6),
        icon3d: 2,
        icon: Icons.local_offer_outlined,
      ),
      if (c.canManage) ...[
        moreRow(
          'แคมเปญ ZOKY',
          () => navigate(11),
          icon3d: 3,
          icon: Icons.shopping_bag_outlined,
          hint: 'ZOKY ช่วยออกส่วนลด',
        ),
        moreRow(
          'โฆษณา',
          () => navigate(10),
          icon3d: 1,
          icon: Icons.campaign_outlined,
        ),
      ],
      moreRow(
        'คุณภาพร้าน',
        () => navigate(7),
        icon3d: 4,
        icon: Icons.verified_user_outlined,
        hint: 'คะแนนและรีวิวจากลูกค้า',
      ),
      moreRow(
        'ฟีดแบ็ก',
        () => navigate(12),
        icon3d: 5,
        icon: Icons.chat_bubble_outline,
      ),
    ]),
    moreGroup('ทีมและการแจ้งเตือน', [
      moreRow('ทีมงาน', () => navigate(9), icon: Icons.groups_outlined),
      moreRow(
        'การแจ้งเตือน',
        pushBusy ? null : enablePush,
        icon: Icons.notifications_outlined,
        hint: pushEnabled
            ? 'เปิดแจ้งเตือนออเดอร์แล้ว'
            : 'รับการแจ้งเตือนเมื่อมีออเดอร์ใหม่',
        hintColor: pushEnabled ? success : null,
      ),
      moreRow(
        'ช่วยเหลือ',
        () => navigate(13),
        icon3d: 6,
        icon: Icons.support_outlined,
      ),
    ]),
    OutlinedButton.icon(
      onPressed: c.busy || signingOut ? null : signOut,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFB0174F),
        side: const BorderSide(color: Color(0xFFF3C9D9)),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.logout),
      label: const Text('ออกจากระบบ'),
    ),
  ];

  /// Founder 2026-11-01: reviews inside the new Merchant (was the legacy page).
  List<Widget> feedbackPage() => [
    heading('ฟีดแบ็ก', 'ความคิดเห็นจากลูกค้า ZOKY ที่สั่งจริง'),
    box(
      FeedbackPanel(
        key: ValueKey(c.storeId),
        repository: widget.repository,
        storeId: c.storeId!,
        refreshedAt: _panelRefresh(12),
      ),
    ),
  ];

  Future<void> copyStoreDiagnostics() async {
    final store = c.store!;
    final detail = [
      'ZOKY Merchant',
      'ร้าน: ${store['name']}',
      'Store ID: ${store['id']}',
      'สถานะ: ${store['is_open'] == true ? 'เปิดร้าน' : 'ปิดร้าน'} / ${store['is_published'] == true ? 'เผยแพร่แล้ว' : 'ยังไม่เผยแพร่'}',
      'เวลา: ${DateTime.now().toUtc().toIso8601String()}',
    ].join('\n');
    try {
      await Clipboard.setData(ClipboardData(text: detail));
      notice('คัดลอกข้อมูลสำหรับแจ้งปัญหาแล้ว');
    } catch (_) {
      notice('คัดลอกไม่สำเร็จ กรุณาจด Store ID จากหน้านี้');
    }
  }

  /// Founder 2026-11-01: help inside the new Merchant (was the legacy page).
  List<Widget> helpPage() {
    Widget tip(String title, String body) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(body),
    );
    return [
      heading('ช่วยเหลือ', 'ศูนย์ช่วยเหลือร้านค้า'),
      box(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ต้องการความช่วยเหลือ?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'ติดต่อบัญชี Official @wynos_s ใน WYNOS พร้อมส่งชื่อร้านและ Store ID เพื่อให้ทีมตรวจสอบได้เร็วขึ้น',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => launchUrl(
                    Uri.parse('https://wynos.online'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('เปิด WYNOS'),
                ),
                OutlinedButton(
                  onPressed: copyStoreDiagnostics,
                  child: const Text('คัดลอกข้อมูลร้าน'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              'Store ID: ${c.store!['id']}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B76)),
            ),
          ],
        ),
      ),
      box(
        Column(
          children: [
            tip(
              'ออเดอร์ไม่ดัง',
              'ตรวจว่าเปิดการแจ้งเตือน (เพิ่มเติม → การแจ้งเตือน) หรือ LINE และมือถือไม่ได้ปิดเสียง',
            ),
            tip(
              'สลิปไม่ขึ้น',
              'ปิดออเดอร์แล้วเปิดใหม่ หากยังไม่ขึ้นให้คัดลอกข้อมูลร้านส่งทีม',
            ),
            tip(
              'ร้านไม่ขึ้นบน ZOKY',
              'ตรวจความพร้อมร้าน ช่องทางรับเงิน เมนู ตำแหน่ง และสถานะเผยแพร่',
            ),
            tip(
              'ยอดขายหรือการเงินไม่ตรง',
              'ใช้หน้า “การเงิน” เลือกช่วงวันที่เพื่อตรวจรายการ',
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> adsPage() => [
    heading('โฆษณา', 'ให้ร้านขึ้นเป็นร้านแนะนำและอยู่บนสุดตอนค้นหา'),
    if (c.canManage)
      box(
        AdsPanel(
          key: ValueKey(c.storeId),
          repository: widget.repository,
          storeId: c.storeId!,
          refreshedAt: _panelRefresh(10),
        ),
      )
    else
      box(const Text('เฉพาะเจ้าของ แอดมิน หรือผู้จัดการร้านที่จัดการโฆษณาได้')),
  ];

  List<Widget> zokyCampaignsPage() => [
    heading('แคมเปญ ZOKY', 'แคมเปญส่วนลดที่ ZOKY ช่วยออกให้ เข้าร่วมได้เอง'),
    if (c.canManage)
      box(
        PlatformCampaignsPanel(
          key: ValueKey(c.storeId),
          repository: widget.repository,
          storeId: c.storeId!,
          refreshedAt: _panelRefresh(11),
        ),
      )
    else
      box(
        const Text('เฉพาะเจ้าของ แอดมิน หรือผู้จัดการร้านที่เข้าร่วมแคมเปญได้'),
      ),
  ];

  List<Widget> staffPage() => [
    heading('ทีมงาน', 'คนที่เข้าจัดการร้านนี้ได้ และสิทธิ์ของแต่ละคน'),
    box(
      StaffPanel(
        key: ValueKey(c.storeId),
        repository: widget.repository,
        storeId: c.storeId!,
        refreshedAt: _panelRefresh(9),
      ),
    ),
  ];

  List<Widget> financePage() => [
    heading('การเงินของร้าน', 'ยอดขาย คืนเงิน และรายได้ของร้าน'),
    // Re-checked on every refresh: losing the role removes the panel and
    // the figures it holds.
    if (c.canManage)
      box(
        FinancePanel(
          key: ValueKey(c.storeId),
          repository: widget.repository,
          storeId: c.storeId!,
          refreshedAt: _panelRefresh(8),
        ),
      )
    else
      box(const Text('เฉพาะเจ้าของ แอดมิน หรือผู้จัดการร้านที่ดูการเงินได้')),
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
      box(
        Text(c.summariesLoading ? 'กำลังโหลดโปรโมชั่น' : 'ยังไม่มีโปรโมชั่น'),
      ),
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
        children: orderTabs.entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  // "จัดส่ง" also lists pickup orders ready for collection.
                  label: Text(e.value),
                  selected: c.status == e.key,
                  onSelected: c.busy ? null : (_) => c.selectStatus(e.key),
                ),
              ),
            )
            .toList(),
      ),
    ),
    const SizedBox(height: 20),
    if (c.orders.isEmpty && (c.ordersLoading || c.refreshing))
      const Text('กำลังโหลดออเดอร์'),
    if (c.orders.isEmpty && !c.loading && !c.ordersLoading && !c.refreshing)
      emptyState(
        Icons.shopping_bag_outlined,
        'ไม่มีออเดอร์ในแท็บนี้',
        'ออเดอร์จะแสดงตามสถานะที่เลือก',
      ),
    ...c.orders.map(orderCard),
    if (c.hasMore)
      OutlinedButton(
        onPressed: c.writable && !c.ordersLoading && !c.refreshing
            ? c.loadMore
            : null,
        child: Text(
          c.ordersLoading ? 'กำลังโหลดออเดอร์' : 'โหลดออเดอร์เพิ่มเติม',
        ),
      ),
    const SizedBox(height: 12),
    const Text(
      'อัปเดตผ่าน Realtime และตรวจข้อมูลซ้ำทุก 20 วินาที',
      style: TextStyle(color: Color(0xFF6B6B76), fontSize: 12),
    ),
  ];

  /// "2 นาทีที่แล้ว" for recent orders; older ones keep the full date.
  String agoLabel(dynamic value) {
    final at = DateTime.tryParse('$value')?.toLocal();
    if (at == null) return dateLabel(value);
    final minutes = DateTime.now().difference(at).inMinutes;
    if (minutes < 1) return 'เมื่อสักครู่';
    if (minutes < 60) return '$minutes นาทีที่แล้ว';
    if (minutes < 360) return '${minutes ~/ 60} ชม.ที่แล้ว';
    return dateLabel(value);
  }

  int defaultEta(Json o) =>
      (num.tryParse(
                '${o['eta_minutes'] ?? c.store?['prep_time_max_minutes'] ?? 30}',
              )?.toInt() ??
              30)
          .clamp(1, 240);

  /// Payment still needs the store's check before the order can be accepted.
  bool needsPaymentReview(Json o) =>
      o['payment_method'] != 'cod' &&
      o['payment_status'] != 'paid' &&
      !stripeWaiting(o) &&
      (o['payment_slip_path'] != null || o['payment_status'] == 'pending');

  bool stripeWaiting(Json o) =>
      o['payment_method'] != 'cod' &&
      o['payment_status'] != 'paid' &&
      (o['payment_provider'] == 'stripe' ||
          (o['stripe_checkout_session_id'] != null &&
              o['payment_slip_path'] == null));

  Widget pill(String text, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );

  Widget orderPill(Json o) {
    final status = '${o['status']}';
    if (status == 'pending_acceptance') {
      if (o['payment_method'] == 'cod') {
        return pill(
          'เก็บเงินปลายทาง',
          const Color(0xFF7A4B00),
          const Color(0xFFFFF1DC),
        );
      }
      if (o['payment_status'] == 'paid') {
        return pill(
          'ชำระแล้ว',
          const Color(0xFF0A6B3B),
          const Color(0xFFEAF8F0),
        );
      }
      if (o['payment_status'] == 'issue') {
        return pill('สลิปมีปัญหา', const Color(0xFFB0174F), brandSoft);
      }
      return pill(
        stripeWaiting(o) ? 'รอยืนยันชำระ' : 'ตรวจสลิป',
        const Color(0xFF7A4B00),
        const Color(0xFFFFF1DC),
      );
    }
    if (status == 'delivered') {
      return pill(
        orderStatusLabel(o),
        const Color(0xFF0A6B3B),
        const Color(0xFFEAF8F0),
      );
    }
    if (status == 'cancelled') {
      return pill(
        orderStatusLabel(o),
        const Color(0xFF5C5157),
        const Color(0xFFF1EDEF),
      );
    }
    if (status == 'preparing' && o['eta_minutes'] != null) {
      return pill(
        'ทำ ${o['eta_minutes']} นาที',
        const Color(0xFF9C1149),
        brandSoft,
      );
    }
    return pill(orderStatusLabel(o), const Color(0xFF9C1149), brandSoft);
  }

  Widget orderCard(Json o) {
    final status = o['status'] as String;
    final next = orderNextStatus(o);
    final pickup = o['fulfillment_type'] == 'pickup';
    // Collecting a pickup order is an order-desk step, not a delivery one.
    final allowed = status == 'ready_for_delivery' && !pickup
        ? c.canDelivery
        : c.canOrders;
    final id = '${o['id']}';
    final eta = _etaChoice[id] ?? defaultEta(o);
    final etaOptions = ({15, 30, 45, defaultEta(o)}.toList()..sort());
    final items = (o['food_order_items'] as List? ?? []);
    const muted = Color(0xFF6B5F66);
    final canAccept =
        status == 'pending_acceptance' && c.writable && c.canOrders;
    final discount =
        (num.tryParse('${o['campaign_discount']}') ?? 0) +
        (num.tryParse('${o['delivery_discount']}') ?? 0);

    Widget primary(String label, VoidCallback? onPressed, {Color? color}) =>
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onPressed,
            child: Text(label),
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEE7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${o['order_number']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${agoLabel(o['created_at'])} · ${pickup ? '🛍️ รับที่ร้าน' : '🛵 ส่งถึงบ้าน'}'
                      '${o['payment_method'] == 'cod' ? ' · 💵 เก็บเงินปลายทาง' : ''}',
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              orderPill(o),
            ],
          ),
          if (pickup) ...[
            const SizedBox(height: 8),
            Text(
              'นัดรับ ${dateLabel(o['pickup_at'])} · รหัสรับอาหาร: ${o['pickup_code'] ?? '—'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          if (o['scheduled_for'] != null) ...[
            const SizedBox(height: 6),
            Text(
              'นัดส่ง: ${dateLabel(o['scheduled_for'])}',
              style: const TextStyle(color: brand, fontWeight: FontWeight.w600),
            ),
          ],
          if (o['cancel_requested_at'] != null)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ลูกค้าขอยกเลิก',
                    style: TextStyle(
                      color: Color(0xFF8A4A00),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if ('${o['cancel_request_note'] ?? ''}'.isNotEmpty)
                    Text('${o['cancel_request_note']}'),
                  Wrap(
                    spacing: 8,
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
              ),
            ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${item['quantity']}× ${item['item_name']}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (num.tryParse('${item['unit_price']}') != null)
                        Text(
                          money(
                            (num.tryParse('${item['unit_price']}') ?? 0) *
                                (num.tryParse('${item['quantity']}') ?? 1),
                          ),
                          style: const TextStyle(fontSize: 15),
                        ),
                    ],
                  ),
                  if (item['selected_options'] is List &&
                      (item['selected_options'] as List).isNotEmpty)
                    Text(
                      optionLabel(item['selected_options'] as List),
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                  if ((item['item_note'] ?? '').toString().isNotEmpty)
                    Text(
                      'หมายเหตุเมนู: ${item['item_note']}',
                      style: const TextStyle(
                        color: Color(0xFF8A4A00),
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
          if ((o['customer_note'] ?? '').toString().isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'หมายเหตุลูกค้า: ${o['customer_note']}',
                style: const TextStyle(color: Color(0xFF6A3A00)),
              ),
            ),
          const Divider(height: 24, color: Color(0xFFF1EBEE)),
          if (!pickup)
            Text(
              '📍 ${o['shipping_address']}',
              style: const TextStyle(fontSize: 14),
            ),
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: '${o['recipient_phone']}'),
                  );
                  notice('คัดลอกเบอร์โทรแล้ว');
                },
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: Text('${o['recipient_name']} · ${o['recipient_phone']}'),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'อาหาร ${money(o['subtotal'])} · ค่าส่ง ${money(o['delivery_fee'])}'
                  '${discount > 0 ? ' · ส่วนลด ${money(discount)}' : ''}',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ),
              Text(
                money(o['total']),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
            ],
          ),
          if (status == 'pending_acceptance' && !stripeWaiting(o)) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('พร้อมใน', style: TextStyle(color: muted)),
                for (final minutes in etaOptions)
                  ChoiceChip(
                    label: Text('$minutes นาที'),
                    selected: eta == minutes,
                    onSelected: canAccept
                        ? (_) => setState(() => _etaChoice[id] = minutes)
                        : null,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (status == 'pending_acceptance')
            if (stripeWaiting(o))
              primary('รอระบบยืนยันการชำระเงินอัตโนมัติ', null)
            else if (needsPaymentReview(o))
              primary(
                o['payment_slip_path'] != null
                    ? 'ตรวจสลิป · รับออเดอร์'
                    : 'ตรวจเงินเข้า · รับออเดอร์',
                canAccept ? () => reviewAndAccept(o, eta) : null,
              )
            else
              primary(
                'รับออเดอร์ · $eta นาที',
                canAccept &&
                        (o['payment_status'] == 'paid' ||
                            o['payment_method'] == 'cod')
                    ? () => accept(o, eta)
                    : null,
              )
          else if (status == 'out_for_delivery')
            primary(
              'แนบรูปและยืนยันส่งสำเร็จ',
              c.writable && c.canDelivery ? () => finishDelivery(o) : null,
              color: success,
            )
          else if (next != null)
            primary(
              orderNextAction(o)!,
              c.writable && allowed ? () => advance(o, next) : null,
              color: ink,
            ),
          Wrap(
            spacing: 4,
            children: [
              if (o['payment_slip_path'] != null &&
                  (o['payment_status'] == 'paid' ||
                      status != 'pending_acceptance'))
                TextButton(
                  onPressed: () => showEvidence(o, 'slip'),
                  child: const Text('ดูสลิปการชำระเงิน'),
                ),
              if (status == 'delivered' && !pickup)
                TextButton(
                  onPressed: () => showEvidence(o, 'proof'),
                  child: const Text('ดูหลักฐานส่งสำเร็จ'),
                ),
              if (!['delivered', 'cancelled'].contains(status) && c.canOrders)
                TextButton(
                  onPressed: c.writable ? () => cancelOrder(o) : null,
                  child: const Text(
                    'ยกเลิกออเดอร์',
                    style: TextStyle(color: Color(0xFFB0174F)),
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
            ],
          ),
          if (o['refund_status'] == 'pending')
            const Text(
              'รอคืนเงิน • จัดการคืนเงินผ่านหน้าการเงินร้าน',
              style: TextStyle(color: Color(0xFF8A4A00)),
            ),
        ],
      ),
    );
  }

  /// Payment check, then acceptance with the ETA chosen on the card:
  /// the existing review dialog and both server checks stay in place.
  Future<void> reviewAndAccept(Json o, int eta) async {
    if (!await reviewPayment(o) || !mounted) return;
    await accept(o, eta);
  }

  Future<void> accept(Json o, int eta) async {
    if (await c.mutate(
      () => widget.repository.transition(
        c.storeId!,
        o['id'],
        'preparing',
        etaMinutes: eta,
      ),
      reload: MutationReload.orders,
    )) {
      _etaChoice.remove('${o['id']}');
      notice('รับออเดอร์แล้ว · แจ้งลูกค้าว่าพร้อมใน $eta นาที');
    }
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
        reload: MutationReload.orders,
      )) {
        notice('อัปเดตออเดอร์แล้ว');
      }
    }
  }

  Map<String, List<Json>> _menuGroups() {
    final filter = '$query\u0000$category\u0000$menuSort\u0000$soldOutOnly';
    if (identical(_menuSource, c.menu) && _menuFilter == filter) {
      return _menuGroupsCache;
    }
    _menuSource = c.menu;
    _menuFilter = filter;
    final normalized = query.toLowerCase();
    final selectedCategory =
        c.menu.any((m) => '${m['category'] ?? 'ทั่วไป'}' == category)
        ? category
        : null;
    final rows = c.menu
        .where(
          (m) =>
              (!soldOutOnly || m['is_available'] != true) &&
              (selectedCategory == null ||
                  '${m['category'] ?? 'ทั่วไป'}' == selectedCategory) &&
              '${m['name']} ${m['category'] ?? ''}'.toLowerCase().contains(
                normalized,
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
    return _menuGroupsCache = groups;
  }

  List<Widget> menuPage() {
    final categories = c.menu
        .map((m) => '${m['category'] ?? 'ทั่วไป'}')
        .toSet()
        .toList();
    final selectedCategory = categories.contains(category) ? category : null;
    final groups = _menuGroups();
    final soldOut = c.menu.where((m) => m['is_available'] != true).length;
    Widget filterChip(String label, bool selected, VoidCallback onTap) =>
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onTap(),
          ),
        );
    return [
      heading(
        'เมนูอาหาร',
        '${c.menu.length} เมนู · หมด $soldOut',
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
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            filterChip(
              'ทั้งหมด',
              selectedCategory == null && !soldOutOnly,
              () => setState(() {
                category = null;
                soldOutOnly = false;
              }),
            ),
            filterChip(
              'หมดอยู่ $soldOut',
              soldOutOnly,
              () => setState(() => soldOutOnly = !soldOutOnly),
            ),
            for (final name in categories)
              filterChip(
                name,
                selectedCategory == name,
                () => setState(
                  () => category = selectedCategory == name ? null : name,
                ),
              ),
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
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (groups.isEmpty)
        emptyState(
          Icons.restaurant_menu,
          'ไม่พบเมนู',
          'ลองค้นหาด้วยชื่ออื่น หรือเพิ่มเมนูใหม่',
        ),
    ];
  }

  List<Widget> _menuSlivers(bool wide) {
    // A single delegate stays lazy even for stores with many categories. One
    // sliver per category would build each category's first image offscreen.
    final entries = <({String category, Json? item, int count})>[];
    for (final group in _menuGroups().entries) {
      entries.add((category: group.key, item: null, count: group.value.length));
      if (!_collapsedMenuCategories.contains(group.key)) {
        for (final item in group.value) {
          entries.add((category: group.key, item: item, count: 0));
        }
      }
    }
    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 18),
        sliver: SliverList.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final item = entry.item;
            if (item != null) {
              return Card(
                key: ValueKey(item['id']),
                margin: const EdgeInsets.only(bottom: 1),
                child: menuRow(item),
              );
            }
            return Card(
              key: ValueKey('category:${entry.category}'),
              margin: const EdgeInsets.only(bottom: 1, top: 12),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                title: Text(
                  entry.category,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${entry.count} เมนู'),
                trailing: Icon(
                  _collapsedMenuCategories.contains(entry.category)
                      ? Icons.expand_more
                      : Icons.expand_less,
                ),
                onTap: () => setState(() {
                  if (!_collapsedMenuCategories.remove(entry.category)) {
                    _collapsedMenuCategories.add(entry.category);
                  }
                }),
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _menuImage(Json item) {
    final original = item['image_url'] as String;
    final thumbnail = item['image_thumbnail_url'];
    final source = thumbnail is String && thumbnail.isNotEmpty
        ? thumbnail
        : original;
    final pixels = (64 * MediaQuery.devicePixelRatioOf(context).clamp(1, 3))
        .ceil();
    Widget image(String url, {required bool fallback}) => Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: pixels,
      cacheHeight: pixels,
      frameBuilder: (_, child, frame, synchronous) =>
          synchronous || frame != null ? child : menuPlaceholder(),
      errorBuilder: (_, error, stack) => fallback
          ? Image.network(
              original,
              fit: BoxFit.cover,
              cacheWidth: pixels,
              cacheHeight: pixels,
              frameBuilder: (_, child, frame, synchronous) =>
                  synchronous || frame != null ? child : menuPlaceholder(),
              errorBuilder: (_, error, stack) => menuPlaceholder(),
            )
          : menuPlaceholder(),
    );
    return image(source, fallback: source != original);
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
                      reload: MutationReload.menu,
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
                        ? _menuImage(item)
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
    key: const ValueKey('merchant-menu-image-placeholder'),
    color: brandSoft,
    child: const Icon(Icons.restaurant, color: brand, size: 28),
  );

  List<Widget> reportPage() => [
    heading('ยอดขายของร้าน', 'คำนวณจากข้อมูลทั้งหมดในระบบเดิม'),
    if (c.reportError != null) errorBox(c.reportError!),
    if (_reportPending) ...[
      const Text('กำลังโหลดยอดขาย'),
      const LinearProgressIndicator(),
    ],
    stats(),
    section('สรุปยอดขาย'),
    box(
      Column(
        children: [
          summary(
            'สัปดาห์นี้',
            _reportReady ? money(c.report['week_sales']) : '—',
          ),
          summary(
            'ยอดเฉลี่ยต่อออเดอร์',
            _reportReady ? money(c.report['average_order']) : '—',
          ),
          summary(
            'ออเดอร์สำเร็จทั้งหมด',
            _reportReady ? '${c.report['total_orders'] ?? 0}' : '—',
          ),
        ],
      ),
    ),
    section('เมนูขายดีตลอดการขาย'),
    box(
      Column(
        children: [
          if ((c.report['best'] as List? ?? []).isEmpty)
            Text(
              _reportPending ? 'กำลังโหลดเมนูขายดี' : 'ยังไม่มีข้อมูลการขาย',
            ),
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
          save: (values) => c.mutate(
            () => widget.repository.saveStore(c.storeId!, values),
            reload: MutationReload.orders,
          ),
          // A cancelled picker uploads nothing and changes nothing.
          pickQr: () => c.mutate(
            () => widget.repository.pickPaymentQr(c.storeId!),
            reload: MutationReload.orders,
          ),
          error: () => c.error,
        ),
      ),
      box(
        BusinessHoursPanel(
          store: c.store!,
          enabled: c.writable,
          save: (values) => c.mutate(
            () => widget.repository.saveStore(c.storeId!, values),
            reload: MutationReload.orders,
          ),
          error: () => c.error,
        ),
      ),
    ],
    if (c.canManage)
      box(
        StoreProfilePanel(
          key: ValueKey('profile:${c.storeId}'),
          store: c.store!,
          enabled: c.writable,
          save: (values) => c.mutate(
            () => widget.repository.saveStore(c.storeId!, values),
            reload: MutationReload.orders,
          ),
          // A cancelled picker uploads nothing and changes nothing.
          pickImage: (kind) => c.mutate(
            () => widget.repository.pickStoreImage(c.storeId!, kind),
            reload: MutationReload.orders,
          ),
          setPublished: (published) => c.mutate(
            () => widget.repository.setPublished(c.storeId!, published),
            reload: MutationReload.orders,
          ),
          locate: widget.repository.currentLocation,
          pickOnMap: (kind, lat, lng) =>
              widget.repository.pickMapLocation(c.storeId!, kind, lat, lng),
          checkArea: (lat, lng) async {
            try {
              final r = await widget.repository.checkLocation(
                c.storeId!,
                lat,
                lng,
              );
              return r['inside'] is bool ? r['inside'] as bool : null;
            } catch (_) {
              return null;
            }
          },
          error: () => c.error,
        ),
      ),
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
                    reload: MutationReload.orders,
                  )
                : null,
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
          const Text('อัปเดตออเดอร์ผ่าน Realtime และตรวจซ้ำทุก 20 วินาที'),
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
        ],
      ),
    ),
  ];

  Future<bool> reviewPayment(Json order) async {
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
          reload: MutationReload.orders,
        ),
        error: () => c.error,
      ),
    );
    if (result == true) notice('บันทึกการตรวจชำระเงินแล้ว');
    // Accept only after the payment was confirmed as received.
    return result == true &&
        c.orders.any(
          (x) => x['id'] == order['id'] && x['payment_status'] == 'paid',
        );
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
            reload: MutationReload.orders,
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
      reload: MutationReload.orders,
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
            reload: MutationReload.orders,
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
      reload: MutationReload.orders,
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

/// Static shapes communicate progress without animating or inventing store data.
class _MerchantLoadingSkeleton extends StatelessWidget {
  const _MerchantLoadingSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('merchant-store-loading'),
    label: 'กำลังโหลดข้อมูลร้าน',
    liveRegion: true,
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'กำลังโหลดข้อมูลร้าน',
            style: TextStyle(color: Color(0xFF6B6B76), fontSize: 13),
          ),
          const SizedBox(height: 16),
          for (final height in [52.0, 116.0, 168.0])
            Container(
              height: height,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.topLeft,
              child: FractionallySizedBox(
                widthFactor: .56,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: brandSoft,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
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
