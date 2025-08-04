import 'crdt_models.dart';

/// Types of conflicts that can occur
enum ConflictType {
  concurrent,
  deleteUpdate,
  updateDelete,
  duplicateKey,
  constraintViolation,
}

/// Conflict resolution strategies
enum ResolutionStrategy {
  lastWriteWins,
  firstWriteWins,
  manualReview,
  businessRulesBased,
  userChoice,
  merge,
}

/// Represents a conflict between two versions of data
class DataConflict<T extends CRDTModel> {
  final String id;
  final ConflictType type;
  final T localVersion;
  final T remoteVersion;
  final DateTime detectedAt;
  final String tableName;

  const DataConflict({
    required this.id,
    required this.type,
    required this.localVersion,
    required this.remoteVersion,
    required this.detectedAt,
    required this.tableName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'local_version': localVersion.toCRDTJson(),
      'remote_version': remoteVersion.toCRDTJson(),
      'detected_at': detectedAt.millisecondsSinceEpoch,
      'table_name': tableName,
    };
  }
}

/// Result of conflict resolution
class ConflictResolution<T extends CRDTModel> {
  final T resolvedValue;
  final ResolutionStrategy strategy;
  final String reason;
  final bool requiresManualReview;
  final Map<String, dynamic>? metadata;

  const ConflictResolution({
    required this.resolvedValue,
    required this.strategy,
    required this.reason,
    this.requiresManualReview = false,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'resolved_value': resolvedValue.toCRDTJson(),
      'strategy': strategy.name,
      'reason': reason,
      'requires_manual_review': requiresManualReview,
      'metadata': metadata,
    };
  }
}

/// CRDT-aware conflict resolver
class ConflictResolver {
  final List<ConflictResolutionRule> _rules = [];

  ConflictResolver() {
    _initializeDefaultRules();
  }

  /// Detect conflicts between local and remote versions
  ConflictType? detectConflict<T extends CRDTModel>(T local, T remote) {
    // Same version - no conflict
    if (local.version.equals(remote.version)) {
      return null;
    }

    // One is deleted, other is updated
    if (local.isDeleted && !remote.isDeleted) {
      return ConflictType.deleteUpdate;
    }
    if (!local.isDeleted && remote.isDeleted) {
      return ConflictType.updateDelete;
    }

    // Check for concurrent updates
    if (local.version.isConcurrentWith(remote.version)) {
      return ConflictType.concurrent;
    }

    return null;
  }

  /// Resolve conflict using appropriate strategy
  Future<ConflictResolution<T>> resolveConflict<T extends CRDTModel>(
    DataConflict<T> conflict,
  ) async {
    // Find applicable resolution rule
    final rule = _findApplicableRule(conflict);

    switch (rule.strategy) {
      case ResolutionStrategy.merge:
        return await _mergeCRDTValues(conflict, rule);

      case ResolutionStrategy.lastWriteWins:
        return _resolveLastWriteWins(conflict, rule);

      case ResolutionStrategy.firstWriteWins:
        return _resolveFirstWriteWins(conflict, rule);

      case ResolutionStrategy.businessRulesBased:
        return await _resolveBusinessRules(conflict, rule);

      case ResolutionStrategy.manualReview:
        return _requireManualReview(conflict, rule);

      case ResolutionStrategy.userChoice:
        return _requireUserChoice(conflict, rule);
    }
  }

  /// Merge CRDT values (preferred approach)
  Future<ConflictResolution<T>> _mergeCRDTValues<T extends CRDTModel>(
    DataConflict<T> conflict,
    ConflictResolutionRule rule,
  ) async {
    final merged = _createCopy(conflict.localVersion);
    merged.mergeWith(conflict.remoteVersion);

    return ConflictResolution(
      resolvedValue: merged,
      strategy: ResolutionStrategy.merge,
      reason: 'CRDT merge operation - no data loss',
      requiresManualReview: false,
      metadata: {
        'local_version': conflict.localVersion.version.toString(),
        'remote_version': conflict.remoteVersion.version.toString(),
        'merged_version': merged.version.toString(),
      },
    );
  }

