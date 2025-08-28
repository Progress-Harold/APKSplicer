#!/usr/bin/env bash
# Aurora Android Image Setup Script
# Downloads and configures Android kernel and disk images for AVF

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGES_DIR="$PROJECT_ROOT/Images"
KERNELS_DIR="$IMAGES_DIR/kernels"
DISKS_DIR="$IMAGES_DIR/disks"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[Aurora]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[Warning]${NC} $1"
}

error() {
    echo -e "${RED}[Error]${NC} $1"
}

success() {
    echo -e "${GREEN}[Success]${NC} $1"
}

# Create directory structure
setup_directories() {
    log "Setting up directory structure..."
    mkdir -p "$KERNELS_DIR" "$DISKS_DIR"
    success "Directories created"
}

# Download Android-x86 kernel (easier to get started than GSI)
download_android_x86_kernel() {
    local kernel_version="android-x86-9.0-r2"
    local kernel_url="https://osdn.net/projects/android-x86/downloads/71931/android-x86_64-9.0-r2.iso"
    local kernel_iso="$KERNELS_DIR/${kernel_version}.iso"
    
    if [[ -f "$kernel_iso" ]]; then
        log "Android-x86 ISO already exists: $kernel_iso"
        return 0
    fi
    
    log "Downloading Android-x86 kernel ISO..."
    log "URL: $kernel_url"
    log "This may take several minutes..."
    
    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$kernel_iso" "$kernel_url" || {
            error "Failed to download Android-x86 ISO"
            return 1
        }
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$kernel_iso" "$kernel_url" || {
            error "Failed to download Android-x86 ISO"
            return 1
        }
    else
        error "Neither curl nor wget found. Please install one of them."
        return 1
    fi
    
    success "Downloaded Android-x86 ISO: $kernel_iso"
}

# Extract kernel from ISO
extract_kernel_from_iso() {
    local kernel_version="android-x86-9.0-r2"
    local kernel_iso="$KERNELS_DIR/${kernel_version}.iso"
    local extract_dir="$KERNELS_DIR/${kernel_version}_extracted"
    local kernel_file="$KERNELS_DIR/android-kernel"
    local initrd_file="$KERNELS_DIR/android-initrd.img"
    
    if [[ -f "$kernel_file" ]] && [[ -f "$initrd_file" ]]; then
        log "Kernel and initrd already extracted"
        return 0
    fi
    
    if [[ ! -f "$kernel_iso" ]]; then
        error "Android-x86 ISO not found. Run download first."
        return 1
    fi
    
    log "Extracting kernel from ISO..."
    
    # Create mount point
    local mount_point="$extract_dir/mount"
    mkdir -p "$mount_point"
    
    # Mount the ISO
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        hdiutil attach "$kernel_iso" -mountpoint "$mount_point" -readonly || {
            error "Failed to mount ISO"
            return 1
        }
        
        # Copy kernel and initrd
        if [[ -f "$mount_point/kernel" ]]; then
            cp "$mount_point/kernel" "$kernel_file"
        elif [[ -f "$mount_point/boot/kernel" ]]; then
            cp "$mount_point/boot/kernel" "$kernel_file"
        else
            error "Kernel not found in expected locations"
            hdiutil detach "$mount_point"
            return 1
        fi
        
        if [[ -f "$mount_point/initrd.img" ]]; then
            cp "$mount_point/initrd.img" "$initrd_file"
        elif [[ -f "$mount_point/boot/initrd.img" ]]; then
            cp "$mount_point/boot/initrd.img" "$initrd_file"
        else
            warn "initrd.img not found, continuing without it"
        fi
        
        # Unmount
        hdiutil detach "$mount_point"
    else
        error "Unsupported platform for ISO extraction"
        return 1
    fi
    
    success "Kernel extracted to: $kernel_file"
    if [[ -f "$initrd_file" ]]; then
        success "Initrd extracted to: $initrd_file"
    fi
}

