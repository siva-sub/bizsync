import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
// import 'package:share_plus/share_plus.dart'; // Uncomment when adding to pubspec.yaml

import '../models/sgqr_models.dart';
import 'qr_image_service.dart';

/// QR Sharing and Saving Service
class QRSharingService {
  /// Share QR code as text
  static Future<bool> shareQRText({
    required String qrData,
    String? subject,
    String? text,
  }) async {
    try {
      final String shareText = text ?? 'PayNow QR Code: $qrData';
      
      // Using Share.share - uncomment when share_plus is added
      // await Share.share(
      //   shareText,
      //   subject: subject ?? 'PayNow QR Code',
      // );
      
      // Fallback: Copy to clipboard
      await Clipboard.setData(ClipboardData(text: qrData));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Share QR code as image
  static Future<bool> shareQRImage({
    required String qrData,
    QRStylingOptions styling = const QRStylingOptions(),
    QRBrandingOptions? branding,
    String? subject,
    String? text,
  }) async {
    try {
      // Generate QR image
      final QRImageResult imageResult = await QRImageService.generateQRImage(
        data: qrData,
        styling: styling,
        branding: branding,
        saveToFile: true,
        fileName: 'qr_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      if (!imageResult.success || imageResult.imagePath == null) {
        return false;
      }

      // Share image file - uncomment when share_plus is added
      // await Share.shareXFiles(
      //   [XFile(imageResult.imagePath!)],
      //   subject: subject ?? 'PayNow QR Code',
      //   text: text ?? 'Scan this QR code to make a payment',
      // );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Save QR code to device storage
  static Future<QRSaveResult> saveQRToDevice({
    required String qrData,
    QRStylingOptions styling = const QRStylingOptions(),
    QRBrandingOptions? branding,
    String? fileName,
    String? customPath,
  }) async {
    try {
      // Generate QR image
      final QRImageResult imageResult = await QRImageService.generateQRImage(
        data: qrData,
        styling: styling,
        branding: branding,
        saveToFile: false,
      );

      if (!imageResult.success || imageResult.imageBytes == null) {
        return QRSaveResult.failure(
          errors: ['Failed to generate QR image'],
        );
      }

      // Determine save location
      String savePath;
      if (customPath != null) {
        savePath = customPath;
      } else {
        final Directory directory = await getApplicationDocumentsDirectory();
        final String finalFileName = fileName ?? 'payNow_qr_${DateTime.now().millisecondsSinceEpoch}.png';
        savePath = '${directory.path}/$finalFileName';
      }

      // Save to file
      final File file = File(savePath);
      await file.writeAsBytes(imageResult.imageBytes!);

      return QRSaveResult.success(
        filePath: savePath,
        fileSize: imageResult.imageBytes!.length,
      );

    } catch (e) {
      return QRSaveResult.failure(
        errors: ['Failed to save QR code: $e'],
      );
    }
  }

  /// Save QR data as text file
  static Future<QRSaveResult> saveQRDataAsText({
    required String qrData,
    Map<String, dynamic>? metadata,
    String? fileName,
    String? customPath,
  }) async {
    try {
      // Prepare content
      final StringBuffer content = StringBuffer();
      content.writeln('PayNow QR Code Data');
      content.writeln('Generated: ${DateTime.now().toIso8601String()}');
      content.writeln('');
      
      if (metadata != null) {
        content.writeln('Metadata:');
        metadata.forEach((key, value) {
          content.writeln('  $key: $value');
        });
        content.writeln('');
      }
      
      content.writeln('QR Data:');
      content.writeln(qrData);

      // Determine save location
      String savePath;
      if (customPath != null) {
        savePath = customPath;
      } else {
        final Directory directory = await getApplicationDocumentsDirectory();
        final String finalFileName = fileName ?? 'payNow_qr_data_${DateTime.now().millisecondsSinceEpoch}.txt';
        savePath = '${directory.path}/$finalFileName';
      }

      // Save to file
      final File file = File(savePath);
      await file.writeAsString(content.toString());

      return QRSaveResult.success(
        filePath: savePath,
        fileSize: content.toString().length,
      );

    } catch (e) {
      return QRSaveResult.failure(
        errors: ['Failed to save QR data: $e'],
      );
    }
  }

  /// Create shareable QR package (image + data)
  static Future<QRPackageResult> createQRPackage({
    required String qrData,
    required String merchantName,
    QRStylingOptions styling = const QRStylingOptions(),
    QRBrandingOptions? branding,
    Map<String, dynamic>? metadata,
    String? packageName,
  }) async {
    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String finalPackageName = packageName ?? 'payNow_qr_package_$timestamp';
      
      // Create package directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory packageDir = Directory('${appDir.path}/$finalPackageName');
      
      if (!await packageDir.exists()) {
        await packageDir.create(recursive: true);
      }

      final List<String> createdFiles = [];
      final List<String> errors = [];

      // Save QR image
      final QRImageResult imageResult = await QRImageService.generateQRImage(
        data: qrData,
        styling: styling,
        branding: branding,
        saveToFile: true,
        fileName: '${packageDir.path}/qr_code.png',
      );

      if (imageResult.success && imageResult.imagePath != null) {
        createdFiles.add(imageResult.imagePath!);
      } else {
        errors.add('Failed to create QR image');
      }

      // Save QR data
      final QRSaveResult dataResult = await saveQRDataAsText(
        qrData: qrData,
        metadata: {
          'merchant_name': merchantName,
          'package_created': DateTime.now().toIso8601String(),
          ...?metadata,
        },
        customPath: '${packageDir.path}/qr_data.txt',
      );

      if (dataResult.success && dataResult.filePath != null) {
        createdFiles.add(dataResult.filePath!);
      } else {
        errors.addAll(dataResult.errors);
      }

      // Create README file
      final String readmeContent = '''
PayNow QR Code Package
=====================

Generated: ${DateTime.now()}
Merchant: $merchantName

Files included:
- qr_code.png: QR code image for display/printing
- qr_data.txt: Raw QR data and metadata

Instructions:
1. Display or print the QR code image
2. Customers can scan with any PayNow-enabled app
3. QR data can be used to regenerate the code if needed

Generated by BizSync Payment System
''';

      final File readmeFile = File('${packageDir.path}/README.txt');
      await readmeFile.writeAsString(readmeContent);
      createdFiles.add(readmeFile.path);

      return QRPackageResult.success(
        packagePath: packageDir.path,
        createdFiles: createdFiles,
        errors: errors,
      );

    } catch (e) {
      return QRPackageResult.failure(
        errors: ['Failed to create QR package: $e'],
      );
    }
  }

  /// Copy QR data to clipboard
  static Future<bool> copyQRToClipboard(String qrData) async {
    try {
      await Clipboard.setData(ClipboardData(text: qrData));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get QR data from clipboard
  static Future<String?> getQRFromClipboard() async {
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (e) {
      return null;
    }
  }

  /// Print QR code (for platforms that support printing)
  static Future<bool> printQR({
    required String qrData,
    QRStylingOptions styling = const QRStylingOptions(),
    QRBrandingOptions? branding,
  }) async {
    try {
      // Generate printable QR image
      final QRImageResult imageResult = await QRImageService.generateQRImage(
        data: qrData,
        styling: styling.copyWith(
          size: 400, // Larger size for printing
          errorCorrectionLevel: QrErrorCorrectLevel.H, // High error correction
        ),
        branding: branding,
        saveToFile: true,
        fileName: 'qr_print_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      if (!imageResult.success) {
        return false;
      }

      // Here you would integrate with a printing service
      // For now, just return success if image was generated
      return true;

    } catch (e) {
      return false;
    }
  }

  /// Batch export multiple QR codes
  static Future<QRBatchExportResult> batchExportQRs({
    required List<String> qrDataList,
    required List<String> merchantNames,
    QRStylingOptions styling = const QRStylingOptions(),
    List<QRBrandingOptions>? brandingList,
    String? batchName,
  }) async {
    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String finalBatchName = batchName ?? 'qr_batch_$timestamp';
      
      // Create batch directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory batchDir = Directory('${appDir.path}/$finalBatchName');
      
      if (!await batchDir.exists()) {
        await batchDir.create(recursive: true);
      }

      final List<String> successFiles = [];
      final List<String> errors = [];

      for (int i = 0; i < qrDataList.length; i++) {
        try {
          final String qrData = qrDataList[i];
          final String merchantName = i < merchantNames.length ? merchantNames[i] : 'Merchant ${i + 1}';
          final QRBrandingOptions? branding = brandingList?[i];

          // Create individual QR package
          final QRPackageResult packageResult = await createQRPackage(
            qrData: qrData,
            merchantName: merchantName,
            styling: styling,
            branding: branding,
            packageName: '${batchDir.path}/qr_${i + 1}_${merchantName.replaceAll(' ', '_')}',
          );

          if (packageResult.success) {
            successFiles.addAll(packageResult.createdFiles);
          } else {
            errors.addAll(packageResult.errors);
          }

        } catch (e) {
          errors.add('Failed to export QR ${i + 1}: $e');
        }
      }

      // Create batch summary
      final String summaryContent = '''
QR Code Batch Export Summary
============================

Batch: $finalBatchName
Generated: ${DateTime.now()}
Total QR Codes: ${qrDataList.length}
Successful: ${successFiles.length ~/ 3} // 3 files per QR package
Failed: ${errors.length}

${errors.isNotEmpty ? 'Errors:\n${errors.map((e) => '- $e').join('\n')}' : 'All QR codes exported successfully!'}
''';

      final File summaryFile = File('${batchDir.path}/batch_summary.txt');
      await summaryFile.writeAsString(summaryContent);
      successFiles.add(summaryFile.path);

      return QRBatchExportResult.success(
        batchPath: batchDir.path,
        successfulExports: successFiles.length ~/ 3,
        totalExports: qrDataList.length,
        createdFiles: successFiles,
        errors: errors,
      );

    } catch (e) {
      return QRBatchExportResult.failure(
        errors: ['Failed to batch export QR codes: $e'],
      );
    }
  }
}

/// QR Save Result
class QRSaveResult {
  final bool success;
  final String? filePath;
  final int? fileSize;
  final List<String> errors;

  const QRSaveResult({
    required this.success,
    this.filePath,
    this.fileSize,
    this.errors = const [],
  });

  factory QRSaveResult.success({
    required String filePath,
    required int fileSize,
  }) {
    return QRSaveResult(
      success: true,
      filePath: filePath,
      fileSize: fileSize,
    );
  }

  factory QRSaveResult.failure({
    required List<String> errors,
  }) {
    return QRSaveResult(
      success: false,
      errors: errors,
    );
  }
}

/// QR Package Result
class QRPackageResult {
  final bool success;
  final String? packagePath;
  final List<String> createdFiles;
  final List<String> errors;

  const QRPackageResult({
    required this.success,
    this.packagePath,
    this.createdFiles = const [],
    this.errors = const [],
  });

  factory QRPackageResult.success({
    required String packagePath,
    required List<String> createdFiles,
    List<String> errors = const [],
  }) {
    return QRPackageResult(
      success: true,
      packagePath: packagePath,
      createdFiles: createdFiles,
      errors: errors,
    );
  }

  factory QRPackageResult.failure({
    required List<String> errors,
  }) {
    return QRPackageResult(
      success: false,
      errors: errors,
    );
  }
}

/// QR Batch Export Result
class QRBatchExportResult {
  final bool success;
  final String? batchPath;
  final int successfulExports;
  final int totalExports;
  final List<String> createdFiles;
  final List<String> errors;

  const QRBatchExportResult({
    required this.success,
    this.batchPath,
    this.successfulExports = 0,
    this.totalExports = 0,
    this.createdFiles = const [],
    this.errors = const [],
  });

  factory QRBatchExportResult.success({
    required String batchPath,
    required int successfulExports,
    required int totalExports,
    required List<String> createdFiles,
    List<String> errors = const [],
  }) {
    return QRBatchExportResult(
      success: true,
      batchPath: batchPath,
      successfulExports: successfulExports,
      totalExports: totalExports,
      createdFiles: createdFiles,
      errors: errors,
    );
  }

  factory QRBatchExportResult.failure({
    required List<String> errors,
  }) {
    return QRBatchExportResult(
      success: false,
      errors: errors,
    );
  }

  double get successRate => totalExports > 0 ? successfulExports / totalExports : 0.0;
}

/// Extension for QRStylingOptions to support copying
extension QRStylingOptionsExtension on QRStylingOptions {
  QRStylingOptions copyWith({
    Color? foregroundColor,
    Color? backgroundColor,
    double? size,
    int? errorCorrectionLevel,
    EdgeInsets? padding,
    BorderRadius? borderRadius,
    BoxShadow? shadow,
    Gradient? gradient,
  }) {
    return QRStylingOptions(
      foregroundColor: foregroundColor ?? this.foregroundColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      size: size ?? this.size,
      errorCorrectionLevel: errorCorrectionLevel ?? this.errorCorrectionLevel,
      padding: padding ?? this.padding,
      borderRadius: borderRadius ?? this.borderRadius,
      shadow: shadow ?? this.shadow,
      gradient: gradient ?? this.gradient,
    );
  }
}