  /// Resolve using last-write-wins strategy
  ConflictResolution<T> _resolveLastWriteWins<T extends CRDTModel>(
    DataConflict<T> conflict,
    ConflictResolutionRule rule,
  ) {
    final winner = conflict.localVersion.updatedAt
            .happensAfter(conflict.remoteVersion.updatedAt)
        ? conflict.localVersion
        : conflict.remoteVersion;

    return ConflictResolution(
      resolvedValue: winner,
      strategy: ResolutionStrategy.lastWriteWins,
      reason: 'Selected version with latest timestamp',
      requiresManualReview: rule.requiresReview,
      metadata: {
        'winner': winner == conflict.localVersion ? 'local' : 'remote',
        'local_timestamp': conflict.localVersion.updatedAt.toString(),
        'remote_timestamp': conflict.remoteVersion.updatedAt.toString(),
      },
    );
  }

  /// Resolve using first-write-wins strategy
  ConflictResolution<T> _resolveFirstWriteWins<T extends CRDTModel>(
    DataConflict<T> conflict,
    ConflictResolutionRule rule,
  ) {
    final winner = conflict.localVersion.updatedAt
            .happensBefore(conflict.remoteVersion.updatedAt)
        ? conflict.localVersion
        : conflict.remoteVersion;

    return ConflictResolution(
      resolvedValue: winner,
      strategy: ResolutionStrategy.firstWriteWins,
      reason: 'Selected version with earliest timestamp',
      requiresManualReview: rule.requiresReview,
      metadata: {
        'winner': winner == conflict.localVersion ? 'local' : 'remote',
        'local_timestamp': conflict.localVersion.updatedAt.toString(),
        'remote_timestamp': conflict.remoteVersion.updatedAt.toString(),
      },
    );
  }

  /// Resolve using business rules
  Future<ConflictResolution<T>> _resolveBusinessRules<T extends CRDTModel>(
    DataConflict<T> conflict,
    ConflictResolutionRule rule,
  ) async {
    // Apply business-specific resolution logic
    if (conflict.localVersion is CRDTCustomer) {
      return await _resolveCustomerConflict(
          conflict as DataConflict<CRDTCustomer>) as ConflictResolution<T>;
    } else if (conflict.localVersion is CRDTInvoice) {
      return await _resolveInvoiceConflict(
          conflict as DataConflict<CRDTInvoice>) as ConflictResolution<T>;
    } else if (conflict.localVersion is CRDTAccountingTransaction) {
      return await _resolveTransactionConflict(
              conflict as DataConflict<CRDTAccountingTransaction>)
          as ConflictResolution<T>;
    }

    // Fallback to merge if no specific business rule
    return await _mergeCRDTValues(conflict, rule);
  }

  /// Customer-specific conflict resolution
  Future<ConflictResolution<CRDTCustomer>> _resolveCustomerConflict(
    DataConflict<CRDTCustomer> conflict,
  ) async {
    final local = conflict.localVersion;
    final remote = conflict.remoteVersion;

    // Merge customer data - CRDTs handle conflicts automatically
    final merged = _createCopy(local);
    merged.mergeWith(remote);

    // Business rule: Always keep higher loyalty points
    if (remote.loyaltyPoints.value > local.loyaltyPoints.value) {
      merged.loyaltyPoints.mergeWith(remote.loyaltyPoints);
    }

    return ConflictResolution(
      resolvedValue: merged,
      strategy: ResolutionStrategy.businessRulesBased,
      reason: 'Customer data merged with loyalty points optimization',
      requiresManualReview: false,
      metadata: {
        'loyalty_points_local': local.loyaltyPoints.value,
        'loyalty_points_remote': remote.loyaltyPoints.value,
        'loyalty_points_merged': merged.loyaltyPoints.value,
      },
    );
  }

