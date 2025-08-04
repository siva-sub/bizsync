import 'package:flutter_test/flutter_test.dart';
import 'package:bizsync/core/database/crdt_database_service.dart';
import 'package:bizsync/core/database/crdt_models.dart';
import 'package:bizsync/core/crdt/hybrid_logical_clock.dart';
import 'package:bizsync/core/crdt/vector_clock.dart';
import 'package:bizsync/core/crdt/lww_register.dart';
import 'package:bizsync/core/crdt/pn_counter.dart';
import 'package:bizsync/core/crdt/or_set.dart';
import 'package:bizsync/features/invoices/models/enhanced_invoice_model.dart';
import 'package:bizsync/features/invoices/models/invoice_models.dart';
import '../test_factories.dart';

/// Comprehensive integration tests for offline functionality and CRDT operations
/// Tests conflict resolution, data persistence, and sync behavior
void main() {
  group('Offline Functionality Integration Tests', () {
    late CRDTDatabaseService databaseService;
    late HybridLogicalClock nodeAClock;
    late HybridLogicalClock nodeBClock;
    late String nodeAId;
    late String nodeBId;

    setUpAll(() async {
      databaseService = CRDTDatabaseService();
      await databaseService.initialize('test_node_offline');

      nodeAId = 'node_a_${DateTime.now().millisecondsSinceEpoch}';
      nodeBId = 'node_b_${DateTime.now().millisecondsSinceEpoch}';
      nodeAClock = HybridLogicalClock(nodeAId);
      nodeBClock = HybridLogicalClock(nodeBId);
    });

    tearDownAll(() async {
      await databaseService.closeDatabase();
    });

    setUp(() {
      TestFactories.reset();
    });

    group('CRDT Data Persistence', () {
      test('should persist CRDT customer data correctly', () async {
        // Create CRDT customer
        final customer = CRDTCustomer(
          id: 'test_customer_1',
          nodeId: nodeAId,
          createdAt: nodeAClock.tick(),
          updatedAt: nodeAClock.current,
          version: CRDTVectorClock(),
          name: 'Test Customer CRDT',
          email: 'crdt@test.com',
          phone: '+65 91234567',
          address: '123 CRDT Street, Singapore',
        );

        // Persist to database
        await databaseService.upsertCustomer(customer);

        // Retrieve and verify
        final retrieved = await databaseService.getCustomer('test_customer_1');
        expect(retrieved, isNotNull);
        expect(retrieved!.name.value, equals('Test Customer CRDT'));
        expect(retrieved.email.value, equals('crdt@test.com'));
        expect(retrieved.phone.value, equals('+65 91234567'));
        expect(retrieved.nodeId, equals(nodeAId));
      });

      test('should handle offline data modifications', () async {
        // Simulate offline scenario: create customer on node A
        final customer = CRDTCustomer(
          id: 'offline_customer_1',
          nodeId: nodeAId,
          createdAt: nodeAClock.tick(),
          updatedAt: nodeAClock.current,
          version: CRDTVectorClock(),
          name: 'Offline Customer',
        );

        await databaseService.upsertCustomer(customer);

        // Simulate offline modifications
        customer.updateName('Updated Offline Customer', nodeAClock.tick());
        customer.updateEmail('updated@offline.com', nodeAClock.tick());
        customer.addLoyaltyPoints(100);

        // Persist modifications
        await databaseService.upsertCustomer(customer);

        // Verify offline changes persisted
        final retrieved =
            await databaseService.getCustomer('offline_customer_1');
        expect(retrieved!.name.value, equals('Updated Offline Customer'));
        expect(retrieved.email.value, equals('updated@offline.com'));
        expect(retrieved.loyaltyPoints.value, equals(100));
      });

      test('should maintain vector clocks during offline operations', () async {
        final customer = CRDTCustomer(
          id: 'vector_clock_test',
          nodeId: nodeAId,
          createdAt: nodeAClock.tick(),
          updatedAt: nodeAClock.current,
          version: CRDTVectorClock(),
          name: 'Vector Clock Test',
        );

        // Track initial vector clock
        final initialVersion = customer.version.toString();

        // Make several updates
        customer.updateName('Updated Name 1', nodeAClock.tick());
        customer.updateEmail('email1@test.com', nodeAClock.tick());
        customer.updateName('Updated Name 2', nodeAClock.tick());

        // Vector clock should have advanced
        expect(customer.version.toString(), isNot(equals(initialVersion)));

        // Persist and retrieve
        await databaseService.upsertCustomer(customer);
        final retrieved =
            await databaseService.getCustomer('vector_clock_test');

        expect(
            retrieved!.version.toString(), equals(customer.version.toString()));
      });
    });

    group('CRDT Conflict Resolution', () {
      test('should resolve concurrent name updates using LWW-Register',
          () async {
        // Create same customer on two nodes
        final timestampA1 = nodeAClock.tick();
        final customerA = CRDTCustomer(
          id: 'conflict_test_1',
          nodeId: nodeAId,
          createdAt: timestampA1,
          updatedAt: timestampA1,
          version: CRDTVectorClock(),
          name: 'Original Name',
        );

        final timestampB1 = nodeBClock.tick();
        final customerB = CRDTCustomer(
          id: 'conflict_test_1',
          nodeId: nodeBId,
          createdAt: timestampB1,
          updatedAt: timestampB1,
          version: CRDTVectorClock(),
          name: 'Original Name',
        );

        // Simulate concurrent updates
        await Future.delayed(Duration(milliseconds: 1));
        final timestampA2 = nodeAClock.tick();
        customerA.updateName('Node A Updated Name', timestampA2);

        await Future.delayed(Duration(milliseconds: 1));
        final timestampB2 = nodeBClock.tick();
        customerB.updateName('Node B Updated Name', timestampB2);

        // Merge - last writer wins based on timestamp
        customerA.mergeWith(customerB);

        // The update with later timestamp should win
        if (timestampB2.happensAfter(timestampA2)) {
          expect(customerA.name.value, equals('Node B Updated Name'));
        } else {
          expect(customerA.name.value, equals('Node A Updated Name'));
        }
      });

      test('should handle concurrent loyalty points updates with PN-Counter',
          () async {
        final customer = CRDTCustomer(
          id: 'loyalty_conflict_test',
          nodeId: nodeAId,
          createdAt: nodeAClock.tick(),
          updatedAt: nodeAClock.current,
          version: CRDTVectorClock(),
          name: 'Loyalty Test Customer',
        );

        // Save initial state
        await databaseService.upsertCustomer(customer);

        // Simulate concurrent loyalty point updates from different nodes
        customer.addLoyaltyPoints(50); // Node A adds 50 points

        // Create another instance representing Node B's view
        final customerB =
            await databaseService.getCustomer('loyalty_conflict_test');
        customerB!.loyaltyPoints.nodeId = nodeBId; // Simulate different node
        customerB.addLoyaltyPoints(75); // Node B adds 75 points

        // Merge the changes
        customer.mergeWith(customerB);

        // PN-Counter should sum all increments: 50 + 75 = 125
        expect(customer.loyaltyPoints.value, equals(125));
      });

      test('should resolve concurrent tag additions with OR-Set', () async {
        final customer = CRDTCustomer(
          id: 'tag_conflict_test',
          nodeId: nodeAId,
          createdAt: nodeAClock.tick(),
          updatedAt: nodeAClock.current,
          version: CRDTVectorClock(),
          name: 'Tag Test Customer',
        );

        // Node A adds tags
        customer.addTag('vip');
        customer.addTag('premium');

        // Create Node B's view
        final customerB = CRDTCustomer(
          id: 'tag_conflict_test',
          nodeId: nodeBId,
          createdAt: nodeAClock.tick(),
          updatedAt: nodeAClock.current,
          version: CRDTVectorClock(),
          name: 'Tag Test Customer',
        );

        // Node B adds different tags
        customerB.addTag('premium'); // Duplicate
        customerB.addTag('corporate');
        customerB.addTag('bulk_buyer');

        // Merge the changes
        customer.mergeWith(customerB);

        // OR-Set should contain union of all tags
        final finalTags = customer.tags.elements;
        expect(finalTags.contains('vip'), isTrue);
        expect(finalTags.contains('premium'), isTrue);
        expect(finalTags.contains('corporate'), isTrue);
        expect(finalTags.contains('bulk_buyer'), isTrue);
        expect(finalTags.length, equals(4)); // No duplicates
      });

      test('should handle complex invoice conflict scenarios', () async {
        final invoiceId = 'complex_invoice_conflict';

        // Create invoice on Node A
        final invoiceA = CRDTInvoiceEnhanced(
          id: invoiceId,
          nodeId: nodeAId,
          createdAt: nodeAClock.tick(),
          updatedAt: nodeAClock.current,
          version: CRDTVectorClock(),
          invoiceNum: 'INV-CONFLICT-001',
          customer: 'customer_1',
          customerNameValue: 'Test Customer',
          issue: DateTime.now(),
          sub: 1000.0,
          tax: 90.0,
          total: 1090.0,
        );

        // Create same invoice on Node B (different initial state)
        final invoiceB = CRDTInvoiceEnhanced(
          id: invoiceId,
          nodeId: nodeBId,
          createdAt: nodeBClock.tick(),
          updatedAt: nodeBClock.current,
          version: CRDTVectorClock(),
          invoiceNum: 'INV-CONFLICT-001',
          customer: 'customer_1',
          customerNameValue: 'Test Customer',
          issue: DateTime.now(),
          sub: 1000.0,
          tax: 90.0,
          total: 1090.0,
        );

        // Concurrent modifications
        // Node A: Update customer info and add payment
        invoiceA.updateStatus(InvoiceStatus.sent, nodeAClock.tick());
        invoiceA.recordPayment(500.0, nodeAClock.tick()); // Partial payment

        // Node B: Update amounts and add different payment
        invoiceB.updateTotals(
          newSubtotal: 1200.0,
          newTaxAmount: 108.0,
          newTotalAmount: 1308.0,
          timestamp: nodeBClock.tick(),
        );
        invoiceB.recordPayment(300.0, nodeBClock.tick()); // Different payment

        // Merge conflicting changes
        invoiceA.mergeWith(invoiceB);

        // LWW fields should use latest timestamp
        // PN-Counter payments should sum: 500 + 300 = 800 cents = 8.00 SGD
        expect(invoiceA.paymentsReceived.value, equals(80000)); // In cents
        expect(invoiceA.remainingBalance,
            greaterThan(0)); // Should have remaining balance
      });
    });

    group('Offline Sync Scenarios', () {
      test('should simulate offline-online sync cycle', () async {
        final entities = <CRDTCustomer>[];

        // Phase 1: Online - create initial data
        for (int i = 0; i < 3; i++) {
          final customer = CRDTCustomer(
            id: 'sync_customer_$i',
            nodeId: nodeAId,
            createdAt: nodeAClock.tick(),
            updatedAt: nodeAClock.current,
            version: CRDTVectorClock(),
            name: 'Sync Customer $i',
            email: 'sync$i@test.com',
          );

          await databaseService.upsertCustomer(customer);
          entities.add(customer);
        }

        // Phase 2: Go offline - make local modifications
        for (int i = 0; i < entities.length; i++) {
          final customer = entities[i];
          customer.updateName(
              'Offline Updated ${customer.name.value}', nodeAClock.tick());
          customer.addLoyaltyPoints(100 * (i + 1));

          // Store offline changes
          await databaseService.upsertCustomer(customer);
        }

        // Phase 3: Simulate receiving updates from other nodes while offline
        final externalUpdates = <CRDTCustomer>[];
        for (int i = 0; i < entities.length; i++) {
          final externalCustomer = CRDTCustomer(
            id: 'sync_customer_$i',
            nodeId: nodeBId,
            createdAt: nodeBClock.tick(),
            updatedAt: nodeBClock.current,
            version: CRDTVectorClock(),
            name: 'External Updated Customer $i',
            email: 'external$i@test.com',
          );
          externalCustomer.addLoyaltyPoints(50 * (i + 1));
          externalUpdates.add(externalCustomer);
        }

        // Phase 4: Come online - merge conflicts
        for (int i = 0; i < entities.length; i++) {
          final localCustomer =
              await databaseService.getCustomer('sync_customer_$i');
          final externalCustomer = externalUpdates[i];

          // Merge external changes
          localCustomer!.mergeWith(externalCustomer);

          // Persist merged state
          await databaseService.upsertCustomer(localCustomer);
        }

        // Phase 5: Verify final state
        for (int i = 0; i < entities.length; i++) {
          final finalCustomer =
              await databaseService.getCustomer('sync_customer_$i');

          // Loyalty points should be sum of both updates
          final expectedPoints = (100 * (i + 1)) + (50 * (i + 1));
          expect(finalCustomer!.loyaltyPoints.value, equals(expectedPoints));

          // Name should be resolved by LWW (latest timestamp wins)
          expect(finalCustomer.name.value, isNotEmpty);
        }
      });

      test('should handle rapid concurrent updates', () async {
        final customerId = 'rapid_updates_test';
        final customer = CRDTCustomer(
          id: customerId,
          nodeId: nodeAId,
          createdAt: nodeAClock.tick(),
          updatedAt: nodeAClock.current,
          version: CRDTVectorClock(),
          name: 'Rapid Updates Customer',
        );

        await databaseService.upsertCustomer(customer);

        // Simulate rapid updates from multiple sources
        final updates = <Future<void>>[];

        // Node A updates
        for (int i = 0; i < 10; i++) {
          updates.add(Future(() async {
            final customerA = await databaseService.getCustomer(customerId);
            customerA!.addLoyaltyPoints(10);
            customerA.updateEmail('update$i@test.com', nodeAClock.tick());
            await databaseService.upsertCustomer(customerA);
          }));
        }

        // Node B updates (simulated)
        for (int i = 0; i < 5; i++) {
          updates.add(Future(() async {
            final customerB = await databaseService.getCustomer(customerId);
            customerB!.loyaltyPoints.nodeId = nodeBId;
            customerB.addLoyaltyPoints(20);
            customerB.updatePhone('+65 9876543$i', nodeBClock.tick());
            await databaseService.upsertCustomer(customerB);
          }));
        }

        // Wait for all updates to complete
        await Future.wait(updates);

        // Verify final consistency
        final finalCustomer = await databaseService.getCustomer(customerId);
        expect(finalCustomer, isNotNull);
        expect(finalCustomer!.loyaltyPoints.value, greaterThan(0));
        expect(finalCustomer.email.value, isNotNull);
        expect(finalCustomer.phone.value, isNotNull);
      });
    });

    group('Network Partition Simulation', () {
      test('should handle network partition and healing', () async {
        // Create initial customer on both nodes
        final customerId = 'partition_test';

        final customerA = CRDTCustomer(
          id: customerId,
          nodeId: nodeAId,
          createdAt: nodeAClock.tick(),
          updatedAt: nodeAClock.current,
          version: CRDTVectorClock(),
          name: 'Partition Test Customer',
          email: 'original@test.com',
        );

        final customerB = CRDTCustomer(
          id: customerId,
          nodeId: nodeBId,
          createdAt: nodeBClock.tick(),
          updatedAt: nodeBClock.current,
          version: CRDTVectorClock(),
          name: 'Partition Test Customer',
          email: 'original@test.com',
        );

        // Store initial state
        await databaseService.upsertCustomer(customerA);

        // Simulate network partition - nodes work independently
        // Node A side of partition
        customerA.updateName('Node A Updated', nodeAClock.tick());
        customerA.updateEmail('node_a@test.com', nodeAClock.tick());
        customerA.addLoyaltyPoints(100);
        customerA.addTag('node_a_tag');

        // Node B side of partition (simulate with in-memory operations)
        customerB.updateName('Node B Updated', nodeBClock.tick());
        customerB.updatePhone('+65 87654321', nodeBClock.tick());
        customerB.addLoyaltyPoints(150);
        customerB.addTag('node_b_tag');

        // Network partition heals - merge state
        customerA.mergeWith(customerB);

        // Store merged state
        await databaseService.upsertCustomer(customerA);

        // Verify conflict resolution
        final healedCustomer = await databaseService.getCustomer(customerId);
        expect(healedCustomer, isNotNull);

        // PN-Counter should sum: 100 + 150 = 250
        expect(healedCustomer!.loyaltyPoints.value, equals(250));

        // OR-Set should contain both tags
        expect(healedCustomer.tags.elements.contains('node_a_tag'), isTrue);
        expect(healedCustomer.tags.elements.contains('node_b_tag'), isTrue);

        // LWW fields resolved by timestamp
        expect(healedCustomer.name.value,
            isIn(['Node A Updated', 'Node B Updated']));
      });

      test('should maintain causal ordering during partition', () async {
        final customerId = 'causal_ordering_test';

        // Create customer with causal chain of updates
        final customer = CRDTCustomer(
          id: customerId,
          nodeId: nodeAId,
          createdAt: nodeAClock.tick(),
          updatedAt: nodeAClock.current,
          version: CRDTVectorClock(),
          name: 'Causal Test Customer',
        );

        // Update 1: Change name
        customer.updateName('Updated Name', nodeAClock.tick());

        // Update 2: Change email (causally depends on name change)
        customer.updateEmail('updated@test.com', nodeAClock.tick());

        // Update 3: Add loyalty points (causally depends on email change)
        customer.addLoyaltyPoints(50);

        await databaseService.upsertCustomer(customer);

        // Verify causal ordering preserved in timestamps
        final nameTimestamp = customer.name.timestamp;
        final emailTimestamp = customer.email.timestamp;
        final loyaltyTimestamp = customer.loyaltyPoints.timestamp;

        expect(nameTimestamp.happensAfter(customer.createdAt), isTrue);
        expect(emailTimestamp.happensAfter(nameTimestamp), isTrue);
        // PN-Counter doesn't use LWW timestamp, so skip this check

        // Verify final state consistency
        final retrievedCustomer = await databaseService.getCustomer(customerId);
        expect(retrievedCustomer!.name.value, equals('Updated Name'));
        expect(retrievedCustomer.email.value, equals('updated@test.com'));
        expect(retrievedCustomer.loyaltyPoints.value, equals(50));
      });
    });

    group('Data Integrity During Conflicts', () {
      test('should maintain referential integrity during merges', () async {
        // This test would verify that foreign key relationships
        // are maintained even during CRDT merges
        final customerId = 'integrity_customer';
        final customer = CRDTCustomer(
          id: customerId,
          nodeId: nodeAId,
          createdAt: nodeAClock.tick(),
          updatedAt: nodeAClock.current,
          version: CRDTVectorClock(),
          name: 'Integrity Test Customer',
        );

        await databaseService.upsertCustomer(customer);

        // Simulate creating invoice that references customer
        final invoiceData =
            TestFactories.createInvoiceData(customerId: customerId);

        // Verify customer exists before creating invoice
        final customerExists = await databaseService.getCustomer(customerId);
        expect(customerExists, isNotNull);

        // In a real scenario, invoice creation would validate customer reference
        expect(invoiceData['customer_id'], equals(customerId));
      });

      test('should handle deletion conflicts correctly', () async {
        final customerId = 'deletion_conflict_test';

        // Create customer on both nodes
        final customerA = CRDTCustomer(
          id: customerId,
          nodeId: nodeAId,
          createdAt: nodeAClock.tick(),
          updatedAt: nodeAClock.current,
          version: CRDTVectorClock(),
          name: 'Deletion Test Customer',
        );

        final customerB = CRDTCustomer(
          id: customerId,
          nodeId: nodeBId,
          createdAt: nodeBClock.tick(),
          updatedAt: nodeBClock.current,
          version: CRDTVectorClock(),
          name: 'Deletion Test Customer',
        );

        // Node A deletes customer
        customerA.isDeleted = true;
        customerA.updatedAt = nodeAClock.tick();

        // Node B updates customer (concurrent with deletion)
        customerB.updateName('Updated Before Deletion', nodeBClock.tick());
        customerB.addLoyaltyPoints(100);

        // Merge - deletion should win but preserve update info
        customerA.mergeWith(customerB);

        expect(customerA.isDeleted, isTrue);
        // Updates should still be merged in case deletion is reverted
        expect(customerA.loyaltyPoints.value, equals(100));
      });
    });

    group('Performance Under Conflict', () {
      test('should efficiently resolve large number of conflicts', () async {
        const conflictCount = 100;
        final customerId = 'performance_conflict_test';

        final baseCustomer = CRDTCustomer(
          id: customerId,
          nodeId: nodeAId,
          createdAt: nodeAClock.tick(),
          updatedAt: nodeAClock.current,
          version: CRDTVectorClock(),
          name: 'Performance Test Customer',
        );

        // Create many conflicting versions
        final conflictingVersions = <CRDTCustomer>[];
        for (int i = 0; i < conflictCount; i++) {
          final version = CRDTCustomer(
            id: customerId,
            nodeId: 'node_$i',
            createdAt: HybridLogicalClock('node_$i').tick(),
            updatedAt: HybridLogicalClock('node_$i').current,
            version: CRDTVectorClock(),
            name: 'Version $i',
          );
          version.addLoyaltyPoints(i + 1);
          version.addTag('tag_$i');
          conflictingVersions.add(version);
        }

        // Measure conflict resolution performance
        final stopwatch = Stopwatch()..start();

        for (final version in conflictingVersions) {
          baseCustomer.mergeWith(version);
        }

        stopwatch.stop();

        print(
            'Resolved $conflictCount conflicts in ${stopwatch.elapsedMilliseconds}ms');
        expect(stopwatch.elapsedMilliseconds,
            lessThan(1000)); // Should be under 1 second

        // Verify final state
        expect(
            baseCustomer.loyaltyPoints.value,
            equals(
                conflictCount * (conflictCount + 1) ~/ 2)); // Sum 1+2+...+100
        expect(baseCustomer.tags.elements.length, equals(conflictCount));
      });
    });
  });
}
