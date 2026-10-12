import 'package:flashship_shop/core/utils/support_links.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _c(String type, String value, [String? link]) =>
    supportLaunchCandidates(type: type, value: value, link: link)
        .map((u) => '$u')
        .toList();

void main() {
  group('phone', () {
    test('uses the server tel link', () {
      expect(_c('phone', '0909123456', 'tel:0909123456'), ['tel:0909123456']);
    });

    test('builds a tel link from the raw number when the server sent none', () {
      expect(_c('phone', '0909 123 456'), ['tel:0909123456']);
      expect(_c('phone', 'tel:0909123456'), ['tel:0909123456']);
    });
  });

  group('zalo', () {
    test('opens the zalo.me universal link, which launches the Zalo app', () {
      expect(_c('zalo', '0909123456', 'https://zalo.me/0909123456'),
          ['https://zalo.me/0909123456']);
    });

    test('builds the link from a raw phone number without a server link', () {
      expect(_c('zalo', '0909123456'), ['https://zalo.me/0909123456']);
    });
  });

  group('facebook', () {
    test('tries the Facebook app first and falls back to the web page', () {
      final c = _c('facebook', 'flashship', 'https://facebook.com/flashship');
      expect(c, [
        'fb://facewebmodal/f?href=https%3A%2F%2Ffacebook.com%2Fflashship',
        'https://facebook.com/flashship',
      ]);
    });

    test('turns a bare page name into a facebook.com address', () {
      expect(
          _c('facebook', 'flashship').last, 'https://facebook.com/flashship');
    });
  });

  test('email, website and other use the matching link', () {
    expect(_c('email', 'ho.tro@flashship.vn', 'mailto:ho.tro@flashship.vn'),
        ['mailto:ho.tro@flashship.vn']);
    expect(_c('website', 'flashship.vn', 'https://flashship.vn'),
        ['https://flashship.vn']);
    expect(_c('website', 'flashship.vn'), ['https://flashship.vn']);
    expect(_c('other', 'khong hop le'), isEmpty);
  });

  test('an empty value yields no candidates', () {
    expect(_c('phone', ''), isEmpty);
    expect(_c('zalo', ''), isEmpty);
    expect(_c('facebook', ''), isEmpty);
  });
}
