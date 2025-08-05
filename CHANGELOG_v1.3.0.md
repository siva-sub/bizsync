# BizSync v1.3.0 Release Notes

## 🎉 Major Features & Improvements

### 🔐 Enhanced Android Storage Permissions
- **Fixed Android storage permission issues** for all Android versions
- **Android 13+ Support**: Implemented granular media permissions (READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, READ_MEDIA_AUDIO)
- **Scoped Storage Compatibility**: Full support for Android 10+ scoped storage requirements
- **Permission Rationales**: Added clear business-focused explanations for each permission request
- **Privacy-First Approach**: Enhanced data extraction rules and backup configurations

### 📸 Profile Picture Upload
- **Complete Implementation**: Users can now upload profile pictures from camera or gallery
- **Cross-Platform Support**: Works seamlessly on both Android and Linux desktop
- **Image Optimization**: Automatic compression and resizing for optimal storage
- **Permission Handling**: Integrated with new permission system for smooth user experience

### 🔔 Notification System Fixes
- **Dynamic Badge Count**: Notification badge now shows actual unread count instead of hardcoded "3"
- **Grammar Fix**: Updated empty state message from "No notifications yet" to "No notifications"
- **Build Issues Resolved**: Updated flutter_local_notifications to v19.4.0, fixing compilation errors
- **Android 13+ Compatibility**: Proper notification permission handling for newer Android versions

### 🗄️ Database Schema Enhancements
- **Migration System**: Implemented database migration from v1 to v2
- **New Customer Fields**: Added is_active, gst_registered, uen, gst_registration_number, country_code, billing_address, shipping_address
- **Singapore GST Compliance**: Full support for GST calculations and UEN validation
- **Performance Indexes**: Added strategic indexes for improved query performance

### 🛡️ Null Safety & Error Prevention
- **Comprehensive Validation**: Fixed null safety violations in invoice creation
- **Input Sanitization**: Added validation for all form inputs
- **Error Recovery**: Improved error handling with user-friendly messages
- **Type Safety**: Enhanced type checking throughout the application

### 🐧 Linux AppImage Support
- **Complete AppImage Configuration**: Production-ready AppImage build system
- **Auto-Updates**: Zsync-based efficient update mechanism
- **Desktop Integration**: Automatic menu entries and file associations
- **Cross-Distribution**: Works on Ubuntu 20.04+, Debian 11+, Fedora 36+, and more
- **Security**: GPG signing and integrity verification

### 🧪 Testing & Quality Assurance
- **Comprehensive Test Suite**: Added unit, widget, and integration tests
- **Hypothesis-Driven Debugging**: New framework for error prediction and prevention
- **Performance Monitoring**: Built-in performance benchmarks and monitoring
- **Code Coverage**: Targeting >80% coverage for critical paths

## 🐛 Bug Fixes
- Fixed database schema mismatches causing customer creation failures
- Resolved "type 'Null' is not a subtype of type 'String'" errors in invoice creation
- Fixed empty Quick Actions section on dashboard
- Corrected notification permission requests for Android 13+
- Resolved flutter_local_notifications compilation errors
- Fixed various UI text truncation issues

## 🔧 Technical Improvements
- Updated Android compileSdk to 36 for latest compatibility
- Upgraded multiple dependencies for security and performance
- Improved CRDT synchronization reliability
- Enhanced error reporting and debugging capabilities
- Optimized database queries with new indexes

## 📱 Platform Support
- **Android**: 6.0 (API 23) and above
- **Linux**: Ubuntu 20.04+, Debian 11+, Fedora 36+, openSUSE 15.4+
- **Desktop**: Full Linux desktop support with AppImage distribution

## 🚀 Quick Start
### Android APK
```bash
flutter build apk --release
```

### Linux AppImage
```bash
./build-appimage.sh build
```

## 🙏 Acknowledgments
This release includes significant improvements to stability, security, and user experience. Special thanks to all contributors and testers who helped identify and resolve these issues.

---

**Full Changelog**: [v1.2.0...v1.3.0](https://github.com/siva-sub/bizsync/compare/v1.2.0...v1.3.0)