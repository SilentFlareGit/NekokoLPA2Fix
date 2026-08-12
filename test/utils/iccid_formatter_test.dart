import 'package:flutter_test/flutter_test.dart';
import 'package:nlpa2/utils/iccid_formatter.dart';

void main() {
  group('IccidFormatter', () {
    test('removes trailing filler nibbles', () {
      expect(
        IccidFormatter.forDisplay('8988211000000000000F'),
        '8988211000000000000',
      );
      expect(
        IccidFormatter.forDisplay('8988211000000000000fff'),
        '8988211000000000000',
      );
    });

    test('preserves non-trailing filler characters', () {
      expect(
        IccidFormatter.forDisplay('8988F211000000000000'),
        '8988F211000000000000',
      );
    });
  });
}
