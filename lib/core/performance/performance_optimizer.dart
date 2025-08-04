import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// Performance metrics
class PerformanceMetrics {
  final double averageFps;
  final int frameCount;
  final Duration totalTime;
  final int droppedFrames;
  final double frameRenderTime;
  final int memoryUsage;

  const PerformanceMetrics({
    required this.averageFps,
    required this.frameCount,
    required this.totalTime,
    required this.droppedFrames,
    required this.frameRenderTime,
    required this.memoryUsage,
  });

  double get droppedFramePercentage => 
      frameCount > 0 ? (droppedFrames / frameCount) * 100 : 0;

  bool get isPerformanceGood => averageFps >= 55 && droppedFramePercentage < 5;
}

// Performance optimizer service
class PerformanceOptimizer extends ChangeNotifier {
  static final PerformanceOptimizer _instance = PerformanceOptimizer._internal();
  factory PerformanceOptimizer() => _instance;
  PerformanceOptimizer._internal();

  final Completer<void> _readyCompleter = Completer<void>();
  Future<void> get ready => _readyCompleter.future;

  // Performance monitoring
  final List<Duration> _frameTimes = [];
  int _frameCount = 0;
  int _droppedFrames = 0;
  Timer? _performanceTimer;
  PerformanceMetrics? _currentMetrics;

  // Image cache manager
  late CacheManager _imageCache;

  // Performance settings
  bool _enablePerformanceMonitoring = true;
  bool _enableImageCaching = true;
  bool _enableLazyLoading = true;
  int _maxImageCacheSize = 100 * 1024 * 1024; // 100MB
  Duration _imageCacheDuration = const Duration(days: 7);

  // Getters
  PerformanceMetrics? get currentMetrics => _currentMetrics;
  bool get enablePerformanceMonitoring => _enablePerformanceMonitoring;
  bool get enableImageCaching => _enableImageCaching;
  bool get enableLazyLoading => _enableLazyLoading;

  Future<void> initialize() async {
    await _initializeImageCache();
    _startPerformanceMonitoring();
    _readyCompleter.complete();
    debugPrint('Performance Optimizer initialized');
  }

  Future<void> _initializeImageCache() async {
    _imageCache = CacheManager(
      Config(
        'bizsync_image_cache',
        stalePeriod: _imageCacheDuration,
        maxNrOfCacheObjects: 1000,
        repo: JsonCacheInfoRepository(databaseName: 'bizsync_image_cache'),
        fileService: HttpFileService(),
      ),
    );
  }

  void _startPerformanceMonitoring() {
    if (!_enablePerformanceMonitoring) return;

    SchedulerBinding.instance.addPostFrameCallback(_onFrameEnd);
    
    _performanceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updatePerformanceMetrics();
    });
  }

  void _onFrameEnd(Duration duration) {
    if (!_enablePerformanceMonitoring) return;

    _frameCount++;
    _frameTimes.add(duration);

    // Keep only last 60 frames for moving average
    if (_frameTimes.length > 60) {
      _frameTimes.removeAt(0);
    }

    // Check for dropped frames (frames taking longer than 16.67ms for 60fps)
    if (duration.inMicroseconds > 16670) {
      _droppedFrames++;
    }

    // Schedule next frame callback
    SchedulerBinding.instance.addPostFrameCallback(_onFrameEnd);
  }

  void _updatePerformanceMetrics() {
    if (_frameTimes.isEmpty) return;

    final totalFrameTime = _frameTimes.fold<int>(
      0, 
      (sum, duration) => sum + duration.inMicroseconds,
    );
    
    final averageFrameTime = totalFrameTime / _frameTimes.length;
    final averageFps = averageFrameTime > 0 ? 1000000 / averageFrameTime : 0;

    _currentMetrics = PerformanceMetrics(
      averageFps: averageFps,
      frameCount: _frameCount,
      totalTime: Duration(microseconds: totalFrameTime),
      droppedFrames: _droppedFrames,
      frameRenderTime: averageFrameTime / 1000, // Convert to milliseconds
      memoryUsage: 0, // Would need platform-specific implementation
    );

    notifyListeners();

    // Log performance warnings
    if (!_currentMetrics!.isPerformanceGood) {
      debugPrint('Performance Warning: FPS: ${averageFps.toStringAsFixed(1)}, '
          'Dropped: ${_currentMetrics!.droppedFramePercentage.toStringAsFixed(1)}%');
    }
  }

  // Performance optimization methods
  void enablePerformanceMonitoring(bool enable) {
    _enablePerformanceMonitoring = enable;
    if (enable) {
      _startPerformanceMonitoring();
    } else {
      _performanceTimer?.cancel();
    }
  }

  void enableImageCaching(bool enable) {
    _enableImageCaching = enable;
    notifyListeners();
  }

  void enableLazyLoading(bool enable) {
    _enableLazyLoading = enable;
    notifyListeners();
  }

  // Clear image cache
  Future<void> clearImageCache() async {
    await _imageCache.emptyCache();
    debugPrint('Image cache cleared');
  }

  // Get cache info
  Future<Map<String, dynamic>> getCacheInfo() async {
    final cacheKeys = await _imageCache.getKeysByTime();
    final cacheSize = cacheKeys.length;
    
    return {
      'cached_images': cacheSize,
      'cache_size_mb': cacheSize * 0.5, // Rough estimate
      'max_cache_size_mb': _maxImageCacheSize / (1024 * 1024),
    };
  }

  void dispose() {
    _performanceTimer?.cancel();
    super.dispose();
  }
}

