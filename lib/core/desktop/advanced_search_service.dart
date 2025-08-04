import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Search Result Item
class SearchResult {
  final String id;
  final String title;
  final String subtitle;
  final String type;
  final String category;
  final Map<String, dynamic> data;
  final DateTime? lastModified;
  final double relevanceScore;
  final String? iconPath;
  final List<String> tags;

  SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.category,
    required this.data,
    this.lastModified,
    this.relevanceScore = 0.0,
    this.iconPath,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'type': type,
        'category': category,
        'data': data,
        'lastModified': lastModified?.toIso8601String(),
        'relevanceScore': relevanceScore,
        'iconPath': iconPath,
        'tags': tags,
      };

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        id: json['id'],
        title: json['title'],
        subtitle: json['subtitle'],
        type: json['type'],
        category: json['category'],
        data: json['data'] ?? {},
        lastModified: json['lastModified'] != null
            ? DateTime.parse(json['lastModified'])
            : null,
        relevanceScore: json['relevanceScore']?.toDouble() ?? 0.0,
        iconPath: json['iconPath'],
        tags: List<String>.from(json['tags'] ?? []),
      );
}

/// Search Filter
class SearchFilter {
  final String key;
  final String label;
  final SearchFilterType type;
  final List<String>? options;
  final dynamic value;
  final dynamic minValue;
  final dynamic maxValue;

  SearchFilter({
    required this.key,
    required this.label,
    required this.type,
    this.options,
    this.value,
    this.minValue,
    this.maxValue,
  });
}

/// Search Filter Types
enum SearchFilterType {
  text,
  select,
  multiSelect,
  dateRange,
  numberRange,
  boolean,
}

/// Search Query
class SearchQuery {
  final String query;
  final List<String> categories;
  final Map<String, dynamic> filters;
  final String? sortBy;
  final bool sortAscending;
  final int limit;
  final int offset;

  SearchQuery({
    required this.query,
    this.categories = const [],
    this.filters = const {},
    this.sortBy,
    this.sortAscending = true,
    this.limit = 50,
    this.offset = 0,
  });

  Map<String, dynamic> toJson() => {
        'query': query,
        'categories': categories,
        'filters': filters,
        'sortBy': sortBy,
        'sortAscending': sortAscending,
        'limit': limit,
        'offset': offset,
      };

  factory SearchQuery.fromJson(Map<String, dynamic> json) => SearchQuery(
        query: json['query'],
        categories: List<String>.from(json['categories'] ?? []),
        filters: json['filters'] ?? {},
        sortBy: json['sortBy'],
        sortAscending: json['sortAscending'] ?? true,
        limit: json['limit'] ?? 50,
        offset: json['offset'] ?? 0,
      );
}

/// Saved Search
class SavedSearch {
  final String id;
  final String name;
  final String description;
  final SearchQuery query;
  final DateTime created;
  final DateTime lastUsed;
  final int useCount;

  SavedSearch({
    required this.id,
    required this.name,
    required this.description,
    required this.query,
    required this.created,
    required this.lastUsed,
    this.useCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'query': query.toJson(),
        'created': created.toIso8601String(),
        'lastUsed': lastUsed.toIso8601String(),
        'useCount': useCount,
      };

  factory SavedSearch.fromJson(Map<String, dynamic> json) => SavedSearch(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        query: SearchQuery.fromJson(json['query']),
        created: DateTime.parse(json['created']),
        lastUsed: DateTime.parse(json['lastUsed']),
        useCount: json['useCount'] ?? 0,
      );
}

/// Search History Entry
class SearchHistoryEntry {
  final String query;
  final DateTime timestamp;
  final List<String> categories;
  final int resultCount;

