import 'package:flutter/material.dart';

import '../models/sgqr_models.dart';
import '../services/multi_payment_service.dart';

/// Payment Method Selection Widget
class PaymentMethodSelector extends StatefulWidget {
  final List<PaymentNetwork> availableNetworks;
  final List<PaymentNetwork> selectedNetworks;
  final PaymentNetwork? primaryNetwork;
  final Function(List<PaymentNetwork> selected) onSelectionChanged;
  final Function(PaymentNetwork primary)? onPrimaryChanged;
  final bool allowMultipleSelection;
  final bool showIcons;

  const PaymentMethodSelector({
    super.key,
    required this.availableNetworks,
    required this.selectedNetworks,
    required this.onSelectionChanged,
    this.primaryNetwork,
    this.onPrimaryChanged,
    this.allowMultipleSelection = true,
    this.showIcons = true,
  });

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  late List<PaymentNetwork> _selectedNetworks;
  PaymentNetwork? _primaryNetwork;

  @override
  void initState() {
    super.initState();
    _selectedNetworks = List.from(widget.selectedNetworks);
    _primaryNetwork = widget.primaryNetwork;
  }

  @override
  void didUpdateWidget(PaymentMethodSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedNetworks != widget.selectedNetworks) {
      _selectedNetworks = List.from(widget.selectedNetworks);
    }
    if (oldWidget.primaryNetwork != widget.primaryNetwork) {
      _primaryNetwork = widget.primaryNetwork;
    }
  }

  void _toggleNetwork(PaymentNetwork network) {
    setState(() {
      if (_selectedNetworks.contains(network)) {
        if (widget.allowMultipleSelection || _selectedNetworks.length > 1) {
          _selectedNetworks.remove(network);

          // If removing the primary network, set a new primary
          if (_primaryNetwork == network && _selectedNetworks.isNotEmpty) {
            _primaryNetwork = _selectedNetworks.first;
            widget.onPrimaryChanged?.call(_primaryNetwork!);
          }
        }
      } else {
        if (widget.allowMultipleSelection) {
          _selectedNetworks.add(network);
        } else {
          _selectedNetworks = [network];
        }

        // Set as primary if it's the first selection
        if (_primaryNetwork == null ||
            !_selectedNetworks.contains(_primaryNetwork)) {
          _primaryNetwork = network;
          widget.onPrimaryChanged?.call(_primaryNetwork!);
        }
      }

      widget.onSelectionChanged(_selectedNetworks);
    });
  }

  void _setPrimaryNetwork(PaymentNetwork network) {
    if (_selectedNetworks.contains(network)) {
      setState(() {
        _primaryNetwork = network;
        widget.onPrimaryChanged?.call(network);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Methods',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        ...widget.availableNetworks
            .map((network) => _buildNetworkTile(network)),
        if (_selectedNetworks.length > 1 && widget.allowMultipleSelection) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Primary Payment Method',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          ..._selectedNetworks
              .map((network) => _buildPrimaryNetworkTile(network)),
        ],
      ],
    );
  }

  Widget _buildNetworkTile(PaymentNetwork network) {
    final bool isSelected = _selectedNetworks.contains(network);
    final bool isPrimary = _primaryNetwork == network;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 2 : 1,
      child: ListTile(
        leading: widget.showIcons ? _getNetworkIcon(network) : null,
        title: Row(
          children: [
            Text(
              _getNetworkDisplayName(network),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isPrimary) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PRIMARY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(_getNetworkDescription(network)),
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).primaryColor,
              )
            : const Icon(Icons.circle_outlined),
        onTap: () => _toggleNetwork(network),
      ),
    );
  }

  Widget _buildPrimaryNetworkTile(PaymentNetwork network) {
    final bool isPrimary = _primaryNetwork == network;

    return ListTile(
      dense: true,
      leading: Radio<PaymentNetwork>(
        value: network,
        groupValue: _primaryNetwork,
        onChanged: (PaymentNetwork? value) {
          if (value != null) {
            _setPrimaryNetwork(value);
          }
        },
      ),
      title: Text(_getNetworkDisplayName(network)),
      onTap: () => _setPrimaryNetwork(network),
    );
  }

  Widget _getNetworkIcon(PaymentNetwork network) {
    IconData iconData;
    Color? iconColor;

    switch (network) {
      case PaymentNetwork.payNow:
        iconData = Icons.account_balance_wallet;
        iconColor = const Color(0xFF003366); // Singapore blue
        break;
      case PaymentNetwork.nets:
        iconData = Icons.credit_card;
        iconColor = const Color(0xFF2E8B57); // NETS green
        break;
      case PaymentNetwork.visa:
        iconData = Icons.payment;
        iconColor = const Color(0xFF1A1F71); // Visa blue
        break;
      case PaymentNetwork.mastercard:
        iconData = Icons.payment;
        iconColor = const Color(0xFFEB001B); // Mastercard red
        break;
      case PaymentNetwork.americanExpress:
        iconData = Icons.payment;
        iconColor = const Color(0xFF006FCF); // Amex blue
        break;
      case PaymentNetwork.discoverCard:
        iconData = Icons.payment;
        iconColor = const Color(0xFFFF6000); // Discover orange
        break;
      case PaymentNetwork.jcb:
        iconData = Icons.payment;
        iconColor = const Color(0xFF0E4C96); // JCB blue
        break;
      case PaymentNetwork.unionPay:
        iconData = Icons.payment;
        iconColor = const Color(0xFFE21836); // UnionPay red
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor?.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor),
    );
  }

  String _getNetworkDisplayName(PaymentNetwork network) {
    switch (network) {
      case PaymentNetwork.payNow:
        return 'PayNow';
      case PaymentNetwork.nets:
        return 'NETS';
      case PaymentNetwork.visa:
        return 'Visa';
      case PaymentNetwork.mastercard:
        return 'Mastercard';
      case PaymentNetwork.americanExpress:
        return 'American Express';
      case PaymentNetwork.discoverCard:
        return 'Discover';
      case PaymentNetwork.jcb:
        return 'JCB';
      case PaymentNetwork.unionPay:
        return 'UnionPay';
    }
  }

  String _getNetworkDescription(PaymentNetwork network) {
    switch (network) {
      case PaymentNetwork.payNow:
        return 'Singapore\'s national digital payment system';
      case PaymentNetwork.nets:
        return 'Singapore\'s local payment network';
      case PaymentNetwork.visa:
        return 'International credit and debit cards';
      case PaymentNetwork.mastercard:
        return 'International credit and debit cards';
      case PaymentNetwork.americanExpress:
        return 'Premium credit cards';
      case PaymentNetwork.discoverCard:
        return 'International credit cards';
      case PaymentNetwork.jcb:
        return 'Japan Credit Bureau cards';
      case PaymentNetwork.unionPay:
        return 'Chinese payment cards';
    }
  }
}

