import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dashboard_models.dart';

/// Offline caching service for dashboard data
class OfflineCacheService {
  static const String _cachePrefix = 'dashboard_cache_';
  static const String _lastUpdateKey = 'dashboard_last_update';
  static const String _cacheVersionKey = 'dashboard_cache_version';
  static const int _currentCacheVersion = 1;
  static const Duration _cacheExpiryDuration = Duration(hours: 6);

  late SharedPreferences _prefs;
  late Directory _cacheDirectory;
  bool _isInitialized = false;

  /// Initialize the cache service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    _cacheDirectory = await _getCacheDirectory();
    
    // Check cache version and clear if outdated
    await _checkCacheVersion();
    
    _isInitialized = true;
  }

  /// Get cache directory
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/dashboard_cache');
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }

  /// Check and update cache version
  Future<void> _checkCacheVersion() async {
    final currentVersion = _prefs.getInt(_cacheVersionKey) ?? 0;
    
    if (currentVersion < _currentCacheVersion) {
      await clearAllCache();
      await _prefs.setInt(_cacheVersionKey, _currentCacheVersion);
    }
  }

  /// Cache dashboard data
  Future<void> cacheDashboardData(
    DashboardData data,
    TimePeriod period,
  ) async {
    await _ensureInitialized();
    
    try {
      final cacheKey = _getCacheKey('dashboard_data', period);
      final jsonData = json.encode(data.toJson());
      
      // Save to file for large data
      final file = File('${_cacheDirectory.path}/$cacheKey.json');
      await file.writeAsString(jsonData);
      
      // Save metadata to SharedPreferences
      await _prefs.setString('${cacheKey}_timestamp', DateTime.now().toIso8601String());
      await _prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
      
      // Update cache index
      await _updateCacheIndex(cacheKey);
      
    } catch (e) {
      throw CacheException('Failed to cache dashboard data: $e');
    }
  }

  /// Retrieve cached dashboard data
  Future<DashboardData?> getCachedDashboardData(TimePeriod period) async {
    await _ensureInitialized();
    
    try {
      final cacheKey = _getCacheKey('dashboard_data', period);
      final file = File('${_cacheDirectory.path}/$cacheKey.json');
      
      if (!await file.exists()) {
        return null;
      }
      
      // Check if cache is expired
      if (await _isCacheExpired(cacheKey)) {
        await _removeFromCache(cacheKey);
        return null;
      }
      
      final jsonString = await file.readAsString();
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      
      return DashboardData.fromJson(jsonData);
      
    } catch (e) {
      // If cache is corrupted, remove it
      await _removeFromCache(_getCacheKey('dashboard_data', period));
      return null;
    }
  }

  /// Cache KPIs data
  Future<void> cacheKPIs(List<KPI> kpis, TimePeriod period) async {
    await _ensureInitialized();
    
    try {
      final cacheKey = _getCacheKey('kpis', period);
      final jsonData = json.encode(kpis.map((kpi) => kpi.toJson()).toList());
      
      await _prefs.setString(cacheKey, jsonData);
      await _prefs.setString('${cacheKey}_timestamp', DateTime.now().toIso8601String());
      
      await _updateCacheIndex(cacheKey);
      
    } catch (e) {
      throw CacheException('Failed to cache KPIs: $e');
    }
  }

  /// Retrieve cached KPIs
  Future<List<KPI>?> getCachedKPIs(TimePeriod period) async {
    await _ensureInitialized();
    
    final cacheKey = _getCacheKey('kpis', period);
    
    try {
      if (await _isCacheExpired(cacheKey)) {
        await _removeFromCache(cacheKey);
        return null;
      }
      
      final jsonString = _prefs.getString(cacheKey);
      if (jsonString == null) return null;
      
      final jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList.map((json) => KPI.fromJson(json as Map<String, dynamic>)).toList();
      
    } catch (e) {
      await _removeFromCache(cacheKey);
      return null;
    }
  }

  /// Cache revenue analytics
  Future<void> cacheRevenueAnalytics(RevenueAnalytics analytics, TimePeriod period) async {
    await _ensureInitialized();
    
    try {
      final cacheKey = _getCacheKey('revenue_analytics', period);
      final jsonData = json.encode(analytics.toJson());
      
      final file = File('${_cacheDirectory.path}/$cacheKey.json');
      await file.writeAsString(jsonData);
      
      await _prefs.setString('${cacheKey}_timestamp', DateTime.now().toIso8601String());
      await _updateCacheIndex(cacheKey);
      
    } catch (e) {
      throw CacheException('Failed to cache revenue analytics: $e');
    }
  }

  /// Retrieve cached revenue analytics
  Future<RevenueAnalytics?> getCachedRevenueAnalytics(TimePeriod period) async {
    await _ensureInitialized();
    
    final cacheKey = _getCacheKey('revenue_analytics', period);
    
    try {
      final file = File('${_cacheDirectory.path}/$cacheKey.json');
      
      if (!await file.exists() || await _isCacheExpired(cacheKey)) {
        await _removeFromCache(cacheKey);
        return null;
      }
      
      final jsonString = await file.readAsString();
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      
      return RevenueAnalytics.fromJson(jsonData);
      
    } catch (e) {
      await _removeFromCache(cacheKey);
      return null;
    }
  }

  /// Cache cash flow data
  Future<void> cacheCashFlowData(CashFlowData data, TimePeriod period) async {
    await _ensureInitialized();
    
    try {
      final cacheKey = _getCacheKey('cash_flow', period);
      final jsonData = json.encode(data.toJson());
      
      final file = File('${_cacheDirectory.path}/$cacheKey.json');
      await file.writeAsString(jsonData);
      
      await _prefs.setString('${cacheKey}_timestamp', DateTime.now().toIso8601String());
      await _updateCacheIndex(cacheKey);
      
    } catch (e) {
      throw CacheException('Failed to cache cash flow data: $e');
    }
  }

  /// Retrieve cached cash flow data
  Future<CashFlowData?> getCachedCashFlowData(TimePeriod period) async {
    await _ensureInitialized();
    
    final cacheKey = _getCacheKey('cash_flow', period);
    
    try {
      final file = File('${_cacheDirectory.path}/$cacheKey.json');
      
      if (!await file.exists() || await _isCacheExpired(cacheKey)) {
        await _removeFromCache(cacheKey);
        return null;
      }
      
      final jsonString = await file.readAsString();
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      
      return CashFlowData.fromJson(jsonData);
      
    } catch (e) {
      await _removeFromCache(cacheKey);
      return null;
    }
  }

  /// Cache customer insights
  Future<void> cacheCustomerInsights(CustomerInsights insights, TimePeriod period) async {
    await _ensureInitialized();
    
    try {
      final cacheKey = _getCacheKey('customer_insights', period);
      final jsonData = json.encode(insights.toJson());
      
      final file = File('${_cacheDirectory.path}/$cacheKey.json');
      await file.writeAsString(jsonData);
      
      await _prefs.setString('${cacheKey}_timestamp', DateTime.now().toIso8601String());
      await _updateCacheIndex(cacheKey);
      
    } catch (e) {
      throw CacheException('Failed to cache customer insights: $e');
    }
  }

  /// Retrieve cached customer insights
  Future<CustomerInsights?> getCachedCustomerInsights(TimePeriod period) async {
    await _ensureInitialized();
    
    final cacheKey = _getCacheKey('customer_insights', period);
    
    try {
      final file = File('${_cacheDirectory.path}/$cacheKey.json');
      
      if (!await file.exists() || await _isCacheExpired(cacheKey)) {
        await _removeFromCache(cacheKey);
        return null;
      }
      
      final jsonString = await file.readAsString();
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      
      return CustomerInsights.fromJson(jsonData);
      
    } catch (e) {
      await _removeFromCache(cacheKey);
      return null;
    }
  }

  /// Cache inventory overview
  Future<void> cacheInventoryOverview(InventoryOverview overview) async {
    await _ensureInitialized();
    
    try {
      const cacheKey = 'inventory_overview';
      final jsonData = json.encode(overview.toJson());
      
      await _prefs.setString(cacheKey, jsonData);
      await _prefs.setString('${cacheKey}_timestamp', DateTime.now().toIso8601String());
      
      await _updateCacheIndex(cacheKey);
      
    } catch (e) {
      throw CacheException('Failed to cache inventory overview: $e');
    }
  }

  /// Retrieve cached inventory overview
  Future<InventoryOverview?> getCachedInventoryOverview() async {
    await _ensureInitialized();
    
    const cacheKey = 'inventory_overview';
    
    try {
      
      if (await _isCacheExpired(cacheKey)) {
        await _removeFromCache(cacheKey);
        return null;
      }
      
      final jsonString = _prefs.getString(cacheKey);
      if (jsonString == null) return null;
      
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      return InventoryOverview.fromJson(jsonData);
      
    } catch (e) {
      await _removeFromCache(cacheKey);
      return null;
    }
  }

  /// Cache anomalies
  Future<void> cacheAnomalies(List<BusinessAnomaly> anomalies) async {
    await _ensureInitialized();
    
    try {
      const cacheKey = 'business_anomalies';
      final jsonData = json.encode(anomalies.map((anomaly) => anomaly.toJson()).toList());
      
      final file = File('${_cacheDirectory.path}/$cacheKey.json');
      await file.writeAsString(jsonData);
      
      await _prefs.setString('${cacheKey}_timestamp', DateTime.now().toIso8601String());
      await _updateCacheIndex(cacheKey);
      
    } catch (e) {
      throw CacheException('Failed to cache anomalies: $e');
    }
  }

  /// Retrieve cached anomalies
  Future<List<BusinessAnomaly>?> getCachedAnomalies() async {
    await _ensureInitialized();
    
    const cacheKey = 'business_anomalies';
    
    try {
      final file = File('${_cacheDirectory.path}/$cacheKey.json');
      
      if (!await file.exists() || await _isCacheExpired(cacheKey)) {
        await _removeFromCache(cacheKey);
        return null;
      }
      
      final jsonString = await file.readAsString();
      final jsonList = json.decode(jsonString) as List<dynamic>;
      
      return jsonList.map((json) => 
          BusinessAnomaly.fromJson(json as Map<String, dynamic>)).toList();
      
    } catch (e) {
      await _removeFromCache(cacheKey);
      return null;
    }
  }

  /// Get cache status information
  Future<CacheStatus> getCacheStatus() async {
    await _ensureInitialized();
    
    try {
      final cacheIndex = await _getCacheIndex();
      final lastUpdate = _prefs.getString(_lastUpdateKey);
      
      int totalSize = 0;
      int expiredItems = 0;
      
      for (final cacheKey in cacheIndex) {
        // Check file size
        final file = File('${_cacheDirectory.path}/$cacheKey.json');
        if (await file.exists()) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
        
        // Check if expired
        if (await _isCacheExpired(cacheKey)) {
          expiredItems++;
        }
      }
      
      return CacheStatus(
        totalItems: cacheIndex.length,
        expiredItems: expiredItems,
        totalSizeBytes: totalSize,
        lastUpdate: lastUpdate != null ? DateTime.parse(lastUpdate) : null,
      );
      
    } catch (e) {
      return CacheStatus(
        totalItems: 0,
        expiredItems: 0,
        totalSizeBytes: 0,
        lastUpdate: null,
      );
    }
  }

  /// Clear expired cache entries
  Future<void> clearExpiredCache() async {
    await _ensureInitialized();
    
    try {
      final cacheIndex = await _getCacheIndex();
      final expiredKeys = <String>[];
      
      for (final cacheKey in cacheIndex) {
        if (await _isCacheExpired(cacheKey)) {
          expiredKeys.add(cacheKey);
        }
      }
      
      for (final key in expiredKeys) {
        await _removeFromCache(key);
      }
      
    } catch (e) {
      throw CacheException('Failed to clear expired cache: $e');
    }
  }

  /// Clear all cached data
  Future<void> clearAllCache() async {
    await _ensureInitialized();
    
    try {
      // Delete all cache files
      if (await _cacheDirectory.exists()) {
        await _cacheDirectory.delete(recursive: true);
        await _cacheDirectory.create(recursive: true);
      }
      
      // Clear SharedPreferences cache entries
      final keys = _prefs.getKeys().where((key) => key.startsWith(_cachePrefix));
      for (final key in keys) {
        await _prefs.remove(key);
      }
      
      // Clear cache index
      await _prefs.remove('cache_index');
      await _prefs.remove(_lastUpdateKey);
      
    } catch (e) {
      throw CacheException('Failed to clear all cache: $e');
    }
  }

  /// Check if cache data is available for offline use
  Future<bool> isOfflineDataAvailable(TimePeriod period) async {
    await _ensureInitialized();
    
    final dashboardData = await getCachedDashboardData(period);
    final kpis = await getCachedKPIs(period);
    
    return dashboardData != null || kpis != null;
  }

  // Private helper methods

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  String _getCacheKey(String dataType, [TimePeriod? period]) {
    final periodSuffix = period != null ? '_${period.name}' : '';
    return '$_cachePrefix${dataType}$periodSuffix';
  }

  Future<bool> _isCacheExpired(String cacheKey) async {
    final timestampString = _prefs.getString('${cacheKey}_timestamp');
    if (timestampString == null) return true;
    
    try {
      final timestamp = DateTime.parse(timestampString);
      final now = DateTime.now();
      return now.difference(timestamp) > _cacheExpiryDuration;
    } catch (e) {
      return true;
    }
  }

  Future<void> _removeFromCache(String cacheKey) async {
    // Remove from SharedPreferences
    await _prefs.remove(cacheKey);
    await _prefs.remove('${cacheKey}_timestamp');
    
    // Remove file if exists
    final file = File('${_cacheDirectory.path}/$cacheKey.json');
    if (await file.exists()) {
      await file.delete();
    }
    
    // Update cache index
    final cacheIndex = await _getCacheIndex();
    cacheIndex.remove(cacheKey);
    await _prefs.setStringList('cache_index', cacheIndex);
  }

  Future<void> _updateCacheIndex(String cacheKey) async {
    final cacheIndex = await _getCacheIndex();
    if (!cacheIndex.contains(cacheKey)) {
      cacheIndex.add(cacheKey);
      await _prefs.setStringList('cache_index', cacheIndex);
    }
  }

  Future<List<String>> _getCacheIndex() async {
    return _prefs.getStringList('cache_index') ?? [];
  }
}

/// Cache status model
class CacheStatus {
  final int totalItems;
  final int expiredItems;
  final int totalSizeBytes;
  final DateTime? lastUpdate;

  CacheStatus({
    required this.totalItems,
    required this.expiredItems,
    required this.totalSizeBytes,
    this.lastUpdate,
  });

  int get validItems => totalItems - expiredItems;
  
  String get formattedSize {
    if (totalSizeBytes < 1024) {
      return '$totalSizeBytes B';
    } else if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

/// Cache exception
class CacheException implements Exception {
  final String message;
  
  CacheException(this.message);
  
  @override
  String toString() => 'CacheException: $message';
}