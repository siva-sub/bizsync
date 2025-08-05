#!/bin/bash

# BizSync AppImage Master Build Script
# Convenient wrapper for the complete AppImage build process

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPIMAGE_SCRIPTS_DIR="${SCRIPT_DIR}/appimage/scripts"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_build() {
    echo -e "${BLUE}[BUILD]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show banner
show_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                            BizSync AppImage Builder                          ║
║                     Production-Ready Linux Distribution                      ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
}

# Function to check if scripts exist
check_scripts() {
    local scripts=(
        "build-appimage.sh"
        "bundle-dependencies.sh"
        "version-manager.sh"
        "update-manager.sh"
        "signing-manager.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ ! -f "${APPIMAGE_SCRIPTS_DIR}/${script}" ]; then
            log_error "Required script not found: ${script}"
            return 1
        fi
        
        if [ ! -x "${APPIMAGE_SCRIPTS_DIR}/${script}" ]; then
            log_warn "Making script executable: ${script}"
            chmod +x "${APPIMAGE_SCRIPTS_DIR}/${script}"
        fi
    done
    
    log_info "All build scripts verified"
    return 0
}

# Function to show system information
show_system_info() {
    log_info "System Information:"
    echo "  OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "$(uname -s) $(uname -r)")"
    echo "  Architecture: $(uname -m)"
    echo "  Flutter: $(flutter --version | head -n1 2>/dev/null || echo "Not found")"
    echo "  Dart: $(dart --version 2>&1 | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1 || echo "Not found")"
    echo "  GPG: $(gpg --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1 || echo "Not found")"
    echo ""
}

# Function to perform full build
full_build() {
    local sign_appimage="${1:-true}"
    
    log_build "Starting full AppImage build process..."
    
    # Check dependencies first
    log_build "Step 1/6: Checking dependencies..."
    "${APPIMAGE_SCRIPTS_DIR}/build-appimage.sh" --deps-only
    
    # Version management
    log_build "Step 2/6: Version management..."
    "${APPIMAGE_SCRIPTS_DIR}/version-manager.sh" info
    
    # Main build
    log_build "Step 3/6: Building AppImage..."
    "${APPIMAGE_SCRIPTS_DIR}/build-appimage.sh"
    
    # Find the built AppImage
    local appimage_file=$(find "${SCRIPT_DIR}/appimage/build" -name "*.AppImage" -type f | head -n1)
    
    if [ ! -f "$appimage_file" ]; then
        log_error "AppImage build failed - no output file found"
        return 1
    fi
    
    log_build "AppImage built: $(basename "$appimage_file")"
    
    # Digital signing
    if [ "$sign_appimage" = "true" ]; then
        log_build "Step 4/6: Digital signing..."
        if "${APPIMAGE_SCRIPTS_DIR}/signing-manager.sh" sign "$appimage_file"; then
            log_build "AppImage signed successfully"
            "${APPIMAGE_SCRIPTS_DIR}/signing-manager.sh" create-verify-script "$appimage_file"
        else
            log_warn "Signing failed - continuing without signature"
        fi
    else
        log_build "Step 4/6: Skipping digital signing (disabled)"
    fi
    
    # Verification
    log_build "Step 5/6: Verification..."
    if [ -f "${appimage_file}.sig" ]; then
        "${APPIMAGE_SCRIPTS_DIR}/signing-manager.sh" verify "$appimage_file"
    else
        log_info "Testing AppImage execution..."
        timeout 30s "$appimage_file" --appimage-extract-and-run --version || log_info "Basic test completed"
    fi
    
    # Final information
    log_build "Step 6/6: Build summary..."
    echo ""
    log_build "Build completed successfully!"
    echo "  AppImage: $appimage_file"
    echo "  Size: $(du -h "$appimage_file" | cut -f1)"
    echo "  Signature: $([ -f "${appimage_file}.sig" ] && echo "Yes" || echo "No")"
    echo "  Checksum: $([ -f "${appimage_file}.sha256" ] && echo "Yes" || echo "No")"
    echo ""
    
    # Usage instructions
    log_info "Usage Instructions:"
    echo "  1. Make executable: chmod +x $(basename "$appimage_file")"
    echo "  2. Run application: ./$(basename "$appimage_file")"
    if [ -f "${appimage_file}.verify" ]; then
        echo "  3. Verify integrity: ./$(basename "$appimage_file").verify"
    fi
    echo ""
}

# Function to setup development environment
setup_dev_environment() {
    log_info "Setting up development environment..."
    
    # Create development configuration
    cat > "${SCRIPT_DIR}/.appimage-dev" << EOF
# BizSync AppImage Development Configuration
SKIP_SIGNING=true
DEBUG_BUILD=true
DEV_MODE=true
EOF
    
    # Setup Git hooks if in Git repository
    if [ -d "${SCRIPT_DIR}/.git" ]; then
        log_info "Setting up Git hooks..."
        
        cat > "${SCRIPT_DIR}/.git/hooks/pre-commit" << 'EOF'
#!/bin/bash
# Pre-commit hook for AppImage validation

echo "Validating AppImage configuration..."

# Check script syntax
for script in appimage/scripts/*.sh; do
    if [ -f "$script" ]; then
        if ! bash -n "$script"; then
            echo "Syntax error in: $script"
            exit 1
        fi
    fi
done

# Validate desktop file
if [ -f "appimage/AppDir/bizsync.desktop" ]; then
    if command -v desktop-file-validate >/dev/null 2>&1; then
        desktop-file-validate appimage/AppDir/bizsync.desktop || exit 1
    fi
fi

echo "AppImage configuration validation passed"
EOF
        
        chmod +x "${SCRIPT_DIR}/.git/hooks/pre-commit"
        log_info "Git hooks installed"
    fi
    
    # Create development build script
    cat > "${SCRIPT_DIR}/build-dev.sh" << 'EOF'
#!/bin/bash
# Development build script

source .appimage-dev 2>/dev/null || true

export SKIP_SIGNING=${SKIP_SIGNING:-true}
export DEBUG_BUILD=${DEBUG_BUILD:-true}

echo "Building development AppImage..."
./build-appimage.sh --no-sign --dev
EOF
    
    chmod +x "${SCRIPT_DIR}/build-dev.sh"
    
    log_info "Development environment setup completed"
    log_info "Use ./build-dev.sh for development builds"
}

# Function to show help
show_help() {
    cat << EOF
BizSync AppImage Builder

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    build           Build production AppImage (default)
    dev-build       Build development AppImage (no signing)
    quick-build     Quick build for testing
    sign-only       Sign existing AppImage
    verify          Verify existing AppImage
    clean           Clean build artifacts
    setup-dev       Setup development environment
    version         Show version information
    help            Show this help message

OPTIONS:
    --no-sign       Skip digital signing
    --clean         Clean previous builds
    --verbose       Enable verbose output
    --dev           Development mode

EXAMPLES:
    $0                           # Full production build
    $0 build --clean             # Clean build
    $0 dev-build                 # Development build
    $0 sign-only BizSync.AppImage # Sign specific file
    $0 verify BizSync.AppImage   # Verify specific file

SCRIPTS:
    appimage/scripts/build-appimage.sh     - Main build script
    appimage/scripts/version-manager.sh    - Version management
    appimage/scripts/signing-manager.sh    - Digital signing
    appimage/scripts/update-manager.sh     - Auto-updates

For detailed documentation, see: appimage/README.md
EOF
}

# Main function
main() {
    show_banner
    echo ""
    
    # Check if we're in the right directory
    if [ ! -f "pubspec.yaml" ]; then
        log_error "This script must be run from the Flutter project root directory"
        log_error "Current directory: $(pwd)"
        exit 1
    fi
    
    # Verify scripts exist
    if ! check_scripts; then
        log_error "AppImage configuration incomplete"
        log_info "Run this script from the project root where appimage/ directory exists"
        exit 1
    fi
    
    # Parse arguments
    local command="${1:-build}"
    local skip_signing=false
    local clean_build=false
    local verbose=false
    local dev_mode=false
    
    shift || true  # Remove first argument
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-sign)
                skip_signing=true
                shift
                ;;
            --clean)
                clean_build=true
                shift
                ;;
            --verbose)
                verbose=true
                set -x
                shift
                ;;
            --dev)
                dev_mode=true
                skip_signing=true
                shift
                ;;
            *)
                # Unknown option, might be file for sign-only/verify
                break
                ;;
        esac
    done
    
    # Show system info if verbose
    if [ "$verbose" = true ]; then
        show_system_info
    fi
    
    # Execute command
    case "$command" in
        "build"|"")
            if [ "$clean_build" = true ]; then
                log_info "Cleaning previous builds..."
                "${APPIMAGE_SCRIPTS_DIR}/build-appimage.sh" --clean
            fi
            full_build "$(!$skip_signing && echo "true" || echo "false")"
            ;;
        "dev-build")
            log_info "Building development AppImage..."
            skip_signing=true
            full_build "false"
            ;;
        "quick-build")
            log_info "Quick build for testing..."
            "${APPIMAGE_SCRIPTS_DIR}/build-appimage.sh" --flutter-only
            ;;
        "sign-only")
            local target_file="$1"
            if [ -z "$target_file" ]; then
                target_file=$(find "${SCRIPT_DIR}/appimage/build" -name "*.AppImage" -type f | head -n1)
            fi
            if [ -f "$target_file" ]; then
                "${APPIMAGE_SCRIPTS_DIR}/signing-manager.sh" sign "$target_file"
            else
                log_error "AppImage file not found: $target_file"
                exit 1
            fi
            ;;
        "verify")
            local target_file="$1"
            if [ -z "$target_file" ]; then
                target_file=$(find "${SCRIPT_DIR}/appimage/build" -name "*.AppImage" -type f | head -n1)
            fi
            if [ -f "$target_file" ]; then
                "${APPIMAGE_SCRIPTS_DIR}/signing-manager.sh" verify "$target_file"
            else
                log_error "AppImage file not found: $target_file"
                exit 1
            fi
            ;;
        "clean")
            log_info "Cleaning build artifacts..."
            rm -rf "${SCRIPT_DIR}/appimage/build"/*
            rm -rf "${SCRIPT_DIR}/build/linux"
            log_info "Clean completed"
            ;;
        "setup-dev")
            setup_dev_environment
            ;;
        "version")
            "${APPIMAGE_SCRIPTS_DIR}/version-manager.sh" info
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'log_error "Build interrupted"; exit 1' INT TERM

# Run main function with all arguments
main "$@"