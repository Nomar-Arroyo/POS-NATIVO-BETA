import 'package:data_local/data_local.dart';
import 'package:data_migration/data_migration.dart';
import 'package:test/test.dart';

const options = BetaMigrationOptions(
  organizationId: 'organization-pilot',
  branchId: 'branch-pilot',
  syntheticOnly: true,
);

const syntheticJson = '''
{
  "synthetic": true,
  "version": 4,
  "users": [
    {"id":"synthetic-user-1","name":"Synthetic Cashier","role":"cashier","active":true}
  ],
  "categories": [
    {"id":"synthetic-category-1","name":"Synthetic Drinks","order":1}
  ],
  "products": [
    {
      "id":"synthetic-product-1",
      "name":"Synthetic Coffee",
      "description":"Pilot item",
      "category":"Synthetic Drinks",
      "price":3.50,
      "active":true,
      "offlineSellable":true,
      "sku":"SYN-001"
    }
  ],
  "tables": [],
  "orders": [],
  "pagos": [],
  "facturas": [],
  "auditLogs": [],
  "cashSessions": [],
  "cashMovements": []
}
''';

void main() {
  group('Beta importer preview', () {
    test('accepts an explicitly synthetic export', () {
      const importer = BetaImporter();
      final preview = importer.preview(syntheticJson, options);

      expect(preview.isValid, isTrue);
      expect(preview.synthetic, isTrue);
      expect(preview.checksum, isNotEmpty);
      expect(preview.counts['categories'], 1);
      expect(preview.counts['products'], 1);
      expect(preview.idMap['categories:synthetic-category-1'], isNotEmpty);
    });

    test('rejects real data in synthetic-only mode', () {
      const importer = BetaImporter();
      const realJson = '''
      {"synthetic":false,"version":4,"categories":[],"products":[]}
      ''';
      final preview = importer.preview(realJson, options);

      expect(preview.isValid, isFalse);
      expect(
        preview.issues.where((issue) => issue.code == 'VALIDATION'),
        isNotEmpty,
      );
    });

    test('detects duplicate Beta identifiers', () {
      const importer = BetaImporter();
      const duplicateJson = '''
      {
        "synthetic": true,
        "version": 4,
        "categories":[
          {"id":"cat-1","name":"One","order":1},
          {"id":"cat-1","name":"Duplicate","order":2}
        ],
        "products":[]
      }
      ''';
      final preview = importer.preview(duplicateJson, options);

      expect(preview.duplicates, hasLength(1));
      expect(preview.isValid, isFalse);
      expect(preview.duplicates.first.betaId, 'cat-1');
    });

    test('reports malformed product references', () {
      const importer = BetaImporter();
      const missingCategoryJson = '''
      {
        "synthetic": true,
        "version": 4,
        "categories":[
          {"id":"cat-1","name":"Known","order":1}
        ],
        "products":[
          {"id":"prod-1","name":"Bad","category":"Unknown","price":1.00}
        ]
      }
      ''';
      final preview = importer.preview(missingCategoryJson, options);

      expect(preview.isValid, isFalse);
      expect(
        preview.issues.where((issue) => issue.code == 'REFERENCE'),
        isNotEmpty,
      );
    });
  });

  group('transactional import and reconciliation', () {
    test('imports catalog and profile in one transaction', () async {
      const importer = BetaImporter();
      final preview = importer.preview(syntheticJson, options);
      final database = await LocalDatabase.openInMemory();
      addTearDown(database.close);

      final report = importer.importPreview(
        syntheticJson,
        preview,
        database,
        options,
      );

      expect(report.imported['categories'], 1);
      expect(report.imported['products'], 1);
      expect(report.imported['users'], 1);
      expect(report.reconciliation['categories'], 1);
      expect(report.reconciliation['products'], 1);
      expect(database.tableCount('sync_outbox'), 0);

      final products = database.database.select(
        'SELECT beta_origin_id, price_minor FROM products',
      );
      expect(products.first['beta_origin_id'], 'synthetic-product-1');
      expect(products.first['price_minor'], '350');

      final second = importer.importPreview(
        syntheticJson,
        preview,
        database,
        options,
      );
      expect(second.imported['categories'], 0);
      expect(second.skippedExisting['categories'], 1);
      expect(second.imported['products'], 0);
      expect(second.skippedExisting['products'], 1);
    });

    test('rejects import after JSON changes', () async {
      const importer = BetaImporter();
      final preview = importer.preview(syntheticJson, options);
      final database = await LocalDatabase.openInMemory();
      addTearDown(database.close);
      final changed = syntheticJson.replaceFirst('3.50', '3.51');

      expect(
        () => importer.importPreview(
          changed,
          preview,
          database,
          options,
        ),
        throwsStateError,
      );
      expect(database.tableCount('sales'), 0);
      expect(database.tableCount('products'), 0);
    });
  });
}
