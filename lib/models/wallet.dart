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

  const Wallet({
    required this.id,
    required this.name,
    required this.type,
    required this.startingBalance,
    this.currency = 'PHP',
    required this.colorValue,
    this.archived = false,
    required this.logoAsset,
  });

  Color get color => Color(colorValue);

  Wallet copyWith({
    String? id,
    String? name,
    WalletType? type,
    double? startingBalance,
    String? currency,
    int? colorValue,
    bool? archived,
    String? logoAsset,
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
    colorValue: 0xFF1A1A1A,
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
    type: WalletType.ewallet,
    colorValue: 0xFFFF6B35,
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
    colorValue: 0xFFFFC107,
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