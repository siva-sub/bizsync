import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/sgqr_models.dart';

/// Amount Input Widget with currency support and validation
class AmountInputWidget extends StatefulWidget {
  final double? initialAmount;
  final CurrencyCode currency;
  final Function(double? amount) onAmountChanged;
  final double? minimumAmount;
  final double? maximumAmount;
  final bool allowZero;
  final bool enableDynamicMode;
  final String? label;
  final String? helpText;

  const AmountInputWidget({
    super.key,
    this.initialAmount,
    this.currency = CurrencyCode.sgd,
    required this.onAmountChanged,
    this.minimumAmount,
    this.maximumAmount,
    this.allowZero = false,
    this.enableDynamicMode = true,
    this.label,
    this.helpText,
  });

  @override
  State<AmountInputWidget> createState() => _AmountInputWidgetState();
}

class _AmountInputWidgetState extends State<AmountInputWidget> {
  late TextEditingController _controller;
  late NumberFormat _currencyFormatter;
  bool _isDynamic = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _currencyFormatter = _getCurrencyFormatter(widget.currency);

    if (widget.initialAmount != null) {
      _controller.text = widget.initialAmount!.toStringAsFixed(2);
    }

    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(AmountInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currency != widget.currency) {
      _currencyFormatter = _getCurrencyFormatter(widget.currency);
    }

