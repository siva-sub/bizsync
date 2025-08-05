#!/bin/bash

# BizSync Dependency Bundling Script
# This script ensures all necessary dependencies are included in the AppImage

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"
APPDIR="${PROJECT_ROOT}/appimage/AppDir"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to get library dependencies
get_dependencies() {
    local binary="$1"
    ldd "$binary" 2>/dev/null | grep -E "=>" | awk '{print $3}' | grep -v "^$" | sort | uniq
}

# Function to copy library with symlinks
copy_library() {
    local lib_path="$1"
    local dest_dir="$2"
    
    if [ -f "$lib_path" ]; then
        local lib_name=$(basename "$lib_path")
        local dest_path="$dest_dir/$lib_name" 
        
        # Remove existing file/symlink if it exists
        [ -e "$dest_path" ] && rm -f "$dest_path"
        [ -L "$dest_path" ] && rm -f "$dest_path"
        
        # Copy the actual library file
        cp -L "$lib_path" "$dest_path"
        
        # Handle symlinks
        local lib_dir=$(dirname "$lib_path")
        
        # Find and copy all related library versions
        local lib_base_name="${lib_name%%.*}"
        find "$lib_dir" -maxdepth 1 \( -name "${lib_base_name}*" -o -name "${lib_name%.*}*" \) 2>/dev/null | while read -r related_file; do
            local related_name=$(basename "$related_file")
            local dest_related="$dest_dir/$related_name"
            
            # Skip if it's the same file we already copied
            [ "$related_name" = "$lib_name" ] && continue
            
            # Remove existing file/symlink if it exists
            [ -e "$dest_related" ] && rm -f "$dest_related"
            [ -L "$dest_related" ] && rm -f "$dest_related"
            
            if [ -L "$related_file" ]; then
                # It's a symlink
                local symlink_target=$(readlink "$related_file")
                if [[ "$symlink_target" == /* ]]; then
                    # Absolute target, make it relative to the actual library file
                    local target_name=$(basename "$symlink_target")
                    ln -sf "$target_name" "$dest_related" 2>/dev/null || true
                else
                    # Relative target
                    ln -sf "$symlink_target" "$dest_related" 2>/dev/null || true
                fi
            elif [ -f "$related_file" ]; then
                # It's a regular file, copy it
                cp -L "$related_file" "$dest_related" 2>/dev/null || true
            fi
        done
    fi
}

# Function to bundle keybinder dependencies specifically
bundle_keybinder_deps() {
    log_info "Bundling keybinder3 dependencies..."
    
    local lib_dir="${APPDIR}/usr/lib"
    
    # Try to find keybinder library
    local keybinder_paths=(
        "/usr/lib/libkeybinder-3.0.so.0"
        "/usr/lib/x86_64-linux-gnu/libkeybinder-3.0.so.0"
        "/usr/local/lib/libkeybinder-3.0.so.0"
    )
    
    local keybinder_found=false
    for path in "${keybinder_paths[@]}"; do
        if [ -f "$path" ]; then
            log_info "Found keybinder library: $path"
            copy_library "$path" "$lib_dir"
            keybinder_found=true
            
            # Copy related dependencies
            local keybinder_deps=$(get_dependencies "$path")
            for dep in $keybinder_deps; do
                if [[ "$dep" == *"libX11"* ]] || [[ "$dep" == *"libxcb"* ]] || [[ "$dep" == *"libXau"* ]]; then
                    copy_library "$dep" "$lib_dir"
                fi
            done
            break
        fi
    done
    
    if [ "$keybinder_found" = false ]; then
        log_warn "Keybinder library not found - hotkey functionality may not work"
    fi
}

# Function to bundle Flutter dependencies
bundle_flutter_deps() {
    log_info "Bundling Flutter dependencies..."
    
    local main_binary="${APPDIR}/usr/bin/bizsync"
    local lib_dir="${APPDIR}/usr/lib"
    
    if [ ! -f "$main_binary" ]; then
        log_warn "Main binary not found: $main_binary"
        return 1
    fi
    
    # Get all dependencies
    log_info "Analyzing dependencies for main binary..."
    local deps=$(get_dependencies "$main_binary")
    
    # Additional Flutter engine libraries to bundle
    local flutter_libs=(
        "/usr/lib/libflutter_linux_gtk.so"
        "/usr/lib/x86_64-linux-gnu/libflutter_linux_gtk.so"
    )
    
    for flutter_lib in "${flutter_libs[@]}"; do
        if [ -f "$flutter_lib" ]; then
            copy_library "$flutter_lib" "$lib_dir"
        fi
    done
    
    # System libraries that should NOT be bundled (provided by base system)
    local exclude_libs=(
        "linux-vdso.so"
        "ld-linux-x86-64.so"
        "libc.so"
        "libdl.so"
        "libpthread.so"
        "libm.so"
        "librt.so"
        "libresolv.so"
        "libnsl.so"
        "libutil.so"
        "libcrypt.so"
        "/lib64/"
        "/lib/x86_64-linux-gnu/libc.so"
        "/lib/x86_64-linux-gnu/libdl.so"
        "/lib/x86_64-linux-gnu/libpthread.so"
        "/lib/x86_64-linux-gnu/libm.so"
        "/lib/x86_64-linux-gnu/librt.so"
    )
    
    # Copy dependencies
    for dep in $deps; do
        local should_exclude=false
        
        # Check if library should be excluded
        for exclude in "${exclude_libs[@]}"; do
            if [[ "$dep" == *"$exclude"* ]]; then
                should_exclude=true
                break
            fi
        done
        
        if [ "$should_exclude" = false ]; then
            log_info "Copying dependency: $(basename "$dep")"
            copy_library "$dep" "$lib_dir"
        else
            log_info "Excluding system library: $(basename "$dep")"
        fi
    done
}

# Function to bundle GTK themes and data
bundle_gtk_data() {
    log_info "Bundling GTK themes and data..."
    
    local share_dir="${APPDIR}/usr/share"
    
    # Copy GTK themes (subset)
    if [ -d "/usr/share/themes/Adwaita" ]; then
        mkdir -p "$share_dir/themes"
        cp -r "/usr/share/themes/Adwaita" "$share_dir/themes/" 2>/dev/null || true
    fi
    
    # Copy icons (subset)
    if [ -d "/usr/share/icons/Adwaita" ]; then
        mkdir -p "$share_dir/icons"
        cp -r "/usr/share/icons/Adwaita" "$share_dir/icons/" 2>/dev/null || true
    fi
    
    # Copy GLib schemas
    if [ -d "/usr/share/glib-2.0/schemas" ]; then
        mkdir -p "$share_dir/glib-2.0"
        cp -r "/usr/share/glib-2.0/schemas" "$share_dir/glib-2.0/" 2>/dev/null || true
        
        # Compile schemas
        if command -v glib-compile-schemas >/dev/null 2>&1; then
            glib-compile-schemas "$share_dir/glib-2.0/schemas/" 2>/dev/null || true
        fi
    fi
    
    # Copy font configuration
    if [ -d "/usr/share/fontconfig" ]; then
        mkdir -p "$share_dir/fontconfig"
        cp -r "/usr/share/fontconfig"/* "$share_dir/fontconfig/" 2>/dev/null || true
    fi
}

# Function to bundle Mesa drivers for hardware acceleration
bundle_mesa_drivers() {
    log_info "Bundling Mesa drivers..."
    
    local lib_dir="${APPDIR}/usr/lib"
    
    # Find Mesa DRI drivers
    local mesa_dirs=(
        "/usr/lib/x86_64-linux-gnu/dri"
        "/usr/lib/dri"
        "/usr/lib64/dri"
    )
    
    for mesa_dir in "${mesa_dirs[@]}"; do
        if [ -d "$mesa_dir" ]; then
            mkdir -p "$lib_dir/dri"
            cp "$mesa_dir"/*.so "$lib_dir/dri/" 2>/dev/null || true
            log_info "Copied Mesa drivers from $mesa_dir"
            break
        fi
    done
    
    # Copy VAAPI drivers if available
    local vaapi_dirs=(
        "/usr/lib/x86_64-linux-gnu/dri"
        "/usr/lib/dri"
    )
    
    for vaapi_dir in "${vaapi_dirs[@]}"; do
        if [ -d "$vaapi_dir" ]; then
            mkdir -p "$lib_dir/dri"
            cp "$vaapi_dir"/*vaapi*.so "$lib_dir/dri/" 2>/dev/null || true
        fi
    done
}

# Function to bundle GStreamer plugins (for multimedia)
bundle_gstreamer() {
    log_info "Bundling GStreamer plugins..."
    
    local lib_dir="${APPDIR}/usr/lib"
    
    # Find GStreamer plugins
    local gst_dirs=(
        "/usr/lib/x86_64-linux-gnu/gstreamer-1.0"
        "/usr/lib/gstreamer-1.0"
    )
    
    for gst_dir in "${gst_dirs[@]}"; do
        if [ -d "$gst_dir" ]; then
            mkdir -p "$lib_dir/gstreamer-1.0"
            # Copy essential plugins only
            cp "$gst_dir"/libgst{coreelements,typefindfunctions,playback,audioconvert,audioresample}.so "$lib_dir/gstreamer-1.0/" 2>/dev/null || true
            log_info "Copied essential GStreamer plugins from $gst_dir"
            break
        fi
    done
}

# Function to create library cache
create_lib_cache() {
    log_info "Creating library cache..."
    
    local lib_dir="${APPDIR}/usr/lib"
    
    # Create ld.so.cache equivalent
    cat > "$lib_dir/ld.so.conf" << EOF
/usr/lib
/usr/lib/x86_64-linux-gnu
EOF
    
    # Create GTK module cache
    if command -v gtk-query-immodules-3.0 >/dev/null 2>&1; then
        mkdir -p "${APPDIR}/usr/lib/gtk-3.0/3.0.0"
        gtk-query-immodules-3.0 > "${APPDIR}/usr/lib/gtk-3.0/3.0.0/immodules.cache" 2>/dev/null || true
    fi
}

# Function to strip binaries and libraries
strip_binaries() {
    log_info "Stripping binaries and libraries..."
    
    # Strip main binary
    strip "${APPDIR}/usr/bin/bizsync" 2>/dev/null || true
    
    # Strip libraries
    find "${APPDIR}/usr/lib" -name "*.so*" -type f -exec strip {} \; 2>/dev/null || true
    
    log_info "Stripping completed"
}

# Function to set proper permissions
set_permissions() {
    log_info "Setting proper permissions..."
    
    # Set executable permissions
    chmod +x "${APPDIR}/usr/bin"/*
    
    # Set library permissions
    find "${APPDIR}/usr/lib" -name "*.so*" -exec chmod 755 {} \;
    
    # Set data file permissions
    find "${APPDIR}/usr/share" -type f -exec chmod 644 {} \;
    find "${APPDIR}/usr/share" -type d -exec chmod 755 {} \;
}

# Function to validate bundling
validate_bundling() {
    log_info "Validating dependency bundling..."
    
    local main_binary="${APPDIR}/usr/bin/bizsync"
    local lib_dir="${APPDIR}/usr/lib"
    
    if [ ! -f "$main_binary" ]; then
        log_warn "Main binary not found for validation"
        return 1
    fi
    
    # Set library path for validation
    export LD_LIBRARY_PATH="${lib_dir}:${LD_LIBRARY_PATH}"
    
    # Check for missing dependencies
    local missing_deps=$(ldd "$main_binary" 2>/dev/null | grep "not found" || true)
    
    if [ -n "$missing_deps" ]; then
        log_warn "Missing dependencies found:"
        echo "$missing_deps"
        
        # Check if these are Flutter plugin libraries that should be in our lib directory
        local flutter_plugins_missing=false
        while IFS= read -r line; do
            if [[ "$line" == *"flutter"* ]] || [[ "$line" == *"plugin"* ]]; then
                flutter_plugins_missing=true
            fi
        done <<< "$missing_deps"
        
        if [ "$flutter_plugins_missing" = true ]; then
            log_info "Flutter plugin libraries detected in missing deps - this is normal"
            log_info "These should be available at runtime via LD_LIBRARY_PATH"
        fi
    else
        log_info "All dependencies satisfied"
    fi
    
    # Show bundled libraries count
    local lib_count=$(find "$lib_dir" -name "*.so*" -type f | wc -l)
    log_info "Bundled libraries: $lib_count"
    
    # List Flutter plugin libraries
    local flutter_libs=$(find "$lib_dir" -name "*plugin*.so" -o -name "*flutter*.so" | wc -l)
    log_info "Flutter plugin libraries: $flutter_libs"
    
    # Show AppDir size
    local appdir_size=$(du -sh "$APPDIR" | cut -f1)
    log_info "AppDir size: $appdir_size"
}

# Main function
main() {
    log_info "Starting dependency bundling process..."
    
    # Ensure AppDir structure exists
    mkdir -p "${APPDIR}/usr"/{bin,lib,share}
    
    # Bundle different types of dependencies
    bundle_flutter_deps
    bundle_keybinder_deps
    bundle_gtk_data
    bundle_mesa_drivers
    bundle_gstreamer
    create_lib_cache
    
    # Optimize
    strip_binaries
    set_permissions
    
    # Validate
    validate_bundling
    
    log_info "Dependency bundling completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    --flutter-only)
        bundle_flutter_deps
        ;;
    --gtk-only)
        bundle_gtk_data
        ;;
    --validate)
        validate_bundling
        ;;
    *)
        main
        ;;
esac