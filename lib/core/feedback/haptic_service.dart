import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Haptic feedback types
enum HapticFeedbackType {
  light,
  medium,
  heavy,
  selection,
  success,
  warning,
  error,
  impact,
  notification,
}

// Haptic feedback patterns
class HapticPattern {
  final List<int> pattern;
  final List<int> intensities;

  const HapticPattern({
    required this.pattern,
    required this.intensities,
  });

  static const success = HapticPattern(
    pattern: [0, 100, 50, 100],
    intensities: [0, 128, 0, 255],
  );

  static const error = HapticPattern(
    pattern: [0, 200, 100, 200, 100, 200],
    intensities: [0, 255, 0, 255, 0, 255],
  );

  static const warning = HapticPattern(
    pattern: [0, 150, 75, 150],
    intensities: [0, 200, 0, 200],
  );

  static const notification = HapticPattern(
    pattern: [0, 50, 50, 100],
    intensities: [0, 128, 0, 200],
  );

  static const doubleClick = HapticPattern(
    pattern: [0, 50, 100, 50],
    intensities: [0, 128, 0, 128],
  );

  static const longPress = HapticPattern(
    pattern: [0, 300],
    intensities: [0, 180],
  );
}

// Haptic feedback configuration
class HapticConfig {
  final bool enabled;
  final bool enableForButtons;
  final bool enableForGestures;
  final bool enableForNotifications;
  final bool enableForErrors;
  final double intensity;

  const HapticConfig({
    this.enabled = true,
    this.enableForButtons = true,
    this.enableForGestures = true,
    this.enableForNotifications = true,
    this.enableForErrors = true,
    this.intensity = 1.0,
  });

  HapticConfig copyWith({
    bool? enabled,
    bool? enableForButtons,
    bool? enableForGestures,
    bool? enableForNotifications,
    bool? enableForErrors,
    double? intensity,
  }) {
    return HapticConfig(
      enabled: enabled ?? this.enabled,
      enableForButtons: enableForButtons ?? this.enableForButtons,
      enableForGestures: enableForGestures ?? this.enableForGestures,
      enableForNotifications: enableForNotifications ?? this.enableForNotifications,
      enableForErrors: enableForErrors ?? this.enableForErrors,
      intensity: intensity ?? this.intensity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'enableForButtons': enableForButtons,
      'enableForGestures': enableForGestures,
      'enableForNotifications': enableForNotifications,
      'enableForErrors': enableForErrors,
      'intensity': intensity,
    };
  }

  static HapticConfig fromJson(Map<String, dynamic> json) {
    return HapticConfig(
      enabled: json['enabled'] ?? true,
      enableForButtons: json['enableForButtons'] ?? true,
      enableForGestures: json['enableForGestures'] ?? true,
      enableForNotifications: json['enableForNotifications'] ?? true,
      enableForErrors: json['enableForErrors'] ?? true,
      intensity: (json['intensity'] ?? 1.0).toDouble(),
    );
  }
}

// Haptic feedback service
class HapticService extends ChangeNotifier {
  static const String _configKey = 'haptic_config';
  
  HapticConfig _config = const HapticConfig();
  SharedPreferences? _prefs;
  bool _hasVibration = false;

