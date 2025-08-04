import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../navigation/app_router.dart';

class BreadcrumbWidget extends StatelessWidget {
  final List<BreadcrumbItem> breadcrumbs;

  const BreadcrumbWidget({
    super.key,
    required this.breadcrumbs,
  });

  @override
  Widget build(BuildContext context) {
    if (breadcrumbs.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        ...breadcrumbs.asMap().entries.map((entry) {
          final index = entry.key;
          final breadcrumb = entry.value;
          final isLast = index == breadcrumbs.length - 1;

          return Row(
            children: [
              if (index > 0) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 8),
              ],
              _BreadcrumbButton(
                breadcrumb: breadcrumb,
                isLast: isLast,
              ),
            ],
          );
        }).toList(),
      ],
    );
  }
}

class _BreadcrumbButton extends StatelessWidget {
  final BreadcrumbItem breadcrumb;
  final bool isLast;

  const _BreadcrumbButton({
    required this.breadcrumb,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    if (isLast) {
      // Current page - not clickable
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              breadcrumb.icon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              breadcrumb.label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Clickable breadcrumb
    return InkWell(
      onTap: () => context.go(breadcrumb.path),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              breadcrumb.icon,
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              breadcrumb.label,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BreadcrumbItem {
  final String label;
  final String path;
  final IconData icon;

  const BreadcrumbItem({
    required this.label,
    required this.path,
    required this.icon,
  });
}
