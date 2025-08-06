import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/stubs/barcode_stub.dart';
import '../models/sync_models.dart';
import '../services/p2p_sync_service.dart';

/// Dialog for device pairing with QR code and PIN options
class PairingDialog extends StatefulWidget {
  final DeviceInfo device;
  final P2PSyncService syncService;

  const PairingDialog({
    super.key,
    required this.device,
    required this.syncService,
  });

  @override
  State<PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<PairingDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  DevicePairing? _currentPairing;
  String? _errorMessage;
  bool _isLoading = false;
  StreamSubscription<DevicePairing>? _pairingSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Listen to pairing events
    // TODO: Fix authService implementation
    // _pairingSubscription = widget.syncService._authService.pairingEvents.listen(
    //   _onPairingEvent,
    // );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pairingSubscription?.cancel();
    super.dispose();
  }

  void _onPairingEvent(DevicePairing pairing) {
    if (pairing.remoteDeviceId == widget.device.deviceId) {
      setState(() {
        _currentPairing = pairing;
        _isLoading = false;

        if (pairing.state == PairingState.completed) {
          // Pairing successful
          Navigator.of(context).pop(true);
        } else if (pairing.state == PairingState.failed ||
            pairing.state == PairingState.expired) {
          _errorMessage = 'Pairing failed or expired';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  child: Icon(_getDeviceIcon(widget.device.deviceType)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pair with ${widget.device.deviceName}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${widget.device.platform} • ${widget.device.deviceType}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Error message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Tab bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Generate QR', icon: Icon(Icons.qr_code)),
                Tab(text: 'Scan QR', icon: Icon(Icons.qr_code_scanner)),
                Tab(text: 'PIN Code', icon: Icon(Icons.pin)),
              ],
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGenerateQRTab(),
                  _buildScanQRTab(),
                  _buildPinCodeTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateQRTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Show this QR code to the other device',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_currentPairing?.qrCode != null) ...[
            // QR Code display
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _currentPairing!.qrCode!,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Pairing status
            if (_currentPairing!.state == PairingState.codeGenerated)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 12),
                  Text('Waiting for other device to scan...'),
                ],
              )
            else if (_currentPairing!.state == PairingState.codeScanned)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('QR code scanned! Completing pairing...'),
                ],
              ),
          ] else ...[
            // Generate QR button
            Expanded(
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: _generateQRCode,
                        icon: const Icon(Icons.qr_code),
                        label: const Text('Generate QR Code'),
                      ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'QR code expires in 5 minutes',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScanQRTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Scan the QR code from the other device',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Camera view
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  onDetect: _onQRCodeDetected,
                  // TODO: Fix overlay parameter
                  // overlay: Container(
                  //   decoration: BoxDecoration(
                  //     border: Border.all(
                  //       color: Theme.of(context).primaryColor,
                  //       width: 2,
                  //     ),
                  //   ),
                  // ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Position the QR code within the frame',
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPinCodeTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Use a PIN code for pairing',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          if (_currentPairing?.pairingCode != null) ...[
            // Show generated PIN
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Share this PIN with the other device:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _currentPairing!.pairingCode!,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _currentPairing!.pairingCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('PIN copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy PIN'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (_currentPairing!.state == PairingState.codeGenerated)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 12),
                  Text('Waiting for PIN entry...'),
                ],
              ),
          ] else ...[
            // Generate PIN button
            Expanded(
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: _generatePINCode,
                        icon: const Icon(Icons.pin),
                        label: const Text('Generate PIN Code'),
                      ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // PIN entry section
          const Divider(),
          const SizedBox(height: 16),

          const Text(
            'Or enter PIN from other device:',
            style: TextStyle(fontSize: 14),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Enter 6-digit PIN',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onChanged: (value) {
                    if (value.length == 6) {
                      _processPINCode(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _generateQRCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pairing = await widget.syncService.initiatePairingWithQR(
        widget.device.deviceId,
      );

      setState(() {
        _currentPairing = pairing;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate QR code: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generatePINCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pairing = await widget.syncService.initiatePairingWithPIN(
        widget.device.deviceId,
      );

      setState(() {
        _currentPairing = pairing;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate PIN code: $e';
        _isLoading = false;
      });
    }
  }

  void _onQRCodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;

    if (barcodes.isNotEmpty) {
      final qrData = barcodes.first.rawValue;
      if (qrData != null) {
        _processQRCode(qrData);
      }
    }
  }

  Future<void> _processQRCode(String qrData) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pairing = await widget.syncService.processScannedQR(qrData);

      setState(() {
        _currentPairing = pairing;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid QR code: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _processPINCode(String pinCode) async {
    if (_currentPairing == null) {
      setState(() {
        _errorMessage = 'No active pairing session';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Fix authService implementation
      // await widget.syncService._authService.processPinCode(
      //   _currentPairing!.pairingId,
      //   pinCode,
      // );
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid PIN code: $e';
        _isLoading = false;
      });
    }
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'mobile':
        return Icons.phone_android;
      case 'desktop':
        return Icons.computer;
      case 'tablet':
        return Icons.tablet;
      default:
        return Icons.device_unknown;
    }
  }
}
