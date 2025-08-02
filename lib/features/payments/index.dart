/// SGQR/PayNow Payment Module for BizSync
/// 
/// This module provides comprehensive support for Singapore's SGQR and PayNow
/// payment systems, including QR code generation, multi-payment method support,
/// and customizable UI components.
/// 
/// Features:
/// - SGQR/PayNow QR code generation (static and dynamic)
/// - Support for mobile numbers, UEN, and NRIC identifiers
/// - Multi-payment method support (PayNow, NETS, international cards)
/// - CRC16 checksum validation
/// - EMVCo data object formatting
/// - Customizable QR code styling and branding
/// - QR code sharing and saving functionality
/// - Comprehensive validation and error handling
/// 
/// The implementation follows Singapore's SGQR specification and EMVCo standards
/// for QR code payment systems, ensuring compatibility with the local payment
/// ecosystem while supporting offline-first operations.

library payments;

// Data Models
export 'models/sgqr_models.dart';

// Core Services
export 'services/sgqr_generator_service.dart';
export 'services/paynow_service.dart';
export 'services/multi_payment_service.dart';
export 'services/qr_image_service.dart';
export 'services/qr_sharing_service.dart';

// Utilities
export 'utils/crc16_calculator.dart';
export 'utils/emvco_formatter.dart';

// UI Widgets
export 'widgets/qr_display_widget.dart';
export 'widgets/payment_method_selector.dart';
export 'widgets/amount_input_widget.dart';

/// Payment Module Version
const String paymentModuleVersion = '1.0.0';

/// Payment Module Build Date
const String paymentModuleBuildDate = '2025-01-01';

/// Supported SGQR Specification Version
const String supportedSGQRVersion = '1.1';

/// Supported EMVCo QR Code Specification Version
const String supportedEMVCoVersion = '1.1';