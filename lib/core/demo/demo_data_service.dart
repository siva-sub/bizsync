import 'dart:math';
import '../../data/models/customer.dart';
import '../../features/invoices/models/enhanced_invoice.dart';
import '../../features/notifications/models/notification_models.dart';
import '../../features/notifications/models/notification_types.dart';
import 'models/demo_employee.dart';
import '../../core/utils/uuid_generator.dart';

class DemoDataService {
  static final DemoDataService _instance = DemoDataService._internal();
  factory DemoDataService() => _instance;
  DemoDataService._internal();

  bool _isInitialized = false;
  final Random _random = Random();

  // Demo data storage
  List<Customer> _customers = [];
  List<EnhancedInvoice> _invoices = [];
  List<Employee> _employees = [];
  List<NotificationModel> _notifications = [];
  
  // Getters
  List<Customer> get customers => List.unmodifiable(_customers);
  List<EnhancedInvoice> get invoices => List.unmodifiable(_invoices);
  List<Employee> get employees => List.unmodifiable(_employees);
  List<NotificationModel> get notifications => List.unmodifiable(_notifications);

  bool get isInitialized => _isInitialized;

  Future<void> initializeDemoData() async {
    if (_isInitialized) return;

    // Generate demo data
    await _generateCustomers();
    await _generateEmployees();
    await _generateInvoices();
    await _generateNotifications();

    _isInitialized = true;
  }

  Future<void> _generateCustomers() async {
    final singaporeBusinesses = [
      {
        'name': 'TechCorp Singapore Pte Ltd',
        'email': 'admin@techcorp.sg',
        'phone': '+65 6123 4567',
        'address': '1 Marina Bay Sands, #50-01, Singapore 018956',
        'gstRegistered': true,
        'uen': '202312345A',
      },
      {
        'name': 'Golden Dragon Trading',
        'email': 'orders@goldendragon.sg',
        'phone': '+65 6234 5678',
        'address': '100 Orchard Road, #12-34, Singapore 238840',
        'gstRegistered': true,
        'uen': '201987654B',
      },
      {
        'name': 'Sunrise Logistics Pte Ltd',
        'email': 'info@sunriselogistics.sg',
        'phone': '+65 6345 6789',
        'address': '2 Jurong East Central 1, Singapore 609731',
        'gstRegistered': true,
        'uen': '200876543C',
      },
      {
        'name': 'Eco Green Solutions',
        'email': 'contact@ecogreen.sg',
        'phone': '+65 6456 7890',
        'address': '10 Anson Road, #15-12, Singapore 079903',
        'gstRegistered': false,
        'uen': '202345678D',
      },
      {
        'name': 'Digital Innovations Hub',
        'email': 'hello@digitalhub.sg',
        'phone': '+65 6567 8901',
        'address': '3 Science Park Drive, Singapore 118223',
        'gstRegistered': true,
        'uen': '201234567E',
      },
      {
        'name': 'Foodie Paradise Restaurant',
        'email': 'orders@foodieparadise.sg',
        'phone': '+65 6678 9012',
        'address': '456 Bugis Street, Singapore 188871',
        'gstRegistered': false,
        'uen': '202098765F',
      },
    ];

    for (int i = 0; i < singaporeBusinesses.length; i++) {
      final business = singaporeBusinesses[i];
      _customers.add(Customer(
        id: UuidGenerator.generateId(),
        name: business['name'] as String,
        email: business['email'] as String,
        phone: business['phone'] as String,
        address: business['address'] as String,
        isActive: true,
        gstRegistered: business['gstRegistered'] as bool,
        uen: business['uen'] as String,
        createdAt: DateTime.now().subtract(Duration(days: _random.nextInt(365))),
        updatedAt: DateTime.now().subtract(Duration(days: _random.nextInt(365))),
      ));
    }
  }

