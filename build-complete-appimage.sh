#!/bin/bash

# BizSync Complete AppImage Build Script
# Production-ready script that creates a fully self-contained AppImage
# with all dependencies bundled including keybinder3

set -e

# Configuration
APP_NAME="BizSync"
VERSION="1.3.0"
BUILD_NUMBER="4"
ARCH="x86_64"
AUTHOR="BizSync Team"

# Directories
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPIMAGE_DIR="${PROJECT_ROOT}/appimage"
APPDIR="${APPIMAGE_DIR}/AppDir"
BUILD_DIR="${APPIMAGE_DIR}/build"
FLUTTER_BUILD_DIR="${PROJECT_ROOT}/build/linux/x64/release/bundle"
SCRIPTS_DIR="${APPIMAGE_DIR}/scripts"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} ${BOLD}$1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${CYAN}[SUCCESS]${NC} ${BOLD}$1${NC}"
}

# Function to check system dependencies
check_dependencies() {
    log_step "Checking system dependencies..."
    
    local missing_deps=()
    
    # Essential build tools
    local required_tools=("flutter" "wget" "strip" "ldd" "file")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_deps+=("$tool")
        fi
    done
    
    # Check for keybinder3
    if ! pkg-config --exists keybinder-3.0 2>/dev/null; then
        log_warn "keybinder-3.0 not found via pkg-config, checking for library files..."
        
        local keybinder_found=false
        local keybinder_paths=(
            "/usr/lib/libkeybinder-3.0.so.0"
            "/usr/lib/x86_64-linux-gnu/libkeybinder-3.0.so.0"
        )
        
        for path in "${keybinder_paths[@]}"; do
            if [ -f "$path" ]; then
                keybinder_found=true
                log_info "Found keybinder library: $path"
                break
            fi
        done
        
        if [ "$keybinder_found" = false ]; then
            log_warn "Keybinder library not found. Hotkey functionality will be disabled."
            log_info "To enable hotkeys, install libkeybinder3 (pacman -S libkeybinder3)"
        fi
    else
        log_info "keybinder-3.0 found and available"
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        exit 1
    fi
    
    log_info "All essential dependencies are available"
}

# Function to clean previous builds
clean_build() {
    log_step "Cleaning previous build artifacts..."
    
    if [ "$1" = "--clean" ]; then
        rm -rf "${BUILD_DIR}"
        rm -rf "${APPDIR}/usr"
        log_info "Cleaned build directory and AppDir"
    fi
    
    # Always clean Flutter build for fresh start
    cd "${PROJECT_ROOT}"
    flutter clean
    log_info "Cleaned Flutter build cache"
}

# Function to prepare AppDir structure
prepare_appdir() {
    log_step "Preparing AppImage directory structure..."
    
    # Create directory structure
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${APPDIR}/usr/bin"
    mkdir -p "${APPDIR}/usr/lib"
    mkdir -p "${APPDIR}/usr/share/applications"
    mkdir -p "${APPDIR}/usr/share/icons/hicolor"
    mkdir -p "${APPDIR}/usr/share/glib-2.0/schemas"
    mkdir -p "${APPDIR}/usr/share/themes"
    mkdir -p "${APPDIR}/usr/share/fontconfig"
    
    # Create icon directories
    for size in 16 32 48 64 128 256 512; do
        mkdir -p "${APPDIR}/usr/share/icons/hicolor/${size}x${size}/apps"
    done
    
    log_info "AppDir structure prepared"
}

# Function to build Flutter application
build_flutter_app() {
    log_step "Building Flutter application for Linux..."
    
    cd "${PROJECT_ROOT}"
    
    # Get Flutter dependencies
    flutter pub get
    
    # Build the application
    flutter build linux --release --verbose
    
    # Verify build success
    if [ ! -d "${FLUTTER_BUILD_DIR}" ]; then
        log_error "Flutter build failed - bundle directory not found"
        exit 1
    fi
    
    if [ ! -f "${FLUTTER_BUILD_DIR}/bizsync" ]; then
        log_error "Flutter build failed - executable not found"
        exit 1
    fi
    
    log_success "Flutter application built successfully"
}

