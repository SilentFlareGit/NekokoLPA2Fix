import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../adapter/euicc_adapter.dart';
import '../adapter/composite_adapter.dart';
import '../logic/profile_manager.dart';
import '../plugins/build_plugin_registry.dart';
import '../services/es9plus_service.dart';
import '../widgets/signing_confirmation_dialog.dart';
import '../main.dart';
import '../settings/app_settings.dart';
import '../utils/imei_codec.dart';
import 'package:logging/logging.dart';

class SigningLogic {
  static final Logger _log = Logger('SigningLogic');

  static Future<String?> sign({
    required String smdpAddress,
    required String matchingId,
    int? tac,
    int? imeiHigh,
    int? imeiLow,
    String? imei,
  }) async {
    final composite = CompositeAdapter();
    // Use the internal reader listing to get fresh list
    final readers = await composite.listReaders();

    if (readers.isEmpty) {
      _log.warning("Sign requested but no cards found");
      throw Exception("No cards found");
    }

    // Populate EIDs from persisted settings if not already set
    final settings = AppSettings();
    for (final reader in readers) {
      if (reader.eid == null || reader.eid!.isEmpty) {
        final persistedEid = settings.getPersistedEid(reader.id);
        if (persistedEid != null) {
          reader.eid = persistedEid;
        }
      }
    }

    // If params not specified, we'll get the defaults from AppSettings to show in the dialog
    final displayTac =
        tac ??
        ByteData.sublistView(await settings.getTac()).getUint32(0, Endian.big);
    final imeiBytes = await settings.getImei();
    final displayImeiHigh =
        imeiHigh ?? ByteData.sublistView(imeiBytes).getUint32(0, Endian.big);
    final displayImeiLow =
        imeiLow ?? ByteData.sublistView(imeiBytes).getUint32(4, Endian.big);

    final tacBytes = tac != null ? convertTac(tac) : null;
    final imeiBytesFinal = imei != null
        ? storedImeiBytesFromDigits(imei)
        : (imeiHigh != null && imeiLow != null)
        ? convertImei(imeiHigh, imeiLow)
        : null;

    final currentContext = navigatorKey.currentContext;
    if (currentContext == null || !currentContext.mounted) {
      _log.severe("No context available for signing prompt");
      throw Exception("Internal error: No UI context");
    }

    return await showDialog<String>(
      context: currentContext,
      barrierDismissible: false,
      builder: (context) => SigningConfirmationDialog(
        smdpAddress: smdpAddress,
        matchingId: matchingId,
        readers: readers,
        tac: displayTac,
        imeiHigh: displayImeiHigh,
        imeiLow: displayImeiLow,
        onSign: (reader, updateStatus) => _performSigning(
          reader: reader,
          smdpAddress: smdpAddress,
          matchingId: matchingId,
          tac: tacBytes,
          imei: imeiBytesFinal,
          updateStatus: updateStatus,
        ),
      ),
    );
  }

  static Future<String?> _performSigning({
    required Reader reader,
    required String smdpAddress,
    required String matchingId,
    Uint8List? tac,
    Uint8List? imei,
    required void Function(String status) updateStatus,
  }) async {
    _log.info(
      "Starting signing flow for SM-DP+: $smdpAddress, MatchingID: $matchingId on reader: ${reader.name}",
    );

    final adapter = reader.source;
    final profileManager = ProfileManager(adapter);
    for (var plugin in BuildPluginRegistry.createSessionPlugins()) {
      profileManager.addSessionPlugin(plugin);
    }

    try {
      updateStatus("Connecting...");
      await adapter.connect(reader);
      final channel = await profileManager.openSession();
      try {
        updateStatus("Getting eUICC info...");
        final challenge = await profileManager.getEuiccChallenge(
          useChannel: channel,
        );
        final info1 = await profileManager.getEuiccInfo1(useChannel: channel);

        updateStatus("Authenticating with SM-DP+...");
        final initAuthResp = await Es9PlusService().initiateAuthentication(
          smdpAddress: smdpAddress,
          euiccChallenge: base64Encode(challenge),
          euiccInfo1: base64Encode(info1),
          clientTransactionId: "sign_0",
        );

        if (initAuthResp['serverSigned1'] == null) {
          _log.severe(
            "SM-DP+ initiateAuthentication failed: ${initAuthResp['errorCode'] ?? 'Unknown error'}",
          );
          throw Exception(
            "Server failed to initiate authentication: ${initAuthResp['errorCode'] ?? ''}",
          );
        }

        final serverSigned1 = base64Decode(initAuthResp['serverSigned1']);
        final serverSignature1 = base64Decode(initAuthResp['serverSignature1']);
        final euiccCiPKId = base64Decode(initAuthResp['euiccCiPKIdToBeUsed']);
        final serverCert = base64Decode(initAuthResp['serverCertificate']);

        updateStatus("Signing...");
        final authResp = await profileManager.authenticateServer(
          serverSigned1: serverSigned1,
          serverSignature1: serverSignature1,
          euiccCiPKIdToBeUsed: euiccCiPKId,
          serverCertificate: serverCert,
          matchingId: matchingId,
          tac: tac,
          imei: imei,
          useChannel: channel,
        );

        final responseData = authResp.encode();

        _log.info("Signing successful, returning authenticateServerResponse.");
        return base64Encode(responseData);
      } finally {
        await channel.close();
      }
    } catch (e, stack) {
      _log.severe("Signing flow failed: $e", e, stack);
      rethrow;
    }
  }

  static Uint8List convertTac(int value) {
    return tacBytesFromInteger(value);
  }

  static Uint8List convertImei(int high, int low) {
    return storedImeiBytesFromIntegerParts(high, low);
  }
}
