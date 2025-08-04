import 'dart:convert';
import '../../models/company/company_tax_profile.dart';

enum AuditEventType {
  calculation,
  rateChange,
  reliefApplication,
  complianceFiling,
  dataImport,
  dataExport,
  systemAccess,
  configurationChange,
  error,
}

enum AuditSeverity {
  low,
  medium,
  high,
  critical,
}

class AuditEvent {
  final String id;
  final AuditEventType eventType;
  final DateTime timestamp;
  final String userId;
  final String? companyId;
  final String action;
  final String description;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic>? beforeState;
  final Map<String, dynamic>? afterState;
  final AuditSeverity severity;
  final String? ipAddress;
  final String? userAgent;
  final bool isSystemEvent;

  AuditEvent({
    required this.id,
    required this.eventType,
    required this.timestamp,
    required this.userId,
    this.companyId,
    required this.action,
    required this.description,
    this.metadata = const {},
    this.beforeState,
    this.afterState,
    this.severity = AuditSeverity.low,
    this.ipAddress,
    this.userAgent,
    this.isSystemEvent = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventType': eventType.name,
        'timestamp': timestamp.toIso8601String(),
        'userId': userId,
        'companyId': companyId,
        'action': action,
        'description': description,
        'metadata': metadata,
        'beforeState': beforeState,
        'afterState': afterState,
        'severity': severity.name,
        'ipAddress': ipAddress,
        'userAgent': userAgent,
        'isSystemEvent': isSystemEvent,
      };

  factory AuditEvent.fromJson(Map<String, dynamic> json) => AuditEvent(
        id: json['id'],
        eventType: AuditEventType.values.byName(json['eventType']),
        timestamp: DateTime.parse(json['timestamp']),
        userId: json['userId'],
        companyId: json['companyId'],
        action: json['action'],
        description: json['description'],
        metadata: json['metadata'] ?? {},
        beforeState: json['beforeState'],
        afterState: json['afterState'],
        severity: AuditSeverity.values.byName(json['severity']),
        ipAddress: json['ipAddress'],
        userAgent: json['userAgent'],
        isSystemEvent: json['isSystemEvent'] ?? false,
      );
}

class AuditQuery {
  final DateTime? startDate;
  final DateTime? endDate;
  final List<AuditEventType>? eventTypes;
  final List<AuditSeverity>? severities;
  final String? userId;
  final String? companyId;
  final String? searchTerm;
  final int? limit;
  final int? offset;

  AuditQuery({
    this.startDate,
    this.endDate,
    this.eventTypes,
    this.severities,
    this.userId,
    this.companyId,
    this.searchTerm,
    this.limit,
    this.offset,
  });
}

class AuditReport {
  final DateTime generatedAt;
  final AuditQuery query;
  final int totalEvents;
  final List<AuditEvent> events;
  final Map<String, int> eventTypeCounts;
  final Map<String, int> severityCounts;
  final List<String> topUsers;
  final List<AuditEvent> criticalEvents;

  AuditReport({
    required this.generatedAt,
    required this.query,
    required this.totalEvents,
    required this.events,
    required this.eventTypeCounts,
    required this.severityCounts,
    required this.topUsers,
    required this.criticalEvents,
  });

  Map<String, dynamic> toJson() => {
        'generatedAt': generatedAt.toIso8601String(),
        'totalEvents': totalEvents,
        'events': events.map((e) => e.toJson()).toList(),
        'eventTypeCounts': eventTypeCounts,
        'severityCounts': severityCounts,
        'topUsers': topUsers,
        'criticalEvents': criticalEvents.map((e) => e.toJson()).toList(),
      };
}

abstract class TaxAuditService {
  Future<void> logEvent(AuditEvent event);
  Future<List<AuditEvent>> queryEvents(AuditQuery query);
  Future<AuditReport> generateReport(AuditQuery query);
  Future<void> archiveOldEvents(DateTime cutoffDate);
  Future<Map<String, dynamic>> getComplianceStatus(String companyId);
}

class TaxAuditServiceImpl implements TaxAuditService {
  final List<AuditEvent> _events = []; // In-memory storage for demo

  @override
  Future<void> logEvent(AuditEvent event) async {
    _events.add(event);

    // In production, would save to database
    print('Audit Event Logged: ${event.action} by ${event.userId}');

    // Check for critical events and trigger alerts
    if (event.severity == AuditSeverity.critical) {
      await _handleCriticalEvent(event);
    }
  }

