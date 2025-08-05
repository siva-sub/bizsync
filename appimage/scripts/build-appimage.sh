#!/bin/bash

# BizSync AppImage Build Script
# This script builds a production-ready AppImage for BizSync

set -e

# Configuration
APP_NAME="BizSync"
APP_ID="com.bizsync.app"
ARCH="x86_64"
VERSION="1.2.0"
BUILD_NUMBER="3"

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"
APPIMAGE_DIR="${PROJECT_ROOT}/appimage"
APPDIR="${APPIMAGE_DIR}/AppDir"
BUILD_DIR="${APPIMAGE_DIR}/build"
FLUTTER_BUILD_DIR="${PROJECT_ROOT}/build/linux/x64/release/bundle"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check dependencies
check_dependencies() {
    log_info "Checking build dependencies..."
    
    local missing_deps=()
    
    # Check for required tools
    for cmd in flutter cmake ninja-build pkg-config libgtk-3-dev libblkid-dev liblzma-dev; do
        if ! command -v "$cmd" >/dev/null 2>&1 && ! dpkg -l | grep -q "$cmd"; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Check for AppImageTool
    if [ ! -f "${BUILD_DIR}/appimagetool" ]; then
        log_info "Downloading AppImageTool..."
        mkdir -p "${BUILD_DIR}"
        wget -O "${BUILD_DIR}/appimagetool" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
        chmod +x "${BUILD_DIR}/appimagetool"
    fi
    
    # Check for linuxdeploy
    if [ ! -f "${BUILD_DIR}/linuxdeploy" ]; then
        log_info "Downloading linuxdeploy..."
        wget -O "${BUILD_DIR}/linuxdeploy" "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
        chmod +x "${BUILD_DIR}/linuxdeploy"
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install them using: sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi
    
    log_info "All dependencies satisfied"
}

# Function to clean previous builds
clean_build() {
    log_info "Cleaning previous builds..."
    rm -rf "${APPDIR}/usr/bin" "${APPDIR}/usr/lib" "${APPDIR}/usr/share/lib"
    mkdir -p "${APPDIR}/usr/bin" "${APPDIR}/usr/lib" "${APPDIR}/usr/share/lib"
}

# Function to build Flutter application
build_flutter_app() {
    log_info "Building Flutter application for Linux..."
    
    cd "${PROJECT_ROOT}"
    
    # Clean previous Flutter builds
    flutter clean
    
    # Get dependencies
    flutter pub get
    
    # Build for Linux release
    flutter build linux --release --verbose
    
    if [ ! -d "${FLUTTER_BUILD_DIR}" ]; then
        log_error "Flutter build failed - bundle directory not found"
        exit 1
    fi
    
    log_info "Flutter build completed successfully"
}

