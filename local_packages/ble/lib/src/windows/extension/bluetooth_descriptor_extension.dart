part of ble;

extension BluetoothDescriptorExtension on BluetoothDescriptor {
  BmBluetoothDescriptor toProto() {
    return BmBluetoothDescriptor(
      remoteId: DeviceIdentifier(remoteId.str),
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      descriptorUuid: descriptorUuid,
      primaryServiceUuid: null, // TODO:  API changes
    );
  }
}
