import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  final double? size;
  final Color? color;
  
  const LoadingWidget({
    super.key,
    this.message,
    this.size,
    this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size ?? 40,
          height: size ?? 40,
          child: CircularProgressIndicator(
            color: color ?? Theme.of(context).primaryColor,
            strokeWidth: 3,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: AppConstants.defaultPadding),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color ?? Theme.of(context).textTheme.bodyMedium?.color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? loadingMessage;
  final Color? overlayColor;
  
  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.loadingMessage,
    this.overlayColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: overlayColor ?? Colors.black.withOpacity(0.5),
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.largePadding),
                  child: LoadingWidget(
                    message: loadingMessage ?? 'Loading...',
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}