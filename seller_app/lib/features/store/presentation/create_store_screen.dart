import 'package:flutter/material.dart';

import '../data/seller_repository.dart';
import '../../../core/design/wyn_spacing.dart';

/// "สมัครร้าน" -- the shortest form that's still useful, on purpose
/// (logo/banner are SELLER-004's job, not this one). See
/// .wyn/docs/design/seller-001-foundation.md, Screen: CreateStoreScreen.
class CreateStoreScreen extends StatefulWidget {
  const CreateStoreScreen({
    super.key,
    required this.sellerRepository,
    required this.onStoreCreated,
  });

  final SellerRepository sellerRepository;

  /// Called after a store is successfully created. SellerAuthGate owns
  /// what happens next (re-checking fetchMyStore and rendering
  /// SellerHomeShell as its own child) -- this screen must not navigate
  /// on its own, since it is rendered *as* SellerAuthGate's route
  /// rather than pushed on top of it. Same
  /// callback-to-parent-rebuild pattern as `UsernameSetupScreen`'s
  /// `onUsernameSet` -- see .wyn/learning/PATTERNS.md.
  final VoidCallback onStoreCreated;

  @override
  State<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends State<CreateStoreScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty && !_isSubmitting;

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.sellerRepository.createStore(
        name: _nameController.text,
        description: _descriptionController.text,
      );
      widget.onStoreCreated();
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'สร้างร้านค้าไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างร้านค้า')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WynSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'เริ่มขายของบน ZOKY',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: WynSpacing.space2),
              Text(
                'ตั้งชื่อร้านค้าของคุณเพื่อเริ่มต้น',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: WynSpacing.space6),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อร้าน',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: WynSpacing.space4),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'คำอธิบายร้าน (ไม่บังคับ)',
                ),
              ),
              const SizedBox(height: WynSpacing.space6),
              FilledButton(
                onPressed: _canSubmit ? _submit : null,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('สร้างร้านค้า'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: WynSpacing.space4),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
