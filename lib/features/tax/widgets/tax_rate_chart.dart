import 'package:flutter/material.dart';

class TaxRateChart extends StatefulWidget {
  final List<TaxRatePoint>? data;
  final String? title;
  final Color? primaryColor;

  const TaxRateChart({
    super.key,
    this.data,
    this.title,
    this.primaryColor,
  });

  @override
  State<TaxRateChart> createState() => _TaxRateChartState();
}

class _TaxRateChartState extends State<TaxRateChart> {
  late List<TaxRatePoint> _data;

  @override
  void initState() {
    super.initState();
    _data = widget.data ?? _getDefaultGstData();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null)
            Text(
              widget.title!,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          const SizedBox(height: 16),
          Expanded(
            child: CustomPaint(
              painter: TaxRateChartPainter(
                data: _data,
                primaryColor:
                    widget.primaryColor ?? Theme.of(context).primaryColor,
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 16),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      children: _data.map((point) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: point.color ?? Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${point.year}: ${(point.rate * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }).toList(),
    );
  }

  List<TaxRatePoint> _getDefaultGstData() {
    return [
      TaxRatePoint(1994, 0.03, 'GST Introduction', Colors.blue),
      TaxRatePoint(2004, 0.05, 'First Increase', Colors.green),
      TaxRatePoint(2007, 0.07, 'Second Increase', Colors.orange),
      TaxRatePoint(2023, 0.08, 'Third Increase', Colors.red),
      TaxRatePoint(2024, 0.09, 'Revised Rate', Colors.purple),
    ];
  }
}

class TaxRatePoint {
  final int year;
  final double rate;
  final String? description;
  final Color? color;

  TaxRatePoint(this.year, this.rate, [this.description, this.color]);
}

class TaxRateChartPainter extends CustomPainter {
  final List<TaxRatePoint> data;
  final Color primaryColor;

  TaxRateChartPainter({
    required this.data,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // Calculate chart bounds
    final chartRect = Rect.fromLTWH(40, 20, size.width - 80, size.height - 60);

    // Find min/max values
    final minYear = data.first.year;
    final maxYear = data.last.year;
    final minRate = data.map((p) => p.rate).reduce((a, b) => a < b ? a : b);
    final maxRate = data.map((p) => p.rate).reduce((a, b) => a > b ? a : b);

    // Add padding to rate range
    final rateRange = maxRate - minRate;
    final paddedMinRate = minRate - (rateRange * 0.1);
    final paddedMaxRate = maxRate + (rateRange * 0.1);

    // Draw grid lines
    _drawGrid(
        canvas, chartRect, minYear, maxYear, paddedMinRate, paddedMaxRate);

    // Draw chart line
    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final point = data[i];
      final x = chartRect.left +
          (point.year - minYear) / (maxYear - minYear) * chartRect.width;
      final y = chartRect.bottom -
          (point.rate - paddedMinRate) /
              (paddedMaxRate - paddedMinRate) *
              chartRect.height;

      final offset = Offset(x, y);
      points.add(offset);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw line
    canvas.drawPath(path, paint);

    // Draw points
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final dataPoint = data[i];

      // Draw point circle
      canvas.drawCircle(
          point, 4, pointPaint..color = dataPoint.color ?? primaryColor);
      canvas.drawCircle(
          point,
          4,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);

      // Draw rate label
      textPainter.text = TextSpan(
        text: '${(dataPoint.rate * 100).toStringAsFixed(1)}%',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(point.dx - textPainter.width / 2, point.dy - 20),
      );
    }

    // Draw axis labels
    _drawAxisLabels(
        canvas, chartRect, minYear, maxYear, paddedMinRate, paddedMaxRate);
  }

  void _drawGrid(Canvas canvas, Rect chartRect, int minYear, int maxYear,
      double minRate, double maxRate) {
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    // Vertical grid lines (years)
    final yearStep = ((maxYear - minYear) / 5).ceil();
    for (int year = minYear; year <= maxYear; year += yearStep) {
      final x = chartRect.left +
          (year - minYear) / (maxYear - minYear) * chartRect.width;
      canvas.drawLine(
        Offset(x, chartRect.top),
        Offset(x, chartRect.bottom),
        gridPaint,
      );
    }

    // Horizontal grid lines (rates)
    final rateStep = (maxRate - minRate) / 5;
    for (double rate = minRate; rate <= maxRate; rate += rateStep) {
      final y = chartRect.bottom -
          (rate - minRate) / (maxRate - minRate) * chartRect.height;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }
  }

  void _drawAxisLabels(Canvas canvas, Rect chartRect, int minYear, int maxYear,
      double minRate, double maxRate) {
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // Y-axis labels (rates)
    final rateStep = (maxRate - minRate) / 5;
    for (double rate = minRate; rate <= maxRate; rate += rateStep) {
      final y = chartRect.bottom -
          (rate - minRate) / (maxRate - minRate) * chartRect.height;

      textPainter.text = TextSpan(
        text: '${(rate * 100).toStringAsFixed(1)}%',
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
            chartRect.left - textPainter.width - 8, y - textPainter.height / 2),
      );
    }

    // X-axis labels (years)
    final yearStep = ((maxYear - minYear) / 5).ceil();
    for (int year = minYear; year <= maxYear; year += yearStep) {
      final x = chartRect.left +
          (year - minYear) / (maxYear - minYear) * chartRect.width;

      textPainter.text = TextSpan(
        text: year.toString(),
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, chartRect.bottom + 8),
      );
    }
  }

  @override
  bool shouldRepaint(TaxRateChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.primaryColor != primaryColor;
  }
}
