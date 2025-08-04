import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../feedback/haptic_service.dart';

// Swipe direction
enum SwipeDirection {
  left,
  right,
  up,
  down,
}

// Swipe action
class SwipeAction {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;
  final bool dismissible;

  const SwipeAction({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.onTap,
    this.foregroundColor = Colors.white,
    this.dismissible = false,
  });
}

// Swipe configuration
class SwipeConfig {
  final double threshold;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool enableHapticFeedback;
  final double actionExtentRatio;

  const SwipeConfig({
    this.threshold = 0.4,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeInOut,
    this.enableHapticFeedback = true,
    this.actionExtentRatio = 0.25,
  });
}

// Enhanced swipe-to-action widget
class SwipeActionWidget extends ConsumerStatefulWidget {
  final Widget child;
  final List<SwipeAction> leftActions;
  final List<SwipeAction> rightActions;
  final SwipeConfig config;
  final VoidCallback? onSwipeStart;
  final VoidCallback? onSwipeEnd;
  final Function(SwipeDirection)? onSwipeComplete;

  const SwipeActionWidget({
    super.key,
    required this.child,
    this.leftActions = const [],
    this.rightActions = const [],
    this.config = const SwipeConfig(),
    this.onSwipeStart,
    this.onSwipeEnd,
    this.onSwipeComplete,
  });

  @override
  ConsumerState<SwipeActionWidget> createState() => _SwipeActionWidgetState();
}