  SearchHistoryEntry({
    required this.query,
    required this.timestamp,
    this.categories = const [],
    this.resultCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'query': query,
        'timestamp': timestamp.toIso8601String(),
        'categories': categories,
        'resultCount': resultCount,
      };

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) =>
      SearchHistoryEntry(
        query: json['query'],
        timestamp: DateTime.parse(json['timestamp']),
        categories: List<String>.from(json['categories'] ?? []),
        resultCount: json['resultCount'] ?? 0,
      );
}

/// Advanced Search Service for Linux Desktop
///
/// Provides comprehensive search functionality:
/// - Global search with filters
/// - Search history tracking
/// - Saved searches
/// - Real-time search suggestions
/// - Full-text search across all data
class AdvancedSearchService extends ChangeNotifier {
  static final AdvancedSearchService _instance =
      AdvancedSearchService._internal();
  factory AdvancedSearchService() => _instance;
  AdvancedSearchService._internal();

  bool _isInitialized = false;
  final List<SearchHistoryEntry> _searchHistory = [];
  final List<SavedSearch> _savedSearches = [];
  final Map<String, List<SearchResult>> _searchCache = {};
  static const int _maxHistoryEntries = 100;
  static const int _maxCacheEntries = 50;

  /// Available search categories
  final List<String> _availableCategories = [
    'invoices',
    'customers',
    'products',
    'vendors',
    'reports',
    'settings',
    'help',
  ];

  /// Available search filters
  final Map<String, List<SearchFilter>> _availableFilters = {
    'invoices': [
      SearchFilter(
        key: 'status',
        label: 'Status',
        type: SearchFilterType.select,
        options: ['draft', 'sent', 'paid', 'overdue', 'cancelled'],
      ),
      SearchFilter(
        key: 'amount_range',
        label: 'Amount Range',
        type: SearchFilterType.numberRange,
        minValue: 0,
        maxValue: 100000,
      ),
      SearchFilter(
        key: 'date_range',
        label: 'Date Range',
        type: SearchFilterType.dateRange,
      ),
    ],
    'customers': [
      SearchFilter(
        key: 'company',
        label: 'Company',
        type: SearchFilterType.text,
      ),
      SearchFilter(
        key: 'location',
        label: 'Location',
        type: SearchFilterType.text,
      ),
      SearchFilter(
        key: 'status',
        label: 'Status',
        type: SearchFilterType.select,
        options: ['active', 'inactive', 'prospect'],
      ),
    ],
    'products': [
      SearchFilter(
        key: 'category',
        label: 'Category',
        type: SearchFilterType.select,
        options: ['electronics', 'clothing', 'books', 'home', 'other'],
      ),
      SearchFilter(
        key: 'price_range',
        label: 'Price Range',
        type: SearchFilterType.numberRange,
        minValue: 0,
        maxValue: 10000,
      ),
      SearchFilter(
        key: 'in_stock',
        label: 'In Stock',
        type: SearchFilterType.boolean,
      ),
    ],
  };

  /// Initialize the advanced search service
  Future<void> initialize() async {
    try {
      // Load search history
      await _loadSearchHistory();

      // Load saved searches
      await _loadSavedSearches();

      _isInitialized = true;
      debugPrint('✅ Advanced search service initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize advanced search service: $e');
    }
  }

  /// Perform global search
  Future<List<SearchResult>> search(SearchQuery query) async {
    if (!_isInitialized) {
      debugPrint('Advanced search service not initialized');
      return [];
    }

    try {
      // Check cache first
      final cacheKey = _generateCacheKey(query);
      if (_searchCache.containsKey(cacheKey)) {
        debugPrint('Returning cached search results for: ${query.query}');
        return _searchCache[cacheKey]!;
      }

      final results = <SearchResult>[];

      // Search each category if specified, or all categories
      final categoriesToSearch =
          query.categories.isNotEmpty ? query.categories : _availableCategories;

      for (final category in categoriesToSearch) {
        final categoryResults = await _searchCategory(category, query);
        results.addAll(categoryResults);
      }

      // Sort results by relevance score
      results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

      // Apply limit and offset
      final startIndex = query.offset;
      final endIndex = (startIndex + query.limit).clamp(0, results.length);
      final paginatedResults = results.sublist(startIndex, endIndex);

      // Cache results
      _cacheSearchResults(cacheKey, paginatedResults);

      // Add to search history
      await _addToSearchHistory(SearchHistoryEntry(
        query: query.query,
        timestamp: DateTime.now(),
        categories: query.categories,
        resultCount: results.length,
      ));

      notifyListeners();
      return paginatedResults;
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    }
  }

