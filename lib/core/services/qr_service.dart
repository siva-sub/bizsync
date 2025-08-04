import 'dart:typed_data';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../error/exceptions.dart';

class QRService {
  static final QRService _instance = QRService._internal();
  factory QRService() => _instance;
  QRService._internal();

  /// Generate QR code widget for display
  Widget generateQRWidget({
    required String data,
    double? size,
    Color? foregroundColor,
    Color? backgroundColor,
  }) {
    try {
      return QrImageView(
        data: data,
        version: QrVersions.auto,
        size: size ?? AppConstants.qrCodeSize.toDouble(),
        backgroundColor: backgroundColor ?? Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: foregroundColor ?? Colors.black,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: foregroundColor ?? Colors.black,
        ),
      );
    } catch (e) {
      throw BizSyncException('Failed to generate QR code widget: $e');
    }
  }

  /// Generate QR code as image bytes
  Future<Uint8List> generateQRBytes({
    required String data,
    int? size,
    Color? foregroundColor,
    Color? backgroundColor,
  }) async {
    try {
      final qrPainter = QrPainter(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: foregroundColor ?? Colors.black,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: foregroundColor ?? Colors.black,
        ),
      );

      final picData = await qrPainter.toImageData(
        size?.toDouble() ?? AppConstants.qrCodeSize.toDouble(),
      );

      if (picData == null) {
        throw BizSyncException('Failed to generate QR code image data');
      }

      return picData.buffer.asUint8List();
    } catch (e) {
      throw BizSyncException('Failed to generate QR code bytes: $e');
    }
  }

  /// Create QR data for business contact sharing
  String createBusinessContactQR({
    required String businessName,
    String? ownerName,
    String? email,
    String? phone,
    String? address,
  }) {
    final vCard = StringBuffer();
    vCard.writeln('BEGIN:VCARD');
    vCard.writeln('VERSION:3.0');
    vCard.writeln('FN:$businessName');

    if (ownerName != null) {
      vCard.writeln('N:$ownerName');
    }

    if (email != null) {
      vCard.writeln('EMAIL:$email');
    }

    if (phone != null) {
      vCard.writeln('TEL:$phone');
    }

    if (address != null) {
      vCard.writeln('ADR:;;$address');
    }

    vCard.writeln('ORG:$businessName');
    vCard.writeln('END:VCARD');

    return vCard.toString();
  }

  /// Create QR data for product information
  String createProductQR({
    required String productId,
    required String name,
    required double price,
    String? description,
    String? category,
  }) {
    final productData = {
      'type': 'product',
      'id': productId,
      'name': name,
      'price': price,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Convert to simple string format for QR
    final buffer = StringBuffer();
    buffer.write('PRODUCT:');
    buffer.write('ID=$productId;');
    buffer.write('NAME=$name;');
    buffer.write('PRICE=$price;');

    if (description != null) {
      buffer.write('DESC=$description;');
    }

    if (category != null) {
      buffer.write('CAT=$category;');
    }

    return buffer.toString();
  }

  /// Create QR data for P2P connection
  String createP2PConnectionQR({
    required String deviceId,
    required String deviceName,
    required String connectionKey,
  }) {
    final connectionData = {
      'type': 'p2p_connection',
      'device_id': deviceId,
      'device_name': deviceName,
      'connection_key': connectionKey,
      'app': AppConstants.appName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Convert to simple string format for QR
    final buffer = StringBuffer();
    buffer.write('BIZSYNC_P2P:');
    buffer.write('ID=$deviceId;');
    buffer.write('NAME=$deviceName;');
    buffer.write('KEY=$connectionKey;');

    return buffer.toString();
  }

  /// Parse QR data to determine type and extract information
  Map<String, dynamic> parseQRData(String qrData) {
    try {
      if (qrData.startsWith('BEGIN:VCARD')) {
        return _parseVCard(qrData);
      } else if (qrData.startsWith('PRODUCT:')) {
        return _parseProductData(qrData);
      } else if (qrData.startsWith('BIZSYNC_P2P:')) {
        return _parseP2PData(qrData);
      } else {
        return {
          'type': 'unknown',
          'data': qrData,
        };
      }
    } catch (e) {
      throw BizSyncException('Failed to parse QR data: $e');
    }
  }

  Map<String, dynamic> _parseVCard(String vCard) {
    final result = <String, dynamic>{'type': 'vcard'};
    final lines = vCard.split('\n');

    for (final line in lines) {
      if (line.startsWith('FN:')) {
        result['name'] = line.substring(3);
      } else if (line.startsWith('EMAIL:')) {
        result['email'] = line.substring(6);
      } else if (line.startsWith('TEL:')) {
        result['phone'] = line.substring(4);
      } else if (line.startsWith('ADR:')) {
        result['address'] = line.substring(4);
      } else if (line.startsWith('ORG:')) {
        result['organization'] = line.substring(4);
      }
    }

    return result;
  }

  Map<String, dynamic> _parseProductData(String productData) {
    final result = <String, dynamic>{'type': 'product'};
    final data = productData.substring(8); // Remove 'PRODUCT:'
    final parts = data.split(';');

    for (final part in parts) {
      if (part.isEmpty) continue;

      final keyValue = part.split('=');
      if (keyValue.length == 2) {
        final key = keyValue[0];
        final value = keyValue[1];

        switch (key) {
          case 'ID':
            result['id'] = value;
            break;
          case 'NAME':
            result['name'] = value;
            break;
          case 'PRICE':
            result['price'] = double.tryParse(value) ?? 0.0;
            break;
          case 'DESC':
            result['description'] = value;
            break;
          case 'CAT':
            result['category'] = value;
            break;
        }
      }
    }

    return result;
  }

  Map<String, dynamic> _parseP2PData(String p2pData) {
    final result = <String, dynamic>{'type': 'p2p_connection'};
    final data = p2pData.substring(12); // Remove 'BIZSYNC_P2P:'
    final parts = data.split(';');

    for (final part in parts) {
      if (part.isEmpty) continue;

      final keyValue = part.split('=');
      if (keyValue.length == 2) {
        final key = keyValue[0];
        final value = keyValue[1];

        switch (key) {
          case 'ID':
            result['device_id'] = value;
            break;
          case 'NAME':
            result['device_name'] = value;
            break;
          case 'KEY':
            result['connection_key'] = value;
            break;
        }
      }
    }

    return result;
  }
}
