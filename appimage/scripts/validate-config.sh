#!/bin/bash

# BizSync AppImage Configuration Validator
# Validates the AppImage configuration before building

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"
APPDIR="${PROJECT_ROOT}/appimage/AppDir"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Validation functions
validate_directory_structure() {
    log_info "Validating directory structure..."
    
    local required_dirs=(
        "${APPDIR}"
        "${APPDIR}/usr"
        "${APPDIR}/usr/bin"
        "${APPDIR}/usr/lib"
        "${APPDIR}/usr/share"
        "${APPDIR}/usr/share/applications"
        "${APPDIR}/usr/share/icons/hicolor"
        "${APPDIR}/usr/share/metainfo"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_success "Directory exists: $(realpath --relative-to="$PROJECT_ROOT" "$dir")"
        else
            log_error "Missing directory: $(realpath --relative-to="$PROJECT_ROOT" "$dir")"
            return 1
        fi
    done
    
    return 0
}

validate_apprun_script() {
    log_info "Validating AppRun script..."
    
    local apprun="${APPDIR}/AppRun"
    
    if [ ! -f "$apprun" ]; then
        log_error "AppRun script not found"
        return 1
    fi
    
    if [ ! -x "$apprun" ]; then
        log_error "AppRun script is not executable"
        return 1
    fi
    
    # Check script syntax
    if bash -n "$apprun"; then
        log_success "AppRun script syntax is valid"
    else
        log_error "AppRun script has syntax errors"
        return 1
    fi
    
    # Check for required elements
    local required_patterns=(
        'HERE=".*dirname.*readlink'
        'export APPDIR'
        'export LD_LIBRARY_PATH'
        'exec.*bizsync'
    )
    
    for pattern in "${required_patterns[@]}"; do
        if grep -q "$pattern" "$apprun"; then
            log_success "AppRun contains: $pattern"
        else
            log_warn "AppRun missing pattern: $pattern"
        fi
    done
    
    return 0
}

validate_desktop_file() {
    log_info "Validating desktop file..."
    
    local desktop_files=(
        "${APPDIR}/bizsync.desktop"
        "${APPDIR}/usr/share/applications/bizsync.desktop"
    )
    
    for desktop_file in "${desktop_files[@]}"; do
        if [ ! -f "$desktop_file" ]; then
            log_error "Desktop file not found: $(basename "$desktop_file")"
            continue
        fi
        
        # Validate with desktop-file-validate if available
        if command -v desktop-file-validate >/dev/null 2>&1; then
            if desktop-file-validate "$desktop_file" 2>/dev/null; then
                log_success "Desktop file validation passed: $(basename "$desktop_file")"
            else
                log_warn "Desktop file validation failed: $(basename "$desktop_file")"
            fi
        else
            log_info "desktop-file-validate not available, skipping validation"
        fi
        
        # Check required fields
        local required_fields=(
            "Type=Application"
            "Name=BizSync"
            "Exec=bizsync"
            "Icon=bizsync"
            "Categories="
        )
        
        for field in "${required_fields[@]}"; do
            if grep -q "^$field" "$desktop_file"; then
                log_success "Desktop file contains: $field"
            else
                log_error "Desktop file missing: $field"
            fi
        done
    done
    
    return 0
}

validate_icons() {
    log_info "Validating application icons..."
    
    # Check main icon
    local main_icon="${APPDIR}/bizsync.png"
    if [ -f "$main_icon" ]; then
        log_success "Main icon found: $(basename "$main_icon")"
        
        # Check icon format
        if file "$main_icon" | grep -q "PNG image"; then
            log_success "Main icon is PNG format"
        else
            log_warn "Main icon is not PNG format"
        fi
    else
        log_error "Main icon not found: $main_icon"
    fi
    
    # Check hicolor icons
    local icon_sizes=(16 32 48 64 128 256 512)
    for size in "${icon_sizes[@]}"; do
        local icon_path="${APPDIR}/usr/share/icons/hicolor/${size}x${size}/apps/bizsync.png"
        if [ -f "$icon_path" ]; then
            log_success "Icon found: ${size}x${size}"
        else
            log_warn "Icon missing: ${size}x${size}"
        fi
    done
    
    return 0
}

validate_build_scripts() {
    log_info "Validating build scripts..."
    
    local scripts=(
        "build-appimage.sh"
        "bundle-dependencies.sh"
        "version-manager.sh"
        "update-manager.sh"
        "signing-manager.sh"
    )
    
    for script in "${scripts[@]}"; do
        local script_path="${SCRIPT_DIR}/${script}"
        
        if [ ! -f "$script_path" ]; then
            log_error "Build script not found: $script"
            continue
        fi
        
        if [ ! -x "$script_path" ]; then
            log_warn "Build script not executable: $script"
            chmod +x "$script_path"
            log_info "Made executable: $script"
        fi
        
        # Check syntax
        if bash -n "$script_path"; then
            log_success "Script syntax valid: $script"
        else
            log_error "Script syntax error: $script"
        fi
    done
    
    return 0
}

validate_flutter_config() {
    log_info "Validating Flutter configuration..."
    
    # Check pubspec.yaml
    local pubspec="${PROJECT_ROOT}/pubspec.yaml"
    if [ ! -f "$pubspec" ]; then
        log_error "pubspec.yaml not found"
        return 1
    fi
    
    # Check version format
    local version=$(grep "^version:" "$pubspec" | sed 's/version: *//')
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
        log_success "Version format valid: $version"
    else
        log_error "Invalid version format in pubspec.yaml: $version"
    fi
    
    # Check Linux dependencies
    local linux_deps=(
        "flutter:"
        "cupertino_icons:"
        "path_provider:"
        "sqflite_common_ffi:"
    )
    
    for dep in "${linux_deps[@]}"; do
        if grep -q "$dep" "$pubspec"; then
            log_success "Flutter dependency found: $dep"
        else
            log_warn "Flutter dependency missing: $dep"
        fi
    done
    
    return 0
}

validate_github_workflows() {
    log_info "Validating GitHub workflows..."
    
    local workflows=(
        "appimage-release.yml"
        "appimage-ci.yml"
    )
    
    for workflow in "${workflows[@]}"; do
        local workflow_path="${PROJECT_ROOT}/.github/workflows/${workflow}"
        
        if [ -f "$workflow_path" ]; then
            log_success "GitHub workflow found: $workflow"
            
            # Basic YAML syntax check
            if command -v yamllint >/dev/null 2>&1; then
                if yamllint "$workflow_path" >/dev/null 2>&1; then
                    log_success "Workflow YAML syntax valid: $workflow"
                else
                    log_warn "Workflow YAML syntax issues: $workflow"
                fi
            fi
        else
            log_warn "GitHub workflow not found: $workflow"
        fi
    done
    
    return 0
}

validate_dependencies() {
    log_info "Validating system dependencies..."
    
    local required_tools=(
        "flutter:Flutter SDK"
        "cmake:CMake build system"
        "ninja:Ninja build system"
        "pkg-config:Package config tool"
        "convert:ImageMagick (for icons)"
        "desktop-file-validate:Desktop file utils"
        "gpg:GnuPG (for signing)"
    )
    
    for tool_info in "${required_tools[@]}"; do
        local tool="${tool_info%:*}"
        local description="${tool_info#*:}"
        
        if command -v "$tool" >/dev/null 2>&1; then
            log_success "Tool available: $tool ($description)"
        else
            log_warn "Tool missing: $tool ($description)"
        fi
    done
    
    # Check Flutter doctor
    if command -v flutter >/dev/null 2>&1; then
        log_info "Running Flutter doctor..."
        if flutter doctor -v | grep -q "No issues found"; then
            log_success "Flutter doctor: No issues found"
        else
            log_warn "Flutter doctor found issues (check manually)"
        fi
    fi
    
    return 0
}

check_permissions() {
    log_info "Checking file permissions..."
    
    # Check critical files
    local executable_files=(
        "${APPDIR}/AppRun"
        "${SCRIPT_DIR}/build-appimage.sh"
        "${SCRIPT_DIR}/bundle-dependencies.sh"
        "${SCRIPT_DIR}/version-manager.sh"
        "${SCRIPT_DIR}/update-manager.sh"
        "${SCRIPT_DIR}/signing-manager.sh"
        "${PROJECT_ROOT}/build-appimage.sh"
    )
    
    for file in "${executable_files[@]}"; do
        if [ -f "$file" ]; then
            if [ -x "$file" ]; then
                log_success "Executable permission OK: $(basename "$file")"
            else
                log_warn "Missing executable permission: $(basename "$file")"
                chmod +x "$file"
                log_info "Fixed permission: $(basename "$file")"
            fi
        fi
    done
    
    return 0
}

generate_validation_report() {
    local report_file="${PROJECT_ROOT}/appimage/build/validation_report.txt"
    
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" << EOF
BizSync AppImage Configuration Validation Report
Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

Project Root: $PROJECT_ROOT
AppImage Dir: $APPDIR

Directory Structure: $(validate_directory_structure >/dev/null 2>&1 && echo "PASS" || echo "FAIL")
AppRun Script: $(validate_apprun_script >/dev/null 2>&1 && echo "PASS" || echo "FAIL")
Desktop File: $(validate_desktop_file >/dev/null 2>&1 && echo "PASS" || echo "FAIL")
Icons: $(validate_icons >/dev/null 2>&1 && echo "PASS" || echo "FAIL")
Build Scripts: $(validate_build_scripts >/dev/null 2>&1 && echo "PASS" || echo "FAIL")
Flutter Config: $(validate_flutter_config >/dev/null 2>&1 && echo "PASS" || echo "FAIL")
GitHub Workflows: $(validate_github_workflows >/dev/null 2>&1 && echo "PASS" || echo "FAIL")
Dependencies: $(validate_dependencies >/dev/null 2>&1 && echo "PASS" || echo "FAIL")
Permissions: $(check_permissions >/dev/null 2>&1 && echo "PASS" || echo "FAIL")

For detailed output, run: $0 --verbose
EOF

    log_info "Validation report saved: $report_file"
}

# Main validation function
main() {
    echo "BizSync AppImage Configuration Validator"
    echo "========================================"
    echo ""
    
    local exit_code=0
    local verbose=false
    
    if [ "$1" = "--verbose" ] || [ "$1" = "-v" ]; then
        verbose=true
    fi
    
    # Run all validations
    local validations=(
        "validate_directory_structure"
        "validate_apprun_script"
        "validate_desktop_file"
        "validate_icons"
        "validate_build_scripts"
        "validate_flutter_config"
        "validate_github_workflows"
        "validate_dependencies"
        "check_permissions"
    )
    
    for validation in "${validations[@]}"; do
        if [ "$verbose" = true ]; then
            if ! $validation; then
                exit_code=1
            fi
        else
            if $validation >/dev/null 2>&1; then
                log_success "$(echo "$validation" | sed 's/_/ /g' | sed 's/validate/Validation:/g' | sed 's/check/Check:/g')"
            else
                log_error "$(echo "$validation" | sed 's/_/ /g' | sed 's/validate/Validation:/g' | sed 's/check/Check:/g')"
                exit_code=1
            fi
        fi
        echo ""
    done
    
    # Generate report
    generate_validation_report
    
    if [ $exit_code -eq 0 ]; then
        log_success "All validations passed! AppImage configuration is ready."
    else
        log_error "Some validations failed. Please review the issues above."
        log_info "Run with --verbose for detailed output"
    fi
    
    exit $exit_code
}

# Run main function
main "$@"