class _SwipeActionWidgetState extends ConsumerState<SwipeActionWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  double _dragDistance = 0;
  bool _isSwipeActive = false;
  SwipeDirection? _swipeDirection;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.config.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: widget.config.animationCurve,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handlePanStart(DragStartDetails details) {
    _isSwipeActive = true;
    _dragDistance = 0;
    _swipeDirection = null;
    widget.onSwipeStart?.call();

    if (widget.config.enableHapticFeedback) {
      ref.read(hapticServiceProvider).swipeGesture();
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isSwipeActive) return;

    setState(() {
      _dragDistance += details.delta.dx;
    });

    // Determine swipe direction
    if (_dragDistance.abs() > 10) {
      _swipeDirection =
          _dragDistance > 0 ? SwipeDirection.right : SwipeDirection.left;
    }

    // Trigger haptic feedback when reaching threshold
    if (_dragDistance.abs() > 100 && widget.config.enableHapticFeedback) {
      ref.read(hapticServiceProvider).provideFeedback(
            HapticFeedbackType.medium,
            context: 'gesture',
          );
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _isSwipeActive = false;
    widget.onSwipeEnd?.call();

    final velocity = details.velocity.pixelsPerSecond.dx;
    final threshold =
        MediaQuery.of(context).size.width * widget.config.threshold;

    if (_dragDistance.abs() > threshold || velocity.abs() > 500) {
      _executeSwipeAction();
    } else {
      _resetPosition();
    }
  }

  void _executeSwipeAction() {
    if (_swipeDirection == null) {
      _resetPosition();
      return;
    }

    final actions = _swipeDirection == SwipeDirection.right
        ? widget.leftActions
        : widget.rightActions;

    if (actions.isEmpty) {
      _resetPosition();
      return;
    }

    // Execute the first action for now (could be enhanced to show multiple actions)
    final action = actions.first;

    if (widget.config.enableHapticFeedback) {
      ref.read(hapticServiceProvider).provideFeedback(
            HapticFeedbackType.success,
            context: 'gesture',
          );
    }

    if (action.dismissible) {
      _animationController.forward().then((_) {
        action.onTap();
        widget.onSwipeComplete?.call(_swipeDirection!);
      });
    } else {
      action.onTap();
      widget.onSwipeComplete?.call(_swipeDirection!);
      _resetPosition();
    }
  }

  void _resetPosition() {
    setState(() {
      _dragDistance = 0;
    });
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: Stack(
        children: [
          // Background actions
          _buildActionBackground(),
          // Main content
          Transform.translate(
            offset: Offset(_dragDistance, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }

  Widget _buildActionBackground() {
    final screenWidth = MediaQuery.of(context).size.width;
    final actionWidth = screenWidth * widget.config.actionExtentRatio;

    return Positioned.fill(
      child: Row(
        children: [
          // Left actions
          if (widget.leftActions.isNotEmpty)
            Container(
              width: actionWidth,
              color: widget.leftActions.first.backgroundColor,
              child: _buildActionContent(widget.leftActions.first),
            ),

          const Spacer(),

          // Right actions
          if (widget.rightActions.isNotEmpty)
            Container(
              width: actionWidth,
              color: widget.rightActions.first.backgroundColor,
              child: _buildActionContent(widget.rightActions.first),
            ),
        ],
      ),
    );
  }

  Widget _buildActionContent(SwipeAction action) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            action.icon,
            color: action.foregroundColor,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            action.label,
            style: TextStyle(
              color: action.foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Tab swipe navigator
class TabSwipeNavigator extends ConsumerStatefulWidget {
  final List<Widget> children;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;
  final bool enableSwipe;
  final Duration animationDuration;

  const TabSwipeNavigator({
    super.key,
    required this.children,
    this.initialIndex = 0,
    this.onPageChanged,
    this.enableSwipe = true,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  ConsumerState<TabSwipeNavigator> createState() => _TabSwipeNavigatorState();
}

class _TabSwipeNavigatorState extends ConsumerState<TabSwipeNavigator> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    widget.onPageChanged?.call(index);

    // Provide haptic feedback
    ref.read(hapticServiceProvider).swipeGesture();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      physics: widget.enableSwipe
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: widget.children.length,
      itemBuilder: (context, index) {
        return widget.children[index];
      },
    );
  }

  void animateToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: widget.animationDuration,
      curve: Curves.easeInOut,
    );
  }
}

// Pull-to-refresh wrapper
class PullToRefreshWrapper extends ConsumerWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final String? refreshText;
  final bool enableHapticFeedback;

  const PullToRefreshWrapper({
    super.key,
    required this.child,
    required this.onRefresh,
    this.refreshText,
    this.enableHapticFeedback = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        if (enableHapticFeedback) {
          await ref.read(hapticServiceProvider).provideFeedback(
                HapticFeedbackType.medium,
                context: 'gesture',
              );
        }
        await onRefresh();
        if (enableHapticFeedback) {
          await ref.read(hapticServiceProvider).successAction();
        }
      },
      child: child,
    );
  }
}

// Swipe gesture detector for custom actions
class CustomSwipeDetector extends ConsumerStatefulWidget {
  final Widget child;
  final Function(SwipeDirection)? onSwipe;
  final double threshold;
  final bool enableHapticFeedback;

  const CustomSwipeDetector({
    super.key,
    required this.child,
    this.onSwipe,
    this.threshold = 100.0,
    this.enableHapticFeedback = true,
  });

  @override
  ConsumerState<CustomSwipeDetector> createState() =>
      _CustomSwipeDetectorState();
}

class _CustomSwipeDetectorState extends ConsumerState<CustomSwipeDetector> {
  Offset _startPanPoint = Offset.zero;
  Offset _currentPanPoint = Offset.zero;

  void _onPanStart(DragStartDetails details) {
    _startPanPoint = details.globalPosition;
    _currentPanPoint = details.globalPosition;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _currentPanPoint = details.globalPosition;
  }

  void _onPanEnd(DragEndDetails details) {
    final offset = _currentPanPoint - _startPanPoint;

    if (offset.distance >= widget.threshold) {
      SwipeDirection? direction;

      if (offset.dx.abs() > offset.dy.abs()) {
        // Horizontal swipe
        direction = offset.dx > 0 ? SwipeDirection.right : SwipeDirection.left;
      } else {
        // Vertical swipe
        direction = offset.dy > 0 ? SwipeDirection.down : SwipeDirection.up;
      }

      if (widget.enableHapticFeedback) {
        ref.read(hapticServiceProvider).swipeGesture();
      }

      widget.onSwipe?.call(direction);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: widget.child,
    );
  }
}

// Common swipe actions for business app
class BusinessSwipeActions {
  static SwipeAction get delete => SwipeAction(
        icon: Icons.delete_outline,
        label: 'Delete',
        backgroundColor: Colors.red,
        onTap: () {},
        dismissible: true,
      );

  static SwipeAction get archive => SwipeAction(
        icon: Icons.archive_outlined,
        label: 'Archive',
        backgroundColor: Colors.orange,
        onTap: () {},
        dismissible: true,
      );

  static SwipeAction get edit => SwipeAction(
        icon: Icons.edit_outlined,
        label: 'Edit',
        backgroundColor: Colors.blue,
        onTap: () {},
      );

  static SwipeAction get share => SwipeAction(
        icon: Icons.share_outlined,
        label: 'Share',
        backgroundColor: Colors.green,
        onTap: () {},
      );

  static SwipeAction get duplicate => SwipeAction(
        icon: Icons.copy_outlined,
        label: 'Duplicate',
        backgroundColor: Colors.purple,
        onTap: () {},
      );

  static SwipeAction get favorite => SwipeAction(
        icon: Icons.favorite_outline,
        label: 'Favorite',
        backgroundColor: Colors.pink,
        onTap: () {},
      );

  static SwipeAction get markPaid => SwipeAction(
        icon: Icons.check_circle_outline,
        label: 'Mark Paid',
        backgroundColor: Colors.green,
        onTap: () {},
      );

  static SwipeAction get sendReminder => SwipeAction(
        icon: Icons.notification_important_outlined,
        label: 'Remind',
        backgroundColor: Colors.amber,
        onTap: () {},
      );
}
