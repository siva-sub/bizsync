import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/dashboard_models.dart';

/// Interactive line chart widget for time series data
class InteractiveLineChart extends StatefulWidget {
  final List<DataPoint> data;
  final String title;
  final String? subtitle;
  final Color lineColor;
  final bool showGradient;
  final bool showDots;
  final bool showTooltip;
  final Function(DataPoint)? onPointTap;
  final double height;

  const InteractiveLineChart({
    super.key,
    required this.data,
    required this.title,
    this.subtitle,
    this.lineColor = const Color(0xFF2196F3),
    this.showGradient = true,
    this.showDots = true,
    this.showTooltip = true,
    this.onPointTap,
    this.height = 300,
  });

  @override
  State<InteractiveLineChart> createState() => _InteractiveLineChartState();
}

class _InteractiveLineChartState extends State<InteractiveLineChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int? touchedIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Text('No data available')),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: widget.height - 80,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: widget.data
                              .asMap()
                              .entries
                              .map((entry) => FlSpot(
                                    entry.key.toDouble(),
                                    entry.value.value * _animation.value,
                                  ))
                              .toList(),
                          isCurved: true,
                          color: widget.lineColor,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: widget.showDots,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: touchedIndex == index ? 6 : 4,
                                color: widget.lineColor,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: widget.showGradient
                              ? BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      widget.lineColor.withValues(alpha: 0.3),
                                      widget.lineColor.withValues(alpha: 0.1),
                                    ],
                                  ),
                                )
                              : BarAreaData(show: false),
                        ),
                      ],
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) {
                          return const FlLine(
                            color: Color(0xFFE0E0E0),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: widget.data.length > 10
                                ? (widget.data.length / 5).ceil().toDouble()
                                : 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= widget.data.length) {
                                return const Text('');
                              }
                              final date = widget.data[index].timestamp;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${date.day}/${date.month}',
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: null,
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                _formatCurrency(value),
                                style: const TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(
                          color: const Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        enabled: widget.showTooltip,
                        touchCallback:
                            (FlTouchEvent event, LineTouchResponse? response) {
                          if (response != null &&
                              response.lineBarSpots != null) {
                            final spot = response.lineBarSpots!.first;
                            setState(() {
                              touchedIndex = spot.spotIndex;
                            });

                            if (widget.onPointTap != null) {
                              final dataPoint = widget.data[spot.spotIndex];
                              widget.onPointTap!(dataPoint);
                            }
                          } else {
                            setState(() {
                              touchedIndex = null;
                            });
                          }
                        },
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                            return touchedBarSpots.map((barSpot) {
                              final dataPoint = widget.data[barSpot.spotIndex];
                              return LineTooltipItem(
                                '${_formatCurrency(dataPoint.value)}\n${_formatDate(dataPoint.timestamp)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return '\$${value.toStringAsFixed(0)}';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Interactive bar chart widget
class InteractiveBarChart extends StatefulWidget {
  final List<DataPoint> data;
  final String title;
  final Color barColor;
  final bool showValues;
  final Function(DataPoint)? onBarTap;
  final double height;

  const InteractiveBarChart({
    super.key,
    required this.data,
    required this.title,
    this.barColor = const Color(0xFF4CAF50),
    this.showValues = true,
    this.onBarTap,
    this.height = 300,
  });

  @override
  State<InteractiveBarChart> createState() => _InteractiveBarChartState();
}

class _InteractiveBarChartState extends State<InteractiveBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int? touchedIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Text('No data available')),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: widget.height - 80,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return BarChart(
                    BarChartData(
                      barGroups: widget.data
                          .asMap()
                          .entries
                          .map((entry) => BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value.value * _animation.value,
                                    color: touchedIndex == entry.key
                                        ? widget.barColor.withValues(alpha: 0.8)
                                        : widget.barColor,
                                    width: 20,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              ))
                          .toList(),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) {
                          return const FlLine(
                            color: Color(0xFFE0E0E0),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= widget.data.length) {
                                return const Text('');
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  widget.data[index].label ?? '$index',
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                _formatValue(value),
                                style: const TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(
                          color: const Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchCallback:
                            (FlTouchEvent event, BarTouchResponse? response) {
                          if (response != null && response.spot != null) {
                            final index = response.spot!.touchedBarGroupIndex;
                            setState(() {
                              touchedIndex = index;
                            });

                            if (widget.onBarTap != null) {
                              widget.onBarTap!(widget.data[index]);
                            }
                          } else {
                            setState(() {
                              touchedIndex = null;
                            });
                          }
                        },
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final dataPoint = widget.data[groupIndex];
                            return BarTooltipItem(
                              '${dataPoint.label}\n${_formatValue(dataPoint.value)}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }
}

/// Interactive pie chart widget
class InteractivePieChart extends StatefulWidget {
  final List<DataPoint> data;
  final String title;
  final List<Color>? colors;
  final bool showPercentages;
  final bool showLegend;
  final Function(DataPoint)? onSectionTap;
  final double height;

  const InteractivePieChart({
    super.key,
    required this.data,
    required this.title,
    this.colors,
    this.showPercentages = true,
    this.showLegend = true,
    this.onSectionTap,
    this.height = 300,
  });

  @override
  State<InteractivePieChart> createState() => _InteractivePieChartState();
}

class _InteractivePieChartState extends State<InteractivePieChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int? touchedIndex;

  static const List<Color> _defaultColors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFFEB3B),
    Color(0xFF795548),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Text('No data available')),
      );
    }

    final total = widget.data.fold(0.0, (sum, item) => sum + item.value);
    final colors = widget.colors ?? _defaultColors;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: widget.height - (widget.showLegend ? 160 : 80),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return PieChart(
                    PieChartData(
                      sections: widget.data.asMap().entries.map((entry) {
                        final index = entry.key;
                        final dataPoint = entry.value;
                        final percentage = (dataPoint.value / total) * 100;
                        final isTouched = touchedIndex == index;
                        final radius = isTouched ? 60.0 : 50.0;

                        return PieChartSectionData(
                          value: dataPoint.value * _animation.value,
                          title: widget.showPercentages
                              ? '${percentage.toStringAsFixed(1)}%'
                              : '',
                          color: colors[index % colors.length],
                          radius: radius,
                          titleStyle: TextStyle(
                            fontSize: isTouched ? 14 : 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 0,
                      pieTouchData: PieTouchData(
                        touchCallback:
                            (FlTouchEvent event, PieTouchResponse? response) {
                          if (response != null &&
                              response.touchedSection != null) {
                            final index =
                                response.touchedSection!.touchedSectionIndex;
                            setState(() {
                              touchedIndex = index;
                            });

                            if (widget.onSectionTap != null) {
                              widget.onSectionTap!(widget.data[index]);
                            }
                          } else {
                            setState(() {
                              touchedIndex = null;
                            });
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.showLegend) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: widget.data
                    .asMap()
                    .entries
                    .map((entry) => _buildLegendItem(
                          entry.value.label ?? 'Item ${entry.key + 1}',
                          colors[entry.key % colors.length],
                          entry.value.value,
                          total,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(
      String label, Color color, double value, double total) {
    final percentage = (value / total) * 100;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label (${percentage.toStringAsFixed(1)}%)',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

/// Donut chart widget with center information
class DonutChart extends StatelessWidget {
  final List<DataPoint> data;
  final String title;
  final String? centerText;
  final String? centerSubtext;
  final List<Color>? colors;
  final double height;

  const DonutChart({
    super.key,
    required this.data,
    required this.title,
    this.centerText,
    this.centerSubtext,
    this.colors,
    this.height = 300,
  });

  static const List<Color> _defaultColors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
  ];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('No data available')),
      );
    }

    final total = data.fold(0.0, (sum, item) => sum + item.value);
    final chartColors = colors ?? _defaultColors;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height - 80,
              child: Stack(
                children: [
                  PieChart(
                    PieChartData(
                      sections: data.asMap().entries.map((entry) {
                        final index = entry.key;
                        final dataPoint = entry.value;

                        return PieChartSectionData(
                          value: dataPoint.value,
                          title: '',
                          color: chartColors[index % chartColors.length],
                          radius: 50,
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 80,
                    ),
                  ),
                  if (centerText != null)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            centerText!,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          if (centerSubtext != null)
                            Text(
                              centerSubtext!,
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress gauge widget
class ProgressGauge extends StatefulWidget {
  final double value;
  final double maxValue;
  final String title;
  final String? subtitle;
  final Color color;
  final double height;

  const ProgressGauge({
    super.key,
    required this.value,
    required this.maxValue,
    required this.title,
    this.subtitle,
    this.color = const Color(0xFF4CAF50),
    this.height = 200,
  });

  @override
  State<ProgressGauge> createState() => _ProgressGaugeState();
}

class _ProgressGaugeState extends State<ProgressGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: widget.height - 80,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final animatedValue = widget.value * _animation.value;
                  final percentage =
                      (animatedValue / widget.maxValue * 100).clamp(0, 100);

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CircularProgressIndicator(
                          value: percentage / 100,
                          strokeWidth: 20,
                          backgroundColor: Colors.grey[300],
                          valueColor:
                              AlwaysStoppedAnimation<Color>(widget.color),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: widget.color,
                                ),
                          ),
                          Text(
                            '${animatedValue.toStringAsFixed(0)}/${widget.maxValue.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trend indicator widget
class TrendIndicator extends StatelessWidget {
  final double value;
  final double? previousValue;
  final String label;
  final bool showPercentage;
  final String? unit;

  const TrendIndicator({
    super.key,
    required this.value,
    this.previousValue,
    required this.label,
    this.showPercentage = true,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final trend = _calculateTrend();
    final trendColor = _getTrendColor(trend.direction);
    final trendIcon = _getTrendIcon(trend.direction);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: trendColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: trendColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trendIcon,
            color: trendColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Row(
                children: [
                  Text(
                    '${showPercentage ? '${trend.percentage.toStringAsFixed(1)}%' : value.toStringAsFixed(1)}${unit ?? ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: trendColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  TrendData _calculateTrend() {
    if (previousValue == null || previousValue == 0) {
      return TrendData(
        direction: TrendDirection.stable,
        percentage: 0,
        change: 0,
      );
    }

    final change = value - previousValue!;
    final percentage = (change / previousValue!) * 100;

    TrendDirection direction;
    if (percentage > 5) {
      direction = TrendDirection.up;
    } else if (percentage < -5) {
      direction = TrendDirection.down;
    } else {
      direction = TrendDirection.stable;
    }

    return TrendData(
      direction: direction,
      percentage: percentage,
      change: change,
    );
  }

  Color _getTrendColor(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.up:
        return const Color(0xFF4CAF50);
      case TrendDirection.down:
        return const Color(0xFFF44336);
      case TrendDirection.stable:
        return const Color(0xFF666666);
      case TrendDirection.volatile:
        return const Color(0xFFFF9800);
    }
  }

  IconData _getTrendIcon(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.up:
        return Icons.trending_up;
      case TrendDirection.down:
        return Icons.trending_down;
      case TrendDirection.stable:
        return Icons.trending_flat;
      case TrendDirection.volatile:
        return Icons.show_chart;
    }
  }
}

/// Helper class for trend calculations
class TrendData {
  final TrendDirection direction;
  final double percentage;
  final double change;

  TrendData({
    required this.direction,
    required this.percentage,
    required this.change,
  });
}

/// Animated KPI card widget
class AnimatedKPICard extends StatefulWidget {
  final KPI kpi;
  final Function()? onTap;

  const AnimatedKPICard({
    super.key,
    required this.kpi,
    this.onTap,
  });

  @override
  State<AnimatedKPICard> createState() => _AnimatedKPICardState();
}

class _AnimatedKPICardState extends State<AnimatedKPICard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _valueAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _valueAnimation =
        Tween<double>(begin: 0, end: widget.kpi.currentValue).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trendColor = _getTrendColor(widget.kpi.trend);
    final trendIcon = _getTrendIcon(widget.kpi.trend);

    return AnimationLimiterBuilder(
      animation: _scaleAnimation,
      builder: (context, child, value) {
        return Transform.scale(
          scale: value,
          child: Card(
            elevation: 4,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (widget.kpi.iconName != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: trendColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getIconData(widget.kpi.iconName!),
                              color: trendColor,
                              size: 24,
                            ),
                          ),
                        const Spacer(),
                        Icon(
                          trendIcon,
                          color: trendColor,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.kpi.percentageChange.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: trendColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.kpi.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedBuilder(
                      animation: _valueAnimation,
                      builder: (context, child) {
                        return Text(
                          _formatKPIValue(_valueAnimation.value),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        );
                      },
                    ),
                    if (widget.kpi.targetValue != null) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value:
                            (widget.kpi.currentValue / widget.kpi.targetValue!)
                                .clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(trendColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Target: ${_formatKPIValue(widget.kpi.targetValue!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatKPIValue(double value) {
    String formattedValue = '';

    if (widget.kpi.prefix != null) formattedValue += widget.kpi.prefix!;

    if (value >= 1000000) {
      formattedValue += '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      formattedValue += '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      formattedValue += value.toStringAsFixed(widget.kpi.unit == '%' ? 1 : 0);
    }

    if (widget.kpi.suffix != null) formattedValue += widget.kpi.suffix!;
    if (widget.kpi.unit.isNotEmpty && widget.kpi.suffix == null) {
      formattedValue += ' ${widget.kpi.unit}';
    }

    return formattedValue;
  }

  Color _getTrendColor(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.up:
        return const Color(0xFF4CAF50);
      case TrendDirection.down:
        return const Color(0xFFF44336);
      case TrendDirection.stable:
        return const Color(0xFF666666);
      case TrendDirection.volatile:
        return const Color(0xFFFF9800);
    }
  }

  IconData _getTrendIcon(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.up:
        return Icons.trending_up;
      case TrendDirection.down:
        return Icons.trending_down;
      case TrendDirection.stable:
        return Icons.trending_flat;
      case TrendDirection.volatile:
        return Icons.show_chart;
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'trending_up':
        return Icons.trending_up;
      case 'people':
        return Icons.people;
      case 'inventory':
        return Icons.inventory;
      case 'account_balance':
        return Icons.account_balance;
      case 'analytics':
        return Icons.analytics;
      default:
        return Icons.bar_chart;
    }
  }
}

/// Custom widget to limit animation rebuilds
class AnimationLimiterBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext, Widget?, double) builder;
  final Widget? child;

  const AnimationLimiterBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => builder(context, child, animation.value),
      child: child,
    );
  }
}
