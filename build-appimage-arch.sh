#!/bin/bash

# BizSync AppImage Build Script for Arch Linux
# Simplified version that skips dpkg checks

set -e

# Configuration
APP_NAME="BizSync"
VERSION="1.3.0"
BUILD_NUMBER="4"
ARCH="x86_64"

# Directories
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPIMAGE_DIR="${PROJECT_ROOT}/appimage"
APPDIR="${APPIMAGE_DIR}/AppDir"
BUILD_DIR="${APPIMAGE_DIR}/build"
FLUTTER_BUILD_DIR="${PROJECT_ROOT}/build/linux/x64/release/bundle"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create directories
mkdir -p "${BUILD_DIR}"
mkdir -p "${APPDIR}/usr/bin"
mkdir -p "${APPDIR}/usr/lib"
mkdir -p "${APPDIR}/usr/share/applications"
mkdir -p "${APPDIR}/usr/share/icons/hicolor/256x256/apps"

# Build Flutter app
log_info "Building Flutter application..."
cd "${PROJECT_ROOT}"
flutter build linux --release

# Check if build succeeded
if [ ! -d "${FLUTTER_BUILD_DIR}" ]; then
    log_error "Flutter build failed - bundle directory not found"
    exit 1
fi

# Copy Flutter build to AppDir
log_info "Copying Flutter build to AppDir..."
cp -r "${FLUTTER_BUILD_DIR}"/* "${APPDIR}/usr/"

# Ensure the executable has the correct name
if [ -f "${APPDIR}/usr/bin/${APP_NAME,,}" ]; then
    mv "${APPDIR}/usr/bin/${APP_NAME,,}" "${APPDIR}/usr/bin/bizsync"
fi

# Copy desktop file and icon
log_info "Setting up desktop integration..."
cp "${APPDIR}/bizsync.desktop" "${APPDIR}/usr/share/applications/"
cp "${APPDIR}/bizsync.png" "${APPDIR}/usr/share/icons/hicolor/256x256/apps/"

# Copy additional libraries that might be needed
log_info "Bundling additional libraries..."
# Copy GTK and other essential libraries
for lib in /usr/lib/libgtk-3.so* /usr/lib/libgdk-3.so* /usr/lib/libepoxy.so*; do
    if [ -f "$lib" ]; then
        cp -L "$lib" "${APPDIR}/usr/lib/" 2>/dev/null || true
    fi
done

# Download appimagetool if not present
if [ ! -f "${BUILD_DIR}/appimagetool" ]; then
    log_info "Downloading appimagetool..."
    wget -O "${BUILD_DIR}/appimagetool" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x "${BUILD_DIR}/appimagetool"
fi

# Build AppImage
log_info "Building AppImage..."
OUTPUT_FILE="${BUILD_DIR}/${APP_NAME}-${VERSION}-${ARCH}.AppImage"

# Set environment variables for appimagetool
export ARCH="${ARCH}"
export VERSION="${VERSION}"

# Run appimagetool
"${BUILD_DIR}/appimagetool" "${APPDIR}" "${OUTPUT_FILE}"

if [ -f "${OUTPUT_FILE}" ]; then
    log_info "AppImage built successfully: ${OUTPUT_FILE}"
    log_info "Size: $(du -h "${OUTPUT_FILE}" | cut -f1)"
    
    # Make it executable
    chmod +x "${OUTPUT_FILE}"
    
    echo ""
    log_info "To run the AppImage:"
    echo "  ${OUTPUT_FILE}"
else
    log_error "AppImage build failed"
    exit 1
fi