import 'package:flutter/material.dart';

enum WalletType { bank, ewallet, credit, cash }

extension WalletTypeX on WalletType {
  String get label {
    switch (this) {
      case WalletType.bank:
        return 'Bank';
      case WalletType.ewallet:
        return 'E-Wallet';
      case WalletType.credit:
        return 'Credit Card';
      case WalletType.cash:
        return 'Cash';
    }
  }

  String get logoAsset {
    switch (this) {
      case WalletType.bank:
        return 'assets/logos/bdo.svg';
      case WalletType.ewallet:
        return 'assets/logos/maya.svg';
      case WalletType.credit:
        return 'assets/logos/credit_card.svg';
      case WalletType.cash:
        return 'assets/logos/cash.svg';
    }
  }

  IconData get icon {
    switch (this) {
      case WalletType.bank:
        return Icons.account_balance_rounded;
      case WalletType.ewallet:
        return Icons.account_balance_wallet_rounded;
      case WalletType.credit:
        return Icons.credit_card_rounded;
      case WalletType.cash:
        return Icons.payments_rounded;
    }
  }
}

class Wallet {
  final String id;
  final String name;
  final WalletType type;
  final double startingBalance;
  final String currency;
  final int colorValue;
  final bool archived;
  final String logoAsset;
  final String? accountNumber;
  final String? accountName;
  final String? accountLabel;
  final String? qrImagePath;

  const Wallet({
    required this.id,
    required this.name,
    required this.type,
    required this.startingBalance,
    this.currency = 'PHP',
    required this.colorValue,
    this.archived = false,
    required this.logoAsset,
    this.accountNumber,
    this.accountName,
    this.accountLabel,
    this.qrImagePath,
  });

  Color get color => Color(colorValue);

  bool get hasAccountDetails =>
      (accountNumber != null && accountNumber!.trim().isNotEmpty) ||
      (accountName != null && accountName!.trim().isNotEmpty);

  bool get hasQrImage =>
      (type == WalletType.bank || type == WalletType.ewallet) &&
      qrImagePath != null &&
      qrImagePath!.trim().isNotEmpty;

  bool get canCopyDetails =>
      (type == WalletType.bank || type == WalletType.ewallet) &&
      hasAccountDetails;
  String? get maskedAccountNumber {
    final raw = accountNumber?.trim();
    if (raw == null || raw.isEmpty) return null;
    final compact = raw.replaceAll(RegExp(r'[\s\-]'), '');
    if (compact.length <= 4) {
      return '••••  ••••  $compact';
    }
    final last4 = compact.substring(compact.length - 4);
    if (type == WalletType.ewallet &&
        (compact.startsWith('09') || compact.startsWith('+639')) &&
        compact.length >= 10) {
      final prefix = compact.substring(0, 4);
      return '$prefix ••• $last4';
    }
    return '••••  ••••  $last4';
  }

  String get copyableDetails {
    if (type == WalletType.credit) {
      return [
        name,
        if (maskedAccountNumber != null) maskedAccountNumber!,
      ].join(' · ');
    }
    final parts = <String>[
      name,
      if (accountLabel != null && accountLabel!.trim().isNotEmpty)
        '(${accountLabel!.trim()})',
      if (accountNumber != null && accountNumber!.trim().isNotEmpty)
        accountNumber!.trim(),
      if (accountName != null && accountName!.trim().isNotEmpty)
        accountName!.trim(),
    ];
    return parts.join(' · ');
  }
  static const Object _unset = Object();

