import Flutter
import UIKit
import CryptoTokenKit
import Foundation

extension String {
    var hexadecimal: Data? {
        var data = Data(capacity: count / 2)

        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self)) { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }

        guard data.count > 0 else { return nil }

        return data
    }
}

extension Data {
    var hexadecimal: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

public class CcidPlugin: NSObject, FlutterPlugin {
    var cards: [String: TKSmartCard] = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "ccid", binaryMessenger: registrar.messenger())
        let instance = CcidPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "listReaders":
            let manager = TKSmartCardSlotManager.default
            result(manager?.slotNames ?? [])
            
        case "listReaderATRs":
            guard let manager = TKSmartCardSlotManager.default else {
                result([:]) // Return an empty map if the manager is not available
                return
            }

            var slotATRMap = [String: String]()

            // Access all slot names
            for slotName in manager.slotNames {
                if let slot = manager.slotNamed(slotName),
                   slot.makeSmartCard() != nil {

                    // Get the ATR in hexadecimal
                    if let atrData = slot.atr?.bytes.hexadecimal {
                        slotATRMap[slotName] = atrData
                    } else {
                        slotATRMap[slotName] = ""
                    }
                } else {
                    slotATRMap[slotName] = "[NO_CARD]"
                }
            }
            result(slotATRMap)

        case "connect":
            let reader = call.arguments as! String
            let manager = TKSmartCardSlotManager.default
            if let slot = manager?.slotNamed(reader) {
                if let card = slot.makeSmartCard() {
                    cards[reader] = card
                    result(slot.atr?.bytes.hexadecimal)
                } else {
                    result(FlutterError(code: "NO_CARD", message: "Failed to find a card", details: nil))
                }
            } else {
                result(FlutterError(code: "INVALID_READER", message: "Invalid reader name", details: nil))
            }

        case "transceive":
            let args = call.arguments as! [String: Any?]
            let reader = args["reader"] as! String
            let capdu = args["capdu"] as! String
            let capduData = capdu.hexadecimal!
            
            if (cards[reader] == nil) {
                result(nil)
            } else {
                let card = cards[reader]!
                if card.isValid {
                    card.beginSession { (success, error) in
                        if !success {
                            result(self.mapTKError(error!, defaultCode: "BEGIN_SESSION_ERROR"))
                            return
                        }
                        card.transmit(capduData) { (rapdu, error) in
                            if let rapdu = rapdu {
                                result(rapdu.hexadecimal)
                            } else {
                                result(self.mapTKError(error!, defaultCode: "TRANSMIT_ERROR"))
                            }
                            card.endSession()
                        }
                    }
                } else {
                    cards.removeValue(forKey: reader)
                    result(nil)
                }
            }

        case "disconnect":
            let reader = call.arguments as! String
            cards.removeValue(forKey: reader)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func mapTKError(_ error: Error, defaultCode: String) -> FlutterError {
        let nsError = error as NSError
        if nsError.domain == TKErrorDomain {
            switch nsError.code {
            case TKError.Code.authenticationNeeded.rawValue:
                return FlutterError(code: "AuthenticationNeeded", message: error.localizedDescription, details: nil)
            case TKError.Code.badParameter.rawValue:
                return FlutterError(code: "BadParameter", message: error.localizedDescription, details: nil)
            case TKError.Code.tokenNotFound.rawValue:
                return FlutterError(code: "TokenNotFound", message: error.localizedDescription, details: nil)
            case TKError.Code.objectNotFound.rawValue:
                return FlutterError(code: "ObjectNotFound", message: error.localizedDescription, details: nil)
            case TKError.Code.authenticationFailed.rawValue:
                return FlutterError(code: "AuthenticationFailed", message: error.localizedDescription, details: nil)
            case TKError.Code.canceledByUser.rawValue:
                return FlutterError(code: "CanceledByUser", message: error.localizedDescription, details: nil)
            case TKError.Code.corruptedData.rawValue:
                return FlutterError(code: "CorruptedData", message: error.localizedDescription, details: nil)
            case TKError.Code.communicationError.rawValue:
                return FlutterError(code: "CommunicationError", message: error.localizedDescription, details: nil)
            case TKError.Code.notImplemented.rawValue:
                return FlutterError(code: "NotImplemented", message: error.localizedDescription, details: nil)
            default:
                break
            }
        }
        return FlutterError(code: defaultCode, message: error.localizedDescription, details: "\(nsError.domain):\(nsError.code)")
    }
}
