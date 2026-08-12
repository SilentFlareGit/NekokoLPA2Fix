import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nlpa2/utils/imei_codec.dart';

void main() {
  test('encodes stored 15 digit IMEI as swapped BCD with F filler', () {
    final stored = Uint8List.fromList([
      0x35,
      0x20,
      0x99,
      0x00,
      0x17,
      0x61,
      0x48,
      0x10,
    ]);

    expect(imeiDigitsFromStoredBytes(stored), '352099001761481');
    expect(tacDigitsFromStoredBytes(stored), '35209900');
    expect(
      encodeDeviceInfoImei(stored),
      Uint8List.fromList([0x53, 0x02, 0x99, 0x00, 0x71, 0x16, 0x84, 0xf1]),
    );
  });

  test('builds stored IMEI bytes from default TAC', () {
    final stored = storedImeiBytesFromDigits(
      defaultDeviceTac,
      random: Random(1),
    );
    final digits = imeiDigitsFromStoredBytes(stored);

    expect(digits, hasLength(15));
    expect(digits, startsWith(defaultDeviceTac));
    expect(
      digits[14],
      calculateImeiLuhnChecksum(digits.substring(0, 14)).toString(),
    );
    expect(tacDigitsFromStoredBytes(stored), defaultDeviceTac);
  });

  test('normalizes full IMEI digits to stored bytes with filler nibble', () {
    final stored = storedImeiBytesFromDigits('353837410000013');

    expect(imeiDigitsFromStoredBytes(stored), '353837410000013');
    expect(stored.last & 0x0f, 0);
  });

  test('normalizes a numeric 64-bit IMEI split into integer parts', () {
    final numeric = BigInt.parse('353837410000013');
    final high = (numeric >> 32).toInt();
    final low = (numeric & BigInt.from(0xffffffff)).toInt();

    final stored = storedImeiBytesFromIntegerParts(high, low);

    expect(imeiDigitsFromStoredBytes(stored), '353837410000013');
    expect(
      encodeDeviceInfoImei(stored),
      Uint8List.fromList([0x53, 0x83, 0x73, 0x14, 0x00, 0x00, 0x10, 0xf3]),
    );
  });

  test('normalizes numeric IMEI bytes containing a hexadecimal nibble', () {
    final raw = ByteData(8)..setUint64(0, 744506485380692, Endian.big);
    final bytes = raw.buffer.asUint8List();

    expect(bytes[2], 0xa5);
    expect(
      encodeDeviceInfoImei(bytes),
      Uint8List.fromList([0x47, 0x54, 0x60, 0x84, 0x35, 0x08, 0x96, 0xf2]),
    );
  });

  test('preserves legacy packed BCD integer parts', () {
    final stored = storedImeiBytesFromIntegerParts(0x35383741, 0x00000130);

    expect(imeiDigitsFromStoredBytes(stored), '353837410000013');
  });

  test('normalizes decimal and packed BCD TAC integers', () {
    final expected = Uint8List.fromList([0x35, 0x38, 0x37, 0x41]);

    expect(tacBytesFromInteger(35383741), expected);
    expect(tacBytesFromInteger(0x35383741), expected);
  });
}