  /// Search within a specific category
  Future<List<SearchResult>> _searchCategory(
      String category, SearchQuery query) async {
    switch (category) {
      case 'invoices':
        return await _searchInvoices(query);
      case 'customers':
        return await _searchCustomers(query);
      case 'products':
        return await _searchProducts(query);
      case 'vendors':
        return await _searchVendors(query);
      case 'reports':
        return await _searchReports(query);
      case 'settings':
        return await _searchSettings(query);
      case 'help':
        return await _searchHelp(query);
      default:
        return [];
    }
  }

  /// Search invoices
  Future<List<SearchResult>> _searchInvoices(SearchQuery query) async {
    // This would typically query the database
    // For now, returning mock data
    final mockInvoices = [
      {
        'id': 'INV-001',
        'number': 'INV-001',
        'customerName': 'John Doe',
        'amount': 1000.0,
        'status': 'paid',
        'date': '2024-01-15',
      },
      {
        'id': 'INV-002',
        'number': 'INV-002',
        'customerName': 'Jane Smith',
        'amount': 750.0,
        'status': 'pending',
        'date': '2024-01-20',
      },
    ];

    final results = <SearchResult>[];

    for (final invoice in mockInvoices) {
      if (_matchesQuery(query.query, [
        invoice['number'],
        invoice['customerName'],
        invoice['status'],
      ])) {
        final relevanceScore = _calculateRelevanceScore(query.query, [
          invoice['number'].toString(),
          invoice['customerName'].toString(),
        ]);

        results.add(SearchResult(
          id: invoice['id'].toString(),
          title: 'Invoice ${invoice['number']}',
          subtitle: '${invoice['customerName']} - \$${invoice['amount']}',
          type: 'invoice',
          category: 'invoices',
          data: invoice,
          relevanceScore: relevanceScore,
          tags: ['invoice', invoice['status'].toString()],
        ));
      }
    }

    return results;
  }

  /// Search customers
  Future<List<SearchResult>> _searchCustomers(SearchQuery query) async {
    final mockCustomers = [
      {
        'id': 'CUST-001',
        'name': 'John Doe',
        'email': 'john@email.com',
        'company': 'ABC Corp',
        'phone': '+1-555-0123',
      },
      {
        'id': 'CUST-002',
        'name': 'Jane Smith',
        'email': 'jane@email.com',
        'company': 'XYZ Ltd',
        'phone': '+1-555-0456',
      },
    ];

    final results = <SearchResult>[];

    for (final customer in mockCustomers) {
      if (_matchesQuery(query.query, [
        customer['name'],
        customer['email'],
        customer['company'],
        customer['phone'],
      ])) {
        final relevanceScore = _calculateRelevanceScore(query.query, [
          customer['name'].toString(),
          customer['company'].toString(),
        ]);

        results.add(SearchResult(
          id: customer['id'].toString(),
          title: customer['name'].toString(),
          subtitle: '${customer['company']} - ${customer['email']}',
          type: 'customer',
          category: 'customers',
          data: customer,
          relevanceScore: relevanceScore,
          tags: ['customer', customer['company'].toString()],
        ));
      }
    }

    return results;
  }

