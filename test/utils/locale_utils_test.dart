import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nlpa2/utils/locale_utils.dart';

void main() {
  const supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('zh', 'TW'),
    Locale('zh'),
  ];

  test('builds explicit locale from saved preference', () {
    expect(localeFromPreference(null), isNull);
    expect(localeFromPreference('zh_TW'), const Locale('zh', 'TW'));
    expect(
      localeFromPreference('zh-Hant-HK'),
      const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'HK',
      ),
    );
  });

  test('resolves simplified Chinese system locales to simplified Chinese', () {
    expect(
      resolveSupportedLocale(const Locale('zh', 'CN'), supportedLocales),
      const Locale('zh'),
    );
    expect(
      resolveSupportedLocale(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        supportedLocales,
      ),
      const Locale('zh'),
    );
  });

  test(
    'resolves traditional Chinese system locales to traditional Chinese',
    () {
      expect(
        resolveSupportedLocale(const Locale('zh', 'TW'), supportedLocales),
        const Locale('zh', 'TW'),
      );
      expect(
        resolveSupportedLocale(const Locale('zh', 'HK'), supportedLocales),
        const Locale('zh', 'TW'),
      );
      expect(
        resolveSupportedLocale(const Locale('zh', 'MO'), supportedLocales),
        const Locale('zh', 'TW'),
      );
    },
  );
}
