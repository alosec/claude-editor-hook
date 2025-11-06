#!/usr/bin/env bash
#
# g-menu - Installation Script
#
# Installs the wrapper to ~/.local/bin and tracks deployment metadata

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="$HOME/.local/bin"
WRAPPER_NAME="g-menu"
METADATA_FILE="$INSTALL_DIR/.g-menu-install.json"

# Get the directory where this script lives (project root)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

print_header() {
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  ${BLUE}g-menu - Installation${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
}

# Get git metadata
get_git_info() {
    if ! command -v git >/dev/null 2>&1; then
        print_error "git not found"
        return 1
    fi

    if ! git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        print_error "Not a git repository: $PROJECT_DIR"
        return 1
    fi

    # Get current commit hash
    GIT_COMMIT=$(git -C "$PROJECT_DIR" rev-parse HEAD)
    GIT_SHORT_COMMIT=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)

    # Get current branch
    GIT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD)

    # Get commit date
    GIT_DATE=$(git -C "$PROJECT_DIR" log -1 --format=%ci)

    # Get commit message
    GIT_MESSAGE=$(git -C "$PROJECT_DIR" log -1 --format=%s)

    # Check for uncommitted changes
    if ! git -C "$PROJECT_DIR" diff-index --quiet HEAD -- 2>/dev/null; then
        GIT_DIRTY="true"
    else
        GIT_DIRTY="false"
    fi
}

# Display current installation info
show_current_installation() {
    if [[ -f "$METADATA_FILE" ]]; then
        print_info "Current installation found:"
        echo

        # Pretty print the JSON
        if command -v jq >/dev/null 2>&1; then
            cat "$METADATA_FILE" | jq -r '
                "  Branch:      \(.branch)",
                "  Commit:      \(.commit_short) (\(.commit))",
                "  Date:        \(.commit_date)",
                "  Message:     \(.commit_message)",
                "  Installed:   \(.install_date)",
                "  Path:        \(.install_path)",
                if .dirty == "true" then "  Status:      ⚠️  DIRTY (uncommitted changes)" else "  Status:      ✓ Clean" end
            '
        else
            cat "$METADATA_FILE"
        fi
        echo
    else
        print_info "No previous installation found"
        echo
    fi
}

# Create installation metadata
create_metadata() {
    local install_path="$1"

    cat > "$METADATA_FILE" <<EOF
{
  "install_date": "$(date -Iseconds)",
  "install_path": "$install_path",
  "project_dir": "$PROJECT_DIR",
  "branch": "$GIT_BRANCH",
  "commit": "$GIT_COMMIT",
  "commit_short": "$GIT_SHORT_COMMIT",
  "commit_date": "$GIT_DATE",
  "commit_message": "$GIT_MESSAGE",
  "dirty": "$GIT_DIRTY"
}
EOF
}

# Main installation
install_wrapper() {
    print_header

    # Get git info
    print_info "Gathering git metadata..."
    if ! get_git_info; then
        print_error "Failed to get git information"
        exit 1
    fi

    # Show what we're about to install
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Installation Details"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "  Branch:      $GIT_BRANCH"
    echo "  Commit:      $GIT_SHORT_COMMIT ($GIT_COMMIT)"
    echo "  Date:        $GIT_DATE"
    echo "  Message:     $GIT_MESSAGE"
    if [[ "$GIT_DIRTY" == "true" ]]; then
        echo "  Status:      ⚠️  DIRTY (uncommitted changes)"
    else
        echo "  Status:      ✓ Clean"
    fi
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    # Show current installation if exists
    show_current_installation

    # Create install directory if needed
    if [[ ! -d "$INSTALL_DIR" ]]; then
        print_info "Creating install directory: $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
    fi

    # Check if already installed
    local wrapper_path="$INSTALL_DIR/$WRAPPER_NAME"
    if [[ -L "$wrapper_path" ]]; then
        print_info "Removing existing symlink..."
        rm "$wrapper_path"
    elif [[ -f "$wrapper_path" ]]; then
        print_warning "Found existing file (not symlink), backing up..."
        mv "$wrapper_path" "$wrapper_path.backup.$(date +%s)"
    fi

    # Create symlink
    print_info "Creating symlink: $wrapper_path -> $PROJECT_DIR/bin/$WRAPPER_NAME"
    ln -s "$PROJECT_DIR/bin/$WRAPPER_NAME" "$wrapper_path"

    # Create metadata file
    print_info "Writing installation metadata..."
    create_metadata "$wrapper_path"

    # Verify installation
    if [[ -x "$wrapper_path" ]]; then
        print_success "Installation complete!"
    else
        print_error "Installation failed - wrapper not executable"
        exit 1
    fi

    # Show next steps
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Next Steps"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "1. Ensure ~/.local/bin is in your PATH"
    echo "   Add to ~/.bashrc: export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo
    echo "2. Set EDITOR environment variable"
    echo "   Add to ~/.bashrc: export EDITOR=\"g-menu\""
    echo
    echo "3. Reload your shell"
    echo "   Run: source ~/.bashrc"
    echo
    echo "4. Verify installation"
    echo "   Run: $WRAPPER_NAME --version  (or check installation info)"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
}

# Show installation info
show_info() {
    print_header

    if [[ ! -f "$METADATA_FILE" ]]; then
        print_error "No installation found"
        echo
        echo "Run: $0 install"
        exit 1
    fi

    print_info "Installation Information:"
    echo

    if command -v jq >/dev/null 2>&1; then
        cat "$METADATA_FILE" | jq -r '
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            "  Git Information",
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            "",
            "  Branch:        \(.branch)",
            "  Commit:        \(.commit_short) (\(.commit))",
            "  Date:          \(.commit_date)",
            "  Message:       \(.commit_message)",
            if .dirty == "true" then "  Status:        ⚠️  DIRTY (uncommitted changes)" else "  Status:        ✓ Clean" end,
            "",
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            "  Installation",
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            "",
            "  Installed:     \(.install_date)",
            "  Path:          \(.install_path)",
            "  Project Dir:   \(.project_dir)",
            "",
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        '
    else
        cat "$METADATA_FILE"
    fi
    echo
}

# Uninstall
uninstall() {
    print_header
    print_info "Uninstalling g-menu..."

    local wrapper_path="$INSTALL_DIR/$WRAPPER_NAME"

    if [[ -L "$wrapper_path" ]] || [[ -f "$wrapper_path" ]]; then
        rm "$wrapper_path"
        print_success "Removed: $wrapper_path"
    else
        print_warning "Wrapper not found at: $wrapper_path"
    fi

    if [[ -f "$METADATA_FILE" ]]; then
        rm "$METADATA_FILE"
        print_success "Removed metadata file"
    fi

    echo
    print_success "Uninstallation complete!"
    echo
}

# Main
main() {
    local command="${1:-install}"

    case "$command" in
        install)
            install_wrapper
            ;;
        info|status)
            show_info
            ;;
        uninstall|remove)
            uninstall
            ;;
        *)
            echo "Usage: $0 {install|info|uninstall}"
            echo
            echo "Commands:"
            echo "  install     Install g-menu (default)"
            echo "  info        Show installation information"
            echo "  uninstall   Remove installation"
            exit 1
            ;;
    esac
}

main "$@"
