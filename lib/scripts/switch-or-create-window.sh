#!/usr/bin/env bash
# Switch to existing window or create new one
# Usage: switch-or-create-window.sh <session-name> <window-name> <command>

SESSION_NAME="$1"
WINDOW_NAME="$2"
COMMAND="$3"

if [ -z "$SESSION_NAME" ] || [ -z "$WINDOW_NAME" ]; then
    echo "Usage: switch-or-create-window.sh <session-name> <window-name> [command]" >&2
    exit 1
fi

# Check if session exists
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Error: Session '$SESSION_NAME' does not exist" >&2
    exit 1
fi

# Check if window already exists
if tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null | grep -q "^${WINDOW_NAME}$"; then
    # Window exists, switch to it
    tmux select-window -t "$SESSION_NAME:$WINDOW_NAME"
else
    # Window doesn't exist, create it
    if [ -n "$COMMAND" ]; then
        # Create with specific command
        tmux new-window -t "$SESSION_NAME" -n "$WINDOW_NAME" "$COMMAND"
    else
        # Create with default shell
        tmux new-window -t "$SESSION_NAME" -n "$WINDOW_NAME"
    fi
fi
