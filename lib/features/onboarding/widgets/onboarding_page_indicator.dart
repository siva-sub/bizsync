import 'package:flutter/material.dart';

class OnboardingPageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Color? activeColor;
  final Color? inactiveColor;
  final double dotSize;
  final double spacing;

  const OnboardingPageIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.activeColor,
    this.inactiveColor,
    this.dotSize = 8.0,
    this.spacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColorFinal = activeColor ?? theme.colorScheme.primary;
    final inactiveColorFinal = inactiveColor ?? theme.colorScheme.outline.withOpacity(0.3);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalPages,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: EdgeInsets.symmetric(horizontal: spacing / 2),
          width: index == currentPage ? dotSize * 2.5 : dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: index == currentPage ? activeColorFinal : inactiveColorFinal,
            borderRadius: BorderRadius.circular(dotSize / 2),
          ),
        ),
      ),
    );
  }
}

class OnboardingProgressIndicator extends StatelessWidget {
  final double progress;
  final Color? backgroundColor;
  final Color? progressColor;
  final double height;
  final String? label;

  const OnboardingProgressIndicator({
    super.key,
    required this.progress,
    this.backgroundColor,
    this.progressColor,
    this.height = 8.0,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColorFinal = backgroundColor ?? theme.colorScheme.outline.withOpacity(0.2);
    final progressColorFinal = progressColor ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onBackground.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: backgroundColorFinal,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    progressColorFinal,
                    progressColorFinal.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).round()}% complete',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class OnboardingStepIndicator extends StatelessWidget {
  final List<String> steps;
  final int currentStepIndex;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? completedColor;

  const OnboardingStepIndicator({
    super.key,
    required this.steps,
    required this.currentStepIndex,
    this.activeColor,
    this.inactiveColor,
    this.completedColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColorFinal = activeColor ?? theme.colorScheme.primary;
    final inactiveColorFinal = inactiveColor ?? theme.colorScheme.outline.withOpacity(0.3);
    final completedColorFinal = completedColor ?? theme.colorScheme.tertiary;

    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _buildStepCircle(
            context,
            i,
            currentStepIndex,
            activeColorFinal,
            inactiveColorFinal,
            completedColorFinal,
          ),
          if (i < steps.length - 1)
            Expanded(
              child: _buildConnector(
                context,
                i < currentStepIndex,
                completedColorFinal,
                inactiveColorFinal,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildStepCircle(
    BuildContext context,
    int stepIndex,
    int currentIndex,
    Color activeColor,
    Color inactiveColor,
    Color completedColor,
  ) {
    final isCompleted = stepIndex < currentIndex;
    final isActive = stepIndex == currentIndex;
    final isInactive = stepIndex > currentIndex;

    Color circleColor;
    Widget child;

    if (isCompleted) {
      circleColor = completedColor;
      child = Icon(
        Icons.check,
        color: Colors.white,
        size: 16,
      );
    } else if (isActive) {
      circleColor = activeColor;
      child = Text(
        '${stepIndex + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    } else {
      circleColor = inactiveColor;
      child = Text(
        '${stepIndex + 1}',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    }

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: isInactive
                ? Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    width: 2,
                  )
                : null,
          ),
          child: child,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Text(
            steps[stepIndex],
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isActive
                  ? activeColor
                  : Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(
    BuildContext context,
    bool isCompleted,
    Color completedColor,
    Color inactiveColor,
  ) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isCompleted ? completedColor : inactiveColor,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}