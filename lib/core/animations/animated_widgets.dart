import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'animation_constants.dart';
import '../widgets/mesa_safe_widgets.dart';

/// Animated button with press feedback and hover effects
class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Duration duration;
  final double pressScale;
  final double hoverScale;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool enabled;

  const AnimatedButton({
    super.key,
    required this.child,
    this.onPressed,
    this.duration = AnimationConstants.buttonPress,
    this.pressScale = 0.95,
    this.hoverScale = 1.02,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius,
    this.padding,
    this.enabled = true,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationConstants.buttonCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.enabled) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.enabled) {
      setState(() => _isPressed = false);
      _controller.reverse();
      widget.onPressed?.call();
    }
  }

  void _onTapCancel() {
    if (widget.enabled) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isHovered && !_isPressed 
                  ? widget.hoverScale 
                  : _scaleAnimation.value,
              child: AnimatedContainer(
                duration: AnimationConstants.cardHover,
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? theme.colorScheme.primary,
                  borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
                  boxShadow: _isHovered && widget.enabled
                      ? createMesaSafeBoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          offset: const Offset(0, 4),
                          blurRadius: 12,
                        )
                      : null,
                ),
                padding: widget.padding ?? const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: widget.foregroundColor ?? theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  child: widget.child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Animated card with hover effects and tap feedback
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double elevation;
  final double hoverElevation;
  final Duration duration;
  final BorderRadius? borderRadius;
  final Color? color;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.elevation = 2.0,
    this.hoverElevation = 8.0,
    this.duration = AnimationConstants.cardHover,
    this.borderRadius,
    this.color,
    this.margin,
    this.padding,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: widget.duration,
          curve: AnimationConstants.cardCurve,
          margin: widget.margin,
          child: MesaSafeCard(
            elevation: _isHovered ? widget.hoverElevation : widget.elevation,
            color: widget.color,
            shape: RoundedRectangleBorder(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            ),
            child: widget.padding != null
                ? Padding(
                    padding: widget.padding!,
                    child: widget.child,
                  )
                : widget.child,
          ),
        ),
      ),
    );
  }
}

/// Animated number counter with smooth counting animation
class AnimatedNumberCounter extends StatefulWidget {
  final int value;
  final Duration duration;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Curve curve;

  const AnimatedNumberCounter({
    super.key,
    required this.value,
    this.duration = AnimationConstants.numberCounter,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.curve = AnimationConstants.easeOut,
  });

  @override
  State<AnimatedNumberCounter> createState() => _AnimatedNumberCounterState();
}

class _AnimatedNumberCounterState extends State<AnimatedNumberCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;
  int _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _updateAnimation();
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedNumberCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _updateAnimation();
      _controller.reset();
      _controller.forward();
    }
  }

  void _updateAnimation() {
    _animation = IntTween(
      begin: _previousValue,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${widget.prefix}${_animation.value}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

/// Animated progress indicator
class AnimatedProgressBar extends StatefulWidget {
  final double progress;
  final Duration duration;
  final Color? backgroundColor;
  final Color? progressColor;
  final double height;
  final BorderRadius? borderRadius;

  const AnimatedProgressBar({
    super.key,
    required this.progress,
    this.duration = AnimationConstants.medium,
    this.backgroundColor,
    this.progressColor,
    this.height = 4.0,
    this.borderRadius,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationConstants.easeOut,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: AnimationConstants.easeOut,
      ));
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? 
               theme.colorScheme.surfaceContainerHighest,
        borderRadius: widget.borderRadius ?? 
                     BorderRadius.circular(widget.height / 2),
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _animation.value,
            child: Container(
              decoration: BoxDecoration(
                color: widget.progressColor ?? theme.colorScheme.primary,
                borderRadius: widget.borderRadius ?? 
                             BorderRadius.circular(widget.height / 2),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Staggered list animation wrapper
class StaggeredListView extends StatelessWidget {
  final List<Widget> children;
  final Duration duration;
  final Duration delay;
  final Axis scrollDirection;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;

  const StaggeredListView({
    super.key,
    required this.children,
    this.duration = AnimationConstants.fast,
    this.delay = AnimationConstants.staggerDelay,
    this.scrollDirection = Axis.vertical,
    this.physics,
    this.padding,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: ListView.builder(
        scrollDirection: scrollDirection,
        physics: physics,
        padding: padding,
        shrinkWrap: shrinkWrap,
        itemCount: children.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: duration,
            delay: delay,
            child: SlideAnimation(
              verticalOffset: scrollDirection == Axis.vertical ? 50.0 : 0.0,
              horizontalOffset: scrollDirection == Axis.horizontal ? 50.0 : 0.0,
              child: FadeInAnimation(
                child: children[index],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Staggered grid animation wrapper
class StaggeredGridView extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final Duration duration;
  final Duration delay;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  const StaggeredGridView({
    super.key,
    required this.children,
    required this.crossAxisCount,
    this.duration = AnimationConstants.fast,
    this.delay = AnimationConstants.staggerDelay,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.padding,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: GridView.builder(
        padding: padding,
        physics: physics,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
        ),
        itemCount: children.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: duration,
            delay: delay,
            columnCount: crossAxisCount,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: children[index],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Hero animation wrapper for list to detail transitions
class HeroAnimationWrapper extends StatelessWidget {
  final String tag;
  final Widget child;
  final Duration duration;

  const HeroAnimationWrapper({
    super.key,
    required this.tag,
    required this.child,
    this.duration = AnimationConstants.heroTransition,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      transitionOnUserGestures: true,
      flightShuttleBuilder: (
        BuildContext flightContext,
        Animation<double> animation,
        HeroFlightDirection flightDirection,
        BuildContext fromHeroContext,
        BuildContext toHeroContext,
      ) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform.scale(
              scale: animation.value,
              child: child,
            );
          },
          child: Material(
            elevation: 0,
            color: Colors.transparent,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Animated floating action button with ripple effect
class AnimatedFAB extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final double pressedElevation;

  const AnimatedFAB({
    super.key,
    this.onPressed,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 6.0,
    this.pressedElevation = 12.0,
  });

  @override
  State<AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<AnimatedFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationConstants.buttonPress,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationConstants.buttonCurve,
    ));

    _elevationAnimation = Tween<double>(
      begin: widget.elevation,
      end: widget.pressedElevation,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AnimationConstants.buttonCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: FloatingActionButton(
              onPressed: null, // Handled by GestureDetector
              backgroundColor: widget.backgroundColor,
              foregroundColor: widget.foregroundColor,
              elevation: getMesaSafeElevation(_elevationAnimation.value),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}