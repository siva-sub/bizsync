import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path/path.dart' as path;

/// Chart Data Point
class ChartDataPoint {
  final dynamic x;
  final dynamic y;
  final String? label;
  final Color? color;
  final Map<String, dynamic>? metadata;

  ChartDataPoint({
    required this.x,
    required this.y,
    this.label,
    this.color,
    this.metadata,
  });
}

/// Chart Configuration
class ChartConfig {
  final String title;
  final String? subtitle;
  final String xAxisLabel;
  final String yAxisLabel;
  final ChartType type;
  final bool enableZoom;
  final bool enablePan;
  final bool showLegend;
  final bool showGrid;
  final bool showTooltips;
  final Color? primaryColor;
  final List<Color>? colorPalette;
  final Map<String, dynamic> customSettings;

  ChartConfig({
    required this.title,
    this.subtitle,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.type,
    this.enableZoom = true,
    this.enablePan = true,
    this.showLegend = true,
    this.showGrid = true,
    this.showTooltips = true,
    this.primaryColor,
    this.colorPalette,
    this.customSettings = const {},
  });
}

/// Chart Types
enum ChartType {
  line,
  bar,
  pie,
  area,
  scatter,
  column,
  spline,
  bubble,
  doughnut,
  radar,
  funnel,
  pyramid,
}

/// Export Format
enum ExportFormat {
  png,
  jpg,
  pdf,
  svg,
}

/// Chart Series Data
class ChartSeries {
  final String name;
  final List<ChartDataPoint> dataPoints;
  final Color? color;
  final ChartType? seriesType;
  final bool visible;

  ChartSeries({
    required this.name,
    required this.dataPoints,
    this.color,
    this.seriesType,
    this.visible = true,
  });
}

/// Interactive Chart Widget
class InteractiveChartWidget extends StatefulWidget {
  final List<ChartSeries> series;
  final ChartConfig config;
  final Function(ChartDataPoint dataPoint)? onDataPointTapped;
  final Function(List<ChartDataPoint> dataPoints)? onSelectionChanged;

  const InteractiveChartWidget({
    Key? key,
    required this.series,
    required this.config,
    this.onDataPointTapped,
    this.onSelectionChanged,
  }) : super(key: key);

  @override
  State<InteractiveChartWidget> createState() => _InteractiveChartWidgetState();
}

class _InteractiveChartWidgetState extends State<InteractiveChartWidget> {
  late TooltipBehavior _tooltipBehavior;
  late ZoomPanBehavior _zoomPanBehavior;
  late SelectionBehavior _selectionBehavior;

  @override
  void initState() {
    super.initState();
    
    _tooltipBehavior = TooltipBehavior(
      enable: widget.config.showTooltips,
      canShowMarker: true,
      header: '',
      format: 'point.x : point.y',
    );
    
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: widget.config.enableZoom,
      enablePanning: widget.config.enablePan,
      enableDoubleTapZooming: widget.config.enableZoom,
      enableMouseWheelZooming: widget.config.enableZoom,
      enableSelectionZooming: widget.config.enableZoom,
    );
    
    _selectionBehavior = SelectionBehavior(
      enable: true,
      toggleSelection: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildSyncfusionChart();
  }

  Widget _buildSyncfusionChart() {
    switch (widget.config.type) {
      case ChartType.line:
        return _buildLineChart();
      case ChartType.bar:
        return _buildBarChart();
      case ChartType.pie:
        return _buildPieChart();
      case ChartType.area:
        return _buildAreaChart();
      case ChartType.column:
        return _buildColumnChart();
      case ChartType.scatter:
        return _buildScatterChart();
      default:
        return _buildLineChart();
    }
  }

