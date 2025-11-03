#!/usr/bin/env bash
# Switch to an existing terminal window and update $PROMPT
# Usage: switch-to-terminal.sh <window-name> <prompt-file>

SESSION_NAME="Claude"
WINDOW_NAME="$1"
PROMPT_FILE="$2"

# Check if session exists
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Error: Claude session does not exist" >&2
    exit 1
fi

# Check if window exists
if ! tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' | grep -q "^${WINDOW_NAME}$"; then
    echo "Error: Window $WINDOW_NAME does not exist" >&2
    exit 1
fi

# Switch to the window
tmux select-window -t "$SESSION_NAME:$WINDOW_NAME"

# Update $PROMPT environment variable for the pane
# Use setenv to set it for the pane without sending visible commands
tmux set-environment -t "$SESSION_NAME:$WINDOW_NAME" PROMPT "$PROMPT_FILE"