  Wallet copyWith({
    String? id,
    String? name,
    WalletType? type,
    double? startingBalance,
    String? currency,
    int? colorValue,
    bool? archived,
    String? logoAsset,
    Object? accountNumber = _unset,
    Object? accountName = _unset,
    Object? accountLabel = _unset,
    Object? qrImagePath = _unset,
    bool clearAccountDetails = false,
  }) {
    return Wallet(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      startingBalance: startingBalance ?? this.startingBalance,
      currency: currency ?? this.currency,
      colorValue: colorValue ?? this.colorValue,
      archived: archived ?? this.archived,
      logoAsset: logoAsset ?? this.logoAsset,
      accountNumber: clearAccountDetails
          ? null
          : (identical(accountNumber, _unset)
              ? this.accountNumber
              : accountNumber as String?),
      accountName: clearAccountDetails
          ? null
          : (identical(accountName, _unset)
              ? this.accountName
              : accountName as String?),
      accountLabel: clearAccountDetails
          ? null
          : (identical(accountLabel, _unset)
              ? this.accountLabel
              : accountLabel as String?),
      qrImagePath: clearAccountDetails
          ? null
          : (identical(qrImagePath, _unset)
              ? this.qrImagePath
              : qrImagePath as String?),
    );
  }
  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'starting_balance': startingBalance,
        'currency': currency,
        'color_value': colorValue,
        'archived': archived ? 1 : 0,
        'logo_asset': logoAsset,
        'account_number': accountNumber,
        'account_name': accountName,
        'account_label': accountLabel,
        'qr_image_path': qrImagePath,
      };

  factory Wallet.fromMap(Map<String, Object?> m) => Wallet(
        id: m['id'] as String,
        name: m['name'] as String,
        type: WalletType.values.byName(m['type'] as String),
        startingBalance: (m['starting_balance'] as num).toDouble(),
        currency: m['currency'] as String? ?? 'PHP',
        colorValue: m['color_value'] as int,
        archived: (m['archived'] as int? ?? 0) == 1,
        logoAsset: m['logo_asset'] as String,
        accountNumber: m['account_number'] as String?,
        accountName: m['account_name'] as String?,
        accountLabel: m['account_label'] as String?,
        qrImagePath: m['qr_image_path'] as String?,
      );
}

class WalletPreset {
  final String name;
  final WalletType type;
  final int colorValue;
  final String logoAsset;
  final String? notificationPackage;

  const WalletPreset({
    required this.name,
    required this.type,
    required this.colorValue,
    required this.logoAsset,
    this.notificationPackage,
  });

  Wallet toWallet(String id) => Wallet(
        id: id,
        name: name,
        type: type,
        startingBalance: 0,
        colorValue: colorValue,
        logoAsset: logoAsset,
      );
}

const List<WalletPreset> kWalletPresets = [
  WalletPreset(
    name: 'BDO',
    type: WalletType.bank,
    colorValue: 0xFF0033A0,
    logoAsset: 'assets/logos/bdo.svg',
    notificationPackage: 'com.bdo.bdopersonal',
  ),
  WalletPreset(
    name: 'BPI',
    type: WalletType.bank,
    colorValue: 0xFFE31837,
    logoAsset: 'assets/logos/bpi.svg',
    notificationPackage: 'com.bpi.mobileapp',
  ),
  WalletPreset(
    name: 'Maya',
    type: WalletType.ewallet,
    colorValue: 0xFF00B865,
    logoAsset: 'assets/logos/maya.svg',
    notificationPackage: 'com.paymaya',
  ),
  WalletPreset(
    name: 'GCash',
    type: WalletType.ewallet,
    colorValue: 0xFF0073E6,
    logoAsset: 'assets/logos/gcash.svg',
    notificationPackage: 'com.globe.gcash.android',
  ),
  WalletPreset(
    name: 'GoTyme',
    type: WalletType.bank,
    colorValue: 0xFF00B8D4,
    logoAsset: 'assets/logos/gotyme.svg',
  ),
  WalletPreset(
    name: 'Metrobank',
    type: WalletType.bank,
    colorValue: 0xFF003D7A,
    logoAsset: 'assets/logos/metrobank.svg',
  ),
  WalletPreset(
    name: 'UnionBank',
    type: WalletType.bank,
    colorValue: 0xFFFF8000,
    logoAsset: 'assets/logos/unionbank.svg',
  ),
  WalletPreset(
    name: 'Maribank',
    type: WalletType.bank,
    colorValue: 0xFFEA7A1F,
    logoAsset: 'assets/logos/maribank.svg',
  ),
  WalletPreset(
    name: 'Security Bank',
    type: WalletType.bank,
    colorValue: 0xFF0E2A47,
    logoAsset: 'assets/logos/security_bank.svg',
  ),
  WalletPreset(
    name: 'Landbank',
    type: WalletType.bank,
    colorValue: 0xFF0B6E4F,
    logoAsset: 'assets/logos/landbank.svg',
  ),
  WalletPreset(
    name: 'RCBC',
    type: WalletType.bank,
    colorValue: 0xFF005DAA,
    logoAsset: 'assets/logos/rcbc.svg',
  ),
  WalletPreset(
    name: 'ShopeePay',
    type: WalletType.ewallet,
    colorValue: 0xFFEE4D2D,
    logoAsset: 'assets/logos/shopee.svg',
  ),
  WalletPreset(
    name: 'Cash on Hand',
    type: WalletType.cash,
    colorValue: 0xFF2E7D32,
    logoAsset: 'assets/logos/cash.svg',
  ),
];
