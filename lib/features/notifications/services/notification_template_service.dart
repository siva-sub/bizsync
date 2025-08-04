import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/notification_template.dart';
import '../models/notification_types.dart';
import '../models/notification_models.dart';

/// Service for managing notification templates
class NotificationTemplateService {
  static final NotificationTemplateService _instance =
      NotificationTemplateService._internal();
  factory NotificationTemplateService() => _instance;
  NotificationTemplateService._internal();

  final _uuid = const Uuid();
  final List<NotificationTemplate> _customTemplates = [];
  bool _initialized = false;

  /// Initialize the template service
  Future<void> initialize() async {
    if (_initialized) return;

    await _loadCustomTemplates();
    _initialized = true;
  }

  /// Get all available templates (default + custom)
  List<NotificationTemplate> getAllTemplates() {
    return [
      ...NotificationTemplates.defaultTemplates
          .map((template) => template.copyWith(createdAt: DateTime.now())),
      ..._customTemplates,
    ];
  }

  /// Get templates by category
  List<NotificationTemplate> getTemplatesByCategory(
      NotificationCategory category) {
    return getAllTemplates()
        .where((template) => template.category == category)
        .toList();
  }

  /// Get templates by business type
  List<NotificationTemplate> getTemplatesByType(BusinessNotificationType type) {
    return getAllTemplates()
        .where((template) => template.type == type)
        .toList();
  }