  Future<void> _generateEmployees() async {
    final singaporeEmployees = [
      {
        'name': 'Lim Wei Ming',
        'position': 'Senior Software Engineer',
        'email': 'weiming.lim@bizsync.sg',
        'phone': '+65 9123 4567',
        'workPassType': 'Citizen',
        'nric': 'S1234567A',
        'basicSalary': 8500.0,
        'cpfContribution': 1700.0,
      },
      {
        'name': 'Priya Sharma',
        'position': 'Marketing Manager',
        'email': 'priya.sharma@bizsync.sg',
        'phone': '+65 9234 5678',
        'workPassType': 'Employment Pass',
        'nric': 'G1234567B',
        'basicSalary': 6800.0,
        'cpfContribution': 1360.0,
      },
      {
        'name': 'Chen Ming Hui',
        'position': 'Accountant',
        'email': 'minghui.chen@bizsync.sg',
        'phone': '+65 9345 6789',
        'workPassType': 'Permanent Resident',
        'nric': 'S9876543C',
        'basicSalary': 5200.0,
        'cpfContribution': 1040.0,
      },
      {
        'name': 'Ahmed Hassan',
        'position': 'DevOps Engineer',
        'email': 'ahmed.hassan@bizsync.sg',
        'phone': '+65 9456 7890',
        'workPassType': 'S Pass',
        'nric': 'G9876543D',
        'basicSalary': 4800.0,
        'cpfContribution': 960.0,
      },
      {
        'name': 'Sarah Tan',
        'position': 'HR Executive',
        'email': 'sarah.tan@bizsync.sg',
        'phone': '+65 9567 8901',
        'workPassType': 'Citizen',
        'nric': 'S5678901E',
        'basicSalary': 4200.0,
        'cpfContribution': 840.0,
      },
    ];

    for (int i = 0; i < singaporeEmployees.length; i++) {
      final emp = singaporeEmployees[i];
      _employees.add(Employee(
        id: UuidGenerator.generateId(),
        name: emp['name'] as String,
        position: emp['position'] as String,
        email: emp['email'] as String,
        phone: emp['phone'] as String,
        workPassType: emp['workPassType'] as String,
        nric: emp['nric'] as String,
        basicSalary: emp['basicSalary'] as double,
        cpfContribution: emp['cpfContribution'] as double,
        isActive: true,
        joinDate: DateTime.now().subtract(Duration(days: _random.nextInt(1095))), // Up to 3 years ago
        leaveBalance: _random.nextInt(21) + 5, // 5-25 days
      ));
    }
  }

  Future<void> _generateInvoices() async {
    final invoiceItems = [
      {'description': 'Web Development Services', 'unitPrice': 1200.0, 'quantity': 1},
      {'description': 'Mobile App Development', 'unitPrice': 2500.0, 'quantity': 1},
      {'description': 'UI/UX Design Consultation', 'unitPrice': 800.0, 'quantity': 2},
      {'description': 'Digital Marketing Campaign', 'unitPrice': 1500.0, 'quantity': 1},
      {'description': 'System Integration Services', 'unitPrice': 3000.0, 'quantity': 1},
      {'description': 'Cloud Infrastructure Setup', 'unitPrice': 1800.0, 'quantity': 1},
      {'description': 'Data Analytics Dashboard', 'unitPrice': 2200.0, 'quantity': 1},
      {'description': 'E-commerce Platform Development', 'unitPrice': 4500.0, 'quantity': 1},
      {'description': 'Software Maintenance (Monthly)', 'unitPrice': 500.0, 'quantity': 3},
      {'description': 'Training & Support Services', 'unitPrice': 600.0, 'quantity': 4},
    ];

    final statuses = [
      InvoiceStatus.draft,
      InvoiceStatus.sent,
      InvoiceStatus.paid,
      InvoiceStatus.overdue,
      InvoiceStatus.cancelled,
    ];

    for (int i = 0; i < 15; i++) {
      final customer = _customers[_random.nextInt(_customers.length)];
      final item = invoiceItems[_random.nextInt(invoiceItems.length)];
      final status = statuses[_random.nextInt(statuses.length)];
      
      final subtotal = (item['unitPrice'] as double) * (item['quantity'] as int);
      final gstRate = customer.gstRegistered ? 0.09 : 0.0; // 9% GST for registered customers
      final gstAmount = subtotal * gstRate;
      final total = subtotal + gstAmount;

      final invoiceDate = DateTime.now().subtract(Duration(days: _random.nextInt(90)));
      final dueDate = invoiceDate.add(Duration(days: 30));

      _invoices.add(EnhancedInvoice(
        id: UuidGenerator.generateId(),
        invoiceNumber: 'INV-${(1000 + i).toString()}',
        customerId: customer.id,
        customerName: customer.name,
        customerEmail: customer.email,
        customerAddress: customer.address,
        issueDate: invoiceDate,
        dueDate: dueDate,
        lineItems: [
          InvoiceLineItem(
            id: UuidGenerator.generateId(),
            description: item['description'] as String,
            quantity: (item['quantity'] as int).toDouble(),
            unitPrice: item['unitPrice'] as double,
            taxRate: gstRate,
            lineTotal: subtotal,
          ),
        ],
        subtotal: subtotal,
        taxAmount: gstAmount,
        totalAmount: total,
        status: status,
        notes: _generateInvoiceNotes(status),
        terms: 'Payment due within 30 days. Late payment charges may apply.',
        createdAt: invoiceDate,
        updatedAt: status == InvoiceStatus.paid 
          ? invoiceDate.add(Duration(days: _random.nextInt(30)))
          : invoiceDate,
      ));
    }

    // Sort invoices by date (most recent first)
    _invoices.sort((a, b) => b.issueDate.compareTo(a.issueDate));
  }

