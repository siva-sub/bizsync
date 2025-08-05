# BizSync AppImage Configuration

This directory contains the complete AppImage build configuration for BizSync, enabling easy distribution of the application as a self-contained portable executable for Linux systems.

## 📁 Directory Structure

```
appimage/
├── AppDir/                     # AppImage application directory
│   ├── AppRun                  # Main entry point script
│   ├── bizsync.desktop         # Desktop entry file
│   ├── bizsync.png            # Application icon
│   └── usr/                   # Application files
│       ├── bin/               # Executable binaries
│       ├── lib/               # Shared libraries
│       └── share/            # Data files, icons, metadata
│           ├── applications/  # Desktop entries
│           ├── icons/        # Multi-size icons
│           └── metainfo/     # AppStream metadata
├── build/                     # Build artifacts
├── scripts/                   # Build and management scripts
│   ├── build-appimage.sh     # Main build script
│   ├── bundle-dependencies.sh # Dependency bundling
│   ├── version-manager.sh    # Version management
│   ├── update-manager.sh     # Auto-update functionality
│   └── signing-manager.sh    # Digital signing
├── ci/                       # CI/CD scripts
├── docs/                     # Documentation
└── README.md                 # This file
```

## 🚀 Quick Start

### Prerequisites

Install required dependencies:

```bash
# Ubuntu/Debian
sudo apt-get install -y \
    build-essential cmake ninja-build pkg-config \
    libgtk-3-dev libblkid-dev liblzma-dev \
    fuse imagemagick zsync wget

# Flutter
flutter pub get
```

### Build AppImage

```bash
# Build complete AppImage
./appimage/scripts/build-appimage.sh

# Build with specific options
./appimage/scripts/build-appimage.sh --clean    # Clean build
./appimage/scripts/build-appimage.sh --deps-only # Check dependencies only
```

### Test AppImage

```bash
# The built AppImage will be in appimage/build/
chmod +x appimage/build/BizSync-*.AppImage
./appimage/build/BizSync-*.AppImage
```

## 🔧 Build Scripts

### Main Build Script (`build-appimage.sh`)

The primary build script handles the complete AppImage creation process:

- ✅ Flutter app compilation
- ✅ Dependency bundling
- ✅ AppDir structure creation
- ✅ AppImage generation
- ✅ Testing and validation

**Usage:**
```bash
./appimage/scripts/build-appimage.sh [options]

Options:
  --clean       Clean previous builds
  --deps-only   Check dependencies only
  --flutter-only Build Flutter app only
  --test        Test existing AppImage
```

### Dependency Bundling (`bundle-dependencies.sh`)

Handles automatic detection and bundling of required libraries:

- 🔍 Library dependency analysis
- 📦 GTK and system library bundling
- 🎨 Theme and icon bundling
- 🖥️ Mesa driver inclusion
- 🎵 GStreamer plugin bundling

### Version Management (`version-manager.sh`)

Manages versioning across all components:

- 📈 Semantic version bumping
- 📝 Metadata updates
- 📋 Changelog generation
- 🏗️ Build metadata creation

**Usage:**
```bash
./appimage/scripts/version-manager.sh info        # Show current version
./appimage/scripts/version-manager.sh bump patch  # Bump patch version
./appimage/scripts/version-manager.sh release     # Prepare release
```

### Update Manager (`update-manager.sh`)

Provides auto-update functionality:

- 🔍 Update availability checking
- ⬇️ Zsync-based downloading
- 🔄 Automatic application of updates
- 🔔 Update notifications

### Signing Manager (`signing-manager.sh`)

Handles digital signing for security:

- 🔐 GPG key generation
- ✍️ AppImage signing
- ✅ Signature verification
- 🛡️ Security documentation

## 🤖 CI/CD Integration

### GitHub Actions

The repository includes comprehensive GitHub Actions workflows:

#### Release Workflow (`.github/workflows/appimage-release.yml`)

Automatically builds and releases AppImages on:
- 🏷️ Tag pushes (`v*`)
- 🚀 Manual workflow dispatch
- 📝 Pull requests (testing)

Features:
- ✅ Automated building
- 🔍 Multi-distribution testing
- 🔐 Digital signing
- 📦 Release creation
- ✅ Security scanning

#### CI Workflow (`.github/workflows/appimage-ci.yml`)

Continuous integration for development:
- 🧪 Build testing
- 📝 Code analysis
- 🔍 Script validation
- 🛡️ Security checks
- 📚 Documentation validation

### Setting Up CI/CD

1. **Generate Signing Key:**
   ```bash
   ./appimage/scripts/signing-manager.sh generate-key
   ```

