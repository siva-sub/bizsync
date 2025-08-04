/// Null safety validation tests
library null_safety_validation_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:bizsync/core/debugging/null_safety_validator.dart';
import 'package:bizsync/data/models/customer.dart';
import 'package:bizsync/features/inventory/models/product.dart';
import 'package:bizsync/features/invoices/models/invoice_models.dart';
import '../../test_config.dart';
import '../../test_factories.dart';

void main() {
  group('Null Safety Validation Tests', () {
    late NullSafetyValidator validator;
    
    setUpAll(() async {
      await TestConfig.initialize();
    });
    
    setUp(() async {
      await TestConfig.reset();
      validator = NullSafetyValidator();
    });
    
    group('Customer Model Validation', () {
      test('should accept valid customer with all required fields', () {
        final customer = TestFactories.createCustomer();
        
        final result = validator.validateCustomer(customer);
        
        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });
      
      test('should reject customer with null id', () {
        final customer = TestFactories.createCustomer();
        final invalidCustomer = Customer(
          id: null as dynamic, // Force null
          name: customer.name,
          email: customer.email,
          phone: customer.phone,
          address: customer.address,
          gstRegistered: customer.gstRegistered,
          gstRegistrationNumber: customer.gstRegistrationNumber,
          countryCode: customer.countryCode,
          billingAddress: customer.billingAddress,
          shippingAddress: customer.shippingAddress,
          createdAt: customer.createdAt,
          updatedAt: customer.updatedAt,
        );
        
        expect(() => validator.validateCustomer(invalidCustomer), throwsA(isA<ArgumentError>()));
      });
      
      test('should reject customer with null name', () {
        final customer = TestFactories.createCustomer();
        
        expect(() => Customer(
          id: customer.id,
          name: null as dynamic, // Force null
          email: customer.email,
          phone: customer.phone,
          address: customer.address,
          gstRegistered: customer.gstRegistered,
          gstRegistrationNumber: customer.gstRegistrationNumber,
          countryCode: customer.countryCode,
          billingAddress: customer.billingAddress,
          shippingAddress: customer.shippingAddress,
          createdAt: customer.createdAt,
          updatedAt: customer.updatedAt,
        ), throwsA(isA<TypeError>()));
      });
      
      test('should accept customer with null optional fields', () {
        final customer = Customer(
          id: 'test-id',
          name: 'Test Customer',
          email: null, // Optional
          phone: null, // Optional
          address: null, // Optional
          gstRegistered: false,
          gstRegistrationNumber: null, // Optional
          countryCode: 'SG',
          billingAddress: null, // Optional
          shippingAddress: null, // Optional
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final result = validator.validateCustomer(customer);
        
        expect(result.isValid, isTrue);
      });
      
      test('should validate GST registration number when provided', () {
        final customer = TestFactories.createSingaporeGstCustomer(
          gstNumber: '200012345M' // Valid format
        );
        
        final result = validator.validateCustomer(customer);
        
        expect(result.isValid, isTrue);
        
        // Test invalid GST number format
        final invalidCustomer = TestFactories.createSingaporeGstCustomer(
          gstNumber: 'INVALID' // Invalid format
        );
        
        final invalidResult = validator.validateCustomer(invalidCustomer);
        
        expect(invalidResult.isValid, isFalse);
        expect(invalidResult.errors, contains('Invalid GST registration number format'));
      });
      
      test('should validate email format when provided', () {
        final customer = TestFactories.createCustomer(email: 'valid@email.com');
        
        final result = validator.validateCustomer(customer);
        
        expect(result.isValid, isTrue);
        
        // Test invalid email format
        final invalidCustomer = TestFactories.createCustomer(email: 'invalid-email');
        
        final invalidResult = validator.validateCustomer(invalidCustomer);
        
        expect(invalidResult.isValid, isFalse);
        expect(invalidResult.errors, contains('Invalid email format'));
      });
    });
    
    group('Product Model Validation', () {
      test('should accept valid product with all required fields', () {
        final product = TestFactories.createProduct();
        
        final result = validator.validateProduct(product);
        
        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });
      
      test('should reject product with null required fields', () {
        expect(() => Product(
          id: null as dynamic, // Force null
          name: 'Test Product',
          description: 'Description',
          price: 100.0,
          cost: 60.0,
          stockQuantity: 10,
          minStockLevel: 5,
          categoryId: 'cat-1',
          category: 'Test Category',
          barcode: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ), throwsA(isA<TypeError>()));
        
        expect(() => Product(
          id: 'test-id',
          name: null as dynamic, // Force null
          description: 'Description',
          price: 100.0,
          cost: 60.0,
          stockQuantity: 10,
          minStockLevel: 5,
          categoryId: 'cat-1',
          category: 'Test Category',
          barcode: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ), throwsA(isA<TypeError>()));
        
        expect(() => Product(
          id: 'test-id',
          name: 'Test Product',
          description: 'Description',
          price: null as dynamic, // Force null
          cost: 60.0,
          stockQuantity: 10,
          minStockLevel: 5,
          categoryId: 'cat-1',
          category: 'Test Category',
          barcode: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ), throwsA(isA<TypeError>()));
      });
      
      test('should validate price is positive', () {
        final product = TestFactories.createProduct(price: -10.0);
        
        final result = validator.validateProduct(product);
        
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Price must be positive'));
      });
      
      test('should validate stock quantities are non-negative', () {
        final product = TestFactories.createProduct(stockQuantity: -5);
        
        final result = validator.validateProduct(product);
        
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Stock quantity cannot be negative'));
        
        final product2 = TestFactories.createProduct(minStockLevel: -1);
        
        final result2 = validator.validateProduct(product2);
        
        expect(result2.isValid, isFalse);
        expect(result2.errors, contains('Minimum stock level cannot be negative'));
      });
      
      test('should accept product with null optional fields', () {
        final product = Product(
          id: 'test-id',
          name: 'Test Product',
          description: null, // Optional
          price: 100.0,
          cost: null, // Optional
          stockQuantity: 10,
          minStockLevel: 5,
          categoryId: null, // Optional
          category: null, // Optional
          barcode: null, // Optional
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final result = validator.validateProduct(product);
        
        expect(result.isValid, isTrue);
      });
    });
    
    group('Invoice Model Validation', () {
      test('should accept valid invoice with all required fields', () {
        final invoiceData = TestFactories.createInvoiceData();
        
        final result = validator.validateInvoiceData(invoiceData);
        
        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });
      
      test('should reject invoice with null required fields', () {
        final invoiceData = TestFactories.createInvoiceData();
        
        // Test null id
        final invalidData1 = Map<String, dynamic>.from(invoiceData);
        invalidData1['id'] = null;
        
        final result1 = validator.validateInvoiceData(invalidData1);
        expect(result1.isValid, isFalse);
        expect(result1.errors, contains('Invoice ID cannot be null'));
        
        // Test null invoice number
        final invalidData2 = Map<String, dynamic>.from(invoiceData);
        invalidData2['invoice_number'] = null;
        
        final result2 = validator.validateInvoiceData(invalidData2);
        expect(result2.isValid, isFalse);
        expect(result2.errors, contains('Invoice number cannot be null'));
        
        // Test null customer_id
        final invalidData3 = Map<String, dynamic>.from(invoiceData);
        invalidData3['customer_id'] = null;
        
        final result3 = validator.validateInvoiceData(invalidData3);
        expect(result3.isValid, isFalse);
        expect(result3.errors, contains('Customer ID cannot be null'));
      });
      
      test('should validate monetary amounts are non-negative', () {
        final invoiceData = TestFactories.createInvoiceData();
        
        // Test negative subtotal
        final invalidData1 = Map<String, dynamic>.from(invoiceData);
        invalidData1['subtotal'] = -100.0;
        
        final result1 = validator.validateInvoiceData(invalidData1);
        expect(result1.isValid, isFalse);
        expect(result1.errors, contains('Subtotal cannot be negative'));
        
        // Test negative tax amount
        final invalidData2 = Map<String, dynamic>.from(invoiceData);
        invalidData2['tax_amount'] = -10.0;
        
        final result2 = validator.validateInvoiceData(invalidData2);
        expect(result2.isValid, isFalse);
        expect(result2.errors, contains('Tax amount cannot be negative'));
        
        // Test negative total amount
        final invalidData3 = Map<String, dynamic>.from(invoiceData);
        invalidData3['total_amount'] = -110.0;
        
        final result3 = validator.validateInvoiceData(invalidData3);
        expect(result3.isValid, isFalse);
        expect(result3.errors, contains('Total amount cannot be negative'));
      });
      
      test('should validate line items are not null or empty', () {
        final invoiceData = TestFactories.createInvoiceData();
        
        // Test null line items
        final invalidData1 = Map<String, dynamic>.from(invoiceData);
        invalidData1['line_items'] = null;
        
        final result1 = validator.validateInvoiceData(invalidData1);
        expect(result1.isValid, isFalse);
        expect(result1.errors, contains('Line items cannot be null'));
        
        // Test empty line items
        final invalidData2 = Map<String, dynamic>.from(invoiceData);
        invalidData2['line_items'] = <Map<String, dynamic>>[];
        
        final result2 = validator.validateInvoiceData(invalidData2);
        expect(result2.isValid, isFalse);
        expect(result2.errors, contains('Invoice must have at least one line item'));
      });
      
      test('should validate line item fields', () {
        final invoiceData = TestFactories.createInvoiceData();
        final lineItems = List<Map<String, dynamic>>.from(invoiceData['line_items']);
        
        // Test line item with null required field
        lineItems[0]['product_name'] = null;
        final invalidData = Map<String, dynamic>.from(invoiceData);
        invalidData['line_items'] = lineItems;
        
        final result = validator.validateInvoiceData(invalidData);
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Line item product name cannot be null'));
      });
      
      test('should validate calculation consistency', () {
        final invoiceData = TestFactories.createInvoiceData();
        
        // Manipulate total to be inconsistent
        final invalidData = Map<String, dynamic>.from(invoiceData);
        invalidData['total_amount'] = 999.99; // Inconsistent with subtotal + tax
        
        final result = validator.validateInvoiceData(invalidData);
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Invoice calculations are inconsistent'));
      });
    });
    
    group('Generic Null Safety Tests', () {
      test('should detect null values in required fields', () {
        final data = {
          'required_field': null,
          'optional_field': 'value',
        };
        
        final requiredFields = ['required_field'];
        
        final result = validator.validateRequiredFields(data, requiredFields);
        
        expect(result.isValid, isFalse);
        expect(result.errors, contains('required_field cannot be null'));
      });
      
      test('should accept null values in optional fields', () {
        final data = {
          'required_field': 'value',
          'optional_field': null,
        };
        
        final requiredFields = ['required_field'];
        
        final result = validator.validateRequiredFields(data, requiredFields);
        
        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });
      
      test('should detect missing required fields', () {
        final data = {
          'optional_field': 'value',
        };
        
        final requiredFields = ['required_field'];
        
        final result = validator.validateRequiredFields(data, requiredFields);
        
        expect(result.isValid, isFalse);
        expect(result.errors, contains('required_field is missing'));
      });
      
      test('should validate nested object fields', () {
        final data = {
          'customer': {
            'id': 'customer-1',
            'name': null, // Null in nested object
          },
          'amount': 100.0,
        };
        
        final result = validator.validateNestedFields(data);
        
        expect(result.isValid, isFalse);
        expect(result.errors, contains('customer.name cannot be null'));
      });
      
      test('should handle array fields validation', () {
        final data = {
          'items': [
            {'name': 'Item 1', 'price': 10.0},
            {'name': null, 'price': 20.0}, // Null in array item
            {'name': 'Item 3', 'price': 30.0},
          ],
        };
        
        final result = validator.validateArrayFields(data, 'items', ['name', 'price']);
        
        expect(result.isValid, isFalse);
        expect(result.errors, contains('items[1].name cannot be null'));
      });
    });
    
    group('Runtime Null Safety Monitoring', () {
      test('should monitor null safety violations during runtime', () {
        final monitor = NullSafetyMonitor();
        final violations = <String>[];
        
        monitor.onViolation = (violation) {
          violations.add(violation);
        };
        
        // Simulate null safety violation
        monitor.checkValue('test_field', null, isRequired: true);
        
        expect(violations, contains('Null safety violation: test_field is required but was null'));
      });
      
      test('should provide stack trace for null safety violations', () {
        final monitor = NullSafetyMonitor();
        String? capturedStackTrace;
        
        monitor.onViolationWithStackTrace = (violation, stackTrace) {
          capturedStackTrace = stackTrace;
        };
        
        // Simulate null safety violation
        monitor.checkValueWithStackTrace('test_field', null, isRequired: true);
        
        expect(capturedStackTrace, isNotNull);
        expect(capturedStackTrace, contains('null_safety_validation_test.dart'));
      });
      
      test('should collect null safety statistics', () {
        final monitor = NullSafetyMonitor();
        
        // Simulate multiple checks
        monitor.checkValue('field1', 'value1', isRequired: true); // OK
        monitor.checkValue('field2', null, isRequired: false);    // OK
        monitor.checkValue('field3', null, isRequired: true);     // Violation
        monitor.checkValue('field4', 'value4', isRequired: true); // OK
        monitor.checkValue('field5', null, isRequired: true);     // Violation
        
        final stats = monitor.getStatistics();
        
        expect(stats['total_checks'], equals(5));
        expect(stats['violations'], equals(2));
        expect(stats['violation_rate'], equals(0.4));
      });
    });
  });
}

/// Validation result model for null safety tests
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  
  ValidationResult({required this.isValid, required this.errors});
}

/// Mock Null Safety Validator for testing
class NullSafetyValidator {
  /// Validate customer model
  ValidationResult validateCustomer(Customer customer) {
    final errors = <String>[];
    
    if (customer.gstRegistered && 
        customer.gstRegistrationNumber != null &&
        !TestValidators.validateGstNumber(customer.gstRegistrationNumber)) {
      errors.add('Invalid GST registration number format');
    }
    
    if (customer.email != null && !TestValidators.validateEmail(customer.email)) {
      errors.add('Invalid email format');
    }
    
    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
  
  /// Validate product model
  ValidationResult validateProduct(Product product) {
    final errors = <String>[];
    
    if (product.price <= 0) {
      errors.add('Price must be positive');
    }
    
    if (product.stockQuantity < 0) {
      errors.add('Stock quantity cannot be negative');
    }
    
    if (product.minStockLevel < 0) {
      errors.add('Minimum stock level cannot be negative');
    }
    
    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
  
  /// Validate invoice data
  ValidationResult validateInvoiceData(Map<String, dynamic> data) {
    final errors = <String>[];
    
    // Check required fields
    final requiredFields = ['id', 'invoice_number', 'customer_id', 'customer_name'];
    for (final field in requiredFields) {
      if (data[field] == null) {
        errors.add('${field.replaceAll('_', ' ').toUpperCase()} cannot be null');
      }
    }
    
    // Check monetary amounts
    final monetaryFields = ['subtotal', 'tax_amount', 'total_amount'];
    for (final field in monetaryFields) {
      final value = data[field];
      if (value != null && value < 0) {
        errors.add('${field.replaceAll('_', ' ').toUpperCase()} cannot be negative');
      }
    }
    
    // Check line items
    final lineItems = data['line_items'];
    if (lineItems == null) {
      errors.add('Line items cannot be null');
    } else if (lineItems is List && lineItems.isEmpty) {
      errors.add('Invoice must have at least one line item');
    } else if (lineItems is List) {
      for (int i = 0; i < lineItems.length; i++) {
        final item = lineItems[i] as Map<String, dynamic>;
        if (item['product_name'] == null) {
          errors.add('Line item product name cannot be null');
        }
      }
    }
    
    // Validate calculation consistency
    if (data['subtotal'] != null && data['tax_amount'] != null && data['total_amount'] != null) {
      final subtotal = data['subtotal'] as double;
      final discount = data['discount_amount'] as double? ?? 0.0;
      final taxAmount = data['tax_amount'] as double;
      final totalAmount = data['total_amount'] as double;
      
      final expectedTotal = (subtotal - discount) + taxAmount;
      if ((expectedTotal - totalAmount).abs() > 0.01) {
        errors.add('Invoice calculations are inconsistent');
      }
    }
    
    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
  
  /// Validate required fields in generic data
  ValidationResult validateRequiredFields(Map<String, dynamic> data, List<String> requiredFields) {
    final errors = <String>[];
    
    for (final field in requiredFields) {
      if (!data.containsKey(field)) {
        errors.add('$field is missing');
      } else if (data[field] == null) {
        errors.add('$field cannot be null');
      }
    }
    
    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
  
  /// Validate nested object fields
  ValidationResult validateNestedFields(Map<String, dynamic> data) {
    final errors = <String>[];
    
    data.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        value.forEach((nestedKey, nestedValue) {
          if (nestedValue == null && nestedKey == 'name') {
            errors.add('$key.$nestedKey cannot be null');
          }
        });
      }
    });
    
    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
  
  /// Validate array fields
  ValidationResult validateArrayFields(Map<String, dynamic> data, String arrayField, List<String> requiredItemFields) {
    final errors = <String>[];
    
    final array = data[arrayField];
    if (array is List) {
      for (int i = 0; i < array.length; i++) {
        final item = array[i];
        if (item is Map<String, dynamic>) {
          for (final field in requiredItemFields) {
            if (item[field] == null) {
              errors.add('$arrayField[$i].$field cannot be null');
            }
          }
        }
      }
    }
    
    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
}

/// Null safety runtime monitor for testing
class NullSafetyMonitor {
  int _totalChecks = 0;
  int _violations = 0;
  Function(String)? onViolation;
  Function(String, String)? onViolationWithStackTrace;
  
  void checkValue(String fieldName, dynamic value, {required bool isRequired}) {
    _totalChecks++;
    
    if (isRequired && value == null) {
      _violations++;
      onViolation?.call('Null safety violation: $fieldName is required but was null');
    }
  }
  
  void checkValueWithStackTrace(String fieldName, dynamic value, {required bool isRequired}) {
    _totalChecks++;
    
    if (isRequired && value == null) {
      _violations++;
      final stackTrace = StackTrace.current.toString();
      onViolationWithStackTrace?.call(
        'Null safety violation: $fieldName is required but was null',
        stackTrace,
      );
    }
  }
  
  Map<String, dynamic> getStatistics() {
    return {
      'total_checks': _totalChecks,
      'violations': _violations,
      'violation_rate': _totalChecks > 0 ? _violations / _totalChecks : 0.0,
    };
  }
}