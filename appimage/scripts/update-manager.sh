#!/bin/bash

# BizSync AppImage Update Manager
# Handles auto-updates using zsync and provides update functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"

# Configuration
UPDATE_SERVER_URL="https://github.com/your-repo/bizsync/releases/download/continuous"
UPDATE_CHECK_INTERVAL=86400  # 24 hours in seconds
UPDATE_CONFIG_DIR="${HOME}/.config/bizsync/updates"
UPDATE_CACHE_DIR="${HOME}/.cache/bizsync/updates"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_update() {
    echo -e "${BLUE}[UPDATE]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to detect if running as AppImage
is_appimage() {
    [ -n "${APPIMAGE}" ] && [ -f "${APPIMAGE}" ]
}

# Function to get current version
get_current_version() {
    if is_appimage; then
        # Extract version from AppImage path or metadata
        local appimage_name=$(basename "${APPIMAGE}")
        echo "$appimage_name" | grep -o 'v\?[0-9]\+\.[0-9]\+\.[0-9]\+' | sed 's/^v//' || echo "unknown"
    else
        # Running from source - get from pubspec.yaml
        if [ -f "${PROJECT_ROOT}/pubspec.yaml" ]; then
            grep "^version:" "${PROJECT_ROOT}/pubspec.yaml" | sed 's/version: *//' | cut -d'+' -f1
        else
            echo "development"
        fi
    fi
}

# Function to get latest version from GitHub API
get_latest_version() {
    local api_url="https://api.github.com/repos/your-repo/bizsync/releases/latest"
    
    if command -v curl >/dev/null 2>&1; then
        curl -s "$api_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//'
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$api_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//'
    else
        log_error "Neither curl nor wget available for update check"
        return 1
    fi
}

# Function to compare versions
version_greater() {
    local version1="$1"
    local version2="$2"
    
    # Convert versions to comparable format
    local v1=$(echo "$version1" | sed 's/[^0-9.]//g')
    local v2=$(echo "$version2" | sed 's/[^0-9.]//g')
    
    # Use sort to compare versions
    [ "$(printf '%s\n%s' "$v1" "$v2" | sort -V | head -n1)" != "$v1" ]
}

# Function to check if update is available
check_update_available() {
    local current_version=$(get_current_version)
    local latest_version=$(get_latest_version)
    
    if [ -z "$latest_version" ] || [ "$latest_version" = "null" ]; then
        log_warn "Could not fetch latest version information"
        return 1
    fi
    
    log_info "Current version: $current_version"
    log_info "Latest version: $latest_version"
    
    if version_greater "$latest_version" "$current_version"; then
        log_update "Update available: $current_version → $latest_version"
        return 0
    else
        log_info "No update available"
        return 1
    fi
}

# Function to download update using zsync
download_update() {
    if ! is_appimage; then
        log_error "Updates only supported when running as AppImage"
        return 1
    fi
    
    local latest_version=$(get_latest_version)
    if [ -z "$latest_version" ]; then
        log_error "Could not determine latest version"
        return 1
    fi
    
    # Create update directories
    mkdir -p "$UPDATE_CONFIG_DIR" "$UPDATE_CACHE_DIR"
    
    local zsync_url="${UPDATE_SERVER_URL}/BizSync-${latest_version}-x86_64.AppImage.zsync"
    local new_appimage="${UPDATE_CACHE_DIR}/BizSync-${latest_version}-x86_64.AppImage"
    
    log_update "Downloading update from: $zsync_url"
    
    # Try zsync2 first, then zsync
    if command -v zsync2 >/dev/null 2>&1; then
        cd "$UPDATE_CACHE_DIR"
        zsync2 -i "${APPIMAGE}" -o "$new_appimage" "$zsync_url"
    elif command -v zsync >/dev/null 2>&1; then
        cd "$UPDATE_CACHE_DIR"
        zsync -i "${APPIMAGE}" -o "$new_appimage" "$zsync_url"
    else
        log_warn "zsync not available, falling back to direct download"
        download_direct_update "$latest_version" "$new_appimage"
    fi
    
    if [ -f "$new_appimage" ]; then
        log_update "Update downloaded successfully: $new_appimage"
        return 0
    else
        log_error "Failed to download update"
        return 1
    fi
}

# Function to download update directly (fallback)
download_direct_update() {
    local version="$1"
    local output_file="$2"
    local download_url="${UPDATE_SERVER_URL}/BizSync-${version}-x86_64.AppImage"
    
    log_update "Downloading update directly from: $download_url"
    
    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$output_file" "$download_url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$output_file" "$download_url"
    else
        log_error "No download tool available"
        return 1
    fi
    
    # Verify download
    if [ -f "$output_file" ] && [ -s "$output_file" ]; then
        chmod +x "$output_file"
        return 0
    else
        log_error "Download verification failed"
        return 1
    fi
}

# Function to verify update integrity
verify_update() {
    local update_file="$1"
    
    if [ ! -f "$update_file" ]; then
        log_error "Update file not found: $update_file"
        return 1
    fi
    
    # Check if it's a valid AppImage
    if ! file "$update_file" | grep -q "ELF.*executable"; then
        log_error "Downloaded file is not a valid executable"
        return 1
    fi
    
    # Test if the AppImage can extract (basic integrity check)
    if ! timeout 30s "$update_file" --appimage-extract-and-run --version >/dev/null 2>&1; then
        log_warn "Update verification test failed, but file may still be valid"
    fi
    
    log_info "Update verification completed"
    return 0
}

# Function to apply update
apply_update() {
    if ! is_appimage; then
        log_error "Updates only supported when running as AppImage"
        return 1
    fi
    
    local latest_version=$(get_latest_version)
    local new_appimage="${UPDATE_CACHE_DIR}/BizSync-${latest_version}-x86_64.AppImage"
    
    if [ ! -f "$new_appimage" ]; then
        log_error "Update file not found: $new_appimage"
        return 1
    fi
    
    if ! verify_update "$new_appimage"; then
        log_error "Update verification failed"
        return 1
    fi
    
    # Create backup of current AppImage
    local backup_file="${APPIMAGE}.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "Creating backup: $backup_file"
    cp "${APPIMAGE}" "$backup_file"
    
    # Replace current AppImage
    log_update "Applying update..."
    if mv "$new_appimage" "${APPIMAGE}"; then
        log_update "Update applied successfully!"
        log_info "Backup available at: $backup_file"
        
        # Update last check timestamp
        echo "$(date +%s)" > "${UPDATE_CONFIG_DIR}/last_check"
        echo "$latest_version" > "${UPDATE_CONFIG_DIR}/current_version"
        
        # Restart application
        log_info "Restarting application with new version..."
        exec "${APPIMAGE}" "$@"
    else
        log_error "Failed to apply update"
        # Restore backup
        mv "$backup_file" "${APPIMAGE}"
        return 1
    fi
}

# Function to check if auto-update is due
is_update_check_due() {
    local last_check_file="${UPDATE_CONFIG_DIR}/last_check"
    
    if [ ! -f "$last_check_file" ]; then
        return 0  # First run
    fi
    
    local last_check=$(cat "$last_check_file" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    local time_diff=$((current_time - last_check))
    
    [ $time_diff -gt $UPDATE_CHECK_INTERVAL ]
}

# Function to perform background update check
background_update_check() {
    if ! is_appimage; then
        return 0  # Skip for development builds
    fi
    
    if ! is_update_check_due; then
        return 0  # Too soon for next check
    fi
    
    log_info "Performing background update check..."
    
    if check_update_available >/dev/null 2>&1; then
        # Update available - notify user
        create_update_notification
    fi
    
    # Update last check timestamp
    mkdir -p "$UPDATE_CONFIG_DIR"
    echo "$(date +%s)" > "${UPDATE_CONFIG_DIR}/last_check"
}

# Function to create update notification
create_update_notification() {
    local latest_version=$(get_latest_version)
    local notification_file="${UPDATE_CACHE_DIR}/update_available"
    
    cat > "$notification_file" << EOF
{
  "available": true,
  "version": "$latest_version",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "url": "${UPDATE_SERVER_URL}/BizSync-${latest_version}-x86_64.AppImage"
}
EOF
    
    log_info "Update notification created: $notification_file"
}

# Function to get update status
get_update_status() {
    local notification_file="${UPDATE_CACHE_DIR}/update_available"
    
    if [ -f "$notification_file" ]; then
        cat "$notification_file"
    else
        echo '{"available": false}'
    fi
}

# Function to configure auto-updates
configure_auto_updates() {
    local enabled="$1"
    local config_file="${UPDATE_CONFIG_DIR}/auto_update_config"
    
    mkdir -p "$UPDATE_CONFIG_DIR"
    
    cat > "$config_file" << EOF
{
  "enabled": $enabled,
  "check_interval": $UPDATE_CHECK_INTERVAL,
  "last_modified": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    
    log_info "Auto-update configuration saved: enabled=$enabled"
}

# Function to check if auto-updates are enabled
is_auto_update_enabled() {
    local config_file="${UPDATE_CONFIG_DIR}/auto_update_config"
    
    if [ -f "$config_file" ]; then
        grep -q '"enabled": *true' "$config_file"
    else
        return 0  # Default: enabled
    fi
}

# Function to clean up old update files
cleanup_updates() {
    log_info "Cleaning up old update files..."
    
    # Remove old backup files (keep only 3 most recent)
    if [ -d "$(dirname "${APPIMAGE}")" ]; then
        find "$(dirname "${APPIMAGE}")" -name "$(basename "${APPIMAGE}").backup.*" -type f | \
            sort -r | tail -n +4 | xargs rm -f 2>/dev/null || true
    fi
    
    # Clean update cache (files older than 7 days)
    if [ -d "$UPDATE_CACHE_DIR" ]; then
        find "$UPDATE_CACHE_DIR" -type f -mtime +7 -delete 2>/dev/null || true
    fi
    
    log_info "Update cleanup completed"
}

# Main function
main() {
    case "${1:-check}" in
        "check")
            check_update_available
            ;;
        "download")
            download_update
            ;;
        "apply")
            apply_update
            ;;
        "update")
            # Full update process
            if check_update_available; then
                if download_update; then
                    apply_update
                fi
            fi
            ;;
        "status")
            get_update_status
            ;;
        "configure")
            configure_auto_updates "${2:-true}"
            ;;
        "background")
            background_update_check
            ;;
        "cleanup")
            cleanup_updates
            ;;
        "info")
            echo "Update Manager Information:"
            echo "  Current Version: $(get_current_version)"
            echo "  AppImage Mode: $(is_appimage && echo 'Yes' || echo 'No')"
            echo "  Auto-updates: $(is_auto_update_enabled && echo 'Enabled' || echo 'Disabled')"
            echo "  Config Dir: $UPDATE_CONFIG_DIR"
            echo "  Cache Dir: $UPDATE_CACHE_DIR"
            if [ -f "${UPDATE_CONFIG_DIR}/last_check" ]; then
                local last_check=$(cat "${UPDATE_CONFIG_DIR}/last_check")
                echo "  Last Check: $(date -d "@$last_check" 2>/dev/null || echo 'Unknown')"
            fi
            ;;
        *)
            echo "Usage: $0 {check|download|apply|update|status|configure|background|cleanup|info}"
            echo ""
            echo "Commands:"
            echo "  check      Check if update is available"
            echo "  download   Download available update"
            echo "  apply      Apply downloaded update"
            echo "  update     Full update process (check + download + apply)"
            echo "  status     Show update status"
            echo "  configure  Configure auto-updates (true/false)"
            echo "  background Background update check"
            echo "  cleanup    Clean up old update files"
            echo "  info       Show update manager information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"