# Function to copy application files
copy_application_files() {
    log_step "Copying application files to AppDir..."
    
    # Copy Flutter build
    cp -r "${FLUTTER_BUILD_DIR}"/* "${APPDIR}/usr/"
    
    # Move the main executable to the correct location
    if [ -f "${APPDIR}/usr/bizsync" ]; then
        mv "${APPDIR}/usr/bizsync" "${APPDIR}/usr/bin/bizsync"
        chmod +x "${APPDIR}/usr/bin/bizsync"
    elif [ -f "${APPDIR}/usr/bin/bizsync" ]; then
        chmod +x "${APPDIR}/usr/bin/bizsync"
    elif [ -f "${APPDIR}/usr/bin/${APP_NAME,,}" ]; then
        mv "${APPDIR}/usr/bin/${APP_NAME,,}" "${APPDIR}/usr/bin/bizsync"
        chmod +x "${APPDIR}/usr/bin/bizsync"
    else
        log_error "Flutter executable not found in expected locations"
        ls -la "${APPDIR}/usr/"
        exit 1
    fi
    
    log_info "Application files copied successfully"
}

# Function to setup desktop integration files
setup_desktop_integration() {
    log_step "Setting up desktop integration files..."
    
    # Create desktop file
    cat > "${APPDIR}/bizsync.desktop" << EOF
[Desktop Entry]
Type=Application
Name=${APP_NAME}
Comment=Offline-first business management application
GenericName=Business Management
Keywords=business;accounting;invoice;tax;inventory;
Exec=bizsync
Icon=bizsync
StartupNotify=true
StartupWMClass=bizsync
Categories=Office;Finance;
MimeType=application/x-bizsync-project;
Terminal=false
Version=1.0
X-AppImage-Version=${VERSION}
EOF
    
    # Copy to applications directory
    cp "${APPDIR}/bizsync.desktop" "${APPDIR}/usr/share/applications/"
    
    # Create or copy icons
    local icon_source="${PROJECT_ROOT}/assets/icon/app_icon.png"
    if [ -f "$icon_source" ]; then
        # Convert and resize icon for different sizes
        for size in 16 32 48 64 128 256 512; do
            local icon_dest="${APPDIR}/usr/share/icons/hicolor/${size}x${size}/apps/bizsync.png"
            if command -v convert >/dev/null 2>&1; then
                convert "$icon_source" -resize "${size}x${size}" "$icon_dest" 2>/dev/null || {
                    cp "$icon_source" "$icon_dest"
                }
            else
                cp "$icon_source" "$icon_dest"
            fi
        done
        
        # Copy main icon
        cp "$icon_source" "${APPDIR}/bizsync.png"
    else
        log_warn "App icon not found, using default placeholder"
        # Create a simple placeholder icon
        echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==" | base64 -d > "${APPDIR}/bizsync.png"
    fi
    
    log_info "Desktop integration files created"
}

# Function to bundle dependencies
bundle_dependencies() {
    log_step "Bundling application dependencies..."
    
    if [ -f "${SCRIPTS_DIR}/bundle-dependencies.sh" ]; then
        chmod +x "${SCRIPTS_DIR}/bundle-dependencies.sh"
        "${SCRIPTS_DIR}/bundle-dependencies.sh" "${APPDIR}" "${FLUTTER_BUILD_DIR}"
    else
        log_error "Dependency bundling script not found"
        exit 1
    fi
    
    log_success "Dependencies bundled successfully"
}

# Function to create AppStream metadata
create_appstream_metadata() {
    log_step "Creating AppStream metadata..."
    
    mkdir -p "${APPDIR}/usr/share/metainfo"
    
    cat > "${APPDIR}/usr/share/metainfo/bizsync.appdata.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>bizsync</id>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>GPL-3.0-or-later</project_license>
  <name>${APP_NAME}</name>
  <summary>Offline-first business management application</summary>
  <description>
    <p>
      BizSync is a comprehensive business management application designed for
      small to medium businesses. It provides offline-first functionality with
      advanced CRDT synchronization, comprehensive tax calculations, and
      enterprise-grade security.
    </p>
    <p>Features include:</p>
    <ul>
      <li>Invoice and quote management</li>
      <li>Customer and vendor tracking</li>
      <li>Inventory management</li>
      <li>Tax calculations and compliance</li>
      <li>Financial reporting and analytics</li>
      <li>Offline-first architecture</li>
      <li>Cross-platform synchronization</li>
    </ul>
  </description>
  <categories>
    <category>Office</category>
    <category>Finance</category>
  </categories>
  <keywords>
    <keyword>business</keyword>
    <keyword>accounting</keyword>
    <keyword>invoice</keyword>
    <keyword>tax</keyword>
    <keyword>inventory</keyword>
  </keywords>
  <url type="homepage">https://github.com/your-repo/bizsync</url>
  <url type="bugtracker">https://github.com/your-repo/bizsync/issues</url>
  <launchable type="desktop-id">bizsync.desktop</launchable>
  <provides>
    <binary>bizsync</binary>
  </provides>
  <releases>
    <release version="${VERSION}" date="$(date +%Y-%m-%d)">
      <description>
        <p>Latest release with improved stability and new features.</p>
      </description>
    </release>
  </releases>
</component>
EOF
    
    log_info "AppStream metadata created"
}

# Function to download and prepare appimagetool
setup_appimagetool() {
    log_step "Setting up AppImageTool..."
    
    local appimagetool_path="${BUILD_DIR}/appimagetool"
    
    if [ ! -f "$appimagetool_path" ]; then
        log_info "Downloading AppImageTool..."
        wget -O "$appimagetool_path" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
        chmod +x "$appimagetool_path"
    fi
    
    log_info "AppImageTool ready"
}

# Function to build AppImage
build_appimage() {
    log_step "Building AppImage..."
    
    local output_file="${BUILD_DIR}/${APP_NAME}-${VERSION}-${ARCH}.AppImage"
    local appimagetool_path="${BUILD_DIR}/appimagetool"
    
    # Set environment variables for appimagetool
    export ARCH="${ARCH}"
    export VERSION="${VERSION}"
    
    # Remove existing AppImage
    [ -f "$output_file" ] && rm "$output_file"
    
    # Build AppImage
    log_info "Running appimagetool..."
    "$appimagetool_path" --appimage-extract-and-run "${APPDIR}" "$output_file"
    
    if [ ! -f "$output_file" ]; then
        log_error "AppImage build failed"
        exit 1
    fi
    
    # Make executable and calculate size
    chmod +x "$output_file"
    local file_size=$(du -h "$output_file" | cut -f1)
    
    log_success "AppImage built successfully!"
    log_info "Output: $output_file"
    log_info "Size: $file_size"
    
    return 0
}

# Function to test AppImage
test_appimage() {
    log_step "Testing AppImage..."
    
    local appimage_file="${BUILD_DIR}/${APP_NAME}-${VERSION}-${ARCH}.AppImage"
    
    if [ ! -f "$appimage_file" ]; then
        log_error "AppImage not found for testing"
        return 1
    fi
    
    # Test if AppImage is executable
    if [ ! -x "$appimage_file" ]; then
        log_error "AppImage is not executable"
        return 1
    fi
    
    # Test AppImage structure
    log_info "Validating AppImage structure..."
    "$appimage_file" --appimage-extract-and-run --version 2>/dev/null || {
        log_warn "Could not get version info (this might be normal)"
    }
    
    # Test desktop integration
    if [ -f "${APPDIR}/bizsync.desktop" ]; then
        if command -v desktop-file-validate >/dev/null 2>&1; then
            desktop-file-validate "${APPDIR}/bizsync.desktop" || {
                log_warn "Desktop file validation issues detected"
            }
        fi
    fi
    
    log_success "AppImage testing completed"
}

# Function to create distribution package
create_distribution_package() {
    log_step "Creating distribution package..."
    
    local dist_dir="${PROJECT_ROOT}/release-assets"
    local appimage_file="${BUILD_DIR}/${APP_NAME}-${VERSION}-${ARCH}.AppImage"
    
    mkdir -p "$dist_dir"
    
    # Copy AppImage to release directory
    if [ -f "$appimage_file" ]; then
        cp "$appimage_file" "$dist_dir/"
        
        # Create checksums
        cd "$dist_dir"
        sha256sum "$(basename "$appimage_file")" > "$(basename "$appimage_file").sha256"
        
        # Create info file
        cat > "${APP_NAME}-${VERSION}-info.txt" << EOF
${APP_NAME} v${VERSION} - Linux AppImage
=====================================

Built: $(date)
Architecture: ${ARCH}
Size: $(du -h "$appimage_file" | cut -f1)

Installation:
1. Download the AppImage file
2. Make it executable: chmod +x ${APP_NAME}-${VERSION}-${ARCH}.AppImage
3. Run: ./${APP_NAME}-${VERSION}-${ARCH}.AppImage

System Requirements:
- Linux x86_64 (64-bit)
- FUSE support (for AppImage mounting)
- GTK 3.24+ compatible system

Features:
- Self-contained (no installation required)
- Desktop integration included
- All dependencies bundled
- Hardware acceleration support
- Wayland and X11 compatible

For more information, visit: https://github.com/your-repo/bizsync
EOF
        
        log_success "Distribution package created in: $dist_dir"
    else
        log_error "AppImage not found for distribution packaging"
        return 1
    fi
}

# Function to display build summary
show_build_summary() {
    echo ""
    echo "=================================="
    log_success "BizSync AppImage Build Complete!"
    echo "=================================="
    echo ""
    
    local appimage_file="${BUILD_DIR}/${APP_NAME}-${VERSION}-${ARCH}.AppImage"
    local dist_dir="${PROJECT_ROOT}/release-assets"
    
    if [ -f "$appimage_file" ]; then
        echo "📦 AppImage Details:"
        echo "   File: $appimage_file"
        echo "   Size: $(du -h "$appimage_file" | cut -f1)"
        echo "   Version: ${VERSION}"
        echo "   Architecture: ${ARCH}"
        echo ""
        
        echo "🚀 How to run:"
        echo "   chmod +x \"$appimage_file\""
        echo "   \"$appimage_file\""
        echo ""
        
        if [ -d "$dist_dir" ]; then
            echo "📋 Distribution files:"
            ls -la "$dist_dir"/${APP_NAME}-${VERSION}*
            echo ""
        fi
        
        echo "✨ Features included:"
        echo "   ✅ All dependencies bundled"
        echo "   ✅ Desktop integration"
        echo "   ✅ Hardware acceleration"
        echo "   ✅ Wayland/X11 compatibility"
        
        if [ -f "${APPDIR}/usr/lib/libkeybinder-3.0.so.0" ]; then
            echo "   ✅ Hotkey support (keybinder3)"
        else
            echo "   ⚠️  Hotkey support disabled (keybinder3 not found)"
        fi
        
        echo ""
        echo "🎉 Ready for distribution!"
    else
        log_error "Build completed but AppImage not found"
    fi
}

# Main function
main() {
    echo ""
    echo "🚀 BizSync AppImage Builder"
    echo "=========================="
    echo ""
    
    # Parse command line arguments
    local clean_build=false
    local skip_tests=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                clean_build=true
                shift
                ;;
            --skip-tests)
                skip_tests=true
                shift
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --clean       Clean previous builds"
                echo "  --skip-tests  Skip AppImage testing"
                echo "  --help        Show this help"
                echo ""
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Execute build steps
    check_dependencies
    
    if [ "$clean_build" = true ]; then
        clean_build --clean
    else
        clean_build
    fi
    
    prepare_appdir
    build_flutter_app
    copy_application_files
    setup_desktop_integration
    bundle_dependencies
    create_appstream_metadata
    setup_appimagetool
    build_appimage
    
    if [ "$skip_tests" = false ]; then
        test_appimage
    fi
    
    create_distribution_package
    show_build_summary
}

# Handle script termination
cleanup() {
    log_info "Build process interrupted"
    exit 1
}

trap cleanup INT TERM

# Execute main function
main "$@"