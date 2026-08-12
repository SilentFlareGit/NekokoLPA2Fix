import 'package:flutter/material.dart';

class ProfilePackage {
  final String name;
  final double totalBytes;
  final double usedBytes;
  final String? expiry;

  ProfilePackage({
    required this.name,
    required this.totalBytes,
    required this.usedBytes,
    this.expiry,
  });

  double get remainingBytes => totalBytes - usedBytes;
  double get progress => totalBytes > 0 ? remainingBytes / totalBytes : 0.0;
}

/// Represents the data to be displayed in the bottom section of a profile card.
class ProfileCardBottomData {
  final Color themeColor;
  final String? phoneNumber;
  final String? lineExpiry;
  final String? balance;
  final List<ProfilePackage> packages;

  ProfileCardBottomData({
    required this.themeColor,
    this.phoneNumber,
    this.lineExpiry,
    this.balance,
    this.packages = const [],
  });

  /// Limit the number of packages to display
  ProfileCardBottomData trimPackages(int max) {
    if (packages.length <= max) return this;
    return ProfileCardBottomData(
      themeColor: themeColor,
      phoneNumber: phoneNumber,
      lineExpiry: lineExpiry,
      balance: balance,
      packages: packages.sublist(0, max),
    );
  }

  /// Check if this data is effectively empty
  bool get isEmpty =>
      phoneNumber == null &&
      lineExpiry == null &&
      balance == null &&
      packages.isEmpty;
}
