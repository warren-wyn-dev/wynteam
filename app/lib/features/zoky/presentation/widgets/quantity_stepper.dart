import 'package:flutter/material.dart';

/// A +/- quantity control for Cart items (ZOKY-003) -- the first
/// component of this shape in the project. [max] is the product's
/// current stock (the real ceiling a buyer can add without a later
/// checkout rejecting it), not an arbitrary UI limit.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.max,
    required this.onChanged,
    this.min = 1,
  });

  final int quantity;
  final int max;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final atMax = quantity >= max;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          tooltip: 'ลดจำนวน',
          onPressed: quantity > min ? () => onChanged(quantity - 1) : null,
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: atMax ? 'สินค้าคงเหลือ $max ชิ้น' : 'เพิ่มจำนวน',
          onPressed: atMax ? null : () => onChanged(quantity + 1),
        ),
      ],
    );
  }
}
