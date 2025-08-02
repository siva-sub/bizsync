import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/crdt_database_service.dart';
import '../../core/storage/database_service.dart';
import '../../core/database/conflict_resolver.dart';
import '../../core/database/database_seeding_service.dart';
import '../../core/services/notification_service.dart';
import '../../features/invoices/repositories/invoice_repository.dart';
import '../../data/repositories/customer_repository.dart';

// Core service providers
final crdtDatabaseServiceProvider = Provider<CRDTDatabaseService>((ref) {
  return CRDTDatabaseService();
});

final databaseServiceProvider = Provider<CRDTDatabaseService>((ref) {
  return ref.read(crdtDatabaseServiceProvider);
});

final basicDatabaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final conflictResolverProvider = Provider<ConflictResolver>((ref) {
  return ConflictResolver();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// Repository providers
final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  final database = ref.read(crdtDatabaseServiceProvider);
  final conflictResolver = ref.read(conflictResolverProvider);
  return InvoiceRepository(database, conflictResolver, database.nodeId);
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository();
});

final databaseSeedingServiceProvider = Provider<DatabaseSeedingService>((ref) {
  final database = ref.read(crdtDatabaseServiceProvider);
  return DatabaseSeedingService(database);
});

// App state providers
final isAppInitializedProvider = StateProvider<bool>((ref) => false);

final themeProvider = StateProvider<bool>((ref) => false); // false = light, true = dark

// Initialize app services
final appInitializationProvider = FutureProvider<void>((ref) async {
  final crdtDatabase = ref.read(crdtDatabaseServiceProvider);
  final basicDatabase = ref.read(basicDatabaseServiceProvider);
  final notifications = ref.read(notificationServiceProvider);
  final seeding = ref.read(databaseSeedingServiceProvider);
  
  // Initialize core services
  await crdtDatabase.initialize(); // Initialize CRDT database
  await basicDatabase.database; // Initialize basic database
  await notifications.initialize();
  
  // Seed database with initial data if needed
  await seeding.seedDatabase();
  
  // Mark app as initialized
  ref.read(isAppInitializedProvider.notifier).state = true;
});

// Navigation state
final currentTabProvider = StateProvider<int>((ref) => 0);

// Error handling
final errorProvider = StateProvider<String?>((ref) => null);