  @override
  Future<List<AuditEvent>> queryEvents(AuditQuery query) async {
    var filteredEvents = _events.where((event) {
      // Date range filter
      if (query.startDate != null &&
          event.timestamp.isBefore(query.startDate!)) {
        return false;
      }
      if (query.endDate != null && event.timestamp.isAfter(query.endDate!)) {
        return false;
      }

      // Event type filter
      if (query.eventTypes != null &&
          !query.eventTypes!.contains(event.eventType)) {
        return false;
      }

      // Severity filter
      if (query.severities != null &&
          !query.severities!.contains(event.severity)) {
        return false;
      }

      // User filter
      if (query.userId != null && event.userId != query.userId) {
        return false;
      }

      // Company filter
      if (query.companyId != null && event.companyId != query.companyId) {
        return false;
      }

      // Search term filter
      if (query.searchTerm != null &&
          !event.description
              .toLowerCase()
              .contains(query.searchTerm!.toLowerCase()) &&
          !event.action
              .toLowerCase()
              .contains(query.searchTerm!.toLowerCase())) {
        return false;
      }

      return true;
    }).toList();

    // Sort by timestamp (newest first)
    filteredEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Apply pagination
    if (query.offset != null) {
      filteredEvents = filteredEvents.skip(query.offset!).toList();
    }
    if (query.limit != null) {
      filteredEvents = filteredEvents.take(query.limit!).toList();
    }

    return filteredEvents;
  }

  @override
  Future<AuditReport> generateReport(AuditQuery query) async {
    final events = await queryEvents(query);
    final allEvents = await queryEvents(AuditQuery(
      startDate: query.startDate,
      endDate: query.endDate,
      companyId: query.companyId,
    ));

    // Calculate statistics
    final eventTypeCounts = <String, int>{};
    final severityCounts = <String, int>{};
    final userCounts = <String, int>{};
    final criticalEvents = <AuditEvent>[];

    for (final event in allEvents) {
      eventTypeCounts[event.eventType.name] =
          (eventTypeCounts[event.eventType.name] ?? 0) + 1;

      severityCounts[event.severity.name] =
          (severityCounts[event.severity.name] ?? 0) + 1;

      userCounts[event.userId] = (userCounts[event.userId] ?? 0) + 1;

      if (event.severity == AuditSeverity.critical) {
        criticalEvents.add(event);
      }
    }

    // Get top users
    final topUsers = userCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(10);

    return AuditReport(
      generatedAt: DateTime.now(),
      query: query,
      totalEvents: allEvents.length,
      events: events,
      eventTypeCounts: eventTypeCounts,
      severityCounts: severityCounts,
      topUsers: topUsers.map((e) => e.key).toList(),
      criticalEvents: criticalEvents,
    );
  }

  @override
  Future<void> archiveOldEvents(DateTime cutoffDate) async {
    final eventsToArchive =
        _events.where((event) => event.timestamp.isBefore(cutoffDate)).toList();

    // In production, would move to archive storage
    for (final event in eventsToArchive) {
      _events.remove(event);
    }

    await logEvent(AuditEvent(
      id: 'archive_${DateTime.now().millisecondsSinceEpoch}',
      eventType: AuditEventType.systemAccess,
      timestamp: DateTime.now(),
      userId: 'system',
      action: 'archive_old_events',
      description:
          'Archived ${eventsToArchive.length} events older than $cutoffDate',
      severity: AuditSeverity.medium,
      isSystemEvent: true,
    ));
  }

  @override
  Future<Map<String, dynamic>> getComplianceStatus(String companyId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    final recentEvents = await queryEvents(AuditQuery(
      companyId: companyId,
      startDate: thirtyDaysAgo,
    ));

    final criticalEvents =
        recentEvents.where((e) => e.severity == AuditSeverity.critical).length;

    final highEvents =
        recentEvents.where((e) => e.severity == AuditSeverity.high).length;

    // Calculate compliance score
    int complianceScore = 100;
    complianceScore -= criticalEvents * 20; // -20 per critical event
    complianceScore -= highEvents * 10; // -10 per high severity event
    complianceScore = complianceScore.clamp(0, 100);

    return {
      'companyId': companyId,
      'complianceScore': complianceScore,
      'period': '30 days',
      'totalEvents': recentEvents.length,
      'criticalEvents': criticalEvents,
      'highSeverityEvents': highEvents,
      'lastAuditDate': recentEvents.isNotEmpty
          ? recentEvents.first.timestamp.toIso8601String()
          : null,
      'recommendations': _generateComplianceRecommendations(
          complianceScore, criticalEvents, highEvents),
    };
  }

  // Convenience methods for common audit events
  Future<void> logTaxCalculation({
    required String userId,
    required String companyId,
    required String calculationType,
    required double amount,
    required double taxAmount,
    Map<String, dynamic>? metadata,
  }) async {
    await logEvent(AuditEvent(
      id: 'calc_${DateTime.now().millisecondsSinceEpoch}',
      eventType: AuditEventType.calculation,
      timestamp: DateTime.now(),
      userId: userId,
      companyId: companyId,
      action: 'tax_calculation',
      description:
          'Calculated $calculationType tax for amount S\$${amount.toStringAsFixed(2)}',
      metadata: {
        'calculationType': calculationType,
        'amount': amount,
        'taxAmount': taxAmount,
        ...?metadata,
      },
      severity: AuditSeverity.low,
    ));
  }

