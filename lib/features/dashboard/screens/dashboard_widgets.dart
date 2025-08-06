import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../providers/dashboard_providers.dart';
import '../models/dashboard_models.dart';
import '../../../core/animations/animated_widgets.dart';
import '../../../core/animations/animation_constants.dart';
import '../../../core/animations/animation_utils.dart';
import '../../../core/widgets/mesa_safe_widgets.dart';
import '../../../core/utils/mesa_rendering_config.dart';

/// Additional widget methods for main dashboard screen
mixin DashboardWidgetsMixin {
  Widget buildQuickActions(BuildContext context) {
    return AnimationUtils.slideAndFade(
      child: AnimatedCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              AnimationLimiter(
                child: Row(
                  children: AnimationConfiguration.toStaggeredList(
                    duration: AnimationConstants.fast,
                    delay: AnimationConstants.listItemStagger,
                    childAnimationBuilder: (widget) => SlideAnimation(
                      horizontalOffset: 30.0,
                      child: FadeInAnimation(child: widget),
                    ),
                    children: [
                      Expanded(
                        child: AnimatedQuickActionButton(
                          icon: Icons.add_circle_outline,
                          label: 'New Invoice',
                          color: Colors.blue,
                          onPressed: () => context.go('/invoices/create'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedQuickActionButton(
                          icon: Icons.warning_amber_outlined,
                          label: 'Overdue',
                          color: Colors.orange,
                          onPressed: () =>
                              context.go('/invoices?filter=overdue'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedQuickActionButton(
                          icon: Icons.people_outline,
                          label: 'Customers',
                          color: Colors.green,
                          onPressed: () => context.go('/customers'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedQuickActionButton(
                          icon: Icons.assessment_outlined,
                          label: 'Reports',
                          color: Colors.purple,
                          onPressed: () => context.go('/reports'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildKPISection(
      BuildContext context, List<KPI> kpis, ThemeData theme) {
    return AnimationUtils.slideAndFade(
      begin: const Offset(0, 20),
      duration: AnimationConstants.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Metrics',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          AnimationLimiter(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: kpis.length,
              itemBuilder: (context, index) =>
                  AnimationConfiguration.staggeredGrid(
                position: index,
                duration: AnimationConstants.fast,
                delay: AnimationConstants.listItemStagger,
                columnCount: 3,
                child: ScaleAnimation(
                  child: FadeInAnimation(
                    child: buildKPICard(context, kpis[index], theme),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildKPICard(BuildContext context, KPI kpi, ThemeData theme) {
    final isPositive = kpi.trend == TrendDirection.up;
    final isNegative = kpi.trend == TrendDirection.down;

    return GestureDetector(
      onTap: () => _navigateToKPIDetail(context, kpi),
      child: AnimatedCard(
        elevation: 2.0,
        hoverElevation: 6.0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      kpi.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimationUtils.scaleIn(
                    child: Icon(
                      getKPIIcon(kpi.iconName),
                      size: 20,
                      color: getKPIColor(kpi.color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildAnimatedKPIValue(kpi, theme),
              if (kpi.percentageChange != 0) ...[
                const SizedBox(height: 4),
                AnimationUtils.slideAndFade(
                  begin: const Offset(0, 10),
                  delay: const Duration(milliseconds: 500),
                  child: Row(
                    children: [
                      Icon(
                        isPositive
                            ? Icons.trending_up
                            : isNegative
                                ? Icons.trending_down
                                : Icons.trending_flat,
                        size: 16,
                        color: isPositive
                            ? Colors.green
                            : isNegative
                                ? Colors.red
                                : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${kpi.percentageChange.abs().toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isPositive
                              ? Colors.green
                              : isNegative
                                  ? Colors.red
                                  : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToKPIDetail(BuildContext context, KPI kpi) {
    // Navigate based on KPI type
    switch (kpi.type) {
      case KPIType.revenue:
        context.go('/reports/sales');
        break;
      case KPIType.cashFlow:
        context.go('/reports/financial');
        break;
      case KPIType.customers:
        context.go('/customers');
        break;
      case KPIType.inventory:
        context.go('/inventory');
        break;
      case KPIType.taxCompliance:
        context.go('/tax/calculator');
        break;
      default:
        context.go('/reports');
    }
  }

  Widget _buildAnimatedKPIValue(KPI kpi, ThemeData theme) {
    // Extract numeric value from formatted string for animation
    final numericValue = _extractNumericValue(kpi.formattedValue);

    if (numericValue != null) {
      final prefix =
          kpi.formattedValue.replaceAll(RegExp(r'[\d,.]'), '').trim();
      return AnimatedNumberCounter(
        value: numericValue,
        duration: AnimationConstants.numberCounter,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
        prefix: prefix.isEmpty ? '' : '$prefix ',
      );
    } else {
      // Fallback for non-numeric values
      return AnimationUtils.slideAndFade(
        begin: const Offset(0, 10),
        delay: const Duration(milliseconds: 200),
        child: Text(
          kpi.formattedValue,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
  }

  int? _extractNumericValue(String formattedValue) {
    final match = RegExp(r'[\d,]+').firstMatch(formattedValue);
    if (match != null) {
      final numericString = match.group(0)?.replaceAll(',', '');
      return int.tryParse(numericString ?? '');
    }
    return null;
  }

  // Continue with simplified charts that work...
  Widget buildRevenueChart(
      BuildContext context, RevenueAnalytics analytics, ThemeData theme) {
    return MesaSafeCard(
      child: InkWell(
        onTap: () => context.go('/reports/sales'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Revenue Trend',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                NumberFormat.currency(symbol: '\$')
                    .format(analytics.totalRevenue),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCashFlowChart(
      BuildContext context, CashFlowData cashFlow, ThemeData theme) {
    return MesaSafeCard(
      child: InkWell(
        onTap: () => context.go('/reports/financial'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cash Flow',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                NumberFormat.currency(symbol: '\$')
                    .format(cashFlow.netCashFlow),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: cashFlow.netCashFlow >= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildInvoiceStatusChart(
      BuildContext context, DashboardData data, ThemeData theme) {
    return MesaSafeCard(
      child: InkWell(
        onTap: () => context.go('/invoices'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Invoice Status',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              Text('Click to view invoices'),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCustomerGrowthChart(
      BuildContext context, CustomerInsights insights, ThemeData theme) {
    return MesaSafeCard(
      child: InkWell(
        onTap: () => context.go('/customers'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Customer Growth',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${insights.totalCustomers} Total',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildActivityFeed(ThemeData theme) {
    return MesaSafeCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text('No recent activity'),
          ],
        ),
      ),
    );
  }

  Widget buildTopCustomers(
      BuildContext context, RevenueAnalytics analytics, ThemeData theme) {
    return MesaSafeCard(
      child: InkWell(
        onTap: () => context.go('/customers'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Top Customers by Revenue',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              Text('Click to view customers'),
            ],
          ),
        ),
      ),
    );
  }

  IconData getKPIIcon(String? iconName) {
    switch (iconName) {
      case 'trending_up':
        return Icons.trending_up;
      case 'account_balance':
        return Icons.account_balance;
      case 'people':
        return Icons.people;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'receipt':
        return Icons.receipt;
      case 'warning':
        return Icons.warning;
      default:
        return Icons.analytics;
    }
  }

  Color getKPIColor(String? colorStr) {
    if (colorStr == null) return Colors.blue;
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }
}

// Keep the existing QuickActionButton classes...
class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated version of QuickActionButton with hover and press effects
class AnimatedQuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const AnimatedQuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  State<AnimatedQuickActionButton> createState() =>
      _AnimatedQuickActionButtonState();
}

class _AnimatedQuickActionButtonState extends State<AnimatedQuickActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onPressed();
        },
        onTapCancel: () => _controller.reverse(),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: AnimationConstants.cardHover,
                curve: AnimationConstants.cardCurve,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isHovered
                        ? widget.color.withValues(alpha: 0.6)
                        : widget.color.withValues(alpha: 0.3),
                  ),
                  color: _isHovered
                      ? widget.color.withValues(alpha: 0.05)
                      : Colors.transparent,
                  boxShadow: _isHovered
                      ? createMesaSafeBoxShadow(
                          color: widget.color.withValues(alpha: 0.2),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                        )
                      : null,
                ),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: AnimationConstants.cardHover,
                      child: Icon(
                        widget.icon,
                        color: widget.color,
                        size: _isHovered ? 26 : 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: widget.color,
                            fontWeight:
                                _isHovered ? FontWeight.w600 : FontWeight.w500,
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
