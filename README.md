# BizSync - Offline-First Business Management Platform for Singapore SMEs

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Android%20|%20iOS%20|%20Web%20|%20Desktop-blue?style=for-the-badge)
![GST](https://img.shields.io/badge/GST-9%25%20Ready-success?style=for-the-badge)

## 🚀 Overview

BizSync is a comprehensive, offline-first business management solution designed specifically for Singapore's Small and Medium Enterprises (SMEs). Built with Flutter, it provides a modern, intuitive interface for managing invoices, inventory, payments, and more - all while working seamlessly offline.

### ✨ Key Features

- **📱 Offline-First Architecture** - Full functionality without internet connection using CRDT synchronization
- **💼 Singapore-Specific Features** - GST 9% calculations, PayNow QR integration, SGQR support
- **📊 Comprehensive Business Tools** - Invoicing, inventory, CRM, tax management, and analytics
- **🔒 Bank-Grade Security** - End-to-end encryption, biometric authentication, secure data storage
- **🌐 Multi-Platform** - Single codebase for Android, iOS, Web, and Desktop
- **🎨 Modern UI/UX** - Material Design 3 with adaptive themes and Mesa-safe rendering

## 📋 Table of Contents

- [Features](#-features)
- [Getting Started](#-getting-started)
- [Installation](#-installation)
- [Development](#-development)
- [Architecture](#-architecture)
- [Contributing](#-contributing)
- [License](#-license)
- [Contact](#-contact)

## 🎯 Features

### Core Business Modules

#### 💰 **Invoicing & Billing**
- Create professional invoices with GST calculations
- Multiple invoice templates
- Automated invoice numbering
- PDF generation and sharing
- Payment tracking and reminders
- Export to Excel/CSV formats

#### 📦 **Inventory Management**
- Real-time stock tracking
- Low stock alerts
- Barcode scanning support
- Product categorization
- Stock movement history
- Batch operations

#### 💳 **Singapore Payment Integration**
- PayNow QR code generation (Mobile, UEN, NRIC)
- SGQR support for multiple payment methods
- Payment status tracking
- Transaction history
- Automated reconciliation

#### 📊 **Tax Management**
- GST 9% automatic calculations
- GST F5/F7 report generation
- Tax period tracking
- IRAS compliance features
- Tax payment reminders
- Multi-currency support

#### 👥 **Customer Relationship Management**
- Customer database with full details
- Communication history
- Credit limit management
- Customer analytics & segmentation
- Bulk SMS/Email capabilities
- Behavioral insights

#### 📈 **Analytics & Reporting**
- Real-time business dashboard
- Sales analytics with forecasting
- Inventory reports
- Financial statements
- Customizable reports
- Interactive data visualization

### 📱 Mobile-Specific Features (NEW)

#### 🔐 **Biometric Authentication**
- Fingerprint and Face ID support
- Secure access to sensitive data
- Configurable security levels
- Session timeout management

#### 🌙 **Dark Mode**
- System-aware theme switching
- Custom color schemes
- OLED-optimized dark theme
- Persistent preferences

#### 📴 **Enhanced Offline Mode**
- Real-time connectivity monitoring
- Automatic sync queue management
- Conflict resolution UI
- Offline operation indicators

#### 👆 **Advanced Gestures**
- Swipe to delete/archive
- Pull-to-refresh everywhere
- Tab swipe navigation
- Customizable swipe actions

#### 🔔 **Smart Notifications**
- Payment reminders
- Invoice due alerts
- Low inventory warnings
- Quiet hours support
- Priority filtering

#### ⚡ **Performance Optimizations**
- 60fps smooth animations
- Lazy loading lists
- Image caching
- Memory optimization

### 🖥️ Linux Desktop Features (NEW)

#### 🔧 **System Integration**
- System tray with quick actions
- Minimize to tray
- Native notifications
- Desktop widgets

#### ⌨️ **Productivity Shortcuts**
- Global keyboard shortcuts (Ctrl+N, Ctrl+F, etc.)
- Quick navigation (Ctrl+Tab)
- Window management shortcuts
- Custom shortcut configuration

#### 🪟 **Multi-Window Support**
- Open invoices in separate windows
- Detachable panels
- Window position memory
- Cascade/tile arrangements

#### 📄 **File System Integration**
- Drag & drop imports
- Watch folders for auto-import
- Native file dialogs
- Recent files menu

#### 🖨️ **Professional Printing**
- Direct invoice printing
- Print preview
- Custom print layouts
- Batch printing

#### 💻 **Command Line Interface**
```bash
# Create invoice from CLI
bizsync invoice --action create --customer "John Doe" --amount 1000

# Export data
bizsync export --type customers --format csv

# Batch operations
bizsync batch --file operations.json
```

#### 🔍 **Advanced Search**
- Global search across all modules
- Advanced filters
- Search history
- Saved searches
- Real-time suggestions

### Technical Features

- **Offline Synchronization**: Conflict-free Replicated Data Types (CRDT) for seamless offline/online sync
- **Multi-User Support**: Role-based access control with admin, manager, and staff roles
- **Data Security**: SQLite encryption, biometric authentication, secure key storage
- **Backup & Restore**: Automated cloud backups, local backup options
- **Performance Optimized**: Lazy loading, efficient caching, optimized for low-end devices
- **Internationalization**: Support for English, Chinese, Malay, and Tamil

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.x or higher
- Dart SDK 3.x or higher
- Android Studio / Xcode (for mobile development)
- Git

### System Requirements

- **Development**: 8GB RAM minimum, 16GB recommended
- **Storage**: 10GB free space for development environment
- **OS**: Windows 10+, macOS 10.14+, Ubuntu 20.04+

## 📥 Installation

### 1. Clone the Repository

```bash
git clone https://github.com/siva-sub/bizsync.git
cd bizsync
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Generate Code

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Run the Application

```bash
# For development
flutter run

# For specific platform
flutter run -d android
flutter run -d ios
flutter run -d chrome
flutter run -d linux
flutter run -d windows
```

## 🛠️ Development

### Project Structure

```
bizsync/
├── lib/
│   ├── core/           # Core functionality (database, utils, themes)
│   │   ├── desktop/    # Linux desktop-specific features
│   │   ├── mobile/     # Mobile-specific features
│   │   ├── offline/    # Offline sync functionality
│   │   └── security/   # Security & authentication
│   ├── features/       # Feature modules (invoices, inventory, etc.)
│   ├── shared/         # Shared widgets and components
│   └── main.dart       # Application entry point
├── assets/             # Images, fonts, and static files
├── test/              # Unit and widget tests
├── integration_test/   # Integration tests
└── docs/              # Documentation
```

### Building for Production

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Linux
flutter build linux --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release
```

### Running Tests

```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test

# Test coverage
flutter test --coverage
```

## 🏗️ Architecture

BizSync follows Clean Architecture principles with the following layers:

1. **Presentation Layer** - Flutter UI with Riverpod state management
2. **Domain Layer** - Business logic and use cases
3. **Data Layer** - Repository pattern with local and remote data sources
4. **Core Layer** - Shared utilities, themes, and configurations

### Technology Stack

- **Frontend**: Flutter, Material Design 3
- **State Management**: Riverpod
- **Database**: SQLite with encryption
- **Offline Sync**: CRDT (Conflict-free Replicated Data Types)
- **Authentication**: Biometric, PIN, Pattern
- **Payment Integration**: PayNow API, SGQR standards
- **Desktop**: System tray, native notifications, file system integration
- **Mobile**: Push notifications, haptic feedback, quick actions

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Sivasubramanian Ramanthan**

- 🌐 Website: [sivasub.com](https://sivasub.com)
- 📧 Email: [hello@sivasub.com](mailto:hello@sivasub.com)
- 💼 LinkedIn: [sivasub987](https://linkedin.com/in/sivasub987)
- 🐙 GitHub: [@siva-sub](https://github.com/siva-sub)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Singapore government for PayNow and SGQR standards documentation
- Open source community for various packages used
- Beta testers and early adopters

## 🚦 Project Status

**Current Version**: 1.0.0  
**Status**: Production Ready  
**Last Updated**: December 2024

### Recent Updates
- ✅ Added comprehensive mobile features (biometric auth, dark mode, gestures)
- ✅ Implemented Linux desktop features (system tray, CLI, multi-window)
- ✅ Enhanced offline synchronization
- ✅ Improved performance and user experience
- ✅ Added advanced analytics and reporting

---

<p align="center">Made with ❤️ in Singapore 🇸🇬</p>