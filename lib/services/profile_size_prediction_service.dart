import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

class ProfileSizePredictionService {
  static final Logger _log = Logger('ProfileSizePredictionService');
  static final ProfileSizePredictionService _instance =
      ProfileSizePredictionService._internal();
  factory ProfileSizePredictionService() => _instance;
  ProfileSizePredictionService._internal();

  Map<String, dynamic>? _data;
  bool _isLoading = false;

  Future<void> ensureLoaded() async {
    if (_data != null) return;
    if (_isLoading) {
      while (_data == null) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _isLoading = true;
    try {
      _log.info("Loading reference sizes...");
      final jsonString = await rootBundle.loadString(
        'data/reference_sizes_simple.json',
      );
      _data = jsonDecode(jsonString);
      _log.info(
        "Loaded reference sizes: ${(_data?['results'] as List?)?.length} entries.",
      );
    } catch (e) {
      _log.severe("Failed to load reference sizes: $e");
      _data = {'results': []};
    } finally {
      _isLoading = false;
    }
  }

  int? predictSize({
    required String? eid,
    String? smdpAddress,
    String? plmn,
    String? serviceProviderName,
  }) {
    if (_data == null) return null;

    final results = _data!['results'] as List<dynamic>;
    final referenceEum = _data!['reference_eum'] as String?;

    // Get EUM prefix from EID (first 8 digits)
    String? eumPrefix;
    if (eid != null && eid.length >= 8) {
      eumPrefix = eid.substring(0, 8);
    }

    // Try to find matching results
    // Priority:
    // 1. RSP + Service Provider + PLMN
    // 2. RSP + Service Provider
    // 3. RSP + PLMN
    // 4. RSP (Fallback)
    // If SM-DP+ is unknown, we prioritize SPN + PLMN
    dynamic bestMatch;
    int bestScore = 0;

    for (final result in results) {
      final rsp = result['rsp'] as String?;
      if (rsp == null) continue;

      int score = 0;
      bool rspMatches = false;

      // Match RSP address (SM-DP+ address)
      if (smdpAddress != null) {
        if (rsp.toLowerCase() == smdpAddress.toLowerCase()) {
          score += 1; // Base score for RSP match
          rspMatches = true;
        } else {
          continue; // Mismatch on provided SMDP
        }
      } else {
        // No SMDP provided, so we treat it as neutral, but we need OTHER matches
        rspMatches = true;
      }

      if (rspMatches) {
        // Check PLMN match
        if (plmn != null && result['plmn'] == plmn) {
          score += 2;
        }

        // Check Service Provider Name match
        // We use a loose contains check or exact match
        if (serviceProviderName != null) {
          final resultSpn = result['serviceProviderName'] as String?;
          if (resultSpn != null &&
              (resultSpn.toLowerCase() == serviceProviderName.toLowerCase() ||
                  serviceProviderName.toLowerCase().contains(
                    resultSpn.toLowerCase(),
                  ))) {
            score += 3; // SPN is very specific
          }
        }

        // If we didn't match RSP explicitly (smdpAddress was null), we require at least one other strong match (SPN or PLMN)
        if (smdpAddress == null && score == 0) continue;

        if (score > bestScore) {
          bestScore = score;
          bestMatch = result;
        }
      }
    }

    if (bestMatch != null) {
      final eumSizes = bestMatch['eum_sizes'] as Map<String, dynamic>?;

      // If we have an EUM prefix and it exists in eum_sizes, use it
      if (eumPrefix != null &&
          eumSizes != null &&
          eumSizes.containsKey(eumPrefix)) {
        return eumSizes[eumPrefix] as int;
      }

      // Otherwise fallback to reference_size or the reference_eum entry if prefix matches reference
      if (eumPrefix != null && eumPrefix == referenceEum) {
        return bestMatch['reference_size'] as int;
      }

      // If no prefix match, still use reference_size as the best guess
      return bestMatch['reference_size'] as int;
    }

    return null;
  }
}
