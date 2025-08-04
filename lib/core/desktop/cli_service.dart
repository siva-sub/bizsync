import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

/// CLI Command Result
class CLIResult {
  final bool success;
  final String? output;
  final String? error;
  final int exitCode;
  final Map<String, dynamic>? data;

  CLIResult({
    required this.success,
    this.output,
    this.error,
    this.exitCode = 0,
    this.data,
  });
}

/// CLI Command Interface
abstract class CLICommand {
  String get name;
  String get description;
  ArgParser get argParser;
  Future<CLIResult> execute(ArgResults args);
}

/// Invoice CLI Command
class InvoiceCommand implements CLICommand {
  @override
  String get name => 'invoice';

  @override
  String get description => 'Manage invoices from command line';

  @override
  ArgParser get argParser {
    final parser = ArgParser();
    parser.addOption('action',
        abbr: 'a', help: 'Action to perform (create, list, show, export)');
    parser.addOption('number', abbr: 'n', help: 'Invoice number');
    parser.addOption('customer', abbr: 'c', help: 'Customer ID or name');
    parser.addOption('amount', help: 'Invoice amount');
    parser.addOption('format',
        abbr: 'f', help: 'Export format (pdf, csv, json)', defaultsTo: 'pdf');
    parser.addOption('output', abbr: 'o', help: 'Output file path');
    parser.addFlag('help', abbr: 'h', help: 'Show help for invoice command');
    return parser;
  }

  @override
  Future<CLIResult> execute(ArgResults args) async {
    if (args['help'] as bool) {
      return CLIResult(
        success: true,
        output: _getHelpText(),
      );
    }

    final action = args['action'] as String?;
    if (action == null) {
      return CLIResult(
        success: false,
        error: 'Action is required. Use --action or -a',
        exitCode: 1,
      );
    }

    switch (action) {
      case 'create':
        return await _createInvoice(args);
      case 'list':
        return await _listInvoices(args);
      case 'show':
        return await _showInvoice(args);
      case 'export':
        return await _exportInvoice(args);
      default:
        return CLIResult(
          success: false,
          error: 'Unknown action: $action',
          exitCode: 1,
        );
    }
  }

  Future<CLIResult> _createInvoice(ArgResults args) async {
    final customer = args['customer'] as String?;
    final amountStr = args['amount'] as String?;

    if (customer == null || amountStr == null) {
      return CLIResult(
        success: false,
        error: 'Customer and amount are required for invoice creation',
        exitCode: 1,
      );
    }

    final amount = double.tryParse(amountStr);
    if (amount == null) {
      return CLIResult(
        success: false,
        error: 'Invalid amount format',
        exitCode: 1,
      );
    }

    // Create invoice logic would go here
    final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}';

    return CLIResult(
      success: true,
      output: 'Invoice created successfully: $invoiceNumber',
      data: {
        'invoiceNumber': invoiceNumber,
        'customer': customer,
        'amount': amount,
      },
    );
  }

  Future<CLIResult> _listInvoices(ArgResults args) async {
    // List invoices logic would go here
    final invoices = [
      {
        'number': 'INV-001',
        'customer': 'John Doe',
        'amount': 1000.0,
        'status': 'paid'
      },
      {
        'number': 'INV-002',
        'customer': 'Jane Smith',
        'amount': 750.0,
        'status': 'pending'
      },
    ];

    final output = StringBuffer();
    output.writeln('Invoice List:');
    output.writeln('Number\t\tCustomer\t\tAmount\t\tStatus');
    output.writeln('─' * 60);

    for (final invoice in invoices) {
      output.writeln(
          '${invoice['number']}\t\t${invoice['customer']}\t\t\$${invoice['amount']}\t\t${invoice['status']}');
    }

    return CLIResult(
      success: true,
      output: output.toString(),
      data: {'invoices': invoices},
    );
  }

  Future<CLIResult> _showInvoice(ArgResults args) async {
    final number = args['number'] as String?;
    if (number == null) {
      return CLIResult(
        success: false,
        error: 'Invoice number is required',
        exitCode: 1,
      );
    }

    // Show invoice logic would go here
    final invoice = {
      'number': number,
      'customer': 'John Doe',
      'amount': 1000.0,
      'status': 'paid',
      'date': '2024-01-15',
      'items': [
        {'description': 'Product A', 'quantity': 2, 'price': 300.0},
        {'description': 'Product B', 'quantity': 1, 'price': 400.0},
      ],
    };

    final output = StringBuffer();
    output.writeln('Invoice Details:');
    output.writeln('Number: ${invoice['number']}');
    output.writeln('Customer: ${invoice['customer']}');
    output.writeln('Date: ${invoice['date']}');
    output.writeln('Status: ${invoice['status']}');
    output.writeln('Amount: \$${invoice['amount']}');
    output.writeln('\nLine Items:');
    for (final item in invoice['items'] as List) {
      output.writeln(
          '  ${item['description']} - Qty: ${item['quantity']} - Price: \$${item['price']}');
    }

    return CLIResult(
      success: true,
      output: output.toString(),
      data: invoice,
    );
  }

  Future<CLIResult> _exportInvoice(ArgResults args) async {
    final number = args['number'] as String?;
    final format = args['format'] as String?;
    final outputPath = args['output'] as String?;

    if (number == null) {
      return CLIResult(
        success: false,
        error: 'Invoice number is required for export',
        exitCode: 1,
      );
    }

    final fileName = outputPath ??
        'invoice_${number}_${DateTime.now().millisecondsSinceEpoch}.$format';

    // Export logic would go here
    return CLIResult(
      success: true,
      output: 'Invoice exported to: $fileName',
      data: {'exportPath': fileName, 'format': format},
    );
  }

  String _getHelpText() {
    return '''
Invoice Command Usage:
  bizsync invoice --action <action> [options]

Actions:
  create    Create a new invoice
  list      List all invoices
  show      Show invoice details
  export    Export invoice to file

Options:
  -a, --action      Action to perform
  -n, --number      Invoice number
  -c, --customer    Customer ID or name
  --amount          Invoice amount
  -f, --format      Export format (pdf, csv, json)
  -o, --output      Output file path
  -h, --help        Show this help message

Examples:
  bizsync invoice --action create --customer "John Doe" --amount 1000
  bizsync invoice --action list
  bizsync invoice --action show --number INV-001
  bizsync invoice --action export --number INV-001 --format pdf
''';
  }
}

