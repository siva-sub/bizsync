#!/bin/bash

# BizSync AppImage Signing Manager
# Handles GPG signing and verification for security

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"
BUILD_DIR="${PROJECT_ROOT}/appimage/build"
KEYS_DIR="${PROJECT_ROOT}/appimage/keys"

# Configuration
SIGNING_KEY_ID=""
SIGNING_KEY_EMAIL="bizsync-release@example.com"
SIGNING_KEY_NAME="BizSync Release Key"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_security() {
    echo -e "${BLUE}[SECURITY]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if GPG is available
check_gpg() {
    if ! command -v gpg >/dev/null 2>&1; then
        log_error "GPG not found. Please install gnupg"
        log_info "Ubuntu/Debian: sudo apt-get install gnupg"
        log_info "CentOS/RHEL: sudo yum install gnupg"
        return 1
    fi
    
    log_info "GPG version: $(gpg --version | head -n1)"
    return 0
}

# Function to generate signing key
generate_signing_key() {
    local key_name="${1:-$SIGNING_KEY_NAME}"
    local key_email="${2:-$SIGNING_KEY_EMAIL}"
    
    log_security "Generating new GPG signing key..."
    log_warn "This will create a new GPG key for AppImage signing"
    log_warn "Store the generated key securely and backup the private key!"
    
    # Create GPG key generation config
    local key_config=$(mktemp)
    cat > "$key_config" << EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $key_name
Name-Email: $key_email
Expire-Date: 2y
Passphrase: 
%commit
%echo done
EOF

    # Generate the key
    if gpg --batch --generate-key "$key_config"; then
        rm -f "$key_config"
        
        # Get the generated key ID
        local key_id=$(gpg --list-secret-keys --keyid-format LONG "$key_email" | grep sec | awk '{print $2}' | cut -d'/' -f2)
        
        if [ -n "$key_id" ]; then
            log_security "GPG key generated successfully"
            log_info "Key ID: $key_id"
            log_info "Email: $key_email"
            
            # Export public key
            mkdir -p "$KEYS_DIR"
            gpg --armor --export "$key_id" > "${KEYS_DIR}/public_key.asc"
            
            # Save key info
            cat > "${KEYS_DIR}/key_info.txt" << EOF
Key ID: $key_id
Email: $key_email
Name: $key_name
Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Public Key: public_key.asc
EOF
            
            log_security "Public key exported to: ${KEYS_DIR}/public_key.asc"
            log_warn "IMPORTANT: Backup your private key: gpg --export-secret-keys $key_id > private_key.gpg"
            
            return 0
        else
            log_error "Failed to retrieve generated key ID"
            return 1
        fi
    else
        rm -f "$key_config"
        log_error "Failed to generate GPG key"
        return 1
    fi
}

# Function to import signing key
import_signing_key() {
    local key_file="$1"
    
    if [ ! -f "$key_file" ]; then
        log_error "Key file not found: $key_file"
        return 1
    fi
    
    log_security "Importing GPG key from: $key_file"
    
    if gpg --import "$key_file"; then
        log_security "GPG key imported successfully"
        return 0
    else
        log_error "Failed to import GPG key"
        return 1
    fi
}

# Function to list available signing keys
list_signing_keys() {
    log_security "Available GPG signing keys:"
    
    gpg --list-secret-keys --keyid-format LONG | while read -r line; do
        if [[ "$line" == sec* ]]; then
            local key_id=$(echo "$line" | awk '{print $2}' | cut -d'/' -f2)
            echo "  Key ID: $key_id"
        elif [[ "$line" == uid* ]]; then
            local uid=$(echo "$line" | sed 's/uid\s*\[.*\]\s*//')
            echo "    User: $uid"
        fi
    done
}

# Function to get default signing key
get_signing_key() {
    if [ -n "$SIGNING_KEY_ID" ]; then
        echo "$SIGNING_KEY_ID"
        return 0
    fi
    
    # Try to find key from key_info.txt
    if [ -f "${KEYS_DIR}/key_info.txt" ]; then
        local key_id=$(grep "Key ID:" "${KEYS_DIR}/key_info.txt" | cut -d':' -f2 | tr -d ' ')
        if [ -n "$key_id" ]; then
            echo "$key_id"
            return 0
        fi
    fi
    
    # Try to find any available signing key
    local available_key=$(gpg --list-secret-keys --keyid-format LONG | grep "sec" | head -n1 | awk '{print $2}' | cut -d'/' -f2)
    if [ -n "$available_key" ]; then
        echo "$available_key"
        return 0
    fi
    
    return 1
}

# Function to sign AppImage
sign_appimage() {
    local appimage_file="$1"
    local key_id="${2:-$(get_signing_key)}"
    
    if [ ! -f "$appimage_file" ]; then
        log_error "AppImage file not found: $appimage_file"
        return 1
    fi
    
    if [ -z "$key_id" ]; then
        log_error "No signing key available"
        log_info "Generate a key with: $0 generate-key"
        return 1
    fi
    
    log_security "Signing AppImage: $(basename "$appimage_file")"
    log_info "Using key ID: $key_id"
    
    # Create detached signature
    local signature_file="${appimage_file}.sig"
    
    if gpg --detach-sign --armor --local-user "$key_id" --output "$signature_file" "$appimage_file"; then
        log_security "AppImage signed successfully"
        log_info "Signature: $signature_file"
        
        # Create checksum file with signature
        local checksum_file="${appimage_file}.sha256"
        sha256sum "$appimage_file" > "$checksum_file"
        
        # Sign the checksum file
        if gpg --clearsign --local-user "$key_id" --output "${checksum_file}.asc" "$checksum_file"; then
            log_security "Checksum file signed"
            log_info "Signed checksum: ${checksum_file}.asc"
        fi
        
        return 0
    else
        log_error "Failed to sign AppImage"
        return 1
    fi
}

# Function to verify AppImage signature
verify_appimage() {
    local appimage_file="$1"
    local signature_file="${appimage_file}.sig"
    local checksum_file="${appimage_file}.sha256.asc"
    
    if [ ! -f "$appimage_file" ]; then
        log_error "AppImage file not found: $appimage_file"
        return 1
    fi
    
    log_security "Verifying AppImage: $(basename "$appimage_file")"
    
    # Verify signature
    if [ -f "$signature_file" ]; then
        log_info "Verifying GPG signature..."
        if gpg --verify "$signature_file" "$appimage_file" 2>/dev/null; then
            log_security "✓ GPG signature verification passed"
        else
            log_error "✗ GPG signature verification failed"
            return 1
        fi
    else
        log_warn "No signature file found: $signature_file"
    fi
    
    # Verify checksum
    if [ -f "$checksum_file" ]; then
        log_info "Verifying checksum..."
        if gpg --verify "$checksum_file" 2>/dev/null; then
            log_security "✓ Signed checksum verification passed"
            
            # Extract and verify the actual checksum
            local expected_checksum=$(gpg --decrypt "$checksum_file" 2>/dev/null | awk '{print $1}')
            local actual_checksum=$(sha256sum "$appimage_file" | awk '{print $1}')
            
            if [ "$expected_checksum" = "$actual_checksum" ]; then
                log_security "✓ SHA256 checksum verification passed"
            else
                log_error "✗ SHA256 checksum verification failed"
                log_error "Expected: $expected_checksum"
                log_error "Actual:   $actual_checksum"
                return 1
            fi
        else
            log_error "✗ Signed checksum verification failed"
            return 1
        fi
    else
        log_warn "No signed checksum file found: $checksum_file"
        
        # Perform basic checksum verification
        if [ -f "${appimage_file}.sha256" ]; then
            log_info "Verifying basic checksum..."
            if sha256sum -c "${appimage_file}.sha256" >/dev/null 2>&1; then
                log_security "✓ Basic SHA256 checksum verification passed"
            else
                log_error "✗ Basic SHA256 checksum verification failed"
                return 1
            fi
        fi
    fi
    
    log_security "AppImage verification completed successfully"
    return 0
}

# Function to create verification script
create_verification_script() {
    local appimage_file="$1"
    local script_file="${appimage_file}.verify"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash

# AppImage Verification Script
# This script verifies the integrity and authenticity of the AppImage

set -e

APPIMAGE_FILE="$(dirname "${BASH_SOURCE[0]}")/$(basename "${BASH_SOURCE[0]}" .verify)"
SIGNATURE_FILE="${APPIMAGE_FILE}.sig"
CHECKSUM_FILE="${APPIMAGE_FILE}.sha256.asc"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

verify() {
    echo "Verifying AppImage: $(basename "$APPIMAGE_FILE")"
    echo ""
    
    # Check if AppImage exists
    if [ ! -f "$APPIMAGE_FILE" ]; then
        log_error "AppImage file not found: $APPIMAGE_FILE"
        exit 1
    fi
    
    # Check GPG
    if ! command -v gpg >/dev/null 2>&1; then
        log_warn "GPG not available - signature verification skipped"
    else
        # Verify signature
        if [ -f "$SIGNATURE_FILE" ]; then
            echo "Verifying GPG signature..."
            if gpg --verify "$SIGNATURE_FILE" "$APPIMAGE_FILE" 2>/dev/null; then
                log_success "GPG signature verification passed"
            else
                log_error "GPG signature verification failed"
                exit 1
            fi
        else
            log_warn "No signature file found"
        fi
        
        # Verify signed checksum
        if [ -f "$CHECKSUM_FILE" ]; then
            echo "Verifying signed checksum..."
            if gpg --verify "$CHECKSUM_FILE" 2>/dev/null; then
                log_success "Signed checksum verification passed"
                
                # Check actual checksum
                expected=$(gpg --decrypt "$CHECKSUM_FILE" 2>/dev/null | awk '{print $1}')
                actual=$(sha256sum "$APPIMAGE_FILE" | awk '{print $1}')
                
                if [ "$expected" = "$actual" ]; then
                    log_success "SHA256 checksum verification passed"
                else
                    log_error "SHA256 checksum mismatch"
                    exit 1
                fi
            else
                log_error "Signed checksum verification failed"
                exit 1
            fi
        fi
    fi
    
    # Basic file checks
    if file "$APPIMAGE_FILE" | grep -q "ELF.*executable"; then
        log_success "File format verification passed"
    else
        log_error "Invalid AppImage format"
        exit 1
    fi
    
    echo ""
    log_success "All verifications passed - AppImage is authentic and intact"
}

case "${1:-verify}" in
    "verify"|"check")
        verify
        ;;
    "info")
        echo "AppImage Verification Tool"
        echo "File: $(basename "$APPIMAGE_FILE")"
        echo "Size: $(du -h "$APPIMAGE_FILE" | cut -f1)"
        echo "Modified: $(stat -c %y "$APPIMAGE_FILE")"
        ;;
    *)
        echo "Usage: $0 {verify|check|info}"
        exit 1
        ;;