  HapticConfig get config => _config;
  bool get hasVibration => _hasVibration;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadConfig();
    await _checkVibrationCapabilities();
  }

  Future<void> _loadConfig() async {
    if (_prefs == null) return;
    
    final configJson = _prefs!.getString(_configKey);
    if (configJson != null) {
      try {
        final Map<String, dynamic> data = _parseJson(configJson);
        _config = HapticConfig.fromJson(data);
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading haptic config: $e');
      }
    }
  }

  Future<void> _saveConfig() async {
    if (_prefs == null) return;
    
    try {
      final configJson = _stringifyJson(_config.toJson());
      await _prefs!.setString(_configKey, configJson);
    } catch (e) {
      debugPrint('Error saving haptic config: $e');
    }
  }

  Future<void> _checkVibrationCapabilities() async {
    try {
      _hasVibration = await Vibration.hasVibrator() ?? false;
      debugPrint('Device has vibration support: $_hasVibration');
    } catch (e) {
      debugPrint('Error checking vibration capabilities: $e');
      _hasVibration = false;
    }
  }

  Future<void> updateConfig(HapticConfig newConfig) async {
    _config = newConfig;
    await _saveConfig();
    notifyListeners();
  }

  // Main haptic feedback method
  Future<void> provideFeedback(HapticFeedbackType type, {String? context}) async {
    if (!_config.enabled || !_hasVibration) return;

    // Check context-specific settings
    switch (context) {
      case 'button':
        if (!_config.enableForButtons) return;
        break;
      case 'gesture':
        if (!_config.enableForGestures) return;
        break;
      case 'notification':
        if (!_config.enableForNotifications) return;
        break;
      case 'error':
        if (!_config.enableForErrors) return;
        break;
    }

    try {
      switch (type) {
        case HapticFeedbackType.light:
          await _triggerLightFeedback();
          break;
        case HapticFeedbackType.medium:
          await _triggerMediumFeedback();
          break;
        case HapticFeedbackType.heavy:
          await _triggerHeavyFeedback();
          break;
        case HapticFeedbackType.selection:
          await _triggerSelectionFeedback();
          break;
        case HapticFeedbackType.success:
          await _triggerPatternFeedback(HapticPattern.success);
          break;
        case HapticFeedbackType.warning:
          await _triggerPatternFeedback(HapticPattern.warning);
          break;
        case HapticFeedbackType.error:
          await _triggerPatternFeedback(HapticPattern.error);
          break;
        case HapticFeedbackType.impact:
          await _triggerImpactFeedback();
          break;
        case HapticFeedbackType.notification:
          await _triggerPatternFeedback(HapticPattern.notification);
          break;
      }
    } catch (e) {
      debugPrint('Error providing haptic feedback: $e');
    }
  }

  Future<void> _triggerLightFeedback() async {
    HapticFeedback.lightImpact();
    if (await Vibration.hasCustomVibrationsSupport() ?? false) {
      final duration = (50 * _config.intensity).round();
      await Vibration.vibrate(duration: duration);
    }
  }

  Future<void> _triggerMediumFeedback() async {
    HapticFeedback.mediumImpact();
    if (await Vibration.hasCustomVibrationsSupport() ?? false) {
      final duration = (100 * _config.intensity).round();
      await Vibration.vibrate(duration: duration);
    }
  }

  Future<void> _triggerHeavyFeedback() async {
    HapticFeedback.heavyImpact();
    if (await Vibration.hasCustomVibrationsSupport() ?? false) {
      final duration = (200 * _config.intensity).round();
      await Vibration.vibrate(duration: duration);
    }
  }

  Future<void> _triggerSelectionFeedback() async {
    HapticFeedback.selectionClick();
    if (await Vibration.hasCustomVibrationsSupport() ?? false) {
      final duration = (25 * _config.intensity).round();
      await Vibration.vibrate(duration: duration);
    }
  }

  Future<void> _triggerImpactFeedback() async {
    HapticFeedback.vibrate();
    if (await Vibration.hasCustomVibrationsSupport() ?? false) {
      final duration = (150 * _config.intensity).round();
      await Vibration.vibrate(duration: duration);
    }
  }

  Future<void> _triggerPatternFeedback(HapticPattern pattern) async {
    if (await Vibration.hasCustomVibrationsSupport() ?? false) {
      // Adjust pattern intensity
      final adjustedPattern = pattern.pattern
          .map((duration) => (duration * _config.intensity).round())
          .toList();
      
      final adjustedIntensities = pattern.intensities
          .map((intensity) => (intensity * _config.intensity).round())
          .toList();

      await Vibration.vibrate(
        pattern: adjustedPattern,
        intensities: adjustedIntensities,
      );
    } else {
      // Fallback to simple vibration
      final totalDuration = pattern.pattern
          .where((duration) => duration > 0)
          .fold(0, (sum, duration) => sum + duration);
      
      if (totalDuration > 0) {
        await Vibration.vibrate(
          duration: (totalDuration * _config.intensity).round(),
        );
      }
    }
  }

  // Convenience methods for common UI interactions
  Future<void> buttonTap() async {
    await provideFeedback(HapticFeedbackType.light, context: 'button');
  }

  Future<void> buttonPress() async {
    await provideFeedback(HapticFeedbackType.medium, context: 'button');
  }

  Future<void> swipeGesture() async {
    await provideFeedback(HapticFeedbackType.selection, context: 'gesture');
  }

  Future<void> longPress() async {
    await _triggerPatternFeedback(HapticPattern.longPress);
  }

  Future<void> doubleClick() async {
    await _triggerPatternFeedback(HapticPattern.doubleClick);
  }

  Future<void> successAction() async {
    await provideFeedback(HapticFeedbackType.success);
  }

  Future<void> errorAction() async {
    await provideFeedback(HapticFeedbackType.error, context: 'error');
  }

  Future<void> warningAction() async {
    await provideFeedback(HapticFeedbackType.warning);
  }

  Future<void> notificationReceived() async {
    await provideFeedback(HapticFeedbackType.notification, context: 'notification');
  }

  Future<void> dataSync() async {
    await provideFeedback(HapticFeedbackType.medium);
  }

  Future<void> itemDeleted() async {
    await provideFeedback(HapticFeedbackType.heavy);
  }

  Future<void> itemAdded() async {
    await provideFeedback(HapticFeedbackType.light);
  }

  Future<void> paymentSuccess() async {
    await provideFeedback(HapticFeedbackType.success);
  }

  Future<void> paymentFailed() async {
    await provideFeedback(HapticFeedbackType.error, context: 'error');
  }

  // Simple JSON parsing methods
  Map<String, dynamic> _parseJson(String jsonString) {
    final Map<String, dynamic> result = {};
    
    final content = jsonString.replaceAll(RegExp(r'[{}"]'), '');
    final pairs = content.split(',');
    
    for (final pair in pairs) {
      final keyValue = pair.split(':');
      if (keyValue.length == 2) {
        final key = keyValue[0].trim();
        final value = keyValue[1].trim();
        
        if (value == 'true') {
          result[key] = true;
        } else if (value == 'false') {
          result[key] = false;
        } else if (value == 'null') {
          result[key] = null;
        } else if (double.tryParse(value) != null) {
          result[key] = double.parse(value);
        } else if (int.tryParse(value) != null) {
          result[key] = int.parse(value);
        } else {
          result[key] = value;
        }
      }
    }
    
    return result;
  }

  String _stringifyJson(Map<String, dynamic> data) {
    final List<String> pairs = [];
    
    data.forEach((key, value) {
      String valueStr;
      if (value == null) {
        valueStr = 'null';
      } else if (value is bool) {
        valueStr = value.toString();
      } else if (value is num) {
        valueStr = value.toString();
      } else {
        valueStr = '"$value"';
      }
      pairs.add('"$key":$valueStr');
    });
    
    return '{${pairs.join(',')}}';
  }
}

