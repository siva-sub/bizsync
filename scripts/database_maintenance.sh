#!/bin/bash

# BizSync Database Maintenance Script
# Provides backup, restore, and health check functionality for database administrators
# Supports both Android and Linux environments

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DATABASE_NAME="bizsync.db"
BACKUP_DIR="$PROJECT_ROOT/backups"
LOG_FILE="$BACKUP_DIR/maintenance.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        "DEBUG")
            echo -e "${BLUE}[DEBUG]${NC} $message"
            ;;
    esac
    
    # Also log to file
    mkdir -p "$BACKUP_DIR"
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Platform detection
detect_platform() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Find database path
find_database_path() {
    local platform=$(detect_platform)
    local possible_paths=()
    
    case $platform in
        "linux")
            possible_paths=(
                "$HOME/Documents/$DATABASE_NAME"
                "$HOME/.local/share/bizsync/$DATABASE_NAME"
                "$PROJECT_ROOT/$DATABASE_NAME"
                "/tmp/bizsync_test/$DATABASE_NAME"
            )
            ;;
        "macos")
            possible_paths=(
                "$HOME/Documents/$DATABASE_NAME"
                "$HOME/Library/Application Support/bizsync/$DATABASE_NAME"
                "$PROJECT_ROOT/$DATABASE_NAME"
            )
            ;;
        "windows")
            possible_paths=(
                "$USERPROFILE/Documents/$DATABASE_NAME"
                "$APPDATA/bizsync/$DATABASE_NAME"
                "$PROJECT_ROOT/$DATABASE_NAME"
            )
            ;;
    esac
    
    for path in "${possible_paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# Create backup with retention policy
create_backup() {
    local db_path="$1"
    local backup_type="${2:-manual}"
    
    if [[ ! -f "$db_path" ]]; then
        log "ERROR" "Database file not found: $db_path"
        return 1
    fi
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_filename="${backup_type}_backup_${timestamp}.db"
    local backup_path="$BACKUP_DIR/$backup_filename"
    
    mkdir -p "$BACKUP_DIR"
    
    log "INFO" "Creating backup: $backup_filename"
    
    # Create backup with integrity check
    if sqlite3 "$db_path" ".backup '$backup_path'"; then
        log "INFO" "Backup created successfully: $backup_path"
        
        # Verify backup integrity
        if sqlite3 "$backup_path" "PRAGMA integrity_check;" | grep -q "ok"; then
            log "INFO" "Backup integrity verified"
            
            # Create metadata file
            cat > "$backup_path.meta" << EOF
{
    "backup_type": "$backup_type",
    "source_database": "$db_path",
    "backup_path": "$backup_path",
    "timestamp": "$timestamp",
    "platform": "$(detect_platform)",
    "file_size": $(stat -f%z "$backup_path" 2>/dev/null || stat -c%s "$backup_path" 2>/dev/null || echo "unknown"),
    "database_version": $(sqlite3 "$backup_path" "PRAGMA user_version;" 2>/dev/null || echo "unknown")
}
EOF
            
            # Apply retention policy (keep last 10 backups of each type)
            cleanup_old_backups "$backup_type"
            
            return 0
        else
            log "ERROR" "Backup integrity check failed"
            rm -f "$backup_path"
            return 1
        fi
    else
        log "ERROR" "Failed to create backup"
        return 1
    fi
}

