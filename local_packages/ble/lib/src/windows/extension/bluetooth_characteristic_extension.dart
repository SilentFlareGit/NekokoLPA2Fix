part of ble;

extension BluetoothCharacteristicExtension on BluetoothCharacteristic {
  BmBluetoothCharacteristic toProto() {
    return BmBluetoothCharacteristic(
      remoteId: DeviceIdentifier(remoteId.str),
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      descriptors: [for (final d in descriptors) d.toProto()],
      properties: properties.toProto(),
      primaryServiceUuid: null, // TODO:  API changes
    );
  }
}