# Create a basic Android disk image
create_android_disk() {
    local disk_name="android-base.img"
    local disk_path="$DISKS_DIR/$disk_name"
    local disk_size_gb=8
    
    if [[ -f "$disk_path" ]]; then
        log "Android disk image already exists: $disk_path"
        return 0
    fi
    
    log "Creating Android disk image (${disk_size_gb}GB)..."
    
    # Create sparse disk image
    local disk_size_bytes=$((disk_size_gb * 1024 * 1024 * 1024))
    
    # Use dd to create sparse file
    dd if=/dev/zero of="$disk_path" bs=1 count=0 seek=$disk_size_bytes || {
        error "Failed to create disk image"
        return 1
    }
    
    success "Created Android disk image: $disk_path"
    log "Size: ${disk_size_gb}GB (sparse)"
}

# Create configuration file with paths
create_config() {
    local config_file="$IMAGES_DIR/aurora-config.json"
    
    cat > "$config_file" << EOF
{
  "version": "1.0",
  "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "kernels": {
    "android-x86-9": {
      "kernel_path": "kernels/android-kernel",
      "initrd_path": "kernels/android-initrd.img",
      "boot_args": "androidboot.hardware=android_x86_64 androidboot.console=ttyS0 quiet",
      "architecture": "x86_64",
      "recommended_memory_mb": 4096,
      "recommended_cpu_count": 4
    }
  },
  "disk_templates": {
    "android-base": {
      "path": "disks/android-base.img",
      "size_gb": 8,
      "format": "raw",
      "description": "Base Android disk image"
    }
  },
  "notes": [
    "This configuration supports Android-x86 for initial testing",
    "For production, consider using Android GSI arm64 builds",
    "Kernel paths are relative to the Images directory"
  ]
}
EOF
    
    success "Created configuration file: $config_file"
}

# Verify setup
verify_setup() {
    log "Verifying Android setup..."
    
    local kernel_file="$KERNELS_DIR/android-kernel"
    local disk_file="$DISKS_DIR/android-base.img"
    local config_file="$IMAGES_DIR/aurora-config.json"
    
    local errors=0
    
    if [[ ! -f "$kernel_file" ]]; then
        error "Kernel file missing: $kernel_file"
        ((errors++))
    else
        success "Kernel file found: $kernel_file"
        log "  Size: $(du -h "$kernel_file" | cut -f1)"
    fi
    
    if [[ ! -f "$disk_file" ]]; then
        error "Disk image missing: $disk_file"
        ((errors++))
    else
        success "Disk image found: $disk_file"
        log "  Size: $(du -h "$disk_file" | cut -f1)"
    fi
    
    if [[ ! -f "$config_file" ]]; then
        error "Config file missing: $config_file"
        ((errors++))
    else
        success "Config file found: $config_file"
    fi
    
    if [[ $errors -eq 0 ]]; then
        success "Android setup verification complete!"
        log ""
        log "Next steps:"
        log "1. Update VMManager to use kernel at: $kernel_file"
        log "2. Point disk image creation to: $DISKS_DIR"
        log "3. Test VM boot with Android-x86 kernel"
        log ""
        log "Note: This uses Android-x86 for initial testing."
        log "For production, consider switching to Android GSI arm64."
    else
        error "Setup verification failed with $errors errors"
        return 1
    fi
}

# Show help
show_help() {
    cat << EOF
Aurora Android Image Setup Script

Usage: $0 [command]

Commands:
    download    Download Android-x86 ISO
    extract     Extract kernel from downloaded ISO
    disk        Create base Android disk image
    config      Create configuration file
    verify      Verify setup is complete
    all         Run all setup steps (default)
    help        Show this help message

Examples:
    $0              # Run complete setup
    $0 all          # Run complete setup
    $0 download     # Only download ISO
    $0 verify       # Check current setup

EOF
}

# Main execution
main() {
    local command="${1:-all}"
    
    case "$command" in
        "download")
            setup_directories
            download_android_x86_kernel
            ;;
        "extract")
            setup_directories
            extract_kernel_from_iso
            ;;
        "disk")
            setup_directories
            create_android_disk
            ;;
        "config")
            setup_directories
            create_config
            ;;
        "verify")
            verify_setup
            ;;
        "all"|"")
            log "Starting Aurora Android image setup..."
            setup_directories
            download_android_x86_kernel
            extract_kernel_from_iso
            create_android_disk
            create_config
            verify_setup
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
