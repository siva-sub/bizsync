import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sync_models.dart' as sync;
import '../services/p2p_sync_service.dart';
import '../security/device_authentication.dart';
import 'pairing_dialog.dart';
import 'sync_settings_dialog.dart';

/// Device discovery screen for finding and connecting to nearby devices
class DeviceDiscoveryScreen extends ConsumerStatefulWidget {
  const DeviceDiscoveryScreen({super.key});

  @override
  ConsumerState<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends ConsumerState<DeviceDiscoveryScreen>
    with TickerProviderStateMixin {
  
  final P2PSyncService _syncService = P2PSyncService();
  
  late AnimationController _scanAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<double> _scanAnimation;
  late Animation<double> _fadeAnimation;
  
  final List<sync.DeviceInfo> _discoveredDevices = [];
  final List<sync.P2PConnection> _activeConnections = [];
  final List<PairedDevice> _pairedDevices = [];
  final Set<sync.TransportType> _selectedTransports = {sync.TransportType.bluetooth, sync.TransportType.mdns};
  
  bool _isScanning = false;
  bool _isAdvertising = false;
  String? _errorMessage;
  StreamSubscription<sync.DeviceInfo>? _discoverySubscription;
  StreamSubscription<sync.P2PConnection>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanAnimationController, curve: Curves.easeInOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeInOut),
    );
    
    _initializeService();
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _fadeAnimationController.dispose();
    _discoverySubscription?.cancel();
    _connectionSubscription?.cancel();
    _syncService.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    try {
      await _syncService.initialize();
      await _loadPairedDevices();
      
      // Set up listeners
      _discoverySubscription = _syncService.discoveredDevices.listen(_onDeviceDiscovered);
      _connectionSubscription = _syncService.connectionStateChanges.listen(_onConnectionStateChanged);
      
      setState(() {
        _errorMessage = null;
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize sync service: $e';
      });
    }
  }

  Future<void> _loadPairedDevices() async {
    try {
      final pairedDevices = await _syncService.getPairedDevices();
      setState(() {
        _pairedDevices.clear();
        _pairedDevices.addAll(pairedDevices);
      });
    } catch (e) {
      debugPrint('Error loading paired devices: $e');
    }
  }

  void _onDeviceDiscovered(sync.DeviceInfo device) {
    setState(() {
      // Remove existing device if present
      _discoveredDevices.removeWhere((d) => d.deviceId == device.deviceId);
      // Add updated device
      _discoveredDevices.add(device);
      // Sort by last seen (most recent first)
      _discoveredDevices.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    });
    
    _fadeAnimationController.forward().then((_) {
      _fadeAnimationController.reset();
    });
  }

  void _onConnectionStateChanged(sync.P2PConnection connection) {
    setState(() {
      if (connection.state == sync.ConnectionState.connected) {
        _activeConnections.removeWhere((c) => c.connectionId == connection.connectionId);
        _activeConnections.add(connection);
      } else if (connection.state == sync.ConnectionState.disconnected) {
        _activeConnections.removeWhere((c) => c.connectionId == connection.connectionId);
      }
    });
  }

  Future<void> _startDiscovery() async {
    if (_isScanning) return;
    
    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _discoveredDevices.clear();
    });
    
    _scanAnimationController.repeat();
    
    try {
      await _syncService.startDiscovery(
        transportTypes: _selectedTransports.toList(),
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start discovery: $e';
        _isScanning = false;
      });
      _scanAnimationController.stop();
    }
  }

  Future<void> _stopDiscovery() async {
    if (!_isScanning) return;
    
    setState(() {
      _isScanning = false;
    });
    
    _scanAnimationController.stop();
    _scanAnimationController.reset();
    
    try {
      await _syncService.stopDiscovery();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to stop discovery: $e';
      });
    }
  }

  Future<void> _toggleAdvertising() async {
    try {
      if (_isAdvertising) {
        await _syncService.stopAdvertising();
        setState(() {
          _isAdvertising = false;
        });
      } else {
        await _syncService.startAdvertising(
          transportTypes: _selectedTransports.toList(),
        );
        setState(() {
          _isAdvertising = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to toggle advertising: $e';
      });
    }
  }

  Future<void> _pairDevice(sync.DeviceInfo device) async {
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => PairingDialog(
          device: device,
          syncService: _syncService,
        ),
      );
      
      if (result == true) {
        await _loadPairedDevices();
        _showSnackBar('Successfully paired with ${device.deviceName}');
      }
    } catch (e) {
      _showSnackBar('Failed to pair device: $e');
    }
  }

  Future<void> _connectToDevice(sync.DeviceInfo device) async {
    try {
      await _syncService.connectToDevice(device);
      _showSnackBar('Connected to ${device.deviceName}');
    } catch (e) {
      _showSnackBar('Failed to connect: $e');
    }
  }

  Future<void> _disconnectFromDevice(String deviceId) async {
    try {
      await _syncService.disconnectFromDevice(deviceId);
      _showSnackBar('Disconnected from device');
    } catch (e) {
      _showSnackBar('Failed to disconnect: $e');
    }
  }

  Future<void> _startSync() async {
    if (_activeConnections.isEmpty) {
      _showSnackBar('No connected devices available for sync');
      return;
    }
    
    try {
      final configuration = await showDialog<sync.SyncConfiguration>(
        context: context,
        builder: (context) => const SyncSettingsDialog(),
      );
      
      if (configuration != null) {
        final deviceIds = _activeConnections
            .map((conn) => conn.remoteDevice.deviceId)
            .toList();
        
        final session = await _syncService.startSyncSession(deviceIds, configuration);
        
        if (mounted) {
          _showSnackBar('Started sync session with ${deviceIds.length} devices');
          Navigator.pop(context, session);
        }
      }
    } catch (e) {
      _showSnackBar('Failed to start sync: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Discovery'),
        actions: [
          IconButton(
            icon: Icon(_isAdvertising ? Icons.visibility : Icons.visibility_off),
            onPressed: _toggleAdvertising,
            tooltip: _isAdvertising ? 'Stop advertising' : 'Start advertising',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  _loadPairedDevices();
                  break;
                case 'settings':
                  _showTransportSettings();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh'),
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Transport Settings'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _isAdvertising ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                      color: _isAdvertising ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isAdvertising ? 'Device is visible to others' : 'Device is not advertising',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                if (_activeConnections.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.link, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        '${_activeConnections.length} active connections',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Error message
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.error,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          
          // Content
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Discovered', icon: Icon(Icons.search)),
                      Tab(text: 'Paired', icon: Icon(Icons.devices)),
                      Tab(text: 'Connected', icon: Icon(Icons.link)),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildDiscoveredDevicesTab(),
                        _buildPairedDevicesTab(),
                        _buildConnectedDevicesTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_activeConnections.isNotEmpty)
            FloatingActionButton.extended(
              onPressed: _startSync,
              icon: const Icon(Icons.sync),
              label: const Text('Start Sync'),
              heroTag: 'sync',
            ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _isScanning ? _stopDiscovery : _startDiscovery,
            heroTag: 'scan',
            child: AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _scanAnimation.value * 2 * 3.14159,
                  child: Icon(_isScanning ? Icons.stop : Icons.search),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveredDevicesTab() {
    if (_discoveredDevices.isEmpty && !_isScanning) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No devices discovered'),
            Text('Tap the search button to start discovery'),
          ],
        ),
      );
    }
    
    if (_discoveredDevices.isEmpty && _isScanning) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching for devices...'),
          ],
        ),
      );
    }
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _discoveredDevices.length,
        itemBuilder: (context, index) {
          final device = _discoveredDevices[index];
          final isPaired = _pairedDevices.any((p) => p.deviceId == device.deviceId);
          final isConnected = _activeConnections.any((c) => c.remoteDevice.deviceId == device.deviceId);
          
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(_getDeviceIcon(device.deviceType)),
              ),
              title: Text(device.deviceName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${device.platform} • ${device.deviceType}'),
                  Text(
                    'Transports: ${device.supportedTransports.join(", ")}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Last seen: ${_formatLastSeen(device.lastSeen)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPaired && !isConnected)
                    IconButton(
                      icon: const Icon(Icons.link),
                      onPressed: () => _connectToDevice(device),
                      tooltip: 'Connect',
                    ),
                  if (isConnected)
                    const Icon(Icons.check_circle, color: Colors.green),
                  if (!isPaired)
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _pairDevice(device),
                      tooltip: 'Pair',
                    ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPairedDevicesTab() {
    if (_pairedDevices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No paired devices'),
            Text('Discover and pair with nearby devices'),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pairedDevices.length,
      itemBuilder: (context, index) {
        final device = _pairedDevices[index];
        final isConnected = _activeConnections.any((c) => c.remoteDevice.deviceId == device.deviceId);
        
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.devices),
            ),
            title: Text(device.deviceName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Device ID: ${device.deviceId.substring(0, 8)}...'),
                Text('Paired: ${_formatDate(device.pairedAt)}'),
                Text('Method: ${device.pairingMethod.name}'),
              ],
            ),
            trailing: isConnected
                ? const Icon(Icons.check_circle, color: Colors.green)
                : IconButton(
                    icon: const Icon(Icons.link),
                    onPressed: () {
                      // Find device in discovered list or create one
                      final discoveredDevice = _discoveredDevices
                          .where((d) => d.deviceId == device.deviceId)
                          .firstOrNull;
                      
                      if (discoveredDevice != null) {
                        _connectToDevice(discoveredDevice);
                      } else {
                        _showSnackBar('Device not currently discoverable');
                      }
                    },
                    tooltip: 'Connect',
                  ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildConnectedDevicesTab() {
    if (_activeConnections.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No connected devices'),
            Text('Connect to paired devices to enable sync'),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeConnections.length,
      itemBuilder: (context, index) {
        final connection = _activeConnections[index];
        
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(_getDeviceIcon(connection.remoteDevice.deviceType)),
            ),
            title: Text(connection.remoteDevice.deviceName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Transport: ${connection.transport.name}'),
                Text('Connected: ${_formatDate(connection.connectedAt)}'),
                Text('State: ${connection.state.name}'),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _disconnectFromDevice(connection.remoteDevice.deviceId),
              tooltip: 'Disconnect',
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  void _showTransportSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transport Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: sync.TransportType.values.map((transport) {
            return CheckboxListTile(
              title: Text(transport.name),
              value: _selectedTransports.contains(transport),
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedTransports.add(transport);
                  } else {
                    _selectedTransports.remove(transport);
                  }
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'mobile':
        return Icons.phone_android;
      case 'desktop':
        return Icons.computer;
      case 'tablet':
        return Icons.tablet;
      default:
        return Icons.device_unknown;
    }
  }

  String _formatLastSeen(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}