  /// Invoice-specific conflict resolution
  Future<ConflictResolution<CRDTInvoice>> _resolveInvoiceConflict(
    DataConflict<CRDTInvoice> conflict,
  ) async {
    final local = conflict.localVersion;
    final remote = conflict.remoteVersion;

    // Business rules for invoices
    // 1. If one is paid and other is sent, paid wins
    if (local.status.value == 'paid' && remote.status.value != 'paid') {
      return ConflictResolution(
        resolvedValue: local,
        strategy: ResolutionStrategy.businessRulesBased,
        reason: 'Paid invoice takes precedence over other statuses',
        requiresManualReview: false,
      );
    }

    if (remote.status.value == 'paid' && local.status.value != 'paid') {
      return ConflictResolution(
        resolvedValue: remote,
        strategy: ResolutionStrategy.businessRulesBased,
        reason: 'Paid invoice takes precedence over other statuses',
        requiresManualReview: false,
      );
    }

    // 2. If one is cancelled, cancelled wins (unless other is paid)
    if (local.status.value == 'cancelled' && remote.status.value != 'paid') {
      return ConflictResolution(
        resolvedValue: local,
        strategy: ResolutionStrategy.businessRulesBased,
        reason: 'Cancelled invoice takes precedence',
        requiresManualReview: true, // May need review
      );
    }

    // 3. Otherwise merge using CRDT
    final merged = _createCopy(local);
    merged.mergeWith(remote);

    return ConflictResolution(
      resolvedValue: merged,
      strategy: ResolutionStrategy.businessRulesBased,
      reason: 'Invoice data merged with business rule validation',
      requiresManualReview: _requiresInvoiceReview(merged),
    );
  }

  /// Transaction-specific conflict resolution
  Future<ConflictResolution<CRDTAccountingTransaction>>
      _resolveTransactionConflict(
    DataConflict<CRDTAccountingTransaction> conflict,
  ) async {
    final local = conflict.localVersion;
    final remote = conflict.remoteVersion;

    // Business rules for accounting transactions
    // 1. Posted transactions should not be modified
    if (local.status.value == 'posted' && remote.status.value != 'posted') {
      return ConflictResolution(
        resolvedValue: local,
        strategy: ResolutionStrategy.businessRulesBased,
        reason: 'Posted transaction is immutable',
        requiresManualReview: true,
      );
    }

    if (remote.status.value == 'posted' && local.status.value != 'posted') {
      return ConflictResolution(
        resolvedValue: remote,
        strategy: ResolutionStrategy.businessRulesBased,
        reason: 'Posted transaction is immutable',
        requiresManualReview: true,
      );
    }

    // 2. Merge draft transactions
    final merged = _createCopy(local);
    merged.mergeWith(remote);

    return ConflictResolution(
      resolvedValue: merged,
      strategy: ResolutionStrategy.businessRulesBased,
      reason: 'Draft transaction merged',
      requiresManualReview: !merged.isBalanced,
      metadata: {
        'is_balanced': merged.isBalanced,
        'total_debit': merged.totalDebit,
        'total_credit': merged.totalCredit,
      },
    );
  }

  /// Require manual review
  ConflictResolution<T> _requireManualReview<T extends CRDTModel>(
    DataConflict<T> conflict,
    ConflictResolutionRule rule,
  ) {
    return ConflictResolution(
      resolvedValue: conflict.localVersion, // Keep local for now
      strategy: ResolutionStrategy.manualReview,
      reason: rule.description,
      requiresManualReview: true,
      metadata: {
        'conflict_type': conflict.type.name,
        'requires_user_intervention': true,
      },
    );
  }

  /// Require user choice
  ConflictResolution<T> _requireUserChoice<T extends CRDTModel>(
    DataConflict<T> conflict,
    ConflictResolutionRule rule,
  ) {
    return ConflictResolution(
      resolvedValue: conflict.localVersion, // Default to local
      strategy: ResolutionStrategy.userChoice,
      reason: 'User must choose between conflicting versions',
      requiresManualReview: true,
      metadata: {
        'local_summary': _getSummary(conflict.localVersion),
        'remote_summary': _getSummary(conflict.remoteVersion),
      },
    );
  }

