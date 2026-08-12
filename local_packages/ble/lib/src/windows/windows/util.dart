part of ble;

// Re-use common helpers from utils.dart

extension Boolean2ConnectionStateWin on bool {
  BluetoothConnectionState get isConnected {
    if (this) return BluetoothConnectionState.connected;
    return BluetoothConnectionState.disconnected;
  }
}
