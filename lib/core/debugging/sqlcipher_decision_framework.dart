import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../utils/uuid_generator.dart';
import '../constants/app_constants.dart';
import '../database/platform_database_factory.dart';
import 'cross_platform_compatibility_validator.dart';

/// Decision factors for SQLCipher vs SQLite choice
enum DecisionFactor {
  platformSupport,
  securityRequirement,
  performanceImpact,
  developmentComplexity,
  deploymentComplexity,
  maintenanceBurden,
  crossPlatformCompatibility,
  businessRequirements,
  technicalDebt,
  userExperience,
}

/// Decision outcome
enum DatabaseDecision {
  useSQLCipher,
  useSQLite,
  hybridApproach,
  needMoreInformation,
}

/// Decision criterion with weight and evaluation
class DecisionCriterion {
  final DecisionFactor factor;
  final String name;
  final String description;
  final double weight; // 0.0 to 1.0
  final double score; // 0.0 to 10.0
  final String reasoning;
  final List<String> evidence;
  final DatabaseDecision preference; // What this criterion suggests

  const DecisionCriterion({
    required this.factor,
    required this.name,
    required this.description,
    required this.weight,
    required this.score,
    required this.reasoning,
    required this.evidence,
    required this.preference,
  });

  double get weightedScore => weight * score;

  Map<String, dynamic> toJson() {
    return {
      'factor': factor.name,
      'name': name,
      'description': description,
      'weight': weight,
      'score': score,
      'reasoning': reasoning,
      'evidence': evidence,
      'preference': preference.name,
      'weighted_score': weightedScore,
    };
  }
}

/// Comprehensive decision analysis report
class DatabaseDecisionReport {
  final String reportId;
  final DateTime generatedAt;
  final String platform;
  final List<DecisionCriterion> criteria;
  final DatabaseDecision finalDecision;
  final double confidenceScore;
  final String decisionReasoning;
  final List<String> implementationSteps;
  final List<String> riskMitigations;
  final Map<String, dynamic> platformAnalysis;
  final List<String> alternativeOptions;

  const DatabaseDecisionReport({
    required this.reportId,
    required this.generatedAt,
    required this.platform,
    required this.criteria,
    required this.finalDecision,
    required this.confidenceScore,
    required this.decisionReasoning,
    required this.implementationSteps,
    required this.riskMitigations,
    required this.platformAnalysis,
    required this.alternativeOptions,
  });

  Map<String, dynamic> toJson() {
    return {
      'report_id': reportId,
      'generated_at': generatedAt.toIso8601String(),
      'platform': platform,
      'criteria': criteria.map((c) => c.toJson()).toList(),
      'final_decision': finalDecision.name,
      'confidence_score': confidenceScore,
      'decision_reasoning': decisionReasoning,
      'implementation_steps': implementationSteps,
      'risk_mitigations': riskMitigations,
      'platform_analysis': platformAnalysis,
      'alternative_options': alternativeOptions,
    };
  }
}

/// Intelligent decision framework for choosing between SQLCipher and SQLite
class SQLCipherDecisionFramework {
  final CrossPlatformCompatibilityValidator _compatibilityValidator;
  final Map<String, DatabaseDecisionReport> _decisionHistory = {};
  final Map<DecisionFactor, double> _factorWeights;

  SQLCipherDecisionFramework(
    this._compatibilityValidator, {
    Map<DecisionFactor, double>? customWeights,
  }) : _factorWeights = customWeights ?? _getDefaultFactorWeights();

  /// Generate comprehensive decision analysis
  Future<DatabaseDecisionReport> analyzeDecision({
    bool includePerformanceTests = true,
    bool includeSecurityAssessment = true,
    Map<String, dynamic>? businessContext,
    List<String>? specificRequirements,
  }) async {
    debugPrint('🔍 Analyzing SQLCipher vs SQLite decision...');
    
    final reportId = UuidGenerator.generateId();
    final timestamp = DateTime.now();
    final platform = Platform.operatingSystem;

    // Collect comprehensive data
    final platformAnalysis = await _analyzePlatformCapabilities();
    final compatibilityReport = await _compatibilityValidator.validateCompatibility(
      includePerformanceTests: includePerformanceTests,
      includeEncryptionTests: true,
    );

    // Evaluate all decision criteria
    final criteria = await _evaluateAllCriteria(
      platformAnalysis,
      compatibilityReport,
      businessContext,
      specificRequirements,
    );

    // Make decision based on weighted criteria
    final decisionAnalysis = _analyzeDecision(criteria);

    // Generate implementation guidance
    final implementationSteps = _generateImplementationSteps(
      decisionAnalysis['decision'],
      platformAnalysis,
    );

    final riskMitigations = _generateRiskMitigations(
      decisionAnalysis['decision'],
      criteria,
    );

    final alternativeOptions = _generateAlternativeOptions(
      decisionAnalysis['decision'],
      criteria,
    );

    final report = DatabaseDecisionReport(
      reportId: reportId,
      generatedAt: timestamp,
      platform: platform,
      criteria: criteria,
      finalDecision: decisionAnalysis['decision'],
      confidenceScore: decisionAnalysis['confidence'],
      decisionReasoning: decisionAnalysis['reasoning'],
      implementationSteps: implementationSteps,
      riskMitigations: riskMitigations,
      platformAnalysis: platformAnalysis,
      alternativeOptions: alternativeOptions,
    );

    // Store decision for historical analysis
    _decisionHistory[reportId] = report;

    debugPrint('✅ Decision analysis completed: ${report.finalDecision.name} (${report.confidenceScore.toStringAsFixed(1)}% confidence)');
    
    return report;
  }