  /// Get template by ID
  NotificationTemplate? getTemplate(String id) {
    try {
      return getAllTemplates().firstWhere((template) => template.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Create custom template
  Future<NotificationTemplate> createCustomTemplate({
    required String name,
    required String description,
    required BusinessNotificationType type,
    required NotificationCategory category,
    NotificationPriority priority = NotificationPriority.medium,
    required NotificationChannel channel,
    required String titleTemplate,
    required String bodyTemplate,
    String? bigTextTemplate,
    NotificationStyle style = NotificationStyle.basic,
    List<NotificationAction>? actions,
    Map<String, dynamic>? defaultPayload,
    List<String> requiredVariables = const [],
    String? imageUrl,
    String? largeIcon,
    bool persistent = false,
    bool autoCancel = true,
    int? timeoutMs,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_initialized) await initialize();

    final template = NotificationTemplate(
      id: _uuid.v4(),
      name: name,
      description: description,
      type: type,
      category: category,
      priority: priority,
      channel: channel,
      titleTemplate: titleTemplate,
      bodyTemplate: bodyTemplate,
      bigTextTemplate: bigTextTemplate,
      style: style,
      actions: actions,
      defaultPayload: defaultPayload,
      requiredVariables: requiredVariables,
      enabled: true,
      createdAt: DateTime.now(),
      imageUrl: imageUrl,
      largeIcon: largeIcon,
      persistent: persistent,
      autoCancel: autoCancel,
      timeoutMs: timeoutMs,
      metadata: metadata,
    );

    _customTemplates.add(template);
    await _saveCustomTemplates();

    return template;
  }

  /// Update custom template
  Future<NotificationTemplate?> updateCustomTemplate({
    required String id,
    String? name,
    String? description,
    BusinessNotificationType? type,
    NotificationCategory? category,
    NotificationPriority? priority,
    NotificationChannel? channel,
    String? titleTemplate,
    String? bodyTemplate,
    String? bigTextTemplate,
    NotificationStyle? style,
    List<NotificationAction>? actions,
    Map<String, dynamic>? defaultPayload,
    List<String>? requiredVariables,
    bool? enabled,
    String? imageUrl,
    String? largeIcon,
    bool? persistent,
    bool? autoCancel,
    int? timeoutMs,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_initialized) await initialize();

    final index = _customTemplates.indexWhere((t) => t.id == id);
    if (index == -1) return null;

    final existingTemplate = _customTemplates[index];
    final updatedTemplate = NotificationTemplate(
      id: existingTemplate.id,
      name: name ?? existingTemplate.name,
      description: description ?? existingTemplate.description,
      type: type ?? existingTemplate.type,
      category: category ?? existingTemplate.category,
      priority: priority ?? existingTemplate.priority,
      channel: channel ?? existingTemplate.channel,
      titleTemplate: titleTemplate ?? existingTemplate.titleTemplate,
      bodyTemplate: bodyTemplate ?? existingTemplate.bodyTemplate,
      bigTextTemplate: bigTextTemplate ?? existingTemplate.bigTextTemplate,
      style: style ?? existingTemplate.style,
      actions: actions ?? existingTemplate.actions,
      defaultPayload: defaultPayload ?? existingTemplate.defaultPayload,
      requiredVariables:
          requiredVariables ?? existingTemplate.requiredVariables,
      enabled: enabled ?? existingTemplate.enabled,
      createdAt: existingTemplate.createdAt,
      updatedAt: DateTime.now(),
      imageUrl: imageUrl ?? existingTemplate.imageUrl,
      largeIcon: largeIcon ?? existingTemplate.largeIcon,
      persistent: persistent ?? existingTemplate.persistent,
      autoCancel: autoCancel ?? existingTemplate.autoCancel,
      timeoutMs: timeoutMs ?? existingTemplate.timeoutMs,
      metadata: metadata ?? existingTemplate.metadata,
    );

    _customTemplates[index] = updatedTemplate;
    await _saveCustomTemplates();

    return updatedTemplate;
  }

  /// Delete custom template
  Future<bool> deleteCustomTemplate(String id) async {
    if (!_initialized) await initialize();

    final lengthBefore = _customTemplates.length;
    _customTemplates.removeWhere((t) => t.id == id);
    final removed = lengthBefore - _customTemplates.length;
    if (removed > 0) {
      await _saveCustomTemplates();
      return true;
    }
    return false;
  }

  /// Generate notification from template
  Future<BizSyncNotification?> generateNotification({
    required String templateId,
    required Map<String, dynamic> variables,
    DateTime? scheduledFor,
    Map<String, dynamic>? additionalPayload,
    String? customId,
  }) async {
    if (!_initialized) await initialize();

    final template = getTemplate(templateId);
    if (template == null) return null;

    // Validate required variables
    if (!template.validateVariables(variables)) {
      throw ArgumentError(
          'Missing required variables: ${template.getMissingVariables(variables).join(', ')}');
    }

    return BizSyncNotification(
      id: customId ?? _uuid.v4(),
      title: template.generateTitle(variables),
      body: template.generateBody(variables),
      type: template.type,
      category: template.category,
      priority: template.priority,
      channel: template.channel,
      createdAt: DateTime.now(),
      scheduledFor: scheduledFor,
      payload: {
        ...?template.defaultPayload,
        ...?additionalPayload,
        'templateId': templateId,
        'variables': variables,
      },
      actions: template.actions,
      bigText: template.generateBigText(variables),
      style: template.style,
      persistent: template.persistent,
      autoCancel: template.autoCancel,
      imageUrl: template.imageUrl,
      largeIcon: template.largeIcon,
      metadata: template.metadata,
    );
  }

  /// Preview notification from template
  NotificationPreview previewNotification({
    required String templateId,
    required Map<String, dynamic> variables,
  }) {
    final template = getTemplate(templateId);
    if (template == null) {
      return NotificationPreview(
        success: false,
        error: 'Template not found: $templateId',
      );
    }

    // Check for missing variables
    final missingVariables = template.getMissingVariables(variables);
    if (missingVariables.isNotEmpty) {
      return NotificationPreview(
        success: false,
        error: 'Missing required variables: ${missingVariables.join(', ')}',
        missingVariables: missingVariables,
      );
    }

    return NotificationPreview(
      success: true,
      title: template.generateTitle(variables),
      body: template.generateBody(variables),
      bigText: template.generateBigText(variables),
      style: template.style,
      actions: template.actions,
      priority: template.priority,
      category: template.category,
    );
  }

  /// Clone template (useful for creating variations)
  Future<NotificationTemplate> cloneTemplate({
    required String templateId,
    String? newName,
    Map<String, dynamic>? modifications,
  }) async {
    if (!_initialized) await initialize();

    final originalTemplate = getTemplate(templateId);
    if (originalTemplate == null) {
      throw ArgumentError('Template not found: $templateId');
    }

    final clonedTemplate = NotificationTemplate(
      id: _uuid.v4(),
      name: newName ?? '${originalTemplate.name} (Copy)',
      description: originalTemplate.description,
      type: originalTemplate.type,
      category: originalTemplate.category,
      priority: originalTemplate.priority,
      channel: originalTemplate.channel,
      titleTemplate: originalTemplate.titleTemplate,
      bodyTemplate: originalTemplate.bodyTemplate,
      bigTextTemplate: originalTemplate.bigTextTemplate,
      style: originalTemplate.style,
      actions: originalTemplate.actions,
      defaultPayload: originalTemplate.defaultPayload,
      requiredVariables: originalTemplate.requiredVariables,
      enabled: originalTemplate.enabled,
      createdAt: DateTime.now(),
      imageUrl: originalTemplate.imageUrl,
      largeIcon: originalTemplate.largeIcon,
      persistent: originalTemplate.persistent,
      autoCancel: originalTemplate.autoCancel,
      timeoutMs: originalTemplate.timeoutMs,
      metadata: {
        ...?originalTemplate.metadata,
        'clonedFrom': templateId,
        'clonedAt': DateTime.now().toIso8601String(),
      },
    );

    _customTemplates.add(clonedTemplate);
    await _saveCustomTemplates();

    return clonedTemplate;
  }

  /// Get template usage statistics
  Future<TemplateUsageStats> getTemplateUsageStats(String templateId) async {
    final prefs = await SharedPreferences.getInstance();
    final usageData = prefs.getString('template_usage_$templateId');

    if (usageData != null) {
      try {
        final data = jsonDecode(usageData) as Map<String, dynamic>;
        return TemplateUsageStats.fromJson(data);
      } catch (e) {
        // Return empty stats if parsing fails
      }
    }

    return TemplateUsageStats(
      templateId: templateId,
      totalUsage: 0,
      lastUsed: null,
      averageEngagement: 0.0,
      createdAt: DateTime.now(),
    );
  }

  /// Record template usage
  Future<void> recordTemplateUsage({
    required String templateId,
    double? engagementScore,
  }) async {
    final stats = await getTemplateUsageStats(templateId);

    final updatedStats = TemplateUsageStats(
      templateId: templateId,
      totalUsage: stats.totalUsage + 1,
      lastUsed: DateTime.now(),
      averageEngagement: engagementScore != null
          ? ((stats.averageEngagement * stats.totalUsage) + engagementScore) /
              (stats.totalUsage + 1)
          : stats.averageEngagement,
      createdAt: stats.createdAt,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'template_usage_$templateId',
      jsonEncode(updatedStats.toJson()),
    );
  }

  /// Get popular templates based on usage
  Future<List<NotificationTemplate>> getPopularTemplates(
      {int limit = 10}) async {
    final templates = getAllTemplates();
    final templatesWithStats = <TemplateWithStats>[];

    for (final template in templates) {
      final stats = await getTemplateUsageStats(template.id);
      templatesWithStats.add(TemplateWithStats(template, stats));
    }

    // Sort by usage and engagement
    templatesWithStats.sort((a, b) {
      final aScore = a.stats.totalUsage * a.stats.averageEngagement;
      final bScore = b.stats.totalUsage * b.stats.averageEngagement;
      return bScore.compareTo(aScore);
    });

    return templatesWithStats.take(limit).map((item) => item.template).toList();
  }

  /// Export templates to JSON
  Future<Map<String, dynamic>> exportTemplates({
    bool includeDefaultTemplates = false,
    List<String>? templateIds,
  }) async {
    if (!_initialized) await initialize();

    List<NotificationTemplate> templatesToExport;

    if (templateIds != null) {
      templatesToExport =
          getAllTemplates().where((t) => templateIds.contains(t.id)).toList();
    } else if (includeDefaultTemplates) {
      templatesToExport = getAllTemplates();
    } else {
      templatesToExport = _customTemplates;
    }

    return {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'templates': templatesToExport.map((t) => t.toJson()).toList(),
    };
  }

  /// Import templates from JSON
  Future<ImportResult> importTemplates(Map<String, dynamic> data) async {
    if (!_initialized) await initialize();

    try {
      final templates = data['templates'] as List;
      final importedTemplates = <NotificationTemplate>[];
      final errors = <String>[];

      for (final templateData in templates) {
        try {
          final template = NotificationTemplate.fromJson(
              templateData as Map<String, dynamic>);

          // Generate new ID to avoid conflicts
          final importedTemplate = NotificationTemplate(
            id: _uuid.v4(),
            name: '${template.name} (Imported)',
            description: template.description,
            type: template.type,
            category: template.category,
            priority: template.priority,
            channel: template.channel,
            titleTemplate: template.titleTemplate,
            bodyTemplate: template.bodyTemplate,
            bigTextTemplate: template.bigTextTemplate,
            style: template.style,
            actions: template.actions,
            defaultPayload: template.defaultPayload,
            requiredVariables: template.requiredVariables,
            enabled: template.enabled,
            createdAt: DateTime.now(),
            imageUrl: template.imageUrl,
            largeIcon: template.largeIcon,
            persistent: template.persistent,
            autoCancel: template.autoCancel,
            timeoutMs: template.timeoutMs,
            metadata: {
              ...?template.metadata,
              'importedAt': DateTime.now().toIso8601String(),
              'originalId': template.id,
            },
          );

          _customTemplates.add(importedTemplate);
          importedTemplates.add(importedTemplate);
        } catch (e) {
          errors.add('Failed to import template: $e');
        }
      }

      if (importedTemplates.isNotEmpty) {
        await _saveCustomTemplates();
      }

      return ImportResult(
        success: true,
        importedCount: importedTemplates.length,
        totalCount: templates.length,
        errors: errors,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        importedCount: 0,
        totalCount: 0,
        errors: ['Failed to parse import data: $e'],
      );
    }
  }

  /// Load custom templates from storage
  Future<void> _loadCustomTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final templatesJson =
        prefs.getStringList('custom_notification_templates') ?? [];

    _customTemplates.clear();
    for (final templateJson in templatesJson) {
      try {
        final templateData = jsonDecode(templateJson) as Map<String, dynamic>;
        final template = NotificationTemplate.fromJson(templateData);
        _customTemplates.add(template);
      } catch (e) {
        // Skip malformed template data
        continue;
      }
    }
  }

  /// Save custom templates to storage
  Future<void> _saveCustomTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final templatesJson = _customTemplates
        .map((template) => jsonEncode(template.toJson()))
        .toList();
    await prefs.setStringList('custom_notification_templates', templatesJson);
  }

  /// Clear all custom templates
  Future<void> clearCustomTemplates() async {
    _customTemplates.clear();
    await _saveCustomTemplates();
  }

  /// Get template count by category
  Map<NotificationCategory, int> getTemplateCounts() {
    final counts = <NotificationCategory, int>{};

    for (final category in NotificationCategory.values) {
      counts[category] = getTemplatesByCategory(category).length;
    }

    return counts;
  }
}

/// Helper classes for template service

class NotificationPreview {
  final bool success;
  final String? error;
  final List<String>? missingVariables;
  final String? title;
  final String? body;
  final String? bigText;
  final NotificationStyle? style;
  final List<NotificationAction>? actions;
  final NotificationPriority? priority;
  final NotificationCategory? category;

