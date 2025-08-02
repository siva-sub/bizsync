// P2P Sync Feature Export File
// This file provides a single entry point for all P2P sync functionality

// Core
export 'core/p2p_transport.dart';

// Communication Transports
export 'communication/bluetooth_transport.dart';
export 'communication/wifi_direct_transport.dart';
export 'communication/mdns_transport.dart';

// Security
export 'security/encryption_service.dart';
export 'security/device_authentication.dart';

// Sync Engine
export 'engine/crdt_sync_engine.dart';

// Services
export 'services/p2p_sync_service.dart';

// Models
export 'models/sync_models.dart';

// UI Components
export 'ui/device_discovery_screen.dart';
export 'ui/pairing_dialog.dart';
export 'ui/sync_settings_dialog.dart';
export 'ui/sync_progress_screen.dart';

/// P2P Sync Feature
/// 
/// This feature provides comprehensive peer-to-peer synchronization capabilities
/// for the BizSync application, including:
/// 
/// - Multiple transport types (Bluetooth, WiFi Direct, mDNS/LAN)
/// - End-to-end encryption using Signal Protocol concepts
/// - Device authentication and pairing with QR codes and PIN codes
/// - CRDT-based conflict-free data synchronization
/// - Differential sync to minimize data transfer
/// - Bandwidth management and data compression
/// - Multi-device support with vector clock synchronization
/// - Comprehensive UI for device discovery, pairing, and sync progress
/// 
/// ## Quick Start
/// 
/// ```dart
/// // Initialize the P2P sync service
/// final syncService = P2PSyncService();
/// await syncService.initialize();
/// 
/// // Start device discovery
/// await syncService.startDiscovery();
/// 
/// // Listen for discovered devices
/// syncService.discoveredDevices.listen((device) {
///   print('Found device: ${device.deviceName}');
/// });
/// 
/// // Pair with a device
/// final pairing = await syncService.initiatePairingWithQR(deviceId);
/// 
/// // Connect to paired device
/// await syncService.connectToDevice(device);
/// 
/// // Start sync session
/// final session = await syncService.startSyncSession(
///   [deviceId], 
///   SyncConfiguration(
///     syncInvoices: true,
///     syncCustomers: true,
///     encryptData: true,
///     compressData: true,
///   ),
/// );
/// ```
/// 
/// ## Architecture
/// 
/// The P2P sync system is built with a modular architecture:
/// 
/// 1. **Transport Layer**: Handles different communication methods
///    - Bluetooth Classic for short-range communication
///    - WiFi Direct for high-speed device-to-device transfer
///    - mDNS for local network discovery and connection
/// 
/// 2. **Security Layer**: Provides end-to-end encryption and authentication
///    - X25519 key exchange for session establishment
///    - AES-256-GCM for data encryption
///    - HMAC-SHA256 for message authentication
///    - Device pairing with QR codes and PIN codes
/// 
/// 3. **Sync Engine**: Implements CRDT-based conflict-free synchronization
///    - Hybrid Logical Clocks for causality tracking
///    - Vector Clocks for distributed consistency
///    - Automatic conflict resolution with last-writer-wins
/// 
/// 4. **Service Layer**: Coordinates all components and provides high-level API
///    - Device discovery and connection management
///    - Session orchestration and progress tracking
///    - Error handling and recovery
/// 
/// 5. **UI Layer**: Provides user interfaces for all sync operations
///    - Device discovery and pairing screens
///    - Sync configuration and progress monitoring
///    - Conflict resolution interfaces
/// 
/// ## Security
/// 
/// All communication is secured by default:
/// - Device pairing establishes shared secrets
/// - All data is encrypted end-to-end
/// - Message authentication prevents tampering
/// - Forward secrecy through session key rotation
/// 
/// ## Performance
/// 
/// The system is optimized for efficiency:
/// - Differential sync transfers only changed data
/// - Data compression reduces bandwidth usage
/// - Bandwidth limits prevent network congestion
/// - Background sync for non-blocking operation
/// 
/// ## Offline Operation
/// 
/// The P2P sync system is designed to work without internet:
/// - Local discovery using Bluetooth and mDNS
/// - Direct device-to-device communication
/// - Offline conflict resolution
/// - Queue-based sync for intermittent connections
/// 
class P2PSyncFeature {
  static const String version = '1.0.0';
  static const String description = 'Comprehensive P2P synchronization system';
  
  /// Supported transport types
  static const List<String> supportedTransports = [
    'bluetooth',
    'wifiDirect', 
    'mdns',
  ];
  
  /// Security features
  static const List<String> securityFeatures = [
    'end-to-end encryption',
    'device authentication',
    'message authentication',
    'forward secrecy',
  ];
  
  /// Sync capabilities
  static const List<String> syncCapabilities = [
    'CRDT-based merge',
    'conflict resolution',
    'differential sync',
    'vector clocks',
    'multi-device support',
  ];
}