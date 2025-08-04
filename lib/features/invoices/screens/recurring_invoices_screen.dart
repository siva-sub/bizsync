import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_invoice_models.dart';
import '../services/recurring_invoice_service.dart';
import 'recurring_invoice_form_screen.dart';

/// Screen for managing recurring invoice templates
class RecurringInvoicesScreen extends StatefulWidget {
  const RecurringInvoicesScreen({super.key});

  @override
  State<RecurringInvoicesScreen> createState() => _RecurringInvoicesScreenState();
}

class _RecurringInvoicesScreenState extends State<RecurringInvoicesScreen> {
  final RecurringInvoiceService _recurringService = RecurringInvoiceService.instance;
  List<RecurringInvoiceTemplate> _templates = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, active, inactive

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    
    try {
      final templates = await _recurringService.getAllTemplates();
      setState(() {
        _templates = templates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading templates: $e')),
        );
      }
    }
  }

  List<RecurringInvoiceTemplate> get _filteredTemplates {
    switch (_filter) {
      case 'active':
        return _templates.where((t) => t.isActive).toList();
      case 'inactive':
        return _templates.where((t) => !t.isActive).toList();
      default:
        return _templates;
    }
  }

  Future<void> _generateDueInvoices() async {
    try {
      final result = await _recurringService.generateDueRecurringInvoices();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? '${result.generatedInvoiceIds.length} invoices generated successfully'
                  : 'Generation completed with errors: ${result.errors.join(', ')}',
            ),
            backgroundColor: result.success ? Colors.green : Colors.orange,
          ),
        );
        
        if (result.generatedInvoiceIds.isNotEmpty) {
          await _loadTemplates(); // Refresh to show updated counts
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating invoices: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleTemplateStatus(RecurringInvoiceTemplate template) async {
    try {
      if (template.isActive) {
        await _recurringService.deactivateTemplate(template.id);
      } else {
        final reactivatedTemplate = template.copyWith(isActive: true);
        await _recurringService.updateTemplate(reactivatedTemplate);
      }
      
      await _loadTemplates();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              template.isActive 
                  ? 'Template deactivated' 
                  : 'Template reactivated',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTemplate(RecurringInvoiceTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recurring Template'),
        content: Text(
          'Are you sure you want to delete "${template.templateName}"? '
          'This action cannot be undone, but existing generated invoices will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _recurringService.deleteTemplate(template.id);
        await _loadTemplates();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Template deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting template: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Invoices'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _filter = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Templates')),
              const PopupMenuItem(value: 'active', child: Text('Active Only')),
              const PopupMenuItem(value: 'inactive', child: Text('Inactive Only')),
            ],
            child: const Icon(Icons.filter_list),
          ),
          IconButton(
            onPressed: _generateDueInvoices,
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Generate Due Invoices',
          ),
          IconButton(
            onPressed: _loadTemplates,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTemplates,
              child: _templates.isEmpty
                  ? _buildEmptyState()
                  : _buildTemplatesList(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (context) => const RecurringInvoiceFormScreen(),
            ),
          );
          
          if (result == true) {
            await _loadTemplates();
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Create Recurring Template',
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.repeat, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Recurring Templates',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Create your first recurring invoice template\nto automate invoice generation',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesList() {
    final filteredTemplates = _filteredTemplates;
    
    return ListView.builder(
      itemCount: filteredTemplates.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final template = filteredTemplates[index];
        return _buildTemplateCard(template);
      },
    );
  }

  Widget _buildTemplateCard(RecurringInvoiceTemplate template) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: template.isActive 
              ? Colors.green.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          child: Icon(
            template.isActive ? Icons.repeat : Icons.pause,
            color: template.isActive ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(
          template.templateName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(template.customerName),
            Text(
              '${template.getPatternDescription()} • ${currencyFormat.format(template.invoiceTemplate.totalAmount)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${template.generatedCount} generated',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                if (template.nextGenerationDate != null)
                  Text(
                    'Next: ${dateFormat.format(template.nextGenerationDate!)}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: const Text('Edit'),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(template.isActive ? 'Deactivate' : 'Activate'),
                ),
                PopupMenuItem(
                  value: 'history',
                  child: const Text('View History'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: const Text('Delete'),
                ),
              ],
              onSelected: (value) async {
                switch (value) {
                  case 'edit':
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (context) => RecurringInvoiceFormScreen(
                          template: template,
                        ),
                      ),
                    );
                    if (result == true) await _loadTemplates();
                    break;
                  case 'toggle':
                    await _toggleTemplateStatus(template);
                    break;
                  case 'history':
                    await _showGenerationHistory(template);
                    break;
                  case 'delete':
                    await _deleteTemplate(template);
                    break;
                }
              },
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Start Date', dateFormat.format(template.startDate)),
                if (template.endDate != null)
                  _buildInfoRow('End Date', dateFormat.format(template.endDate!)),
                if (template.maxOccurrences != null)
                  _buildInfoRow('Max Occurrences', '${template.maxOccurrences}'),
                _buildInfoRow('Status', template.isActive ? 'Active' : 'Inactive'),
                const SizedBox(height: 8),
                Text(
                  'Invoice Details:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Items: ${template.invoiceTemplate.lineItems.length}'),
                Text('Subtotal: ${currencyFormat.format(template.invoiceTemplate.subtotal)}'),
                Text('Tax: ${currencyFormat.format(template.invoiceTemplate.taxAmount)}'),
                Text('Total: ${currencyFormat.format(template.invoiceTemplate.totalAmount)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _showGenerationHistory(RecurringInvoiceTemplate template) async {
    try {
      final history = await _recurringService.getGenerationHistory(template.id);
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Generation History - ${template.templateName}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: history.isEmpty
                ? const Center(child: Text('No generation history found'))
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final entry = history[index];
                      final date = DateTime.parse(entry['generation_date']);
                      final success = entry['success'] == 1;
                      
                      return ListTile(
                        leading: Icon(
                          success ? Icons.check_circle : Icons.error,
                          color: success ? Colors.green : Colors.red,
                        ),
                        title: Text(DateFormat('dd/MM/yyyy HH:mm').format(date)),
                        subtitle: success
                            ? Text('Invoice: ${entry['invoice_id']}')
                            : Text('Error: ${entry['error_message'] ?? 'Unknown error'}'),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}