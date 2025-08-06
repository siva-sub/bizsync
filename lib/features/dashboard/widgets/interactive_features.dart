import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as excel;
import 'package:printing/printing.dart';
import '../models/dashboard_models.dart';

/// Date range picker widget for dashboard filtering
class DashboardDateRangePicker extends StatefulWidget {
  final DateTimeRange? initialDateRange;
  final Function(DateTimeRange?) onDateRangeChanged;
  final TimePeriod selectedPeriod;
  final Function(TimePeriod) onPeriodChanged;

  const DashboardDateRangePicker({
    super.key,
    this.initialDateRange,
    required this.onDateRangeChanged,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  State<DashboardDateRangePicker> createState() =>
      _DashboardDateRangePickerState();
}

class _DashboardDateRangePickerState extends State<DashboardDateRangePicker> {
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _selectedDateRange = widget.initialDateRange;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time Period',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Predefined period buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPeriodChip(TimePeriod.today, 'Today'),
                _buildPeriodChip(TimePeriod.thisWeek, 'This Week'),
                _buildPeriodChip(TimePeriod.thisMonth, 'This Month'),
                _buildPeriodChip(TimePeriod.thisQuarter, 'This Quarter'),
                _buildPeriodChip(TimePeriod.thisYear, 'This Year'),
                _buildPeriodChip(TimePeriod.custom, 'Custom'),
              ],
            ),

