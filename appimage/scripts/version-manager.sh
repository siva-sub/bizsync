#!/bin/bash

# BizSync Version Management Script
# Manages versioning, metadata, and release information for AppImage builds

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"
PUBSPEC_FILE="${PROJECT_ROOT}/pubspec.yaml"
APPDIR="${PROJECT_ROOT}/appimage/AppDir"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_version() {
    echo -e "${BLUE}[VERSION]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to get current version from pubspec.yaml
get_current_version() {
    if [ -f "$PUBSPEC_FILE" ]; then
        grep "^version:" "$PUBSPEC_FILE" | sed 's/version: *//' | tr -d ' '
    else
        echo "1.0.0+1"
    fi
}

# Function to parse version components
parse_version() {
    local version="$1"
    local version_part=$(echo "$version" | cut -d'+' -f1)
    local build_part=$(echo "$version" | cut -d'+' -f2)
    
    local major=$(echo "$version_part" | cut -d'.' -f1)
    local minor=$(echo "$version_part" | cut -d'.' -f2)
    local patch=$(echo "$version_part" | cut -d'.' -f3)
    
    echo "$major" "$minor" "$patch" "$build_part"
}

# Function to increment version
increment_version() {
    local current_version="$1"
    local increment_type="$2"
    
    read -r major minor patch build <<< $(parse_version "$current_version")
    
    case "$increment_type" in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            build=$((build + 1))
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            build=$((build + 1))
            ;;
        "patch")
            patch=$((patch + 1))
            build=$((build + 1))
            ;;
        "build")
            build=$((build + 1))
            ;;
        *)
            log_warn "Unknown increment type: $increment_type"
            return 1
            ;;
    esac
    
    echo "${major}.${minor}.${patch}+${build}"
}

# Function to update pubspec.yaml
update_pubspec_version() {
    local new_version="$1"
    
    if [ -f "$PUBSPEC_FILE" ]; then
        # Create backup
        cp "$PUBSPEC_FILE" "${PUBSPEC_FILE}.backup"
        
        # Update version
        sed -i "s/^version:.*/version: $new_version/" "$PUBSPEC_FILE"
        
        log_info "Updated pubspec.yaml version to: $new_version"
    else
        log_warn "pubspec.yaml not found at: $PUBSPEC_FILE"
        return 1
    fi
}

# Function to update desktop files
update_desktop_files() {
    local version="$1"
    local version_part=$(echo "$version" | cut -d'+' -f1)
    
    # Update main desktop file
    local desktop_files=(
        "${APPDIR}/bizsync.desktop"
        "${APPDIR}/usr/share/applications/bizsync.desktop"
    )
    
    for desktop_file in "${desktop_files[@]}"; do
        if [ -f "$desktop_file" ]; then
            sed -i "s/X-AppImage-Version=.*/X-AppImage-Version=$version_part/" "$desktop_file"
            log_info "Updated desktop file: $(basename "$desktop_file")"
        fi
    done
}

# Function to update AppStream metadata
update_appstream_metadata() {
    local version="$1"
    local version_part=$(echo "$version" | cut -d'+' -f1)
    local date=$(date -I)
    
    local metainfo_file="${APPDIR}/usr/share/metainfo/com.bizsync.app.appdata.xml"
    
    if [ -f "$metainfo_file" ]; then
        # Update version in release tag
        sed -i "s/<release version=\"[^\"]*\"/<release version=\"$version_part\"/" "$metainfo_file"
        sed -i "s/date=\"[^\"]*\"/date=\"$date\"/" "$metainfo_file"
        
        log_info "Updated AppStream metadata version to: $version_part"
    fi
}

# Function to create changelog entry
create_changelog_entry() {
    local version="$1"
    local date=$(date '+%Y-%m-%d')
    local changelog_file="${PROJECT_ROOT}/CHANGELOG.md"
    
    # Create changelog if it doesn't exist
    if [ ! -f "$changelog_file" ]; then
        cat > "$changelog_file" << EOF
# Changelog

All notable changes to BizSync will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

EOF
    fi
    
    # Add new entry at the top (after the header)
    local temp_file=$(mktemp)
    local version_part=$(echo "$version" | cut -d'+' -f1)
    
    # Read existing changelog
    head -n 5 "$changelog_file" > "$temp_file"
    
    # Add new version entry
    cat >> "$temp_file" << EOF
## [$version_part] - $date

### Added
- New features and enhancements

### Changed
- Improvements and modifications

### Fixed
- Bug fixes and corrections

### Security
- Security improvements

EOF
    
    # Add rest of changelog
    tail -n +6 "$changelog_file" >> "$temp_file"
    
    # Replace original
    mv "$temp_file" "$changelog_file"
    
    log_info "Created changelog entry for version: $version_part"
}

