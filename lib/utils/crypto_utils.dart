import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import './hex_utils.dart';
import 'package:logging/logging.dart';

class CryptoUtils {
  static final Logger _log = Logger('CryptoUtils');

  static Uint8List computeHashCc(
    String confirmationCode,
    Uint8List transactionId,
  ) {
    // HashCc = SHA256 (SHA256 (Confirmation Code) | TransactionID)
    // SGP.22 specifies that TransactionID is the binary octet string (16 bytes).

    Uint8List binaryTxnId = transactionId;

    // Fallback: If passed a 32-character ASCII hex representation instead of 16 binary bytes
    if (transactionId.length == 32) {
      try {
        final hexString = String.fromCharCodes(transactionId);
        if (RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(hexString)) {
          _log.info(
            "computeHashCc: Detected 32-byte ASCII hex TransactionID, decoding to 16-byte binary.",
          );
          binaryTxnId = HexUtils.hexToBytes(hexString);
        }
      } catch (_) {
        // Not decodable as ASCII, treat as raw binary (even though length is 32)
      }
    }

    if (binaryTxnId.length != 16) {
      _log.warning(
        "WARNING: TransactionID length is ${binaryTxnId.length}, expected 16 bytes for binary form.",
      );
    }

    // 1. SHA256 of CC (UTF-8 encoded)
    final ccBytes = utf8.encode(confirmationCode);
    final firstHash = sha256.convert(ccBytes).bytes;

    // 2. Concatenate firstHash (32 bytes) and binaryTxnId (16 bytes)
    final combined = Uint8List(firstHash.length + binaryTxnId.length);
    combined.setAll(0, firstHash);
    combined.setAll(firstHash.length, binaryTxnId);

    // 3. Final SHA256
    final finalHash = sha256.convert(combined).bytes;

    return Uint8List.fromList(finalHash);
  }

  /// Generate AES key from password using SHA256
  static Uint8List keyFromPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return Uint8List.fromList(digest.bytes);
  }

  /// Encrypt JSON data using AES-256-CBC
  /// Returns base64(iv + ciphertext)
  static String encryptAES(String plaintext, String password) {
    final key = keyFromPassword(password);
    return encryptAESWithKey(plaintext, key);
  }

  static String encryptAESWithKey(String plaintext, Uint8List key) {
    try {
      final iv = Uint8List(16);
      final random = Random.secure();
      for (var i = 0; i < 16; i++) {
        iv[i] = random.nextInt(256);
      }

      final params = PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(key), iv),
        null,
      );

      final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
      cipher.init(true, params);

      final input = Uint8List.fromList(utf8.encode(plaintext));
      final encrypted = cipher.process(input);

      final combined = Uint8List(iv.length + encrypted.length);
      combined.setAll(0, iv);
      combined.setAll(iv.length, encrypted);

      return base64Encode(combined);
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  /// Decrypt JSON data using AES-256-CBC
  /// Expects base64(iv + ciphertext)
  static String decryptAES(String ciphertext, String password) {
    final key = keyFromPassword(password);
    return decryptAESWithKey(ciphertext, key);
  }

  static String decryptAESWithKey(String ciphertext, Uint8List key) {
    try {
      final combined = base64Decode(ciphertext);
      final iv = combined.sublist(0, 16);
      final encrypted = combined.sublist(16);

      final params = PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(key), iv),
        null,
      );

      final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
      cipher.init(false, params);

      final decrypted = cipher.process(encrypted);
      return utf8.decode(decrypted);
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }
}
