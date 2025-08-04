import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/iras/iras_service.dart';
import '../services/iras/iras_exceptions.dart';

/// IRAS Integration Dashboard Screen
class IrasDashboardScreen extends ConsumerStatefulWidget {
  const IrasDashboardScreen({super.key});

  @override
  ConsumerState<IrasDashboardScreen> createState() =>
      _IrasDashboardScreenState();
}

class _IrasDashboardScreenState extends ConsumerState<IrasDashboardScreen> {
  final IrasService _irasService = IrasService.instance;
  Map<String, dynamic>? _serviceStatus;
  Map<String, dynamic>? _connectivityTest;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadServiceStatus();
  }

  void _loadServiceStatus() {
    setState(() {
      _serviceStatus = _irasService.getServiceStatus();
    });
  }

  Future<void> _testConnectivity() async {
    setState(() {
      _isLoading = true;
      _connectivityTest = null;
    });

    try {
      final result = await _irasService.testConnectivity();
      setState(() {
        _connectivityTest = result;
      });
    } catch (e) {
      setState(() {
        _connectivityTest = {
          'overall_status': 'error',
          'error': e.toString(),
        };
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initiateAuthentication() async {
    try {
      final authUrl = await _irasService.initiateAuthentication(
        callbackUrl: 'https://bizsync.app/auth/callback',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Authentication URL generated: ${authUrl.substring(0, 50)}...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on IrasException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IRAS Integration'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadServiceStatus();
              _testConnectivity();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildServiceStatusCard(),
            const SizedBox(height: 16),
            _buildAuthenticationCard(),
            const SizedBox(height: 16),
            _buildServicesCard(),
            const SizedBox(height: 16),
            _buildConnectivityCard(),
            const SizedBox(height: 16),
            _buildQuickActionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStatusCard() {
    if (_serviceStatus == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isConfigured = _serviceStatus!['is_configured'] as bool;
    final isAuthenticated = _serviceStatus!['is_authenticated'] as bool;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConfigured && isAuthenticated
                      ? Icons.check_circle
                      : Icons.warning,
                  color: isConfigured && isAuthenticated
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Service Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Configuration', isConfigured),
            _buildStatusRow('Authentication', isAuthenticated),
            if (isAuthenticated && _serviceStatus!['token_expires_in'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Token expires in ${_serviceStatus!['token_expires_in']} minutes',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            status ? Icons.check : Icons.close,
            color: status ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildAuthenticationCard() {
    final isAuthenticated =
        _serviceStatus?['is_authenticated'] as bool? ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Authentication',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (isAuthenticated) ...[
              const Row(
                children: [
                  Icon(Icons.verified_user, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Successfully authenticated with IRAS'),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  _irasService.logout();
                  _loadServiceStatus();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logged out successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ] else ...[
              const Text(
                'Authentication required to access IRAS services',
                style: TextStyle(color: Colors.orange),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _initiateAuthentication,
                icon: const Icon(Icons.login),
                label: const Text('Authenticate with SingPass'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServicesCard() {
    final services = _serviceStatus?['services'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Services',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...services.entries.map((entry) {
              return ListTile(
                leading: const Icon(Icons.api, color: Colors.blue),
                title: Text(entry.key.toUpperCase()),
                subtitle: Text('Status: ${entry.value}'),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
                onTap: () => _navigateToService(entry.key),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectivityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Connectivity Test',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testConnectivity,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check),
                  label: const Text('Test'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_connectivityTest != null) ...[
              _buildConnectivityResults(),
            ] else ...[
              const Text('Click "Test" to check connectivity to IRAS services'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectivityResults() {
    final status = _connectivityTest!['overall_status'] as String;
    final tests = _connectivityTest!['tests'] as Map<String, dynamic>? ?? {};

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'success':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'warning':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case 'error':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(statusIcon, color: statusColor),
            const SizedBox(width: 8),
            Text(
              'Overall Status: ${status.toUpperCase()}',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...tests.entries.map((entry) {
          final testResult = entry.value as Map<String, dynamic>;
          final testStatus = testResult['status'] as String;
          final message = testResult['message'] as String;

          Color testColor;
          IconData testIcon;

          switch (testStatus) {
            case 'success':
              testColor = Colors.green;
              testIcon = Icons.check;
              break;
            case 'warning':
              testColor = Colors.orange;
              testIcon = Icons.warning;
              break;
            case 'error':
              testColor = Colors.red;
              testIcon = Icons.close;
              break;
            default:
              testColor = Colors.grey;
              testIcon = Icons.help;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(testIcon, color: testColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        message,
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
        }),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _navigateToService('gst'),
                  icon: const Icon(Icons.receipt),
                  label: const Text('GST Returns'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _navigateToService('corporate_tax'),
                  icon: const Icon(Icons.business),
                  label: const Text('Corporate Tax'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _navigateToService('employment'),
                  icon: const Icon(Icons.people),
                  label: const Text('Employment Records'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _navigateToAuditLogs(),
                  icon: const Icon(Icons.history),
                  label: const Text('Audit Logs'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToService(String service) {
    switch (service) {
      case 'gst':
        context.go('/tax/iras/gst');
        break;
      case 'corporate_tax':
        context.go('/tax/iras/corporate-tax');
        break;
      case 'employment':
        context.go('/tax/iras/employment');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$service service screen not implemented yet'),
          ),
        );
    }
  }

  void _navigateToAuditLogs() {
    context.go('/tax/iras/audit-logs');
  }
}
