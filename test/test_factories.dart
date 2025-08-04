import 'package:bizsync/data/models/customer.dart';
import 'package:bizsync/features/inventory/models/product.dart';
import 'package:bizsync/features/invoices/models/invoice_models.dart';
import 'package:bizsync/core/crdt/hybrid_logical_clock.dart';
import 'package:bizsync/core/utils/uuid_generator.dart';

/// Test data factories for creating consistent test data
class TestFactories {
  static final _nodeId = 'test_node_${DateTime.now().millisecondsSinceEpoch}';
  static final _hlc = HybridLogicalClock(_nodeId);

  /// Create a test customer with optional overrides
  static Customer createCustomer({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    bool? gstRegistered,
    String? gstRegistrationNumber,
    String? countryCode,
    String? billingAddress,
    String? shippingAddress,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return Customer(
      id: id ?? UuidGenerator.generateId(),
      name: name ?? 'Test Customer ${DateTime.now().millisecondsSinceEpoch}',
      email: email ?? 'test@example.com',
      phone: phone ?? '+65 91234567',
      address: address ?? '123 Test Street, Singapore 123456',
      gstRegistered: gstRegistered ?? false,
      gstRegistrationNumber: gstRegistrationNumber,
      countryCode: countryCode ?? 'SG',
      billingAddress: billingAddress,
      shippingAddress: shippingAddress,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  /// Create a GST-registered Singapore customer
  static Customer createSingaporeGstCustomer({
    String? name,
    String? gstNumber,
  }) {
    return createCustomer(
      name: name ?? 'GST Registered Customer',
      gstRegistered: true,
      gstRegistrationNumber: gstNumber ?? '200012345M',
      countryCode: 'SG',
    );
  }

  /// Create an export customer (non-Singapore)
  static Customer createExportCustomer({
    String? name,
    String? countryCode,
  }) {
    return createCustomer(
      name: name ?? 'Export Customer',
      countryCode: countryCode ?? 'US',
      gstRegistered: false,
    );
  }

  /// Create a test product with optional overrides
  static Product createProduct({
    String? id,
    String? name,
    String? description,
    double? price,
    double? cost,
    int? stockQuantity,
    int? minStockLevel,
    String? categoryId,
    String? category,
    String? barcode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return Product(
      id: id ?? UuidGenerator.generateId(),
      name: name ?? 'Test Product ${DateTime.now().millisecondsSinceEpoch}',
      description: description ?? 'A test product for integration testing',
      price: price ?? 100.0,
      cost: cost ?? 60.0,
      stockQuantity: stockQuantity ?? 50,
      minStockLevel: minStockLevel ?? 10,
      categoryId: categoryId,
      category: category ?? 'Test Category',
      barcode: barcode,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  /// Create a low stock product
  static Product createLowStockProduct({
    String? name,
    int? stockQuantity,
    int? minStockLevel,
  }) {
    return createProduct(
      name: name ?? 'Low Stock Product',
      stockQuantity: stockQuantity ?? 5,
      minStockLevel: minStockLevel ?? 10,
    );
  }

  /// Create an out of stock product
  static Product createOutOfStockProduct({
    String? name,
  }) {
    return createProduct(
      name: name ?? 'Out of Stock Product',
      stockQuantity: 0,
      minStockLevel: 10,
    );
  }

  /// Create test invoice line items
  static List<Map<String, dynamic>> createInvoiceLineItems({
    int? count,
    List<Product>? products,
  }) {
    final itemCount = count ?? 3;
    final items = <Map<String, dynamic>>[];

    for (int i = 0; i < itemCount; i++) {
      final product = products != null && i < products.length
          ? products[i]
          : createProduct(name: 'Invoice Item ${i + 1}');

      items.add({
        'id': UuidGenerator.generateId(),
        'product_id': product.id,
        'product_name': product.name,
        'description': product.description ?? '',
        'quantity': 2.0,
        'unit_price': product.price,
        'discount_amount': 0.0,
        'tax_rate': 0.09, // 9% GST
        'line_total': product.price * 2.0,
      });
    }

    return items;
  }

  /// Create a test invoice with optional overrides
  static Map<String, dynamic> createInvoiceData({
    String? id,
    String? invoiceNumber,
    String? customerId,
    Customer? customer,
    DateTime? issueDate,
    DateTime? dueDate,
    PaymentTerm? paymentTerms,
    InvoiceStatus? status,
    List<Map<String, dynamic>>? lineItems,
    double? discountAmount,
    String? notes,
    String? currency,
  }) {
    final now = DateTime.now();
    final testCustomer = customer ?? createCustomer();
    final items = lineItems ?? createInvoiceLineItems();

    // Calculate totals
    final subtotal = items.fold<double>(
      0.0,
      (sum, item) => sum + (item['line_total'] as double),
    );
    final discount = discountAmount ?? 0.0;
    final netAmount = subtotal - discount;
    final taxAmount = netAmount * 0.09; // 9% GST
    final totalAmount = netAmount + taxAmount;

    return {
      'id': id ?? UuidGenerator.generateId(),
      'invoice_number':
          invoiceNumber ?? 'INV-${DateTime.now().millisecondsSinceEpoch}',
      'customer_id': customerId ?? testCustomer.id,
      'customer_name': testCustomer.name,
      'customer_email': testCustomer.email,
      'customer_gst_registered': testCustomer.gstRegistered,
      'customer_country_code': testCustomer.countryCode,
      'issue_date': issueDate ?? now,
      'due_date': dueDate ?? now.add(Duration(days: 30)),
      'payment_terms': paymentTerms ?? PaymentTerm.net30,
      'status': status ?? InvoiceStatus.draft,
      'line_items': items,
      'subtotal': subtotal,
      'discount_amount': discount,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'currency': currency ?? 'SGD',
      'notes': notes,
      'created_at': now,
      'updated_at': now,
    };
  }

  /// Create a simple draft invoice
  static Map<String, dynamic> createDraftInvoice({
    Customer? customer,
    List<Product>? products,
  }) {
    return createInvoiceData(
      customer: customer,
      status: InvoiceStatus.draft,
      lineItems:
          products != null ? createInvoiceLineItems(products: products) : null,
    );
  }

  /// Create an invoice for export customer (should be zero-rated)
  static Map<String, dynamic> createExportInvoice({
    Customer? exportCustomer,
  }) {
    final customer = exportCustomer ?? createExportCustomer();
    return createInvoiceData(
      customer: customer,
      status: InvoiceStatus.draft,
    );
  }

  /// Create an invoice with high discount
  static Map<String, dynamic> createDiscountedInvoice({
    Customer? customer,
    double? discountPercentage,
  }) {
    final items = createInvoiceLineItems();
    final subtotal = items.fold<double>(
      0.0,
      (sum, item) => sum + (item['line_total'] as double),
    );
    final discountAmount =
        subtotal * (discountPercentage ?? 0.15); // 15% discount

    return createInvoiceData(
      customer: customer,
      lineItems: items,
      discountAmount: discountAmount,
    );
  }

  /// Create test payment data
  static Map<String, dynamic> createPaymentData({
    String? invoiceId,
    double? amount,
    DateTime? paymentDate,
    String? paymentMethod,
    String? reference,
  }) {
    return {
      'id': UuidGenerator.generateId(),
      'invoice_id': invoiceId ?? UuidGenerator.generateId(),
      'amount': amount ?? 100.0,
      'payment_date': paymentDate ?? DateTime.now(),
      'payment_method': paymentMethod ?? 'PayNow',
      'reference':
          reference ?? 'TEST-PAY-${DateTime.now().millisecondsSinceEpoch}',
      'currency': 'SGD',
      'status': 'completed',
    };
  }

  /// Create test PayNow QR data
  static Map<String, dynamic> createPayNowQRData({
    double? amount,
    String? merchantName,
    String? merchantUEN,
    String? reference,
  }) {
    return {
      'amount': amount ?? 100.0,
      'currency': 'SGD',
      'merchant_name': merchantName ?? 'Test Merchant',
      'merchant_uen': merchantUEN ?? '202012345A',
      'reference':
          reference ?? 'TEST-REF-${DateTime.now().millisecondsSinceEpoch}',
      'description': 'Test payment description',
    };
  }

  /// Create test tax scenario data
  static Map<String, dynamic> createTaxScenario({
    required String scenarioName,
    required double amount,
    required bool isGstRegistered,
    required bool customerIsGstRegistered,
    String? customerCountry,
    bool? isExport,
    DateTime? calculationDate,
  }) {
    return {
      'scenario_name': scenarioName,
      'amount': amount,
      'is_gst_registered': isGstRegistered,
      'customer_is_gst_registered': customerIsGstRegistered,
      'customer_country': customerCountry ?? 'SG',
      'is_export': isExport ?? false,
      'calculation_date': calculationDate ?? DateTime.now(),
    };
  }

  /// Create multiple tax scenarios for comprehensive testing
  static List<Map<String, dynamic>> createTaxScenarios() {
    final scenarios = <Map<String, dynamic>>[];

    // Standard Singapore GST scenarios
    scenarios.add(createTaxScenario(
      scenarioName: 'Standard Singapore B2B GST',
      amount: 1000.0,
      isGstRegistered: true,
      customerIsGstRegistered: true,
    ));

    scenarios.add(createTaxScenario(
      scenarioName: 'Standard Singapore B2C GST',
      amount: 1000.0,
      isGstRegistered: true,
      customerIsGstRegistered: false,
    ));

    // Export scenarios (zero-rated)
    scenarios.add(createTaxScenario(
      scenarioName: 'Export to US (Zero-rated)',
      amount: 1000.0,
      isGstRegistered: true,
      customerIsGstRegistered: false,
      customerCountry: 'US',
      isExport: true,
    ));

    // Company not GST registered
    scenarios.add(createTaxScenario(
      scenarioName: 'Non-GST registered company',
      amount: 1000.0,
      isGstRegistered: false,
      customerIsGstRegistered: false,
    ));

    // Historical GST rates
    scenarios.add(createTaxScenario(
      scenarioName: 'Historical 8% GST rate (2022)',
      amount: 1000.0,
      isGstRegistered: true,
      customerIsGstRegistered: true,
      calculationDate: DateTime(2022, 6, 1),
    ));

    scenarios.add(createTaxScenario(
      scenarioName: 'Historical 7% GST rate (2020)',
      amount: 1000.0,
      isGstRegistered: true,
      customerIsGstRegistered: true,
      calculationDate: DateTime(2020, 6, 1),
    ));

    return scenarios;
  }

  /// Create CRDT conflict scenarios for testing
  static Map<String, dynamic> createCRDTConflictScenario({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localChanges,
    required Map<String, dynamic> remoteChanges,
  }) {
    return {
      'entity_type': entityType,
      'entity_id': entityId,
      'local_changes': localChanges,
      'remote_changes': remoteChanges,
      'conflict_timestamp': DateTime.now(),
    };
  }

  /// Reset static state (useful for test isolation)
  static void reset() {
    // Reset any static state if needed
  }
}

/// Test validation helpers
class TestValidators {
  /// Validate invoice calculation accuracy
  static bool validateInvoiceCalculations(Map<String, dynamic> invoice) {
    final lineItems = invoice['line_items'] as List<Map<String, dynamic>>;
    final subtotal = invoice['subtotal'] as double;
    final discount = invoice['discount_amount'] as double? ?? 0.0;
    final taxAmount = invoice['tax_amount'] as double;
    final totalAmount = invoice['total_amount'] as double;

    // Calculate expected subtotal
    final expectedSubtotal = lineItems.fold<double>(
      0.0,
      (sum, item) => sum + (item['line_total'] as double),
    );

    // Validate subtotal
    if ((expectedSubtotal - subtotal).abs() > 0.01) {
      print('Subtotal mismatch: expected $expectedSubtotal, got $subtotal');
      return false;
    }

    // Calculate expected tax (9% GST on net amount)
    final netAmount = subtotal - discount;
    final expectedTax = netAmount * 0.09;

    // Validate tax amount (allow 1 cent tolerance for rounding)
    if ((expectedTax - taxAmount).abs() > 0.01) {
      print('Tax amount mismatch: expected $expectedTax, got $taxAmount');
      return false;
    }

    // Validate total amount
    final expectedTotal = netAmount + taxAmount;
    if ((expectedTotal - totalAmount).abs() > 0.01) {
      print('Total amount mismatch: expected $expectedTotal, got $totalAmount');
      return false;
    }

    return true;
  }

  /// Validate GST registration number format
  static bool validateGstNumber(String? gstNumber) {
    if (gstNumber == null || gstNumber.isEmpty) return false;
    return RegExp(r'^\d{9}[A-Z]$').hasMatch(gstNumber);
  }

  /// Validate PayNow QR code format
  static bool validatePayNowQR(String qrString) {
    // Basic validation - should start with proper payload format
    return qrString.isNotEmpty &&
        qrString.startsWith('00') &&
        qrString.contains('SG.PAYNOW');
  }

  /// Validate email format
  static bool validateEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }

  /// Validate Singapore phone number format
  static bool validateSingaporePhone(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    // Remove spaces and special characters
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    // Should be +659XXXXXXX or 9XXXXXXX
    return RegExp(r'^(\+65)?[89]\d{7}$').hasMatch(cleanPhone);
  }
}