/// Customer CLI Command
class CustomerCommand implements CLICommand {
  @override
  String get name => 'customer';

  @override
  String get description => 'Manage customers from command line';

  @override
  ArgParser get argParser {
    final parser = ArgParser();
    parser.addOption('action',
        abbr: 'a',
        help: 'Action to perform (create, list, show, update, delete)');
    parser.addOption('id', help: 'Customer ID');
    parser.addOption('name', abbr: 'n', help: 'Customer name');
    parser.addOption('email', abbr: 'e', help: 'Customer email');
    parser.addOption('phone', abbr: 'p', help: 'Customer phone');
    parser.addOption('company', abbr: 'c', help: 'Customer company');
    parser.addFlag('help', abbr: 'h', help: 'Show help for customer command');
    return parser;
  }

  @override
  Future<CLIResult> execute(ArgResults args) async {
    if (args['help'] as bool) {
      return CLIResult(
        success: true,
        output: _getHelpText(),
      );
    }

    final action = args['action'] as String?;
    if (action == null) {
      return CLIResult(
        success: false,
        error: 'Action is required. Use --action or -a',
        exitCode: 1,
      );
    }

    switch (action) {
      case 'create':
        return await _createCustomer(args);
      case 'list':
        return await _listCustomers(args);
      case 'show':
        return await _showCustomer(args);
      default:
        return CLIResult(
          success: false,
          error: 'Unknown action: $action',
          exitCode: 1,
        );
    }
  }

  Future<CLIResult> _createCustomer(ArgResults args) async {
    final name = args['name'] as String?;
    final email = args['email'] as String?;

    if (name == null || email == null) {
      return CLIResult(
        success: false,
        error: 'Name and email are required for customer creation',
        exitCode: 1,
      );
    }

    final customerId = 'CUST-${DateTime.now().millisecondsSinceEpoch}';

    return CLIResult(
      success: true,
      output: 'Customer created successfully: $customerId',
      data: {
        'customerId': customerId,
        'name': name,
        'email': email,
        'phone': args['phone'],
        'company': args['company'],
      },
    );
  }

  Future<CLIResult> _listCustomers(ArgResults args) async {
    final customers = [
      {
        'id': 'CUST-001',
        'name': 'John Doe',
        'email': 'john@email.com',
        'company': 'ABC Corp'
      },
      {
        'id': 'CUST-002',
        'name': 'Jane Smith',
        'email': 'jane@email.com',
        'company': 'XYZ Ltd'
      },
    ];

    final output = StringBuffer();
    output.writeln('Customer List:');
    output.writeln('ID\t\tName\t\tEmail\t\t\tCompany');
    output.writeln('─' * 70);

    for (final customer in customers) {
      output.writeln(
          '${customer['id']}\t\t${customer['name']}\t\t${customer['email']}\t\t${customer['company']}');
    }

    return CLIResult(
      success: true,
      output: output.toString(),
      data: {'customers': customers},
    );
  }