  Widget _buildLineChart() {
    return SfCartesianChart(
      title: ChartTitle(text: widget.config.title),
      legend: Legend(isVisible: widget.config.showLegend),
      tooltipBehavior: _tooltipBehavior,
      zoomPanBehavior: _zoomPanBehavior,
      primaryXAxis: CategoryAxis(
        title: AxisTitle(text: widget.config.xAxisLabel),
        majorGridLines: MajorGridLines(width: widget.config.showGrid ? 1 : 0),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: widget.config.yAxisLabel),
        majorGridLines: MajorGridLines(width: widget.config.showGrid ? 1 : 0),
      ),
      series: widget.series.map((series) => LineSeries<ChartDataPoint, dynamic>(
        name: series.name,
        dataSource: series.dataPoints,
        xValueMapper: (ChartDataPoint data, _) => data.x,
        yValueMapper: (ChartDataPoint data, _) => data.y,
        color: series.color ?? widget.config.primaryColor,
        markerSettings: const MarkerSettings(isVisible: true),
        enableTooltip: widget.config.showTooltips,
        selectionBehavior: _selectionBehavior,
        onPointTap: (pointInteractionDetails) {
          if (widget.onDataPointTapped != null) {
            final dataPoint = widget.series[pointInteractionDetails.seriesIndex]
                .dataPoints[pointInteractionDetails.pointIndex!];
            widget.onDataPointTapped!(dataPoint);
          }
        },
      )).toList(),
    );
  }

  Widget _buildBarChart() {
    return SfCartesianChart(
      title: ChartTitle(text: widget.config.title),
      legend: Legend(isVisible: widget.config.showLegend),
      tooltipBehavior: _tooltipBehavior,
      zoomPanBehavior: _zoomPanBehavior,
      primaryXAxis: CategoryAxis(
        title: AxisTitle(text: widget.config.xAxisLabel),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: widget.config.yAxisLabel),
      ),
      series: widget.series.map((series) => BarSeries<ChartDataPoint, dynamic>(
        name: series.name,
        dataSource: series.dataPoints,
        xValueMapper: (ChartDataPoint data, _) => data.x,
        yValueMapper: (ChartDataPoint data, _) => data.y,
        color: series.color ?? widget.config.primaryColor,
        enableTooltip: widget.config.showTooltips,
        selectionBehavior: _selectionBehavior,
      )).toList(),
    );
  }

  Widget _buildPieChart() {
    final firstSeries = widget.series.first;
    return SfCircularChart(
      title: ChartTitle(text: widget.config.title),
      legend: Legend(isVisible: widget.config.showLegend),
      tooltipBehavior: _tooltipBehavior,
      series: <PieSeries<ChartDataPoint, String>>[
        PieSeries<ChartDataPoint, String>(
          name: firstSeries.name,
          dataSource: firstSeries.dataPoints,
          xValueMapper: (ChartDataPoint data, _) => data.x.toString(),
          yValueMapper: (ChartDataPoint data, _) => data.y,
          dataLabelMapper: (ChartDataPoint data, _) => data.label ?? data.x.toString(),
          dataLabelSettings: const DataLabelSettings(isVisible: true),
          enableTooltip: widget.config.showTooltips,
          selectionBehavior: _selectionBehavior,
        ),
      ],
    );
  }

  Widget _buildAreaChart() {
    return SfCartesianChart(
      title: ChartTitle(text: widget.config.title),
      legend: Legend(isVisible: widget.config.showLegend),
      tooltipBehavior: _tooltipBehavior,
      zoomPanBehavior: _zoomPanBehavior,
      primaryXAxis: CategoryAxis(
        title: AxisTitle(text: widget.config.xAxisLabel),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: widget.config.yAxisLabel),
      ),
      series: widget.series.map((series) => AreaSeries<ChartDataPoint, dynamic>(
        name: series.name,
        dataSource: series.dataPoints,
        xValueMapper: (ChartDataPoint data, _) => data.x,
        yValueMapper: (ChartDataPoint data, _) => data.y,
        color: series.color ?? widget.config.primaryColor,
        enableTooltip: widget.config.showTooltips,
        selectionBehavior: _selectionBehavior,
      )).toList(),
    );
  }

  Widget _buildColumnChart() {
    return SfCartesianChart(
      title: ChartTitle(text: widget.config.title),
      legend: Legend(isVisible: widget.config.showLegend),
      tooltipBehavior: _tooltipBehavior,
      zoomPanBehavior: _zoomPanBehavior,
      primaryXAxis: CategoryAxis(
        title: AxisTitle(text: widget.config.xAxisLabel),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: widget.config.yAxisLabel),
      ),
      series: widget.series.map((series) => ColumnSeries<ChartDataPoint, dynamic>(
        name: series.name,
        dataSource: series.dataPoints,
        xValueMapper: (ChartDataPoint data, _) => data.x,
        yValueMapper: (ChartDataPoint data, _) => data.y,
        color: series.color ?? widget.config.primaryColor,
        enableTooltip: widget.config.showTooltips,
        selectionBehavior: _selectionBehavior,
      )).toList(),
    );
  }

  Widget _buildScatterChart() {
    return SfCartesianChart(
      title: ChartTitle(text: widget.config.title),
      legend: Legend(isVisible: widget.config.showLegend),
      tooltipBehavior: _tooltipBehavior,
      zoomPanBehavior: _zoomPanBehavior,
      primaryXAxis: NumericAxis(
        title: AxisTitle(text: widget.config.xAxisLabel),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: widget.config.yAxisLabel),
      ),
      series: widget.series.map((series) => ScatterSeries<ChartDataPoint, dynamic>(
        name: series.name,
        dataSource: series.dataPoints,
        xValueMapper: (ChartDataPoint data, _) => data.x,
        yValueMapper: (ChartDataPoint data, _) => data.y,
        color: series.color ?? widget.config.primaryColor,
        markerSettings: const MarkerSettings(
          height: 8,
          width: 8,
          shape: DataMarkerType.circle,
        ),
        enableTooltip: widget.config.showTooltips,
        selectionBehavior: _selectionBehavior,
      )).toList(),
    );
  }
}

