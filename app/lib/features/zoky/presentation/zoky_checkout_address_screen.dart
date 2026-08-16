import 'package:flutter/material.dart';

import '../data/cart_item.dart';
import '../data/zoky_repository.dart';
import 'zoky_checkout_summary_screen.dart';
import '../../../core/design/wyn_spacing.dart';

/// Screen 3 (ZOKY-003) -- Checkout step 1 of 2: shipping address form.
/// Deliberately its own screen rather than folded into the summary
/// below it, so the buyer always sees the fee/total breakdown in full
/// (Screen 4) before there's ever a "confirm" button to tap. See
/// .wyn/docs/design/zoky-003-cart-checkout-order.md, Screen 3.
class ZokyCheckoutAddressScreen extends StatefulWidget {
  const ZokyCheckoutAddressScreen({
    super.key,
    required this.zokyRepository,
    required this.cartItems,
  });

  final ZokyRepository zokyRepository;
  final List<CartItem> cartItems;

  @override
  State<ZokyCheckoutAddressScreen> createState() => _ZokyCheckoutAddressScreenState();
}

class _ZokyCheckoutAddressScreenState extends State<ZokyCheckoutAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _next() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ZokyCheckoutSummaryScreen(
          zokyRepository: widget.zokyRepository,
          cartItems: widget.cartItems,
          recipientName: _nameController.text.trim(),
          recipientPhone: _phoneController.text.trim(),
          shippingAddress: _addressController.text.trim(),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'กรุณากรอกข้อมูล';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ที่อยู่จัดส่ง')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(WynSpacing.space4),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'ชื่อผู้รับ'),
                validator: _required,
              ),
              const SizedBox(height: WynSpacing.space4),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์'),
                keyboardType: TextInputType.phone,
                validator: _required,
              ),
              const SizedBox(height: WynSpacing.space4),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'ที่อยู่จัดส่ง'),
                maxLines: 3,
                validator: _required,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WynSpacing.space4),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _next, child: const Text('ถัดไป')),
          ),
        ),
      ),
    );
  }
}