  Future<CLIResult> _showCustomer(ArgResults args) async {
    final id = args['id'] as String?;
    if (id == null) {
      return CLIResult(
        success: false,
        error: 'Customer ID is required',
        exitCode: 1,
      );
    }

    final customer = {
      'id': id,
      'name': 'John Doe',
      'email': 'john@email.com',
      'phone': '+1-555-0123',
      'company': 'ABC Corp',
      'address': '123 Main St, City, State 12345',
    };

    final output = StringBuffer();
    output.writeln('Customer Details:');
    output.writeln('ID: ${customer['id']}');
    output.writeln('Name: ${customer['name']}');
    output.writeln('Email: ${customer['email']}');
    output.writeln('Phone: ${customer['phone']}');
    output.writeln('Company: ${customer['company']}');
    output.writeln('Address: ${customer['address']}');

    return CLIResult(
      success: true,
      output: output.toString(),
      data: customer,
    );
  }

  String _getHelpText() {
    return '''
Customer Command Usage:
  bizsync customer --action <action> [options]

Actions:
  create    Create a new customer
  list      List all customers
  show      Show customer details

Options:
  -a, --action      Action to perform
  --id              Customer ID
  -n, --name        Customer name
  -e, --email       Customer email
  -p, --phone       Customer phone
  -c, --company     Customer company
  -h, --help        Show this help message

Examples:
  bizsync customer --action create --name "John Doe" --email john@email.com
  bizsync customer --action list
  bizsync customer --action show --id CUST-001
''';
  }
}

/// CLI Service for Linux Desktop
///
/// Provides command line interface functionality:
/// - CLI arguments for quick actions
/// - Batch operations support
/// - Headless mode for automation
/// - Scriptable business operations
class CLIService {
  static final CLIService _instance = CLIService._internal();
  factory CLIService() => _instance;
  CLIService._internal();

  bool _isInitialized = false;
  final Map<String, CLICommand> _commands = {};
  late ArgParser _mainParser;

  /// Initialize the CLI service
  Future<void> initialize() async {
    try {
      // Register built-in commands
      _registerCommand(InvoiceCommand());
      _registerCommand(CustomerCommand());

      // Set up main argument parser
      _setupMainParser();

      _isInitialized = true;
      debugPrint('✅ CLI service initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize CLI service: $e');
    }
  }

  /// Set up main argument parser
  void _setupMainParser() {
    _mainParser = ArgParser();
    _mainParser.addFlag('help', abbr: 'h', help: 'Show help message');
    _mainParser.addFlag('version', abbr: 'v', help: 'Show version information');
    _mainParser.addFlag('headless', help: 'Run in headless mode (no GUI)');
    _mainParser.addOption('config', abbr: 'c', help: 'Configuration file path');
    _mainParser.addOption('log-level',
        help: 'Set log level (debug, info, warn, error)', defaultsTo: 'info');
    _mainParser.addFlag('quiet', abbr: 'q', help: 'Suppress output');
    _mainParser.addFlag('verbose', help: 'Verbose output');
  }

  /// Register a CLI command
  void _registerCommand(CLICommand command) {
    _commands[command.name] = command;
    debugPrint('Registered CLI command: ${command.name}');
  }

  /// Process command line arguments
  Future<CLIResult> processArguments(List<String> arguments) async {
    if (!_isInitialized) {
      return CLIResult(
        success: false,
        error: 'CLI service not initialized',
        exitCode: 1,
      );
    }

    try {
      if (arguments.isEmpty) {
        return CLIResult(
          success: true,
          output: _getMainHelpText(),
        );
      }

      // Check for main flags first
      final mainArgs = _mainParser.parse(arguments);

      if (mainArgs['help'] as bool) {
        return CLIResult(
          success: true,
          output: _getMainHelpText(),
        );
      }

      if (mainArgs['version'] as bool) {
        return CLIResult(
          success: true,
          output: 'BizSync CLI v1.0.0',
        );
      }

      // Extract command name
      final commandName = arguments.first;
      final command = _commands[commandName];

      if (command == null) {
        return CLIResult(
          success: false,
          error:
              'Unknown command: $commandName\nUse --help to see available commands',
          exitCode: 1,
        );
      }

      // Parse command-specific arguments
      final commandArgs = arguments.skip(1).toList();
      final parsedArgs = command.argParser.parse(commandArgs);

      // Execute command
      return await command.execute(parsedArgs);
    } catch (e) {
      return CLIResult(
        success: false,
        error: 'Error processing arguments: $e',
        exitCode: 1,
      );
    }
  }

