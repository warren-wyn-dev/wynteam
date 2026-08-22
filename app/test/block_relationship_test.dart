import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/block/data/block_relationship.dart';

void main() {
  group('BlockRelationship.fromWire', () {
    test('maps every known wire value to its enum', () {
      expect(BlockRelationship.fromWire('blocked_by_me'), BlockRelationship.blockedByMe);
      expect(BlockRelationship.fromWire('blocked_me'), BlockRelationship.blockedMe);
      expect(BlockRelationship.fromWire('mutual'), BlockRelationship.mutual);
      expect(BlockRelationship.fromWire('none'), BlockRelationship.none);
    });

    test('falls back to none for an unrecognized value', () {
      expect(BlockRelationship.fromWire('something-unexpected'), BlockRelationship.none);
    });
  });

  group('isBlockedEitherWay', () {
    test('true for every relationship except none', () {
      expect(BlockRelationship.none.isBlockedEitherWay, isFalse);
      expect(BlockRelationship.blockedByMe.isBlockedEitherWay, isTrue);
      expect(BlockRelationship.blockedMe.isBlockedEitherWay, isTrue);
      expect(BlockRelationship.mutual.isBlockedEitherWay, isTrue);
    });
  });

  group('iBlockedThem', () {
    test('true only when I initiated the block (blockedByMe or mutual)', () {
      expect(BlockRelationship.blockedByMe.iBlockedThem, isTrue);
      expect(BlockRelationship.mutual.iBlockedThem, isTrue);
      expect(BlockRelationship.blockedMe.iBlockedThem, isFalse);
      expect(BlockRelationship.none.iBlockedThem, isFalse);
    });
  });
}
