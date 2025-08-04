import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// QR code styling options
class QRStylingOptions {
  final Color foregroundColor;
  final Color backgroundColor;
  final double size;
  final int errorCorrectionLevel;
  final EdgeInsets padding;
  final BorderRadius? borderRadius;
  final BoxShadow? shadow;
  final Gradient? gradient;

  const QRStylingOptions({
    this.foregroundColor = Colors.black,
    this.backgroundColor = Colors.white,
    this.size = 300.0,
    this.errorCorrectionLevel = QrErrorCorrectLevel.M,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius,
    this.shadow,
    this.gradient,
  });

  /// Default Singapore themed styling
  factory QRStylingOptions.singaporeTheme() {
    return QRStylingOptions(
      foregroundColor: const Color(0xFF003366), // Singapore blue
      backgroundColor: Colors.white,
      size: 300.0,
      padding: const EdgeInsets.all(20.0),
      borderRadius: BorderRadius.circular(12.0),
      shadow: const BoxShadow(
        color: Colors.black12,
        blurRadius: 8.0,
        offset: Offset(0, 4),
      ),
    );
  }

  /// Business professional styling
  factory QRStylingOptions.professional() {
    return QRStylingOptions(
      foregroundColor: const Color(0xFF2C3E50),
      backgroundColor: Colors.white,
      size: 350.0,
      padding: const EdgeInsets.all(24.0),
      borderRadius: BorderRadius.circular(16.0),
      shadow: const BoxShadow(
        color: Colors.black26,
        blurRadius: 12.0,
        offset: Offset(0, 6),
      ),
    );
  }

  /// Minimal styling
  factory QRStylingOptions.minimal() {
    return const QRStylingOptions(
      foregroundColor: Colors.black,
      backgroundColor: Colors.transparent,
      size: 250.0,
      padding: EdgeInsets.all(8.0),
    );
  }

  /// High contrast styling for better readability
  factory QRStylingOptions.highContrast() {
    return const QRStylingOptions(
      foregroundColor: Colors.black,
      backgroundColor: Colors.white,
      size: 400.0,
      padding: EdgeInsets.all(32.0),
      errorCorrectionLevel: QrErrorCorrectLevel.H,
    );
  }
}

/// Logo embedding options
class LogoEmbedOptions {
  final String? logoPath;
  final Uint8List? logoBytes;
  final double logoSize;
  final EdgeInsets logoMargin;
  final BorderRadius? logoBorderRadius;
  final Color? logoBackgroundColor;
  final bool addLogoBackground;

  const LogoEmbedOptions({
    this.logoPath,
    this.logoBytes,
    this.logoSize = 60.0,
    this.logoMargin = const EdgeInsets.all(8.0),
    this.logoBorderRadius,
    this.logoBackgroundColor = Colors.white,
    this.addLogoBackground = true,
  });

  bool get hasLogo => logoPath != null || logoBytes != null;
}

/// QR code branding options
class QRBrandingOptions {
  final String? title;
  final String? subtitle;
  final String? footer;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final TextStyle? footerStyle;
  final Color? brandColor;
  final LogoEmbedOptions? logo;

  const QRBrandingOptions({
    this.title,
    this.subtitle,
    this.footer,
    this.titleStyle,
    this.subtitleStyle,
    this.footerStyle,
    this.brandColor,
    this.logo,
  });

  /// PayNow branding
  factory QRBrandingOptions.payNow({
    String? merchantName,
    String? amount,
  }) {
    return QRBrandingOptions(
      title: 'PayNow QR',
      subtitle: merchantName,
      footer: amount != null ? 'Amount: \$${amount}' : 'Scan to Pay',
      titleStyle: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFF003366),
      ),
      subtitleStyle: const TextStyle(
        fontSize: 16,
        color: Colors.black87,
      ),
      footerStyle: const TextStyle(
        fontSize: 14,
        color: Colors.grey,
      ),
      brandColor: const Color(0xFF003366),
    );
  }

  /// Business branding
  factory QRBrandingOptions.business({
    required String businessName,
    String? tagline,
    Color? brandColor,
  }) {
    return QRBrandingOptions(
      title: businessName,
      subtitle: tagline,
      footer: 'Scan to Pay',
      titleStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: brandColor ?? Colors.black,
      ),
      subtitleStyle: const TextStyle(
        fontSize: 14,
        color: Colors.black54,
      ),
      footerStyle: const TextStyle(
        fontSize: 12,
        color: Colors.grey,
      ),
      brandColor: brandColor,
    );
  }
}