  /// Execute batch operations from file
  Future<List<CLIResult>> executeBatchFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return [
          CLIResult(
            success: false,
            error: 'Batch file not found: $filePath',
            exitCode: 1,
          )
        ];
      }

      final lines = await file.readAsLines();
      final results = <CLIResult>[];

      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty || trimmedLine.startsWith('#')) {
          continue; // Skip empty lines and comments
        }

        final arguments = _parseCommandLine(trimmedLine);
        final result = await processArguments(arguments);
        results.add(result);

        // Stop on first error if not in continue-on-error mode
        if (!result.success) {
          break;
        }
      }

      return results;
    } catch (e) {
      return [
        CLIResult(
          success: false,
          error: 'Error executing batch file: $e',
          exitCode: 1,
        )
      ];
    }
  }

  /// Execute JSON batch operations
  Future<List<CLIResult>> executeBatchJson(String jsonPath) async {
    try {
      final file = File(jsonPath);
      if (!await file.exists()) {
        return [
          CLIResult(
            success: false,
            error: 'JSON batch file not found: $jsonPath',
            exitCode: 1,
          )
        ];
      }

      final jsonContent = await file.readAsString();
      final batchData = jsonDecode(jsonContent);

      if (batchData is! Map<String, dynamic> ||
          !batchData.containsKey('commands')) {
        return [
          CLIResult(
            success: false,
            error: 'Invalid JSON batch format',
            exitCode: 1,
          )
        ];
      }

      final commands = batchData['commands'] as List;
      final results = <CLIResult>[];

      for (final commandData in commands) {
        if (commandData is! Map<String, dynamic>) continue;

        final command = commandData['command'] as String?;
        final args = commandData['args'] as List?;

        if (command == null) continue;

        final arguments = [command, ...?args?.cast<String>()];
        final result = await processArguments(arguments);
        results.add(result);

        if (!result.success && batchData['continueOnError'] != true) {
          break;
        }
      }

      return results;
    } catch (e) {
      return [
        CLIResult(
          success: false,
          error: 'Error executing JSON batch: $e',
          exitCode: 1,
        )
      ];
    }
  }

  /// Parse command line string into arguments
  List<String> _parseCommandLine(String commandLine) {
    final arguments = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    bool escapeNext = false;

    for (int i = 0; i < commandLine.length; i++) {
      final char = commandLine[i];

      if (escapeNext) {
        buffer.write(char);
        escapeNext = false;
        continue;
      }

      if (char == '\\') {
        escapeNext = true;
        continue;
      }

      if (char == '"' || char == "'") {
        inQuotes = !inQuotes;
        continue;
      }

      if (char == ' ' && !inQuotes) {
        if (buffer.isNotEmpty) {
          arguments.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }

      buffer.write(char);
    }

    if (buffer.isNotEmpty) {
      arguments.add(buffer.toString());
    }

    return arguments;
  }

  /// Get main help text
  String _getMainHelpText() {
    final buffer = StringBuffer();
    buffer.writeln('BizSync CLI - Business Management Command Line Interface');
    buffer.writeln('');
    buffer.writeln('Usage: bizsync [options] <command> [command-options]');
    buffer.writeln('');
    buffer.writeln('Global Options:');
    buffer.writeln('  -h, --help        Show this help message');
    buffer.writeln('  -v, --version     Show version information');
    buffer.writeln('  --headless        Run in headless mode (no GUI)');
    buffer.writeln('  -c, --config      Configuration file path');
    buffer.writeln(
        '  --log-level       Set log level (debug, info, warn, error)');
    buffer.writeln('  -q, --quiet       Suppress output');
    buffer.writeln('  --verbose         Verbose output');
    buffer.writeln('');
    buffer.writeln('Available Commands:');

    for (final command in _commands.values) {
      buffer.writeln('  ${command.name.padRight(12)} ${command.description}');
    }

    buffer.writeln('');
    buffer.writeln('Use "bizsync <command> --help" for command-specific help.');
    buffer.writeln('');
    buffer.writeln('Examples:');
    buffer.writeln('  bizsync invoice --action list');
    buffer.writeln(
        '  bizsync customer --action create --name "John Doe" --email john@email.com');
    buffer.writeln(
        '  bizsync --headless invoice --action export --number INV-001');

    return buffer.toString();
  }

  /// Check if running in headless mode
  bool isHeadlessMode(List<String> arguments) {
    return arguments.contains('--headless');
  }

  /// Get available commands
  List<String> get availableCommands => _commands.keys.toList();

  /// Get command by name
  CLICommand? getCommand(String name) => _commands[name];

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose of the CLI service
  Future<void> dispose() async {
    _commands.clear();
    _isInitialized = false;
    debugPrint('CLI service disposed');
  }
}
