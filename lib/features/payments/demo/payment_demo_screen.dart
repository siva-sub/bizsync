import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../index.dart';

/// Demo screen showcasing PayNow payment functionality
class PaymentDemoScreen extends StatefulWidget {
  const PaymentDemoScreen({super.key});

  @override
  State<PaymentDemoScreen> createState() => _PaymentDemoScreenState();
}

class _PaymentDemoScreenState extends State<PaymentDemoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Demo data
  String _merchantName = 'BizSync Demo Store';
  String _merchantCity = 'Singapore';
  String _payNowIdentifier = '91234567'; // Demo mobile number
  PayNowIdentifierType _identifierType = PayNowIdentifierType.mobile;
  double? _amount;
  CurrencyCode _currency = CurrencyCode.sgd;

  // QR Generation
  String? _generatedQR;
  bool _isGenerating = false;
  String? _errorMessage;

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

  Future<void> _generateQR() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      // Create message from merchant name and amount
      String? message;
      if (_amount != null) {
        message =
            'Payment to $_merchantName - ${_getCurrencySymbol(_currency)}${_amount!.toStringAsFixed(2)}';
      } else {
        message = 'Payment to $_merchantName';
      }

      final PayNowResult result = PayNowService.createPayNowQR(
        identifier: _payNowIdentifier,
        amount: _amount,
        message: message,
      );

      setState(() {
        if (result.success) {
          _generatedQR = result.payNowString;
        } else {
          _errorMessage = result.error ?? 'Unknown error';
        }
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate QR: $e';
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PayNow QR Demo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: 'Setup'),
            Tab(icon: Icon(Icons.qr_code), text: 'QR Code'),
            Tab(icon: Icon(Icons.share), text: 'Share'),
            Tab(icon: Icon(Icons.info), text: 'Info'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSetupTab(),
          _buildQRTab(),
          _buildShareTab(),
          _buildInfoTab(),
        ],
      ),
    );
  }

  Widget _buildSetupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Merchant Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Merchant Name',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: _merchantName),
            onChanged: (value) => _merchantName = value,
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Merchant City',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: _merchantCity),
            onChanged: (value) => _merchantCity = value,
          ),
          const SizedBox(height: 24),
          Text(
            'PayNow Configuration',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<PayNowIdentifierType>(
            value: _identifierType,
            decoration: const InputDecoration(
              labelText: 'Identifier Type',
              border: OutlineInputBorder(),
            ),
            items: PayNowIdentifierType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(_getIdentifierTypeName(type)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _identifierType = value;
                  // Set default values for demo
                  switch (value) {
                    case PayNowIdentifierType.mobile:
                      _payNowIdentifier = '91234567';
                      break;
                    case PayNowIdentifierType.uen:
                      _payNowIdentifier = '201234567Z';
                      break;
                    case PayNowIdentifierType.nric:
                      _payNowIdentifier = 'S1234567A';
                      break;
                  }
                });
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: _getIdentifierLabel(_identifierType),
              border: const OutlineInputBorder(),
              helperText: _getIdentifierHelp(_identifierType),
            ),
            controller: TextEditingController(text: _payNowIdentifier),
            onChanged: (value) => _payNowIdentifier = value,
          ),
          const SizedBox(height: 24),
          Text(
            'Payment Configuration',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          CurrencySelectorWidget(
            selectedCurrency: _currency,
            onCurrencyChanged: (currency) {
              setState(() {
                _currency = currency;
              });
            },
          ),
          const SizedBox(height: 16),
          AmountInputWidget(
            initialAmount: _amount,
            currency: _currency,
            onAmountChanged: (amount) {
              setState(() {
                _amount = amount;
              });
            },
            minimumAmount: 0.01,
            maximumAmount: 999999.99,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateQR,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code_2),
              label: Text(_isGenerating ? 'Generating...' : 'Generate QR Code'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_generatedQR != null) ...[
            QRCardWidget(
              qrData: _generatedQR!,
              title: _merchantName,
              subtitle: _amount != null ? 'Dynamic QR' : 'Static QR',
              amount: _amount != null
                  ? '${_getCurrencySymbol(_currency)}${_amount!.toStringAsFixed(2)}'
                  : null,
              styling: QRStylingOptions.singaporeTheme(),
              actions: [
                IconButton(
                  onPressed: () => _copyToClipboard(_generatedQR!),
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy QR Data',
                ),
                IconButton(
                  onPressed: () => _shareQR(_generatedQR!),
                  icon: const Icon(Icons.share),
                  tooltip: 'Share QR',
                ),
                IconButton(
                  onPressed: () => _saveQR(_generatedQR!),
                  icon: const Icon(Icons.save),
                  tooltip: 'Save QR',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildQRDetails(),
          ] else if (_isGenerating) ...[
            const SizedBox(height: 100),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Generating QR Code...'),
          ] else if (_errorMessage != null) ...[
            const SizedBox(height: 50),
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error generating QR code',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.red[700],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[600]),
            ),
          ] else ...[
            const SizedBox(height: 100),
            Icon(
              Icons.qr_code,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No QR Code Generated',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            const Text('Go to Setup tab to configure and generate a QR code'),
          ],
        ],
      ),
    );
  }

  Widget _buildQRDetails() {
    if (_generatedQR == null) return const SizedBox.shrink();

    // Parse the PayNow URL
    final PayNowParseResult? parsed =
        PayNowService.parsePayNowURL(_generatedQR!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PayNow QR Code Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (parsed != null) ...[
              _buildDetailRow(
                  'Type',
                  _amount != null
                      ? 'Dynamic (with amount)'
                      : 'Static (amount editable)'),
              _buildDetailRow('Payment Method', 'PayNow'),
              _buildDetailRow('Currency', _currency.name.toUpperCase()),
              if (parsed.amount != null)
                _buildDetailRow('Amount',
                    '${_getCurrencySymbol(_currency)}${parsed.amount!.toStringAsFixed(2)}'),
              _buildDetailRow(
                  'PayNow ID Type', _getIdentifierTypeName(_identifierType)),
              _buildDetailRow('PayNow ID', parsed.proxyValue),
              if (parsed.message != null)
                _buildDetailRow('Message', parsed.message!),
              _buildDetailRow('URL Format', 'Simple PayNow URL'),
            ] else ...[
              _buildDetailRow('Status', 'Invalid PayNow URL'),
            ],
            const SizedBox(height: 16),
            Text(
              'PayNow URL',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _generatedQR!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildShareTab() {
    if (_generatedQR == null) {
      return const Center(
        child: Text('Generate a QR code first to access sharing options'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sharing Options',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy QR Data'),
            subtitle: const Text('Copy raw QR string to clipboard'),
            onTap: () => _copyToClipboard(_generatedQR!),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share as Text'),
            subtitle: const Text('Share QR data as text message'),
            onTap: () => _shareQR(_generatedQR!),
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Share as Image'),
            subtitle: const Text('Generate and share QR code image'),
            onTap: () => _shareQRImage(),
          ),
          ListTile(
            leading: const Icon(Icons.save),
            title: const Text('Save to Device'),
            subtitle: const Text('Save QR code image to device storage'),
            onTap: () => _saveQR(_generatedQR!),
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Create QR Package'),
            subtitle: const Text(
                'Create package with image, data, and documentation'),
            onTap: () => _createQRPackage(),
          ),
          const SizedBox(height: 24),
          Text(
            'Styling Options',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStylePreview('Default', QRStylingOptions.minimal()),
              _buildStylePreview(
                  'Singapore', QRStylingOptions.singaporeTheme()),
              _buildStylePreview(
                  'Professional', QRStylingOptions.professional()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStylePreview(String name, QRStylingOptions styling) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: QRDisplayWidget(
            qrData: _generatedQR!,
            styling: styling.copyWith(size: 60),
            interactive: false,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PayNow QR Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            'What is PayNow?',
            'PayNow is Singapore\'s national peer-to-peer fund transfer service that enables instant transfers using mobile numbers, NRIC, or UEN. This implementation uses simple PayNow URLs for compatibility with banking apps.',
            Icons.account_balance_wallet,
          ),
          _buildInfoCard(
            'PayNow URL Format',
            'PayNow QR codes use simple URLs like PAYNOW://0/[MOBILE]?amount=[AMOUNT]&message=[MESSAGE]. This is simpler and more compatible than complex SGQR formatting.',
            Icons.link,
          ),
          _buildInfoCard(
            'Static vs Dynamic QR',
            'Static QR codes allow customers to enter any amount, while Dynamic QR codes have a fixed amount pre-set by the merchant.',
            Icons.compare_arrows,
          ),
          _buildInfoCard(
            'Supported Features',
            '• PayNow mobile, UEN, and NRIC identifiers\n• Simple URL format for better compatibility\n• Works with all Singapore banking apps\n• Customizable styling and branding\n• Offline-first operation',
            Icons.check_circle,
          ),
          const SizedBox(height: 16),
          Text(
            'Module Information',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          _buildDetailRow('Version', paymentModuleVersion),
          _buildDetailRow('Build Date', paymentModuleBuildDate),
          _buildDetailRow('SGQR Spec', supportedSGQRVersion),
          _buildDetailRow('EMVCo Spec', supportedEMVCoVersion),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String content, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(content),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(String data) async {
    await Clipboard.setData(ClipboardData(text: data));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR data copied to clipboard')),
      );
    }
  }

  Future<void> _shareQR(String data) async {
    final bool success = await QRSharingService.shareQRText(
      qrData: data,
      subject: 'PayNow QR Code',
      text: 'PayNow QR Code from $_merchantName: $data',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(success ? 'QR shared successfully' : 'Failed to share QR'),
        ),
      );
    }
  }

  Future<void> _shareQRImage() async {
    final bool success = await QRSharingService.shareQRImage(
      qrData: _generatedQR!,
      styling: QRStylingOptions.singaporeTheme(),
      branding: QRBrandingOptions.payNow(
        merchantName: _merchantName,
        amount: _amount?.toStringAsFixed(2),
      ),
      subject: 'PayNow QR Code',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'QR image shared successfully'
              : 'Failed to share QR image'),
        ),
      );
    }
  }

  Future<void> _saveQR(String data) async {
    final QRSaveResult result = await QRSharingService.saveQRToDevice(
      qrData: data,
      styling: QRStylingOptions.singaporeTheme(),
      branding: QRBrandingOptions.payNow(
        merchantName: _merchantName,
        amount: _amount?.toStringAsFixed(2),
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success
              ? 'QR saved to ${result.filePath}'
              : 'Failed to save QR: ${result.errors.join(', ')}'),
        ),
      );
    }
  }

  Future<void> _createQRPackage() async {
    final QRPackageResult result = await QRSharingService.createQRPackage(
      qrData: _generatedQR!,
      merchantName: _merchantName,
      styling: QRStylingOptions.singaporeTheme(),
      branding: QRBrandingOptions.payNow(
        merchantName: _merchantName,
        amount: _amount?.toStringAsFixed(2),
      ),
      metadata: {
        'currency': _currency.value,
        'identifier_type': _identifierType.value,
        'identifier': _payNowIdentifier,
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success
              ? 'QR package created at ${result.packagePath}'
              : 'Failed to create package: ${result.errors.join(', ')}'),
        ),
      );
    }
  }

  String _getIdentifierTypeName(PayNowIdentifierType type) {
    switch (type) {
      case PayNowIdentifierType.mobile:
        return 'Mobile Number';
      case PayNowIdentifierType.uen:
        return 'UEN';
      case PayNowIdentifierType.nric:
        return 'NRIC';
    }
  }

  String _getIdentifierLabel(PayNowIdentifierType type) {
    switch (type) {
      case PayNowIdentifierType.mobile:
        return 'Mobile Number';
      case PayNowIdentifierType.uen:
        return 'UEN';
      case PayNowIdentifierType.nric:
        return 'NRIC';
    }
  }

  String _getIdentifierHelp(PayNowIdentifierType type) {
    switch (type) {
      case PayNowIdentifierType.mobile:
        return 'Singapore mobile number (8 digits)';
      case PayNowIdentifierType.uen:
        return 'Unique Entity Number';
      case PayNowIdentifierType.nric:
        return 'NRIC/FIN (e.g., S1234567A)';
    }
  }

  String _getCurrencySymbol(CurrencyCode currency) {
    switch (currency) {
      case CurrencyCode.sgd:
        return 'S\$';
      case CurrencyCode.usd:
        return '\$';
      case CurrencyCode.eur:
        return '€';
      case CurrencyCode.jpy:
        return '¥';
      case CurrencyCode.gbp:
        return '£';
      case CurrencyCode.aud:
        return 'A\$';
      case CurrencyCode.cad:
        return 'C\$';
      case CurrencyCode.hkd:
        return 'HK\$';
      case CurrencyCode.myr:
        return 'RM';
      case CurrencyCode.thb:
        return '฿';
      case CurrencyCode.cny:
        return '¥';
      case CurrencyCode.inr:
        return '₹';
    }
  }
}
