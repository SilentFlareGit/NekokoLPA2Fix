class ApduException implements Exception {
  final int sw1;
  final int sw2;
  final String message;

  ApduException(this.sw1, this.sw2, this.message);

  @override
  String toString() =>
      "ApduException: $message (SW=${sw1.toRadixString(16).padLeft(2, '0').toUpperCase()}${sw2.toRadixString(16).padLeft(2, '0').toUpperCase()})";
}

class ConditionOfUseNotSatisfiedException extends ApduException {
  ConditionOfUseNotSatisfiedException(super.sw1, super.sw2, super.message);
}

class ProactiveRefreshException implements Exception {
  final int sw1;
  final int sw2;
  ProactiveRefreshException(this.sw1, this.sw2);
  @override
  String toString() =>
      "ProactiveRefreshException: 0x${sw1.toRadixString(16).padLeft(2, '0').toUpperCase()}${sw2.toRadixString(16).padLeft(2, '0').toUpperCase()}";
}

class CardBusyException implements Exception {
  final String message;
  CardBusyException(this.message);
  @override
  String toString() => "CardBusyException: $message";
}

class ApduValidator {
  static void validate(int sw1, int sw2) {
    if (sw1 == 0x90 && sw2 == 0x00) {
      return; // Success
    }

    // Check for specific errors
    if (sw1 == 0x6A && sw2 == 0x80) {
      throw ApduException(
        sw1,
        sw2,
        "Incorrect/invalid data field encoding (not a DER data object)",
      );
    }
    if (sw1 == 0x6A && sw2 == 0x88) {
      throw ApduException(
        sw1,
        sw2,
        "Reference data not found (unsupported/unknown command request)",
      );
    }
    if (sw1 == 0x69 && sw2 == 0x85) {
      throw ConditionOfUseNotSatisfiedException(
        sw1,
        sw2,
        "Conditions of use not satisfied (Profile state change ongoing)",
      );
    }
    if (sw1 == 0x68 && sw2 == 0x81) {
      throw CardBusyException("Card busy - session unavailable (6881)");
    }

    // Generic
    throw ApduException(sw1, sw2, "APDU failed");
  }
}
