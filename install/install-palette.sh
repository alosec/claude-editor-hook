#!/usr/bin/env bash
# Install tmux command palette
# Creates symlink and sets up keybinding

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
BIN_DIR="$HOME/.local/bin"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Installing Universal Tmux Command Palette"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Ensure ~/.local/bin exists
mkdir -p "$BIN_DIR"

# Create symlink for tmux-command-palette
echo "Creating symlink: $BIN_DIR/tmux-command-palette"
ln -sf "$REPO_ROOT/bin/tmux-command-palette" "$BIN_DIR/tmux-command-palette"

# Verify it's in PATH
if ! command -v tmux-command-palette &>/dev/null; then
    echo ""
    echo "Warning: $BIN_DIR is not in your PATH"
    echo "Add this to your ~/.bashrc or ~/.zshrc:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

echo "✓ Symlink created"
echo ""

# Run keybinding setup
echo "Setting up global Alt-g keybinding..."
bash "$SCRIPT_DIR/setup-global-keybinding.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Features available:"
echo "  • Alt-g - Open command palette from anywhere"
echo "  • Switch projects (fuzzy search ~/code)"
echo "  • Find files (current directory)"
echo "  • Git operations (status, log, branches)"
echo "  • Recent files (when in Claude session)"
echo "  • Prompt enhancement (when in Claude session)"
echo ""
echo "To activate in existing tmux sessions:"
echo "  tmux source-file ~/.tmux.conf"
echo ""
