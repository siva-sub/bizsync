#!/bin/bash
# BizSync Cross-Platform Build Script
# Version: 1.0.0
# Author: Sivasubramanian Ramanthan

set -e

# Detect operating system
OS="$(uname -s)"

# Build configuration
VERSION="1.0.0"
PROJECT_NAME="bizsync"

# Prepare build environment
prepare_build() {
    echo "Preparing build environment..."
    mkdir -p dist
    pip install -r requirements.txt
}

# Build for Linux
build_linux() {
    echo "Building for Linux..."
    pyinstaller --onefile --name ${PROJECT_NAME}-linux-${VERSION} src/main.py
    mv dist/${PROJECT_NAME}-linux-${VERSION} dist/
}

# Build for macOS
build_macos() {
    echo "Building for macOS..."
    pyinstaller --onefile --name ${PROJECT_NAME}-macos-${VERSION} src/main.py
    mv dist/${PROJECT_NAME}-macos-${VERSION} dist/
}

# Build for Windows
build_windows() {
    echo "Building for Windows..."
    pyinstaller --onefile --name ${PROJECT_NAME}-windows-${VERSION}.exe src/main.py
    mv dist/${PROJECT_NAME}-windows-${VERSION}.exe dist/
}

# Main build process
main() {
    prepare_build

    case "$OS" in
        "Linux")
            build_linux
            ;;
        "Darwin")
            build_macos
            ;;
        "MINGW"*|"MSYS"*|"CYGWIN"*)
            build_windows
            ;;
        *)
            echo "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    echo "Build completed successfully!"
}

main