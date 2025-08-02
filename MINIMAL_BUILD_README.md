# BizSync Minimal Build Guide

This document explains how to build and run the minimal working version of BizSync.

## Quick Start

### 1. Build Minimal Version
```bash
# Using the dedicated minimal build script (recommended)
./build_minimal.sh

# Or using the main build script with minimal mode (default)
./build_linux.sh
```

### 2. Run BizSync
```bash
# Using the run script
./run_bizsync_minimal.sh

# Or directly
cd build/linux/x64/release/bundle
./bizsync
```

## Build Scripts

### Minimal Build Script (`build_minimal.sh`)
- **Purpose**: Simple, focused script that builds only the minimal version
- **Target**: Always uses `lib/minimal_main.dart`
- **Features**: Quick build, minimal dependencies, basic error checking

### Main Build Script (`build_linux.sh`)
- **Purpose**: Full-featured build script with advanced options
- **Modes**: 
  - `BUILD_MODE=minimal` (default) - Uses `lib/minimal_main.dart`
  - `BUILD_MODE=full` - Uses `lib/main.dart` (may have dependency issues)
- **Features**: Advanced validation, packaging, distribution archives

## What's in the Minimal Build

### ✅ Working Features
- **Basic Navigation**: Home screen with feature cards
- **Flutter Material Design**: Clean, responsive UI
- **Core Architecture**: Proper Flutter/Riverpod setup
- **Multiple Screens**: Splash, Home, Dashboard, Invoices, Payments, Settings
- **Theme Support**: Light/dark theme switching
- **Responsive Design**: Works on different screen sizes

### ❌ Disabled Features (Stubbed)
- **QR Code Scanning**: Replaced with stub implementation
- **Complex CRDT Database**: Uses basic local storage
- **Advanced Analytics**: Simplified data models
- **External Integrations**: PayNow, SGQR, etc. are stubbed
- **Employee Management**: Complex HR features disabled
- **Advanced Reporting**: PDF generation, complex charts disabled

## File Structure

```
lib/
├── minimal_main.dart          # Minimal app entry point ✅
├── main.dart                  # Full app entry point (has issues)
├── core/
│   ├── stubs/                 # Stub implementations for disabled features
│   │   ├── barcode_stub.dart     # QR/Barcode scanning stubs
│   │   └── custom_snackbar_stub.dart # Notification stubs
│   └── types/
│       └── invoice_types.dart    # Unified type definitions
└── presentation/
    ├── screens/               # Basic UI screens
    └── widgets/               # Reusable UI components
```

## Build Outputs

### Successful Build Creates
- `build/linux/x64/release/bundle/bizsync` - Executable
- `build/linux/x64/release/bundle/data/` - Flutter assets
- `build/linux/x64/release/bundle/lib/` - Shared libraries

### Distribution Package (from build_linux.sh)
- `dist/bizsync-linux-{version}-{timestamp}.tar.gz`
- Contains executable, launch script, and version info

## Troubleshooting

### Build Fails
1. **Check Flutter Installation**:
   ```bash
   flutter doctor
   flutter config --enable-linux-desktop
   ```

2. **Install Linux Dependencies**:
   ```bash
   sudo apt-get install libgtk-3-dev libblkid-dev liblzma-dev
   ```

3. **Clean and Retry**:
   ```bash
   flutter clean
   flutter pub get
   ./build_minimal.sh
   ```

### Runtime Issues
1. **Missing Libraries**: Install required system packages
2. **Permission Errors**: Ensure executable permissions (`chmod +x bizsync`)
3. **Display Issues**: Check X11/Wayland environment variables

## Development Notes

### Adding Features to Minimal Build
1. Only add features that don't require complex external dependencies
2. Use stub implementations for unavailable services
3. Keep the minimal_main.dart focused on basic functionality
4. Test frequently to ensure the build remains stable

### Upgrading to Full Build
1. Fix import issues in full codebase
2. Implement proper CRDT database integration
3. Add real implementations for stubbed services
4. Use `BUILD_MODE=full ./build_linux.sh` to test

## Status Summary

| Component | Status | Notes |
|-----------|--------|-------|
| ✅ Minimal Build | Working | Compiles and runs successfully |
| ✅ Basic UI | Working | All screens render correctly |
| ✅ Navigation | Working | GoRouter navigation functional |
| ✅ Themes | Working | Material 3 theming applied |
| ❌ Full Build | Broken | Many dependency/import issues |
| ❌ QR Scanning | Stubbed | Shows placeholder UI |
| ❌ Database | Stubbed | No persistent storage |
| ❌ External APIs | Stubbed | No real integrations |

The minimal build provides a solid foundation for the BizSync application with working UI and navigation, while complex features are safely stubbed out to ensure compilation success.