/// QR image generation result
class QRImageResult {
  final bool success;
  final Uint8List? imageBytes;
  final String? imagePath;
  final Size? imageSize;
  final List<String> errors;

  const QRImageResult({
    required this.success,
    this.imageBytes,
    this.imagePath,
    this.imageSize,
    this.errors = const [],
  });

  factory QRImageResult.success({
    required Uint8List imageBytes,
    String? imagePath,
    Size? imageSize,
  }) {
    return QRImageResult(
      success: true,
      imageBytes: imageBytes,
      imagePath: imagePath,
      imageSize: imageSize,
    );
  }

  factory QRImageResult.failure({
    required List<String> errors,
  }) {
    return QRImageResult(
      success: false,
      errors: errors,
    );
  }
}

/// QR Image Service for generating customized QR code images
class QRImageService {
  /// Generate QR code image with styling and branding
  static Future<QRImageResult> generateQRImage({
    required String data,
    QRStylingOptions styling = const QRStylingOptions(),
    QRBrandingOptions? branding,
    bool saveToFile = false,
    String? fileName,
  }) async {
    try {
      // Create QR widget
      final Widget qrWidget = _buildQRWidget(
        data: data,
        styling: styling,
        branding: branding,
      );

      // Convert widget to image
      final Uint8List imageBytes = await _widgetToImage(
        qrWidget,
        styling.size + styling.padding.horizontal,
        _calculateTotalHeight(styling, branding),
      );

      String? savedPath;
      if (saveToFile) {
        savedPath = await _saveImageToFile(imageBytes, fileName);
      }

      return QRImageResult.success(
        imageBytes: imageBytes,
        imagePath: savedPath,
        imageSize: Size(
          styling.size + styling.padding.horizontal,
          _calculateTotalHeight(styling, branding),
        ),
      );
    } catch (e) {
      return QRImageResult.failure(
        errors: ['Failed to generate QR image: $e'],
      );
    }
  }

