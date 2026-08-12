import 'dart:js_interop';

@JS('navigator.webcard')
external WebCard? get webCard;

extension type WebCard._(JSObject _) implements JSObject {
  external JSPromise<JSArray<WebCardReader>> readers();
  external String get installerUrl;
  external JSPromise<WebCardVersions> getVersions();
}

extension type WebCardVersions._(JSObject _) implements JSObject {
  external String get addon;
  external String get app;
  external String get latest;
}

extension type WebCardReader._(JSObject _) implements JSObject {
  external String get name;
  external String get atr;

  // The API documentation suggests connect/disconnect/transceive are on the reader object itself
  external JSPromise<JSString> connect([bool exclusive]);
  external JSPromise<JSAny?> disconnect();

  @JS('transceive')
  external JSPromise<JSString> transceive(String capdu);
}