  Future<void> logComplianceFiling({
    required String userId,
    required String companyId,
    required String filingType,
    required String status,
    Map<String, dynamic>? metadata,
  }) async {
    final severity = status.toLowerCase() == 'failed'
        ? AuditSeverity.high
        : AuditSeverity.medium;

    await logEvent(AuditEvent(
      id: 'filing_${DateTime.now().millisecondsSinceEpoch}',
      eventType: AuditEventType.complianceFiling,
      timestamp: DateTime.now(),
      userId: userId,
      companyId: companyId,
      action: 'compliance_filing',
      description: '$filingType filing $status',
      metadata: {
        'filingType': filingType,
        'status': status,
        ...?metadata,
      },
      severity: severity,
    ));
  }

  Future<void> logTaxRateChange({
    required String userId,
    required String taxType,
    required double oldRate,
    required double newRate,
    required DateTime effectiveDate,
  }) async {
    await logEvent(AuditEvent(
      id: 'rate_${DateTime.now().millisecondsSinceEpoch}',
      eventType: AuditEventType.rateChange,
      timestamp: DateTime.now(),
      userId: userId,
      action: 'tax_rate_change',
      description:
          '$taxType rate changed from ${(oldRate * 100).toStringAsFixed(2)}% to ${(newRate * 100).toStringAsFixed(2)}%',
      beforeState: {'rate': oldRate},
      afterState: {'rate': newRate},
      metadata: {
        'taxType': taxType,
        'effectiveDate': effectiveDate.toIso8601String(),
      },
      severity: AuditSeverity.high,
      isSystemEvent: true,
    ));
  }

  Future<void> logDataExport({
    required String userId,
    required String companyId,
    required String exportType,
    required int recordCount,
    Map<String, dynamic>? metadata,
  }) async {
    await logEvent(AuditEvent(
      id: 'export_${DateTime.now().millisecondsSinceEpoch}',
      eventType: AuditEventType.dataExport,
      timestamp: DateTime.now(),
      userId: userId,
      companyId: companyId,
      action: 'data_export',
      description: 'Exported $recordCount records of $exportType data',
      metadata: {
        'exportType': exportType,
        'recordCount': recordCount,
        ...?metadata,
      },
      severity: AuditSeverity.medium,
    ));
  }

  Future<void> logSystemError({
    required String userId,
    required String error,
    required String context,
    Map<String, dynamic>? metadata,
  }) async {
    await logEvent(AuditEvent(
      id: 'error_${DateTime.now().millisecondsSinceEpoch}',
      eventType: AuditEventType.error,
      timestamp: DateTime.now(),
      userId: userId,
      action: 'system_error',
      description: 'System error in $context: $error',
      metadata: {
        'error': error,
        'context': context,
        ...?metadata,
      },
      severity: AuditSeverity.high,
      isSystemEvent: true,
    ));
  }

  Future<void> _handleCriticalEvent(AuditEvent event) async {
    // In production, would send alerts, notifications, etc.
    print('CRITICAL AUDIT EVENT: ${event.description}');

    // Could integrate with notification service, email alerts, etc.
  }

  List<String> _generateComplianceRecommendations(
      int score, int criticalEvents, int highEvents) {
    final recommendations = <String>[];

    if (score < 50) {
      recommendations.add(
          'Immediate attention required - multiple compliance issues detected');
    } else if (score < 80) {
      recommendations
          .add('Review recent audit events and address identified issues');
    }

    if (criticalEvents > 0) {
      recommendations
          .add('Investigate and resolve $criticalEvents critical events');
    }

    if (highEvents > 5) {
      recommendations
          .add('High number of high-severity events - review system processes');
    }

    recommendations.addAll([
      'Regularly review audit logs for compliance monitoring',
      'Ensure proper user access controls are in place',
      'Maintain documentation for all tax-related decisions',
    ]);

    return recommendations;
  }

  // Sample data for demonstration
  void _loadSampleAuditData() {
    final sampleEvents = [
      AuditEvent(
        id: 'sample_1',
        eventType: AuditEventType.calculation,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        userId: 'user123',
        companyId: 'comp456',
        action: 'gst_calculation',
        description: 'Calculated GST for invoice INV-001',
        metadata: {'amount': 10000, 'gstAmount': 900},
        severity: AuditSeverity.low,
      ),
      AuditEvent(
        id: 'sample_2',
        eventType: AuditEventType.complianceFiling,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        userId: 'user123',
        companyId: 'comp456',
        action: 'gst_f5_filing',
        description: 'GST F5 return submitted successfully',
        metadata: {'period': 'Q4 2024', 'netGst': 15000},
        severity: AuditSeverity.medium,
      ),
      AuditEvent(
        id: 'sample_3',
        eventType: AuditEventType.rateChange,
        timestamp: DateTime.now().subtract(const Duration(days: 30)),
        userId: 'system',
        action: 'gst_rate_update',
        description: 'GST rate changed from 7% to 8%',
        beforeState: {'rate': 0.07},
        afterState: {'rate': 0.08},
        severity: AuditSeverity.high,
        isSystemEvent: true,
      ),
    ];

    _events.addAll(sampleEvents);
  }

  TaxAuditServiceImpl() {
    _loadSampleAuditData();
  }
}
