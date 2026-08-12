part of ble;

extension BluetoothAdapterStateExtension on BleState {
  BluetoothAdapterState toAdapterState() {
    switch (this) {
      case BleState.On:
        return BluetoothAdapterState.on;
      case BleState.Off:
        return BluetoothAdapterState.off;
      case BleState.Unknown:
        return BluetoothAdapterState.unknown;
      case BleState.Disabled:
        return BluetoothAdapterState.unavailable;
      case BleState.Unsupported:
        return BluetoothAdapterState.unauthorized;
    }
  }
}