/// Compact Payment Method Chips
class PaymentMethodChips extends StatelessWidget {
  final List<PaymentNetwork> availableNetworks;
  final List<PaymentNetwork> selectedNetworks;
  final Function(List<PaymentNetwork> selected) onSelectionChanged;
  final bool allowMultipleSelection;

  const PaymentMethodChips({
    super.key,
    required this.availableNetworks,
    required this.selectedNetworks,
    required this.onSelectionChanged,
    this.allowMultipleSelection = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Methods',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableNetworks.map((network) {
            final bool isSelected = selectedNetworks.contains(network);

            return FilterChip(
              label: Text(_getNetworkDisplayName(network)),
              selected: isSelected,
              onSelected: (bool selected) {
                List<PaymentNetwork> newSelection = List.from(selectedNetworks);

                if (selected) {
                  if (allowMultipleSelection) {
                    newSelection.add(network);
                  } else {
                    newSelection = [network];
                  }
                } else {
                  if (allowMultipleSelection || newSelection.length > 1) {
                    newSelection.remove(network);
                  }
                }

                onSelectionChanged(newSelection);
              },
              avatar: _getNetworkIcon(network),
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _getNetworkIcon(PaymentNetwork network) {
    switch (network) {
      case PaymentNetwork.payNow:
        return const Icon(Icons.account_balance_wallet, size: 16);
      case PaymentNetwork.nets:
        return const Icon(Icons.credit_card, size: 16);
      default:
        return const Icon(Icons.payment, size: 16);
    }
  }

  String _getNetworkDisplayName(PaymentNetwork network) {
    switch (network) {
      case PaymentNetwork.payNow:
        return 'PayNow';
      case PaymentNetwork.nets:
        return 'NETS';
      case PaymentNetwork.visa:
        return 'Visa';
      case PaymentNetwork.mastercard:
        return 'Mastercard';
      case PaymentNetwork.americanExpress:
        return 'Amex';
      case PaymentNetwork.discoverCard:
        return 'Discover';
      case PaymentNetwork.jcb:
        return 'JCB';
      case PaymentNetwork.unionPay:
        return 'UnionPay';
    }
  }
}

/// Payment Method Configuration Widget
class PaymentMethodConfigWidget extends StatefulWidget {
  final MultiPaymentConfig initialConfig;
  final Function(MultiPaymentConfig config) onConfigChanged;

  const PaymentMethodConfigWidget({
    super.key,
    required this.initialConfig,
    required this.onConfigChanged,
  });

  @override
  State<PaymentMethodConfigWidget> createState() =>
      _PaymentMethodConfigWidgetState();
}

class _PaymentMethodConfigWidgetState extends State<PaymentMethodConfigWidget> {
  late List<PaymentNetwork> _selectedNetworks;
  late PaymentNetwork _primaryNetwork;

  static const List<PaymentNetwork> _allNetworks = [
    PaymentNetwork.payNow,
    PaymentNetwork.nets,
    PaymentNetwork.visa,
    PaymentNetwork.mastercard,
    PaymentNetwork.americanExpress,
    PaymentNetwork.discoverCard,
    PaymentNetwork.jcb,
    PaymentNetwork.unionPay,
  ];

  @override
  void initState() {
    super.initState();
    _selectedNetworks = List.from(widget.initialConfig.supportedNetworks);
    _primaryNetwork = widget.initialConfig.primaryNetwork;
  }

  void _updateConfig() {
    final MultiPaymentConfig newConfig = MultiPaymentConfig(
      supportedNetworks: _selectedNetworks,
      primaryNetwork: _primaryNetwork,
    );
    widget.onConfigChanged(newConfig);
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
              'Payment Configuration',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            PaymentMethodSelector(
              availableNetworks: _allNetworks,
              selectedNetworks: _selectedNetworks,
              primaryNetwork: _primaryNetwork,
              onSelectionChanged: (List<PaymentNetwork> selected) {
                setState(() {
                  _selectedNetworks = selected;
                  if (!selected.contains(_primaryNetwork) &&
                      selected.isNotEmpty) {
                    _primaryNetwork = selected.first;
                  }
                });
                _updateConfig();
              },
              onPrimaryChanged: (PaymentNetwork primary) {
                setState(() {
                  _primaryNetwork = primary;
                });
                _updateConfig();
              },
            ),

            const SizedBox(height: 16),

            // Quick presets
            Text(
              'Quick Presets',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedNetworks = [PaymentNetwork.payNow];
                      _primaryNetwork = PaymentNetwork.payNow;
                    });
                    _updateConfig();
                  },
                  icon: const Icon(Icons.account_balance_wallet, size: 16),
                  label: const Text('PayNow Only'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedNetworks = [
                        PaymentNetwork.payNow,
                        PaymentNetwork.nets,
                      ];
                      _primaryNetwork = PaymentNetwork.payNow;
                    });
                    _updateConfig();
                  },
                  icon: const Icon(Icons.credit_card, size: 16),
                  label: const Text('SG Standard'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedNetworks = List.from(_allNetworks);
                      _primaryNetwork = PaymentNetwork.payNow;
                    });
                    _updateConfig();
                  },
                  icon: const Icon(Icons.public, size: 16),
                  label: const Text('All Methods'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