  String _generateInvoiceNotes(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return 'Invoice prepared and ready for review.';
      case InvoiceStatus.pending:
        return 'Invoice pending approval.';
      case InvoiceStatus.approved:
        return 'Invoice approved and ready to send.';
      case InvoiceStatus.sent:
        return 'Invoice sent to customer via email.';
      case InvoiceStatus.viewed:
        return 'Invoice viewed by customer.';
      case InvoiceStatus.partiallyPaid:
        return 'Partial payment received. Balance pending.';
      case InvoiceStatus.paid:
        return 'Payment received and processed successfully.';
      case InvoiceStatus.overdue:
        return 'Payment is overdue. Please contact customer for follow-up.';
      case InvoiceStatus.cancelled:
        return 'Invoice cancelled as per customer request.';
      case InvoiceStatus.disputed:
        return 'Invoice disputed by customer. Under review.';
      case InvoiceStatus.voided:
        return 'Invoice voided and cancelled.';
      case InvoiceStatus.refunded:
        return 'Payment refunded to customer.';
    }
  }

  Future<void> _generateNotifications() async {
    final notificationTypes = [
      {
        'title': 'Payment Received',
        'message': 'Payment of \$2,500 received from TechCorp Singapore',
        'type': NotificationCategory.payment,
        'priority': NotificationPriority.high,
      },
      {
        'title': 'Invoice Overdue',
        'message': 'Invoice INV-1003 is 5 days overdue',
        'type': NotificationCategory.invoice,
        'priority': NotificationPriority.high,
      },
      {
        'title': 'New Customer Added',
        'message': 'Digital Innovations Hub has been added to your customer list',
        'type': NotificationCategory.custom,
        'priority': NotificationPriority.medium,
      },
      {
        'title': 'Backup Completed',
        'message': 'Daily backup completed successfully at 2:00 AM',
        'type': NotificationCategory.system,
        'priority': NotificationPriority.low,
      },
      {
        'title': 'GST Filing Reminder',
        'message': 'GST filing due in 7 days',
        'type': NotificationCategory.tax,
        'priority': NotificationPriority.high,
      },
      {
        'title': 'Employee Leave Request',
        'message': 'Priya Sharma has requested 3 days leave',
        'type': NotificationCategory.custom,
        'priority': NotificationPriority.medium,
      },
      {
        'title': 'Sync Completed',
        'message': 'Data synchronization with 2 devices completed',
        'type': NotificationCategory.system,
        'priority': NotificationPriority.low,
      },
    ];

    for (int i = 0; i < notificationTypes.length; i++) {
      final notification = notificationTypes[i];
      _notifications.add(NotificationModel(
        id: UuidGenerator.generateId(),
        title: notification['title'] as String,
        body: notification['message'] as String,
        type: BusinessNotificationType.custom,
        category: notification['type'] as NotificationCategory,
        priority: notification['priority'] as NotificationPriority,
        channel: (notification['type'] as NotificationCategory).defaultChannel,
        createdAt: DateTime.now().subtract(Duration(hours: _random.nextInt(72))),
      ));
    }

    // Sort notifications by date (most recent first)
    _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Dashboard metrics calculation
  Map<String, dynamic> getDashboardMetrics() {
    if (!_isInitialized) return {};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonth = DateTime(now.year, now.month, 1);

    // Calculate revenue metrics
    final paidInvoices = _invoices.where((inv) => inv.status == InvoiceStatus.paid);
    final totalRevenue = paidInvoices.fold<double>(0, (sum, inv) => sum + inv.total);
    final monthlyRevenue = paidInvoices
        .where((inv) => inv.updatedAt.isAfter(thisMonth))
        .fold<double>(0, (sum, inv) => sum + inv.total);

    // Calculate invoice metrics
    final totalInvoices = _invoices.length;
    final pendingInvoices = _invoices.where((inv) => 
        inv.status == InvoiceStatus.sent || inv.status == InvoiceStatus.draft).length;
    final overdueInvoices = _invoices.where((inv) => inv.status == InvoiceStatus.overdue).length;

    // Calculate customer metrics
    final totalCustomers = _customers.length;
    final activeCustomers = _customers.where((c) => c.isActive).length;

    // Calculate employee metrics
    final totalEmployees = _employees.length;
    final activeEmployees = _employees.where((e) => e.isActive).length;

    return {
      'revenue': {
        'total': totalRevenue,
        'monthly': monthlyRevenue,
        'change': '+8.2%', // Mock percentage change
      },
      'invoices': {
        'total': totalInvoices,
        'pending': pendingInvoices,
        'overdue': overdueInvoices,
        'paid': paidInvoices.length,
      },
      'customers': {
        'total': totalCustomers,
        'active': activeCustomers,
      },
      'employees': {
        'total': totalEmployees,
        'active': activeEmployees,
      },
      'payments': {
        'total': totalRevenue * 0.75, // Assume 75% of revenue received
        'pending': totalRevenue * 0.25,
      },
    };
  }

  // Get recent activity
  List<Map<String, dynamic>> getRecentActivity() {
    if (!_isInitialized) return [];

    final activities = <Map<String, dynamic>>[];

    // Add recent invoice activities
    for (final invoice in _invoices.take(3)) {
      activities.add({
        'icon': 'receipt_long',
        'title': 'Invoice ${invoice.invoiceNumber} ${_getInvoiceActivityText(invoice.status)}',
        'subtitle': _getRelativeTime(invoice.updatedAt),
        'color': _getInvoiceActivityColor(invoice.status),
      });
    }

    // Add recent notifications
    for (final notification in _notifications.take(2)) {
      activities.add({
        'icon': _getNotificationIcon(notification.category),
        'title': notification.title,
        'subtitle': _getRelativeTime(notification.createdAt),
        'color': _getNotificationColor(notification.priority),
      });
    }

    // Sort by most recent
    activities.sort((a, b) => b['subtitle'].toString().compareTo(a['subtitle'].toString()));

    return activities.take(5).toList();
  }

  String _getInvoiceActivityText(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft: return 'created';
      case InvoiceStatus.pending: return 'pending';
      case InvoiceStatus.approved: return 'approved';
      case InvoiceStatus.sent: return 'sent';
      case InvoiceStatus.viewed: return 'viewed';
      case InvoiceStatus.partiallyPaid: return 'partially paid';
      case InvoiceStatus.paid: return 'paid';
      case InvoiceStatus.overdue: return 'overdue';
      case InvoiceStatus.cancelled: return 'cancelled';
      case InvoiceStatus.disputed: return 'disputed';
      case InvoiceStatus.voided: return 'voided';
      case InvoiceStatus.refunded: return 'refunded';
    }
  }

  String _getInvoiceActivityColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid: return 'green';
      case InvoiceStatus.overdue: return 'red';
      case InvoiceStatus.sent: return 'blue';
      case InvoiceStatus.cancelled: return 'grey';
      default: return 'orange';
    }
  }

  String _getNotificationIcon(NotificationCategory type) {
    switch (type) {
      case NotificationCategory.payment: return 'payment';
      case NotificationCategory.invoice: return 'receipt_long';
      case NotificationCategory.custom: return 'person_add';
      case NotificationCategory.tax: return 'account_balance';
      case NotificationCategory.system: return 'settings';
      default: return 'notifications';
    }
  }

  String _getNotificationColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.critical: return 'darkred';
      case NotificationPriority.high: return 'red';
      case NotificationPriority.medium: return 'orange';
      case NotificationPriority.low: return 'blue';
      case NotificationPriority.info: return 'gray';
    }
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  // Get invoice by ID
  EnhancedInvoice? getInvoiceById(String id) {
    try {
      return _invoices.firstWhere((invoice) => invoice.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get customer by ID
  Customer? getCustomerById(String id) {
    try {
      return _customers.firstWhere((customer) => customer.id == id);
    } catch (e) {
      return null;
    }
  }

  // Clear all demo data
  void clearDemoData() {
    _customers.clear();
    _invoices.clear();
    _employees.clear();
    _notifications.clear();
    _isInitialized = false;
  }
}