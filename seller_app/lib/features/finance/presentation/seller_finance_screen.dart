import 'package:flutter/material.dart';

import '../../../core/text_utils.dart';
import '../../../core/widgets/search_state_message.dart';
import '../../order/data/order.dart';
import '../../order/presentation/seller_order_detail_screen.dart';
import '../../store/data/seller_repository.dart';
import '../../store/data/store.dart';
import 'widgets/seller_transaction_tile.dart';

/// The 3 time windows `SellerRepository.fetchFinanceBreakdown` reports
/// -- same set/order/default as SellerDashboardScreen's ยอดขาย card
/// (Design spec's decision #5: default "วันนี้").
enum _FinancePeriod { today, thisMonth, allTime }

/// Payout bottom sheet copy -- word-for-word from the Product spec
/// (Requirements #6). Do not paraphrase: Acceptance Criteria checks this
/// text directly.
const _payoutExplanation =
    'ยังไม่รองรับการถอนเงินในเวอร์ชันนี้ เนื่องจากยังไม่มีระบบชำระเงิน '
    '(Payment Gateway) เชื่อมต่อกับแพลตฟอร์ม ยอดคงเหลือที่แสดงเป็นตัวเลข'
    'คำนวณเพื่อการติดตามเท่านั้น';

/// Balance card disclaimer -- word-for-word from the Product spec
/// (Requirements #5). Must appear every time the Balance card is shown,
/// not just once.
const _balanceDisclaimer =
    'ยอดนี้เป็นตัวเลขคำนวณจากคำสั่งซื้อที่ลูกค้าได้รับสินค้าแล้วเท่านั้น '
    'ไม่ใช่เงินในบัญชีธนาคารจริง เนื่องจากยังไม่มีระบบชำระเงิน/โอนเงินเชื่อมต่อ';

/// Fee rate line's second sentence -- word-for-word from the Product
/// spec (Requirements #7).
const _feeRateDisclaimer =
    'อัตรานี้ใช้กับคำสั่งซื้อใหม่เท่านั้น ไม่กระทบยอดของคำสั่งซื้อเก่าที่บันทึกอัตราไว้แล้วตอนสั่งซื้อ';

/// Tab "การเงิน" (index 4) of `SellerHomeShell`, replacing
/// `SellerComingSoonScreen(label: 'การเงิน')` (SELLER-005) -- Gross
/// Sales / ZOKY Fee / Net Revenue breakdown, in-transit summary,
/// cumulative Balance, current platform fee rate, and a paginated
/// Transaction History, all read-only/computed live every load. See
/// .wyn/docs/design/seller-005-finance.md, Screen: SellerFinanceScreen.
class SellerFinanceScreen extends StatefulWidget {
  const SellerFinanceScreen({
    super.key,
    required this.store,
    required this.sellerRepository,
  });

  final Store store;
  final SellerRepository sellerRepository;

  @override
  State<SellerFinanceScreen> createState() => _SellerFinanceScreenState();
}

class _SellerFinanceScreenState extends State<SellerFinanceScreen> {
  final _scrollController = ScrollController();

  final List<Order> _transactions = [];
  int _page = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  SellerFinanceBreakdown? _breakdown;
  double _inTransitSum = 0;
  int _inTransitCount = 0;
  double _feePercent = 10;

  _FinancePeriod _selectedPeriod = _FinancePeriod.today;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final storeId = widget.store.id;
      final breakdown = await widget.sellerRepository.fetchFinanceBreakdown(storeId);
      final inTransit = await widget.sellerRepository.fetchInTransitSummary(storeId);
      final feePercent = await widget.sellerRepository.fetchPlatformFeePercent();
      final transactions = await widget.sellerRepository.fetchTransactionHistory(
        storeId: storeId,
        page: 0,
      );
      if (!mounted) return;
      setState(() {
        _breakdown = breakdown;
        _inTransitSum = inTransit.$1;
        _inTransitCount = inTransit.$2;
        _feePercent = feePercent;
        _transactions
          ..clear()
          ..addAll(transactions);
        _page = 0;
        _hasMore = transactions.length == SellerRepository.ordersPageSize;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดข้อมูลการเงินไม่สำเร็จ';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final page = await widget.sellerRepository.fetchTransactionHistory(
      storeId: widget.store.id,
      page: nextPage,
    );
    if (!mounted) return;
    setState(() {
      _transactions.addAll(page);
      _page = nextPage;
      _hasMore = page.length == SellerRepository.ordersPageSize;
      _isLoadingMore = false;
    });
  }

