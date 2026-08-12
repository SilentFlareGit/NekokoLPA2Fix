import 'dart:math';
import 'dart:typed_data';

const String defaultDeviceTac = '35383741';

/// Converts the app's ordinary digit-order IMEI bytes into the swapped BCD
/// encoding used by GSMA deviceInfo.imei.
Uint8List encodeDeviceInfoImei(List<int> imei) {
  final digits = _imeiDigitsFromStoredOrIntegerBytes(imei);
  return _encodeSwappedBcd(digits);
}

/// Signing callers historically supplied an IMEI either as persisted BCD or
/// as the big-endian bytes of one unsigned 64-bit decimal value. Normalize at
/// the final deviceInfo boundary as well as in the JavaScript bridge so neither
/// representation can leak a hexadecimal nibble into the IMEI encoder.
String _imeiDigitsFromStoredOrIntegerBytes(List<int> imei) {
  try {
    return imeiDigitsFromStoredBytes(imei);
  } on FormatException {
    final digits = _imeiDigitsFromUnsignedIntegerBytes(imei);
    if (digits == null) rethrow;
    return digits;
  }
}

String? _imeiDigitsFromUnsignedIntegerBytes(List<int> imei) {
  if (imei.length != 8 || imei.any((byte) => byte < 0 || byte > 0xff)) {
    return null;
  }

  var numeric = BigInt.zero;
  for (final byte in imei) {
    numeric = (numeric << 8) | BigInt.from(byte);
  }
  final digits = numeric.toString();
  return digits.length == 15 ? digits : null;
}

/// Normalizes the two 32-bit values used by the signing bridge.
///
/// Older callers pass packed BCD bytes split into two integers, while newer
/// callers may split an ordinary 15-digit IMEI as one unsigned 64-bit integer.
/// Accept both representations at this API boundary.
Uint8List storedImeiBytesFromIntegerParts(int high, int low) {
  final normalizedHigh = high & 0xffffffff;
  final normalizedLow = low & 0xffffffff;
  final bytes = ByteData(8)
    ..setUint32(0, normalizedHigh, Endian.big)
    ..setUint32(4, normalizedLow, Endian.big);
  final packed = bytes.buffer.asUint8List();

  try {
    imeiDigitsFromStoredBytes(packed);
    return packed;
  } on FormatException {
    final digits = _imeiDigitsFromUnsignedIntegerBytes(packed);
    if (digits == null) {
      throw FormatException(
        'IMEI integer must contain exactly 15 decimal digits',
      );
    }
    return _encodeStoredBytes(digits);
  }
}

/// Accepts either an ordinary 8-digit TAC integer or a legacy packed-BCD
/// integer and returns the four bytes expected by deviceInfo.tac.
Uint8List tacBytesFromInteger(int value) {
  final decimal = value.toString();
  if (RegExp(r'^[0-9]{8}$').hasMatch(decimal)) {
    return Uint8List.fromList(
      List.generate(
        4,
        (index) =>
            int.parse(decimal.substring(index * 2, index * 2 + 2), radix: 16),
      ),
    );
  }

  final normalized = value & 0xffffffff;
  final bytes = ByteData(4)..setUint32(0, normalized, Endian.big);
  final packed = bytes.buffer.asUint8List();
  for (final byte in packed) {
    if ((byte >> 4) > 9 || (byte & 0x0f) > 9) {
      throw FormatException('TAC must contain exactly 8 decimal digits');
    }
  }
  return packed;
}

/// Reads IMEI digits from the app's persisted byte format.
///
/// The settings value is 8 bytes in ordinary digit order, with the final
/// nibble used as filler for a 15-digit IMEI. deviceInfo.imei must not expose
/// that filler as a real digit.
String imeiDigitsFromStoredBytes(List<int> imei) {
  if (imei.length != 8) {
    throw ArgumentError.value(imei.length, 'imei.length', 'must be 8 bytes');
  }

  final digits = StringBuffer();
  for (var index = 0; index < imei.length; index++) {
    final byte = imei[index];
    final nibbles = [(byte >> 4) & 0x0f, byte & 0x0f];
    for (var nibbleIndex = 0; nibbleIndex < nibbles.length; nibbleIndex++) {
      final isLastNibble = index == imei.length - 1 && nibbleIndex == 1;
      final nibble = nibbles[nibbleIndex];
      if (isLastNibble) {
        break;
      }
      if (nibble > 9) {
        throw FormatException(
          'invalid IMEI digit nibble: 0x${nibble.toRadixString(16)}',
        );
      }
      digits.write(nibble);
    }
  }

  return digits.toString();
}

String tacDigitsFromStoredBytes(List<int> imei) {
  final digits = imeiDigitsFromStoredBytes(imei);
  if (digits.length < 8) {
    throw FormatException('stored IMEI is too short for TAC: $digits');
  }
  return digits.substring(0, 8);
}

Uint8List storedImeiBytesFromDigits(String value, {Random? random}) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  final imeiDigits = switch (digits.length) {
    8 => imeiDigitsFromTac(digits, random: random),
    15 => digits,
    16 => digits.substring(0, 15),
    _ => throw FormatException('Enter an 8-digit TAC or 15-digit IMEI'),
  };

  return _encodeStoredBytes(imeiDigits);
}

String imeiDigitsFromTac(String tac, {Random? random}) {
  final digits = tac.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length != 8) {
    throw FormatException('TAC must be exactly 8 digits');
  }

  final rng = random ?? Random();
  final body = StringBuffer(digits);
  while (body.length < 14) {
    body.write(rng.nextInt(10));
  }

  final checkDigit = calculateImeiLuhnChecksum(body.toString());
  return '$body$checkDigit';
}

int calculateImeiLuhnChecksum(String bodyDigits) {
  final digits = bodyDigits.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length != 14) {
    throw FormatException('IMEI body must be exactly 14 digits');
  }

  var sum = 0;
  for (var index = 0; index < digits.length; index++) {
    var digit = int.parse(digits[index]);
    if (index.isOdd) {
      digit *= 2;
      if (digit > 9) {
        digit = (digit % 10) + 1;
      }
    }
    sum += digit;
  }

  return (10 - (sum % 10)) % 10;
}

Uint8List _encodeStoredBytes(String digits) {
  if (digits.length != 15) {
    throw FormatException('stored IMEI source must be exactly 15 digits');
  }

  final imei = Uint8List(8);
  for (var index = 0; index < 7; index++) {
    imei[index] =
        (int.parse(digits[index * 2]) << 4) | int.parse(digits[index * 2 + 1]);
  }
  imei[7] = int.parse(digits[14]) << 4;
  return imei;
}

Uint8List _encodeSwappedBcd(String digits) {
  if (digits.length.isOdd) {
    digits += 'F';
  }

  final out = Uint8List(digits.length ~/ 2);
  for (var index = 0; index < out.length; index++) {
    final first = int.parse(digits[index * 2], radix: 16);
    final second = int.parse(digits[index * 2 + 1], radix: 16);
    out[index] = ((second << 4) & 0xf0) | (first & 0x0f);
  }
  return out;
}
