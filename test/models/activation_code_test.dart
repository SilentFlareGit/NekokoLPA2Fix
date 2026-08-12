import 'package:flutter_test/flutter_test.dart';
import 'package:nlpa2/models/activation_code.dart';

void main() {
  group('ActivationCode', () {
    test('parses the required SM-DP+ and matching ID fields', () {
      final code = ActivationCode.parse('LPA:1\$smdp.example\$MATCH123');

      expect(code, isNotNull);
      expect(code!.format, 'LPA:1');
      expect(code.smdpAddress, 'smdp.example');
      expect(code.matchingId, 'MATCH123');
      expect(code.smdpOid, isNull);
      expect(code.confirmationCode, isNull);
    });

    test('round-trips optional OID and confirmation code', () {
      final code = ActivationCode(
        format: 'LPA:1',
        smdpAddress: 'smdp.example',
        matchingId: 'MATCH123',
        smdpOid: '1.2.3',
        confirmationCode: '123456',
      );

      expect(code.toString(), 'LPA:1\$smdp.example\$MATCH123\$1.2.3\$123456');
      expect(ActivationCode.parse(code.toString())!.confirmationCode, '123456');
    });

    test('rejects non-LPA activation strings', () {
      expect(ActivationCode.parse('https://example.com'), isNull);
    });
  });
}