// Riverpod providers for haptic service
final hapticServiceProvider = Provider<HapticService>((ref) {
  final service = HapticService();
  service.initialize();
  return service;
});

final hapticConfigProvider = StateNotifierProvider<HapticConfigNotifier, HapticConfig>((ref) {
  final service = ref.watch(hapticServiceProvider);
  return HapticConfigNotifier(service);
});

class HapticConfigNotifier extends StateNotifier<HapticConfig> {
  final HapticService _service;

  HapticConfigNotifier(this._service) : super(_service.config) {
    _service.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    state = _service.config;
  }

  Future<void> updateConfig(HapticConfig config) async {
    await _service.updateConfig(config);
  }

  Future<void> toggleEnabled() async {
    await updateConfig(state.copyWith(enabled: !state.enabled));
  }

  Future<void> toggleButtons() async {
    await updateConfig(state.copyWith(enableForButtons: !state.enableForButtons));
  }

  Future<void> toggleGestures() async {
    await updateConfig(state.copyWith(enableForGestures: !state.enableForGestures));
  }

  Future<void> toggleNotifications() async {
    await updateConfig(state.copyWith(enableForNotifications: !state.enableForNotifications));
  }

  Future<void> toggleErrors() async {
    await updateConfig(state.copyWith(enableForErrors: !state.enableForErrors));
  }

  Future<void> setIntensity(double intensity) async {
    await updateConfig(state.copyWith(intensity: intensity.clamp(0.0, 1.0)));
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }
}