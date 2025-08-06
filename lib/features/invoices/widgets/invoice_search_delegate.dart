import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/types/invoice_types.dart' hide InvoiceStatus;
import '../models/enhanced_invoice.dart';
import '../models/enhanced_invoice_model.dart';
import '../models/invoice_models.dart' as IM;
import 'invoice_status_chip.dart';

class InvoiceSearchDelegate extends SearchDelegate<String> {
  final List<CRDTInvoiceEnhanced> invoices;
  static const String _recentSearchesKey = 'invoice_recent_searches';
  static const int _maxRecentSearches = 10;
  List<String>? _recentSearchesCache;

  InvoiceSearchDelegate({required this.invoices});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // Save search term to recent searches
    if (query.trim().isNotEmpty) {
      _saveRecentSearch(query.trim());
    }
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Clear recent searches cache when query changes
    if (query.isNotEmpty) {
      _recentSearchesCache = null;
    }
    if (query.isEmpty) {
      return _buildRecentSearches(context);
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final filteredInvoices = invoices.where((invoice) {
      final queryLower = query.toLowerCase();
      return invoice.invoiceNumber.value.toLowerCase().contains(queryLower) ||
          (invoice.customerName.value ?? '')
              .toLowerCase()
              .contains(queryLower) ||
          (invoice.customerEmail.value ?? '')
              .toLowerCase()
              .contains(queryLower) ||
          (invoice.notes.value ?? '').toLowerCase().contains(queryLower);
    }).toList();

    if (filteredInvoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No invoices found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredInvoices.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final invoice = filteredInvoices[index];
        return _InvoiceSearchResultTile(
          invoice: invoice,
          searchQuery: query,
          onTap: () {
            close(context, invoice.id);
            context.go('/invoices/detail/${invoice.id}');
          },
        );
      },
    );
  }

  Widget _buildRecentSearches(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _getRecentSearches(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyRecentSearches(context);
        }

        final recentSearches = snapshot.data!;
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
              ),
            ),
            ...recentSearches.map((search) => ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(search),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _removeRecentSearch(search),
                  ),
                  onTap: () {
                    query = search;
                    showResults(context);
                  },
                )),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Search Tips',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
              ),
            ),
            const ListTile(
              leading: Icon(Icons.lightbulb_outline),
              title: Text('Search by invoice number'),
              subtitle: Text('e.g., INV-001, INV-2024-001'),
            ),
            const ListTile(
              leading: Icon(Icons.lightbulb_outline),
              title: Text('Search by customer name'),
              subtitle: Text('e.g., John Doe, Acme Corp'),
            ),
            const ListTile(
              leading: Icon(Icons.lightbulb_outline),
              title: Text('Search by email'),
              subtitle: Text('e.g., john@example.com'),
            ),
          ],
        );
      },
    );
  }

  /// Get recent searches from shared preferences
  Future<List<String>> _getRecentSearches() async {
    if (_recentSearchesCache != null) {
      return _recentSearchesCache!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final recentSearchesJson = prefs.getStringList(_recentSearchesKey) ?? [];
      _recentSearchesCache = recentSearchesJson;
      return _recentSearchesCache!;
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
      return [];
    }
  }

  /// Save a search term to recent searches
  Future<void> _saveRecentSearch(String searchTerm) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> recentSearches =
          prefs.getStringList(_recentSearchesKey) ?? [];

      // Remove if already exists to avoid duplicates
      recentSearches.remove(searchTerm);

      // Add to the beginning
      recentSearches.insert(0, searchTerm);

      // Keep only the latest searches
      if (recentSearches.length > _maxRecentSearches) {
        recentSearches = recentSearches.take(_maxRecentSearches).toList();
      }

      await prefs.setStringList(_recentSearchesKey, recentSearches);
      _recentSearchesCache = recentSearches;
    } catch (e) {
      debugPrint('Error saving recent search: $e');
    }
  }

  /// Remove a specific search term from recent searches
  Future<void> _removeRecentSearch(String searchTerm) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> recentSearches =
          prefs.getStringList(_recentSearchesKey) ?? [];
      recentSearches.remove(searchTerm);
      await prefs.setStringList(_recentSearchesKey, recentSearches);
      _recentSearchesCache = recentSearches;
    } catch (e) {
      debugPrint('Error removing recent search: $e');
    }
  }

  /// Clear all recent searches
  Future<void> _clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
      _recentSearchesCache = [];
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
    }
  }

  /// Build empty recent searches widget
  Widget _buildEmptyRecentSearches(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Recent Searches',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.search,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No recent searches',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your search history will appear here',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildSearchSuggestions(context),
      ],
    );
  }

  /// Build search suggestions widget
  Widget _buildSearchSuggestions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search Suggestions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSuggestionChip(context, 'Draft invoices', 'status:draft'),
              _buildSuggestionChip(
                  context, 'Overdue invoices', 'status:overdue'),
              _buildSuggestionChip(context, 'This week', 'week:current'),
              _buildSuggestionChip(context, 'This month', 'month:current'),
              _buildSuggestionChip(context, 'Large amounts', 'amount:>1000'),
            ],
          ),
        ],
      ),
    );
  }

  /// Build a suggestion chip
  Widget _buildSuggestionChip(
      BuildContext context, String label, String searchQuery) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        query = searchQuery;
        showResults(context);
      },
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
    );
  }
}

class _InvoiceSearchResultTile extends StatelessWidget {
  final CRDTInvoiceEnhanced invoice;
  final String searchQuery;
  final VoidCallback onTap;

