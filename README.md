# BizSync - Offline-First Business Management Platform for Singapore SMEs

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Android%20|%20iOS%20|%20Web%20|%20Desktop-blue?style=for-the-badge)
![GST](https://img.shields.io/badge/GST-9%25%20Ready-success?style=for-the-badge)

<p align="center">
  <img src="assets/app_icon.png" width="200" alt="BizSync Logo">
</p>

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

#### 📦 **Inventory Management**
- Real-time stock tracking
- Low stock alerts
- Barcode scanning support
- Product categorization
- Stock movement history

#### 💳 **Singapore Payment Integration**
- PayNow QR code generation (Mobile, UEN, NRIC)
- SGQR support for multiple payment methods
- Payment status tracking
- Transaction history

#### 📊 **Tax Management**
- GST 9% automatic calculations
- GST F5/F7 report generation
- Tax period tracking
- IRAS compliance features
- Tax payment reminders

#### 👥 **Customer Relationship Management**
- Customer database with full details
- Communication history
- Credit limit management
- Customer analytics
- Bulk SMS/Email capabilities

#### 📈 **Analytics & Reporting**
- Real-time business dashboard
- Sales analytics
- Inventory reports
- Financial statements
- Customizable reports

### Technical Features

- **Offline Synchronization**: Conflict-free Replicated Data Types (CRDT) for seamless offline/online sync
- **Multi-User Support**: Role-based access control with admin, manager, and staff roles
- **Data Security**: SQLCipher encryption, biometric authentication, secure key storage
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

### 3. Configure Environment

Create a `.env` file in the project root:

```env
# Singapore-specific configurations
GST_RATE=0.09
CURRENCY=SGD
COUNTRY_CODE=SG

# API Keys (Optional for enhanced features)
GOOGLE_MAPS_API_KEY=your_api_key_here
FIREBASE_PROJECT_ID=your_project_id
```

### 4. Run the Application

```bash
# For development
flutter run

# For specific platform
flutter run -d android
flutter run -d ios
flutter run -d chrome
flutter run -d macos
flutter run -d linux
flutter run -d windows
```

## 🛠️ Development

### Project Structure

```
bizsync/
├── lib/
│   ├── core/           # Core functionality (database, utils, themes)
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

# Web
flutter build web --release

# Desktop
flutter build windows --release
flutter build macos --release
flutter build linux --release
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

1. **Presentation Layer** - Flutter UI with BLoC/Provider state management
2. **Domain Layer** - Business logic and use cases
3. **Data Layer** - Repository pattern with local and remote data sources
4. **Core Layer** - Shared utilities, themes, and configurations

### Technology Stack

- **Frontend**: Flutter, Material Design 3
- **State Management**: Provider, BLoC
- **Database**: SQLite with SQLCipher encryption
- **Offline Sync**: CRDT (Conflict-free Replicated Data Types)
- **Authentication**: Biometric, PIN, Pattern
- **Payment Integration**: PayNow API, SGQR standards
- **CI/CD**: GitHub Actions

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

## 📸 Screenshots

<p align="center">
  <img src="docs/screenshots/dashboard.png" width="250" alt="Dashboard">
  <img src="docs/screenshots/invoice.png" width="250" alt="Invoice">
  <img src="docs/screenshots/inventory.png" width="250" alt="Inventory">
</p>

## 🚦 Status

![Build Status](https://img.shields.io/github/actions/workflow/status/siva-sub/bizsync/flutter.yml?style=for-the-badge)
![Last Commit](https://img.shields.io/github/last-commit/siva-sub/bizsync?style=for-the-badge)
![Issues](https://img.shields.io/github/issues/siva-sub/bizsync?style=for-the-badge)
![Pull Requests](https://img.shields.io/github/issues-pr/siva-sub/bizsync?style=for-the-badge)

---

<p align="center">Made with ❤️ in Singapore 🇸🇬</p>