import '../services/smdp_client.dart';

class Es9PlusService {
  static final Es9PlusService _instance = Es9PlusService._internal();
  factory Es9PlusService() => _instance;
  Es9PlusService._internal();

  Future<Map<String, dynamic>> initiateAuthentication({
    required String smdpAddress,
    required String euiccChallenge, // Base64
    required String euiccInfo1, // Base64
    required String clientTransactionId,
  }) async {
    return await SmdpClient.post(
      smdpAddress: smdpAddress,
      endpoint: 'initiateAuthentication',
      bodyData: {
        'euiccChallenge': euiccChallenge,
        'euiccInfo1': euiccInfo1,
        'smdpAddress': smdpAddress,
      },
    );
  }

  Future<Map<String, dynamic>> authenticateClient({
    required String smdpAddress,
    required String transactionId,
    required String authenticateServerResponse, // Base64
  }) async {
    return await SmdpClient.post(
      smdpAddress: smdpAddress,
      endpoint: 'authenticateClient',
      bodyData: {
        'transactionId': transactionId,
        'authenticateServerResponse': authenticateServerResponse,
      },
    );
  }

  Future<Map<String, dynamic>> getBoundProfilePackage({
    required String smdpAddress,
    required String transactionId,
    required String prepareDownloadResponse, // Base64
  }) async {
    return await SmdpClient.post(
      smdpAddress: smdpAddress,
      endpoint: 'getBoundProfilePackage',
      bodyData: {
        'transactionId': transactionId,
        'prepareDownloadResponse': prepareDownloadResponse,
      },
    );
  }
}
