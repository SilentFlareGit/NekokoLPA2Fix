import 'dart:js_interop';

@JS('navigator.smartCard')
external SmartCardResourceManager? get smartCard;

// @JS() // Remove @JS() on extension type if not needed or causing issues, but usually fine.
// The error was "Type argument 'void' doesn't conform to the bound 'JSAny?'".
// void is not a JSAny subtype. logic: use JSAny? for void promises.

extension type SmartCardResourceManager._(JSObject _) implements JSObject {
  external JSPromise<JSArray<SmartCardReader>> getReaders();
}

extension type SmartCardReader._(JSObject _) implements JSObject {
  external String get name;
  external JSPromise<SmartCardConnection> connect(String accessMode);
}

extension type SmartCardConnection._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> disconnect();
  external JSPromise<SmartCardResponse> transmit(SmartCardAPDU input);
}

@JS()
@anonymous
extension type SmartCardAPDU._(JSObject _) implements JSObject {
  external factory SmartCardAPDU({required JSUint8Array data});
}

@JS()
@anonymous
extension type SmartCardResponse._(JSObject _) implements JSObject {
  external JSArrayBuffer get data;
  external int get sw;
}