  /// Search products
  Future<List<SearchResult>> _searchProducts(SearchQuery query) async {
    final mockProducts = [
      {
        'id': 'PROD-001',
        'name': 'Laptop Computer',
        'sku': 'LAP-001',
        'category': 'electronics',
        'price': 999.99,
        'stock': 50,
      },
      {
        'id': 'PROD-002',
        'name': 'Office Chair',
        'sku': 'CHR-001',
        'category': 'furniture',
        'price': 299.99,
        'stock': 25,
      },
    ];

    final results = <SearchResult>[];

    for (final product in mockProducts) {
      if (_matchesQuery(query.query, [
        product['name'],
        product['sku'],
        product['category'],
      ])) {
        final relevanceScore = _calculateRelevanceScore(query.query, [
          product['name'].toString(),
          product['sku'].toString(),
        ]);

        results.add(SearchResult(
          id: product['id'].toString(),
          title: product['name'].toString(),
          subtitle:
              '${product['sku']} - \$${product['price']} (${product['stock']} in stock)',
          type: 'product',
          category: 'products',
          data: product,
          relevanceScore: relevanceScore,
          tags: ['product', product['category'].toString()],
        ));
      }
    }

    return results;
  }

  /// Search vendors (placeholder)
  Future<List<SearchResult>> _searchVendors(SearchQuery query) async {
    return [];
  }

  /// Search reports (placeholder)
  Future<List<SearchResult>> _searchReports(SearchQuery query) async {
    return [];
  }

  /// Search settings (placeholder)
  Future<List<SearchResult>> _searchSettings(SearchQuery query) async {
    return [];
  }

  /// Search help (placeholder)
  Future<List<SearchResult>> _searchHelp(SearchQuery query) async {
    return [];
  }

  /// Check if any of the fields match the query
  bool _matchesQuery(String query, List<dynamic> fields) {
    final searchTerms = query.toLowerCase().split(' ');
    final fieldsText = fields.join(' ').toLowerCase();

    return searchTerms.every((term) => fieldsText.contains(term));
  }

  /// Calculate relevance score based on query and fields
  double _calculateRelevanceScore(String query, List<String> fields) {
    double score = 0.0;
    final searchTerms = query.toLowerCase().split(' ');

    for (final field in fields) {
      final fieldText = field.toLowerCase();

      // Exact match gets highest score
      if (fieldText == query.toLowerCase()) {
        score += 100.0;
      }
      // Field starts with query gets high score
      else if (fieldText.startsWith(query.toLowerCase())) {
        score += 80.0;
      }
      // Field contains query gets medium score
      else if (fieldText.contains(query.toLowerCase())) {
        score += 50.0;
      }
      // Individual term matches get lower scores
      else {
        for (final term in searchTerms) {
          if (fieldText.contains(term)) {
            score += 20.0;
          }
        }
      }
    }

    return score;
  }

  /// Generate cache key for search query
  String _generateCacheKey(SearchQuery query) {
    return '${query.query}_${query.categories.join(',')}_${query.filters.toString()}_${query.sortBy}_${query.sortAscending}';
  }

  /// Cache search results
  void _cacheSearchResults(String key, List<SearchResult> results) {
    if (_searchCache.length >= _maxCacheEntries) {
      // Remove oldest entry
      final oldestKey = _searchCache.keys.first;
      _searchCache.remove(oldestKey);
    }

    _searchCache[key] = results;
  }

  /// Get search suggestions based on query
  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.length < 2) return [];

    final suggestions = <String>[];

    // Add suggestions from search history
    for (final entry in _searchHistory) {
      if (entry.query.toLowerCase().contains(query.toLowerCase()) &&
          !suggestions.contains(entry.query)) {
        suggestions.add(entry.query);
      }
    }

    // Add suggestions from saved searches
    for (final saved in _savedSearches) {
      if (saved.name.toLowerCase().contains(query.toLowerCase()) &&
          !suggestions.contains(saved.name)) {
        suggestions.add(saved.name);
      }
    }