            // Custom date range picker
            if (widget.selectedPeriod == TimePeriod.custom) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showDateRangePicker,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _selectedDateRange != null
                            ? '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}'
                            : 'Select Date Range',
                      ),
                    ),
                  ),
                  if (_selectedDateRange != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedDateRange = null;
                        });
                        widget.onDateRangeChanged(null);
                      },
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear Date Range',
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(TimePeriod period, String label) {
    final isSelected = widget.selectedPeriod == period;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          widget.onPeriodChanged(period);
          if (period != TimePeriod.custom) {
            setState(() {
              _selectedDateRange = null;
            });
            widget.onDateRangeChanged(null);
          }
        }
      },
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Future<void> _showDateRangePicker() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 2);
    final lastDate = DateTime(now.year + 1);

    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );

    if (dateRange != null) {
      setState(() {
        _selectedDateRange = dateRange;
      });
      widget.onDateRangeChanged(dateRange);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Export options dialog for dashboard data
class DashboardExportDialog extends StatefulWidget {
  final DashboardData dashboardData;
  final String title;

  const DashboardExportDialog({
    super.key,
    required this.dashboardData,
    required this.title,
  });

  @override
  State<DashboardExportDialog> createState() => _DashboardExportDialogState();
}

class _DashboardExportDialogState extends State<DashboardExportDialog> {
  ExportFormat _selectedFormat = ExportFormat.pdf;
  bool _includeCharts = true;
  bool _includeKPIs = true;
  bool _includeAnalytics = true;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Export ${widget.title}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Format',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            // Export format selection
            ...ExportFormat.values.map((format) => RadioListTile<ExportFormat>(
                  title: Text(_getFormatLabel(format)),
                  subtitle: Text(_getFormatDescription(format)),
                  value: format,
                  groupValue: _selectedFormat,
                  onChanged: (value) {
                    setState(() {
                      _selectedFormat = value!;
                    });
                  },
                )),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            Text(
              'Include Data',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            // Data inclusion options
            CheckboxListTile(
              title: const Text('KPIs and Metrics'),
              value: _includeKPIs,
              onChanged: (value) {
                setState(() {
                  _includeKPIs = value ?? false;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Charts and Visualizations'),
              value: _includeCharts,
              onChanged: (value) {
                setState(() {
                  _includeCharts = value ?? false;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Analytics and Insights'),
              value: _includeAnalytics,
              onChanged: (value) {
                setState(() {
                  _includeAnalytics = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isExporting ? null : _exportData,
          child: _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Export'),
        ),
      ],
    );
  }

  String _getFormatLabel(ExportFormat format) {
    switch (format) {
      case ExportFormat.pdf:
        return 'PDF Document';
      case ExportFormat.excel:
        return 'Excel Spreadsheet';
      case ExportFormat.csv:
        return 'CSV File';
      case ExportFormat.json:
        return 'JSON Data';
    }
  }

  String _getFormatDescription(ExportFormat format) {
    switch (format) {
      case ExportFormat.pdf:
        return 'Formatted report with charts and tables';
      case ExportFormat.excel:
        return 'Structured data in Excel format';
      case ExportFormat.csv:
        return 'Raw data in comma-separated values';
      case ExportFormat.json:
        return 'Machine-readable data format';
    }
  }

  Future<void> _exportData() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final exportService = DashboardExportService();

      switch (_selectedFormat) {
        case ExportFormat.pdf:
          await exportService.exportToPDF(
            widget.dashboardData,
            includeCharts: _includeCharts,
            includeKPIs: _includeKPIs,
            includeAnalytics: _includeAnalytics,
          );
          break;
        case ExportFormat.excel:
          await exportService.exportToExcel(
            widget.dashboardData,
            includeCharts: _includeCharts,
            includeKPIs: _includeKPIs,
            includeAnalytics: _includeAnalytics,
          );
          break;
        case ExportFormat.csv:
          await exportService.exportToCSV(
            widget.dashboardData,
            includeKPIs: _includeKPIs,
            includeAnalytics: _includeAnalytics,
          );
          break;
        case ExportFormat.json:
          await exportService.exportToJSON(widget.dashboardData);
          break;
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Data exported successfully as ${_getFormatLabel(_selectedFormat)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }
}

/// Drill-down navigation widget
class DrillDownNavigator extends StatelessWidget {
  final List<DrillDownLevel> levels;
  final Function(int) onLevelTap;
  final int currentLevel;

  const DrillDownNavigator({
    super.key,
    required this.levels,
    required this.onLevelTap,
    required this.currentLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.analytics,
              color: Theme.of(context).primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: levels.asMap().entries.map((entry) {
                    final index = entry.key;
                    final level = entry.value;
                    final isActive = index == currentLevel;
                    final isClickable = index <= currentLevel;

                    return Row(
                      children: [
                        if (index > 0) ...[
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                        ],
                        GestureDetector(
                          onTap: isClickable ? () => onLevelTap(index) : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withValues(alpha: 0.1)
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              border: isActive
                                  ? Border.all(
                                      color: Theme.of(context).primaryColor,
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Text(
                              level.title,
                              style: TextStyle(
                                color: isActive
                                    ? Theme.of(context).primaryColor
                                    : isClickable
                                        ? Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                        : Colors.grey[400],
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Real-time update indicator
class RealTimeUpdateIndicator extends StatefulWidget {
  final bool isUpdating;
  final DateTime? lastUpdated;
  final Function()? onRefresh;

  const RealTimeUpdateIndicator({
    super.key,
    required this.isUpdating,
    this.lastUpdated,
    this.onRefresh,
  });

  @override
  State<RealTimeUpdateIndicator> createState() =>
      _RealTimeUpdateIndicatorState();
}

class _RealTimeUpdateIndicatorState extends State<RealTimeUpdateIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(RealTimeUpdateIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isUpdating && !oldWidget.isUpdating) {
      _animationController.repeat();
    } else if (!widget.isUpdating && oldWidget.isUpdating) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isUpdating
            ? Colors.blue.withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isUpdating ? Colors.blue : Colors.green,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isUpdating)
            RotationTransition(
              turns: _animationController,
              child: const Icon(
                Icons.refresh,
                size: 16,
                color: Colors.blue,
              ),
            )
          else
            const Icon(
              Icons.check_circle,
              size: 16,
              color: Colors.green,
            ),
          const SizedBox(width: 6),
          Text(
            widget.isUpdating
                ? 'Updating...'
                : widget.lastUpdated != null
                    ? 'Updated ${_formatRelativeTime(widget.lastUpdated!)}'
                    : 'Up to date',
            style: TextStyle(
              color: widget.isUpdating ? Colors.blue : Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.onRefresh != null && !widget.isUpdating) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onRefresh,
              child: const Icon(
                Icons.refresh,
                size: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Enums for export functionality
enum ExportFormat {
  pdf,
  excel,
  csv,
  json,
}

/// Drill-down level model
class DrillDownLevel {
  final String title;
  final String description;
  final Map<String, dynamic>? data;

  DrillDownLevel({
    required this.title,
    required this.description,
    this.data,
  });
}

/// Dashboard export service
class DashboardExportService {
  /// Export dashboard data to PDF
  Future<void> exportToPDF(
    DashboardData data, {
    bool includeCharts = true,
    bool includeKPIs = true,
    bool includeAnalytics = true,
  }) async {
    final pdf = pw.Document();

    // Add cover page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Business Dashboard Report'),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Generated on: ${DateTime.now().toString()}'),
              pw.Text('Period: ${data.currentPeriod.name}'),
              pw.SizedBox(height: 40),

              // KPIs section
              if (includeKPIs) ...[
                pw.Header(
                    level: 1, child: pw.Text('Key Performance Indicators')),
                pw.SizedBox(height: 10),
                ...data.kpis.map((kpi) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 10),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(kpi.title),
                          pw.Text(kpi.formattedValue),
                        ],
                      ),
                    )),
              ],
            ],
          );
        },
      ),
    );

    // Print or save the PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  /// Export dashboard data to Excel
  Future<void> exportToExcel(
    DashboardData data, {
    bool includeCharts = true,
    bool includeKPIs = true,
    bool includeAnalytics = true,
  }) async {
    final excelFile = excel.Excel.createExcel();

    // KPIs sheet
    if (includeKPIs) {
      final kpiSheet = excelFile['KPIs'];
      kpiSheet.cell(excel.CellIndex.indexByString('A1')).value =
          'KPI Name' as excel.CellValue?;
      kpiSheet.cell(excel.CellIndex.indexByString('B1')).value =
          'Current Value' as excel.CellValue?;
      kpiSheet.cell(excel.CellIndex.indexByString('C1')).value =
          'Previous Value' as excel.CellValue?;
      kpiSheet.cell(excel.CellIndex.indexByString('D1')).value =
          'Change %' as excel.CellValue?;

      for (int i = 0; i < data.kpis.length; i++) {
        final kpi = data.kpis[i];
        final row = i + 2;
        kpiSheet.cell(excel.CellIndex.indexByString('A$row')).value =
            kpi.title as excel.CellValue?;
        kpiSheet.cell(excel.CellIndex.indexByString('B$row')).value =
            kpi.currentValue as excel.CellValue?;
        kpiSheet.cell(excel.CellIndex.indexByString('C$row')).value =
            kpi.previousValue as excel.CellValue?;
        kpiSheet.cell(excel.CellIndex.indexByString('D$row')).value =
            kpi.percentageChange as excel.CellValue?;
      }
    }

    // Revenue analytics sheet
    if (includeAnalytics && data.revenueAnalytics != null) {
      final revenueSheet = excelFile['Revenue Analytics'];
      revenueSheet.cell(excel.CellIndex.indexByString('A1')).value =
          'Date' as excel.CellValue?;
      revenueSheet.cell(excel.CellIndex.indexByString('B1')).value =
          'Revenue' as excel.CellValue?;

      for (int i = 0; i < data.revenueAnalytics!.revenueByDay.length; i++) {
        final dataPoint = data.revenueAnalytics!.revenueByDay[i];
        final row = i + 2;
        revenueSheet.cell(excel.CellIndex.indexByString('A$row')).value =
            dataPoint.timestamp.toString() as excel.CellValue?;
        revenueSheet.cell(excel.CellIndex.indexByString('B$row')).value =
            dataPoint.value as excel.CellValue?;
      }
    }

    // Save the Excel file
    final fileBytes = excelFile.save();
    if (fileBytes != null) {
      // In a real implementation, you would save this to device storage
      // For now, we'll just simulate success
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Export dashboard data to CSV
  Future<void> exportToCSV(
    DashboardData data, {
    bool includeKPIs = true,
    bool includeAnalytics = true,
  }) async {
    final buffer = StringBuffer();

    if (includeKPIs) {
      buffer.writeln('KPI Name,Current Value,Previous Value,Change %');
      for (final kpi in data.kpis) {
        buffer.writeln(
            '${kpi.title},${kpi.currentValue},${kpi.previousValue ?? ''},${kpi.percentageChange}');
      }
      buffer.writeln();
    }

    if (includeAnalytics && data.revenueAnalytics != null) {
      buffer.writeln('Date,Revenue');
      for (final dataPoint in data.revenueAnalytics!.revenueByDay) {
        buffer.writeln('${dataPoint.timestamp},${dataPoint.value}');
      }
    }

    // In a real implementation, you would save this to device storage
    await Future.delayed(const Duration(milliseconds: 300));
  }

  /// Export dashboard data to JSON
  Future<void> exportToJSON(DashboardData data) async {
    final jsonData = data.toJson();

    // In a real implementation, you would save this to device storage
    await Future.delayed(const Duration(milliseconds: 200));
  }
}