  const _InvoiceSearchResultTile({
    required this.invoice,
    required this.searchQuery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(_convertStatus(invoice.status.value))
              .withValues(alpha: 0.1),
          child: Icon(
            _getStatusIcon(_convertStatus(invoice.status.value)),
            color: _getStatusColor(_convertStatus(invoice.status.value)),
            size: 20,
          ),
        ),
        title: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: _highlightSearchTerm(
              invoice.invoiceNumber.value,
              searchQuery,
              context,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodySmall,
                children: _highlightSearchTerm(
                  invoice.customerName.value ?? '',
                  searchQuery,
                  context,
                ),
              ),
            ),
            if (invoice.customerEmail.value?.isNotEmpty == true)
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                  children: _highlightSearchTerm(
                    invoice.customerEmail.value ?? '',
                    searchQuery,
                    context,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                InvoiceStatusChip(
                    status: invoice.status.value, isCompact: true),
                const SizedBox(width: 8),
                Text(
                  '${invoice.issueDate.value.day}/${invoice.issueDate.value.month}/${invoice.issueDate.value.year}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${invoice.totalAmount.value.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            Text(
              'Due ${invoice.dueDate.value?.day ?? ''}/${invoice.dueDate.value?.month ?? ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: (invoice.dueDate.value?.isBefore(DateTime.now()) ??
                            false)
                        ? Colors.red
                        : Colors.grey[600],
                  ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  List<TextSpan> _highlightSearchTerm(
    String text,
    String searchTerm,
    BuildContext context, {
    FontWeight? fontWeight,
  }) {
    if (searchTerm.isEmpty) {
      return [
        TextSpan(
          text: text,
          style: TextStyle(fontWeight: fontWeight),
        )
      ];
    }

    final List<TextSpan> spans = [];
    final lowerText = text.toLowerCase();
    final lowerSearchTerm = searchTerm.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerSearchTerm, start);
      if (index == -1) {
        // Add remaining text
        if (start < text.length) {
          spans.add(TextSpan(
            text: text.substring(start),
            style: TextStyle(fontWeight: fontWeight),
          ));
        }
        break;
      }

      // Add text before match
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: TextStyle(fontWeight: fontWeight),
        ));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + searchTerm.length),
        style: TextStyle(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + searchTerm.length;
    }

    return spans;
  }

  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return Colors.grey[600]!;
      case InvoiceStatus.pending:
        return Colors.orange[600]!;
      case InvoiceStatus.approved:
        return Colors.blue[400]!;
      case InvoiceStatus.sent:
        return Colors.blue[600]!;
      case InvoiceStatus.viewed:
        return Colors.cyan[600]!;
      case InvoiceStatus.partiallyPaid:
        return Colors.amber[600]!;
      case InvoiceStatus.paid:
        return Colors.green[600]!;
      case InvoiceStatus.overdue:
        return Colors.red[600]!;
      case InvoiceStatus.cancelled:
        return Colors.orange[600]!;
      case InvoiceStatus.disputed:
        return Colors.purple[600]!;
      case InvoiceStatus.voided:
        return Colors.grey[800]!;
      case InvoiceStatus.refunded:
        return Colors.teal[600]!;
    }
  }

  IconData _getStatusIcon(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return Icons.edit_outlined;
      case InvoiceStatus.pending:
        return Icons.schedule_outlined;
      case InvoiceStatus.approved:
        return Icons.check_outlined;
      case InvoiceStatus.sent:
        return Icons.send_outlined;
      case InvoiceStatus.viewed:
        return Icons.visibility_outlined;
      case InvoiceStatus.partiallyPaid:
        return Icons.payment_outlined;
      case InvoiceStatus.paid:
        return Icons.check_circle_outline;
      case InvoiceStatus.overdue:
        return Icons.warning_outlined;
      case InvoiceStatus.cancelled:
        return Icons.cancel_outlined;
      case InvoiceStatus.disputed:
        return Icons.report_problem_outlined;
      case InvoiceStatus.voided:
        return Icons.block_outlined;
      case InvoiceStatus.refunded:
        return Icons.money_off_outlined;
    }
  }

  // Convert from invoice_models.InvoiceStatus to enhanced_invoice.InvoiceStatus
  InvoiceStatus _convertStatus(IM.InvoiceStatus status) {
    switch (status) {
      case IM.InvoiceStatus.draft:
        return InvoiceStatus.draft;
      case IM.InvoiceStatus.pending:
        return InvoiceStatus.pending;
      case IM.InvoiceStatus.approved:
        return InvoiceStatus.approved;
      case IM.InvoiceStatus.sent:
        return InvoiceStatus.sent;
      case IM.InvoiceStatus.viewed:
        return InvoiceStatus.viewed;
      case IM.InvoiceStatus.partiallyPaid:
        return InvoiceStatus.partiallyPaid;
      case IM.InvoiceStatus.paid:
        return InvoiceStatus.paid;
      case IM.InvoiceStatus.overdue:
        return InvoiceStatus.overdue;
      case IM.InvoiceStatus.cancelled:
        return InvoiceStatus.cancelled;
      case IM.InvoiceStatus.disputed:
        return InvoiceStatus.disputed;
      case IM.InvoiceStatus.voided:
        return InvoiceStatus.voided;
      case IM.InvoiceStatus.refunded:
        return InvoiceStatus.refunded;
    }
  }
}
