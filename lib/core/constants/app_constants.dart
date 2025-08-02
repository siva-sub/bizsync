// App-wide constants for BizSync
class AppConstants {
  // App Info
  static const String appName = 'BizSync';
  static const String appVersion = '1.0.0';
  
  // Database
  static const String databaseName = 'bizsync.db';
  static const int databaseVersion = 1;
  
  // Encryption
  static const String encryptionKey = 'bizsync_secure_key_2024';
  
  // P2P Communication
  static const String serviceId = 'com.bizsync.p2p';
  static const int discoveryTimeoutMs = 30000;
  static const int connectionTimeoutMs = 10000;
  
  // Notifications
  static const String notificationChannelId = 'bizsync_notifications';
  static const String notificationChannelName = 'BizSync Notifications';
  
  // QR Code
  static const int qrCodeSize = 200;
  static const double qrCodeVersion = 4.0;
  
  // Business Logic
  static const int maxCustomers = 10000;
  static const int maxProducts = 50000;
  static const int maxTransactions = 100000;
  
  // UI
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
}