  /// Quick decision based on current system state
  Future<DatabaseDecision> getQuickDecision() async {
    debugPrint('⚡ Getting quick SQLCipher vs SQLite decision...');
    
    final platform = Platform.operatingSystem;
    
    // Quick platform-based decision
    if (Platform.isAndroid) {
      // Android typically has SQLCipher compatibility issues
      final sqlcipherSupport = await PlatformDatabaseFactory.supportsSqlcipher;
      if (!sqlcipherSupport) {
        debugPrint('💡 Quick decision: SQLite (Android + no SQLCipher support)');
        return DatabaseDecision.useSQLite;
      }
    }

    // Check if we have recent decision for this platform
    final recentDecision = _getRecentDecisionForPlatform(platform);
    if (recentDecision != null) {
      debugPrint('💡 Quick decision: ${recentDecision.name} (from recent analysis)');
      return recentDecision;
    }

    // Default fallback decision
    final defaultDecision = await _getDefaultDecision();
    debugPrint('💡 Quick decision: ${defaultDecision.name} (default for $platform)');
    return defaultDecision;
  }

  /// Test current database configuration against decision
  Future<Map<String, dynamic>> testCurrentConfiguration() async {
    debugPrint('🧪 Testing current database configuration...');
    
    final testResults = <String, dynamic>{
      'test_id': UuidGenerator.generateId(),
      'timestamp': DateTime.now().toIso8601String(),
      'platform': Platform.operatingSystem,
      'current_config': {},
      'test_results': {},
      'issues_found': <String>[],
      'recommendations': <String>[],
    };

    try {
      // Get current configuration
      final dbInfo = await PlatformDatabaseFactory.getDatabaseInfo();
      testResults['current_config'] = dbInfo;

      // Test database connectivity
      final connectivityTest = await _testDatabaseConnectivity();
      testResults['test_results']['connectivity'] = connectivityTest;

      if (!connectivityTest['success']) {
        testResults['issues_found'].add('Database connectivity issues');
        testResults['recommendations'].add('Fix database initialization problems');
      }

      // Test encryption status
      final encryptionTest = await _testEncryptionStatus();
      testResults['test_results']['encryption'] = encryptionTest;

      if (encryptionTest['encryption_requested'] && !encryptionTest['encryption_working']) {
        testResults['issues_found'].add('Encryption requested but not working');
        testResults['recommendations'].add('Consider switching to SQLite or fix SQLCipher setup');
      }

      // Test platform compatibility
      final compatibilityTest = await _testPlatformCompatibility();
      testResults['test_results']['compatibility'] = compatibilityTest;

      if (!compatibilityTest['compatible']) {
        testResults['issues_found'].add('Platform compatibility issues');
        testResults['recommendations'].add('Use platform-specific database configuration');
      }

      // Generate overall assessment
      final issueCount = (testResults['issues_found'] as List).length;
      testResults['overall_status'] = issueCount == 0 ? 'good' : 
                                     issueCount <= 2 ? 'warning' : 'critical';

      testResults['success'] = issueCount == 0;

    } catch (e) {
      testResults['error'] = e.toString();
      testResults['success'] = false;
      testResults['issues_found'].add('Configuration test failed');
    }

    debugPrint('✅ Configuration test completed: ${testResults['overall_status']}');
    return testResults;
  }

  /// Get decision history and trends
  Map<String, dynamic> getDecisionHistory() {
    final history = <String, dynamic>{
      'total_decisions': _decisionHistory.length,
      'decisions_by_platform': <String, int>{},
      'decisions_by_outcome': <String, int>{},
      'average_confidence': 0.0,
      'recent_decisions': <Map<String, dynamic>>[],
    };

    if (_decisionHistory.isEmpty) return history;

    // Analyze decisions by platform
    final platformCounts = <String, int>{};
    final outcomeCounts = <String, int>{};
    double totalConfidence = 0.0;

    for (final report in _decisionHistory.values) {
      platformCounts[report.platform] = (platformCounts[report.platform] ?? 0) + 1;
      outcomeCounts[report.finalDecision.name] = (outcomeCounts[report.finalDecision.name] ?? 0) + 1;
      totalConfidence += report.confidenceScore;
    }

    history['decisions_by_platform'] = platformCounts;
    history['decisions_by_outcome'] = outcomeCounts;
    history['average_confidence'] = totalConfidence / _decisionHistory.length;

    // Get recent decisions (last 5)
    final sortedReports = _decisionHistory.values.toList()
      ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    
    history['recent_decisions'] = sortedReports
      .take(5)
      .map((report) => {
        'id': report.reportId,
        'platform': report.platform,
        'decision': report.finalDecision.name,
        'confidence': report.confidenceScore,
        'timestamp': report.generatedAt.toIso8601String(),
      })
      .toList();

    return history;
  }