# Function to create build metadata
create_build_metadata() {
    local version="$1"
    local build_dir="${PROJECT_ROOT}/appimage/build"
    local metadata_file="${build_dir}/build_metadata.json"
    
    mkdir -p "$build_dir"
    
    local version_part=$(echo "$version" | cut -d'+' -f1)
    local build_part=$(echo "$version" | cut -d'+' -f2)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    
    cat > "$metadata_file" << EOF
{
  "version": "$version_part",
  "build_number": "$build_part",
  "full_version": "$version",
  "build_timestamp": "$timestamp",
  "git_commit": "$commit_hash",
  "git_branch": "$branch",
  "build_type": "release",
  "target_platform": "linux",
  "architecture": "x86_64",
  "flutter_version": "$(flutter --version | head -n1 | cut -d' ' -f2 2>/dev/null || echo 'unknown')",
  "dart_version": "$(dart --version 2>&1 | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1 || echo 'unknown')"
}
EOF
    
    log_info "Created build metadata: $metadata_file"
}

# Function to show current version info
show_version_info() {
    local current_version=$(get_current_version)
    read -r major minor patch build <<< $(parse_version "$current_version")
    
    log_version "Current Version Information:"
    log_version "  Full Version: $current_version"
    log_version "  Major: $major"
    log_version "  Minor: $minor"
    log_version "  Patch: $patch"
    log_version "  Build: $build"
    
    if command -v git >/dev/null 2>&1; then
        local commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        local branch=$(git branch --show-current 2>/dev/null || echo "unknown")
        log_version "  Git Commit: $commit_hash"
        log_version "  Git Branch: $branch"
    fi
}

# Function to validate version format
validate_version() {
    local version="$1"
    
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
        log_warn "Invalid version format: $version"
        log_warn "Expected format: MAJOR.MINOR.PATCH+BUILD (e.g., 1.2.0+3)"
        return 1
    fi
    
    return 0
}

# Function to set custom version
set_version() {
    local new_version="$1"
    
    if ! validate_version "$new_version"; then
        return 1
    fi
    
    update_pubspec_version "$new_version"
    update_desktop_files "$new_version"
    update_appstream_metadata "$new_version"
    create_build_metadata "$new_version"
    
    log_info "Version updated to: $new_version"
}

# Function to bump version
bump_version() {
    local increment_type="$1"
    local current_version=$(get_current_version)
    local new_version=$(increment_version "$current_version" "$increment_type")
    
    if [ $? -eq 0 ]; then
        set_version "$new_version"
        create_changelog_entry "$new_version"
        
        log_info "Version bumped from $current_version to $new_version"
    else
        return 1
    fi
}

# Function to prepare release
prepare_release() {
    local version_type="${1:-patch}"
    
    log_info "Preparing release with $version_type version bump..."
    
    # Bump version
    bump_version "$version_type"
    
    # Create git tag if in git repository
    if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
        local new_version=$(get_current_version)
        local version_part=$(echo "$new_version" | cut -d'+' -f1)
        local tag_name="v$version_part"
        
        log_info "Creating git tag: $tag_name"
        git tag -a "$tag_name" -m "Release version $version_part" 2>/dev/null || log_warn "Failed to create git tag"
    fi
    
    log_info "Release preparation completed!"
}

# Main function
main() {
    case "${1:-info}" in
        "info"|"show")
            show_version_info
            ;;
        "bump")
            bump_version "${2:-patch}"
            ;;
        "set")
            if [ -z "$2" ]; then
                log_warn "Please provide a version to set (e.g., 1.2.0+3)"
                exit 1
            fi
            set_version "$2"
            ;;
        "major")
            bump_version "major"
            ;;
        "minor")
            bump_version "minor"
            ;;
        "patch")
            bump_version "patch"
            ;;
        "build")
            bump_version "build"
            ;;
        "release")
            prepare_release "${2:-patch}"
            ;;
        "metadata")
            local current_version=$(get_current_version)
            create_build_metadata "$current_version"
            ;;
        *)
            echo "Usage: $0 {info|bump|set|major|minor|patch|build|release|metadata} [VERSION]"
            echo ""
            echo "Commands:"
            echo "  info          Show current version information"
            echo "  bump [TYPE]   Bump version (patch|minor|major|build)"
            echo "  set VERSION   Set specific version (e.g., 1.2.0+3)"
            echo "  major         Bump major version"
            echo "  minor         Bump minor version"
            echo "  patch         Bump patch version"
            echo "  build         Bump build number only"
            echo "  release [TYPE] Prepare release with version bump"
            echo "  metadata      Create build metadata file"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"