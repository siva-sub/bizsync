// Forecasting Feature - Comprehensive Business Forecasting and Reporting System
//
// This feature provides advanced forecasting capabilities including:
// - Multiple forecasting algorithms (Linear Regression, Moving Averages, Exponential Smoothing, Seasonal Decomposition)
// - Real-time data integration from invoices, transactions, and business operations
// - Interactive dashboard with charts and visualizations
// - PDF and Excel export functionality
// - Accuracy metrics and model comparison
// - Revenue, Expense, Cash Flow, and Inventory forecasting

// Models
export 'models/forecasting_models.dart';

// Algorithms
export 'algorithms/linear_regression_model.dart';
export 'algorithms/moving_average_model.dart';
export 'algorithms/exponential_smoothing_model.dart';
export 'algorithms/seasonal_decomposition_model.dart';

// Services
export 'services/forecasting_service.dart';
export 'services/forecast_export_service.dart';

// Screens
export 'screens/forecasting_dashboard_screen.dart';
export 'screens/revenue_forecasting_screen.dart';

// Widgets
export 'widgets/forecast_session_card.dart';
export 'widgets/forecast_metric_card.dart';
export 'widgets/forecast_quick_actions.dart';