2. **Export for CI:**
   ```bash
   ./appimage/scripts/signing-manager.sh setup-ci
   ./appimage/ci/export-key.sh YOUR_KEY_ID
   ```

3. **Add to GitHub Secrets:**
   - `GPG_PRIVATE_KEY`: Base64-encoded private key
   - `GPG_KEY_ID`: Key identifier

## 🔄 Auto-Updates

### Configuration

Auto-updates use zsync for efficient differential updates:

```bash
# Configure auto-updates
./appimage/scripts/update-manager.sh configure true

# Check for updates
./appimage/scripts/update-manager.sh check

# Apply updates
./appimage/scripts/update-manager.sh update
```

### Update Server Setup

The AppImage expects updates from:
```
https://github.com/your-repo/bizsync/releases/download/continuous/
```

Required files:
- `BizSync-VERSION-x86_64.AppImage`
- `BizSync-VERSION-x86_64.AppImage.zsync`

### User Experience

- 🔄 Background update checking
- 🔔 Update notifications
- 📥 One-click updates
- 🔙 Automatic rollback on failure

## 🔐 Security

### Digital Signatures

All AppImages are signed with GPG:

```bash
# Verify signature
gpg --verify BizSync-*.AppImage.sig BizSync-*.AppImage

# Use verification script
./BizSync-*.AppImage.verify
```

### Security Features

- ✅ GPG signature verification
- 🔍 SHA256 checksum validation
- 🛡️ Integrity checking
- 📝 Audit trails

## 🧪 Testing

### Automated Testing

The build process includes comprehensive testing:

- ✅ Dependency verification
- 🔍 AppImage structure validation
- 🖥️ Multi-distribution compatibility
- 🔐 Security scanning

### Manual Testing

```bash
# Test AppImage execution
./BizSync-*.AppImage --version

# Test desktop integration
./BizSync-*.AppImage --appimage-extract
```

## 📋 Compatibility

### System Requirements

**Minimum Requirements:**
- Linux x86_64 (64-bit)
- GLIBC 2.31+ (Ubuntu 20.04+)
- GTK 3.24+
- X11 or Wayland display server

**Tested Distributions:**
- ✅ Ubuntu 20.04, 22.04
- ✅ Debian 11, 12
- ✅ Fedora 36+
- ✅ openSUSE Leap 15.4+
- ✅ Arch Linux

### Runtime Dependencies

Bundled in AppImage:
- GTK3 libraries
- Flutter engine
- Mesa drivers
- Essential system libraries

External dependencies:
- FUSE (for AppImage mounting)
- Basic X11/Wayland libraries

## 🛠️ Customization

### AppRun Script

The `AppRun` script can be customized for:
- Environment variable setup
- Library path configuration
- Desktop integration
- Error handling

### Build Configuration

Modify build scripts for:
- Custom dependency inclusion
- Build optimization
- Platform-specific adjustments
- Additional metadata

## 📚 Advanced Usage

### Development Builds

```bash
# Build development AppImage
./appimage/scripts/build-appimage.sh --debug

# Skip signing for development
export SKIP_SIGNING=1
./appimage/scripts/build-appimage.sh
```

### Custom Metadata

Update AppStream metadata in:
```bash
appimage/scripts/build-appimage.sh  # create_appstream_metadata function
```

### Environment Variables

Control build behavior:
- `SKIP_SIGNING=1`: Skip digital signing
- `DEBUG_BUILD=1`: Enable debug information
- `CUSTOM_UPDATE_URL`: Override update URL

## 🐛 Troubleshooting

### Common Issues

1. **FUSE not available:**
   ```bash
   sudo apt install fuse
   # Or run with: ./app.AppImage --appimage-extract-and-run
   ```

2. **Permission denied:**
   ```bash
   chmod +x BizSync-*.AppImage
   ```

3. **Missing dependencies:**
   ```bash
   ldd BizSync-*.AppImage  # Check dependencies
   ./appimage/scripts/bundle-dependencies.sh --validate
   ```

4. **Signature verification fails:**
   ```bash
   # Import public key
   gpg --import appimage/keys/public_key.asc
   ```

### Debug Mode

Enable verbose logging:
```bash
export APPIMAGE_DEBUG=1
./BizSync-*.AppImage
```

## 📞 Support

For AppImage-specific issues:

1. Check the troubleshooting section
2. Review build logs in `appimage/build/`
3. Test with `--appimage-extract-and-run`
4. Report issues with:
   - AppImage version
   - Linux distribution
   - Error messages
   - Build logs

## 📄 License

The AppImage configuration is part of the BizSync project and follows the same licensing terms.

---

**Built with ❤️ for the Linux community**

This AppImage configuration provides a production-ready, secure, and user-friendly distribution method for BizSync on Linux systems.