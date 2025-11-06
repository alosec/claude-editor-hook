#!/usr/bin/env bash
# Jump to menu window in User session from anywhere
# Usage: focus-menu-pane.sh

SESSION_NAME="User"
MENU_WINDOW="menu"

# Check if we're in tmux
if [ -z "$TMUX" ]; then
    echo "Error: Not in a tmux session" >&2
    exit 1
fi

# Check if User session exists
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Error: User session does not exist. Run 'u' to initialize." >&2
    exit 1
fi

# Check if menu window exists
if ! tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null | grep -q "^${MENU_WINDOW}$"; then
    echo "Error: Menu window does not exist in User session" >&2
    exit 1
fi

# Get current session name
CURRENT_SESSION=$(tmux display-message -p '#{session_name}')

if [ "$CURRENT_SESSION" = "$SESSION_NAME" ]; then
    # Already in User session, just switch to menu window
    tmux select-window -t "$SESSION_NAME:$MENU_WINDOW"
else
    # In different session, switch to User session and select menu window
    tmux switch-client -t "$SESSION_NAME"
    tmux select-window -t "$SESSION_NAME:$MENU_WINDOW"
fi
