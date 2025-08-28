#!/usr/bin/env bash
# Install Aurora Git Hooks
# Sets up automatic README sync reminders

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[Aurora Hooks]${NC} $1"
}

success() {
    echo -e "${GREEN}[Success]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[Info]${NC} $1"
}

# Create pre-commit hook that reminds to sync README
create_pre_commit_hook() {
    local hook_file="$HOOKS_DIR/pre-commit"
    
    cat > "$hook_file" << 'EOF'
#!/bin/bash
# Aurora Pre-commit Hook
# Reminds to sync README when progress file changes

PROGRESS_FILE="APKSplicer/Docs/aurora_progress.md"

# Check if progress file is being committed
if git diff --cached --name-only | grep -q "$PROGRESS_FILE"; then
    echo "🔄 Aurora Progress file updated!"
    echo "💡 Don't forget to sync README: ./Scripts/sync-readme-progress.sh"
    echo ""
    
    # Optionally auto-sync (uncomment to enable)
    # echo "🤖 Auto-syncing README..."
    # ./Scripts/sync-readme-progress.sh
    # git add README.md
    # echo "✅ README synced automatically"
fi
EOF
    
    chmod +x "$hook_file"
    success "Pre-commit hook installed"
}

# Create post-commit hook for success message
create_post_commit_hook() {
    local hook_file="$HOOKS_DIR/post-commit"
    
    cat > "$hook_file" << 'EOF'
#!/bin/bash
# Aurora Post-commit Hook
# Shows success message and reminds about README sync

# Check if this was a progress update commit
if git diff-tree --no-commit-id --name-only -r HEAD | grep -q "aurora_progress.md"; then
    echo ""
    echo "🎉 Aurora progress committed!"
    echo "📝 Remember to check if README.md needs updating"
    echo "🔄 Run: ./Scripts/sync-readme-progress.sh"
    echo ""
fi
EOF
    
    chmod +x "$hook_file"
    success "Post-commit hook installed"
}

# Main installation
main() {
    log "Installing Aurora Git hooks..."
    
    if [[ ! -d "$HOOKS_DIR" ]]; then
        warn "Git hooks directory not found. Are you in a Git repository?"
        exit 1
    fi
    
    create_pre_commit_hook
    create_post_commit_hook
    
    echo ""
    success "✅ Aurora Git hooks installed!"
    warn "💡 Hooks will remind you to sync README when progress file changes"
    warn "🔧 Edit hooks in .git/hooks/ to customize behavior"
    
    echo ""
    log "To enable auto-sync, uncomment lines in .git/hooks/pre-commit"
}

main "$@"