  // Private methods

  static Map<DecisionFactor, double> _getDefaultFactorWeights() {
    return {
      DecisionFactor.platformSupport: 0.20,
      DecisionFactor.securityRequirement: 0.15,
      DecisionFactor.performanceImpact: 0.12,
      DecisionFactor.crossPlatformCompatibility: 0.15,
      DecisionFactor.developmentComplexity: 0.10,
      DecisionFactor.deploymentComplexity: 0.08,
      DecisionFactor.maintenanceBurden: 0.08,
      DecisionFactor.businessRequirements: 0.07,
      DecisionFactor.technicalDebt: 0.03,
      DecisionFactor.userExperience: 0.02,
    };
  }

  Future<Map<String, dynamic>> _analyzePlatformCapabilities() async {
    final analysis = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'is_desktop': Platform.isLinux || Platform.isWindows || Platform.isMacOS,
      'is_mobile': Platform.isAndroid || Platform.isIOS,
      'sqlite_support': {},
      'sqlcipher_support': {},
      'file_system': {},
      'performance_characteristics': {},
    };

    // SQLite support analysis
    try {
      final dbInfo = await PlatformDatabaseFactory.getDatabaseInfo();
      analysis['sqlite_support'] = {
        'available': true,
        'factory_type': dbInfo['database_factory'],
        'version_available': true,
      };
    } catch (e) {
      analysis['sqlite_support'] = {
        'available': false,
        'error': e.toString(),
      };
    }

    // SQLCipher support analysis
    try {
      final sqlcipherSupport = await PlatformDatabaseFactory.supportsSqlcipher;
      analysis['sqlcipher_support'] = {
        'available': sqlcipherSupport,
        'tested': true,
      };
    } catch (e) {
      analysis['sqlcipher_support'] = {
        'available': false,
        'error': e.toString(),
        'tested': false,
      };
    }

    // File system capabilities
    analysis['file_system'] = {
      'documents_directory_available': true, // Would test actual access
      'temporary_directory_available': true, // Would test actual access
      'write_permissions': true, // Would test actual permissions
    };

    // Performance characteristics (platform-specific)
    analysis['performance_characteristics'] = _getPerformanceCharacteristics(Platform.operatingSystem);

