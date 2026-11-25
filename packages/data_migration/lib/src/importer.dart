import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:data_local/data_local.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

class BetaMigrationOptions {
  const BetaMigrationOptions({
    required this.organizationId,
    required this.branchId,
    this.syntheticOnly = true,
  });

  final String organizationId;
  final String branchId;
  final bool syntheticOnly;
}

class BetaImporter {
  const BetaImporter();

  static const _uuid = Uuid();

  String checksum(String jsonText) =>
      sha256.convert(utf8.encode(jsonText)).toString();

  String uuidFor(String entityType, String betaId) => _uuid.v5(
        Namespace.url.value,
        'caffe-amalfi:beta:$entityType:$betaId',
      );

  MigrationPreview preview(
    String jsonText,
    BetaMigrationOptions options,
  ) {
    final checksum = this.checksum(jsonText);
    final issues = <MigrationIssue>[];
    final duplicates = <MigrationDuplicate>[];
    final idMap = <String, String>{};
    final counts = <String, int>{};
    Map<String, dynamic> document;

    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) {
        issues.add(const MigrationIssue(
          path: r'$',
          code: 'VALIDATION',
          message: 'The root JSON value must be an object',
        ));
        document = const <String, dynamic>{};
      } else {
        document = decoded;
      }
    } catch (error) {
      issues.add(MigrationIssue(
        path: r'$',
        code: 'VALIDATION',
        message: 'Invalid JSON: $error',
      ));
      document = const <String, dynamic>{};
    }

    final betaVersion = document['version'];
    final version = betaVersion is int ? betaVersion : 0;
    if (version < 1) {
      issues.add(const MigrationIssue(
        path: 'version',
        code: 'VALIDATION',
        message: 'Schema version must be a positive integer',
      ));
    }

    final synthetic = document['synthetic'] == true ||
        document['demo'] == true ||
        (document['_metadata'] is Map &&
            (document['_metadata'] as Map)['synthetic'] == true);

    if (options.syntheticOnly && !synthetic) {
      issues.add(const MigrationIssue(
        path: 'synthetic',
        code: 'VALIDATION',
        message:
            'Real data is blocked. Synthetic pilot requires synthetic=true',
      ));
    }

    final collections = <String>[
      'users',
      'categories',
      'products',
      'tables',
      'orders',
      'pagos',
      'facturas',
      'auditLogs',
      'cashSessions',
      'cashMovements',
    ];
    for (final collectionName in collections) {
      final value = document[collectionName];
      if (value == null) {
        counts[collectionName] = 0;
        continue;
      }
      if (value is! List) {
        counts[collectionName] = 0;
        issues.add(MigrationIssue(
          path: collectionName,
          code: 'VALIDATION',
          message: 'Expected an array',
        ));
        continue;
      }

      counts[collectionName] = value.length;
      final seen = <String, int>{};
      for (var index = 0; index < value.length; index++) {
        final item = value[index];
        if (item is! Map) {
          issues.add(MigrationIssue(
            path: '$collectionName[$index]',
            code: 'VALIDATION',
            message: 'Expected an object',
          ));
          continue;
        }
        final betaId = item['id'];
        if (betaId is! String || betaId.trim().isEmpty) {
          issues.add(MigrationIssue(
            path: '$collectionName[$index].id',
            code: 'VALIDATION',
            message: 'Missing or invalid Beta identifier',
          ));
          continue;
        }
        seen.update(betaId, (count) => count + 1, ifAbsent: () => 1);
        idMap['$collectionName:$betaId'] = uuidFor(collectionName, betaId);
      }
      for (final entry in seen.entries) {
        if (entry.value > 1) {
          duplicates.add(MigrationDuplicate(
            entityType: collectionName,
            betaId: entry.key,
            count: entry.value,
          ));
          issues.add(MigrationIssue(
            path: collectionName,
            code: 'DUPLICATE',
            message:
                'Duplicate Beta identifier ${entry.key} (${entry.value} entries)',
          ));
        }
      }
    }

    _validateProductReferences(document, issues);
    _validateFacturas(document, issues);

    return MigrationPreview(
      checksum: checksum,
      betaVersion: version,
      synthetic: synthetic,
      idMap: idMap,
      counts: counts,
      duplicates: duplicates,
      issues: issues,
    );
  }

  void _validateProductReferences(
    Map<String, dynamic> document,
    List<MigrationIssue> issues,
  ) {
    final categories = document['categories'];
    final categoryNames = <String>{};
    if (categories is List) {
      for (final item in categories) {
        if (item is Map && item['name'] is String) {
          categoryNames.add(item['name'] as String);
        }
      }
    }

    final products = document['products'];
    if (products is! List) return;
    for (var index = 0; index < products.length; index++) {
      final item = products[index];
      if (item is! Map) continue;
      final name = item['name'];
      final price = item['price'];
      final category = item['category'];
      if (name is! String || name.trim().isEmpty) {
        issues.add(MigrationIssue(
          path: 'products[$index].name',
          code: 'VALIDATION',
          message: 'Missing product name',
        ));
      }
      if (price is! num || !price.isFinite || price < 0) {
        issues.add(MigrationIssue(
          path: 'products[$index].price',
          code: 'VALIDATION',
          message: 'Invalid product price',
        ));
      }
      if (category is String &&
          categoryNames.isNotEmpty &&
          !categoryNames.contains(category)) {
        issues.add(MigrationIssue(
          path: 'products[$index].category',
          code: 'REFERENCE',
          message: 'Unknown Beta category: $category',
        ));
      }
    }
  }

  void _validateFacturas(
    Map<String, dynamic> document,
    List<MigrationIssue> issues,
  ) {
    final facturas = document['facturas'];
    if (facturas is! List) return;
    for (var index = 0; index < facturas.length; index++) {
      final factura = facturas[index];
      if (factura is! Map) continue;
      final total = factura['total'];
      final payments = factura['payments'];
      if (total is! num || !total.isFinite || total < 0) {
        issues.add(MigrationIssue(
          path: 'facturas[$index].total',
          code: 'VALIDATION',
          message: 'Invalid invoice total',
        ));
      }
      if (payments is! List) {
        issues.add(MigrationIssue(
          path: 'facturas[$index].payments',
          code: 'VALIDATION',
          message: 'Expected a payment array',
        ));
      }
    }
  }

  ReconciliationReport importPreview(
    String jsonText,
    MigrationPreview preview,
    LocalDatabase target,
    BetaMigrationOptions options,
  ) {
    if (!preview.isValid) {
      throw StateError(
        'Cannot import preview because validation issues exist',
      );
    }
    if (preview.checksum != checksum(jsonText)) {
      throw StateError('JSON content changed after preview');
    }

    final document = jsonDecode(jsonText) as Map<String, dynamic>;
    final imported = <String, int>{};
    final skipped = <String, int>{};
    target.database.execute('BEGIN IMMEDIATE');
    try {
      _ensureOrganization(target, options.organizationId);
      _ensureBranch(
        target,
        options.organizationId,
        options.branchId,
      );

      _importCategories(document, target, options, imported, skipped);
      _importProducts(document, target, options, imported, skipped);
      _importUsers(document, target, options, imported, skipped);

      target.database.execute('COMMIT');
    } catch (_) {
      target.database.execute('ROLLBACK');
      rethrow;
    }

    final reconciliation = <String, int>{};
    for (final entity in ['users', 'categories', 'products']) {
      reconciliation[entity] = target.database
          .select(
            'SELECT COUNT(*) AS value FROM ${_tableForEntity(entity)} '
            'WHERE ${_betaOriginWhere(entity)}',
          )
          .first['value'] as int;
    }

    return ReconciliationReport(
      preview: preview,
      imported: imported,
      skippedExisting: skipped,
      reconciliation: reconciliation,
    );
  }

  void _ensureOrganization(LocalDatabase target, String organizationId) {
    final now = DateTime.now().toUtc().toIso8601String();
    target.database.execute(
      'INSERT OR IGNORE INTO organizations'
      '(id, name, tax_id, status, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        organizationId,
        'Imported Organization',
        null,
        'active',
        now,
        now,
      ],
    );
  }

  void _ensureBranch(
    LocalDatabase target,
    String organizationId,
    String branchId,
  ) {
    final now = DateTime.now().toUtc().toIso8601String();
    target.database.execute(
      'INSERT OR IGNORE INTO branches'
      '(id, organization_id, name, code, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        branchId,
        organizationId,
        'Imported Branch',
        'BETA',
        now,
        now,
      ],
    );
  }

  void _importCategories(
    Map<String, dynamic> document,
    LocalDatabase target,
    BetaMigrationOptions options,
    Map<String, int> imported,
    Map<String, int> skipped,
  ) {
    final categories = document['categories'];
    if (categories is! List) return;
    var importedCount = 0;
    var skippedCount = 0;
    final now = DateTime.now().toUtc().toIso8601String();
    for (final item in categories) {
      if (item is! Map) continue;
      final betaId = item['id'];
      final name = item['name'];
      if (betaId is! String || name is! String) continue;
      final id = uuidFor('categories', betaId);
      final existing = target.database.select(
        'SELECT 1 FROM categories WHERE beta_origin_id = ?',
        [betaId],
      );
      if (existing.isNotEmpty) {
        skippedCount++;
        continue;
      }
      target.database.execute(
        'INSERT INTO categories'
        '(id, organization_id, name, sort_order, active, beta_origin_id, '
        'created_at, updated_at, version) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          options.organizationId,
          name,
          item['order'] is int ? item['order'] as int : 0,
          1,
          betaId,
          now,
          now,
          1,
        ],
      );
      importedCount++;
    }
    imported['categories'] = importedCount;
    skipped['categories'] = skippedCount;
  }

  void _importProducts(
    Map<String, dynamic> document,
    LocalDatabase target,
    BetaMigrationOptions options,
    Map<String, int> imported,
    Map<String, int> skipped,
  ) {
    final products = document['products'];
    if (products is! List) return;
    var importedCount = 0;
    var skippedCount = 0;
    final now = DateTime.now().toUtc().toIso8601String();
    for (final item in products) {
      if (item is! Map) continue;
      final betaId = item['id'];
      final name = item['name'];
      final price = item['price'];
      if (betaId is! String || name is! String || price is! num) continue;
      final existing = target.database.select(
        'SELECT 1 FROM products WHERE beta_origin_id = ?',
        [betaId],
      );
      if (existing.isNotEmpty) {
        skippedCount++;
        continue;
      }

      final categoryName = item['category'];
      String? categoryId;
      if (categoryName is String) {
        final rows = target.database.select(
          'SELECT id FROM categories '
          'WHERE organization_id = ? AND name = ?',
          [options.organizationId, categoryName],
        );
        if (rows.isNotEmpty) {
          categoryId = rows.first['id'] as String;
        }
      }

      final productId = uuidFor('products', betaId);
      final minorUnits = _priceToMinorUnits(price);
      target.database.execute(
        'INSERT INTO products'
        '(id, organization_id, category_id, sku, name, description, '
        'base_currency, price_minor, cost_minor, offline_sellable, active, '
        'beta_origin_id, created_at, updated_at, version) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          productId,
          options.organizationId,
          categoryId,
          item['sku'],
          name,
          item['description'] is String ? item['description'] : null,
          'USD',
          minorUnits,
          '0',
          item['offlineSellable'] == true ? 1 : 0,
          item['active'] != false ? 1 : 0,
          betaId,
          now,
          now,
          1,
        ],
      );
      final variantId = uuidFor('product_variants', betaId);
      target.database.execute(
        'INSERT INTO product_variants'
        '(id, organization_id, product_id, sku, name, price_minor, '
        'cost_minor, active, beta_origin_id, created_at, updated_at, version) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          variantId,
          options.organizationId,
          productId,
          item['sku'],
          name,
          minorUnits,
          '0',
          item['active'] != false ? 1 : 0,
          betaId,
          now,
          now,
          1,
        ],
      );
      importedCount++;
    }
    imported['products'] = importedCount;
    skipped['products'] = skippedCount;
  }

  void _importUsers(
    Map<String, dynamic> document,
    LocalDatabase target,
    BetaMigrationOptions options,
    Map<String, int> imported,
    Map<String, int> skipped,
  ) {
    final users = document['users'];
    if (users is! List) return;
    var importedCount = 0;
    var skippedCount = 0;
    final now = DateTime.now().toUtc().toIso8601String();
    for (final item in users) {
      if (item is! Map) continue;
      final betaId = item['id'];
      final name = item['name'];
      if (betaId is! String || name is! String) continue;
      final existing = target.database.select(
        'SELECT 1 FROM profiles WHERE id = ?',
        [uuidFor('users', betaId)],
      );
      if (existing.isNotEmpty) {
        skippedCount++;
        continue;
      }
      target.database.execute(
        'INSERT INTO profiles'
        '(id, organization_id, display_name, status, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [
          uuidFor('users', betaId),
          options.organizationId,
          name,
          item['active'] != false ? 'active' : 'inactive',
          now,
          now,
        ],
      );
      importedCount++;
    }
    imported['users'] = importedCount;
    skipped['users'] = skippedCount;
  }

  String _priceToMinorUnits(num price) {
    final text = price.toString();
    final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d*))?$').firstMatch(text);
    if (match == null) {
      throw FormatException('Invalid price: $text');
    }
    final sign = match.group(1) == '-' ? BigInt.from(-1) : BigInt.one;
    final whole = match.group(2)!;
    final fraction = (match.group(3) ?? '').padRight(2, '0');
    if ((match.group(3) ?? '').length > 2) {
      throw FormatException('Price exceeds two decimal places: $text');
    }
    final minor = BigInt.parse('$whole${fraction.padRight(2, '0')}') * sign;
    return minor.toString();
  }

  String _tableForEntity(String entity) {
    switch (entity) {
      case 'categories':
        return 'categories';
      case 'products':
        return 'products';
      case 'users':
        return 'profiles';
      default:
        return '';
    }
  }

  String _betaOriginWhere(String entity) =>
      entity == 'users' ? '1=1' : 'beta_origin_id IS NOT NULL';
}
