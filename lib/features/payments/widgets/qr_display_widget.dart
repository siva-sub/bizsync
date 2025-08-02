import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/sgqr_models.dart';
import '../services/qr_image_service.dart';

/// QR Display Widget for showing SGQR/PayNow QR codes
class QRDisplayWidget extends StatelessWidget {
  final String qrData;
  final QRStylingOptions? styling;
  final QRBrandingOptions? branding;
  final VoidCallback? onTap;
  final bool interactive;
  final Widget? overlay;

  const QRDisplayWidget({
    super.key,
    required this.qrData,
    this.styling,
    this.branding,
    this.onTap,
    this.interactive = true,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    final QRStylingOptions effectiveStyling = styling ?? const QRStylingOptions();
    
    Widget qrWidget = Container(
      padding: effectiveStyling.padding,
      decoration: BoxDecoration(
        color: effectiveStyling.backgroundColor,
        borderRadius: effectiveStyling.borderRadius,
        boxShadow: effectiveStyling.shadow != null ? [effectiveStyling.shadow!] : null,
        gradient: effectiveStyling.gradient,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          if (branding?.title != null) ...[
            Text(
              branding!.title!,
              style: branding!.titleStyle ?? Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],

          // Subtitle
          if (branding?.subtitle != null) ...[
            Text(
              branding!.subtitle!,
              style: branding!.subtitleStyle ?? Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],

          // QR Code
          Stack(
            alignment: Alignment.center,
            children: [
              QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: effectiveStyling.size,
                foregroundColor: effectiveStyling.foregroundColor,
                backgroundColor: Colors.transparent,
                errorCorrectionLevel: effectiveStyling.errorCorrectionLevel,
                padding: EdgeInsets.zero,
              ),
              
              // Logo overlay
              if (branding?.logo?.hasLogo == true)
                _buildLogoOverlay(branding!.logo!),
              
              // Custom overlay
              if (overlay != null) overlay!,
            ],
          ),

          // Footer
          if (branding?.footer != null) ...[
            const SizedBox(height: 16),
            Text(
              branding!.footer!,
              style: branding!.footerStyle ?? Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );

    if (interactive && onTap != null) {
      qrWidget = GestureDetector(
        onTap: onTap,
        child: qrWidget,
      );
    }

    return qrWidget;
  }

  Widget _buildLogoOverlay(LogoEmbedOptions logoOptions) {
    Widget logoWidget = Container(
      width: logoOptions.logoSize,
      height: logoOptions.logoSize,
      decoration: BoxDecoration(
        color: logoOptions.addLogoBackground ? logoOptions.logoBackgroundColor : null,
        borderRadius: logoOptions.logoBorderRadius ?? BorderRadius.circular(8),
      ),
      padding: logoOptions.logoMargin,
      child: const Icon(Icons.business, size: 24), // Placeholder - would use actual logo
    );

    return logoWidget;
  }
}

/// Animated QR Display Widget with loading states
class AnimatedQRDisplayWidget extends StatefulWidget {
  final String? qrData;
  final QRStylingOptions? styling;
  final QRBrandingOptions? branding;
  final VoidCallback? onTap;
  final bool isLoading;
  final String? errorMessage;

  const AnimatedQRDisplayWidget({
    super.key,
    this.qrData,
    this.styling,
    this.branding,
    this.onTap,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  State<AnimatedQRDisplayWidget> createState() => _AnimatedQRDisplayWidgetState();
}

class _AnimatedQRDisplayWidgetState extends State<AnimatedQRDisplayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    if (widget.qrData != null && !widget.isLoading) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(AnimatedQRDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.qrData != null && !widget.isLoading && oldWidget.qrData != widget.qrData) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildLoadingState();
    }

    if (widget.errorMessage != null) {
      return _buildErrorState();
    }

    if (widget.qrData == null) {
      return _buildEmptyState();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: QRDisplayWidget(
              qrData: widget.qrData!,
              styling: widget.styling,
              branding: widget.branding,
              onTap: widget.onTap,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    final QRStylingOptions styling = widget.styling ?? const QRStylingOptions();
    
    return Container(
      width: styling.size + styling.padding.horizontal,
      height: styling.size + styling.padding.vertical,
      padding: styling.padding,
      decoration: BoxDecoration(
        color: styling.backgroundColor,
        borderRadius: styling.borderRadius,
        boxShadow: styling.shadow != null ? [styling.shadow!] : null,
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating QR Code...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final QRStylingOptions styling = widget.styling ?? const QRStylingOptions();
    
    return Container(
      width: styling.size + styling.padding.horizontal,
      height: styling.size + styling.padding.vertical,
      padding: styling.padding,
      decoration: BoxDecoration(
        color: styling.backgroundColor,
        borderRadius: styling.borderRadius,
        boxShadow: styling.shadow != null ? [styling.shadow!] : null,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error generating QR',
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final QRStylingOptions styling = widget.styling ?? const QRStylingOptions();
    
    return Container(
      width: styling.size + styling.padding.horizontal,
      height: styling.size + styling.padding.vertical,
      padding: styling.padding,
      decoration: BoxDecoration(
        color: styling.backgroundColor,
        borderRadius: styling.borderRadius,
        boxShadow: styling.shadow != null ? [styling.shadow!] : null,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No QR Data',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// QR Card Widget for displaying QR with additional information
class QRCardWidget extends StatelessWidget {
  final String qrData;
  final String title;
  final String? subtitle;
  final String? amount;
  final List<Widget>? actions;
  final VoidCallback? onTap;
  final QRStylingOptions? styling;

  const QRCardWidget({
    super.key,
    required this.qrData,
    required this.title,
    this.subtitle,
    this.amount,
    this.actions,
    this.onTap,
    this.styling,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (amount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        amount!,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // QR Code
              QRDisplayWidget(
                qrData: qrData,
                styling: styling ?? QRStylingOptions.minimal(),
                interactive: false,
              ),

              // Actions
              if (actions != null) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Expandable QR Widget for space-constrained layouts
class ExpandableQRWidget extends StatefulWidget {
  final String qrData;
  final String title;
  final QRStylingOptions? styling;
  final QRBrandingOptions? branding;
  final Widget? collapsedChild;

  const ExpandableQRWidget({
    super.key,
    required this.qrData,
    required this.title,
    this.styling,
    this.branding,
    this.collapsedChild,
  });

  @override
  State<ExpandableQRWidget> createState() => _ExpandableQRWidgetState();
}

class _ExpandableQRWidgetState extends State<ExpandableQRWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header (always visible)
        InkWell(
          onTap: _toggleExpanded,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: widget.collapsedChild ?? 
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                ),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(Icons.expand_more),
                ),
              ],
            ),
          ),
        ),

        // Expandable QR content
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: QRDisplayWidget(
              qrData: widget.qrData,
              styling: widget.styling ?? QRStylingOptions.minimal(),
              branding: widget.branding,
              interactive: false,
            ),
          ),
        ),
      ],
    );
  }
}