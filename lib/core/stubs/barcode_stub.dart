/// Stub implementation for barcode/QR code scanning functionality
/// This is used when the actual mobile_scanner package is not available or disabled

// Required imports for the stub to work
import 'package:flutter/material.dart';

class BarcodeCapture {
  final List<Barcode> barcodes;
  
  const BarcodeCapture({required this.barcodes});
}

class Barcode {
  final String? rawValue;
  final BarcodeType type;
  
  const Barcode({
    this.rawValue,
    this.type = BarcodeType.unknown,
  });
}

enum BarcodeType {
  unknown,
  qrCode,
  code128,
  code39,
  ean13,
  ean8,
  upcA,
}

enum BarcodeFormat {
  all,
  aztec,
  codabar,
  code39,
  code93,
  code128,
  dataMatrix,
  ean8,
  ean13,
  itf,
  maxiCode,
  pdf417,
  qrCode,
  rss14,
  rssExpanded,
  upcA,
  upcE,
  upcEanExtension,
}

class MobileScannerController {
  static const Duration _defaultDelay = Duration(milliseconds: 250);
  
  final Duration detectionSpeed;
  final List<BarcodeFormat> formats;
  final bool detectionTimeoutMs;
  final bool returnImage;
  
  MobileScannerController({
    this.detectionSpeed = _defaultDelay,
    this.formats = const [],
    this.detectionTimeoutMs = false,
    this.returnImage = false,
  });
  
  /// Stub method - always throws UnimplementedError
  Future<void> start() {
    throw UnimplementedError('QR scanning is disabled in minimal build');
  }
  
  /// Stub method - always throws UnimplementedError
  Future<void> stop() {
    throw UnimplementedError('QR scanning is disabled in minimal build');
  }
  
  /// Stub method - always throws UnimplementedError
  void dispose() {
    throw UnimplementedError('QR scanning is disabled in minimal build');
  }
  
  /// Stub method - always throws UnimplementedError
  Future<void> toggleTorch() {
    throw UnimplementedError('QR scanning is disabled in minimal build');
  }
  
  /// Stub method - always throws UnimplementedError
  Future<void> switchCamera() {
    throw UnimplementedError('QR scanning is disabled in minimal build');
  }
}

class MobileScanner extends StatelessWidget {
  final MobileScannerController? controller;
  final void Function(BarcodeCapture)? onDetect;
  final Widget? errorBuilder;
  final Widget? placeholderBuilder;
  
  const MobileScanner({
    super.key,
    this.controller,
    this.onDetect,
    this.errorBuilder,
    this.placeholderBuilder,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'QR Scanner Not Available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'QR scanning is disabled in this build',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}