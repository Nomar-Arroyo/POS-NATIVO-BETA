import 'package:amalfi_pos_desktop/services/local_print_service.dart';
import 'package:data_local/data_local.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'prints disabled station orders sequentially without losing failures',
    () async {
      final database = await LocalDatabase.openInMemory();
      addTearDown(database.close);
      database.createLocalWorkspace(
        const LocalWorkspaceInput(
          organizationId: 'output-org',
          organizationName: 'Output Test',
          branchId: 'output-branch',
          branchName: 'Main',
          terminalId: 'output-terminal',
          terminalName: 'Terminal',
          profileId: 'output-admin',
          profileName: 'Administrator',
          profilePin: '1234',
          warehouseId: 'output-warehouse',
          warehouseName: 'Main',
          cashRegisterId: 'output-cash',
          cashRegisterName: 'Register',
        ),
      );
      database.setStationDisplayEnabled('KITCHEN', false);
      database.setStationDisplayEnabled('BAR', false);

      final orders = [
        _order('K-1', 'KITCHEN'),
        _order('B-1', 'BAR'),
        _order('K-2', 'KITCHEN'),
      ];
      final attempted = <String>[];
      final result = await printOrdersWithoutStationDisplays(
        database: database,
        orders: orders,
        printOrder: (order) async {
          attempted.add(order.orderNumber);
          if (order.station == 'KITCHEN' && order.orderNumber == 'K-1') {
            return false;
          }
          if (order.station == 'BAR') {
            throw StateError('printer unavailable');
          }
          return true;
        },
      );

      expect(attempted, ['K-1', 'B-1', 'K-2']);
      expect(result.cancelledCount, 1);
      expect(result.failures, hasLength(1));
      expect(result.failures.single, contains('BAR'));
      expect(result.hasIssues, isTrue);
    },
  );
}

LocalProductionOrder _order(String number, String station) =>
    LocalProductionOrder(
      id: number,
      orderNumber: number,
      tableName: 'Mesa 1',
      station: station,
      status: 'PENDING',
      createdAt: '2026-01-01T10:00:00Z',
      items: const [],
    );