    if (oldWidget.initialAmount != widget.initialAmount) {
      if (widget.initialAmount != null) {
        _controller.text = widget.initialAmount!.toStringAsFixed(2);
      } else {
        _controller.clear();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  NumberFormat _getCurrencyFormatter(CurrencyCode currency) {
    switch (currency) {
      case CurrencyCode.sgd:
        return NumberFormat.currency(locale: 'en_SG', symbol: 'S\$');
      case CurrencyCode.usd:
        return NumberFormat.currency(locale: 'en_US', symbol: '\$');
      case CurrencyCode.eur:
        return NumberFormat.currency(locale: 'en_EU', symbol: '€');
      case CurrencyCode.jpy:
        return NumberFormat.currency(
            locale: 'ja_JP', symbol: '¥', decimalDigits: 0);
      case CurrencyCode.gbp:
        return NumberFormat.currency(locale: 'en_GB', symbol: '£');
      case CurrencyCode.aud:
        return NumberFormat.currency(locale: 'en_AU', symbol: 'A\$');
      case CurrencyCode.cad:
        return NumberFormat.currency(locale: 'en_CA', symbol: 'C\$');
      case CurrencyCode.hkd:
        return NumberFormat.currency(locale: 'en_HK', symbol: 'HK\$');
      case CurrencyCode.myr:
        return NumberFormat.currency(locale: 'ms_MY', symbol: 'RM');
      case CurrencyCode.thb:
        return NumberFormat.currency(locale: 'th_TH', symbol: '฿');
      case CurrencyCode.cny:
        return NumberFormat.currency(locale: 'zh_CN', symbol: '¥');
      case CurrencyCode.inr:
        return NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    }
  }

  void _onTextChanged() {
    final String text = _controller.text;
    final double? amount = double.tryParse(text);

    setState(() {
      _errorText = _validateAmount(amount);
    });

    widget.onAmountChanged(_errorText == null ? amount : null);
  }

  String? _validateAmount(double? amount) {
    if (!_isDynamic) {
      return null; // No validation for static QR
    }

    if (amount == null) {
      if (_controller.text.isNotEmpty) {
        return 'Invalid amount format';
      }
      return null; // Empty is allowed for static QR
    }

    if (amount < 0) {
      return 'Amount cannot be negative';
    }

    if (!widget.allowZero && amount == 0) {
      return 'Amount must be greater than zero';
    }

    if (widget.minimumAmount != null && amount < widget.minimumAmount!) {
      return 'Amount must be at least ${_currencyFormatter.format(widget.minimumAmount!)}';
    }

    if (widget.maximumAmount != null && amount > widget.maximumAmount!) {
      return 'Amount cannot exceed ${_currencyFormatter.format(widget.maximumAmount!)}';
    }

    // Check for reasonable decimal places
    final String amountStr = amount.toString();
    if (amountStr.contains('.')) {
      final int decimalPlaces = amountStr.split('.')[1].length;
      if (decimalPlaces > 2) {
        return 'Amount can have at most 2 decimal places';
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dynamic/Static toggle
        if (widget.enableDynamicMode) ...[
          Row(
            children: [
              Text(
                'QR Type:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Static'),
                      icon: Icon(Icons.qr_code, size: 16),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Dynamic'),
                      icon: Icon(Icons.qr_code_2, size: 16),
                    ),
                  ],
                  selected: {_isDynamic},
                  onSelectionChanged: (Set<bool> selection) {
                    setState(() {
                      _isDynamic = selection.first;
                      if (!_isDynamic) {
                        _controller.clear();
                        widget.onAmountChanged(null);
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Amount input
        TextField(
          controller: _controller,
          enabled: _isDynamic,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            labelText: widget.label ?? 'Amount',
            helperText: widget.helpText ??
                (_isDynamic
                    ? 'Enter amount for fixed payment'
                    : 'Leave empty for customer to enter amount'),
            errorText: _errorText,
            prefixText: _getCurrencySymbol(widget.currency),
            suffixIcon: _isDynamic && _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      widget.onAmountChanged(null);
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 8),

        // Quick amount buttons for SGD
        if (_isDynamic && widget.currency == CurrencyCode.sgd) ...[
          const SizedBox(height: 8),
          Text(
            'Quick Amounts:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [10, 20, 50, 100, 200, 500].map((amount) {
              return ActionChip(
                label: Text('S\$${amount}'),
                onPressed: () {
                  _controller.text = amount.toStringAsFixed(2);
                  _onTextChanged();
                },
              );
            }).toList(),
          ),
        ],

        // Amount validation info
        if (_isDynamic) ...[
          const SizedBox(height: 8),
          _buildValidationInfo(),
        ],
      ],
    );
  }

  Widget _buildValidationInfo() {
    final List<String> info = [];

    if (widget.minimumAmount != null) {
      info.add('Min: ${_currencyFormatter.format(widget.minimumAmount!)}');
    }

    if (widget.maximumAmount != null) {
      info.add('Max: ${_currencyFormatter.format(widget.maximumAmount!)}');
    }

    if (info.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            info.join(' • '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  String _getCurrencySymbol(CurrencyCode currency) {
    switch (currency) {
      case CurrencyCode.sgd:
        return 'S\$ ';
      case CurrencyCode.usd:
        return '\$ ';
      case CurrencyCode.eur:
        return '€ ';
      case CurrencyCode.jpy:
        return '¥ ';
      case CurrencyCode.gbp:
        return '£ ';
      case CurrencyCode.aud:
        return 'A\$ ';
      case CurrencyCode.cad:
        return 'C\$ ';
      case CurrencyCode.hkd:
        return 'HK\$ ';
      case CurrencyCode.myr:
        return 'RM ';
      case CurrencyCode.thb:
        return '฿ ';
      case CurrencyCode.cny:
        return '¥ ';
      case CurrencyCode.inr:
        return '₹ ';
    }
  }
}

/// Currency Selector Widget
class CurrencySelectorWidget extends StatelessWidget {
  final CurrencyCode selectedCurrency;
  final Function(CurrencyCode currency) onCurrencyChanged;
  final List<CurrencyCode>? availableCurrencies;

  const CurrencySelectorWidget({
    super.key,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
    this.availableCurrencies,
  });

  static const List<CurrencyCode> _defaultCurrencies = [
    CurrencyCode.sgd,
    CurrencyCode.usd,
    CurrencyCode.eur,
    CurrencyCode.gbp,
    CurrencyCode.jpy,
    CurrencyCode.aud,
    CurrencyCode.cad,
    CurrencyCode.hkd,
    CurrencyCode.myr,
  ];

  @override
  Widget build(BuildContext context) {
    final List<CurrencyCode> currencies =
        availableCurrencies ?? _defaultCurrencies;

    return DropdownButtonFormField<CurrencyCode>(
      value: selectedCurrency,
      decoration: const InputDecoration(
        labelText: 'Currency',
        border: OutlineInputBorder(),
      ),
      items: currencies.map((currency) {
        return DropdownMenuItem<CurrencyCode>(
          value: currency,
          child: Row(
            children: [
              Text(_getCurrencyFlag(currency)),
              const SizedBox(width: 8),
              Text(_getCurrencyName(currency)),
              const Spacer(),
              Text(
                _getCurrencyCode(currency),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (CurrencyCode? currency) {
        if (currency != null) {
          onCurrencyChanged(currency);
        }
      },
    );
  }

  String _getCurrencyFlag(CurrencyCode currency) {
    switch (currency) {
      case CurrencyCode.sgd:
        return '🇸🇬';
      case CurrencyCode.usd:
        return '🇺🇸';
      case CurrencyCode.eur:
        return '🇪🇺';
      case CurrencyCode.jpy:
        return '🇯🇵';
      case CurrencyCode.gbp:
        return '🇬🇧';
      case CurrencyCode.aud:
        return '🇦🇺';
      case CurrencyCode.cad:
        return '🇨🇦';
      case CurrencyCode.hkd:
        return '🇭🇰';
      case CurrencyCode.myr:
        return '🇲🇾';
      case CurrencyCode.thb:
        return '🇹🇭';
      case CurrencyCode.cny:
        return '🇨🇳';
      case CurrencyCode.inr:
        return '🇮🇳';
    }
  }

  String _getCurrencyName(CurrencyCode currency) {
    switch (currency) {
      case CurrencyCode.sgd:
        return 'Singapore Dollar';
      case CurrencyCode.usd:
        return 'US Dollar';
      case CurrencyCode.eur:
        return 'Euro';
      case CurrencyCode.jpy:
        return 'Japanese Yen';
      case CurrencyCode.gbp:
        return 'British Pound';
      case CurrencyCode.aud:
        return 'Australian Dollar';
      case CurrencyCode.cad:
        return 'Canadian Dollar';
      case CurrencyCode.hkd:
        return 'Hong Kong Dollar';
      case CurrencyCode.myr:
        return 'Malaysian Ringgit';
      case CurrencyCode.thb:
        return 'Thai Baht';
      case CurrencyCode.cny:
        return 'Chinese Yuan';
      case CurrencyCode.inr:
        return 'Indian Rupee';
    }
  }

  String _getCurrencyCode(CurrencyCode currency) {
    switch (currency) {
      case CurrencyCode.sgd:
        return 'SGD';
      case CurrencyCode.usd:
        return 'USD';
      case CurrencyCode.eur:
        return 'EUR';
      case CurrencyCode.jpy:
        return 'JPY';
      case CurrencyCode.gbp:
        return 'GBP';
      case CurrencyCode.aud:
        return 'AUD';
      case CurrencyCode.cad:
        return 'CAD';
      case CurrencyCode.hkd:
        return 'HKD';
      case CurrencyCode.myr:
        return 'MYR';
      case CurrencyCode.thb:
        return 'THB';
      case CurrencyCode.cny:
        return 'CNY';
      case CurrencyCode.inr:
        return 'INR';
    }
  }
}
