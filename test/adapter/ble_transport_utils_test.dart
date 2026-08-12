import 'package:flutter_test/flutter_test.dart';
import 'package:nlpa2/adapter/ble/ble_transport_utils.dart';

void main() {
  test('uses negotiated ATT payload size within the protocol cap', () {
    expect(calculateBleWriteChunkSize(23), 20);
    expect(calculateBleWriteChunkSize(185), 182);
    expect(calculateBleWriteChunkSize(512), 240);
    expect(calculateBleWriteChunkSize(185, maxChunkSize: 100), 100);
  });

  test('prefers acknowledged writes whenever they are supported', () {
    expect(
      preferWriteWithoutResponse(canWrite: true, canWriteWithoutResponse: true),
      isFalse,
    );
    expect(
      preferWriteWithoutResponse(
        canWrite: false,
        canWriteWithoutResponse: true,
      ),
      isTrue,
    );
  });
}
