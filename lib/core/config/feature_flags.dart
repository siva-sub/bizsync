import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Feature flags for controlling app features
class FeatureFlags {
  static final FeatureFlags _instance = FeatureFlags._internal();
  factory FeatureFlags() => _instance;
  FeatureFlags._internal();

  SharedPreferences? _prefs;
  
  // Feature flag keys
  static const String _enableDemoDataKey = 'enable_demo_data';
  static const String _enableDebugModeKey = 'enable_debug_mode';
  static const String _enableBetaFeaturesKey = 'enable_beta_features';
  
  // Default values
  bool _enableDemoData = false;
  bool _enableDebugMode = kDebugMode;
  bool _enableBetaFeatures = false;

  /// Initialize feature flags
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFlags();
  }

  void _loadFlags() {
    if (_prefs == null) return;
    
    _enableDemoData = _prefs!.getBool(_enableDemoDataKey) ?? false;
    _enableDebugMode = _prefs!.getBool(_enableDebugModeKey) ?? kDebugMode;
    _enableBetaFeatures = _prefs!.getBool(_enableBetaFeaturesKey) ?? false;
  }

  /// Check if demo data is enabled
  bool get isDemoDataEnabled => _enableDemoData;
  
  /// Check if debug mode is enabled
  bool get isDebugModeEnabled => _enableDebugMode;
  
  /// Check if beta features are enabled
  bool get areBetaFeaturesEnabled => _enableBetaFeatures;

  /// Enable/disable demo data
  Future<void> setDemoDataEnabled(bool enabled) async {
    _enableDemoData = enabled;
    await _prefs?.setBool(_enableDemoDataKey, enabled);
  }

  /// Enable/disable debug mode
  Future<void> setDebugModeEnabled(bool enabled) async {
    _enableDebugMode = enabled;
    await _prefs?.setBool(_enableDebugModeKey, enabled);
  }

  /// Enable/disable beta features
  Future<void> setBetaFeaturesEnabled(bool enabled) async {
    _enableBetaFeatures = enabled;
    await _prefs?.setBool(_enableBetaFeaturesKey, enabled);
  }

  /// Check if we should show demo data banner
  bool get shouldShowDemoDataBanner => _enableDemoData && !kReleaseMode;

  /// Reset all flags to defaults
  Future<void> resetToDefaults() async {
    await setDemoDataEnabled(false);
    await setDebugModeEnabled(kDebugMode);
    await setBetaFeaturesEnabled(false);
  }
}