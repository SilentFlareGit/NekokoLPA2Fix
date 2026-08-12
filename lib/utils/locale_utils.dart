import 'package:flutter/widgets.dart';

Locale? localeFromPreference(String? value) {
  if (value == null || value.isEmpty) return null;

  final parts = value.replaceAll('-', '_').split('_');
  if (parts.length == 1) {
    return Locale.fromSubtags(languageCode: parts[0]);
  }

  final second = parts[1];
  final hasScript = second.length == 4;
  return Locale.fromSubtags(
    languageCode: parts[0],
    scriptCode: hasScript ? second : null,
    countryCode: hasScript ? (parts.length > 2 ? parts[2] : null) : second,
  );
}

Locale resolveSupportedLocale(
  Locale? locale,
  Iterable<Locale> supportedLocales,
) {
  if (locale != null) {
    for (final supportedLocale in supportedLocales) {
      if (supportedLocale == locale) {
        return supportedLocale;
      }
    }

    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode &&
          supportedLocale.countryCode == locale.countryCode) {
        return supportedLocale;
      }
    }

    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode &&
          supportedLocale.scriptCode == locale.scriptCode &&
          locale.scriptCode != null) {
        return supportedLocale;
      }
    }

    if (locale.languageCode == 'zh') {
      final countryCode = locale.countryCode?.toUpperCase();
      final isTraditional =
          locale.scriptCode == 'Hant' ||
          countryCode == 'TW' ||
          countryCode == 'HK' ||
          countryCode == 'MO';
      for (final supportedLocale in supportedLocales) {
        if (supportedLocale.languageCode != 'zh') continue;
        final supportedCountry = supportedLocale.countryCode?.toUpperCase();
        final isSupportedTraditional =
            supportedLocale.scriptCode == 'Hant' ||
            supportedCountry == 'TW' ||
            supportedCountry == 'HK' ||
            supportedCountry == 'MO';
        if (isTraditional == isSupportedTraditional) {
          return supportedLocale;
        }
      }
    }

    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return supportedLocale;
      }
    }
  }

  return supportedLocales.firstWhere(
    (locale) => locale.languageCode == 'en',
    orElse: () => const Locale('en'),
  );
}