  /// Build QR widget with styling and branding
  static Widget _buildQRWidget({
    required String data,
    required QRStylingOptions styling,
    QRBrandingOptions? branding,
  }) {
    return Container(
      padding: styling.padding,
      decoration: BoxDecoration(
        color: styling.backgroundColor,
        borderRadius: styling.borderRadius,
        boxShadow: styling.shadow != null ? [styling.shadow!] : null,
        gradient: styling.gradient,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          if (branding?.title != null) ...[
            Text(
              branding!.title!,
              style: branding.titleStyle ??
                  const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],

          // Subtitle
          if (branding?.subtitle != null) ...[
            Text(
              branding!.subtitle!,
              style: branding.subtitleStyle ??
                  const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],

          // QR Code with optional logo
          Stack(
            alignment: Alignment.center,
            children: [
              // QR Code
              QrImageView(
                data: data,
                version: QrVersions.auto,
                size: styling.size,
                backgroundColor: Colors.transparent,
                errorCorrectionLevel: styling.errorCorrectionLevel,
                padding: EdgeInsets.zero,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: styling.foregroundColor,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: styling.foregroundColor,
                ),
              ),

              // Logo overlay
              if (branding?.logo?.hasLogo == true)
                _buildLogoOverlay(branding!.logo!),
            ],
          ),

          // Footer
          if (branding?.footer != null) ...[
            const SizedBox(height: 16),
            Text(
              branding!.footer!,
              style: branding.footerStyle ??
                  const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Build logo overlay widget
  static Widget _buildLogoOverlay(LogoEmbedOptions logoOptions) {
    Widget logoWidget;

    if (logoOptions.logoBytes != null) {
      logoWidget = Image.memory(
        logoOptions.logoBytes!,
        width: logoOptions.logoSize,
        height: logoOptions.logoSize,
        fit: BoxFit.contain,
      );
    } else if (logoOptions.logoPath != null) {
      logoWidget = Image.file(
        File(logoOptions.logoPath!),
        width: logoOptions.logoSize,
        height: logoOptions.logoSize,
        fit: BoxFit.contain,
      );
    } else {
      return const SizedBox.shrink();
    }

    if (logoOptions.addLogoBackground) {
      logoWidget = Container(
        padding: logoOptions.logoMargin,
        decoration: BoxDecoration(
          color: logoOptions.logoBackgroundColor,
          borderRadius:
              logoOptions.logoBorderRadius ?? BorderRadius.circular(8),
        ),
        child: logoWidget,
      );
    }

    return logoWidget;
  }

  /// Convert widget to image bytes
  static Future<Uint8List> _widgetToImage(
    Widget widget,
    double width,
    double height,
  ) async {
    final RenderRepaintBoundary repaintBoundary = RenderRepaintBoundary();
    final RenderView renderView = RenderView(
      view: WidgetsBinding.instance.platformDispatcher.views.first,
      configuration: ViewConfiguration.fromView(
        WidgetsBinding.instance.platformDispatcher.views.first,
      ),
    );

    final PipelineOwner pipelineOwner = PipelineOwner();
    final BuildOwner buildOwner = BuildOwner();

    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final RenderObjectToWidgetElement<RenderBox> rootElement =
        RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: widget),
          ),
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final ui.Image image = await repaintBoundary.toImage(
      pixelRatio: 2.0,
    );

    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData!.buffer.asUint8List();
  }

  /// Save image bytes to file
  static Future<String> _saveImageToFile(
    Uint8List imageBytes,
    String? fileName,
  ) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath =
        '${directory.path}/${fileName ?? 'qr_code_${DateTime.now().millisecondsSinceEpoch}.png'}';
    final File file = File(filePath);
    await file.writeAsBytes(imageBytes);
    return filePath;
  }

  /// Calculate total height needed for the QR widget
  static double _calculateTotalHeight(
    QRStylingOptions styling,
    QRBrandingOptions? branding,
  ) {
    double height = styling.size + styling.padding.vertical;

    if (branding?.title != null) {
      height += 32; // Title height + spacing
    }

    if (branding?.subtitle != null) {
      height += 32; // Subtitle height + spacing
    }

    if (branding?.footer != null) {
      height += 32; // Footer height + spacing
    }

    return height;
  }

  /// Generate batch QR images
  static Future<List<QRImageResult>> generateBatchQRImages({
    required List<String> dataList,
    QRStylingOptions styling = const QRStylingOptions(),
    List<QRBrandingOptions>? brandingList,
    bool saveToFile = false,
    String? fileNamePrefix,
  }) async {
    final List<QRImageResult> results = [];

    for (int i = 0; i < dataList.length; i++) {
      final QRBrandingOptions? branding = brandingList?[i];
      final String? fileName = saveToFile
          ? '${fileNamePrefix ?? 'qr'}_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.png'
          : null;

      final QRImageResult result = await generateQRImage(
        data: dataList[i],
        styling: styling,
        branding: branding,
        saveToFile: saveToFile,
        fileName: fileName,
      );

      results.add(result);
    }

    return results;
  }

  /// Generate QR image with predefined PayNow styling
  static Future<QRImageResult> generatePayNowQRImage({
    required String sgqrData,
    required String merchantName,
    String? amount,
    bool saveToFile = false,
    String? fileName,
  }) {
    return generateQRImage(
      data: sgqrData,
      styling: QRStylingOptions.singaporeTheme(),
      branding: QRBrandingOptions.payNow(
        merchantName: merchantName,
        amount: amount,
      ),
      saveToFile: saveToFile,
      fileName: fileName,
    );
  }

  /// Generate business QR image
  static Future<QRImageResult> generateBusinessQRImage({
    required String sgqrData,
    required String businessName,
    String? tagline,
    Color? brandColor,
    LogoEmbedOptions? logo,
    bool saveToFile = false,
    String? fileName,
  }) {
    return generateQRImage(
      data: sgqrData,
      styling: QRStylingOptions.professional(),
      branding: QRBrandingOptions.business(
        businessName: businessName,
        tagline: tagline,
        brandColor: brandColor,
      ).copyWith(logo: logo),
      saveToFile: saveToFile,
      fileName: fileName,
    );
  }

  /// Validate QR data before image generation
  static List<String> validateQRData(String data) {
    final List<String> errors = [];

    if (data.isEmpty) {
      errors.add('QR data cannot be empty');
    }

    if (data.length > 4296) {
      errors.add('QR data exceeds maximum length (4296 characters)');
    }

    // Check for invalid characters
    if (data.contains(RegExp(r'[^\x20-\x7E]'))) {
      errors.add('QR data contains invalid characters');
    }

    return errors;
  }
}

/// Extension for QRBrandingOptions
extension QRBrandingOptionsExtension on QRBrandingOptions {
  QRBrandingOptions copyWith({
    String? title,
    String? subtitle,
    String? footer,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    TextStyle? footerStyle,
    Color? brandColor,
    LogoEmbedOptions? logo,
  }) {
    return QRBrandingOptions(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      footer: footer ?? this.footer,
      titleStyle: titleStyle ?? this.titleStyle,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      footerStyle: footerStyle ?? this.footerStyle,
      brandColor: brandColor ?? this.brandColor,
      logo: logo ?? this.logo,
    );
  }
}