/// Enhanced Data Visualization Service for Linux Desktop
/// 
/// Provides advanced data visualization capabilities:
/// - Interactive charts with zoom/pan
/// - Export charts as images
/// - Full-screen chart view
/// - Multiple chart types
/// - Custom styling and themes
class DataVisualizationService {
  static final DataVisualizationService _instance = DataVisualizationService._internal();
  factory DataVisualizationService() => _instance;
  DataVisualizationService._internal();

  bool _isInitialized = false;
  final GlobalKey _chartKey = GlobalKey();

  /// Default color palette
  final List<Color> _defaultColorPalette = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.lime,
    Colors.cyan,
  ];

  /// Initialize the data visualization service
  Future<void> initialize() async {
    try {
      _isInitialized = true;
      debugPrint('✅ Data visualization service initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize data visualization service: $e');
    }
  }

  /// Create revenue chart
  Widget createRevenueChart({
    required List<Map<String, dynamic>> revenueData,
    ChartConfig? config,
  }) {
    final series = ChartSeries(
      name: 'Revenue',
      dataPoints: revenueData.map((data) => ChartDataPoint(
        x: data['month'] ?? data['date'],
        y: data['revenue'] ?? data['amount'],
        label: data['label'],
      )).toList(),
      color: Colors.green,
    );

    final chartConfig = config ?? ChartConfig(
      title: 'Revenue Over Time',
      xAxisLabel: 'Time Period',
      yAxisLabel: 'Revenue (\$)',
      type: ChartType.line,
    );

    return InteractiveChartWidget(
      series: [series],
      config: chartConfig,
    );
  }

  /// Create sales chart
  Widget createSalesChart({
    required List<Map<String, dynamic>> salesData,
    ChartConfig? config,
  }) {
    final series = ChartSeries(
      name: 'Sales',
      dataPoints: salesData.map((data) => ChartDataPoint(
        x: data['product'] ?? data['category'],
        y: data['sales'] ?? data['count'],
        label: data['label'],
      )).toList(),
      color: Colors.blue,
    );

    final chartConfig = config ?? ChartConfig(
      title: 'Sales by Product',
      xAxisLabel: 'Products',
      yAxisLabel: 'Sales Count',
      type: ChartType.column,
    );

    return InteractiveChartWidget(
      series: [series],
      config: chartConfig,
    );
  }

  /// Create customer distribution chart
  Widget createCustomerDistributionChart({
    required List<Map<String, dynamic>> customerData,
    ChartConfig? config,
  }) {
    final series = ChartSeries(
      name: 'Customers',
      dataPoints: customerData.map((data) => ChartDataPoint(
        x: data['region'] ?? data['category'],
        y: data['count'] ?? data['customers'],
        label: data['label'],
      )).toList(),
    );

    final chartConfig = config ?? ChartConfig(
      title: 'Customer Distribution',
      xAxisLabel: 'Region',
      yAxisLabel: 'Customer Count',
      type: ChartType.pie,
    );

    return InteractiveChartWidget(
      series: [series],
      config: chartConfig,
    );
  }

  /// Create inventory levels chart
  Widget createInventoryLevelsChart({
    required List<Map<String, dynamic>> inventoryData,
    ChartConfig? config,
  }) {
    final series = ChartSeries(
      name: 'Stock Levels',
      dataPoints: inventoryData.map((data) => ChartDataPoint(
        x: data['product'] ?? data['sku'],
        y: data['stock'] ?? data['quantity'],
        label: data['label'],
        color: (data['stock'] ?? 0) < (data['minStock'] ?? 10) 
            ? Colors.red 
            : Colors.green,
      )).toList(),
    );

    final chartConfig = config ?? ChartConfig(
      title: 'Inventory Levels',
      xAxisLabel: 'Products',
      yAxisLabel: 'Stock Quantity',
      type: ChartType.bar,
    );

    return InteractiveChartWidget(
      series: [series],
      config: chartConfig,
    );
  }

  /// Create expense breakdown chart
  Widget createExpenseBreakdownChart({
    required List<Map<String, dynamic>> expenseData,
    ChartConfig? config,
  }) {
    final series = ChartSeries(
      name: 'Expenses',
      dataPoints: expenseData.map((data) => ChartDataPoint(
        x: data['category'] ?? data['type'],
        y: data['amount'] ?? data['expense'],
        label: data['label'],
      )).toList(),
    );

    final chartConfig = config ?? ChartConfig(
      title: 'Expense Breakdown',
      xAxisLabel: 'Categories',
      yAxisLabel: 'Amount (\$)',
      type: ChartType.doughnut,
    );

    return InteractiveChartWidget(
      series: [series],
      config: chartConfig,
    );
  }

  /// Create multi-series comparison chart
  Widget createComparisonChart({
    required List<ChartSeries> series,
    required ChartConfig config,
  }) {
    // Assign colors from palette if not specified
    for (int i = 0; i < series.length; i++) {
      if (series[i].color == null) {
        final colorIndex = i % _defaultColorPalette.length;
        series[i] = ChartSeries(
          name: series[i].name,
          dataPoints: series[i].dataPoints,
          color: _defaultColorPalette[colorIndex],
          seriesType: series[i].seriesType,
          visible: series[i].visible,
        );
      }
    }

    return InteractiveChartWidget(
      series: series,
      config: config,
    );
  }

  /// Export chart as image
  Future<String?> exportChartAsImage({
    required Widget chart,
    required ExportFormat format,
    String? fileName,
    String? directory,
  }) async {
    if (!_isInitialized) return null;

    try {
      // Create a RepaintBoundary widget to capture the chart
      final boundary = RepaintBoundary(
        key: _chartKey,
        child: Container(
          width: 800,
          height: 600,
          color: Colors.white,
          child: chart,
        ),
      );

      // Render the widget to get the image
      final renderObject = _chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (renderObject == null) {
        debugPrint('Could not find render object for chart');
        return null;
      }

      final image = await renderObject.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        debugPrint('Failed to convert chart to image data');
        return null;
      }

      // Generate file name and path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = format.toString().split('.').last;
      final filename = fileName ?? 'chart_$timestamp.$extension';
      
      final outputDirectory = directory ?? Directory.current.path;
      final filePath = path.join(outputDirectory, filename);

      // Save the image
      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      debugPrint('Chart exported to: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('Failed to export chart: $e');
      return null;
    }
  }

  /// Show chart in full-screen dialog
  void showFullScreenChart({
    required BuildContext context,
    required Widget chart,
    String? title,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(title ?? 'Chart View'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 1,
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () async {
                  final filePath = await exportChartAsImage(
                    chart: chart,
                    format: ExportFormat.png,
                  );
                  if (filePath != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Chart exported to: $filePath'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          body: Container(
            padding: const EdgeInsets.all(16),
            child: chart,
          ),
        ),
      ),
    );
  }

  /// Create chart toolbar with common actions
  Widget createChartToolbar({
    required Widget chart,
    required BuildContext context,
    String? title,
  }) {
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              if (title != null)
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.fullscreen),
                onPressed: () => showFullScreenChart(
                  context: context,
                  chart: chart,
                  title: title,
                ),
                tooltip: 'Full Screen',
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () async {
                  final filePath = await exportChartAsImage(
                    chart: chart,
                    format: ExportFormat.png,
                  );
                  if (filePath != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Chart exported to: $filePath'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                tooltip: 'Export',
              ),
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: () {
                  // Integration with print service would go here
                  debugPrint('Print chart functionality');
                },
                tooltip: 'Print',
              ),
            ],
          ),
        ),
        Expanded(child: chart),
      ],
    );
  }

  /// Generate sample data for demonstration
  List<Map<String, dynamic>> generateSampleRevenueData() {
    return [
      {'month': 'Jan', 'revenue': 15000},
      {'month': 'Feb', 'revenue': 18000},
      {'month': 'Mar', 'revenue': 22000},
      {'month': 'Apr', 'revenue': 19000},
      {'month': 'May', 'revenue': 25000},
      {'month': 'Jun', 'revenue': 28000},
      {'month': 'Jul', 'revenue': 32000},
      {'month': 'Aug', 'revenue': 29000},
      {'month': 'Sep', 'revenue': 35000},
      {'month': 'Oct', 'revenue': 38000},
      {'month': 'Nov', 'revenue': 42000},
      {'month': 'Dec', 'revenue': 45000},
    ];
  }

  /// Generate sample sales data
  List<Map<String, dynamic>> generateSampleSalesData() {
    return [
      {'product': 'Laptops', 'sales': 120},
      {'product': 'Phones', 'sales': 200},
      {'product': 'Tablets', 'sales': 80},
      {'product': 'Monitors', 'sales': 65},
      {'product': 'Keyboards', 'sales': 150},
      {'product': 'Mice', 'sales': 180},
    ];
  }

  /// Generate sample customer distribution data
  List<Map<String, dynamic>> generateSampleCustomerData() {
    return [
      {'region': 'North America', 'count': 450},
      {'region': 'Europe', 'count': 320},
      {'region': 'Asia Pacific', 'count': 280},
      {'region': 'South America', 'count': 150},
      {'region': 'Africa', 'count': 80},
    ];
  }

  /// Get default color palette
  List<Color> get defaultColorPalette => List.unmodifiable(_defaultColorPalette);

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose of the data visualization service
  Future<void> dispose() async {
    _isInitialized = false;
    debugPrint('Data visualization service disposed');
  }
}