# Cleanup old backups based on retention policy
cleanup_old_backups() {
    local backup_type="$1"
    local keep_count=10
    
    log "INFO" "Applying retention policy for $backup_type backups (keeping $keep_count)"
    
    # Find and sort backup files by modification time
    local backup_files=($(ls -t "$BACKUP_DIR"/${backup_type}_backup_*.db 2>/dev/null || true))
    
    if [[ ${#backup_files[@]} -gt $keep_count ]]; then
        for ((i=$keep_count; i<${#backup_files[@]}; i++)); do
            local old_backup="${backup_files[$i]}"
            log "INFO" "Removing old backup: $(basename "$old_backup")"
            rm -f "$old_backup" "$old_backup.meta"
        done
    fi
}

# Restore database from backup
restore_backup() {
    local backup_path="$1"
    local target_path="$2"
    
    if [[ ! -f "$backup_path" ]]; then
        log "ERROR" "Backup file not found: $backup_path"
        return 1
    fi
    
    log "INFO" "Restoring database from backup: $backup_path"
    
    # Verify backup integrity before restore
    if ! sqlite3 "$backup_path" "PRAGMA integrity_check;" | grep -q "ok"; then
        log "ERROR" "Cannot restore: backup file is corrupted"
        return 1
    fi
    
    # Create backup of current database if it exists
    if [[ -f "$target_path" ]]; then
        local current_backup="$BACKUP_DIR/pre_restore_backup_$(date '+%Y%m%d_%H%M%S').db"
        log "INFO" "Backing up current database before restore: $current_backup"
        cp "$target_path" "$current_backup"
    fi
    
    # Perform restore
    if cp "$backup_path" "$target_path"; then
        log "INFO" "Database restored successfully"
        
        # Verify restored database
        if sqlite3 "$target_path" "PRAGMA integrity_check;" | grep -q "ok"; then
            log "INFO" "Restored database integrity verified"
            return 0
        else
            log "ERROR" "Restored database failed integrity check"
            return 1
        fi
    else
        log "ERROR" "Failed to restore database"
        return 1
    fi
}

# Perform database health check
health_check() {
    local db_path="$1"
    
    if [[ ! -f "$db_path" ]]; then
        log "ERROR" "Database file not found: $db_path"
        return 1
    fi
    
    log "INFO" "Performing database health check: $db_path"
    
    local health_report="$BACKUP_DIR/health_report_$(date '+%Y%m%d_%H%M%S').txt"
    
    {
        echo "=== BizSync Database Health Report ==="
        echo "Timestamp: $(date)"
        echo "Database: $db_path"
        echo "Platform: $(detect_platform)"
        echo ""
        
        # Basic connectivity
        echo "=== Basic Connectivity ==="
        if sqlite3 "$db_path" "SELECT 1;" >/dev/null 2>&1; then
            echo "✅ Database accessible"
        else
            echo "❌ Database not accessible"
        fi
        echo ""
        
        # Integrity check
        echo "=== Integrity Check ==="
        local integrity_result=$(sqlite3 "$db_path" "PRAGMA integrity_check;")
        if [[ "$integrity_result" == "ok" ]]; then
            echo "✅ Database integrity: OK"
        else
            echo "❌ Database integrity: FAILED"
            echo "$integrity_result"
        fi
        echo ""
        
        # Schema information
        echo "=== Schema Information ==="
        echo "Database version: $(sqlite3 "$db_path" "PRAGMA user_version;" 2>/dev/null || echo "unknown")"
        echo "Page size: $(sqlite3 "$db_path" "PRAGMA page_size;" 2>/dev/null || echo "unknown")"
        echo "Page count: $(sqlite3 "$db_path" "PRAGMA page_count;" 2>/dev/null || echo "unknown")"
        echo ""
        
        # Table statistics
        echo "=== Table Statistics ==="
        local tables=(customers_crdt invoices_crdt products_crdt sync_metadata audit_trail)
        for table in "${tables[@]}"; do
            local count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "N/A")
            printf "%-20s: %s records\n" "$table" "$count"
        done
        echo ""
        
        # PRAGMA settings
        echo "=== PRAGMA Settings ==="
        echo "Journal mode: $(sqlite3 "$db_path" "PRAGMA journal_mode;" 2>/dev/null || echo "unknown")"
        echo "Synchronous: $(sqlite3 "$db_path" "PRAGMA synchronous;" 2>/dev/null || echo "unknown")"
        echo "Foreign keys: $(sqlite3 "$db_path" "PRAGMA foreign_keys;" 2>/dev/null || echo "unknown")"
        echo "Cache size: $(sqlite3 "$db_path" "PRAGMA cache_size;" 2>/dev/null || echo "unknown")"
        echo ""
        
        echo "=== End Report ==="
        
    } | tee "$health_report"
    
    log "INFO" "Health report saved: $health_report"
}

# List available backups
list_backups() {
    log "INFO" "Available backups:"
    echo ""
    
    if [[ -d "$BACKUP_DIR" ]]; then
        local backup_files=($(ls -t "$BACKUP_DIR"/*.db 2>/dev/null || true))
        
        if [[ ${#backup_files[@]} -eq 0 ]]; then
            log "WARN" "No backup files found"
            return 0
        fi
        
        printf "%-30s %-15s %-20s %-10s\n" "Backup File" "Type" "Date" "Size"
        echo "--------------------------------------------------------------------------------"
        
        for backup_file in "${backup_files[@]}"; do
            local filename=$(basename "$backup_file")
            local backup_type="unknown"
            local backup_date="unknown"
            local file_size="unknown"
            
            # Extract type from filename
            if [[ "$filename" =~ ^([^_]+)_backup_ ]]; then
                backup_type="${BASH_REMATCH[1]}"
            fi
            
            # Get file date and size
            backup_date=$(date -r "$backup_file" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown")
            file_size=$(du -h "$backup_file" 2>/dev/null | cut -f1 || echo "unknown")
            
            printf "%-30s %-15s %-20s %-10s\n" "$filename" "$backup_type" "$backup_date" "$file_size"
        done
    else
        log "WARN" "Backup directory does not exist: $BACKUP_DIR"
    fi
}

# Main menu
show_help() {
    cat << EOF
BizSync Database Maintenance Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    backup [TYPE]           Create a backup (default: manual)
    restore <backup_file>   Restore from backup
    health                  Perform health check
    list                    List available backups
    cleanup                 Clean up old backups
    monitor                 Continuous monitoring mode
    help                    Show this help message

Examples:
    $0 backup               # Create manual backup
    $0 backup scheduled     # Create scheduled backup
    $0 restore manual_backup_20231201_120000.db
    $0 health              # Run health check
    $0 list                # List all backups

Notes:
    - Backups are stored in: $BACKUP_DIR
    - Logs are written to: $LOG_FILE
    - Automatic retention policy keeps last 10 backups per type
EOF
}

# Main script logic
main() {
    local command="${1:-help}"
    
    case "$command" in
        "backup")
            local backup_type="${2:-manual}"
            local db_path=$(find_database_path)
            if [[ -n "$db_path" ]]; then
                create_backup "$db_path" "$backup_type"
            else
                log "ERROR" "Database file not found"
                exit 1
            fi
            ;;
        "restore")
            local backup_file="$2"
            if [[ -z "$backup_file" ]]; then
                log "ERROR" "Please specify backup file to restore"
                exit 1
            fi
            
            local backup_path="$BACKUP_DIR/$backup_file"
            local db_path=$(find_database_path)
            if [[ -z "$db_path" ]]; then
                log "ERROR" "Cannot determine target database path"
                exit 1
            fi
            
            restore_backup "$backup_path" "$db_path"
            ;;
        "health")
            local db_path=$(find_database_path)
            if [[ -n "$db_path" ]]; then
                health_check "$db_path"
            else
                log "ERROR" "Database file not found"
                exit 1
            fi
            ;;
        "list")
            list_backups
            ;;
        "cleanup")
            log "INFO" "Cleaning up old backups..."
            cleanup_old_backups "manual"
            cleanup_old_backups "scheduled"
            cleanup_old_backups "automatic"
            ;;
        "monitor")
            log "INFO" "Starting continuous monitoring mode (Ctrl+C to stop)"
            while true; do
                local db_path=$(find_database_path)
                if [[ -n "$db_path" ]]; then
                    health_check "$db_path" >/dev/null 2>&1
                    log "INFO" "Health check completed"
                else
                    log "WARN" "Database not found during monitoring"
                fi
                sleep 300  # Check every 5 minutes
            done
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Check dependencies
if ! command -v sqlite3 >/dev/null 2>&1; then
    log "ERROR" "sqlite3 is required but not installed"
    exit 1
fi

# Run main function
main "$@"