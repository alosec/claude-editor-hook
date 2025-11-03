#!/usr/bin/env bash
# List terminal windows in Claude session
# Returns formatted list: "terminal-1:Terminal 1", "terminal-2:Terminal 2 (workspace)", etc.
# Format: <window-name>:<display-label>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METADATA_SCRIPT="$SCRIPT_DIR/manage-terminal-metadata.sh"

# Session name
SESSION_NAME="Claude"

# Check if session exists
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    # Session doesn't exist, no terminals
    exit 0
fi

# Get list of windows matching terminal-* pattern
tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null | grep '^terminal-' | sort -t- -k2 -n | while read -r window_name; do
    # Extract terminal number from window name
    terminal_num=$(echo "$window_name" | grep -o '[0-9]*$')

    # Check if there's a custom display name
    display_name=$(bash "$METADATA_SCRIPT" get "$window_name")

    # Build display label
    if [ -n "$display_name" ]; then
        display_label="Terminal $terminal_num ($display_name)"
    else
        display_label="Terminal $terminal_num"
    fi

    # Output: window-name:display-label
    echo "$window_name:$display_label"
done
