import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/iras/iras_service.dart';
import '../services/iras/iras_gst_service.dart';
import '../services/iras/iras_exceptions.dart';
import '../models/iras/gst_models.dart';

/// IRAS GST Services Screen
class IrasGstScreen extends ConsumerStatefulWidget {
  const IrasGstScreen({super.key});

  @override
  ConsumerState<IrasGstScreen> createState() => _IrasGstScreenState();
}

class _IrasGstScreenState extends ConsumerState<IrasGstScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final IrasService _irasService = IrasService.instance;

  bool _isLoading = false;
  String? _lastSubmissionResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GST Services'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'F5 Return'),
            Tab(text: 'Register Check'),
            Tab(text: 'History'),
            Tab(text: 'Help'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildF5ReturnTab(),
          _buildRegisterCheckTab(),
          _buildHistoryTab(),
          _buildHelpTab(),
        ],
      ),
    );
  }

  Widget _buildF5ReturnTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GST F5 Return Submission',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Submit your quarterly GST return (Form F5) to IRAS',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  if (!_irasService.isAuthenticated) ...[
                    const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Authentication required to submit GST returns',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _irasService.isAuthenticated && !_isLoading
                            ? _submitSampleF5Return
                            : null,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        label: const Text('Submit Sample F5'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _showF5FormDialog,
                        icon: const Icon(Icons.edit),
                        label: const Text('Custom F5'),
                      ),
                    ],
                  ),
                  if (_lastSubmissionResult != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Last Submission Result:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(_lastSubmissionResult!),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildGstStatusCard(),
        ],
      ),
    );
  }

  Widget _buildGstStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GST Service Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatusItem(
              'Authentication',
              _irasService.isAuthenticated,
              _irasService.isAuthenticated
                  ? 'Ready to submit returns'
                  : 'Please authenticate first',
            ),
            _buildStatusItem(
              'GST F5 Submission',
              true,
              'Service available',
            ),
            _buildStatusItem(
              'GST F7 Editing',
              true,
              'Service available',
            ),
            _buildStatusItem(
              'GST F8 Annual Return',
              true,
              'Service available',
            ),
            _buildStatusItem(
              'Transaction Listings',
              true,
              'Service available',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String title, bool status, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.warning,
            color: status ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterCheckTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GST Registration Check',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check GST registration status for any company',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'GST Registration Number',
                  hintText: 'e.g., M12345678A',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _checkGstRegister,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _checkGstRegister('M12345678A'),
                icon: const Icon(Icons.search),
                label: const Text('Check Sample GST No.'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Submission History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text('No submissions yet.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GST Forms Guide',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildHelpItem(
                    'GST F5 Return',
                    'Quarterly GST return for standard-rated, zero-rated, and exempt supplies',
                    Icons.receipt,
                  ),
                  _buildHelpItem(
                    'GST F7 Edit',
                    'Edit previously submitted GST returns within the allowable period',
                    Icons.edit,
                  ),
                  _buildHelpItem(
                    'GST F8 Annual Return',
                    'Annual GST return for companies with annual turnover ≤ S\$1 million',
                    Icons.calendar_today,
                  ),
                  _buildHelpItem(
                    'Transaction Listings',
                    'Submit detailed transaction listings when required by IRAS',
                    Icons.list,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Important Notes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNoteItem(
                      'GST returns must be submitted by the last day of the month following the end of the taxable period'),
                  _buildNoteItem(
                      'Ensure all amounts are in Singapore Dollars (SGD)'),
                  _buildNoteItem(
                      'Keep proper records and supporting documents for audit purposes'),
                  _buildNoteItem(
                      'Late submission may result in penalties and interest charges'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteItem(String note) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitSampleF5Return() async {
    setState(() {
      _isLoading = true;
      _lastSubmissionResult = null;
    });

    try {
      final sampleRequest = IrasGstService.createSampleF5Request();
      final response = await _irasService.submitGstF5Return(sampleRequest);

      if (response.isSuccess) {
        setState(() {
          _lastSubmissionResult =
              'Success! Acknowledgment: ${response.data?.filingInfo.ackNo ?? 'N/A'}';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GST F5 return submitted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw IrasApiException(
          'Submission failed',
          response.returnCode,
          response.info?.toJson(),
        );
      }
    } on IrasException catch (e) {
      setState(() {
        _lastSubmissionResult = 'Error: ${e.message}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkGstRegister(String gstRegNo) async {
    if (gstRegNo.isEmpty) return;

    try {
      final response = await _irasService.checkGstRegister(gstRegNo);

      if (response.isSuccess && response.data != null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('GST Registration Check'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GST Reg No: ${response.data!.gstRegNo}'),
                  Text('Company: ${response.data!.companyName}'),
                  Text('Status: ${response.data!.registrationStatus}'),
                  if (response.data!.effectiveDate != null)
                    Text('Effective Date: ${response.data!.effectiveDate}'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('GST registration not found or invalid: $gstRegNo'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } on IrasException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check failed: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showF5FormDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom GST F5 Form'),
        content: const Text(
          'Custom GST F5 form builder not implemented yet.\n\n'
          'This would allow you to input your own GST return data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
