#!/bin/bash

# BizSync Version Manager
# Manages version updates across the project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC_FILE="$PROJECT_ROOT/pubspec.yaml"
CHANGELOG_FILE="$PROJECT_ROOT/CHANGELOG.md"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get current version from pubspec.yaml
get_current_version() {
    grep "^version:" "$PUBSPEC_FILE" | sed 's/version: //' | sed 's/+.*//'
}

# Get current build number from pubspec.yaml
get_current_build() {
    grep "^version:" "$PUBSPEC_FILE" | sed 's/.*+//'
}

# Update version in pubspec.yaml
update_pubspec_version() {
    local new_version="$1"
    local new_build="$2"
    
    # Create backup
    cp "$PUBSPEC_FILE" "$PUBSPEC_FILE.backup"
    
    # Update version
    sed -i "s/^version:.*/version: $new_version+$new_build/" "$PUBSPEC_FILE"
    
    log_success "Updated pubspec.yaml version to $new_version+$new_build"
}

# Update changelog
update_changelog() {
    local version="$1"
    local date="$2"
    
    # Create backup
    cp "$CHANGELOG_FILE" "$CHANGELOG_FILE.backup"
    
    # Replace [Unreleased] with version and date
    sed -i "s/## \[Unreleased\]/## [$version] - $date/" "$CHANGELOG_FILE"
    
    # Add new unreleased section
    sed -i "/## \[$version\] - $date/i ## [Unreleased]\n\n### Added\n- \n\n### Changed\n- \n\n### Fixed\n- \n\n### Security\n- \n" "$CHANGELOG_FILE"
    
    log_success "Updated CHANGELOG.md for version $version"
}

# Validate version format (semver)
validate_version() {
    local version="$1"
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid version format. Use semantic versioning (e.g., 1.0.0)"
        return 1
    fi
    return 0
}

# Compare versions
version_greater() {
    local current="$1"
    local new="$2"
    
    # Convert versions to comparable format
    current_num=$(echo "$current" | sed 's/\./ /g' | awk '{printf "%03d%03d%03d\n", $1, $2, $3}')
    new_num=$(echo "$new" | sed 's/\./ /g' | awk '{printf "%03d%03d%03d\n", $1, $2, $3}')
    
    [ "$new_num" -gt "$current_num" ]
}

# Show current version info
show_current_version() {
    local current_version=$(get_current_version)
    local current_build=$(get_current_build)
    
    echo
    log_info "Current Version Information:"
    echo "  Version: $current_version"
    echo "  Build:   $current_build"
    echo "  Full:    $current_version+$current_build"
    echo
}

# Increment version automatically
increment_version() {
    local type="$1"
    local current_version=$(get_current_version)
    
    IFS='.' read -ra VERSION_PARTS <<< "$current_version"
    local major="${VERSION_PARTS[0]}"
    local minor="${VERSION_PARTS[1]}"
    local patch="${VERSION_PARTS[2]}"
    
    case "$type" in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "patch")
            patch=$((patch + 1))
            ;;
        *)
            log_error "Invalid increment type. Use: major, minor, or patch"
            return 1
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# Create release tag
create_release_tag() {
    local version="$1"
    local message="$2"
    
    log_info "Creating git tag for version $version..."
    
    # Check if tag already exists
    if git tag -l | grep -q "^v$version$"; then
        log_error "Tag v$version already exists"
        return 1
    fi
    
    # Create tag
    git tag -a "v$version" -m "$message"
    log_success "Created tag v$version"
    
    log_info "To push the tag, run: git push origin v$version"
}

# Generate release notes
generate_release_notes() {
    local version="$1"
    local output_file="$PROJECT_ROOT/.github/RELEASE_TEMPLATE/release_notes_v$version.md"
    local template_file="$PROJECT_ROOT/.github/RELEASE_TEMPLATE/release_notes_template.md"
    
    if [ ! -f "$template_file" ]; then
        log_error "Release notes template not found at $template_file"
        return 1
    fi
    
    # Copy template and replace placeholders
    cp "$template_file" "$output_file"
    
    # Replace placeholders
    local current_date=$(date +"%Y-%m-%d")
    local build_number=$(get_current_build)
    
    sed -i "s/{{VERSION}}/$version/g" "$output_file"
    sed -i "s/{{RELEASE_DATE}}/$current_date/g" "$output_file"
    sed -i "s/{{BUILD_NUMBER}}/$build_number/g" "$output_file"
    
    log_success "Generated release notes at $output_file"
    log_info "Please edit the release notes before publishing"
}

