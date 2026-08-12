import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

class CustomHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return true;
      };
  }
}

class SmdpException implements Exception {
  final String subjectCode;
  final String reasonCode;
  final String subjectIdentifier;
  final String message;
  final int? statusCode;

  SmdpException({
    required this.subjectCode,
    required this.reasonCode,
    required this.subjectIdentifier,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() {
    String detail = "SM-DP+ Error ($subjectCode, $reasonCode)";
    if (statusCode != null) detail += " [HTTP $statusCode]";
    return "$detail\n"
        "Identifier: $subjectIdentifier\n"
        "Message: $message";
  }
}

class SmdpClient {
  static final Logger _log = Logger('SmdpClient');

  static void init() {
    HttpOverrides.global = CustomHttpOverrides();
  }

  static Future<Map<String, dynamic>> post({
    required String smdpAddress,
    required String endpoint,
    required Map<String, dynamic> bodyData,
    bool checkStatus = true,
  }) async {
    init();

    final smdpAddress0 = smdpAddress.trim();

    final url = Uri.parse(
      kIsWeb
          ? 'https://nlpa-data.nekoko.ee/rsp/$smdpAddress0/gsma/rsp2/es9plus/$endpoint'
          : 'https://$smdpAddress0/gsma/rsp2/es9plus/$endpoint',
    );
    final headers = kIsWeb
        ? {'Content-Type': 'application/json'}
        : {
            'User-Agent': 'gsma-rsp-lpad',
            'X-Admin-Protocol': 'gsma/rsp/v2.2.0',
            'Content-Type': 'application/json',
          };

    final body = jsonEncode(bodyData);
    final stopwatch = Stopwatch()..start();

    try {
      _log.info("SM-DP+ POST $endpoint -> $url (bodyBytes=${body.length})");
      _log.fine("HEADERS: $headers");
      _log.fine("BODY: $body");

      final response = await http.post(url, headers: headers, body: body);

      stopwatch.stop();
      _log.info(
        "SM-DP+ RESPONSE $endpoint <- ${response.statusCode} "
        "(${stopwatch.elapsedMilliseconds}ms, bodyBytes=${response.body.length})",
      );
      _log.fine("BODY: ${response.body}");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return {};
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          _log.info("SM-DP+ RESPONSE $endpoint keys: ${data.keys.join(', ')}");
        }
        if (checkStatus) {
          _checkResponse(data, response.statusCode);
        }
        return data;
      } else {
        throw Exception(
          "SM-DP+ Network Error ${response.statusCode}: ${response.body}",
        );
      }
    } on SmdpException {
      rethrow;
    } catch (e, stackTrace) {
      stopwatch.stop();
      if (e.toString().contains("SM-DP+")) rethrow;
      _log.severe(
        "SmdpClient connection error on $endpoint after "
        "${stopwatch.elapsedMilliseconds}ms: $e",
        e,
        stackTrace,
      );
      throw Exception("Failed to contact SM-DP+ at $smdpAddress: $e");
    }
  }

  static void _checkResponse(Map<String, dynamic> data, int httpStatus) {
    if (data.containsKey('header')) {
      final header = data['header'];
      if (header.containsKey('functionExecutionStatus')) {
        final status = header['functionExecutionStatus'];
        if (status['status'] == 'Failed') {
          final codeData = status['statusCodeData'] ?? {};
          throw SmdpException(
            subjectCode: codeData['subjectCode'] ?? 'N/A',
            reasonCode: codeData['reasonCode'] ?? 'N/A',
            subjectIdentifier: codeData['subjectIdentifier'] ?? 'N/A',
            message: codeData['message'] ?? 'Unknown SM-DP+ Error',
            statusCode: httpStatus,
          );
        }
      }
    }
  }
}