    // Limit suggestions
    return suggestions.take(10).toList();
  }

  /// Save a search query
  Future<void> saveSearch({
    required String name,
    required String description,
    required SearchQuery query,
  }) async {
    final savedSearch = SavedSearch(
      id: 'saved_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      query: query,
      created: DateTime.now(),
      lastUsed: DateTime.now(),
    );

    _savedSearches.add(savedSearch);
    await _saveSavedSearches();
    notifyListeners();
  }

  /// Update saved search usage
  Future<void> updateSavedSearchUsage(String savedSearchId) async {
    final index = _savedSearches.indexWhere((s) => s.id == savedSearchId);
    if (index != -1) {
      final savedSearch = _savedSearches[index];
      _savedSearches[index] = SavedSearch(
        id: savedSearch.id,
        name: savedSearch.name,
        description: savedSearch.description,
        query: savedSearch.query,
        created: savedSearch.created,
        lastUsed: DateTime.now(),
        useCount: savedSearch.useCount + 1,
      );

      await _saveSavedSearches();
      notifyListeners();
    }
  }

  /// Delete saved search
  Future<void> deleteSavedSearch(String savedSearchId) async {
    _savedSearches.removeWhere((s) => s.id == savedSearchId);
    await _saveSavedSearches();
    notifyListeners();
  }

  /// Add entry to search history
  Future<void> _addToSearchHistory(SearchHistoryEntry entry) async {
    // Remove existing entry with same query
    _searchHistory.removeWhere((e) => e.query == entry.query);

    // Add new entry at the beginning
    _searchHistory.insert(0, entry);

    // Limit history size
    if (_searchHistory.length > _maxHistoryEntries) {
      _searchHistory.removeRange(_maxHistoryEntries, _searchHistory.length);
    }

    await _saveSearchHistory();
  }

  /// Clear search history
  Future<void> clearSearchHistory() async {
    _searchHistory.clear();
    await _saveSearchHistory();
    notifyListeners();
  }

  /// Clear search cache
  void clearSearchCache() {
    _searchCache.clear();
    notifyListeners();
  }

  /// Save search history to persistent storage
  Future<void> _saveSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = _searchHistory.map((e) => e.toJson()).toList();
      await prefs.setString('search_history', jsonEncode(historyJson));
    } catch (e) {
      debugPrint('Failed to save search history: $e');
    }
  }

  /// Load search history from persistent storage
  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString('search_history');

      if (historyString != null) {
        final historyList = jsonDecode(historyString) as List;
        _searchHistory.clear();

        for (final entryJson in historyList) {
          try {
            final entry = SearchHistoryEntry.fromJson(entryJson);
            _searchHistory.add(entry);
          } catch (e) {
            debugPrint('Failed to load search history entry: $e');
          }
        }

        debugPrint('Loaded ${_searchHistory.length} search history entries');
      }
    } catch (e) {
      debugPrint('Failed to load search history: $e');
    }
  }

  /// Save saved searches to persistent storage
  Future<void> _saveSavedSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = _savedSearches.map((s) => s.toJson()).toList();
      await prefs.setString('saved_searches', jsonEncode(savedJson));
    } catch (e) {
      debugPrint('Failed to save saved searches: $e');
    }
  }

  /// Load saved searches from persistent storage
  Future<void> _loadSavedSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedString = prefs.getString('saved_searches');

      if (savedString != null) {
        final savedList = jsonDecode(savedString) as List;
        _savedSearches.clear();

        for (final savedJson in savedList) {
          try {
            final saved = SavedSearch.fromJson(savedJson);
            _savedSearches.add(saved);
          } catch (e) {
            debugPrint('Failed to load saved search: $e');
          }
        }

        debugPrint('Loaded ${_savedSearches.length} saved searches');
      }
    } catch (e) {
      debugPrint('Failed to load saved searches: $e');
    }
  }

  /// Get available categories
  List<String> get availableCategories =>
      List.unmodifiable(_availableCategories);

  /// Get available filters for category
  List<SearchFilter> getFiltersForCategory(String category) {
    return _availableFilters[category] ?? [];
  }

  /// Get search history
  List<SearchHistoryEntry> get searchHistory =>
      List.unmodifiable(_searchHistory);

  /// Get saved searches
  List<SavedSearch> get savedSearches => List.unmodifiable(_savedSearches);

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose of the advanced search service
  Future<void> dispose() async {
    await _saveSearchHistory();
    await _saveSavedSearches();

    _searchHistory.clear();
    _savedSearches.clear();
    _searchCache.clear();

    _isInitialized = false;
    debugPrint('Advanced search service disposed');
  }
}