# Function to copy application files
copy_app_files() {
    log_info "Copying application files to AppDir..."
    
    # Copy Flutter bundle
    cp -r "${FLUTTER_BUILD_DIR}"/* "${APPDIR}/usr/bin/"
    
    # Rename main executable
    if [ -f "${APPDIR}/usr/bin/bizsync" ]; then
        log_info "Main executable found"
    else
        log_error "Main executable 'bizsync' not found in Flutter bundle"
        ls -la "${APPDIR}/usr/bin/"
        exit 1
    fi
    
    # Copy additional data files if they exist
    if [ -d "${PROJECT_ROOT}/assets" ]; then
        mkdir -p "${APPDIR}/usr/share/bizsync"
        cp -r "${PROJECT_ROOT}/assets" "${APPDIR}/usr/share/bizsync/"
    fi
}

# Function to bundle dependencies
bundle_dependencies() {
    log_info "Bundling dependencies with linuxdeploy..."
    
    cd "${APPIMAGE_DIR}"
    
    # Use linuxdeploy to bundle dependencies
    "${BUILD_DIR}/linuxdeploy" \
        --appdir "${APPDIR}" \
        --executable "${APPDIR}/usr/bin/bizsync" \
        --desktop-file "${APPDIR}/usr/share/applications/bizsync.desktop" \
        --icon-file "${APPDIR}/bizsync.png" \
        --output appimage \
        --verbosity 2
    
    # Additional manual library copying for Flutter-specific dependencies
    copy_flutter_libraries
}

# Function to copy Flutter-specific libraries
copy_flutter_libraries() {
    log_info "Copying Flutter-specific libraries..."
    
    # Get Flutter library path
    FLUTTER_LIB_PATH="$(flutter --print-app-dir)/lib"
    
    # Copy ICU data files
    if [ -f "${FLUTTER_BUILD_DIR}/icudtl.dat" ]; then
        cp "${FLUTTER_BUILD_DIR}/icudtl.dat" "${APPDIR}/usr/bin/"
    fi
    
    # Copy Flutter engine libraries
    for lib in libflutter_linux_gtk.so; do
        if [ -f "${FLUTTER_BUILD_DIR}/${lib}" ]; then
            cp "${FLUTTER_BUILD_DIR}/${lib}" "${APPDIR}/usr/lib/"
        fi
    done
    
    # Copy system libraries that might be missing
    copy_system_libraries
}

# Function to copy essential system libraries
copy_system_libraries() {
    log_info "Copying essential system libraries..."
    
    # Define essential libraries for Flutter Linux
    local essential_libs=(
        "libgtk-3.so.0"
        "libgdk-3.so.0"
        "libglib-2.0.so.0"
        "libgobject-2.0.so.0"
        "libgio-2.0.so.0"
        "libgdk_pixbuf-2.0.so.0"
        "libcairo.so.2"
        "libpango-1.0.so.0"
        "libpangocairo-1.0.so.0"
        "libatk-1.0.so.0"
        "libepoxy.so.0"
        "libX11.so.6"
        "libXcomposite.so.1"
        "libXdamage.so.1"
        "libXext.so.6"
        "libXfixes.so.3"
        "libXrandr.so.2"
        "libXrender.so.1"
        "libXi.so.6"
        "libXcursor.so.1"
    )
    
    # Find and copy libraries
    for lib in "${essential_libs[@]}"; do
        lib_path=$(ldconfig -p | grep "$lib" | awk '{print $4}' | head -1)
        if [ -n "$lib_path" ] && [ -f "$lib_path" ]; then
            cp "$lib_path" "${APPDIR}/usr/lib/" 2>/dev/null || true
        fi
    done
}

# Function to create AppStream metadata
create_appstream_metadata() {
    log_info "Creating AppStream metadata..."
    
    cat > "${APPDIR}/usr/share/metainfo/${APP_ID}.appdata.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>${APP_ID}</id>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>MIT</project_license>
  <name>BizSync</name>
  <summary>Professional offline-first business management application</summary>
  <description>
    <p>
      BizSync is a comprehensive business management suite designed for modern enterprises.
      It features offline-first architecture with CRDT synchronization, comprehensive tax 
      calculations for Singapore businesses, invoice management, and enterprise-grade security.
    </p>
    <p>Key features:</p>
    <ul>
      <li>Offline-first with seamless synchronization</li>
      <li>Comprehensive tax and GST calculations</li>
      <li>Professional invoicing system</li>
      <li>Customer and vendor management</li>
      <li>Advanced reporting and analytics</li>
      <li>Enterprise-grade security</li>
    </ul>
  </description>
  <launchable type="desktop-id">${APP_ID}.desktop</launchable>
  <provides>
    <binary>bizsync</binary>
  </provides>
  <screenshots>
    <screenshot type="default">
      <image>https://raw.githubusercontent.com/your-repo/bizsync/main/docs/screenshots/main.png</image>
    </screenshot>
  </screenshots>
  <url type="homepage">https://github.com/your-repo/bizsync</url>
  <url type="bugtracker">https://github.com/your-repo/bizsync/issues</url>
  <developer_name>BizSync Team</developer_name>
  <update_contact>contact@bizsync.app</update_contact>
  <releases>
    <release version="${VERSION}" date="$(date -I)">
      <description>
        <p>Latest stable release with improved performance and new features.</p>
      </description>
    </release>
  </releases>
  <content_rating type="oars-1.1"/>
  <categories>
    <category>Office</category>
    <category>Finance</category>
  </categories>
</component>
EOF
}

# Function to create update information
create_update_info() {
    log_info "Creating update information..."
    
    cat > "${BUILD_DIR}/update_info" << EOF
APPIMAGE_UPDATE_INFORMATION=zsync|https://github.com/your-repo/bizsync/releases/download/continuous/BizSync-${VERSION}-${ARCH}.AppImage.zsync
APPIMAGE_VERSION=${VERSION}
APPIMAGE_BUILD=${BUILD_NUMBER}
EOF
}

# Function to build AppImage
build_appimage() {
    log_info "Building AppImage..."
    
    cd "${APPIMAGE_DIR}"
    
    # Set update information
    if [ -f "${BUILD_DIR}/update_info" ]; then
        source "${BUILD_DIR}/update_info"
        export APPIMAGE_UPDATE_INFORMATION
    fi
    
    # Create AppImage
    ARCH="${ARCH}" "${BUILD_DIR}/appimagetool" \
        --comp gzip \
        --mksquashfs-opt -comp --mksquashfs-opt gzip \
        --mksquashfs-opt -Xcompression-level --mksquashfs-opt 9 \
        --updateinformation "${APPIMAGE_UPDATE_INFORMATION:-}" \
        "${APPDIR}" \
        "${BUILD_DIR}/BizSync-${VERSION}-${ARCH}.AppImage"
    
    if [ -f "${BUILD_DIR}/BizSync-${VERSION}-${ARCH}.AppImage" ]; then
        log_info "AppImage created successfully: ${BUILD_DIR}/BizSync-${VERSION}-${ARCH}.AppImage"
        
        # Create zsync file for updates
        if command -v zsyncmake >/dev/null 2>&1; then
            zsyncmake "${BUILD_DIR}/BizSync-${VERSION}-${ARCH}.AppImage"
        fi
        
        # Make executable
        chmod +x "${BUILD_DIR}/BizSync-${VERSION}-${ARCH}.AppImage"
        
        # Show file info
        ls -lh "${BUILD_DIR}/BizSync-${VERSION}-${ARCH}.AppImage"
        
    else
        log_error "Failed to create AppImage"
        exit 1
    fi
}

# Function to test AppImage
test_appimage() {
    log_info "Testing AppImage..."
    
    APPIMAGE_PATH="${BUILD_DIR}/BizSync-${VERSION}-${ARCH}.AppImage"
    
    if [ -f "${APPIMAGE_PATH}" ]; then
        # Test if AppImage can extract
        "${APPIMAGE_PATH}" --appimage-extract-and-run --version || true
        
        log_info "AppImage test completed"
    else
        log_error "AppImage not found for testing"
        exit 1
    fi
}

# Main build function
main() {
    log_info "Starting BizSync AppImage build process..."
    log_info "Version: ${VERSION}, Build: ${BUILD_NUMBER}, Architecture: ${ARCH}"
    
    check_dependencies
    clean_build
    build_flutter_app
    copy_app_files
    create_appstream_metadata
    create_update_info
    bundle_dependencies
    build_appimage
    test_appimage
    
    log_info "Build process completed successfully!"
    log_info "AppImage location: ${BUILD_DIR}/BizSync-${VERSION}-${ARCH}.AppImage"
}

# Handle script arguments
case "${1:-}" in
    --clean)
        log_info "Cleaning build directories..."
        rm -rf "${BUILD_DIR}" "${APPDIR}/usr"
        ;;
    --deps-only)
        check_dependencies
        ;;
    --flutter-only)
        build_flutter_app
        ;;
    --test)
        test_appimage
        ;;
    *)
        main
        ;;
esac