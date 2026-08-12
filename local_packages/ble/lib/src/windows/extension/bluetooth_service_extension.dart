part of ble;

extension BluetoothServiceExtension on BluetoothService {
  BmBluetoothService toProto() {
    return BmBluetoothService(
      serviceUuid: serviceUuid,
      remoteId: DeviceIdentifier(remoteId.str),
      characteristics: [for (final c in characteristics) c.toProto()],
      primaryServiceUuid: null, // TODO:  API changes
    );
  }
}