# Main command handlers
cmd_show() {
    show_current_version
}

cmd_bump() {
    local type="${1:-patch}"
    
    local current_version=$(get_current_version)
    local current_build=$(get_current_build)
    local new_version=$(increment_version "$type")
    local new_build=$((current_build + 1))
    
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    log_info "Bumping version from $current_version to $new_version"
    log_info "Incrementing build from $current_build to $new_build"
    
    # Update files
    update_pubspec_version "$new_version" "$new_build"
    update_changelog "$new_version" "$(date +%Y-%m-%d)"
    
    log_success "Version bumped successfully!"
    echo
    log_info "Next steps:"
    echo "  1. Review and edit CHANGELOG.md"
    echo "  2. Commit changes: git commit -am 'Bump version to $new_version'"
    echo "  3. Create tag: $0 tag $new_version"
    echo "  4. Push changes: git push && git push --tags"
}

cmd_set() {
    local new_version="$1"
    
    if [ -z "$new_version" ]; then
        log_error "Version required. Usage: $0 set <version>"
        exit 1
    fi
    
    if ! validate_version "$new_version"; then
        exit 1
    fi
    
    local current_version=$(get_current_version)
    
    if ! version_greater "$current_version" "$new_version"; then
        log_warning "New version $new_version is not greater than current version $current_version"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Version update cancelled"
            exit 0
        fi
    fi
    
    local current_build=$(get_current_build)
    local new_build=$((current_build + 1))
    
    log_info "Setting version to $new_version"
    
    # Update files
    update_pubspec_version "$new_version" "$new_build"
    update_changelog "$new_version" "$(date +%Y-%m-%d)"
    
    log_success "Version set successfully!"
}

cmd_tag() {
    local version="${1:-$(get_current_version)}"
    local message="Release version $version"
    
    create_release_tag "$version" "$message"
}

cmd_release() {
    local version="${1:-$(get_current_version)}"
    
    log_info "Preparing release for version $version"
    
    # Generate release notes
    generate_release_notes "$version"
    
    # Create tag
    create_release_tag "$version" "Release version $version"
    
    log_success "Release prepared for version $version"
    echo
    log_info "Next steps:"
    echo "  1. Edit release notes in .github/RELEASE_TEMPLATE/release_notes_v$version.md"
    echo "  2. Push tag: git push origin v$version"
    echo "  3. Create GitHub release using the generated notes"
}

cmd_help() {
    echo "BizSync Version Manager"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  show                    Show current version information"
    echo "  bump [major|minor|patch] Increment version (default: patch)"
    echo "  set <version>           Set specific version"
    echo "  tag [version]           Create git tag for version"
    echo "  release [version]       Prepare release (generate notes + tag)"
    echo "  help                    Show this help message"
    echo
    echo "Examples:"
    echo "  $0 show                 # Show current version"
    echo "  $0 bump minor           # Bump minor version (1.0.0 -> 1.1.0)"
    echo "  $0 set 2.0.0            # Set version to 2.0.0"
    echo "  $0 tag                  # Create tag for current version"
    echo "  $0 release 1.0.0        # Prepare release for 1.0.0"
    echo
}

# Main script logic
main() {
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 1
    fi
    
    # Check if required files exist
    if [ ! -f "$PUBSPEC_FILE" ]; then
        log_error "pubspec.yaml not found at $PUBSPEC_FILE"
        exit 1
    fi
    
    if [ ! -f "$CHANGELOG_FILE" ]; then
        log_error "CHANGELOG.md not found at $CHANGELOG_FILE"
        exit 1
    fi
    
    local command="${1:-help}"
    
    case "$command" in
        "show")
            cmd_show
            ;;
        "bump")
            cmd_bump "${2:-patch}"
            ;;
        "set")
            cmd_set "$2"
            ;;
        "tag")
            cmd_tag "$2"
            ;;
        "release")
            cmd_release "$2"
            ;;
        "help"|"-h"|"--help")
            cmd_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo
            cmd_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"