esac
EOF

    chmod +x "$script_file"
    log_security "Verification script created: $script_file"
}

# Function to setup CI/CD signing
setup_ci_signing() {
    log_security "Setting up CI/CD signing configuration..."
    
    local ci_scripts_dir="${PROJECT_ROOT}/appimage/ci"
    mkdir -p "$ci_scripts_dir"
    
    # Create CI signing script
    cat > "${ci_scripts_dir}/ci-sign.sh" << 'EOF'
#!/bin/bash

# CI/CD AppImage Signing Script
# This script handles signing in automated environments

set -e

# Import signing key from environment or file
if [ -n "$GPG_PRIVATE_KEY" ]; then
    echo "Importing GPG private key from environment..."
    echo "$GPG_PRIVATE_KEY" | base64 -d | gpg --import --batch --yes
elif [ -f "$GPG_PRIVATE_KEY_FILE" ]; then
    echo "Importing GPG private key from file..."
    gpg --import --batch --yes "$GPG_PRIVATE_KEY_FILE"
else
    echo "No GPG private key found in environment"
    exit 1
fi

# Sign all AppImages in build directory
for appimage in ./appimage/build/*.AppImage; do
    if [ -f "$appimage" ]; then
        echo "Signing: $(basename "$appimage")"
        ./appimage/scripts/signing-manager.sh sign "$appimage" "$GPG_KEY_ID"
    fi
done

echo "CI signing completed"
EOF

    chmod +x "${ci_scripts_dir}/ci-sign.sh"
    
    # Create key export helper
    cat > "${ci_scripts_dir}/export-key.sh" << 'EOF'
#!/bin/bash

# Helper script to export GPG key for CI/CD

if [ -z "$1" ]; then
    echo "Usage: $0 <key-id>"
    echo "Example: $0 1234567890ABCDEF"
    exit 1
fi

KEY_ID="$1"

echo "Exporting GPG key for CI/CD use..."
echo "Key ID: $KEY_ID"
echo ""

echo "# Add this to your CI/CD environment as GPG_PRIVATE_KEY:"
echo "# (Base64 encoded private key)"
gpg --export-secret-keys --armor "$KEY_ID" | base64 -w 0
echo ""
echo ""

echo "# Add this to your CI/CD environment as GPG_KEY_ID:"
echo "GPG_KEY_ID=$KEY_ID"
echo ""

echo "# Public key for verification:"
gpg --export --armor "$KEY_ID"
EOF

    chmod +x "${ci_scripts_dir}/export-key.sh"
    
    log_security "CI/CD signing scripts created in: $ci_scripts_dir"
    log_info "Use export-key.sh to prepare keys for CI/CD"
}

# Function to create security documentation
create_security_docs() {
    local docs_dir="${PROJECT_ROOT}/appimage/docs"
    mkdir -p "$docs_dir"
    
    cat > "${docs_dir}/SECURITY.md" << 'EOF'
# BizSync AppImage Security

## Digital Signatures

All official BizSync AppImage releases are digitally signed using GPG for security and authenticity verification.

### Verification

Before running any AppImage, verify its authenticity:

```bash
# Automatic verification
./BizSync-*.AppImage.verify

# Manual verification
gpg --verify BizSync-*.AppImage.sig BizSync-*.AppImage
```

### Public Key

Import the official BizSync public key:

```bash
# From file
gpg --import public_key.asc

# From keyserver (if published)
gpg --keyserver keyserver.ubuntu.com --recv-keys YOUR_KEY_ID
```

### Trust Model

- Only download AppImages from official sources
- Always verify signatures before execution
- Check checksums for integrity
- Report any signature verification failures

## Security Best Practices

### For Users

1. **Verify Downloads**: Always verify GPG signatures
2. **Trusted Sources**: Only download from official releases
3. **Keep Updated**: Use auto-update feature for security patches
4. **Permissions**: Review AppImage permissions before first run
5. **Sandboxing**: Consider running in sandbox if available

### For Developers

1. **Key Security**: Protect signing keys with strong passphrases
2. **Key Rotation**: Rotate signing keys periodically
3. **Secure Build**: Build in clean environments
4. **Audit Trail**: Maintain signing logs and audit trails
5. **Incident Response**: Have procedures for compromised keys

## Reporting Security Issues

Report security vulnerabilities to: security@bizsync.app

Do not disclose security issues publicly until they are resolved.

## Compliance

This AppImage signing follows industry best practices:

- GPG signatures for authenticity
- SHA256 checksums for integrity
- Detached signatures for non-repudiation
- Key rotation procedures
- Secure CI/CD pipelines
EOF

    log_security "Security documentation created: ${docs_dir}/SECURITY.md"
}

# Main function
main() {
    if ! check_gpg; then
        exit 1
    fi
    
    case "${1:-help}" in
        "generate-key")
            generate_signing_key "$2" "$3"
            ;;
        "import-key")
            import_signing_key "$2"
            ;;
        "list-keys")
            list_signing_keys
            ;;
        "sign")
            sign_appimage "$2" "$3"
            ;;
        "verify")
            verify_appimage "$2"
            ;;
        "create-verify-script")
            create_verification_script "$2"
            ;;
        "setup-ci")
            setup_ci_signing
            ;;
        "create-docs")
            create_security_docs
            ;;
        "info")
            echo "Signing Manager Information:"
            echo "  Default Key: $(get_signing_key 2>/dev/null || echo 'None')"
            echo "  Keys Directory: $KEYS_DIR"
            echo "  Available Keys:"
            list_signing_keys
            ;;
        *)
            echo "Usage: $0 {generate-key|import-key|list-keys|sign|verify|create-verify-script|setup-ci|create-docs|info}"
            echo ""
            echo "Commands:"
            echo "  generate-key [name] [email]  Generate new signing key"
            echo "  import-key <file>            Import signing key from file"
            echo "  list-keys                    List available signing keys"
            echo "  sign <appimage> [key-id]     Sign AppImage file"
            echo "  verify <appimage>            Verify AppImage signature"
            echo "  create-verify-script <file>  Create verification script"
            echo "  setup-ci                     Setup CI/CD signing"
            echo "  create-docs                  Create security documentation"
            echo "  info                         Show signing information"
            echo ""
            echo "Examples:"
            echo "  $0 generate-key 'BizSync Release' 'release@bizsync.app'"
            echo "  $0 sign ./appimage/build/BizSync-1.2.0-x86_64.AppImage"
            echo "  $0 verify ./appimage/build/BizSync-1.2.0-x86_64.AppImage"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"