    return analysis;
  }

  Future<List<DecisionCriterion>> _evaluateAllCriteria(
    Map<String, dynamic> platformAnalysis,
    CompatibilityReport compatibilityReport,
    Map<String, dynamic>? businessContext,
    List<String>? specificRequirements,
  ) async {
    final criteria = <DecisionCriterion>[];

    // Platform Support Criterion
    criteria.add(await _evaluatePlatformSupport(platformAnalysis, compatibilityReport));

    // Security Requirements Criterion
    criteria.add(await _evaluateSecurityRequirements(businessContext, specificRequirements));

    // Performance Impact Criterion
    criteria.add(await _evaluatePerformanceImpact(platformAnalysis, compatibilityReport));

    // Cross-platform Compatibility Criterion
    criteria.add(await _evaluateCrossPlatformCompatibility(compatibilityReport));

    // Development Complexity Criterion
    criteria.add(await _evaluateDevelopmentComplexity(platformAnalysis));

    // Deployment Complexity Criterion
    criteria.add(await _evaluateDeploymentComplexity(platformAnalysis));

    // Maintenance Burden Criterion
    criteria.add(await _evaluateMaintenanceBurden(platformAnalysis));

    // Business Requirements Criterion
    criteria.add(await _evaluateBusinessRequirements(businessContext, specificRequirements));

    // Technical Debt Criterion
    criteria.add(await _evaluateTechnicalDebt());

    // User Experience Criterion
    criteria.add(await _evaluateUserExperience(platformAnalysis));

    return criteria;
  }

  Future<DecisionCriterion> _evaluatePlatformSupport(
    Map<String, dynamic> platformAnalysis,
    CompatibilityReport compatibilityReport,
  ) async {
    final platform = Platform.operatingSystem;
    final sqliteSupport = platformAnalysis['sqlite_support'] as Map<String, dynamic>;
    final sqlcipherSupport = platformAnalysis['sqlcipher_support'] as Map<String, dynamic>;

    double score = 5.0; // Neutral start
    final evidence = <String>[];
    DatabaseDecision preference = DatabaseDecision.useSQLite;

    // SQLite is universally supported
    if (sqliteSupport['available'] == true) {
      score += 2.0;
      evidence.add('SQLite is available and working on $platform');
    }

    // SQLCipher support varies by platform
    if (sqlcipherSupport['available'] == true) {
      score += 1.0;
      evidence.add('SQLCipher is available on $platform');
      
      // If both are available, might consider hybrid or SQLCipher
      if (platform == 'android') {
        score -= 1.0; // Android SQLCipher can be problematic
        evidence.add('SQLCipher on Android can have compatibility issues');
      } else {
        preference = DatabaseDecision.useSQLCipher;
      }
    } else {
      score += 1.0; // Prefer SQLite if SQLCipher not available
      evidence.add('SQLCipher is not available on $platform');
      preference = DatabaseDecision.useSQLite;
    }

    // Consider compatibility test results
    if (!compatibilityReport.isCompatible) {
      score -= 2.0;
      evidence.add('Compatibility tests failed');
    }

    String reasoning;
    if (sqlcipherSupport['available'] == true && platform != 'android') {
      reasoning = 'Platform supports both SQLite and SQLCipher with good compatibility';
    } else if (sqlcipherSupport['available'] != true) {
      reasoning = 'Platform only supports SQLite reliably';
    } else {
      reasoning = 'Platform supports both but SQLCipher may have issues';
    }

    return DecisionCriterion(
      factor: DecisionFactor.platformSupport,
      name: 'Platform Support',
      description: 'How well each database option is supported on the current platform',
      weight: _factorWeights[DecisionFactor.platformSupport]!,
      score: score.clamp(0.0, 10.0),
      reasoning: reasoning,
      evidence: evidence,
      preference: preference,
    );
  }

  Future<DecisionCriterion> _evaluateSecurityRequirements(
    Map<String, dynamic>? businessContext,
    List<String>? specificRequirements,
  ) async {
    double score = 5.0;
    final evidence = <String>[];
    DatabaseDecision preference = DatabaseDecision.useSQLite;

    // Check if encryption is explicitly required
    final encryptionRequired = businessContext?['encryption_required'] == true ||
                              specificRequirements?.contains('encryption') == true ||
                              specificRequirements?.contains('data_encryption') == true;

    if (encryptionRequired) {
      score = 8.0;
      evidence.add('Encryption is explicitly required');
      preference = DatabaseDecision.useSQLCipher;
    } else {
      // Check business context for security indicators
      final isBusinessApp = businessContext?['app_type'] == 'business' ||
                           businessContext?['handles_sensitive_data'] == true;
      
      if (isBusinessApp) {
        score = 6.5;
        evidence.add('Business application handling sensitive data');
        preference = DatabaseDecision.useSQLCipher;
      } else {
        score = 4.0;
        evidence.add('No explicit encryption requirements identified');
        preference = DatabaseDecision.useSQLite;
      }
    }

    // Consider data types being stored
    final dataTypes = businessContext?['data_types'] as List<String>? ?? [];
    if (dataTypes.contains('financial') || dataTypes.contains('personal') || dataTypes.contains('medical')) {
      score += 2.0;
      evidence.add('Handling sensitive data types: ${dataTypes.join(', ')}');
      preference = DatabaseDecision.useSQLCipher;
    }

    return DecisionCriterion(
      factor: DecisionFactor.securityRequirement,
      name: 'Security Requirements',
      description: 'The level of data security and encryption needed',
      weight: _factorWeights[DecisionFactor.securityRequirement]!,
      score: score.clamp(0.0, 10.0),
      reasoning: encryptionRequired 
        ? 'Encryption is required for this application'
        : 'Security requirements are moderate - encryption optional',
      evidence: evidence,
      preference: preference,
    );
  }

  Future<DecisionCriterion> _evaluatePerformanceImpact(
    Map<String, dynamic> platformAnalysis,
    CompatibilityReport compatibilityReport,
  ) async {
    double score = 5.0;
    final evidence = <String>[];
    DatabaseDecision preference = DatabaseDecision.useSQLite;

    // SQLite generally has better performance
    score += 2.0;
    evidence.add('SQLite has lower overhead and better performance');

    // Check if performance tests were run
    final performanceResults = compatibilityReport.testResults
      .where((result) => result.testName.contains('Performance'))
      .toList();

    if (performanceResults.isNotEmpty) {
      final performanceResult = performanceResults.first;
      if (performanceResult.passed) {
        score += 1.0;
        evidence.add('Performance tests passed');
      } else {
        score -= 1.0;
        evidence.add('Performance tests failed');
      }
    }

    // Platform-specific performance considerations
    final performanceChars = platformAnalysis['performance_characteristics'] as Map<String, dynamic>;
    if (performanceChars['encryption_overhead'] == 'high') {
      score += 1.0; // Favor SQLite for high encryption overhead platforms
      evidence.add('Platform has high encryption overhead');
    }

    return DecisionCriterion(
      factor: DecisionFactor.performanceImpact,
      name: 'Performance Impact',
      description: 'The performance impact of each database option',
      weight: _factorWeights[DecisionFactor.performanceImpact]!,
      score: score.clamp(0.0, 10.0),
      reasoning: 'SQLite generally provides better performance with lower overhead',
      evidence: evidence,
      preference: preference,
    );
  }

  Future<DecisionCriterion> _evaluateCrossPlatformCompatibility(
    CompatibilityReport compatibilityReport,
  ) async {
    double score = compatibilityReport.compatibilityScore / 10.0; // Convert percentage to 0-10
    final evidence = <String>[];
    DatabaseDecision preference = DatabaseDecision.useSQLite;

    evidence.add('Overall compatibility score: ${compatibilityReport.compatibilityScore.toStringAsFixed(1)}%');

    // Check for critical compatibility issues
    if (compatibilityReport.criticalIssues.isNotEmpty) {
      score -= 2.0;
      evidence.add('Critical compatibility issues found: ${compatibilityReport.criticalIssues.length}');
    }

    // SQLite is generally more compatible across platforms
    if (score >= 8.0) {
      preference = DatabaseDecision.useSQLCipher; // If compatibility is high, can consider SQLCipher
    } else if (score >= 6.0) {
      preference = DatabaseDecision.hybridApproach; // Mixed compatibility suggests hybrid
    } else {
      preference = DatabaseDecision.useSQLite; // Low compatibility suggests SQLite
    }

    return DecisionCriterion(
      factor: DecisionFactor.crossPlatformCompatibility,
      name: 'Cross-platform Compatibility',
      description: 'How well the database works across different platforms',
      weight: _factorWeights[DecisionFactor.crossPlatformCompatibility]!,
      score: score.clamp(0.0, 10.0),
      reasoning: score >= 7.0 
        ? 'High compatibility allows for more database options'
        : 'Compatibility issues suggest using simpler SQLite approach',
      evidence: evidence,
      preference: preference,
    );
  }

  Future<DecisionCriterion> _evaluateDevelopmentComplexity(
    Map<String, dynamic> platformAnalysis,
  ) async {
    double score = 7.0; // SQLite is simpler
    final evidence = <String>[];
    DatabaseDecision preference = DatabaseDecision.useSQLite;

    evidence.add('SQLite requires less setup and configuration');
    evidence.add('No encryption key management needed with SQLite');

    // Check if SQLCipher is available - if not, complexity is lower
    final sqlcipherSupport = platformAnalysis['sqlcipher_support'] as Map<String, dynamic>;
    if (sqlcipherSupport['available'] != true) {
      score += 1.0;
      evidence.add('SQLCipher not available - reduces complexity choice');
    } else {
      score -= 1.0;
      evidence.add('SQLCipher available but adds configuration complexity');
    }

    // Platform-specific complexity
    if (Platform.isAndroid) {
      score += 1.0;
      evidence.add('Android SQLCipher setup can be complex');
    }

    return DecisionCriterion(
      factor: DecisionFactor.developmentComplexity,
      name: 'Development Complexity',
      description: 'The complexity of implementing and maintaining each option',
      weight: _factorWeights[DecisionFactor.developmentComplexity]!,
      score: score.clamp(0.0, 10.0),
      reasoning: 'SQLite is significantly simpler to implement and maintain',
      evidence: evidence,
      preference: preference,
    );
  }

  Future<DecisionCriterion> _evaluateDeploymentComplexity(
    Map<String, dynamic> platformAnalysis,
  ) async {
    double score = 7.0; // SQLite is simpler to deploy
    final evidence = <String>[];
    DatabaseDecision preference = DatabaseDecision.useSQLite;

    evidence.add('SQLite has no additional dependencies');
    evidence.add('No encryption configuration needed in deployment');

    // Platform-specific deployment considerations
    if (Platform.isAndroid) {
      score += 1.0;
      evidence.add('Android deployment is simpler with SQLite');
    }

    final sqlcipherSupport = platformAnalysis['sqlcipher_support'] as Map<String, dynamic>;
    if (sqlcipherSupport['available'] != true) {
      score += 1.0;
      evidence.add('No SQLCipher dependencies to manage');
    }

    return DecisionCriterion(
      factor: DecisionFactor.deploymentComplexity,
      name: 'Deployment Complexity',
      description: 'The complexity of deploying and distributing the application',
      weight: _factorWeights[DecisionFactor.deploymentComplexity]!,
      score: score.clamp(0.0, 10.0),
      reasoning: 'SQLite deployment is simpler with fewer dependencies',
      evidence: evidence,
      preference: preference,
    );
  }

  Future<DecisionCriterion> _evaluateMaintenanceBurden(
    Map<String, dynamic> platformAnalysis,
  ) async {
    double score = 7.0; // SQLite has lower maintenance burden
    final evidence = <String>[];
    DatabaseDecision preference = DatabaseDecision.useSQLite;

    evidence.add('SQLite requires no key management or encryption maintenance');
    evidence.add('Fewer dependencies to update and maintain');

    // Consider current technical debt
    final currentlyUsingSQLCipher = AppConstants.encryptionKey.isNotEmpty;
    if (currentlyUsingSQLCipher) {
      score -= 1.0;
      evidence.add('Currently using encryption - switching would require migration');
    }

    return DecisionCriterion(
      factor: DecisionFactor.maintenanceBurden,
      name: 'Maintenance Burden',
      description: 'The ongoing maintenance requirements for each option',
      weight: _factorWeights[DecisionFactor.maintenanceBurden]!,
      score: score.clamp(0.0, 10.0),
      reasoning: 'SQLite has lower long-term maintenance requirements',
      evidence: evidence,
      preference: preference,
    );
  }

  Future<DecisionCriterion> _evaluateBusinessRequirements(
    Map<String, dynamic>? businessContext,
    List<String>? specificRequirements,
  ) async {
    double score = 5.0;
    final evidence = <String>[];
    DatabaseDecision preference = DatabaseDecision.useSQLite;

    // Check specific business requirements
    if (businessContext != null) {
      final appType = businessContext['app_type'] as String?;
      final industry = businessContext['industry'] as String?;
      final complianceReqs = businessContext['compliance_requirements'] as List<String>? ?? [];

      if (appType == 'enterprise' || appType == 'business') {
        score += 1.0;
        evidence.add('Enterprise/business application context');
      }

      if (industry == 'healthcare' || industry == 'finance' || industry == 'legal') {
        score += 2.0;
        evidence.add('High-security industry: $industry');
        preference = DatabaseDecision.useSQLCipher;
      }

      if (complianceReqs.contains('GDPR') || complianceReqs.contains('HIPAA') || 
          complianceReqs.contains('SOX') || complianceReqs.contains('PCI-DSS')) {
        score += 2.0;
        evidence.add('Compliance requirements: ${complianceReqs.join(', ')}');
        preference = DatabaseDecision.useSQLCipher;
      }
    }

    // Check specific requirements
    if (specificRequirements != null) {
      if (specificRequirements.contains('audit_trail')) {
        score += 1.0;
        evidence.add('Audit trail requirements identified');
      }
      
      if (specificRequirements.contains('data_protection')) {
        score += 1.5;
        evidence.add('Data protection requirements identified');
        preference = DatabaseDecision.useSQLCipher;
      }
    }

    return DecisionCriterion(
      factor: DecisionFactor.businessRequirements,
      name: 'Business Requirements',
      description: 'Specific business and compliance requirements',
      weight: _factorWeights[DecisionFactor.businessRequirements]!,
      score: score.clamp(0.0, 10.0),
      reasoning: score >= 7.0 
        ? 'Business requirements strongly favor encryption'
        : 'Business requirements are flexible on encryption',
      evidence: evidence,
      preference: preference,
    );
  }

  Future<DecisionCriterion> _evaluateTechnicalDebt(
  ) async {
    double score = 5.0;
    final evidence = <String>[];
    DatabaseDecision preference = DatabaseDecision.useSQLite;

    // Check current implementation state
    final currentlyUsingSQLCipher = AppConstants.encryptionKey.isNotEmpty;
    
    if (currentlyUsingSQLCipher) {
      // If already using SQLCipher but having issues, consider switch
      score -= 1.0;
      evidence.add('Currently using SQLCipher - switching would require migration effort');
      preference = DatabaseDecision.useSQLCipher; // Prefer staying with current if working
    } else {
      score += 1.0;
      evidence.add('Currently using SQLite - no encryption migration needed');
    }

    // Consider existing database schema complexity
    score += 1.0;
    evidence.add('Complex CRDT schema benefits from simpler database layer');

    return DecisionCriterion(
      factor: DecisionFactor.technicalDebt,
      name: 'Technical Debt',
      description: 'Impact on existing technical debt and code complexity',
      weight: _factorWeights[DecisionFactor.technicalDebt]!,
      score: score.clamp(0.0, 10.0),
      reasoning: 'Simpler database choice reduces overall system complexity',
      evidence: evidence,
      preference: preference,
    );
  }

  Future<DecisionCriterion> _evaluateUserExperience(
    Map<String, dynamic> platformAnalysis,
  ) async {
    double score = 6.0;
    final evidence = <String>[];
    DatabaseDecision preference = DatabaseDecision.useSQLite;

    // SQLite generally provides better user experience due to:
    // - Faster initialization
    // - More reliable startup
    // - Fewer error scenarios

    evidence.add('SQLite provides more reliable database initialization');
    evidence.add('Fewer startup errors improve user experience');

    // Platform-specific UX considerations
    if (Platform.isAndroid) {
      score += 1.0;
      evidence.add('Android users benefit from reliable SQLite performance');
    }

    // Performance impact on UX
    final performanceChars = platformAnalysis['performance_characteristics'] as Map<String, dynamic>;
    if (performanceChars['startup_time'] == 'fast') {
      score += 0.5;
      evidence.add('Fast startup time improves user experience');
    }

    return DecisionCriterion(
      factor: DecisionFactor.userExperience,
      name: 'User Experience',
      description: 'Impact on user experience and application reliability',
      weight: _factorWeights[DecisionFactor.userExperience]!,
      score: score.clamp(0.0, 10.0),
      reasoning: 'SQLite provides more reliable user experience with fewer errors',
      evidence: evidence,
      preference: preference,
    );
  }

  Map<String, dynamic> _analyzeDecision(List<DecisionCriterion> criteria) {
    // Calculate weighted scores for each decision option
    final scores = <DatabaseDecision, double>{
      DatabaseDecision.useSQLCipher: 0.0,
      DatabaseDecision.useSQLite: 0.0,
      DatabaseDecision.hybridApproach: 0.0,
    };

    // Weight votes based on criterion preferences
    for (final criterion in criteria) {
      final vote = criterion.weightedScore;
      
      switch (criterion.preference) {
        case DatabaseDecision.useSQLCipher:
          scores[DatabaseDecision.useSQLCipher] = scores[DatabaseDecision.useSQLCipher]! + vote;
          break;
        case DatabaseDecision.useSQLite:
          scores[DatabaseDecision.useSQLite] = scores[DatabaseDecision.useSQLite]! + vote;
          break;
        case DatabaseDecision.hybridApproach:
          scores[DatabaseDecision.hybridApproach] = scores[DatabaseDecision.hybridApproach]! + vote;
          // Also add half weight to both options
          scores[DatabaseDecision.useSQLCipher] = scores[DatabaseDecision.useSQLCipher]! + (vote * 0.5);
          scores[DatabaseDecision.useSQLite] = scores[DatabaseDecision.useSQLite]! + (vote * 0.5);
          break;
        case DatabaseDecision.needMoreInformation:
          // Neutral - no vote
          break;
      }
    }

    // Find the winning decision
    final sortedScores = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final winningDecision = sortedScores.first.key;
    final winningScore = sortedScores.first.value;
    final totalPossibleScore = criteria.fold<double>(0.0, (sum, c) => sum + (c.weight * 10.0));
    
    final confidence = totalPossibleScore > 0 ? (winningScore / totalPossibleScore) * 100 : 0.0;

    // Generate reasoning
    final supportingCriteria = criteria
      .where((c) => c.preference == winningDecision)
      .toList();

    final reasoning = _generateDecisionReasoning(winningDecision, supportingCriteria, confidence);

    return {
      'decision': winningDecision,
      'confidence': confidence.clamp(0.0, 100.0),
      'reasoning': reasoning,
      'scores': scores,
      'supporting_criteria': supportingCriteria.length,
    };
  }

  String _generateDecisionReasoning(
    DatabaseDecision decision,
    List<DecisionCriterion> supportingCriteria,
    double confidence,
  ) {
    final platform = Platform.operatingSystem;
    final confidenceLevel = confidence >= 80 ? 'high' : confidence >= 60 ? 'medium' : 'low';
    
    String reasoning = 'Based on $platform platform analysis with $confidenceLevel confidence:\n\n';

    switch (decision) {
      case DatabaseDecision.useSQLite:
        reasoning += 'SQLite is recommended because:\n';
        reasoning += '• Better cross-platform compatibility and reliability\n';
        reasoning += '• Lower complexity for development and deployment\n';
        reasoning += '• No encryption overhead or dependency management\n';
        if (Platform.isAndroid) {
          reasoning += '• Android platform works better with standard SQLite\n';
        }
        break;

      case DatabaseDecision.useSQLCipher:
        reasoning += 'SQLCipher is recommended because:\n';
        reasoning += '• Strong security requirements identified\n';
        reasoning += '• Platform supports SQLCipher reliably\n';
        reasoning += '• Business/compliance requirements favor encryption\n';
        break;

      case DatabaseDecision.hybridApproach:
        reasoning += 'Hybrid approach is recommended because:\n';
        reasoning += '• Mixed platform compatibility results\n';
        reasoning += '• Different security needs across platforms\n';
        reasoning += '• Gradual migration strategy may be beneficial\n';
        break;

      case DatabaseDecision.needMoreInformation:
        reasoning += 'More information needed because:\n';
        reasoning += '• Conflicting requirements or test results\n';
        reasoning += '• Insufficient data for confident decision\n';
        break;
    }

    if (supportingCriteria.isNotEmpty) {
      reasoning += '\nKey supporting factors:\n';
      for (final criterion in supportingCriteria.take(3)) {
        reasoning += '• ${criterion.name}: ${criterion.reasoning}\n';
      }
    }

    return reasoning;
  }

  List<String> _generateImplementationSteps(
    DatabaseDecision decision,
    Map<String, dynamic> platformAnalysis,
  ) {
    final steps = <String>[];

    switch (decision) {
      case DatabaseDecision.useSQLite:
        steps.addAll([
          'Set AppConstants.encryptionKey to null',
          'Update PlatformDatabaseFactory to skip SQLCipher checks',
          'Test database initialization on target platforms',
          'Update error handling to remove encryption-related error paths',
          'Document the decision to use unencrypted SQLite',
        ]);
        break;

      case DatabaseDecision.useSQLCipher:
        steps.addAll([
          'Verify SQLCipher dependencies are properly included',
          'Configure proper encryption key management',
          'Test encrypted database creation on all platforms',
          'Implement key rotation strategy if needed',
          'Add encryption status monitoring',
        ]);
        break;

      case DatabaseDecision.hybridApproach:
        steps.addAll([
          'Implement platform-specific database configuration',
          'Use SQLCipher on desktop platforms',
          'Use SQLite on mobile platforms',
          'Create abstraction layer for encryption differences',
          'Test synchronization between encrypted and unencrypted databases',
        ]);
        break;

      case DatabaseDecision.needMoreInformation:
        steps.addAll([
          'Conduct additional platform compatibility testing',
          'Gather detailed security requirements',
          'Perform user experience testing with both options',
          'Analyze business compliance requirements',
          'Re-run decision framework with additional data',
        ]);
        break;
    }

    return steps;
  }

  List<String> _generateRiskMitigations(
    DatabaseDecision decision,
    List<DecisionCriterion> criteria,
  ) {
    final mitigations = <String>[];

    switch (decision) {
      case DatabaseDecision.useSQLite:
        mitigations.addAll([
          'Implement application-level data protection measures',
          'Use device-level encryption where available',
          'Implement secure data handling practices',
          'Add comprehensive audit logging',
          'Consider file-level encryption for sensitive data',
        ]);
        break;

      case DatabaseDecision.useSQLCipher:
        mitigations.addAll([
          'Implement fallback to SQLite if SQLCipher fails',
          'Add comprehensive error handling for encryption issues',
          'Test key management and recovery scenarios',
          'Monitor encryption performance impact',
          'Have migration plan ready if encryption issues arise',
        ]);
        break;

      case DatabaseDecision.hybridApproach:
        mitigations.addAll([
          'Ensure data sync works correctly between encrypted and unencrypted databases',
          'Implement consistent data validation across platforms',
          'Add platform detection and configuration management',
          'Test cross-platform data migration scenarios',
          'Monitor for platform-specific issues',
        ]);
        break;

      case DatabaseDecision.needMoreInformation:
        mitigations.addAll([
          'Implement temporary SQLite solution while gathering information',
          'Add extensive logging for decision criteria evaluation',
          'Create rollback plan for any interim solution',
          'Set timeline for final decision',
        ]);
        break;
    }

    return mitigations;
  }

  List<String> _generateAlternativeOptions(
    DatabaseDecision decision,
    List<DecisionCriterion> criteria,
  ) {
    final alternatives = <String>[];

    // Always include the other main options
    switch (decision) {
      case DatabaseDecision.useSQLite:
        alternatives.addAll([
          'Use SQLCipher with fallback to SQLite on failure',
          'Implement hybrid approach with platform-specific encryption',
          'Use external encryption service for sensitive data',
          'Implement application-level encryption for specific fields',
        ]);
        break;

      case DatabaseDecision.useSQLCipher:
        alternatives.addAll([
          'Use SQLite with application-level field encryption',
          'Implement SQLite with device-level encryption',
          'Use hybrid approach with SQLite on problematic platforms',
          'Consider alternative encrypted database solutions',
        ]);
        break;

      case DatabaseDecision.hybridApproach:
        alternatives.addAll([
          'Standardize on SQLite with field-level encryption',
          'Use SQLCipher everywhere with extensive fallback handling',
          'Implement cloud-based encryption service',
          'Use platform-native secure storage for sensitive data',
        ]);
        break;

      case DatabaseDecision.needMoreInformation:
        alternatives.addAll([
          'Proceed with current SQLite implementation',
          'Implement basic SQLCipher with extensive error handling',
          'Use temporary solution while evaluating options',
          'Conduct proof-of-concept implementations',
        ]);
        break;
    }

    return alternatives;
  }

  Map<String, dynamic> _getPerformanceCharacteristics(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return {
          'encryption_overhead': 'medium',
          'startup_time': 'medium',
          'io_performance': 'good',
          'memory_usage': 'constrained',
        };
      case 'linux':
        return {
          'encryption_overhead': 'low',
          'startup_time': 'fast',
          'io_performance': 'excellent',
          'memory_usage': 'abundant',
        };
      case 'windows':
        return {
          'encryption_overhead': 'low',
          'startup_time': 'fast',
          'io_performance': 'good',
          'memory_usage': 'good',
        };
      case 'macos':
        return {
          'encryption_overhead': 'low',
          'startup_time': 'fast',
          'io_performance': 'excellent',
          'memory_usage': 'good',
        };
      default:
        return {
          'encryption_overhead': 'unknown',
          'startup_time': 'unknown',
          'io_performance': 'unknown',
          'memory_usage': 'unknown',
        };
    }
  }

  DatabaseDecision? _getRecentDecisionForPlatform(String platform) {
    final recentDecisions = _decisionHistory.values
      .where((report) => report.platform == platform)
      .where((report) => DateTime.now().difference(report.generatedAt).inDays < 7)
      .toList();

    if (recentDecisions.isEmpty) return null;

    // Return most recent decision
    recentDecisions.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return recentDecisions.first.finalDecision;
  }

  Future<DatabaseDecision> _getDefaultDecision() async {
    // Platform-based default decisions
    if (Platform.isAndroid) {
      return DatabaseDecision.useSQLite; // Android often has SQLCipher issues
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // Check if SQLCipher is available on desktop
      try {
        final sqlcipherSupport = await PlatformDatabaseFactory.supportsSqlcipher;
        return sqlcipherSupport ? DatabaseDecision.useSQLCipher : DatabaseDecision.useSQLite;
      } catch (e) {
        return DatabaseDecision.useSQLite;
      }
    }

    return DatabaseDecision.useSQLite; // Safe default
  }

  Future<Map<String, dynamic>> _testDatabaseConnectivity() async {
    try {
      final result = await PlatformDatabaseFactory.testDatabaseConnectivity('test.db');
      return {
        'success': result,
        'test_performed': true,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'test_performed': true,
      };
    }
  }

  Future<Map<String, dynamic>> _testEncryptionStatus() async {
    return {
      'encryption_requested': AppConstants.encryptionKey.isNotEmpty,
      'encryption_working': false, // Would test actual encryption
      'sqlcipher_available': await PlatformDatabaseFactory.supportsSqlcipher,
    };
  }

  Future<Map<String, dynamic>> _testPlatformCompatibility() async {
    try {
      final dbInfo = await PlatformDatabaseFactory.getDatabaseInfo();
      return {
        'compatible': dbInfo['initialization_status'] == 'Ready',
        'platform': dbInfo['platform'],
        'database_type': dbInfo['database_type'],
      };
    } catch (e) {
      return {
        'compatible': false,
        'error': e.toString(),
      };
    }
  }
}