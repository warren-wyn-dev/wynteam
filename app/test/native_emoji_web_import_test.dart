import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PlatformViewHitTestBehavior is available for web platform views', () {
    expect(PlatformViewHitTestBehavior.transparent.name, 'transparent');
  });
}