  /// Find applicable resolution rule
  ConflictResolutionRule _findApplicableRule<T extends CRDTModel>(
      DataConflict<T> conflict) {
    for (final rule in _rules) {
      if (rule.appliesTo(conflict)) {
        return rule;
      }
    }

    // Default rule: merge CRDTs
    return ConflictResolutionRule(
      name: 'default_merge',
      description: 'Default CRDT merge strategy',
      strategy: ResolutionStrategy.merge,
      condition: (conflict) => true,
      requiresReview: false,
    );
  }

  /// Initialize default conflict resolution rules
  void _initializeDefaultRules() {
    // Rule 1: Always merge CRDTs when possible
    _rules.add(ConflictResolutionRule(
      name: 'crdt_merge',
      description: 'Merge CRDT values automatically',
      strategy: ResolutionStrategy.merge,
      condition: (conflict) => true,
      requiresReview: false,
    ));

    // Rule 2: Delete-Update conflicts need review
    _rules.add(ConflictResolutionRule(
      name: 'delete_update_review',
      description: 'Delete-Update conflicts require manual review',
      strategy: ResolutionStrategy.manualReview,
      condition: (conflict) => conflict.type == ConflictType.deleteUpdate,
      requiresReview: true,
    ));

    // Rule 3: Financial data needs review
    _rules.add(ConflictResolutionRule(
      name: 'financial_review',
      description: 'Financial data conflicts require review',
      strategy: ResolutionStrategy.businessRulesBased,
      condition: (conflict) =>
          conflict.tableName.contains('invoice') ||
          conflict.tableName.contains('transaction'),
      requiresReview: true,
    ));
  }

  /// Check if invoice requires review
  bool _requiresInvoiceReview(CRDTInvoice invoice) {
    // Review needed if amounts are very different or status conflicts
    return invoice.totalAmount.value > 10000 || // Large amounts
        invoice.status.value == 'cancelled'; // Cancelled invoices
  }

  /// Create a deep copy of CRDT model
  T _createCopy<T extends CRDTModel>(T original) {
    // This would need to be implemented for each CRDT type
    // For now, assume we can recreate from JSON
    final json = original.toCRDTJson();

    if (original is CRDTCustomer) {
      return CRDTCustomer.fromCRDTJson(json) as T;
    } else if (original is CRDTInvoice) {
      // Would need CRDTInvoice.fromCRDTJson implementation
      throw UnimplementedError('CRDTInvoice.fromCRDTJson not implemented');
    }

    throw UnimplementedError('Copy not implemented for ${T.toString()}');
  }

  /// Get summary of CRDT model for user display
  Map<String, dynamic> _getSummary<T extends CRDTModel>(T model) {
    if (model is CRDTCustomer) {
      return {
        'type': 'customer',
        'name': model.name.value,
        'email': model.email.value,
        'updated_at': model.updatedAt.physicalTime,
      };
    } else if (model is CRDTInvoice) {
      return {
        'type': 'invoice',
        'invoice_number': model.invoiceNumber.value,
        'total_amount': model.totalAmount.value,
        'status': model.status.value,
        'updated_at': model.updatedAt.physicalTime,
      };
    }

    return {
      'type': 'unknown',
      'id': model.id,
      'updated_at': model.updatedAt.physicalTime,
    };
  }
}

/// Conflict resolution rule
class ConflictResolutionRule {
  final String name;
  final String description;
  final ResolutionStrategy strategy;
  final bool Function(DataConflict) condition;
  final bool requiresReview;

  const ConflictResolutionRule({
    required this.name,
    required this.description,
    required this.strategy,
    required this.condition,
    this.requiresReview = false,
  });

  bool appliesTo(DataConflict conflict) => condition(conflict);
}
