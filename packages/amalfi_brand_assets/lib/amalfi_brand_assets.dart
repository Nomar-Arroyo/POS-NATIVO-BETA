import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum AmalfiIconName {
  dashboard,
  tables,
  posCart,
  orders,
  inventory,
  cash,
  reports,
  audit,
  settings,
  calendar,
  currency,
  receipt,
  coffee,
  users,
  search,
  plus,
  minus,
  wifi,
  sync,
  printer,
  barcode,
  trash,
  edit,
  check,
  close,
  bell,
  moon,
  sun,
}

class AmalfiBrandAssets {
  const AmalfiBrandAssets._();

  static const logo =
      'packages/amalfi_brand_assets/assets/brand/cafe-amalfi-logo.png';
  static const brandSignature =
      'packages/amalfi_brand_assets/assets/brand/cafe-amalfi-deleita-el-paladar.png';
  static const dashboardMotto =
      'packages/amalfi_brand_assets/assets/brand/gestiona-vende-y-disfruta.png';
  static const dashboardBackground =
      'packages/amalfi_brand_assets/assets/backgrounds/fondo-decorativo-dashboard.png';
  static const coffeeBackground =
      'packages/amalfi_brand_assets/assets/backgrounds/fondo-cafe-taza-y-granos.png';
  static const coffeeSceneBackground =
      'packages/amalfi_brand_assets/assets/backgrounds/cafe-amalfi-coffee.png';
  static const appIcon =
      'packages/amalfi_brand_assets/assets/app_icon/cafe-amalfi-app-icon-1024.png';
  static const appIcon192 =
      'packages/amalfi_brand_assets/assets/app_icon/cafe-amalfi-app-icon-192.png';
  static const appIcon256 =
      'packages/amalfi_brand_assets/assets/app_icon/cafe-amalfi-app-icon-256.png';
  static const appIcon512 =
      'packages/amalfi_brand_assets/assets/app_icon/cafe-amalfi-app-icon-512.png';

  static String icon(AmalfiIconName name) =>
      'packages/amalfi_brand_assets/assets/icons/svg/${_fileName(name)}.svg';

  static String _fileName(AmalfiIconName name) => switch (name) {
    AmalfiIconName.dashboard => 'dashboard',
    AmalfiIconName.tables => 'tables',
    AmalfiIconName.posCart => 'pos-cart',
    AmalfiIconName.orders => 'orders',
    AmalfiIconName.inventory => 'inventory',
    AmalfiIconName.cash => 'cash',
    AmalfiIconName.reports => 'reports',
    AmalfiIconName.audit => 'audit',
    AmalfiIconName.settings => 'settings',
    AmalfiIconName.calendar => 'calendar',
    AmalfiIconName.currency => 'currency',
    AmalfiIconName.receipt => 'receipt',
    AmalfiIconName.coffee => 'coffee',
    AmalfiIconName.users => 'users',
    AmalfiIconName.search => 'search',
    AmalfiIconName.plus => 'plus',
    AmalfiIconName.minus => 'minus',
    AmalfiIconName.wifi => 'wifi',
    AmalfiIconName.sync => 'sync',
    AmalfiIconName.printer => 'printer',
    AmalfiIconName.barcode => 'barcode',
    AmalfiIconName.trash => 'trash',
    AmalfiIconName.edit => 'edit',
    AmalfiIconName.check => 'check',
    AmalfiIconName.close => 'close',
    AmalfiIconName.bell => 'bell',
    AmalfiIconName.moon => 'moon',
    AmalfiIconName.sun => 'sun',
  };
}

class AmalfiIcon extends StatelessWidget {
  const AmalfiIcon({
    required this.name,
    this.size = 20,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final AmalfiIconName name;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    AmalfiBrandAssets.icon(name),
    width: size,
    height: size,
    semanticsLabel: semanticLabel,
    colorFilter: ColorFilter.mode(
      color ??
          IconTheme.of(context).color ??
          Theme.of(context).colorScheme.onSurface,
      BlendMode.srcIn,
    ),
  );
}
