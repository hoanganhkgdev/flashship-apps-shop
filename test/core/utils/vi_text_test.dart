import 'package:flashship_shop/core/utils/vi_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('foldVietnamese strips accents, case and đ', () {
    expect(foldVietnamese('Sân Bay Đường Bào'), 'san bay duong bao');
    expect(foldVietnamese('Rạch Vẹm · Ông Lang'), 'rach vem · ong lang');
  });

  test('matchesVietnamese ignores accents, case and word order', () {
    expect(matchesVietnamese('Sân bay Rạch Giá', 'san bay'), isTrue);
    expect(matchesVietnamese('Sân bay Rạch Giá', 'GIA rach'), isTrue);
    expect(matchesVietnamese('Sân bay Rạch Giá', 'cho'), isFalse);
  });

  test('an empty query matches everything', () {
    expect(matchesVietnamese('Bãi Thơm', ''), isTrue);
    expect(matchesVietnamese('Bãi Thơm', '   '), isTrue);
  });
}