// Optimized image widget
class OptimizedImage extends ConsumerWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableMemoryCache;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.enableMemoryCache = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optimizer = ref.watch(performanceOptimizerProvider);

    if (!optimizer.enableImageCaching) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            errorWidget ?? const Icon(Icons.error),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: enableMemoryCache ? (width?.toInt() ?? 300) : null,
      memCacheHeight: enableMemoryCache ? (height?.toInt() ?? 300) : null,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          ),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }
}

// Lazy loading list view
class LazyLoadingListView<T> extends ConsumerStatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Future<void> Function()? onLoadMore;
  final bool hasMore;
  final Widget? loadingWidget;
  final int loadMoreThreshold;

  const LazyLoadingListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.onLoadMore,
    this.hasMore = false,
    this.loadingWidget,
    this.loadMoreThreshold = 3,
  });

  @override
  ConsumerState<LazyLoadingListView<T>> createState() => _LazyLoadingListViewState<T>();
}

class _LazyLoadingListViewState<T> extends ConsumerState<LazyLoadingListView<T>> {
  late ScrollController _scrollController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    if (!widget.hasMore || _isLoading || widget.onLoadMore == null) return;

    final position = _scrollController.position;
    final remainingItems = widget.items.length - 
        (position.pixels / (position.maxScrollExtent / widget.items.length)).ceil();

    if (remainingItems <= widget.loadMoreThreshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onLoadMore!();
    } catch (e) {
      debugPrint('Error loading more items: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final optimizer = ref.watch(performanceOptimizerProvider);

    if (!optimizer.enableLazyLoading) {
      return ListView.builder(
        controller: _scrollController,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          return widget.itemBuilder(context, widget.items[index], index);
        },
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.items.length) {
          // Loading indicator at the end
          return widget.loadingWidget ??
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
        }

        return widget.itemBuilder(context, widget.items[index], index);
      },
    );
  }
}

// Smooth animation wrapper
class SmoothAnimationWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final bool enabled;

  const SmoothAnimationWrapper({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.enabled = true,
  });

  @override
  State<SmoothAnimationWrapper> createState() => _SmoothAnimationWrapperState();
}

class _SmoothAnimationWrapperState extends State<SmoothAnimationWrapper>
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
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    if (widget.enabled) {
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
    if (!widget.enabled) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * _animation.value),
          child: Opacity(
            opacity: _animation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}

// Performance monitoring widget
class PerformanceMonitor extends ConsumerWidget {
  final Widget child;
  final bool showOverlay;

  const PerformanceMonitor({
    super.key,
    required this.child,
    this.showOverlay = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optimizer = ref.watch(performanceOptimizerProvider);
    final metrics = optimizer.currentMetrics;

    return Stack(
      children: [
        child,
        if (showOverlay && metrics != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FPS: ${metrics.averageFps.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: metrics.isPerformanceGood ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Dropped: ${metrics.droppedFramePercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    'Frame: ${metrics.frameRenderTime.toStringAsFixed(1)}ms',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// Memory efficient builder
class MemoryEfficientBuilder<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final int visibleRange;

  const MemoryEfficientBuilder({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.visibleRange = 50,
  });

  @override
  State<MemoryEfficientBuilder<T>> createState() => _MemoryEfficientBuilderState<T>();
}

class _MemoryEfficientBuilderState<T> extends State<MemoryEfficientBuilder<T>> {
  final ScrollController _scrollController = ScrollController();
  int _startIndex = 0;
  int _endIndex = 0;

  @override
  void initState() {
    super.initState();
    _updateVisibleRange();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _updateVisibleRange();
  }

  void _updateVisibleRange() {
    final itemHeight = 100.0; // Estimated item height
    final scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0;
    final viewportHeight = MediaQuery.of(context).size.height;

    final visibleStart = (scrollOffset / itemHeight).floor();
    final visibleEnd = ((scrollOffset + viewportHeight) / itemHeight).ceil();

    final newStartIndex = (visibleStart - widget.visibleRange ~/ 2).clamp(0, widget.items.length);
    final newEndIndex = (visibleEnd + widget.visibleRange ~/ 2).clamp(0, widget.items.length);

    if (newStartIndex != _startIndex || newEndIndex != _endIndex) {
      setState(() {
        _startIndex = newStartIndex;
        _endIndex = newEndIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        if (index < _startIndex || index >= _endIndex) {
          return const SizedBox(height: 100); // Placeholder
        }

        return widget.itemBuilder(context, widget.items[index]);
      },
    );
  }
}

// Riverpod providers
final performanceOptimizerProvider = Provider<PerformanceOptimizer>((ref) {
  final optimizer = PerformanceOptimizer();
  optimizer.initialize();
  return optimizer;
});

final performanceMetricsProvider = StateProvider<PerformanceMetrics?>((ref) {
  final optimizer = ref.watch(performanceOptimizerProvider);
  return optimizer.currentMetrics;
});