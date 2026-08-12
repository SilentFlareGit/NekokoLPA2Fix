import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nlpa2/l10n/app_localizations.dart';
import 'package:nlpa2/pages/aram_info_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('ee.nekoko.certificate_plugin');
  const legacySha1 = 'C47350C7BA682B34A3E584A0D58463EA42B1AD73';
  const currentSha1 = 'D1C0F48B370E74D4EA4770ED4C3CD70A3198D31F';

  Future<void> pumpPage(
    WidgetTester tester,
    Map<String, List<String>> response,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getCertificateHashes');
          return response;
        });

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AramInfoPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('shows every ARA-M signing-history hash', (tester) async {
    await pumpPage(tester, {
      'sha1': [currentSha1],
      'aramSha1': [legacySha1, currentSha1],
    });

    expect(find.text(legacySha1), findsOneWidget);
    expect(find.text(currentSha1), findsOneWidget);
    expect(find.text('Certificate SHA-1 Hash'), findsNWidgets(2));
  });

  testWidgets('falls back to current hashes for older native builds', (
    tester,
  ) async {
    await pumpPage(tester, {
      'sha1': [currentSha1],
      'aramSha1': const [],
    });

    expect(find.text(currentSha1), findsOneWidget);
    expect(find.text(legacySha1), findsNothing);
  });
}
