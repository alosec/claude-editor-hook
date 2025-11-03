#!/usr/bin/env bash
# Setup global Alt-g keybinding for tmux command palette
# This makes the palette accessible from any tmux session

TMUX_CONF="$HOME/.tmux.conf"
BINDING_LINE='bind-key -n M-g display-popup -E -w 80% -h 60% "tmux-command-palette"'
COMMENT="# Claude command palette - Alt-g to open from anywhere"

echo "Setting up global Alt-g keybinding for tmux command palette..."
echo ""

# Check if tmux-command-palette is in PATH
if ! command -v tmux-command-palette &>/dev/null; then
    echo "Warning: tmux-command-palette not found in PATH"
    echo "You may need to run: ln -s $(pwd)/bin/tmux-command-palette ~/.local/bin/"
    echo ""
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create ~/.tmux.conf if it doesn't exist
if [ ! -f "$TMUX_CONF" ]; then
    echo "Creating $TMUX_CONF..."
    touch "$TMUX_CONF"
fi

# Check if binding already exists
if grep -qF "$BINDING_LINE" "$TMUX_CONF"; then
    echo "✓ Keybinding already exists in $TMUX_CONF"
    exit 0
fi

# Add the binding
echo "" >> "$TMUX_CONF"
echo "$COMMENT" >> "$TMUX_CONF"
echo "$BINDING_LINE" >> "$TMUX_CONF"

echo "✓ Added keybinding to $TMUX_CONF"
echo ""
echo "To activate the binding:"
echo "  1. In existing tmux sessions: tmux source-file ~/.tmux.conf"
echo "  2. Or restart tmux"
echo ""
echo "Usage: Press Alt-g from any tmux window to open the command palette"
