#!/usr/bin/env bash
# Aurora README Progress Sync Script
# Automatically updates README.md with latest progress from aurora_progress.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROGRESS_FILE="$PROJECT_ROOT/APKSplicer/Docs/aurora_progress.md"
README_FILE="$PROJECT_ROOT/README.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[Aurora Sync]${NC} $1"
}

success() {
    echo -e "${GREEN}[Success]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[Warning]${NC} $1"
}

error() {
    echo -e "${RED}[Error]${NC} $1"
}

# Extract overall progress percentage from aurora_progress.md
extract_progress_percentage() {
    if [[ -f "$PROGRESS_FILE" ]]; then
        # Look for line with "Overall Progress: XX%"
        local progress_line=$(grep -E "Overall Progress.*[0-9]+%" "$PROGRESS_FILE" | head -1)
        if [[ -n "$progress_line" ]]; then
            # Extract percentage using regex - handle the format "50% (Phase..."
            echo "$progress_line" | sed -E 's/.*: ([0-9]+)%.*/\1/'
        else
            echo "50" # Default fallback
        fi
    else
        echo "50" # Default fallback
    fi
}

# Extract recent completed tasks from aurora_progress.md
extract_recent_tasks() {
    if [[ -f "$PROGRESS_FILE" ]]; then
        # Look for completed tasks (lines with ✅)
        grep -E "✅.*2025-01-27" "$PROGRESS_FILE" | head -5 | sed 's/^[[:space:]]*/- /'
    fi
}

# Extract current phase from aurora_progress.md
extract_current_phase() {
    if [[ -f "$PROGRESS_FILE" ]]; then
        local phase_line=$(grep -E "Current Phase:" "$PROGRESS_FILE" | head -1)
        if [[ -n "$phase_line" ]]; then
            echo "$phase_line" | sed 's/.*Current Phase[^:]*: *//'
        else
            echo "Phase B — Install & Play"
        fi
    else
        echo "Phase B — Install & Play"
    fi
}

# Generate progress status text
generate_progress_status() {
    local percentage=$1
    local phase="$2"
    
    if [[ $percentage -ge 75 ]]; then
        echo "**Production-Ready** ($percentage% Complete)"
    elif [[ $percentage -ge 50 ]]; then
        echo "**Advanced Development** ($percentage% Complete)"
    elif [[ $percentage -ge 25 ]]; then
        echo "**Early Development** ($percentage% Complete)"
    else
        echo "**Foundation** ($percentage% Complete)"
    fi
}

# Update README.md with latest progress
update_readme() {
    local percentage=$(extract_progress_percentage)
    local phase=$(extract_current_phase)
    local status=$(generate_progress_status "$percentage" "$phase")
    
    log "Updating README with progress: $percentage%"
    
    # Create temporary file for updates
    local temp_readme=$(mktemp)
    
    # Process README line by line
    local in_features_section=false
    local updated_features=false
    
    while IFS= read -r line; do
        # Update the production-ready status line
        if [[ "$line" =~ ^###[[:space:]]*[✅🚧].*\([0-9]+%.*Complete\) ]]; then
            echo "### ✅ $status"
            updated_features=true
        # Update overall progress badge/percentage
        elif [[ "$line" =~ Progress.*[0-9]+% ]]; then
            echo "$line" | sed -E "s/[0-9]+%/${percentage}%/g"
        # Update current phase information
        elif [[ "$line" =~ Current.*Phase ]]; then
            echo "- **Current Phase**: $phase"
        else
            echo "$line"
        fi
    done < "$README_FILE" > "$temp_readme"
    
    # Replace original README
    mv "$temp_readme" "$README_FILE"
    
    success "README.md updated with $percentage% progress"
}

# Generate a dynamic recent achievements section
generate_recent_achievements() {
    local recent_tasks=$(extract_recent_tasks)
    
    if [[ -n "$recent_tasks" ]]; then
        cat << EOF

## 🎯 Recent Achievements

$recent_tasks

*Last updated: $(date '+%Y-%m-%d %H:%M')*
EOF
    fi
}

# Update recent achievements section in README
update_recent_achievements() {
    local temp_readme=$(mktemp)
    local in_achievements_section=false
    local achievements_content=$(generate_recent_achievements)
    
    # Remove existing recent achievements section and add new one
    while IFS= read -r line; do
        if [[ "$line" =~ ^##.*Recent.*Achievements ]]; then
            in_achievements_section=true
            continue
        elif [[ "$line" =~ ^## && "$in_achievements_section" == true ]]; then
            # End of achievements section, add new content and continue
            echo "$achievements_content"
            echo ""
            echo "$line"
            in_achievements_section=false
        elif [[ "$in_achievements_section" == false ]]; then
            echo "$line"
        fi
    done < "$README_FILE" > "$temp_readme"
    
    # If we're at the end and still in achievements section, add content
    if [[ "$in_achievements_section" == true ]]; then
        echo "$achievements_content" >> "$temp_readme"
    fi
    
    mv "$temp_readme" "$README_FILE"
}

# Main execution
main() {
    log "Starting Aurora README progress sync..."
    
    # Verify files exist
    if [[ ! -f "$PROGRESS_FILE" ]]; then
        error "Progress file not found: $PROGRESS_FILE"
        exit 1
    fi
    
    if [[ ! -f "$README_FILE" ]]; then
        error "README file not found: $README_FILE"
        exit 1
    fi
    
    # Update README sections
    update_readme
    update_recent_achievements
    
    # Show summary
    local percentage=$(extract_progress_percentage)
    local phase=$(extract_current_phase)
    
    echo ""
    success "✅ README sync complete!"
    log "📊 Progress: $percentage%"
    log "📍 Phase: $phase"
    log "📝 README updated with latest achievements"
    
    # If git is available, show diff
    if command -v git >/dev/null 2>&1 && [[ -d "$PROJECT_ROOT/.git" ]]; then
        echo ""
        log "📋 Changes made to README.md:"
        git diff --no-index /dev/null "$README_FILE" | tail -n +5 | head -10 || true
    fi
}

# Run main function
main "$@"