  const NotificationPreview({
    required this.success,
    this.error,
    this.missingVariables,
    this.title,
    this.body,
    this.bigText,
    this.style,
    this.actions,
    this.priority,
    this.category,
  });
}

class TemplateUsageStats {
  final String templateId;
  final int totalUsage;
  final DateTime? lastUsed;
  final double averageEngagement;
  final DateTime createdAt;

  const TemplateUsageStats({
    required this.templateId,
    required this.totalUsage,
    this.lastUsed,
    required this.averageEngagement,
    required this.createdAt,
  });

  factory TemplateUsageStats.fromJson(Map<String, dynamic> json) {
    return TemplateUsageStats(
      templateId: json['templateId'] as String,
      totalUsage: json['totalUsage'] as int,
      lastUsed: json['lastUsed'] != null
          ? DateTime.parse(json['lastUsed'] as String)
          : null,
      averageEngagement: (json['averageEngagement'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'templateId': templateId,
      'totalUsage': totalUsage,
      'lastUsed': lastUsed?.toIso8601String(),
      'averageEngagement': averageEngagement,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class TemplateWithStats {
  final NotificationTemplate template;
  final TemplateUsageStats stats;

  const TemplateWithStats(this.template, this.stats);
}

class ImportResult {
  final bool success;
  final int importedCount;
  final int totalCount;
  final List<String> errors;

  const ImportResult({
    required this.success,
    required this.importedCount,
    required this.totalCount,
    required this.errors,
  });
}

/// Extension to add copyWith method to NotificationTemplate
extension NotificationTemplateExtension on NotificationTemplate {
  NotificationTemplate copyWith({
    String? id,
    String? name,
    String? description,
    BusinessNotificationType? type,
    NotificationCategory? category,
    NotificationPriority? priority,
    NotificationChannel? channel,
    String? titleTemplate,
    String? bodyTemplate,
    String? bigTextTemplate,
    NotificationStyle? style,
    List<NotificationAction>? actions,
    Map<String, dynamic>? defaultPayload,
    List<String>? requiredVariables,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imageUrl,
    String? largeIcon,
    bool? persistent,
    bool? autoCancel,
    int? timeoutMs,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      channel: channel ?? this.channel,
      titleTemplate: titleTemplate ?? this.titleTemplate,
      bodyTemplate: bodyTemplate ?? this.bodyTemplate,
      bigTextTemplate: bigTextTemplate ?? this.bigTextTemplate,
      style: style ?? this.style,
      actions: actions ?? this.actions,
      defaultPayload: defaultPayload ?? this.defaultPayload,
      requiredVariables: requiredVariables ?? this.requiredVariables,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      largeIcon: largeIcon ?? this.largeIcon,
      persistent: persistent ?? this.persistent,
      autoCancel: autoCancel ?? this.autoCancel,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      metadata: metadata ?? this.metadata,
    );
  }
}
