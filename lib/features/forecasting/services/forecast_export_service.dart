import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/forecasting_models.dart';

/// Service for exporting forecast data and reports
class ForecastExportService {
  static ForecastExportService? _instance;

  ForecastExportService._internal();

  static ForecastExportService getInstance() {
    _instance ??= ForecastExportService._internal();
    return _instance!;
  }

  /// Export forecast session to PDF
  Future<File> exportToPdf(
    ForecastSession session, {
    bool includeCharts = true,
    List<Uint8List>? chartImages,
  }) async {
    final pdf = pw.Document();
    final dateFormatter = DateFormat('MMM dd, yyyy');
    final numberFormatter = NumberFormat.currency(symbol: '\$');

    // Add title page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPdfHeader(session, dateFormatter),
              pw.SizedBox(height: 20),
              _buildExecutiveSummary(session, numberFormatter, dateFormatter),
              pw.SizedBox(height: 20),
              _buildAccuracyMetrics(session),
            ],
          );
        },
      ),
    );

    // Add scenario details
    for (int i = 0; i < session.scenarios.length; i++) {
      final scenario = session.scenarios[i];
      final results = session.results[scenario.id] ?? [];
      final accuracy = session.accuracyMetrics[scenario.id];

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildScenarioHeader(scenario),
                pw.SizedBox(height: 15),
                if (accuracy != null) _buildScenarioAccuracy(accuracy),
                pw.SizedBox(height: 15),
                _buildForecastTable(results, numberFormatter, dateFormatter),
              ],
            );
          },
        ),
      );
    }

    // Add charts if provided
    if (includeCharts && chartImages != null) {
      for (int i = 0; i < chartImages.length; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                children: [
                  pw.Text(
                    'Forecast Chart ${i + 1}',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Container(
                    child: pw.Image(pw.MemoryImage(chartImages[i])),
                  ),
                ],
              );
            },
          ),
        );
      }
    }

    // Add historical data appendix
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Historical Data',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 15),
              _buildHistoricalDataTable(session.historicalData, numberFormatter, dateFormatter),
            ],
          );
        },
      ),
    );

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/forecast_${session.name.replaceAll(RegExp(r'[^\w\s-]'), '')}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  pw.Widget _buildPdfHeader(ForecastSession session, DateFormat dateFormatter) {
    return pw.Container(
      width: double.infinity,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BizSync Forecast Report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            session.name,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text('Data Source: ${session.dataSource.toUpperCase()}'),
          pw.Text('Generated: ${dateFormatter.format(DateTime.now())}'),
          pw.Text('Scenarios: ${session.scenarios.length}'),
          pw.Divider(),
        ],
      ),
    );
  }

  pw.Widget _buildExecutiveSummary(
    ForecastSession session,
    NumberFormat numberFormatter,
    DateFormat dateFormatter,
  ) {
    final bestScenario = _getBestScenario(session);
    final avgForecast = _getAverageForecast(session);

    return pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Executive Summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          if (bestScenario != null) ...[
            pw.Text('Best Performing Model: ${bestScenario['scenario'].name}'),
            pw.Text('R² Score: ${(bestScenario['accuracy'].r2 * 100).toStringAsFixed(1)}%'),
            pw.Text('MAPE: ${bestScenario['accuracy'].mape.toStringAsFixed(1)}%'),
          ],
          if (avgForecast != null) ...[
            pw.SizedBox(height: 10),
            pw.Text('Average Next Period Forecast: ${numberFormatter.format(avgForecast)}'),
          ],
          pw.SizedBox(height: 10),
          pw.Text('Historical Data Points: ${session.historicalData.length}'),
          pw.Text('Forecast Period: ${session.scenarios.isNotEmpty ? session.scenarios.first.forecastHorizon : 0} periods'),
        ],
      ),
    );
  }

  Map<String, dynamic>? _getBestScenario(ForecastSession session) {
    ForecastScenario? bestScenario;
    ForecastAccuracy? bestAccuracy;
    double bestScore = -1;

    for (final scenario in session.scenarios) {
      final accuracy = session.accuracyMetrics[scenario.id];
      if (accuracy != null) {
        final score = accuracy.r2;
        if (score > bestScore) {
          bestScore = score;
          bestScenario = scenario;
          bestAccuracy = accuracy;
        }
      }
    }

    if (bestScenario != null && bestAccuracy != null) {
      return {'scenario': bestScenario, 'accuracy': bestAccuracy};
    }
    return null;
  }

  double? _getAverageForecast(ForecastSession session) {
    final allFirstForecasts = <double>[];
    
    for (final results in session.results.values) {
      if (results.isNotEmpty) {
        allFirstForecasts.add(results.first.predictedValue);
      }
    }

    if (allFirstForecasts.isEmpty) return null;

    return allFirstForecasts.reduce((a, b) => a + b) / allFirstForecasts.length;
  }

  pw.Widget _buildAccuracyMetrics(ForecastSession session) {
    if (session.accuracyMetrics.isEmpty) {
      return pw.Text('No accuracy metrics available');
    }

    return pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Model Accuracy Comparison',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Model', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('R²', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('MAPE (%)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('RMSE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              ...session.accuracyMetrics.entries.map((entry) {
                final scenarioName = session.scenarios
                    .firstWhere((s) => s.id == entry.key, orElse: () => session.scenarios.first)
                    .name;
                final accuracy = entry.value;
                
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(scenarioName),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text((accuracy.r2 * 100).toStringAsFixed(1)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(accuracy.mape.toStringAsFixed(1)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(accuracy.rmse.toStringAsFixed(2)),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildScenarioHeader(ForecastScenario scenario) {
    return pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            scenario.name,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(scenario.description),
          pw.Text('Method: ${scenario.method.displayName}'),
          pw.Text('Forecast Horizon: ${scenario.forecastHorizon} periods'),
          pw.Text('Confidence Level: ${(scenario.confidenceLevel * 100).toInt()}%'),
        ],
      ),
    );
  }

  pw.Widget _buildScenarioAccuracy(ForecastAccuracy accuracy) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(
            children: [
              pw.Text('R²', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text((accuracy.r2 * 100).toStringAsFixed(1) + '%'),
            ],
          ),
          pw.Column(
            children: [
              pw.Text('MAPE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(accuracy.mape.toStringAsFixed(1) + '%'),
            ],
          ),
          pw.Column(
            children: [
              pw.Text('RMSE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(accuracy.rmse.toStringAsFixed(2)),
            ],
          ),
          pw.Column(
            children: [
              pw.Text('MAE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(accuracy.mae.toStringAsFixed(2)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildForecastTable(
    List<ForecastResult> results,
    NumberFormat numberFormatter,
    DateFormat dateFormatter,
  ) {
    if (results.isEmpty) {
      return pw.Text('No forecast results available');
    }

    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Forecast', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Lower Bound', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Upper Bound', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
        ...results.take(20).map((result) => pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(dateFormatter.format(result.date)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(numberFormatter.format(result.predictedValue)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(numberFormatter.format(result.lowerBound)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(numberFormatter.format(result.upperBound)),
            ),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildHistoricalDataTable(
    List<TimeSeriesPoint> data,
    NumberFormat numberFormatter,
    DateFormat dateFormatter,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text('Value', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
        ...data.take(50).map((point) => pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(dateFormatter.format(point.date)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(numberFormatter.format(point.value)),
            ),
          ],
        )),
      ],
    );
  }

  /// Export forecast session to Excel
  Future<File> exportToExcel(ForecastSession session) async {
    final excel = Excel.createExcel();
    final dateFormatter = DateFormat('yyyy-MM-dd');

    // Remove default sheet
    excel.delete('Sheet1');

    // Create summary sheet
    final summarySheet = excel['Summary'];
    _addSummarySheet(summarySheet, session, dateFormatter);

    // Create historical data sheet
    final historicalSheet = excel['Historical Data'];
    _addHistoricalDataSheet(historicalSheet, session.historicalData, dateFormatter);

    // Create sheets for each scenario
    for (final scenario in session.scenarios) {
      final results = session.results[scenario.id] ?? [];
      final accuracy = session.accuracyMetrics[scenario.id];
      
      final sheetName = scenario.name.replaceAll(RegExp(r'[^\w\s-]'), '').substring(0, 31.clamp(0, scenario.name.length));
      final scenarioSheet = excel[sheetName];
      _addScenarioSheet(scenarioSheet, scenario, results, accuracy, dateFormatter);
    }

    // Create accuracy comparison sheet
    final accuracySheet = excel['Accuracy Metrics'];
    _addAccuracySheet(accuracySheet, session);

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/forecast_${session.name.replaceAll(RegExp(r'[^\w\s-]'), '')}_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(excel.encode()!);

    return file;
  }

  void _addSummarySheet(Sheet sheet, ForecastSession session, DateFormat dateFormatter) {
    // Header
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('BizSync Forecast Report');
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(session.name);
    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('Data Source: ${session.dataSource.toUpperCase()}');
    sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('Generated: ${dateFormatter.format(DateTime.now())}');
    sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue('Scenarios: ${session.scenarios.length}');

    // Best scenario info
    final bestScenario = _getBestScenario(session);
    if (bestScenario != null) {
      sheet.cell(CellIndex.indexByString('A7')).value = TextCellValue('Best Performing Model:');
      sheet.cell(CellIndex.indexByString('B7')).value = TextCellValue(bestScenario['scenario'].name);
      sheet.cell(CellIndex.indexByString('A8')).value = TextCellValue('R² Score:');
      sheet.cell(CellIndex.indexByString('B8')).value = DoubleCellValue(bestScenario['accuracy'].r2);
      sheet.cell(CellIndex.indexByString('A9')).value = TextCellValue('MAPE:');
      sheet.cell(CellIndex.indexByString('B9')).value = DoubleCellValue(bestScenario['accuracy'].mape);
    }

    // Average forecast
    final avgForecast = _getAverageForecast(session);
    if (avgForecast != null) {
      sheet.cell(CellIndex.indexByString('A11')).value = TextCellValue('Average Next Period Forecast:');
      sheet.cell(CellIndex.indexByString('B11')).value = DoubleCellValue(avgForecast);
    }
  }

  void _addHistoricalDataSheet(Sheet sheet, List<TimeSeriesPoint> data, DateFormat dateFormatter) {
    // Headers
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Date');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Value');

    // Data
    for (int i = 0; i < data.length; i++) {
      final point = data[i];
      sheet.cell(CellIndex.indexByString('A${i + 2}')).value = TextCellValue(dateFormatter.format(point.date));
      sheet.cell(CellIndex.indexByString('B${i + 2}')).value = DoubleCellValue(point.value);
    }
  }

  void _addScenarioSheet(
    Sheet sheet,
    ForecastScenario scenario,
    List<ForecastResult> results,
    ForecastAccuracy? accuracy,
    DateFormat dateFormatter,
  ) {
    // Scenario info
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Scenario: ${scenario.name}');
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue('Method: ${scenario.method.displayName}');
    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('Description: ${scenario.description}');

    // Accuracy metrics
    if (accuracy != null) {
      sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue('Accuracy Metrics:');
      sheet.cell(CellIndex.indexByString('A6')).value = TextCellValue('R² Score:');
      sheet.cell(CellIndex.indexByString('B6')).value = DoubleCellValue(accuracy.r2);
      sheet.cell(CellIndex.indexByString('A7')).value = TextCellValue('MAPE:');
      sheet.cell(CellIndex.indexByString('B7')).value = DoubleCellValue(accuracy.mape);
      sheet.cell(CellIndex.indexByString('A8')).value = TextCellValue('RMSE:');
      sheet.cell(CellIndex.indexByString('B8')).value = DoubleCellValue(accuracy.rmse);
      sheet.cell(CellIndex.indexByString('A9')).value = TextCellValue('MAE:');
      sheet.cell(CellIndex.indexByString('B9')).value = DoubleCellValue(accuracy.mae);
    }

    // Forecast results headers
    final startRow = 11;
    sheet.cell(CellIndex.indexByString('A$startRow')).value = TextCellValue('Date');
    sheet.cell(CellIndex.indexByString('B$startRow')).value = TextCellValue('Forecast');
    sheet.cell(CellIndex.indexByString('C$startRow')).value = TextCellValue('Lower Bound');
    sheet.cell(CellIndex.indexByString('D$startRow')).value = TextCellValue('Upper Bound');
    sheet.cell(CellIndex.indexByString('E$startRow')).value = TextCellValue('Confidence');

    // Forecast results data
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      final row = startRow + 1 + i;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(dateFormatter.format(result.date));
      sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(result.predictedValue);
      sheet.cell(CellIndex.indexByString('C$row')).value = DoubleCellValue(result.lowerBound);
      sheet.cell(CellIndex.indexByString('D$row')).value = DoubleCellValue(result.upperBound);
      sheet.cell(CellIndex.indexByString('E$row')).value = DoubleCellValue(result.confidence);
    }
  }

  void _addAccuracySheet(Sheet sheet, ForecastSession session) {
    // Headers
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Model');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('R² Score');
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('MAPE');
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('RMSE');
    sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('MAE');
    sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue('AIC');
    sheet.cell(CellIndex.indexByString('G1')).value = TextCellValue('BIC');

    // Data
    int row = 2;
    for (final entry in session.accuracyMetrics.entries) {
      final scenarioName = session.scenarios
          .firstWhere((s) => s.id == entry.key, orElse: () => session.scenarios.first)
          .name;
      final accuracy = entry.value;

      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(scenarioName);
      sheet.cell(CellIndex.indexByString('B$row')).value = DoubleCellValue(accuracy.r2);
      sheet.cell(CellIndex.indexByString('C$row')).value = DoubleCellValue(accuracy.mape);
      sheet.cell(CellIndex.indexByString('D$row')).value = DoubleCellValue(accuracy.rmse);
      sheet.cell(CellIndex.indexByString('E$row')).value = DoubleCellValue(accuracy.mae);
      sheet.cell(CellIndex.indexByString('F$row')).value = DoubleCellValue(accuracy.aic);
      sheet.cell(CellIndex.indexByString('G$row')).value = DoubleCellValue(accuracy.bic);
      row++;
    }
  }

  /// Capture widget as image for PDF inclusion
  Future<Uint8List> captureWidgetAsImage(
    GlobalKey key, {
    double pixelRatio = 3.0,
  }) async {
    try {
      final RenderRepaintBoundary boundary = 
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData!.buffer.asUint8List();
    } catch (e) {
      throw Exception('Failed to capture widget as image: $e');
    }
  }

  /// Share exported file
  Future<void> shareFile(File file, String title) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: title,
      subject: 'BizSync Forecast Report',
    );
  }
}