  void _openOrder(Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerOrderDetailScreen(
          sellerRepository: widget.sellerRepository,
          orderId: order.id,
        ),
      ),
    );
    // No reload after returning -- unlike SellerOrderListScreen, this
    // screen is read-only end to end, so viewing an order's detail can
    // never change what Finance would show. See the Design spec's User
    // Flow #5.
  }

  Future<void> _showPayoutInfo() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline, size: 32),
              const SizedBox(height: 12),
              Text('ยังไม่รองรับการถอนเงิน', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(_payoutExplanation),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('เข้าใจแล้ว'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  FinancePeriodTotals _totalsFor(_FinancePeriod period) {
    final breakdown = _breakdown;
    if (breakdown == null) return FinancePeriodTotals.zero;
    return switch (period) {
      _FinancePeriod.today => breakdown.today,
      _FinancePeriod.thisMonth => breakdown.thisMonth,
      _FinancePeriod.allTime => breakdown.allTime,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('การเงิน')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadInitial, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    final itemCount = 1 + (_transactions.isEmpty ? 1 : _transactions.length + (_hasMore ? 1 : 0));

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) return _buildSummarySection(context);

          if (_transactions.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 24),
              child: SearchStateMessage(
                icon: Icons.receipt_long_outlined,
                text: 'ยังไม่มีประวัติรายรับ',
              ),
            );
          }

          final txIndex = index - 1;
          if (txIndex >= _transactions.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final order = _transactions[txIndex];
          return Column(
            children: [
              SellerTransactionTile(order: order, onTap: () => _openOrder(order)),
              const Divider(height: 1),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBalanceCard(context),
          const SizedBox(height: 12),
          _buildSalesSummaryCard(context),
          const SizedBox(height: 12),
          _buildInTransitCard(context),
          const SizedBox(height: 12),
          _buildFeeRateLines(context),
          const SizedBox(height: 8),
          Text('ประวัติรายรับ', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final balance = _totalsFor(_FinancePeriod.allTime).net;

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, color: colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  'ยอดคงเหลือสะสม',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: colorScheme.onPrimaryContainer),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              thaiBahtLabel(balance),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _balanceDisclaimer,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                label: 'ปุ่มถอนเงิน ยังไม่พร้อมใช้งานในเวอร์ชันนี้ แตะเพื่อดูรายละเอียด',
                button: true,
                excludeSemantics: true,
                // `container: true` -- without it, this node's label
                // merges into the surrounding Balance card's title/
                // value/disclaimer Text siblings into one combined
                // SemanticsNode (verified via debugDumpSemanticsTree),
                // instead of standing alone as its own accessible
                // element.
                container: true,
                child: OutlinedButton.icon(
                  onPressed: _showPayoutInfo,
                  icon: Icon(Icons.lock_outline, color: colorScheme.outline),
                  label: Text('ถอนเงิน', style: TextStyle(color: colorScheme.outline)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: colorScheme.outline)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesSummaryCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totals = _totalsFor(_selectedPeriod);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('สรุปยอดขาย', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<_FinancePeriod>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _FinancePeriod.today, label: Text('วันนี้')),
                ButtonSegment(value: _FinancePeriod.thisMonth, label: Text('เดือนนี้')),
                ButtonSegment(value: _FinancePeriod.allTime, label: Text('ทั้งหมด')),
              ],
              selected: {_selectedPeriod},
              onSelectionChanged: (selection) =>
                  setState(() => _selectedPeriod = selection.first),
            ),
            const SizedBox(height: 8),
            _summaryRow(context, 'ยอดขาย (Gross Sales)', thaiBahtLabel(totals.gross)),
            _summaryRow(
              context,
              'ค่าธรรมเนียม ZOKY',
              '− ${thaiBahtLabel(totals.fee)}',
              color: colorScheme.onSurfaceVariant,
            ),
            _summaryRow(
              context,
              'สุทธิ (Net Revenue)',
              thaiBahtLabel(totals.net),
              emphasize: true,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              'ยอดขาย (Gross Sales) ตรงกับยอดขายในหน้าแดชบอร์ด',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInTransitCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping_outlined, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'รายได้ระหว่างทาง (รอผู้ซื้อยืนยันรับสินค้า)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _inTransitCount == 0
                  ? 'ไม่มีคำสั่งซื้อที่กำลังจัดส่งอยู่ในขณะนี้'
                  : '${thaiBahtLabel(_inTransitSum)} จาก $_inTransitCount คำสั่งซื้อ',
            ),
            const SizedBox(height: 4),
            Text(
              'ยอดนี้ยังไม่ถูกนับรวมในยอดคงเหลือ จนกว่าลูกค้าจะยืนยันได้รับสินค้า',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeRateLines(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final feeLabel = _feePercent == _feePercent.roundToDouble()
        ? _feePercent.toStringAsFixed(0)
        : _feePercent.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ค่าธรรมเนียมแพลตฟอร์มปัจจุบัน: $feeLabel%',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          _feeRateDisclaimer,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
        ),
      ],
    );
  }

  /// Mirrors `SellerOrderDetailScreen._summaryRow` (label+value share
  /// the same style, [emphasize] switches it to a bold `titleSmall`),
  /// plus an optional [color] override for the Fee (grey) / Net
  /// (primary) rows -- neither of which is an error/success state, per
  /// the Design spec's decision #6.
  Widget _summaryRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
    Color? color,
  }) {
    final baseStyle = emphasize
        ? Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    final style = color != null ? baseStyle?.copyWith(color: color) : baseStyle;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
